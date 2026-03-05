import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/event_types.dart';
import '../constants/location_config.dart';
import '../models/location.dart' as location_model;
import '../services/api_service.dart';
import '../services/firebase_geofence_service.dart';
import '../services/firebase_location_service.dart';
import '../utils/app_cache.dart';
import '../utils/guardian_filter.dart';

/// Firebase 위치 데이터 관리 및 업데이트를 담당하는 Manager 클래스
class FirebaseLocationManager {

  FirebaseLocationManager({
    required this.onUsersUpdated,
    required this.onUserLocationsUpdated,
    required this.onOriginalPositionsUpdated,
    required this.onSelectedUserLocationUpdated,
    required this.onPathUpdateDataReady,
    required this.onMarkerUpdateRequested,
    required this.onUserMarkerUpdateRequested,
    required this.onLocationTextRequested,
    required this.isMounted,
    required this.calculateDistance,
  });
  // 상태
  Map<String, dynamic>? _lastFirebaseData;
  StreamSubscription<Map<String, dynamic>>? _firebaseLocationSubscription;
  Timer? _firebaseUpdateTimer;
  bool _isDisposed = false; // dispose 상태 플래그
  Map<String, bool>? _cachedUserPermissions; // 권한 정보 캐시 (초기 로딩 시 한 번만 가져옴)
  final Map<String, bool> _userOnlineStatus = {}; // 사용자별 이전 온라인 상태 저장

  final List<Map<String, dynamic>> _users = [];
  final Map<String, location_model.Location> _userLocations = {};

  List<Map<String, dynamic>> get users => _users;
  Map<String, location_model.Location> get userLocations => _userLocations;

  // 콜백 함수들
  final Function(List<Map<String, dynamic>>) onUsersUpdated;
  final Function(Map<String, location_model.Location>) onUserLocationsUpdated;
  final Function(Map<String, LatLng>) onOriginalPositionsUpdated;
  final Function(String?, location_model.Location?)
  onSelectedUserLocationUpdated;
  final Function(List<Map<String, dynamic>>?) onPathUpdateDataReady;
  final Function() onMarkerUpdateRequested;
  final Function(location_model.Location) onUserMarkerUpdateRequested;
  final Function(String, double, double) onLocationTextRequested;
  final bool Function() isMounted;

  // 거리 계산 함수 (외부에서 주입)
  final double Function(LatLng, LatLng) calculateDistance;

  // 선택된 사용자 및 세션 정보 (경로 업데이트용)
  String? selectedUserId;
  String? currentOngoingSessionId;
  Map<String, dynamic>? userOngoingSession;

  /// Firebase Stream 구독
  Future<void> subscribeStreams() async {
    final groupId = await AppCache.groupId;
    if (groupId == null) {
      debugPrint('[Firebase] group_id 없음 - Firebase 구독 중단');
      return;
    }

    // 초기 로딩 시 권한 정보 가져오기
    await _loadUserPermissions(groupId);

    final firebaseLocationService = FirebaseLocationService();

    // 전체 그룹 위치 리스닝 (초기 + 변경 모두)
    _firebaseLocationSubscription = firebaseLocationService
        .listenGroupLocations(groupId)
        .listen(
          (allLocations) {
            if (!isMounted()) return;

            debugPrint('[Firebase] RTDB 업데이트 수신: ${allLocations.length}개 사용자');

            // Throttling 제거 - 모든 데이터 받음 (isMoving, battery 등 즉시 반영)
            // 디바운싱만 적용: 1000ms 이내의 연속 업데이트는 마지막만 처리
            _firebaseUpdateTimer?.cancel();
            _firebaseUpdateTimer = Timer(
              const Duration(milliseconds: 1000),
              () {
                if (isMounted()) {
                  debugPrint(
                    '[Firebase] RTDB 데이터 처리 시작: ${allLocations.length}개',
                  );
                  updateAllUsers(allLocations);
                }
              },
            );
          },
          onError: (error) {
            debugPrint('[Firebase] ❌ RTDB 리스너 에러: $error');
            debugPrint('[Firebase] 스택 트레이스: ${StackTrace.current}');
          },
        );

    debugPrint('[Firebase] 실시간 위치 리스너 등록 완료: groupId=$groupId');
  }

