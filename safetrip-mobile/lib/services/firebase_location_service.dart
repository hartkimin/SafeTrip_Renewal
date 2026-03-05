import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

/// Firebase Realtime Database를 사용한 실시간 위치 공유 서비스
/// MQTT를 대체하여 더 간단하고 안정적인 실시간 위치 업데이트 제공
class FirebaseLocationService {
  factory FirebaseLocationService() => _instance;
  FirebaseLocationService._internal();
  static final FirebaseLocationService _instance =
      FirebaseLocationService._internal();

  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  // 캐시 필드 (realtime_locations 전체 데이터)
  Map<String, Map<String, dynamic>>? _cachedLocationData;
  String? _cachedGroupId;

  /// 좌표를 소수점 6자리로 반올림 (RTDB 저장용)
  /// GPS 정확도는 약 10cm 수준이므로 6자리면 충분
  double _roundCoordinate(double coordinate) {
    return double.parse(coordinate.toStringAsFixed(6));
  }

  /// 실시간 위치 업데이트 (MQTT 대체)
  ///
  /// groupId/userId 경로에 위치 정보를 저장
  /// 같은 그룹의 다른 사용자들이 실시간으로 변경사항을 받음
  Future<void> updateRealtimeLocation({
    required String groupId,
    required String userId,
    required String userName,
    required double latitude,
    required double longitude,
    double? accuracy,
    double? altitude,
    double? speed,
    double? heading,
    int? battery,
    bool? isCharging,
    String? activityType,
    bool? isRealMoving,
    String? appVersion,
    String? movementSessionId,
    String? movementSessionCreatedAt,
    String? currentGeofenceId,
    int? geofenceEnteredAt,
    bool? locationSharingEnabled,
    int? mockDetectedAt,
    double? lastLocationLatitude,
    double? lastLocationLongitude,
    int? lastLocationTimestamp,
  }) async {
    try {
      // 좌표를 소수점 6자리로 반올림 (RTDB 저장용)
      final roundedLatitude = _roundCoordinate(latitude);
      final roundedLongitude = _roundCoordinate(longitude);
      final roundedLastLocationLatitude = lastLocationLatitude != null
          ? _roundCoordinate(lastLocationLatitude)
          : null;
      final roundedLastLocationLongitude = lastLocationLongitude != null
          ? _roundCoordinate(lastLocationLongitude)
          : null;

      await _database
          .child('realtime_locations')
          .child(groupId)
          .child(userId)
          .set({
            'user_id': userId,
            'user_name': userName,
            'latitude': roundedLatitude,
            'longitude': roundedLongitude,
            if (accuracy != null) 'accuracy': accuracy,
            if (altitude != null) 'altitude': altitude,
            if (speed != null) 'speed': speed,
            if (heading != null) 'heading': heading,
            if (battery != null) 'battery': battery,
            if (isCharging != null) 'is_charging': isCharging,
            if (activityType != null) 'activity_type': activityType,
            if (isRealMoving != null) 'is_moving': isRealMoving,
            if (appVersion != null) 'app_version': appVersion,
            if (movementSessionId != null) 'movement_session_id': movementSessionId,
            if (movementSessionCreatedAt != null) 'movement_session_created_at': movementSessionCreatedAt,
            if (currentGeofenceId != null) 'current_geofence_id': currentGeofenceId,
            if (geofenceEnteredAt != null) 'geofence_entered_at': geofenceEnteredAt,
            if (locationSharingEnabled != null) 'location_sharing_enabled': locationSharingEnabled,
            if (mockDetectedAt != null) 'mock_detected_at': mockDetectedAt,
            'last_location_latitude': roundedLastLocationLatitude,
            'last_location_longitude': roundedLastLocationLongitude,
            'last_location_timestamp': lastLocationTimestamp,
            'timestamp': DateTime.now().millisecondsSinceEpoch,
            'updated_at': ServerValue.timestamp,
          });

      debugPrint('[Firebase] 실시간 위치 업데이트 성공: $userId');
    } catch (e) {
      debugPrint('[Firebase] 실시간 위치 업데이트 실패: $e');
      rethrow;
    }
  }

