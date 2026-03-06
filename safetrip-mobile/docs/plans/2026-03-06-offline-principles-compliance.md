# Offline Principles Compliance Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task.

**Goal:** Make the SafeTrip Flutter app fully compliant with DOC-T2-OFL-016 (오프라인 동작 통합 원칙) at P0 + P1 level.

**Architecture:** Incremental enhancement of existing stack. Enhance `connectivity_provider.dart`, `offline_sync_service.dart`, `sos_service.dart`, `offline_banner.dart`, and `location_service.dart`. Add new services for battery GPS management and emergency data caching.

**Tech Stack:** Flutter, Riverpod, sqflite, connectivity_plus, SharedPreferences

**Principles Document:** `Master_docs/16_T2_오프라인_동작_통합_원칙.md`

---

### Task 1: Enhanced Network Detection — 3-State with Healthcheck (§2)

**Files:**
- Modify: `lib/features/main/providers/connectivity_provider.dart`
- Modify: `lib/services/api_service.dart` (add health endpoint method)

**Context:**
Currently `connectivity_provider.dart` provides binary online/offline via `connectivity_plus`. The principles require 3 states (Online/Degraded/Offline) with HTTP healthcheck to `/api/v1/health` every 30s, and consecutive failure counting (2 fails → degraded, 3 fails → offline, 1 success → online).

**Step 1: Add NetworkState enum and NetworkStateNotifier**

In `connectivity_provider.dart`, add:

```dart
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';

/// 네트워크 상태 (오프라인 원칙 §2.1)
enum NetworkState { online, degraded, offline }

/// 네트워크 상태 + 마지막 동기화 시간
class NetworkStatus {
  const NetworkStatus({
    required this.state,
    this.lastSyncTime,
  });
  final NetworkState state;
  final DateTime? lastSyncTime;

  bool get isOffline => state == NetworkState.offline;
  bool get isDegraded => state == NetworkState.degraded;
  bool get isOnline => state == NetworkState.online;
}
```

Add `NetworkStateNotifier` class that:
- Listens to `Connectivity().onConnectivityChanged`
- Runs HTTP healthcheck every 30s (5s timeout) to `ApiService().healthCheck()`
- Tracks `_consecutiveFailures` counter
- State transitions: 0 failures → online, 2 failures → degraded, 3+ failures → offline
- On success from degraded: needs 2 consecutive successes to return to online
- On success from offline: immediate return to online (§2.3)
- Stores `lastSyncTime` in SharedPreferences key `'offline_last_sync_time'`
- Updates `lastSyncTime` whenever transitioning from non-online to online

Add providers:
```dart
final networkStateProvider = StateNotifierProvider<NetworkStateNotifier, NetworkStatus>((ref) {
  return NetworkStateNotifier();
});

// Backward-compatible provider
final isOfflineProvider = Provider<bool>((ref) {
  return ref.watch(networkStateProvider).isOffline;
});
```

**Step 2: Add healthCheck method to ApiService**

In `api_service.dart`, add:
```dart
Future<bool> healthCheck() async {
  try {
    final response = await _dio.get('/health',
      options: Options(receiveTimeout: Duration(seconds: 5)));
    return response.statusCode == 200;
  } catch (e) {
    return false;
  }
}
```

**Step 3: Verify**

Run `flutter analyze` — no new errors. Verify `isOfflineProvider` still works for existing consumers. The `networkStateProvider` should be available for new consumers.

**Step 4: Commit**

```bash
git add lib/features/main/providers/connectivity_provider.dart lib/services/api_service.dart
git commit -m "feat(offline): add 3-state network detection with healthcheck (§2)"
```

---

### Task 2: Offline Banner Enhancement (§8.1)

**Files:**
- Modify: `lib/widgets/components/offline_banner.dart`
- Modify: `lib/screens/main/screen_main.dart` (use networkStateProvider)

**Context:**
Current banner shows static "오프라인 상태" text. Principles require:
- Offline: "오프라인 모드 — 마지막 동기화: HH:MM" (orange)
- Degraded: "연결 불안정 — 재시도 중..." (yellow/amber)
- No banner when online

**Step 1: Enhance OfflineBanner to accept NetworkStatus**

Change `OfflineBanner` to accept `NetworkStatus` parameter:

```dart
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key, required this.status});
  final NetworkStatus status;

  @override
  Widget build(BuildContext context) {
    if (status.isOnline) return const SizedBox.shrink();

    final isOffline = status.isOffline;
    final bgColor = isOffline ? Colors.orange : Colors.amber;
    final icon = isOffline ? Icons.cloud_off : Icons.signal_wifi_statusbar_connected_no_internet_4;
    final text = isOffline
        ? '오프라인 모드 — 마지막 동기화: ${_formatTime(status.lastSyncTime)}'
        : '연결 불안정 — 재시도 중...';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      color: bgColor,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: AppSpacing.sm),
          Text(text, style: AppTypography.labelSmall.copyWith(
            color: Colors.white, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  String _formatTime(DateTime? time) {
    if (time == null) return '--:--';
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}
```

**Step 2: Update screen_main.dart**

Replace `ref.watch(isOfflineProvider)` with `ref.watch(networkStateProvider)` where the offline banner is displayed. Pass the `NetworkStatus` object to `OfflineBanner`.

**Step 3: Verify**

Run `flutter analyze`. Check that the banner compiles with the new signature. Existing offline behavior unchanged.

**Step 4: Commit**

```bash
git add lib/widgets/components/offline_banner.dart lib/screens/main/screen_main.dart
git commit -m "feat(offline): enhance banner with last sync time and degraded state (§8.1)"
```

---

### Task 3: SQLite Schema Extension — Chat, Schedule, Cache Tables (§5)

**Files:**
- Modify: `lib/services/offline_sync_service.dart`

**Context:**
Currently 2 tables (locations, SOS). Need to add 3 more per §5.3-5.5: `local_chat_queue`, `local_schedule_draft`, `local_cache_meta`. Must use database migration (version 1 → 2).

**Step 1: Add migration to version 2**

In `_initDatabase()`, change `version: 1` to `version: 2` and add `onUpgrade` callback:

```dart
return await openDatabase(
  path,
  version: 2,
  onCreate: (db, version) async {
    // All tables (original + new)
    await _createTablesV1(db);
    await _createTablesV2(db);
  },
  onUpgrade: (db, oldVersion, newVersion) async {
    if (oldVersion < 2) {
      await _createTablesV2(db);
    }
  },
);
```

Extract V1 tables to `_createTablesV1(db)` and add `_createTablesV2(db)`:

```dart
Future<void> _createTablesV2(Database db) async {
  // Chat queue (§5.3)
  await db.execute('''
    CREATE TABLE IF NOT EXISTS local_chat_queue (
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

  // Schedule draft (§5.4)
  await db.execute('''
    CREATE TABLE IF NOT EXISTS local_schedule_draft (
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

  // Cache meta (§5.5)
  await db.execute('''
    CREATE TABLE IF NOT EXISTS local_cache_meta (
      cache_key TEXT PRIMARY KEY,
      data TEXT NOT NULL,
      cached_at TEXT NOT NULL,
      expires_at TEXT,
      version INTEGER DEFAULT 1
    )
  ''');
}
```

**Step 2: Add table name constants**

```dart
static const String _tableChat = 'local_chat_queue';
static const String _tableScheduleDraft = 'local_schedule_draft';
static const String _tableCacheMeta = 'local_cache_meta';
```

**Step 3: Add push/query methods for new tables**

- `pushChat({tripId, senderId, content, localId, messageType})` — insert to chat queue
- `pushScheduleDraft({scheduleId, tripId, action, payload})` — insert to schedule draft
- `setCacheMeta({cacheKey, data, expiresAt})` — upsert to cache meta
- `getCacheMeta(cacheKey)` → `Map<String, dynamic>?` — read from cache meta
- `getPendingChats({limit})` → `List<Map<String, dynamic>>` — unsynced chats
- `getPendingScheduleDrafts()` → `List<Map<String, dynamic>>` — unsynced drafts
- `deleteSyncedChat(id)`, `markScheduleSynced(id, conflictStatus)`

**Step 4: Verify**

Run `flutter analyze`. No errors. The new tables don't affect existing functionality.

**Step 5: Commit**

```bash
git add lib/services/offline_sync_service.dart
git commit -m "feat(offline): add chat/schedule/cache SQLite tables (§5.3-5.5)"
```

---

### Task 4: Location Queue Limits — 72h/8,640 Records, Eviction (§3.3)

**Files:**
- Modify: `lib/services/offline_sync_service.dart`

**Context:**
Location queue currently has no limits. Principles require: max 72 hours, max 8,640 records, oldest-first eviction when full, newest-first upload.