  /// 권한 정보 로드 (초기 로딩 시 한 번만 호출)
  Future<void> _loadUserPermissions(String groupId) async {
    if (_cachedUserPermissions != null) {
      // 이미 로드된 경우 스킵
      debugPrint('[FirebaseLocationManager] 권한 정보 이미 로드됨 - 스킵');
      return;
    }

    debugPrint('[FirebaseLocationManager] 권한 정보 로드 시작 (DB에서 가져오기 - 현재 사용자만)');
    Map<String, bool> userPermissions = {};
    try {
      final apiService = ApiService();
      final cachedGroupId = await AppCache.groupId ?? groupId;
      final currentUserId = await AppCache.userId;

      debugPrint(
        '[FirebaseLocationManager] groupId: $cachedGroupId, currentUserId: $currentUserId',
      );

      if (currentUserId == null) {
        debugPrint(
          '[FirebaseLocationManager] currentUserId가 null - 권한 정보 로드 실패',
        );
        _cachedUserPermissions = {};
        return;
      }

      debugPrint('[FirebaseLocationManager] getMyPermission API 호출 시작');
      final permission = await apiService.getMyPermission(cachedGroupId);

      if (permission != null) {
        final canViewAll =
            permission['can_view_all_locations'] as bool? ?? false;
        userPermissions[currentUserId] = canViewAll;
        debugPrint(
          '[FirebaseLocationManager] 현재 사용자 권한: userId=$currentUserId, can_view_all_locations=$canViewAll',
        );
      } else {
        debugPrint('[FirebaseLocationManager] 권한 정보를 가져올 수 없음');
        userPermissions[currentUserId] = false;
      }

      _cachedUserPermissions = userPermissions;
      debugPrint(
        '[FirebaseLocationManager] 권한 정보 로드 완료: ${userPermissions.length}명 (현재 사용자만)',
      );
      debugPrint('[FirebaseLocationManager] 권한 정보 캐시 저장 완료');
    } catch (e, stackTrace) {
      debugPrint('[FirebaseLocationManager] 권한 정보 가져오기 실패: $e');
      debugPrint('[FirebaseLocationManager] 스택 트레이스: $stackTrace');
      // 실패 시 빈 맵 사용
      _cachedUserPermissions = {};
    }
  }

  /// Firebase 데이터 변경 감지
  bool detectDataChanges(Map<String, dynamic> allLocations) {
    if (_lastFirebaseData == null) {
      return true; // 첫 업데이트는 항상 변경으로 간주
    }

    // 사용자 수가 변경되었는지 확인
    if (_lastFirebaseData!.length != allLocations.length) {
      return true;
    }

    // 각 사용자의 위치가 변경되었는지 확인
    for (final entry in allLocations.entries) {
      final userId = entry.key;
      final newLocation = entry.value;

      if (!_lastFirebaseData!.containsKey(userId)) {
        return true;
      }

      final oldLocation = _lastFirebaseData![userId];

      // null 체크 추가
      final oldLatValue = oldLocation['latitude'];
      final oldLngValue = oldLocation['longitude'];
      final newLatValue = newLocation['latitude'];
      final newLngValue = newLocation['longitude'];

      // null이거나 타입이 맞지 않으면 변경으로 간주
      if (oldLatValue == null ||
          oldLngValue == null ||
          newLatValue == null ||
          newLngValue == null) {
        return true;
      }

      final oldLat = (oldLatValue as num).toDouble();
      final oldLng = (oldLngValue as num).toDouble();
      final newLat = (newLatValue as num).toDouble();
      final newLng = (newLngValue as num).toDouble();

      // 위치가 distanceFilter 이상 변경되었을 때만 업데이트
      final distance = calculateDistance(
        LatLng(oldLat, oldLng),
        LatLng(newLat, newLng),
      );
      if (distance > LocationConfig.distanceFilter) {
        return true;
      }

      // 위치가 변하지 않아도 다른 필드 변경 시 즉시 반영
      final oldTimestamp = oldLocation['timestamp'] as int?;
      final oldUpdatedAt = oldLocation['updated_at'] as int?;
      final oldBattery = oldLocation['battery'] as int?;
      final oldActivityType = oldLocation['activity_type'] as String?;
      final oldIsCharging = oldLocation['is_charging'] as bool?;
      final oldIsMoving = oldLocation['is_moving'] as bool?;

      final newTimestamp = newLocation['timestamp'] as int?;
      final newUpdatedAt = newLocation['updated_at'] as int?;
      final newBattery = newLocation['battery'] as int?;
      final newActivityType = newLocation['activity_type'] as String?;
      final newIsCharging = newLocation['is_charging'] as bool?;
      final newIsMoving = newLocation['is_moving'] as bool?;

      if (oldTimestamp != newTimestamp ||
          oldUpdatedAt != newUpdatedAt ||
          oldBattery != newBattery ||
          oldActivityType != newActivityType ||
          oldIsCharging != newIsCharging ||
          oldIsMoving != newIsMoving) {
        return true;
      }
    }

    return false;
  }