  /// 그룹 전체 위치 실시간 리스닝
  ///
  /// 그룹의 모든 사용자 위치를 한 번에 받음
  /// 초기 로드나 전체 동기화에 유용
  Stream<Map<String, dynamic>> listenGroupLocations(String groupId) {
    return _database.child('realtime_locations').child(groupId).onValue.map((
      event,
    ) {
      if (event.snapshot.value == null) return {};
      return Map<String, dynamic>.from(event.snapshot.value as Map);
    });
  }

  /// 특정 사용자 위치 변경만 리스닝 (효율적, 권장)
  ///
  /// 변경된 사용자만 받아서 해당 마커만 업데이트
  /// 성능 최적화에 유리
  Stream<Map<String, dynamic>> listenUserLocationChanges(String groupId) {
    return _database
        .child('realtime_locations')
        .child(groupId)
        .onChildChanged
        .map((event) {
          final userId = event.snapshot.key!;
          final location = Map<String, dynamic>.from(
            event.snapshot.value as Map,
          );
          return {userId: location};
        });
  }

  /// 사용자 위치 추가 감지 (새 멤버 추가 시)
  Stream<Map<String, dynamic>> listenUserLocationAdded(String groupId) {
    return _database
        .child('realtime_locations')
        .child(groupId)
        .onChildAdded
        .map((event) {
          final userId = event.snapshot.key!;
          final location = Map<String, dynamic>.from(
            event.snapshot.value as Map,
          );
          return {userId: location};
        });
  }

  /// 사용자 위치 제거 감지 (멤버 탈퇴 시)
  Stream<String> listenUserLocationRemoved(String groupId) {
    return _database
        .child('realtime_locations')
        .child(groupId)
        .onChildRemoved
        .map((event) => event.snapshot.key!);
  }

  /// 사용자 위치 삭제 (그룹 탈퇴/로그아웃 시)
  Future<void> removeUserLocation(String groupId, String userId) async {
    try {
      await _database
          .child('realtime_locations')
          .child(groupId)
          .child(userId)
          .remove();
      debugPrint('[Firebase] 사용자 위치 삭제: $userId');
    } catch (e) {
      debugPrint('[Firebase] 사용자 위치 삭제 실패: $e');
    }
  }

  /// 그룹 전체 위치 삭제 (그룹 해체 시)
  Future<void> removeGroupLocations(String groupId) async {
    try {
      await _database.child('realtime_locations').child(groupId).remove();
      debugPrint('[Firebase] 그룹 위치 전체 삭제: $groupId');
    } catch (e) {
      debugPrint('[Firebase] 그룹 위치 삭제 실패: $e');
    }
  }

  /// 사용자 설정 업데이트 (위치 업데이트 없이 상태만 변경)
  ///
  /// location_sharing_enabled 업데이트
  Future<void> updateUserSettings({
    required String groupId,
    required String userId,
    bool? locationSharingEnabled,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (locationSharingEnabled != null) {
        updates['location_sharing_enabled'] = locationSharingEnabled;
      }
      updates['updated_at'] = ServerValue.timestamp;

      await _database
          .child('realtime_locations')
          .child(groupId)
          .child(userId)
          .update(updates);

      debugPrint('[Firebase] 사용자 설정 업데이트 성공: $userId');
    } catch (e) {
      debugPrint('[Firebase] 사용자 설정 업데이트 실패: $e');
      rethrow;
    }
  }

  /// Mock 위치 감지 상태 업데이트
  ///
  /// mock_detected_at 업데이트
  Future<void> updateMockDetected({
    required String groupId,
    required String userId,
    int? mockDetectedAt,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (mockDetectedAt != null) {
        updates['mock_detected_at'] = mockDetectedAt;
      } else {
        updates['mock_detected_at'] = null;
      }
      updates['updated_at'] = ServerValue.timestamp;

      await _database
          .child('realtime_locations')
          .child(groupId)
          .child(userId)
          .update(updates);

      debugPrint('[Firebase] Mock 위치 감지 상태 업데이트 성공: $userId');
    } catch (e) {
      debugPrint('[Firebase] Mock 위치 감지 상태 업데이트 실패: $e');
      rethrow;
    }
  }