**Step 1: Add constants**

```dart
static const int _maxLocationRecords = 8640;
static const int _maxLocationHours = 72;
static const int _locationBatchSize = 100;
```

**Step 2: Add eviction to pushLocation()**

Before inserting, check count. If >= 8,640, delete oldest:

```dart
final count = Sqflite.firstIntValue(
  await db.rawQuery('SELECT COUNT(*) FROM $_tableLocations')
) ?? 0;
if (count >= _maxLocationRecords) {
  final excess = count - _maxLocationRecords + 1;
  await db.rawDelete('''
    DELETE FROM $_tableLocations WHERE id IN (
      SELECT id FROM $_tableLocations ORDER BY timestamp ASC LIMIT ?
    )
  ''', [excess]);
  debugPrint('[OfflineSync] 위치 큐 가득 참 — $excess건 삭제');
}
```

**Step 3: Add 72-hour cleanup method**

```dart
Future<void> cleanExpiredLocations() async {
  final db = await database;
  final cutoff = DateTime.now().subtract(const Duration(hours: 72)).toUtc().toIso8601String();
  final deleted = await db.delete(
    _tableLocations,
    where: 'timestamp < ?',
    whereArgs: [cutoff],
  );
  if (deleted > 0) debugPrint('[OfflineSync] 72시간 초과 위치 $deleted건 삭제');
}
```

**Step 4: Change upload order to newest-first**

In `syncData()`, change location query:
```dart
orderBy: 'timestamp DESC',  // was ASC — newest first per §3.3
```

**Step 5: Verify & Commit**

```bash
git add lib/services/offline_sync_service.dart
git commit -m "feat(offline): add location queue limits 72h/8640 with eviction (§3.3)"
```

---

### Task 5: Chat Message Queuing — 100 Limit, FIFO (§3.4, §5.3)

**Files:**
- Modify: `lib/services/offline_sync_service.dart` (push/query methods from Task 3)

**Context:**
Chat messages need offline queuing with 100-message limit. When limit reached, show "한도 도달" message. FIFO delivery (oldest sent first). Each message gets a `local_id` (UUID) for deduplication.

**Step 1: Add chat queue limit constant and enforcement**

```dart
static const int _maxChatMessages = 100;
```

In `pushChat()`:
```dart
Future<bool> pushChat({
  required String tripId,
  required String senderId,
  required String content,
  required String localId,
  String messageType = 'text',
}) async {
  final db = await database;
  final count = Sqflite.firstIntValue(
    await db.rawQuery('SELECT COUNT(*) FROM $\_tableChat WHERE is_synced = 0')
  ) ?? 0;
  if (count >= _maxChatMessages) {
    debugPrint('[OfflineSync] 채팅 큐 한도 도달 (100건)');
    return false; // caller shows "한도 도달" UI
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
  return true;
}
```

**Step 2: Add FIFO query method**

```dart
Future<List<Map<String, dynamic>>> getPendingChats({int limit = 50}) async {
  final db = await database;
  return db.query(
    _tableChat,
    where: 'is_synced = 0',
    orderBy: 'created_at ASC', // FIFO — oldest first
    limit: limit,
  );
}
```

**Step 3: Add sync and delete methods**

```dart
Future<void> markChatSynced(int id) async {
  final db = await database;
  await db.update(_tableChat, {'is_synced': 1}, where: 'id = ?', whereArgs: [id]);
}

Future<int> getPendingChatCount() async {
  final db = await database;
  return Sqflite.firstIntValue(
    await db.rawQuery('SELECT COUNT(*) FROM $_tableChat WHERE is_synced = 0')
  ) ?? 0;
}
```

**Step 4: Verify & Commit**

```bash
git add lib/services/offline_sync_service.dart
git commit -m "feat(offline): add chat queue with 100-message FIFO limit (§3.4)"
```

---

### Task 6: 6-Stage Sync Priority Engine (§4)

**Files:**
- Modify: `lib/services/offline_sync_service.dart`

**Context:**
Current `syncData()` only handles SOS (Priority 1) and locations (Priority 3). Need all 6 stages, each as independent transaction. Failure in one stage doesn't block the next.

**Step 1: Redesign syncData()**

