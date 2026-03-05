import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'api_service.dart';

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
      version: 1,
      onCreate: (db, version) async {
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
      },
    );
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

  /// 서버로 동기화 실행
  Future<void> syncData(ApiService apiService) async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final db = await database;

      // 1. SOS 우선 동기화
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
          }
        }
      }

      // 2. 위치 데이터 벌크 동기화
      final locList = await db.query(
        _tableLocations,
        orderBy: 'timestamp ASC',
        limit: 100,
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
          debugPrint('[OfflineSync] 위치 데이터 ${locList.length}건 동기화 완료');
        }
      }
    } catch (e) {
      debugPrint('[OfflineSync] 동기화 중 에러: $e');
    } finally {
      _isSyncing = false;
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
}
