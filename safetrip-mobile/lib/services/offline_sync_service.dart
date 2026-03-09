import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'api_service.dart';

/// 동기화 결과 (§4)
class SyncResult {
  const SyncResult({required this.synced, required this.failed});
  factory SyncResult.empty() => const SyncResult(synced: 0, failed: 0);
  final int synced;
  final int failed;
  bool get hasFailures => failed > 0;
  int get total => synced + failed;
}

/// 스테이지별 내부 결과
class _StageResult {
  const _StageResult({this.synced = 0, this.failed = 0});
  final int synced;
  final int failed;
}

/// 오프라인 데이터 동기화 서비스
/// 네트워크 연결이 없을 때 위치 정보 및 SOS 요청을 로컬 DB에 저장하고,
/// 연결이 복구되면 서버로 일괄 업로드합니다.
class OfflineSyncService {
  factory OfflineSyncService() => _instance;
  OfflineSyncService._internal();
  static final OfflineSyncService _instance = OfflineSyncService._internal();

  Database? _database;
  static const String _tableLocations = 'TB_OFFLINE_LOCATION';
  static const String _tableSOS = 'TB_OFFLINE_SOS';
  static const String _tableChat = 'local_chat_queue';
  static const String _tableScheduleDraft = 'local_schedule_draft';
  static const String _tableCacheMeta = 'local_cache_meta';

  // §3.3 위치 큐 제한
  static const int _maxLocationRecords = 8640;
  static const int _maxLocationHours = 72;
  static const int _locationBatchSize = 100;

  // §3.4 채팅 큐 제한
  static const int _maxChatMessages = 100;