  /// 그룹 멤버 조회
  Future<List<Map<String, dynamic>>> _getGroupMembers(String groupId) async {
    try {
      final apiService = ApiService();
      final members = await apiService.getGroupMembers(groupId);
      debugPrint(
        '[FirebaseLocationManager] 그룹 멤버 목록 조회 완료: ${members.length}명',
      );
      return members;
    } catch (e) {
      debugPrint('[FirebaseLocationManager] 그룹 멤버 조회 실패: $e');
      return [];
    }
  }

  /// RTDB 위치 정보와 멤버 정보 병합
  Future<Map<String, dynamic>> _mergeLocationDataWithMembers(
    List<Map<String, dynamic>> members,
    Map<String, dynamic> allLocations,
    String groupId,
  ) async {
    final List<Map<String, dynamic>> mergedUsers = [];
    final Map<String, location_model.Location> tempUserLocations = {};
    final Map<String, LatLng> tempOriginalPositions = {};

    debugPrint(
      '[FirebaseLocationManager] _mergeLocationDataWithMembers: members=${members.length}명, allLocations=${allLocations.keys.length}개',
    );

    // members는 이미 필터링된 리스트 (보호자 제외, 보호대상만 포함)
    for (final member in members) {
      final userId = member['user_id'] as String;
      final isGuardian = member['is_guardian'] == true ||
          member['member_role'] == 'guardian';

      // 보호자는 절대 포함되지 않아야 함 (안전장치)
      if (isGuardian) {
        debugPrint(
          '[FirebaseLocationManager] ❌ 경고: 보호자가 members에 포함됨! userId=$userId (제외 처리)',
        );
        continue;
      }

      final locationDataRaw = allLocations[userId];
      final locationData = locationDataRaw != null
          ? Map<String, dynamic>.from(locationDataRaw as Map)
          : null;

      debugPrint(
        '[FirebaseLocationManager] 멤버 위치 병합: userId=$userId (보호대상), locationData=${locationData != null ? "있음" : "없음"}',
      );

      // 멤버 기본 정보
      final mergedUser = Map<String, dynamic>.from(member);

      // user_name 설정 (RTDB에 없으면 API의 display_name 사용)
      if (!mergedUser.containsKey('user_name')) {
        mergedUser['user_name'] = member['display_name'] as String? ?? '';
      }

      // RTDB 위치 정보 병합
      if (locationData != null) {
        mergedUser.addAll({
          'user_name':
              locationData['user_name'] as String? ??
              member['display_name'] as String? ??
              '',
          'battery_level': locationData['battery'],
          'last_activity_type': locationData['activity_type'],
          'last_battery_is_charging': locationData['is_charging'],
          'app_version': locationData['app_version'],
          'current_geofence_id': locationData['current_geofence_id'],
          'geofence_entered_at': locationData['geofence_entered_at'],
          'movement_session_id': locationData['movement_session_id'],
          'movement_session_created_at':
              locationData['movement_session_created_at'],
          'location_sharing_enabled': locationData['location_sharing_enabled'],
          'mock_detected_at': locationData['mock_detected_at'],
        });

        // Location 객체 생성
        final latValue = locationData['latitude'];
        final lngValue = locationData['longitude'];

        // null 체크: latitude와 longitude가 없으면 Location 객체 생성하지 않음
        if (latValue != null && lngValue != null) {
          final lat = (latValue as num).toDouble();
          final lng = (lngValue as num).toDouble();
          final speed = locationData['speed'] != null
              ? (locationData['speed'] as num).toDouble()
              : null;
          final timestamp = locationData['timestamp'] as int?;
          final updatedAt = locationData['updated_at'] as int?;
          final timeValue =
              updatedAt ?? timestamp ?? DateTime.now().millisecondsSinceEpoch;

          final isMoving = locationData['is_moving'] as bool?;
          debugPrint(
            '[RTDB] userId=$userId isMoving=$isMoving '
            'activityType=${locationData['activity_type']} '
            'pos=($lat, $lng)',
          );

          tempUserLocations[userId] = location_model.Location(
            userId: userId,
            userName:
                locationData['user_name'] as String? ??
                member['display_name'] as String? ??
                '',
            latitude: lat,
            longitude: lng,
            battery: locationData['battery'] as int?,
            speed: speed,
            timestamp: DateTime.fromMillisecondsSinceEpoch(
              timeValue,
              isUtc: true,
            ),
            updatedAt: updatedAt,
            activityType: locationData['activity_type'] as String?,
            isMoving: isMoving,
          );

          tempOriginalPositions[userId] = LatLng(lat, lng);
          debugPrint(
            '[FirebaseLocationManager] ✅ 위치 추가: userId=$userId, pos=($lat, $lng)',
          );
        } else {
          debugPrint(
            '[FirebaseLocationManager] ❌ 위치 정보 없음: userId=$userId (lat=$latValue, lng=$lngValue)',
          );
        }
      } else {
        debugPrint(
          '[FirebaseLocationManager] ❌ RTDB 위치 데이터 없음: userId=$userId',
        );
      }

      mergedUsers.add(mergedUser);
    }

    debugPrint(
      '[FirebaseLocationManager] 병합 완료: users=${mergedUsers.length}명, locations=${tempUserLocations.length}개, positions=${tempOriginalPositions.length}개',
    );

    return {
      'usersWithGeofence': mergedUsers,
      'tempUserLocations': tempUserLocations,
      'tempOriginalPositions': tempOriginalPositions,
    };
  }