```dart
Future<SyncResult> syncData(ApiService apiService) async {
  if (_isSyncing) return SyncResult.empty();
  _isSyncing = true;

  int totalSynced = 0;
  int totalFailed = 0;

  try {
    // Priority 1: SOS (즉시)
    final sosResult = await _syncSOS(apiService);
    totalSynced += sosResult.synced;
    totalFailed += sosResult.failed;

    // Priority 2: Guardian alerts (currently no separate queue — skip for now)

    // Priority 3: Location batch (100건씩, newest first)
    final locResult = await _syncLocations(apiService);
    totalSynced += locResult.synced;
    totalFailed += locResult.failed;

    // Priority 4: Schedule drafts (conflict detection)
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
```

**Step 2: Add SyncResult class**

```dart
class SyncResult {
  const SyncResult({required this.synced, required this.failed});
  factory SyncResult.empty() => const SyncResult(synced: 0, failed: 0);
  final int synced;
  final int failed;
  bool get hasFailures => failed > 0;
}
```

**Step 3: Extract existing SOS/location sync into private methods**

`_syncSOS(apiService)` → returns `_StageResult`
`_syncLocations(apiService)` → returns `_StageResult`

**Step 4: Add _syncChats and _syncScheduleDrafts**

`_syncChats(apiService)`:
- Query `getPendingChats(limit: 50)`
- For each: POST to chat API endpoint
- On success: `markChatSynced(id)`
- On failure: increment retry_count

`_syncScheduleDrafts(apiService)`:
- Query pending drafts
- For each: check `updated_at` conflict with server
- On conflict: mark `conflict_status = 'conflict'` (shown in UI later)
- On success: mark synced

**Step 5: Update DeviceStatusService to handle SyncResult**

In `device_status_service.dart`, change the sync call to use the new return type so sync completion notifications can be shown.

**Step 6: Verify & Commit**

```bash
git add lib/services/offline_sync_service.dart lib/services/device_status_service.dart
git commit -m "feat(offline): implement 6-stage sync priority engine (§4)"
```

---

### Task 7: SOS Offline Fallback — SMS + Local Alarm (§3.2)

**Files:**
- Modify: `lib/services/sos_service.dart`
- Modify: `lib/services/offline_sync_service.dart` (cache meta read for emergency contacts)
- Modify: `pubspec.yaml` (add `url_launcher` already present, may need `audioplayers`)

**Context:**
SOS offline flow: 1) SMS to emergency contacts + guardian phones, 2) Local alarm (max volume), 3) SQLite queue, 4) Display emergency numbers on screen. Currently only step 3 is implemented.

**Step 1: Add SMS fallback using url_launcher**

Since `telephony` package has platform issues, use `url_launcher` for `sms:` URI scheme (works cross-platform):

```dart
Future<void> _sendSOSSms({
  required String userName,
  required double latitude,
  required double longitude,
  required String tripName,
  required List<String> phoneNumbers,
}) async {
  final message = '[SafeTrip SOS] $userName이 긴급 도움을 요청합니다. '
      '위치: $latitude,$longitude | 여행: $tripName';
  for (final phone in phoneNumbers) {
    final uri = Uri.parse('sms:$phone?body=${Uri.encodeComponent(message)}');
    try {
      await launchUrl(uri);
    } catch (e) {
      debugPrint('[SOS] SMS 발송 실패 ($phone): $e');
    }
  }
}
```

**Step 2: Add local alarm**

Use `flutter_local_notifications` (already in pubspec) for persistent notification with alarm sound:

```dart
Future<void> _playLocalAlarm() async {
  // Use system default alarm channel with max importance
  final flnp = FlutterLocalNotificationsPlugin();
  const androidDetails = AndroidNotificationDetails(
    'sos_alarm', 'SOS 알람',
    importance: Importance.max,
    priority: Priority.max,
    playSound: true,
    sound: RawResourceAndroidNotificationSound('alarm'),
    ongoing: true,
  );
  await flnp.show(9999, 'SOS 긴급 알람', '긴급 도움 요청이 활성화되었습니다',
    const NotificationDetails(android: androidDetails));
}
```

**Step 3: Integrate into SOS offline flow**

In `sendSOS()`, when offline:
```dart
if (isOffline) {
  // 1순위: SMS 발송
  final emergencyContacts = await _getEmergencyPhones();
  if (emergencyContacts.isNotEmpty) {
    await _sendSOSSms(
      userName: userName, latitude: latitude, longitude: longitude,
      tripName: tripId, phoneNumbers: emergencyContacts,
    );
  }
  // 2순위: 로컬 알람
  await _playLocalAlarm();
  // 3순위: SQLite 큐잉
  await offlineSyncService.pushSOS(...);
  // 4순위: 긴급 연락처 표시는 caller (SOS overlay)에서 처리
  return true;
}
```