  bool _isSyncing = false;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'offline_sync.db');

    return await openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await _createTablesV1(db);
        await _createTablesV2(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createTablesV2(db);
        }
      },
    );
  }

  /// V1 테이블: 위치 데이터 큐, SOS 데이터 큐
  Future<void> _createTablesV1(Database db) async {
    // 위치 데이터 큐
    await db.execute('''
      CREATE TABLE $_tableLocations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        trip_id TEXT,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        accuracy REAL,
        altitude REAL,
        speed REAL,
        heading REAL,
        battery_level INTEGER,
        battery_is_charging INTEGER,
        network_type TEXT,
        timestamp TEXT NOT NULL,
        created_at INTEGER DEFAULT (strftime('%s', 'now'))
      )
    ''');

    // SOS 데이터 큐
    await db.execute('''
      CREATE TABLE $_tableSOS (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sos_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        trip_id TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        trigger_type TEXT NOT NULL,
        message TEXT,
        timestamp TEXT NOT NULL,
        created_at INTEGER DEFAULT (strftime('%s', 'now'))
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_offline_loc_time ON $_tableLocations(timestamp)',
    );
    await db.execute(
      'CREATE INDEX idx_offline_sos_time ON $_tableSOS(timestamp)',
    );
  }

  /// V2 테이블: 채팅 큐, 일정 드래프트, 캐시 메타 (§5.3-5.5)
  Future<void> _createTablesV2(Database db) async {
    // 채팅 큐 (§5.3)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_tableChat (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        trip_id TEXT NOT NULL,
        sender_id TEXT NOT NULL,
        message_type TEXT DEFAULT 'text',
        content TEXT NOT NULL,
        local_id TEXT NOT NULL UNIQUE,
        is_synced INTEGER DEFAULT 0,
        retry_count INTEGER DEFAULT 0,
        created_at TEXT DEFAULT (datetime('now'))
      )
    ''');

    // 일정 드래프트 (§5.4)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_tableScheduleDraft (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        schedule_id TEXT,
        trip_id TEXT NOT NULL,
        action TEXT NOT NULL,
        payload TEXT NOT NULL,
        is_synced INTEGER DEFAULT 0,
        conflict_status TEXT DEFAULT 'pending',
        created_at TEXT DEFAULT (datetime('now'))
      )
    ''');

    // 캐시 메타 (§5.5)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_tableCacheMeta (
        cache_key TEXT PRIMARY KEY,
        data TEXT NOT NULL,
        cached_at TEXT NOT NULL,
        expires_at TEXT,
        version INTEGER DEFAULT 1
      )
    ''');
  }

  /// 위치 데이터 큐에 추가
  Future<void> pushLocation({
    required String userId,
    required double latitude,
    required double longitude,
    String? tripId,
    double? accuracy,
    double? altitude,
    double? speed,
    double? heading,
    int? batteryLevel,
    bool? batteryIsCharging,
    String? networkType,
    DateTime? timestamp,
  }) async {
    try {
      final db = await database;

      // §3.3 위치 큐 상한 — 8,640건 초과 시 가장 오래된 레코드 삭제
      final count = Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM $_tableLocations'),
          ) ??
          0;
      if (count >= _maxLocationRecords) {
        final excess = count - _maxLocationRecords + 1;
        await db.rawDelete('''
          DELETE FROM $_tableLocations WHERE id IN (
            SELECT id FROM $_tableLocations ORDER BY timestamp ASC LIMIT ?
          )
        ''', [excess]);
        debugPrint('[OfflineSync] 위치 큐 가득 참 — $excess건 삭제');
      }

      await db.insert(_tableLocations, {
        'user_id': userId,
        'trip_id': tripId,
        'latitude': latitude,
        'longitude': longitude,
        'accuracy': accuracy,
        'altitude': altitude,
        'speed': speed,
        'heading': heading,
        'battery_level': batteryLevel,
        'battery_is_charging': batteryIsCharging == true ? 1 : 0,
        'network_type': networkType,
        'timestamp': (timestamp ?? DateTime.now()).toUtc().toIso8601String(),
      });
      debugPrint('[OfflineSync] 위치 큐 추가 성공');
    } catch (e) {
      debugPrint('[OfflineSync] 위치 큐 추가 실패: $e');
    }
  }

  /// SOS 데이터 큐에 추가
  Future<void> pushSOS({
    required String sosId,
    required String userId,
    required String tripId,
    required double latitude,
    required double longitude,
    required String triggerType,
    String? message,
    DateTime? timestamp,
  }) async {
    try {
      final db = await database;
      await db.insert(_tableSOS, {
        'sos_id': sosId,
        'user_id': userId,
        'trip_id': tripId,
        'latitude': latitude,
        'longitude': longitude,
        'trigger_type': triggerType,
        'message': message,
        'timestamp': (timestamp ?? DateTime.now()).toUtc().toIso8601String(),
      });
      debugPrint('[OfflineSync] SOS 큐 추가 성공');
    } catch (e) {
      debugPrint('[OfflineSync] SOS 큐 추가 실패: $e');
    }
  }

  /// 서버로 동기화 실행 — 6-Stage Sync Priority Engine (§4)
  Future<SyncResult> syncData(ApiService apiService) async {
    if (_isSyncing) return SyncResult.empty();
    _isSyncing = true;

    int totalSynced = 0;
    int totalFailed = 0;

    try {
      // Priority 1: SOS (§4 — 즉시)
      final sosResult = await _syncSOS(apiService);
      totalSynced += sosResult.synced;
      totalFailed += sosResult.failed;

      // Priority 2: Guardian alerts — FCM이 오프라인 전달을 네이티브로 처리.
      // Firebase Cloud Messaging은 디바이스가 오프라인일 때 메시지를 자체 큐에
      // 보관했다가 연결 복구 시 자동 전달하므로 별도 로컬 큐 불필요. (§4)

      // Priority 3: Location batch (100건씩, newest first)
      final locResult = await _syncLocations(apiService);
      totalSynced += locResult.synced;
      totalFailed += locResult.failed;

      // Priority 4: Schedule drafts (충돌 감지 포함)
      final schedResult = await _syncScheduleDrafts(apiService);
      totalSynced += schedResult.synced;
      totalFailed += schedResult.failed;

      // Priority 5: Chat messages (FIFO)
      final chatResult = await _syncChats(apiService);
      totalSynced += chatResult.synced;
      totalFailed += chatResult.failed;

      // Priority 6: General events (future extension)

      // Clean expired data
      await cleanExpiredLocations();
    } catch (e) {
      debugPrint('[OfflineSync] 동기화 중 에러: $e');
    } finally {
      _isSyncing = false;
    }

    return SyncResult(synced: totalSynced, failed: totalFailed);
  }

  /// Priority 1: SOS 동기화 (§4)
  Future<_StageResult> _syncSOS(ApiService apiService) async {
    int synced = 0, failed = 0;
    try {
      final db = await database;
      final sosList = await db.query(
        _tableSOS,
        orderBy: 'timestamp ASC',
        limit: 10,
      );
      if (sosList.isNotEmpty) {
        debugPrint('[OfflineSync] SOS 동기화 시작 (${sosList.length}건)');
        for (final item in sosList) {
          final success = await _uploadSOS(apiService, item);
          if (success) {
            await db.delete(
              _tableSOS,
              where: 'id = ?',
              whereArgs: [item['id']],
            );
            synced++;
          } else {
            failed++;
          }
        }
      }
    } catch (e) {
      debugPrint('[OfflineSync] SOS 동기화 에러: $e');
    }
    return _StageResult(synced: synced, failed: failed);
  }

  /// Priority 3: 위치 데이터 벌크 동기화 (§4, §3.3 — 최신 데이터 우선)
  Future<_StageResult> _syncLocations(ApiService apiService) async {
    int synced = 0, failed = 0;
    try {
      final db = await database;
      final locList = await db.query(
        _tableLocations,
        orderBy: 'timestamp DESC',
        limit: _locationBatchSize,
      );
      if (locList.isNotEmpty) {
        debugPrint('[OfflineSync] 위치 데이터 동기화 시작 (${locList.length}건)');
        final success = await _uploadLocationsBulk(apiService, locList);
        if (success) {
          final ids = locList.map((e) => e['id']).toList();
          await db.delete(
            _tableLocations,
            where: 'id IN (${List.filled(ids.length, '?').join(',')})',
            whereArgs: ids,
          );
          synced += locList.length;
          debugPrint('[OfflineSync] 위치 데이터 ${locList.length}건 동기화 완료');
        } else {
          failed += locList.length;
        }
      }
    } catch (e) {
      debugPrint('[OfflineSync] 위치 동기화 에러: $e');
    }
    return _StageResult(synced: synced, failed: failed);
  }

  /// Priority 4: 일정 드래프트 동기화 (§4 — 충돌 감지 포함)
  Future<_StageResult> _syncScheduleDrafts(ApiService apiService) async {
    int synced = 0, failed = 0;
    try {
      final drafts = await getPendingScheduleDrafts();
      for (final draft in drafts) {
        // 충돌 상태인 항목은 건너뜀 — 수동 해결 필요
        if (draft['conflict_status'] == 'conflict') continue;
        try {
          final action = draft['action'] as String;
          final payload = jsonDecode(draft['payload'] as String)
              as Map<String, dynamic>;
          bool success = false;

          switch (action) {
            case 'create':
              final result = await apiService.createSchedule(
                groupId: payload['group_id'] as String?,
                userId: payload['user_id'] as String?,
                title: payload['title'] as String,
                description: payload['description'] as String?,
                scheduleType: payload['schedule_type'] as String?,
                startTime: payload['start_time'],
                endTime: payload['end_time'],
                locationName: payload['location_name'] as String?,
                locationAddress: payload['location_address'] as String?,
                locationCoords: payload['location_coords'] as Map<String, dynamic>?,
                reminderEnabled: payload['reminder_enabled'] as bool?,
                timezone: payload['timezone'] as String?,
              );
              success = result != null;
              break;
            case 'update':
              final scheduleId = payload['schedule_id'] as String?;
              if (scheduleId == null) break;
              final result = await apiService.updateSchedule(
                scheduleId: scheduleId,
                groupId: payload['group_id'] as String?,
                userId: payload['user_id'] as String?,
                title: payload['title'] as String?,
                description: payload['description'] as String?,
                scheduleType: payload['schedule_type'] as String?,
                startTime: payload['start_time'] as String?,
                endTime: payload['end_time'] as String?,
                locationName: payload['location_name'] as String?,
                locationAddress: payload['location_address'] as String?,
                locationCoords: payload['location_coords'] as Map<String, dynamic>?,
                reminderEnabled: payload['reminder_enabled'] as bool?,
                timezone: payload['timezone'] as String?,
              );
              success = result != null;
              break;
            case 'delete':
              final scheduleId = payload['schedule_id'] as String?;
              if (scheduleId == null) break;
              success = await apiService.deleteSchedule(
                scheduleId: scheduleId,
              );
              break;
          }

          if (success) {
            await markScheduleSynced(draft['id'] as int, 'resolved');
            synced++;
          } else {
            // API 실패 시 충돌로 마킹 — UI에서 수동 해결 필요
            await resolveConflict(draft['id'] as int, 'conflict');
            failed++;
          }
        } catch (e) {
          debugPrint('[OfflineSync] 일정 드래프트 개별 동기화 에러: $e');
          failed++;
        }
      }
    } catch (e) {
      debugPrint('[OfflineSync] 일정 동기화 에러: $e');
    }
    return _StageResult(synced: synced, failed: failed);
  }

  /// Priority 5: 채팅 메시지 동기화 (§4 — FIFO)
  Future<_StageResult> _syncChats(ApiService apiService) async {
    int synced = 0, failed = 0;
    try {
      final chats = await getPendingChats(limit: 50);
      for (final chat in chats) {
        try {
          final success = await _uploadChat(apiService, chat);
          if (success) {
            await markChatSynced(chat['id'] as int);
            synced++;
          } else {
            failed++;
          }
        } catch (e) {
          failed++;
        }
      }
    } catch (e) {
      debugPrint('[OfflineSync] 채팅 동기화 에러: $e');
    }
    return _StageResult(synced: synced, failed: failed);
  }

  /// 채팅 메시지 업로드 헬퍼
  Future<bool> _uploadChat(
    ApiService apiService,
    Map<String, dynamic> chat,
  ) async {
    try {
      final tripId = chat['trip_id'] as String;
      final content = chat['content'] as String;
      final messageType = chat['message_type'] as String? ?? 'text';
      // trip_id를 roomId로 사용 (그룹 채팅은 trip 단위)
      final result = await apiService.sendChatMessage(
        roomId: tripId,
        content: content,
        messageType: messageType,
      );
      return result != null;
    } catch (e) {
      debugPrint('[OfflineSync] 채팅 업로드 실패: $e');
      return false;
    }
  }

  Future<bool> _uploadSOS(
    ApiService apiService,
    Map<String, dynamic> item,
  ) async {
    try {
      final data = {
        'sos_id': item['sos_id'],
        'user_id': item['user_id'],
        'trip_id': item['trip_id'],
        'latitude': item['latitude'],
        'longitude': item['longitude'],
        'trigger_type': item['trigger_type'],
        'message': item['message'],
        'timestamp': item['timestamp'],
        'is_offline_delayed': true,
      };
      final result = await apiService.sendSOS(data);
      return result != null;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _uploadLocationsBulk(
    ApiService apiService,
    List<Map<String, dynamic>> items,
  ) async {
    try {
      final locations = items
          .map(
            (item) => {
              'user_id': item['user_id'],
              'trip_id': item['trip_id'],
              'latitude': item['latitude'],
              'longitude': item['longitude'],
              'accuracy': item['accuracy'],
              'altitude': item['altitude'],
              'speed': item['speed'],
              'heading': item['heading'],
              'battery_level': item['battery_level'],
              'battery_is_charging': item['battery_is_charging'] == 1,
              'network_type': item['network_type'],
              'timestamp': item['timestamp'],
            },
          )
          .toList();

      return await apiService.syncOfflineLocations(locations);
    } catch (e) {
      return false;
    }
  }

  /// 남은 데이터 개수 확인
  Future<int> getPendingCount() async {
    final db = await database;
    final locCount =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM $_tableLocations'),
        ) ??
        0;
    final sosCount =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM $_tableSOS'),
        ) ??
        0;
    return locCount + sosCount;
  }

  /// §3.3 72시간 초과 위치 데이터 정리
  Future<int> cleanExpiredLocations() async {
    final db = await database;
    final cutoff = DateTime.now()
        .subtract(const Duration(hours: _maxLocationHours))
        .toUtc()
        .toIso8601String();
    final deleted = await db.delete(
      _tableLocations,
      where: 'timestamp < ?',
      whereArgs: [cutoff],
    );
    if (deleted > 0) {
      debugPrint('[OfflineSync] 72시간 초과 위치 $deleted건 삭제');
    }
    return deleted;
  }

  // ── Cache Meta (§5.5) ──────────────────────────────────────────────

  /// 캐시 메타데이터 저장 (upsert)
  Future<void> setCacheMeta({
    required String cacheKey,
    required String data,
    String? expiresAt,
  }) async {
    try {
      final db = await database;
      await db.insert(
        _tableCacheMeta,
        {
          'cache_key': cacheKey,
          'data': data,
          'cached_at': DateTime.now().toUtc().toIso8601String(),
          'expires_at': expiresAt,
          'version': 1,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      debugPrint('[OfflineSync] 캐시 메타 저장: $cacheKey');
    } catch (e) {
      debugPrint('[OfflineSync] 캐시 메타 저장 실패: $e');
    }
  }

  /// 캐시 메타데이터 조회 (만료된 항목은 null 반환)
  Future<Map<String, dynamic>?> getCacheMeta(String cacheKey) async {
    try {
      final db = await database;
      final results = await db.query(
        _tableCacheMeta,
        where: 'cache_key = ?',
        whereArgs: [cacheKey],
        limit: 1,
      );
      if (results.isEmpty) return null;

      final row = results.first;
      // 만료 시간이 설정되어 있고, 현재 시간이 만료 시간을 초과하면 null 반환
      final expiresAt = row['expires_at'] as String?;
      if (expiresAt != null) {
        final expiry = DateTime.tryParse(expiresAt);
        if (expiry != null && DateTime.now().toUtc().isAfter(expiry)) {
          // 만료된 캐시 삭제
          await db.delete(
            _tableCacheMeta,
            where: 'cache_key = ?',
            whereArgs: [cacheKey],
          );
          return null;
        }
      }
      return row;
    } catch (e) {
      debugPrint('[OfflineSync] 캐시 메타 조회 실패: $e');
      return null;
    }
  }

  // ── Chat Queue (§5.3) ──────────────────────────────────────────────

  /// 채팅 메시지를 오프라인 큐에 추가
  Future<bool> pushChat({
    required String tripId,
    required String senderId,
    required String content,
    required String localId,
    String messageType = 'text',
  }) async {
    try {
      final db = await database;

      // §3.4 채팅 큐 100건 제한 — 미동기화 메시지가 한도에 도달하면 거부
      final count = Sqflite.firstIntValue(
            await db.rawQuery(
              "SELECT COUNT(*) FROM $_tableChat WHERE is_synced = 0",
            ),
          ) ??
          0;
      if (count >= _maxChatMessages) {
        debugPrint('[OfflineSync] 채팅 큐 한도 도달 ($_maxChatMessages건)');
        return false;
      }

      await db.insert(_tableChat, {
        'trip_id': tripId,
        'sender_id': senderId,
        'message_type': messageType,
        'content': content,
        'local_id': localId,
        'is_synced': 0,
        'retry_count': 0,
      });
      debugPrint('[OfflineSync] 채팅 큐 추가 성공: $localId');
      return true;
    } catch (e) {
      debugPrint('[OfflineSync] 채팅 큐 추가 실패: $e');
      return false;
    }
  }

  /// 미동기화 채팅 메시지 조회
  Future<List<Map<String, dynamic>>> getPendingChats({int limit = 50}) async {
    try {
      final db = await database;
      return await db.query(
        _tableChat,
        where: 'is_synced = 0',
        orderBy: 'created_at ASC',
        limit: limit,
      );
    } catch (e) {
      debugPrint('[OfflineSync] 미동기화 채팅 조회 실패: $e');
      return [];
    }
  }

  /// 채팅 메시지 동기화 완료 처리
  Future<void> markChatSynced(int id) async {
    try {
      final db = await database;
      await db.update(
        _tableChat,
        {'is_synced': 1},
        where: 'id = ?',
        whereArgs: [id],
      );
      debugPrint('[OfflineSync] 채팅 동기화 완료: id=$id');
    } catch (e) {
      debugPrint('[OfflineSync] 채팅 동기화 처리 실패: $e');
    }
  }

  /// 미동기화 채팅 메시지 개수 조회
  Future<int> getPendingChatCount() async {
    try {
      final db = await database;
      return Sqflite.firstIntValue(
            await db.rawQuery(
              'SELECT COUNT(*) FROM $_tableChat WHERE is_synced = 0',
            ),
          ) ??
          0;
    } catch (e) {
      debugPrint('[OfflineSync] 미동기화 채팅 개수 조회 실패: $e');
      return 0;
    }
  }

  // ── Schedule Draft (§5.4) ──────────────────────────────────────────

  /// 일정 드래프트를 오프라인 큐에 추가
  Future<void> pushScheduleDraft({
    String? scheduleId,
    required String tripId,
    required String action,
    required String payload,
  }) async {
    try {
      final db = await database;
      await db.insert(_tableScheduleDraft, {
        'schedule_id': scheduleId,
        'trip_id': tripId,
        'action': action,
        'payload': payload,
        'is_synced': 0,
        'conflict_status': 'pending',
      });
      debugPrint('[OfflineSync] 일정 드래프트 추가 성공: $action');
    } catch (e) {
      debugPrint('[OfflineSync] 일정 드래프트 추가 실패: $e');
    }
  }

  /// 미동기화 일정 드래프트 조회
  Future<List<Map<String, dynamic>>> getPendingScheduleDrafts() async {
    try {
      final db = await database;
      return await db.query(
        _tableScheduleDraft,
        where: 'is_synced = 0',
        orderBy: 'created_at ASC',
      );
    } catch (e) {
      debugPrint('[OfflineSync] 미동기화 일정 드래프트 조회 실패: $e');
      return [];
    }
  }

  /// 충돌 상태인 드래프트 조회
  Future<List<Map<String, dynamic>>> getConflictedDrafts() async {
    try {
      final db = await database;
      return await db.query(
        _tableScheduleDraft,
        where: "conflict_status = 'conflict'",
        orderBy: 'created_at ASC',
      );
    } catch (e) {
      debugPrint('[OfflineSync] 충돌 드래프트 조회 실패: $e');
      return [];
    }
  }

  /// 일정 드래프트 동기화 완료 및 충돌 상태 업데이트
  Future<void> markScheduleSynced(int id, String conflictStatus) async {
    try {
      final db = await database;
      await db.update(
        _tableScheduleDraft,
        {
          'is_synced': 1,
          'conflict_status': conflictStatus,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      debugPrint(
        '[OfflineSync] 일정 드래프트 동기화 완료: id=$id, status=$conflictStatus',
      );
    } catch (e) {
      debugPrint('[OfflineSync] 일정 드래프트 동기화 처리 실패: $e');
    }
  }

  /// 충돌 드래프트 해결 처리
  Future<void> resolveConflict(int id, String resolution) async {
    try {
      final db = await database;
      await db.update(
        _tableScheduleDraft,
        {'conflict_status': resolution},
        where: 'id = ?',
        whereArgs: [id],
      );
      debugPrint(
        '[OfflineSync] 충돌 해결 완료: id=$id, resolution=$resolution',
      );
    } catch (e) {
      debugPrint('[OfflineSync] 충돌 해결 실패: $e');
    }
  }
}