  /// 사용자 위치 데이터 처리
  Future<Map<String, dynamic>> processUserLocationData(
    List<Map<String, dynamic>> usersWithLocation,
    Map<String, location_model.Location> tempUserLocations,
    Map<String, LatLng> tempOriginalPositions,
    String groupId,
    Map<String, bool> userPermissions,
  ) async {
    final List<Map<String, dynamic>> usersWithGeofence = [];
    final firebaseGeofenceService = FirebaseGeofenceService();

    // 현재 사용자(보는 사람)의 can_view_all_locations 권한 확인
    final currentUserId = await AppCache.userId;
    final currentUserCanViewAll = currentUserId != null
        ? (userPermissions[currentUserId] ?? false)
        : false;

    for (final user in usersWithLocation) {
      final userId = user['user_id'] as String?;
      if (userId == null) continue;

      final currentGeofenceId = user['current_geofence_id'] as String?;
      String? geofenceName;

      // 지오펜스 정보 조회
      if (currentGeofenceId != null) {
        try {
          final geofence = await firebaseGeofenceService.getGeofenceById(
            groupId,
            currentGeofenceId,
          );
          geofenceName = geofence?.name;
        } catch (e) {
          debugPrint(
            '[FirebaseLocationManager] 지오펜스 조회 실패 ($currentGeofenceId): $e',
          );
        }
      }

      // 지오펜스 정보 추가
      final userWithGeofence = Map<String, dynamic>.from(user);
      userWithGeofence['geofence_name'] = geofenceName;
      userWithGeofence['can_view_all_locations'] =
          currentUserCanViewAll; // 현재 사용자(보는 사람)의 권한

      usersWithGeofence.add(userWithGeofence);

      // 위치 정보가 있는 경우 역 지오코딩 수행
      if (tempUserLocations.containsKey(userId)) {
        final location = tempUserLocations[userId]!;
        onLocationTextRequested(userId, location.latitude, location.longitude);
      }
    }

    return {
      'usersWithGeofence': usersWithGeofence,
      'tempUserLocations': tempUserLocations,
      'tempOriginalPositions': tempOriginalPositions,
    };
  }