**Step 4: Add emergency phone retrieval from local cache**

```dart
Future<List<String>> _getEmergencyPhones() async {
  final cache = await offlineSyncService.getCacheMeta('emergency_contacts_$tripId');
  if (cache == null) return [];
  // Parse JSON list of phone numbers
  final data = jsonDecode(cache['data'] as String);
  return List<String>.from(data['phones'] ?? []);
}
```

**Step 5: Verify & Commit**

```bash
git add lib/services/sos_service.dart pubspec.yaml
git commit -m "feat(offline): add SOS SMS fallback and local alarm (§3.2)"
```

---

### Task 8: Emergency Contacts + Safety Guide Caching (P0)

**Files:**
- Create: `lib/services/emergency_cache_service.dart`
- Modify: `lib/services/offline_sync_service.dart` (use cache meta methods)

**Context:**
Emergency contacts and safety guide data must be cached locally for offline access. Cache on trip activation, refresh on online session start. Use `local_cache_meta` table from Task 3.

**Step 1: Create emergency_cache_service.dart**

```dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'api_service.dart';
import 'offline_sync_service.dart';

/// 긴급 연락처 및 안전가이드 로컬 캐싱 서비스 (오프라인 원칙 §3.1)
class EmergencyCacheService {
  EmergencyCacheService({
    required this.apiService,
    required this.offlineSyncService,
  });
  final ApiService apiService;
  final OfflineSyncService offlineSyncService;

  /// 여행 활성화 시 긴급 데이터 캐싱
  Future<void> cacheForTrip(String tripId, String countryCode) async {
    await Future.wait([
      _cacheEmergencyContacts(tripId),
      _cacheSafetyGuide(countryCode),
    ]);
  }

  /// 긴급 연락처 캐싱
  Future<void> _cacheEmergencyContacts(String tripId) async {
    try {
      final contacts = await apiService.getEmergencyContacts(tripId);
      if (contacts != null) {
        await offlineSyncService.setCacheMeta(
          cacheKey: 'emergency_contacts_$tripId',
          data: jsonEncode(contacts),
        );
      }
    } catch (e) {
      debugPrint('[EmergencyCache] 긴급 연락처 캐싱 실패: $e');
    }
  }

  /// 안전가이드 캐싱
  Future<void> _cacheSafetyGuide(String countryCode) async {
    try {
      final guide = await apiService.getSafetyGuide(countryCode);
      if (guide != null) {
        await offlineSyncService.setCacheMeta(
          cacheKey: 'safety_guide_$countryCode',
          data: jsonEncode(guide),
        );
      }
    } catch (e) {
      debugPrint('[EmergencyCache] 안전가이드 캐싱 실패: $e');
    }
  }

  /// 캐시된 긴급 연락처 읽기
  Future<Map<String, dynamic>?> getCachedEmergencyContacts(String tripId) async {
    final meta = await offlineSyncService.getCacheMeta('emergency_contacts_$tripId');
    if (meta == null) return null;
    return jsonDecode(meta['data'] as String) as Map<String, dynamic>;
  }

  /// 캐시된 안전가이드 읽기
  Future<Map<String, dynamic>?> getCachedSafetyGuide(String countryCode) async {
    final meta = await offlineSyncService.getCacheMeta('safety_guide_$countryCode');
    if (meta == null) return null;
    return jsonDecode(meta['data'] as String) as Map<String, dynamic>;
  }
}
```

**Step 2: Verify & Commit**

```bash
git add lib/services/emergency_cache_service.dart
git commit -m "feat(offline): add emergency contacts and safety guide caching (§3.1)"
```

---

### Task 9: Battery-aware GPS Intervals (§7)

**Files:**
- Create: `lib/services/battery_gps_manager.dart`
- Modify: `lib/services/location_service.dart` (integrate battery manager)

**Context:**
GPS collection interval should change based on: (1) privacy level, (2) network state, (3) battery level. Per §7.1 and §7.3:
- Safety-first: online 30s, offline 5min
- Standard: online 60s, offline 5min
- Privacy-first: online 5min, offline 10min
- Battery <20%: 2x interval, <10%: 4x, <5%: SOS-only