  /// 캐시 업데이트 메서드 (FirebaseLocationManager에서 호출)
  ///
  /// Stream으로 받은 전체 위치 데이터를 캐시에 저장
  /// 디바운싱 없이 즉시 업데이트하여 최신 데이터 보장
  void updateCache(String groupId, Map<String, dynamic> allLocations) {
    _cachedGroupId = groupId;
    _cachedLocationData = Map<String, Map<String, dynamic>>.from(
      allLocations.map((userId, data) => MapEntry(
        userId,
        Map<String, dynamic>.from(data as Map),
      )),
    );
    debugPrint('[Firebase] 위치 데이터 캐시 업데이트 완료: ${allLocations.length}명');
  }

  /// 캐시 조회 메서드 (내부용)
  Map<String, dynamic>? _getCachedLocationData(String groupId, String userId) {
    if (_cachedGroupId != groupId) return null;
    return _cachedLocationData?[userId];
  }

  /// 특정 사용자 위치 데이터 조회 (한 번만)
  ///
  /// RTDB에서 특정 사용자의 위치 데이터를 한 번만 조회
  /// 캐시를 우선 조회하고, 없으면 RTDB에서 조회
  /// 반환값: `Map<String, dynamic>?` (있으면 위치 데이터, 없으면 null)
  Future<Map<String, dynamic>?> getUserLocation(
    String groupId,
    String userId,
  ) async {
    // 캐시 우선 조회
    final cachedData = _getCachedLocationData(groupId, userId);
    if (cachedData != null) {
      debugPrint('[Firebase] 캐시에서 위치 데이터 조회: $userId');
      return cachedData;
    }

    // 캐시에 없으면 RTDB 조회
    try {
      debugPrint('[Firebase] RTDB에서 위치 데이터 조회: $userId');
      final snapshot = await _database
          .child('realtime_locations')
          .child(groupId)
          .child(userId)
          .once();
      if (snapshot.snapshot.value == null) {
        return null;
      }
      return Map<String, dynamic>.from(
        snapshot.snapshot.value as Map,
      );
    } catch (e) {
      debugPrint('[Firebase] 사용자 위치 조회 실패: $e');
      return null;
    }
  }

  /// 사용자별 movement_session_id 조회
  ///
  /// Firebase Realtime DB에서 특정 사용자의 현재 이동 세션 ID를 조회
  /// 캐시를 우선 조회하고, 없으면 RTDB에서 조회
  /// 반환값: String? (있으면 세션 ID, 없으면 null)
  Future<String?> getUserMovementSessionId(String groupId, String userId) async {
    // 캐시에서 movement_session_id 추출
    final cachedData = _getCachedLocationData(groupId, userId);
    if (cachedData != null) {
      final sessionId = cachedData['movement_session_id'] as String?;
      debugPrint('[Firebase] 캐시에서 movement_session_id 조회: $userId = $sessionId');
      return sessionId;
    }

    // 캐시에 없으면 RTDB 조회
    try {
      debugPrint('[Firebase] RTDB에서 movement_session_id 조회: $userId');
      final snapshot = await _database
          .child('realtime_locations')
          .child(groupId)
          .child(userId)
          .child('movement_session_id')
          .once();
      return snapshot.snapshot.value as String?;
    } catch (e) {
      debugPrint('[Firebase] movement_session_id 조회 실패: $e');
      return null; // 실패 시 null 반환 → is_completed = true
    }
  }

  /// updated_at만 업데이트 (위치 정보 변경 없이 온라인 상태 유지)
  ///
  /// 위치 정보를 변경하지 않고 updated_at 필드만 업데이트하여
  /// 사용자의 온라인 상태를 지속적으로 유지합니다.
  Future<void> updateUpdatedAt({
    required String groupId,
    required String userId,
  }) async {
    try {
      await _database
          .child('realtime_locations')
          .child(groupId)
          .child(userId)
          .update({
            'updated_at': ServerValue.timestamp,
          });

      debugPrint('[Firebase] updated_at 업데이트 성공: $userId');
    } catch (e) {
      debugPrint('[Firebase] updated_at 업데이트 실패: $e');
      rethrow;
    }
  }
}