  /// 경로 업데이트 데이터 준비
  List<Map<String, dynamic>>? preparePathUpdateData(
    Map<String, dynamic> locationData,
    String userId,
  ) {
    if (userId != selectedUserId) {
      return null;
    }

    final lat = (locationData['latitude'] as num).toDouble();
    final lng = (locationData['longitude'] as num).toDouble();
    final speed = locationData['speed'] != null
        ? (locationData['speed'] as num).toDouble()
        : null;

    final timestamp = locationData['timestamp'] as int?;
    final updatedAt = locationData['updated_at'] as int?;
    final timeValue =
        timestamp ?? updatedAt ?? DateTime.now().millisecondsSinceEpoch;
    final recordedAt = DateTime.fromMillisecondsSinceEpoch(timeValue);

    // 이동중 세션의 end_location 업데이트 (리스트 주소 업데이트용)
    if (userOngoingSession != null &&
        userOngoingSession!['session_id'] == currentOngoingSessionId) {
      userOngoingSession!['end_location'] = {'latitude': lat, 'longitude': lng};
    }

    return [
      {
        'movement_session_id': currentOngoingSessionId,
        'latitude': lat,
        'longitude': lng,
        'speed': speed,
        'recorded_at': recordedAt.toUtc().toIso8601String(),
        'accuracy': locationData['accuracy'],
        'altitude': locationData['altitude'],
        'heading': locationData['heading'],
        'battery_level': locationData['battery'],
        'activity_type': locationData['activity_type'],
      },
    ];
  }