**Step 1: Create battery_gps_manager.dart**

```dart
import 'package:flutter/foundation.dart';

/// 배터리 인식 GPS 주기 관리 (오프라인 원칙 §7)
class BatteryGpsManager {
  /// GPS 주기 계산 (초)
  static int calculateInterval({
    required String privacyLevel, // 'safety_first', 'standard', 'privacy_first'
    required bool isOffline,
    required int batteryLevel,
    required bool isSosActive,
  }) {
    // SOS 활성 중 (§7.1)
    if (isSosActive) {
      return isOffline ? 30 : 10;
    }

    // 기본 주기 (§7.1 매트릭스)
    int baseInterval;
    switch (privacyLevel) {
      case 'safety_first':
        baseInterval = isOffline ? 300 : 30; // 5min / 30s
        break;
      case 'standard':
        baseInterval = isOffline ? 300 : 60; // 5min / 60s
        break;
      case 'privacy_first':
        baseInterval = isOffline ? 600 : 300; // 10min / 5min
        break;
      default:
        baseInterval = isOffline ? 300 : 60;
    }

    // 배터리 임계값 처리 (§7.3)
    if (batteryLevel < 5) {
      return baseInterval * 4; // SOS 대기 모드
    } else if (batteryLevel < 10) {
      return baseInterval * 4;
    } else if (batteryLevel < 20) {
      return baseInterval * 2;
    }

    return baseInterval;
  }
}
```

**Step 2: Integrate into location_service.dart**

In the location service's configuration/update method, call `BatteryGpsManager.calculateInterval()` and update the background geolocation interval when conditions change.

**Step 3: Verify & Commit**

```bash
git add lib/services/battery_gps_manager.dart lib/services/location_service.dart
git commit -m "feat(offline): add battery-aware GPS interval management (§7)"
```

---

### Task 10: Schedule Draft + Conflict Resolution (§5.4, §6)

**Files:**
- Modify: `lib/services/offline_sync_service.dart` (schedule draft methods)

**Context:**
Offline schedule editing stores drafts locally. On sync, compare `updated_at` with server. If server version is newer → conflict. Show dialog asking user to choose.

**Step 1: Add schedule draft methods**

```dart
Future<void> pushScheduleDraft({
  String? scheduleId,
  required String tripId,
  required String action, // 'create', 'update', 'delete'
  required String payload, // JSON
}) async {
  final db = await database;
  await db.insert(_tableScheduleDraft, {
    'schedule_id': scheduleId,
    'trip_id': tripId,
    'action': action,
    'payload': payload,
    'is_synced': 0,
    'conflict_status': 'pending',
  });
}

Future<List<Map<String, dynamic>>> getPendingScheduleDrafts() async {
  final db = await database;
  return db.query(
    _tableScheduleDraft,
    where: 'is_synced = 0',
    orderBy: 'created_at ASC',
  );
}

Future<List<Map<String, dynamic>>> getConflictedDrafts() async {
  final db = await database;
  return db.query(
    _tableScheduleDraft,
    where: "conflict_status = 'conflict'",
  );
}

Future<void> resolveConflict(int id, String resolution) async {
  final db = await database;
  if (resolution == 'keep_local') {
    await db.update(_tableScheduleDraft,
      {'conflict_status': 'resolved'},
      where: 'id = ?', whereArgs: [id]);
  } else {
    await db.delete(_tableScheduleDraft,
      where: 'id = ?', whereArgs: [id]);
  }
}
```

**Step 2: Add _syncScheduleDrafts to syncData**

```dart
Future<_StageResult> _syncScheduleDrafts(ApiService apiService) async {
  int synced = 0, failed = 0;
  try {
    final drafts = await getPendingScheduleDrafts();
    for (final draft in drafts) {
      if (draft['conflict_status'] == 'conflict') continue;

      try {
        // Check server version for conflict (§6.1)
        if (draft['action'] == 'update' && draft['schedule_id'] != null) {
          final serverVersion = await apiService.getScheduleUpdatedAt(
            draft['schedule_id'] as String);
          final localEditTime = draft['created_at'] as String;
          if (serverVersion != null &&
              DateTime.parse(serverVersion).isAfter(DateTime.parse(localEditTime))) {
            // Conflict detected — mark for user resolution
            await _markConflict(draft['id'] as int);
            failed++;
            continue;
          }
        }

        final success = await apiService.syncScheduleDraft(draft);
        if (success) {
          await markScheduleSynced(draft['id'] as int, 'resolved');
          synced++;
        } else {
          failed++;
        }
      } catch (e) {
        failed++;
      }
    }
  } catch (e) {
    debugPrint('[OfflineSync] 일정 동기화 에러: $e');
  }
  return _StageResult(synced: synced, failed: failed);
}
```