  /// Firebase에서 전체 사용자 데이터 업데이트
  Future<void> updateAllUsers(Map<String, dynamic> allLocations) async {
    if (!isMounted()) return;

    // 변경 감지
    final hasChanged = detectDataChanges(allLocations);
    if (!hasChanged) {
      return;
    }

    // 마지막 데이터 저장
    _lastFirebaseData = Map<String, dynamic>.from(allLocations);

    // 그룹 ID 가져오기
    final prefs = await SharedPreferences.getInstance();
    final groupId =
        prefs.getString('group_id') ?? '00000000-0000-0000-0000-000000000002';

    // FirebaseLocationService 캐시 업데이트 (즉시 업데이트, 디바운싱 없음)
    // Stream으로 받은 최신 데이터를 캐시에 저장하여 다른 곳에서 즉시 사용 가능
    final firebaseLocationService = FirebaseLocationService();
    firebaseLocationService.updateCache(groupId, allLocations);

    // 개별 모드 + 진행 중 세션일 때 Firebase 데이터를 경로에 추가할지 여부
    final shouldUpdatePath =
        selectedUserId != null && currentOngoingSessionId != null;

    // API에서 그룹 멤버 목록 조회 (서버에서 이미 필터링됨)
    final members = await _getGroupMembers(groupId);
    if (members.isEmpty) {
      // 멤버가 없으면 빈 결과 반환
      onUsersUpdated([]);
      onUserLocationsUpdated({});
      onOriginalPositionsUpdated({});
      return;
    }

    // 클라이언트 측 추가 필터링 (안전장치) - 보호자 제외
    final filteredMembers = await GuardianFilter.filterMembersForGuardian(
      members,
    );

    debugPrint(
      '[FirebaseLocationManager] 필터링 결과: ${members.length}명 -> ${filteredMembers.length}명',
    );
    debugPrint(
      '[FirebaseLocationManager] filteredMembers 키: ${filteredMembers.map((m) => m['user_id'] as String?).toList()}',
    );

    // RTDB 위치 정보와 병합 (필터링된 멤버만 처리 - 보호자 제외)
    final mergedData = await _mergeLocationDataWithMembers(
      filteredMembers,
      allLocations,
      groupId,
    );

    // 권한 정보 사용 (초기 로딩 시 가져온 캐시 사용)
    final userPermissions = _cachedUserPermissions ?? {};

    // processUserLocationData 호출 (기존 로직 유지)
    final processedData = await processUserLocationData(
      mergedData['usersWithGeofence'] as List<Map<String, dynamic>>,
      mergedData['tempUserLocations'] as Map<String, location_model.Location>,
      mergedData['tempOriginalPositions'] as Map<String, LatLng>,
      groupId,
      userPermissions,
    );
    final usersWithGeofence =
        processedData['usersWithGeofence'] as List<Map<String, dynamic>>;
    final tempUserLocations =
        processedData['tempUserLocations']
            as Map<String, location_model.Location>;
    final tempOriginalPositions =
        processedData['tempOriginalPositions'] as Map<String, LatLng>;

    // 경로 업데이트 데이터 준비
    List<Map<String, dynamic>>? firebaseLocationForPath;
    if (shouldUpdatePath && selectedUserId != null) {
      final selectedUserLocation = allLocations[selectedUserId];
      if (selectedUserLocation != null) {
        // Firebase 데이터를 안전하게 Map<String, dynamic>으로 변환
        final locationData = Map<String, dynamic>.from(
          selectedUserLocation as Map,
        );
        firebaseLocationForPath = preparePathUpdateData(
          locationData,
          selectedUserId!,
        );
      }
    }

    // 콜백을 통해 상태 업데이트
    _users.clear();
    _users.addAll(usersWithGeofence);
    _userLocations.clear();
    _userLocations.addAll(tempUserLocations);

    debugPrint(
      '[FirebaseLocationManager] 콜백 호출: users=${usersWithGeofence.length}명, locations=${tempUserLocations.length}개, positions=${tempOriginalPositions.length}개',
    );
    debugPrint(
      '[FirebaseLocationManager] tempOriginalPositions 키: ${tempOriginalPositions.keys.toList()}',
    );
    onUsersUpdated(usersWithGeofence);
    onUserLocationsUpdated(tempUserLocations);
    onOriginalPositionsUpdated(tempOriginalPositions);

    // 선택된 사용자의 위치 업데이트
    if (selectedUserId != null &&
        tempUserLocations.containsKey(selectedUserId)) {
      onSelectedUserLocationUpdated(
        selectedUserId,
        tempUserLocations[selectedUserId],
      );
    }

    // 마커 업데이트 요청
    onMarkerUpdateRequested();

    // 개별 모드일 때 선택된 사용자 마커 업데이트
    if (selectedUserId != null &&
        tempOriginalPositions.containsKey(selectedUserId) &&
        tempUserLocations.containsKey(selectedUserId)) {
      final userLocation = tempUserLocations[selectedUserId];
      if (userLocation != null) {
        onUserMarkerUpdateRequested(userLocation);
      }
    }

    // 이동중 세션일 때 경로 업데이트 데이터 전달
    if (shouldUpdatePath && firebaseLocationForPath != null) {
      onPathUpdateDataReady(firebaseLocationForPath);
    }

    // 온라인/오프라인 상태 변화 감지 및 이벤트 저장 (현재 로그인한 사용자만)
    final currentUserId = await AppCache.userId;
    if (currentUserId != null && tempUserLocations.containsKey(currentUserId)) {
      _checkOnlineStatusChange(currentUserId, tempUserLocations[currentUserId]);
    }
  }

  /// 온라인/오프라인 상태 변화 감지 및 이벤트 저장
  void _checkOnlineStatusChange(
    String userId,
    location_model.Location? location,
  ) {
    final previousStatus = _userOnlineStatus[userId];

    // updated_at 기반으로 온라인 여부 판단
    bool isCurrentlyOnline = false;
    int? updatedAtMs;
    double? minutesSinceUpdate;

    if (location != null) {
      final timeValue =
          location.updatedAt ?? location.timestamp.millisecondsSinceEpoch;
      updatedAtMs = location.updatedAt;
      final now = DateTime.now().millisecondsSinceEpoch;
      minutesSinceUpdate = (now - timeValue) / 1000 / 60;
      isCurrentlyOnline =
          minutesSinceUpdate < LocationConfig.offlineThresholdMinutes;
    }

    // 상태 변화 감지
    if (previousStatus != null && previousStatus != isCurrentlyOnline) {
      final eventSubtype = isCurrentlyOnline
          ? DeviceStatusEventSubtypes.online
          : DeviceStatusEventSubtypes.offline;

      // 이벤트 저장 (비동기, 에러 무시)
      _saveOnlineStatusEvent(
        userId,
        location,
        eventSubtype,
        previousStatus,
        isCurrentlyOnline,
        updatedAtMs,
        minutesSinceUpdate,
      ).catchError((e) {
        debugPrint('[FirebaseLocationManager] 온라인 상태 이벤트 저장 실패: $e');
      });
    }

    // 현재 상태 저장
    _userOnlineStatus[userId] = isCurrentlyOnline;
  }