**Step 3: Verify & Commit**

```bash
git add lib/services/offline_sync_service.dart
git commit -m "feat(offline): add schedule draft queuing with conflict detection (§5.4, §6)"
```

---

### Task 11: Sync Completion Notifications (§4.2, §8.3)

**Files:**
- Modify: `lib/services/device_status_service.dart`
- Modify: `lib/screens/main/screen_main.dart` (show toast)

**Context:**
After sync completes: show toast "오프라인 중 {N}건의 데이터가 동기화되었습니다" on success, or "일부 데이터 동기화 실패. 재시도 중..." on partial failure.

**Step 1: Update DeviceStatusService to use SyncResult**

In `_initNetworkMonitoring()`, when reconnecting:

```dart
if (result != ConnectivityResult.none) {
  debugPrint('[DeviceStatusService] 네트워크 연결됨 -> 동기화 시도');
  final syncResult = await _offlineSyncService.syncData(_apiService);
  _lastSyncResult = syncResult;
  _syncResultController.add(syncResult);
}
```

Add a `StreamController<SyncResult>` that `screen_main.dart` can listen to.

**Step 2: Show toast in screen_main.dart**

Listen to the sync result stream and show a `SnackBar`:

```dart
if (syncResult.synced > 0 && !syncResult.hasFailures) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('오프라인 중 ${syncResult.synced}건의 데이터가 동기화되었습니다.')),
  );
} else if (syncResult.hasFailures) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('일부 데이터 동기화 실패. 재시도 중...')),
  );
}
```

**Step 3: Verify & Commit**

```bash
git add lib/services/device_status_service.dart lib/screens/main/screen_main.dart
git commit -m "feat(offline): add sync completion toast notifications (§4.2, §8.3)"
```

---

### Task 12: Feature-specific Offline Indicators (§8.2)

**Files:**
- Modify relevant bottom sheet / tab screens

**Context:**
Per §8.2:
- Chat: "⏳ 전송 대기 중" icon next to queued messages
- Real-time location: gray dashed border on member markers
- AI button: grayed out + "인터넷 연결 필요" tooltip
- Safety guide: "캐시 데이터 ({날짜} 기준)" banner

These are UI-only changes that read the `networkStateProvider`.

**Step 1: Add offline indicators to each feature screen**

For each screen that needs an indicator:
- Watch `networkStateProvider` from Riverpod
- Conditionally show the indicator when `!status.isOnline`

**Step 2: Verify & Commit**

```bash
git add <modified files>
git commit -m "feat(offline): add feature-specific offline indicators (§8.2)"
```

---

## Verification Checklist (from §13)

After all tasks, verify:

| # | Check | §  |
|---|-------|-----|
| 1 | Network states correctly transition: online → degraded (2 fails) → offline (3 fails) | §2.3 |
| 2 | Healthcheck runs every 30s, 5s timeout | §2.2 |
| 3 | Offline banner shows last sync time | §8.1 |
| 4 | Degraded banner shows "재시도 중" | §8.1 |
| 5 | SOS sends SMS when offline | §3.2 |
| 6 | SOS plays local alarm when offline | §3.2 |
| 7 | Location queue limited to 8,640 records | §3.3 |
| 8 | Location data older than 72h is evicted | §3.3 |
| 9 | Chat queue limited to 100 messages | §3.4 |
| 10 | Sync priority: SOS → Guardian → Location → Schedule → Chat → Events | §4 |
| 11 | Each sync stage independent (failure doesn't block next) | §4.1 |
| 12 | Sync toast shown on completion | §4.2 |
| 13 | GPS interval adjusts for privacy level + network state | §7.1 |
| 14 | GPS interval adjusts for battery level (<20%, <10%, <5%) | §7.3 |
| 15 | Emergency contacts accessible offline from local cache | §3.1 |
| 16 | Safety guide accessible offline from local cache | §3.1 |
| 17 | Schedule conflict detected and marked | §6.1 |
| 18 | `flutter analyze` reports no new errors | — |