  /// 온라인 상태 이벤트 저장
  Future<void> _saveOnlineStatusEvent(
    String userId,
    location_model.Location? location,
    String eventSubtype,
    bool previousStatus,
    bool isCurrentlyOnline,
    int? updatedAtMs,
    double? minutesSinceUpdate,
  ) async {
    try {
      final apiService = ApiService();

      // 온라인/오프라인 상태만 기록 (최소한의 정보만 포함)
      final eventData = <String, dynamic>{
        'status': isCurrentlyOnline ? 'online' : 'offline',
      };

      await apiService.recordEvent(
        eventType: EventTypes.deviceStatus,
        eventSubtype: eventSubtype,
        eventData: eventData,
      );

      debugPrint(
        '[FirebaseLocationManager] 온라인 상태 이벤트 저장: userId=$userId, subtype=$eventSubtype',
      );
    } catch (e) {
      debugPrint('[FirebaseLocationManager] 온라인 상태 이벤트 저장 실패: $e');
      rethrow;
    }
  }

  /// Stream 구독 일시정지 (백그라운드 전환 시)
  void pauseStreams() {
    if (_isDisposed) return;
    try {
      _firebaseLocationSubscription?.pause();
      _firebaseUpdateTimer?.cancel();
      debugPrint('[FirebaseLocationManager] Stream 구독 일시정지');
    } catch (e) {
      debugPrint('[FirebaseLocationManager] Stream 일시정지 중 오류 (무시): $e');
    }
  }

  /// Stream 구독 재개 (포그라운드 복귀 시)
  void resumeStreams() {
    if (_isDisposed) return;
    try {
      _firebaseLocationSubscription?.resume();
      debugPrint('[FirebaseLocationManager] Stream 구독 재개');
    } catch (e) {
      debugPrint('[FirebaseLocationManager] Stream 재개 중 오류 (무시): $e');
    }
  }

  /// 리소스 정리
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;

    // Timer 정리
    try {
      _firebaseUpdateTimer?.cancel();
      _firebaseUpdateTimer = null;
    } catch (e) {
      debugPrint('[FirebaseLocationManager] Timer 정리 중 오류 (무시): $e');
    }

    // Stream 구독 정리 (MissingPluginException 방지)
    if (_firebaseLocationSubscription != null) {
      final subscription = _firebaseLocationSubscription;
      _firebaseLocationSubscription = null; // 먼저 null로 설정하여 중복 호출 방지

      // pause를 먼저 호출하여 스트림을 안전하게 중지
      try {
        subscription?.pause();
      } catch (e) {
        // pause 실패는 무시 (이미 정리된 경우)
        if (e is! MissingPluginException) {
          debugPrint('[FirebaseLocationManager] pause 중 예외 (무시): $e');
        }
      }

      // cancel 호출을 비동기로 처리하여 MissingPluginException이 앱에 영향을 주지 않도록 함
      // 네이티브 플러그인이 이미 정리된 경우 발생할 수 있는 정상적인 상황
      Future.delayed(const Duration(milliseconds: 100), () {
        try {
          subscription?.cancel();
        } catch (e) {
          // MissingPluginException은 정상적인 상황 (플러그인이 이미 정리됨)
          // 다른 예외만 로그 출력
          if (e is! MissingPluginException) {
            debugPrint('[FirebaseLocationManager] cancel 중 예외 (무시): $e');
          }
        }
      });
    }
  }
}
