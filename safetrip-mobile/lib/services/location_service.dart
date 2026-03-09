import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_geolocation/flutter_background_geolocation.dart'
    as bg;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:geocoding/geocoding.dart';
import 'api_service.dart';
import 'battery_gps_manager.dart';
import 'log_service.dart';
import 'firebase_location_service.dart';
import 'movement_detector.dart';
import 'device_status_service.dart';
import 'offline_sync_service.dart';
import '../constants/location_config.dart';
import '../constants/event_types.dart';
import '../utils/app_cache.dart';
import '../utils/location_cache.dart';

class LocationService {
  factory LocationService() => _instance;
  LocationService._internal();
  static final LocationService _instance = LocationService._internal();

  // 하트비트 스트림 추가
  StreamController<void>? _heartbeatController;
  Stream<void>? get heartbeatStream => _heartbeatController?.stream;

  // 배터리 레벨 스트림 (오프라인 원칙 §7.3 -- UI 배너 표시용)
  final StreamController<int> _batteryLevelController =
      StreamController<int>.broadcast();
  Stream<int> get batteryLevelStream => _batteryLevelController.stream;
  int? _lastBroadcastBatteryLevel;

  bool _isInitialized = false;
  bool _isTracking = false;

  // 마지막 위치 캐시 (하트비트 실패 시 사용)

  // 세션 타임아웃 타이머 (5분 킬 스위치)
  Timer? _sessionTimeoutTimer;

  // updated_at 업데이트 타이머
  Timer? _updatedAtTimer;

  // 이벤트 수집용 변수
  bg.Location? _lastLocation;
  final ApiService _apiService = ApiService();
  final DeviceStatusService _deviceStatusService = DeviceStatusService();

  // 배터리 인식 GPS 주기 캐시 (변경 시에만 setConfig 호출, §7)
  int? _lastGpsIntervalSeconds;

  // changePace 호출 중복 이벤트 방지 플래그 (static: 헤드리스/포어그라운드 인스턴스 간 공유)
  static bool _isChangePaceInProgress = false;

  // changePace로 인한 onLocation 이벤트 무시 카운터 (static: 헤드리스/포어그라운드 인스턴스 간 공유)
  static int changePaceEventCount = 0;

  // 세션 관리 락 (경쟁 조건 방지)
  bool _isSessionManagementInProgress = false;

  Future<void> initialize({String? userId}) async {
    if (_isInitialized) {
      debugPrint('[LocationService] 이미 초기화됨');
      return;
    }

    debugPrint('[LocationService] 초기화 시작... userId: ${userId ?? "null"}');
    _heartbeatController = StreamController<void>.broadcast();

    // ============================================================================
    // BackgroundGeolocation 설정
    // ============================================================================
    // 참고: 이 플러그인은 motion-detection 기반으로 작동합니다
    await bg.BackgroundGeolocation.ready(
      bg.Config(
        // 디버그 및 초기화 설정
        debug: LocationConfig.debug,
        reset: LocationConfig.reset,

        // HTTP 전송 설정
        params: userId != null ? {'user_id': userId} : {},

        // 위치 정확도 및 필터링
        desiredAccuracy: LocationConfig.desiredAccuracy,
        distanceFilter: LocationConfig.distanceFilter,
        disableElasticity: LocationConfig.disableElasticity,

        // 위치 업데이트 주기 (주석 처리됨, 필요시 사용)
        // locationUpdateInterval: LocationConfig.locationUpdateInterval,
        fastestLocationUpdateInterval:
            LocationConfig.fastestLocationUpdateInterval,

        // 지오펜스 설정
        geofenceModeHighAccuracy: LocationConfig.geofenceModeHighAccuracy,
        geofenceInitialTriggerEntry: LocationConfig.geofenceInitialTriggerEntry,
        geofenceProximityRadius: LocationConfig.geofenceProximityRadius,

        // 활동 인식 설정
        disableMotionActivityUpdates:
            LocationConfig.disableMotionActivityUpdates,
        activityRecognitionInterval: LocationConfig.activityRecognitionInterval,
        minimumActivityRecognitionConfidence:
            LocationConfig.minimumActivityRecognitionConfidence,

        // 정지 감지 설정
        pausesLocationUpdatesAutomatically:
            LocationConfig.pausesLocationUpdatesAutomatically,
        stopTimeout: LocationConfig.stopTimeout,
        disableStopDetection: LocationConfig.disableStopDetection,
        stationaryRadius: LocationConfig.stationaryRadius,

        // 백그라운드 및 앱 생명주기
        stopOnTerminate: LocationConfig.stopOnTerminate,
        startOnBoot: LocationConfig.startOnBoot,
        enableHeadless: LocationConfig.enableHeadless,

        // 하트비트 설정
        heartbeatInterval: LocationConfig.heartbeatInterval,

        // 데이터 저장 설정
        maxRecordsToPersist: LocationConfig.maxRecordsToPersist,

        // 로그 레벨
        logLevel: LocationConfig.logLevel,

        // 권한 안내 설정
        locationAuthorizationAlert: {
          'titleWhenNotEnabled': LocationConfig.locationAuthTitleWhenNotEnabled,
          'titleWhenOff': LocationConfig.locationAuthTitleWhenOff,
          'instructions': LocationConfig.locationAuthInstructions,
          'cancelButton': LocationConfig.locationAuthCancelButton,
          'settingsButton': LocationConfig.locationAuthSettingsButton,
        },

        // 알림 설정 (포어그라운드 서비스)
        notification: bg.Notification(
          title: LocationConfig.notificationTitle,
          text: LocationConfig.notificationText,
          channelName: LocationConfig.notificationChannelName,
          priority: LocationConfig.notificationPriority,
          smallIcon: LocationConfig.notificationSmallIcon,
        ),
      ),
    );

    // 위치 이벤트 리스너
    bg.BackgroundGeolocation.onLocation(_onLocation);

    // HEARTBEAT 이벤트 리스너 (포어그라운드용)
    bg.BackgroundGeolocation.onHeartbeat(_onHeartbeat);

    // 위치 권한 변경 리스너
    bg.BackgroundGeolocation.onProviderChange(_onProviderChange);

    // 이벤트 로깅용 리스너
    bg.BackgroundGeolocation.onActivityChange(_onActivityChange);
    bg.BackgroundGeolocation.onGeofence(_onGeofenceForLog);
    bg.BackgroundGeolocation.onGeofencesChange(_onGeofencesChange);

    // HTTP 전송 성공/실패 리스너
    bg.BackgroundGeolocation.onHttp((bg.HttpEvent event) {
      debugPrint('[HTTP] 상태=${event.status}');
      if (event.status >= 200 && event.status < 300) {
        debugPrint('[HTTP] 전송 성공: ${event.responseText}');
      } else {
        debugPrint('[HTTP] 전송 실패: ${event.status} - ${event.responseText}');
      }
    });

    _isInitialized = true;
    debugPrint('[LocationService] 초기화 완료');
  }

  // 앱 시작 시 프리퍼런스 확인 및 처리
  // location이 null이면 내부에서 위치를 가져오고, 제공되면 사용
  Future<void> _handleAppStartState({bg.Location? location}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // 앱이 포어그라운드로 돌아왔으므로 다음 헤드리스 전환을 위해 플래그 재설정
      await prefs.setBool('is_first_headless_location', true);

      final currentSessionId = prefs.getString('current_movement_session_id');
      final userId = await AppCache.userId;

      if (userId == null) return;

      // 위치가 제공되지 않았으면 가져오기
      if (location == null) {
        try {
          location = await bg.BackgroundGeolocation.getCurrentPosition(
            samples: 1,
            timeout: 5, // 타임아웃 단축 (10초 → 5초)
            extras: {'event': 'app_start'},
          );
        } catch (e) {
          debugPrint('[AppStart] 현재 위치 가져오기 실패: $e');
          return;
        }
      }

      // MovementDetector 상태 복원 (앱 재시작 시)
      final movementDetector = MovementDetector();
      if (currentSessionId != null) {
        // 세션이 있으면 이동 중으로 복원
        movementDetector.restoreState(
          true, // 이동 중
          location.coords.latitude,
          location.coords.longitude,
        );
        debugPrint('[AppStart] MovementDetector 상태 복원 - 이동 중');

        // 이동 중: 현재 위치 저장
        debugPrint('[AppStart] 이동 세션 활성화됨 - 위치 저장');

        // 현재 위치를 TB_LOCATION에 저장 (일반 저장)
        final apiService = ApiService();
        final batteryLevel = (location.battery.level * 100).toInt();

        // group_id 읽기
        final groupId = await AppCache.groupId;

        await apiService.saveLocation(
          userId: userId,
          latitude: location.coords.latitude,
          longitude: location.coords.longitude,
          accuracy: location.coords.accuracy,
          altitude: location.coords.altitude,
          speed: location.coords.speed,
          heading: location.coords.heading,
          batteryLevel: batteryLevel,
          movementSessionId: currentSessionId,
          activityType: location.activity.type,
          activityConfidence: location.activity.confidence,
          recordedAt: location.timestamp.toString(),
          groupId: groupId,
        );
        debugPrint('[AppStart] 현재 위치 저장 완료');
      } else {
        // 세션이 없으면 정지 상태로 시작 (MovementDetector는 첫 updateLocation() 호출 시 자동으로 false로 설정됨)
        debugPrint('[AppStart] 정지 상태');
      }
    } catch (e) {
      debugPrint('[AppStart] 앱 시작 상태 처리 실패: $e');
    }
  }

  void _onLocation(bg.Location location) async {
    // 백그라운드 작업 시작 (API 호출이 있으므로 필요)
    int? taskId;
    try {
      taskId = await bg.BackgroundGeolocation.startBackgroundTask();
    } catch (e) {
      debugPrint('[onLocation] startBackgroundTask 실패: $e');
    }

    try {
      debugPrint(
        '[onLocation] 위도=${location.coords.latitude.toStringAsFixed(6)}, 경도=${location.coords.longitude.toStringAsFixed(6)}, activity=${location.activity.type}, confidence=${location.activity.confidence}',
      );

      // mock 위치 체크 (최상단)
      if (location.mock == true) {
        debugPrint('[onLocation] Mock 위치 감지 - 위치 공유 비활성화 및 추적 중단');
        await setMockLocationDetected(true);

        // Mock 위치 감지 이벤트 수집
        await _apiService.recordEvent(
          eventType: EventTypes.deviceStatus,
          eventSubtype: DeviceStatusEventSubtypes.mockLocation,
          latitude: location.coords.latitude,
          longitude: location.coords.longitude,
          batteryLevel: _getBatteryLevel(location),
          batteryIsCharging: location.battery.isCharging,
          networkType: await _getNetworkType(),
          appVersion: await _getAppVersion(),
          eventData: {
            'mock_location': {'detected': true},
          },
        );

        await stopTracking();
        return;
      }

      // mock_location_detected 체크 (mock이 아닌 경우 자동 해제)
      final isMockDetected = await isMockLocationDetected();
      if (isMockDetected) {
        // 이전에 mock이었지만 지금은 mock이 아니면 해제
        debugPrint('[onLocation] Mock 위치 해제 - 정상 위치로 복구');
        await setMockLocationDetected(false);
      }

      // 위치 공유 체크 제거 - 백그라운드에서는 항상 위치 수집 및 저장 수행

      // onLocation 발생 경로 확인 (extras에서 event 타입 확인)
      String locationSource = 'normal'; // 기본값: 일반 location 이벤트
      bool isHeartbeat = false;

      if (location.extras != null && location.extras!['event'] != null) {
        final eventType = location.extras!['event'] as String?;
        switch (eventType) {
          case 'heartbeat':
            locationSource = 'heartbeat';
            isHeartbeat = true;
            break;
          case 'initial_heartbeat':
            locationSource = 'initial_heartbeat';
            isHeartbeat = true;
            break;
          case 'app_start':
            locationSource = 'app_start';
            break;
          case 'app_start_initial':
            locationSource = 'app_start_initial';
            break;
          default:
            locationSource = 'normal';
        }
      }

      // 세션 관리 (먼저 실행하여 세션 ID 생성/업데이트)
      await _manageSession(location);

      // TB_USER + 실시간 위치 업데이트 (세션 정보 포함)
      await _updateUserLocationRealtime(location).catchError((error) {
        debugPrint('[onLocation] TB_USER + 실시간 위치 업데이트 실패: $error');
      });

      // 위치 저장 (세션이 있으면)
      // 세션 확인: _manageSession에서 생성한 세션이 제대로 전달되는지 확인
      final prefsCheck = await SharedPreferences.getInstance();
      final sessionAfterManage = prefsCheck.getString(
        'current_movement_session_id',
      );
      debugPrint('[onLocation] _manageSession 후 세션 확인: $sessionAfterManage');

      await _manageLocation(location);

      // 로그 저장 (모든 가능한 정보 포함)
      try {
        // 현재 세션 ID 가져오기
        final prefs = await SharedPreferences.getInstance();
        final currentSessionId = prefs.getString('current_movement_session_id');

        // SQLite에 저장
        final logService = LogService();
        await logService.addLog('location', {
          'latitude': location.coords.latitude,
          'longitude': location.coords.longitude,
          'accuracy': location.coords.accuracy,
          'speed': location.coords.speed,
          'heading': location.coords.heading,
          'altitude': location.coords.altitude,
          'altitudeAccuracy': location.coords.altitudeAccuracy,
          'floor': location.coords.floor,
          'uuid': location.uuid,
          'event': location.event,
          'odometer': location.odometer,
          'activityType': location.activity.type,
          'activityConfidence': location.activity.confidence,
          'batteryLevel': _getBatteryLevel(location),
          'batteryIsCharging': location.battery.isCharging,
          'movementSessionId': isHeartbeat ? null : currentSessionId,
          'isHeartbeat': isHeartbeat,
          'locationSource': locationSource, // 발생 경로 추가
          'isMoving': location.isMoving,
        });
      } catch (e) {
        // 로그 저장 실패 시 무시
        debugPrint('[LocationService] 로그 저장 실패: $e');
      }

      // 이벤트 수집 (이동 상태 이벤트, 배터리 경고 등)
      // changePace로 인한 onLocation은 이벤트 수집 스킵 (다음 이벤트 1개만)
      final isChangePaceEvent = changePaceEventCount > 0;

      if (isChangePaceEvent) {
        changePaceEventCount--; // 카운터 감소
        debugPrint(
          '[onLocation] changePace로 인한 이벤트 - 이벤트 수집 스킵 (남은 카운트: $changePaceEventCount)',
        );
      } else {
        await _collectEvents(location);
      }

      // 배터리 인식 GPS 주기 동적 조정 (§7)
      await _updateGpsInterval(location);

      // 이전 위치 저장
      _lastLocation = location;
    } finally {
      // 백그라운드 작업 종료
      if (taskId != null) {
        bg.BackgroundGeolocation.stopBackgroundTask(taskId);
      }
    }
  }

  /// 이벤트 수집 (이동 상태 이벤트, 배터리 경고 등)
  Future<void> _collectEvents(bg.Location location) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentSessionId = prefs.getString('current_movement_session_id');

      // 배터리 경고 체크
      final batteryLevel = _getBatteryLevel(location);
      if (batteryLevel != null) {
        await _deviceStatusService.checkBatteryWarning(batteryLevel);

        // §7.3: UI 배너 표시를 위해 배터리 레벨 브로드캐스트
        if (batteryLevel != _lastBroadcastBatteryLevel) {
          _lastBroadcastBatteryLevel = batteryLevel;
          _batteryLevelController.add(batteryLevel);
        }
      }

      // 이동 상태 이벤트 체크 (세션이 있을 때만)
      if (currentSessionId != null && _lastLocation != null) {
        await _checkMovementEvents(location, currentSessionId);
      }
    } catch (e) {
      debugPrint('[LocationService] 이벤트 수집 실패: $e');
    }
  }

  /// 이동 상태 이벤트 체크 (급가속, 급감속, 과속, 방향 급변)
  Future<void> _checkMovementEvents(
    bg.Location location,
    String sessionId,
  ) async {
    try {
      if (_lastLocation == null) return;

      final timeDelta = (DateTime.parse(
        location.timestamp,
      ).difference(DateTime.parse(_lastLocation!.timestamp))).inSeconds;
      if (timeDelta <= 0) return;

      final previousSpeed = _lastLocation!.coords.speed;
      final currentSpeed = location.coords.speed;
      final speedDiff = currentSpeed - previousSpeed;

      // 급가속 체크 (3초 내 5m/s 이상 증가)
      if (timeDelta <= 3 && speedDiff >= 5.0) {
        final acceleration = speedDiff / timeDelta;
        await _apiService.recordEvent(
          eventType: EventTypes.sessionEvent,
          eventSubtype: SessionEventEventSubtypes.rapidAcceleration,
          movementSessionId: sessionId,
          latitude: location.coords.latitude,
          longitude: location.coords.longitude,
          batteryLevel: _getBatteryLevel(location),
          batteryIsCharging: location.battery.isCharging,
          networkType: await _getNetworkType(),
          appVersion: await _getAppVersion(),
          eventData: {
            'speed': {'previous': previousSpeed, 'current': currentSpeed},
            'acceleration': acceleration,
            'time_delta': timeDelta,
          },
        );
      }

      // 급감속 체크 (3초 내 5m/s 이상 감소)
      if (timeDelta <= 3 && speedDiff <= -5.0) {
        final deceleration = -speedDiff / timeDelta;
        await _apiService.recordEvent(
          eventType: EventTypes.sessionEvent,
          eventSubtype: SessionEventEventSubtypes.rapidDeceleration,
          movementSessionId: sessionId,
          latitude: location.coords.latitude,
          longitude: location.coords.longitude,
          batteryLevel: _getBatteryLevel(location),
          batteryIsCharging: location.battery.isCharging,
          networkType: await _getNetworkType(),
          appVersion: await _getAppVersion(),
          eventData: {
            'speed': {'previous': previousSpeed, 'current': currentSpeed},
            'deceleration': deceleration,
            'time_delta': timeDelta,
          },
        );
      }

      // 과속 체크 (33.3m/s = 120km/h 초과)
      const speedLimit = 33.3;
      if (currentSpeed > speedLimit) {
        final exceededBy = currentSpeed - speedLimit;
        await _apiService.recordEvent(
          eventType: EventTypes.sessionEvent,
          eventSubtype: SessionEventEventSubtypes.speeding,
          movementSessionId: sessionId,
          latitude: location.coords.latitude,
          longitude: location.coords.longitude,
          batteryLevel: _getBatteryLevel(location),
          batteryIsCharging: location.battery.isCharging,
          networkType: await _getNetworkType(),
          appVersion: await _getAppVersion(),
          eventData: {
            'speed': {'current': currentSpeed},
            'speed_limit': speedLimit,
            'exceeded_by': exceededBy,
          },
        );
      }
    } catch (e) {
      debugPrint('[LocationService] 이동 상태 이벤트 체크 실패: $e');
    }
  }

  /// 세션 시작 이벤트 수집
  Future<void> _recordSessionStartEvent(
    bg.Location location,
    String sessionId,
  ) async {
    try {
      final movementDetector = MovementDetector();
      final isRealMoving = movementDetector.currentState ?? location.isMoving;

      await _apiService.recordEvent(
        eventType: EventTypes.session,
        eventSubtype: SessionEventSubtypes.start,
        movementSessionId: sessionId,
        latitude: location.coords.latitude,
        longitude: location.coords.longitude,
        address: await _getAddress(
          location.coords.latitude,
          location.coords.longitude,
        ),
        batteryLevel: _getBatteryLevel(location),
        batteryIsCharging: location.battery.isCharging,
        networkType: await _getNetworkType(),
        appVersion: await _getAppVersion(),
        eventData: {
          'is_real_moving': isRealMoving,
          'activity': {
            'type': location.activity.type,
            'confidence': location.activity.confidence,
          },
        },
      );
    } catch (e) {
      debugPrint('[LocationService] 세션 시작 이벤트 수집 실패: $e');
    }
  }

  /// 세션 종료 이벤트 수집
  Future<void> _recordSessionEndEvent(
    bg.Location location,
    String sessionId,
  ) async {
    try {
      final movementDetector = MovementDetector();
      final isRealMoving = movementDetector.currentState ?? false;

      await _apiService.recordEvent(
        eventType: EventTypes.session,
        eventSubtype: SessionEventSubtypes.end,
        movementSessionId: sessionId,
        latitude: location.coords.latitude,
        longitude: location.coords.longitude,
        address: await _getAddress(
          location.coords.latitude,
          location.coords.longitude,
        ),
        batteryLevel: _getBatteryLevel(location),
        batteryIsCharging: location.battery.isCharging,
        networkType: await _getNetworkType(),
        appVersion: await _getAppVersion(),
        eventData: {'is_real_moving': isRealMoving},
      );
    } catch (e) {
      debugPrint('[LocationService] 세션 종료 이벤트 수집 실패: $e');
    }
  }

  /// 세션 킬 이벤트 수집 (타임아웃 종료)
  Future<void> _recordSessionKillEvent(
    bg.Location location,
    String sessionId,
  ) async {
    try {
      final movementDetector = MovementDetector();
      final isRealMoving = movementDetector.currentState ?? false;

      await _apiService.recordEvent(
        eventType: EventTypes.session,
        eventSubtype: SessionEventSubtypes.kill,
        movementSessionId: sessionId,
        latitude: location.coords.latitude,
        longitude: location.coords.longitude,
        address: await _getAddress(
          location.coords.latitude,
          location.coords.longitude,
        ),
        batteryLevel: _getBatteryLevel(location),
        batteryIsCharging: location.battery.isCharging,
        networkType: await _getNetworkType(),
        appVersion: await _getAppVersion(),
        eventData: {
          'is_real_moving': isRealMoving,
          'timeout_minutes': LocationConfig.stopRealTimeout,
        },
      );
    } catch (e) {
      debugPrint('[LocationService] 세션 킬 이벤트 수집 실패: $e');
    }
  }

  /// 네트워크 타입 가져오기
  Future<String?> _getNetworkType() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.wifi) return 'wifi';
      if (connectivityResult == ConnectivityResult.mobile) return 'mobile';
      return 'none';
    } catch (e) {
      return null;
    }
  }

  /// 앱 버전 가져오기
  Future<String?> _getAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (packageInfo.version.isNotEmpty &&
          packageInfo.buildNumber.isNotEmpty) {
        return '${packageInfo.version}+${packageInfo.buildNumber}';
      }
    } catch (e) {
      return null;
    }
    return null;
  }

  /// 주소 가져오기 (Reverse Geocoding)
  Future<String?> _getAddress(double latitude, double longitude) async {
    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isNotEmpty) {
        final place = placemarks[0];
        return '${place.country} ${place.administrativeArea} ${place.locality} ${place.street}';
      }
    } catch (e) {
      return null;
    }
    return null;
  }

  void _onProviderChange(bg.ProviderChangeEvent event) async {
    try {
      final logService = LogService();
      await logService.addLog('event', {
        'event_name': 'onProviderChange',
        'event_type': 'provider_change',
        'app_time': DateTime.now().toIso8601String(),
        'utc_time': DateTime.now().toUtc().toIso8601String(),
        'enabled': event.enabled,
        'status': event.status,
        'gps': event.gps,
        'network': event.network,
      });
    } catch (e) {
      debugPrint('[Event Log] onProviderChange 로그 저장 실패: $e');
    }
  }

  // 이벤트 로깅용 핸들러들
  void _onActivityChange(bg.ActivityChangeEvent event) async {
    try {
      final logService = LogService();
      await logService.addLog('event', {
        'event_name': 'onActivityChange',
        'event_type': event.activity,
        'app_time': DateTime.now().toIso8601String(),
        'utc_time': DateTime.now().toUtc().toIso8601String(),
        'activity': event.activity,
        'confidence': event.confidence,
      });
    } catch (e) {
      debugPrint('[Event Log] onActivityChange 로그 저장 실패: $e');
    }
  }

  void _onGeofenceForLog(bg.GeofenceEvent event) async {
    try {
      final logService = LogService();
      await logService.addLog('event', {
        'event_name': 'onGeofence',
        'event_type': event.action,
        'app_time': DateTime.now().toIso8601String(),
        'utc_time': DateTime.now().toUtc().toIso8601String(),
        'geofence_id': event.identifier,
        'action': event.action,
      });
    } catch (e) {
      debugPrint('[Event Log] onGeofence 로그 저장 실패: $e');
    }
  }

  void _onGeofencesChange(bg.GeofencesChangeEvent event) async {
    try {
      final logService = LogService();

      // 추가된 지오펜스 타입 확인
      int guardianOnCount = 0;
      for (final geofence in event.on) {
        final extras = geofence.extras;
        if (extras != null && extras['type'] != 'stationary') {
          guardianOnCount++;
        }
      }

      final logData = {
        'event_name': 'onGeofencesChange',
        'event_type': 'change',
        'app_time': DateTime.now().toIso8601String(),
        'utc_time': DateTime.now().toUtc().toIso8601String(),
        'on_count': event.on.length,
        'off_count': event.off.length,
      };

      // 타입별 개수 추가 (있는 경우만)
      if (guardianOnCount > 0) {
        logData['guardian_on'] = guardianOnCount;
      }

      await logService.addLog('event', logData);
    } catch (e) {
      debugPrint('[Event Log] onGeofencesChange 로그 저장 실패: $e');
    }
  }

  void _onHeartbeat(bg.HeartbeatEvent event) async {
    // 백그라운드 작업 시작 (API 호출이 있으므로 필요)
    int? taskId;
    try {
      taskId = await bg.BackgroundGeolocation.startBackgroundTask();
    } catch (e) {
      debugPrint('[HEARTBEAT] startBackgroundTask 실패: $e');
    }

    try {
      debugPrint('[HEARTBEAT] 이벤트 수신');

      // 이벤트 로그 저장
      try {
        final logService = LogService();
        await logService.addLog('event', {
          'event_name': 'onHeartbeat',
          'event_type': 'heartbeat',
          'app_time': DateTime.now().toIso8601String(),
          'utc_time': DateTime.now().toUtc().toIso8601String(),
        });
      } catch (e) {
        debugPrint('[Event Log] onHeartbeat 로그 저장 실패: $e');
      }

      // 위치 공유 체크
      final isSharingEnabled = await isLocationSharingEnabled();
      if (!isSharingEnabled) {
        debugPrint('[HEARTBEAT] 위치 공유 꺼짐 - 처리 중단');
        return;
      }

      // 하트비트 이벤트 스트림으로 전송 (메인 맵 리스트 업데이트용)
      if (_heartbeatController != null && !_heartbeatController!.isClosed) {
        _heartbeatController!.add(null);
      }

      // 현재 위치 가져오기
      bg.Location? location = await bg.BackgroundGeolocation.getCurrentPosition(
        samples: 1,
        timeout: 10,
        extras: {'event': 'heartbeat'},
      );

      // TB_USER + 실시간 위치 업데이트
      // 로그 저장 생략: getCurrentPosition()이 onLocation 이벤트를 발생시켜서 _onLocation에서 이미 로그 저장됨
      await _updateUserLocationRealtime(location);
    } catch (error) {
      debugPrint('[HEARTBEAT] 에러: $error');
    } finally {
      // 백그라운드 작업 종료
      if (taskId != null) {
        bg.BackgroundGeolocation.stopBackgroundTask(taskId);
      }
    }
  }

  // TB_USER + 실시간 위치 업데이트 (하트비트/onLocation 공통)
  // 공개 정적 메서드: 헤드리스/포어그라운드 공통
  static Future<void> updateUserLocationRealtime(
    bg.Location location, {
    String? activityType,
  }) async {
    final instance = LocationService();
    await instance._updateUserLocationRealtime(
      location,
      activityType: activityType,
    );
  }

  // Firebase 실시간 위치 업데이트 (내부 메서드)
  Future<void> _updateUserLocationRealtime(
    bg.Location location, {
    String? activityType,
  }) async {
    try {
      // 위치 공유 체크 제거 - Firebase 업데이트는 항상 수행 (상태 정보 포함)

      final prefs = await SharedPreferences.getInstance();
      
      // userId와 userName 읽기 (재시도 로직 포함)
      String? userId;
      String? userName;
      int retryCount = 0;
      const maxRetries = 3;
      const retryDelay = Duration(milliseconds: 200);
      
      while (retryCount < maxRetries) {
        userId = prefs.getString('user_id');
        userName = prefs.getString('user_name');
        
        if (userId != null && userName != null) {
          break; // 값이 있으면 루프 종료
        }
        
        if (retryCount < maxRetries - 1) {
          debugPrint('[LocationService] _updateUserLocationRealtime: userId 또는 userName이 null - 재시도 ${retryCount + 1}/$maxRetries (userId=$userId, userName=$userName)');
          await Future.delayed(retryDelay);
          retryCount++;
        } else {
          debugPrint('[LocationService] _updateUserLocationRealtime: userId 또는 userName이 null - 재시도 실패 (userId=$userId, userName=$userName)');
          return;
        }
      }
      
      if (userId == null || userName == null) {
        debugPrint('[LocationService] _updateUserLocationRealtime: userId 또는 userName이 null - 최종 실패 (userId=$userId, userName=$userName)');
        return;
      }

      // 세션 ID와 지오펜스 정보 읽기 (location.extras에서만)
      final movementSessionId =
          location.extras?['movement_session_id'] as String?;
      final movementSessionCreatedAt =
          location.extras?['movement_session_created_at'] as String?;
      final currentGeofenceId = prefs.getString('last_guardian_geofence_id');
      final geofenceEnteredAtStr = prefs.getString(
        'last_guardian_geofence_entered_at',
      );
      final geofenceEnteredAt = geofenceEnteredAtStr != null
          ? int.tryParse(geofenceEnteredAtStr)
          : null;

      final batteryLevel = (location.battery.level * 100).toInt();
      final batteryIsCharging = location.battery.isCharging;

      // 앱 버전 가져오기 (버전 + 빌드 번호)
      String? appVersion;
      try {
        final packageInfo = await PackageInfo.fromPlatform();
        if (packageInfo.version.isNotEmpty &&
            packageInfo.buildNumber.isNotEmpty) {
          appVersion =
              '${packageInfo.version}+${packageInfo.buildNumber}'; // 예: "1.0.0+1"
        }
      } catch (e) {
        // 앱 버전 가져오기 실패 시 무시 (null 유지)
      }

      // Firebase Realtime DB 업데이트
      var groupId = await AppCache.groupId;
      
      // groupId가 없으면 SharedPreferences에서 다시 읽기 시도
      if (groupId == null) {
        final groupIdFromPrefs = prefs.getString('group_id');
        debugPrint('[LocationService] _updateUserLocationRealtime: AppCache에 groupId 없음, SharedPreferences에서 읽기: $groupIdFromPrefs');
        if (groupIdFromPrefs != null) {
          await AppCache.setGroupId(groupIdFromPrefs);
          groupId = groupIdFromPrefs;
          debugPrint('[LocationService] _updateUserLocationRealtime: AppCache에 groupId 저장 완료: $groupId');
        }
      } else {
        debugPrint('[LocationService] _updateUserLocationRealtime: groupId 확인: $groupId');
      }

      // groupId가 없으면 Firebase 업데이트 불가
      if (groupId == null || groupId.isEmpty) {
        debugPrint('[LocationService] _updateUserLocationRealtime: ❌ groupId 없음 - Firebase 업데이트 스킵');
        return;
      }

      final finalActivityType = activityType ?? location.activity.type;

      // 현재 상태값들 읽기
      final locationSharingEnabled = await isLocationSharingEnabled();
      final mockDetected = await isMockLocationDetected();
      final mockDetectedAt = mockDetected
          ? prefs.getInt('mock_detected_at') ??
                DateTime.now().millisecondsSinceEpoch
          : null;

      // isRealMoving 가져오기 (이미 _manageSession에서 updateLocation 호출됨)
      final movementDetector = MovementDetector();
      final isRealMoving = movementDetector.currentState ?? location.isMoving;

      // last_location_* 값 읽기 (프리퍼런스에서)
      final lastLocationLat = prefs.getDouble('last_location_latitude');
      final lastLocationLng = prefs.getDouble('last_location_longitude');
      final lastLocationTs = prefs.getInt('last_location_timestamp');

      final firebaseLocationService = FirebaseLocationService();
      await firebaseLocationService.updateRealtimeLocation(
        groupId: groupId,
        userId: userId,
        userName: userName,
        latitude: location.coords.latitude,
        longitude: location.coords.longitude,
        accuracy: location.coords.accuracy,
        altitude: location.coords.altitude,
        speed: location.coords.speed,
        heading: location.coords.heading,
        battery: batteryLevel,
        isCharging: batteryIsCharging,
        activityType: finalActivityType,
        isRealMoving: isRealMoving,
        appVersion: appVersion,
        movementSessionId: movementSessionId,
        movementSessionCreatedAt: movementSessionCreatedAt,
        currentGeofenceId: currentGeofenceId,
        geofenceEnteredAt: geofenceEnteredAt,
        locationSharingEnabled: locationSharingEnabled,
        mockDetectedAt: mockDetectedAt,
        lastLocationLatitude: lastLocationLat,
        lastLocationLongitude: lastLocationLng,
        lastLocationTimestamp: lastLocationTs,
      );

      // LocationCache 저장
      await LocationCache.saveLocation(
        location.coords.latitude,
        location.coords.longitude,
      );

      debugPrint('[LocationService] Firebase 실시간 위치 업데이트 완료');
    } catch (e) {
      debugPrint('[LocationService] Firebase 실시간 위치 업데이트 실패: $e');
    }
  }

  // 위치 수집 = 저장 프로세스 (통합 메서드)
  // TB_USER + 실시간 위치 업데이트 + TB_LOCATION 저장을 하나의 프로세스로 통합

  // 공개 정적 메서드: 세션 관리 (헤드리스/포어그라운드 공통)
  static Future<void> manageSession(bg.Location location) async {
    final instance = LocationService();
    await instance._manageSession(location);
  }

  // 공개 정적 메서드: 위치 저장 (헤드리스/포어그라운드 공통)
  static Future<void> manageLocation(bg.Location location) async {
    final instance = LocationService();
    await instance._manageLocation(location);
  }

  // ============================================================================
  // 상태 관리 및 동기화 메서드
  // ============================================================================
  /// isRealMoving과 location.isMoving이 불일치할 때 강제로 동기화
  ///
  /// [isRealMoving] MovementDetector가 계산한 이동 상태
  /// [locationIsMoving] 라이브러리의 isMoving 값
  Future<void> _syncMovingState({
    required bool? isRealMoving,
    required bool locationIsMoving,
  }) async {
    // isRealMoving이 null이면 동기화하지 않음 (초기 상태)
    if (isRealMoving == null) {
      return;
    }

    // 이미 동일한 상태면 동기화 불필요
    if (isRealMoving == locationIsMoving) {
      return;
    }

    // changePace 호출 중이면 스킵 (중복 호출 방지)
    if (_isChangePaceInProgress) {
      debugPrint('[syncMovingState] changePace 호출 중 - 스킵');
      return;
    }

    _isChangePaceInProgress = true;
    changePaceEventCount = 1; // 다음 onLocation 이벤트 1개만 무시

    try {
      if (isRealMoving == false) {
        // isRealMoving이 false인데 location.isMoving이 true → 정지 모드로 강제 변경
        await bg.BackgroundGeolocation.changePace(false);
        debugPrint(
          '[syncMovingState] 정지 모드로 강제 변경 (isRealMoving: false, location.isMoving: $locationIsMoving)',
        );
      } else if (isRealMoving == true) {
        // isRealMoving이 true인데 location.isMoving이 false → 이동 모드로 강제 변경
        await bg.BackgroundGeolocation.changePace(true);
        debugPrint(
          '[syncMovingState] 이동 모드로 강제 변경 (isRealMoving: true, location.isMoving: $locationIsMoving)',
        );
      }
    } catch (e) {
      debugPrint('[syncMovingState] changePace 호출 실패: $e');
    } finally {
      // 안전장치: 5초 후 자동으로 플래그 해제 (onLocation이 오지 않는 경우 대비)
      Future.delayed(const Duration(seconds: 5), () {
        if (_isChangePaceInProgress) {
          _isChangePaceInProgress = false;
          changePaceEventCount = 0;
          debugPrint('[syncMovingState] 타임아웃으로 플래그 자동 해제');
        }
      });
    }
  }

  // 세션 관리 전용 메서드 (isRealMoving 기반 단순 관리 + 지오펜스 백업)
  Future<void> _manageSession(bg.Location location) async {
    // 락 획득 시도
    if (_isSessionManagementInProgress) {
      debugPrint('[manageSession] 세션 관리 락 획득 실패 - 스킵');
      return;
    }

    _isSessionManagementInProgress = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final currentSessionId = prefs.getString('current_movement_session_id');

      // ============================================================================
      // isRealMoving 계산 (커스텀 로직)
      // ============================================================================
      final movementDetector = MovementDetector();
      final isRealMoving = await movementDetector.updateLocation(location);

      // ============================================================================
      // 이동 상태 동기화 (isRealMoving과 location.isMoving 불일치 시 강제 변경)
      // ============================================================================
      await _syncMovingState(
        isRealMoving: isRealMoving,
        locationIsMoving: location.isMoving,
      );

      // 초기 상태 처리 (isRealMoving이 null이면 라이브러리 값 사용)
      final finalIsMoving = isRealMoving ?? location.isMoving;

      // ============================================================================
      // changePace 호출 (상태 변경 시 또는 초기 상태 설정 시) - 주석 처리
      // ============================================================================
      // if (_previousIsRealMoving == null) {
      //   // 초기 상태 설정 - 첫 번째 위치 수신 시
      //   _isChangePaceInProgress = true;
      //   _changePaceTimestamp = DateTime.now();
      //
      //   try {
      //     if (finalIsMoving == false) {
      //       // 초기 상태가 정지 → changePace(false) → 하트비트 활성화
      //       await bg.BackgroundGeolocation.changePace(false);
      //       debugPrint('[manageSession] 초기 상태 - 정지 모드로 설정 (하트비트 활성화)');
      //     } else if (finalIsMoving == true) {
      //       // 초기 상태가 이동 → changePace(true)
      //       await bg.BackgroundGeolocation.changePace(true);
      //       debugPrint('[manageSession] 초기 상태 - 이동 모드로 설정');
      //     }
      //   } catch (e) {
      //     debugPrint('[manageSession] 초기 changePace 호출 실패: $e');
      //   }
      //
      //   // 1초 후 플래그 해제 (changePace로 인한 onLocation 처리 시간)
      //   Future.delayed(Duration(milliseconds: 1000), () {
      //     _isChangePaceInProgress = false;
      //     _changePaceTimestamp = null;
      //   });
      // } else if (_previousIsRealMoving != finalIsMoving) {
      //   // 상태가 변경되었을 때 changePace 호출
      //   _isChangePaceInProgress = true;
      //   _changePaceTimestamp = DateTime.now();
      //
      //   try {
      //     if (finalIsMoving == false) {
      //       // 정지 상태로 전환 → changePace(false) → 하트비트 활성화
      //       await bg.BackgroundGeolocation.changePace(false);
      //       debugPrint('[manageSession] 정지 모드로 전환 - 하트비트 활성화');
      //     } else if (finalIsMoving == true) {
      //       // 이동 상태로 전환 → changePace(true)
      //       await bg.BackgroundGeolocation.changePace(true);
      //       debugPrint('[manageSession] 이동 모드로 전환');
      //     }
      //   } catch (e) {
      //     debugPrint('[manageSession] changePace 호출 실패: $e');
      //   }
      //
      //   // 1초 후 플래그 해제 (changePace로 인한 onLocation 처리 시간)
      //   Future.delayed(Duration(milliseconds: 1000), () {
      //     _isChangePaceInProgress = false;
      //     _changePaceTimestamp = null;
      //   });
      // }

      // ============================================================================
      // 세션 관리 (isRealMoving 사용)
      // ============================================================================
      if (finalIsMoving) {
        // 이동 중 → 세션 생성 (없으면)
        if (currentSessionId == null) {
          // 세션 상태 재확인 (락 획득 후 상태 변경 감지)
          final recheckSessionId = prefs.getString(
            'current_movement_session_id',
          );
          if (recheckSessionId != null) {
            debugPrint(
              '[manageSession] 세션 상태 재확인 - 세션이 이미 존재함: $recheckSessionId (생성 중단)',
            );
            return;
          }
          final newSessionId = const Uuid().v4();
          final sessionCreatedAt = DateTime.now().toIso8601String();

          await prefs.setString('current_movement_session_id', newSessionId);
          await prefs.setString(
            'current_movement_session_created_at',
            sessionCreatedAt,
          );
          debugPrint('[manageSession] 생성: $newSessionId (생성 시간: $sessionCreatedAt)');

          // 종료 위치 삭제 (Preferences + Firebase)
          await prefs.remove('last_location_latitude');
          await prefs.remove('last_location_longitude');
          await prefs.remove('last_location_timestamp');

          // Firebase에서 종료 위치 삭제 (null 설정)
          try {
            final userId = await AppCache.userId;
            final userName = prefs.getString('user_name');
            final groupId =
                await AppCache.groupId ??
                '00000000-0000-0000-0000-000000000002';

            if (userId != null && userName != null) {
              final firebaseLocationService = FirebaseLocationService();
              await firebaseLocationService.updateRealtimeLocation(
                groupId: groupId,
                userId: userId,
                userName: userName,
                latitude: location.coords.latitude,
                longitude: location.coords.longitude,
                accuracy: location.coords.accuracy,
                altitude: location.coords.altitude,
                speed: location.coords.speed,
                heading: location.coords.heading,
                battery: _getBatteryLevel(location),
                isCharging: location.battery.isCharging,
                activityType: location.activity.type,
                isRealMoving: true,
                lastLocationLatitude: null,
                lastLocationLongitude: null,
                lastLocationTimestamp: null,
              );
              debugPrint('[manageSession] 종료 위치 삭제 완료 (Firebase)');

              // last_location_* 삭제 이벤트 로그
              try {
                await _apiService.recordEvent(
                  eventType: EventTypes.session,
                  eventSubtype: SessionEventSubtypes.lastLocationCleared,
                  movementSessionId: newSessionId,
                  latitude: location.coords.latitude,
                  longitude: location.coords.longitude,
                  address: await _getAddress(
                    location.coords.latitude,
                    location.coords.longitude,
                  ),
                  batteryLevel: _getBatteryLevel(location),
                  batteryIsCharging: location.battery.isCharging,
                  networkType: await _getNetworkType(),
                  appVersion: await _getAppVersion(),
                  eventData: {
                    'cleared_at': DateTime.now().millisecondsSinceEpoch,
                  },
                );
                debugPrint('[manageSession] last_location_* 삭제 이벤트 로그 기록 완료');
              } catch (e) {
                debugPrint('[manageSession] last_location_* 삭제 이벤트 로그 기록 실패: $e');
              }
            }
          } catch (e) {
            debugPrint('[manageSession] 종료 위치 삭제 실패 (Firebase): $e');
          }

          // 세션 시작 이벤트 수집
          await _recordSessionStartEvent(location, newSessionId);

          // location.extras에 세션 정보 담기
          try {
            if (location.extras != null) {
              location.extras!['movement_session_id'] = newSessionId;
              location.extras!['movement_session_created_at'] =
                  sessionCreatedAt;
              debugPrint('[manageSession] location.extras에 세션 정보 추가 완료');
            } else {
              debugPrint('[manageSession] ⚠️ location.extras가 null');
            }
          } catch (e) {
            debugPrint('[manageSession] ⚠️ location.extras 수정 실패: $e');
          }
        } else {
          // 세션 상태 재확인 (락 획득 후 상태 변경 감지)
          final recheckSessionId = prefs.getString(
            'current_movement_session_id',
          );
          if (recheckSessionId != currentSessionId) {
            debugPrint(
              '[manageSession] 세션 상태 재확인 - 세션이 변경됨: $currentSessionId → $recheckSessionId (유지 중단)',
            );
            return;
          }

          // 세션 유지 - location.extras에 세션 정보 담기 (생성 시간은 업데이트 안 함)
          final sessionCreatedAt = prefs.getString(
            'current_movement_session_created_at',
          );
          try {
            if (location.extras != null) {
              location.extras!['movement_session_id'] = currentSessionId;
              if (sessionCreatedAt != null) {
                location.extras!['movement_session_created_at'] =
                    sessionCreatedAt;
              }
            }
          } catch (e) {
            debugPrint('[manageSession] ⚠️ location.extras 수정 실패: $e');
          }
          debugPrint('[manageSession] 세션 유지: $currentSessionId');
        }

        // 타이머 리셋 (세션 생성 또는 유지 시)
        _sessionTimeoutTimer?.cancel();
        final movementDetector = MovementDetector();
        final timeout = await movementDetector.getStopRealTimeout();
        _sessionTimeoutTimer = Timer(timeout, () {
          _killSession();
        });
        debugPrint('[manageSession] ${timeout.inMinutes}분 킬 스위치 리셋');
      } else {
        // 정지 → 세션 삭제 (있으면)
        if (currentSessionId != null) {
          // 세션 ID 저장 (삭제 후에도 사용하기 위해)
          final sessionIdToEnd = currentSessionId;

          // 세션 삭제
          await prefs.remove('current_movement_session_id');
          await prefs.remove('current_movement_session_created_at');
          debugPrint('[manageSession] 삭제: $sessionIdToEnd');

          // location.extras에서 세션 정보 제거
          try {
            if (location.extras != null) {
              location.extras!.remove('movement_session_id');
              location.extras!.remove('movement_session_created_at');
              debugPrint('[manageSession] location.extras에서 세션 정보 제거 완료');
            }
          } catch (e) {
            debugPrint('[manageSession] ⚠️ location.extras 수정 실패: $e');
          }

          // 세션 종료 이벤트 수집 (세션 삭제 후)
          await _recordSessionEndEvent(location, sessionIdToEnd);

          // 종료 위치 저장 (Preferences + Firebase)
          try {
            final endLat = location.coords.latitude;
            final endLng = location.coords.longitude;
            final endTimestamp = DateTime.now().millisecondsSinceEpoch;

            // Preferences 저장
            await prefs.setDouble('last_location_latitude', endLat);
            await prefs.setDouble('last_location_longitude', endLng);
            await prefs.setInt('last_location_timestamp', endTimestamp);

            // Firebase 저장
            final userId = await AppCache.userId;
            final userName = prefs.getString('user_name');
            final groupId =
                await AppCache.groupId ??
                '00000000-0000-0000-0000-000000000002';

            if (userId != null && userName != null) {
              final firebaseLocationService = FirebaseLocationService();
              await firebaseLocationService.updateRealtimeLocation(
                groupId: groupId,
                userId: userId,
                userName: userName,
                latitude: location.coords.latitude,
                longitude: location.coords.longitude,
                accuracy: location.coords.accuracy,
                altitude: location.coords.altitude,
                speed: location.coords.speed,
                heading: location.coords.heading,
                battery: _getBatteryLevel(location),
                isCharging: location.battery.isCharging,
                activityType: location.activity.type,
                isRealMoving: false,
                lastLocationLatitude: endLat,
                lastLocationLongitude: endLng,
                lastLocationTimestamp: endTimestamp,
              );
              debugPrint(
                '[manageSession] 종료 위치 저장 완료: lat=$endLat, lng=$endLng, timestamp=$endTimestamp',
              );

              // last_location_* 저장 이벤트 로그
              try {
                await _apiService.recordEvent(
                  eventType: EventTypes.session,
                  eventSubtype: SessionEventSubtypes.lastLocationSaved,
                  movementSessionId: sessionIdToEnd,
                  latitude: endLat,
                  longitude: endLng,
                  address: await _getAddress(endLat, endLng),
                  batteryLevel: _getBatteryLevel(location),
                  batteryIsCharging: location.battery.isCharging,
                  networkType: await _getNetworkType(),
                  appVersion: await _getAppVersion(),
                  eventData: {
                    'last_location_latitude': endLat,
                    'last_location_longitude': endLng,
                    'last_location_timestamp': endTimestamp,
                  },
                );
                debugPrint('[manageSession] last_location_* 저장 이벤트 로그 기록 완료');
              } catch (e) {
                debugPrint('[manageSession] last_location_* 저장 이벤트 로그 기록 실패: $e');
              }
            }
          } catch (e) {
            debugPrint('[manageSession] 종료 위치 저장 실패: $e');
          }
        }

        // 타이머 취소 (세션 삭제 시)
        _sessionTimeoutTimer?.cancel();
        _sessionTimeoutTimer = null;
        debugPrint('[manageSession] 킬 스위치 취소');

        //   if (userId != null) {
        //     // LocationConfig 값 사용
        //     final created =
        //   }
        // }
      }
    } catch (e) {
      debugPrint('[manageSession] 세션 관리 실패: $e');
    } finally {
      // 락 해제
      _isSessionManagementInProgress = false;
    }
  }

  // ============================================================================

  // 세션 타임아웃 킬 스위치 (8분간 위치 수집 없음)
  Future<void> _killSession() async {
    // 락 확인 (락 획득 중이면 스킵)
    if (_isSessionManagementInProgress) {
      debugPrint('[KillSwitch] 세션 관리 락 획득 중 - 스킵');
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final currentSessionId = prefs.getString('current_movement_session_id');

      if (currentSessionId == null) {
        return; // 이미 세션이 삭제됨
      }

      debugPrint(
        '[KillSwitch] 세션 타임아웃 - 세션 삭제: $currentSessionId (${LocationConfig.stopRealTimeout}분간 위치 수집 없음)',
      );

      // 마지막 위치 정보 가져오기 (세션 종료 이벤트 기록용)
      bg.Location? lastLocation;
      try {
        // getCurrentPosition으로 현재 위치 가져오기 시도
        lastLocation = await bg.BackgroundGeolocation.getCurrentPosition(
          samples: 1,
          timeout: 5,
        );
      } catch (e) {
        debugPrint('[KillSwitch] getCurrentPosition 실패, LocationCache 사용: $e');
        // getCurrentPosition 실패 시 LocationCache에서 마지막 위치 가져오기
        final (lat, lng) = await LocationCache.getLocation();
        if (lat != null && lng != null) {
          // 가짜 location 객체 생성 (세션 종료 이벤트 및 Realtime DB 업데이트용)
          // 실제 location 객체가 없으므로 최소한의 정보만 사용
          // location 객체를 만들 수 없으므로 직접 Firebase 업데이트
          final userId = await AppCache.userId;
          final userName = prefs.getString('user_name');
          if (userId != null && userName != null) {
            final groupId =
                await AppCache.groupId ??
                '00000000-0000-0000-0000-000000000002';
            final firebaseLocationService = FirebaseLocationService();
            await firebaseLocationService.updateRealtimeLocation(
              groupId: groupId,
              userId: userId,
              userName: userName,
              latitude: lat,
              longitude: lng,
              accuracy: null,
              altitude: null,
              speed: null,
              heading: null,
              battery: null,
              isCharging: null,
              activityType: null,
              isRealMoving: false,
              appVersion: null,
              movementSessionId: null, // 세션 정보 제거
              movementSessionCreatedAt: null, // 세션 정보 제거
              currentGeofenceId: null,
              geofenceEnteredAt: null,
            );
            debugPrint('[KillSwitch] Realtime Database 업데이트 완료 (세션 정보 제거)');
          }
        }
      }

      // 세션 상태 재확인 (락 획득 후 상태 변경 감지)
      final recheckSessionId = prefs.getString('current_movement_session_id');
      if (recheckSessionId != currentSessionId) {
        debugPrint(
          '[KillSwitch] 세션 상태 재확인 - 세션이 변경됨: $currentSessionId → $recheckSessionId (삭제 중단)',
        );
        return;
      }

      // 세션 삭제
      await prefs.remove('current_movement_session_id');
      await prefs.remove('current_movement_session_created_at');

      // getCurrentPosition 성공 시 Realtime Database 업데이트
      if (lastLocation != null) {
        // location.extras에서 세션 정보 제거
        if (lastLocation.extras != null) {
          lastLocation.extras!.remove('movement_session_id');
          lastLocation.extras!.remove('movement_session_created_at');
        }
        await _updateUserLocationRealtime(lastLocation);
        debugPrint('[KillSwitch] Realtime Database 업데이트 완료 (세션 정보 제거)');
      }

      // 세션 킬 이벤트 기록 (세션 삭제 후)
      if (lastLocation != null) {
        await _recordSessionKillEvent(lastLocation, currentSessionId);
        debugPrint('[KillSwitch] 세션 킬 이벤트 기록 완료');
      } else {
        // location이 없어도 세션 킬 이벤트 기록 시도 (최소 정보로)
        final (lat, lng) = await LocationCache.getLocation();
        if (lat != null && lng != null) {
          // 최소한의 location 정보로 세션 킬 이벤트 기록
          // _recordSessionKillEvent는 location 객체를 필요로 하므로,
          // LocationCache에서 가져온 정보로 최소한의 location 객체 생성이 필요하지만
          // 복잡하므로 일단 이벤트 기록을 스킵하고 로그만 남김
          debugPrint('[KillSwitch] ⚠️ location 객체 없음 - 세션 킬 이벤트 기록 스킵');
        }
      }

      // 종료 위치 저장 (Preferences + Firebase)
      try {
        double? endLat;
        double? endLng;
        final endTimestamp = DateTime.now().millisecondsSinceEpoch;

        // 위치 값 가져오기
        if (lastLocation != null) {
          endLat = lastLocation.coords.latitude;
          endLng = lastLocation.coords.longitude;
        } else {
          final (lat, lng) = await LocationCache.getLocation();
          if (lat != null && lng != null) {
            endLat = lat;
            endLng = lng;
          }
        }

        // 위치 값이 있으면 저장
        if (endLat != null && endLng != null) {
          // Preferences 저장
          await prefs.setDouble('last_location_latitude', endLat);
          await prefs.setDouble('last_location_longitude', endLng);
          await prefs.setInt('last_location_timestamp', endTimestamp);

          // Firebase 저장
          final userId = await AppCache.userId;
          final userName = prefs.getString('user_name');
          final groupId =
              await AppCache.groupId ?? '00000000-0000-0000-0000-000000000002';

          if (userId != null && userName != null) {
            final firebaseLocationService = FirebaseLocationService();
            await firebaseLocationService.updateRealtimeLocation(
              groupId: groupId,
              userId: userId,
              userName: userName,
              latitude: endLat,
              longitude: endLng,
              accuracy: lastLocation?.coords.accuracy,
              altitude: lastLocation?.coords.altitude,
              speed: lastLocation?.coords.speed,
              heading: lastLocation?.coords.heading,
              battery: lastLocation != null
                  ? _getBatteryLevel(lastLocation)
                  : null,
              isCharging: lastLocation?.battery.isCharging,
              activityType: lastLocation?.activity.type,
              isRealMoving: false,
              lastLocationLatitude: endLat,
              lastLocationLongitude: endLng,
              lastLocationTimestamp: endTimestamp,
            );
            debugPrint(
              '[KillSwitch] 종료 위치 저장 완료: lat=$endLat, lng=$endLng, timestamp=$endTimestamp',
            );

            // last_location_* 저장 이벤트 로그
            try {
              await _apiService.recordEvent(
                eventType: EventTypes.session,
                eventSubtype: SessionEventSubtypes.lastLocationSaved,
                movementSessionId: currentSessionId,
                latitude: endLat,
                longitude: endLng,
                address: lastLocation != null
                    ? await _getAddress(endLat, endLng)
                    : null,
                batteryLevel: lastLocation != null
                    ? _getBatteryLevel(lastLocation)
                    : null,
                batteryIsCharging: lastLocation?.battery.isCharging,
                networkType: await _getNetworkType(),
                appVersion: await _getAppVersion(),
                eventData: {
                  'last_location_latitude': endLat,
                  'last_location_longitude': endLng,
                  'last_location_timestamp': endTimestamp,
                },
              );
              debugPrint('[KillSwitch] last_location_* 저장 이벤트 로그 기록 완료');
            } catch (e) {
              debugPrint('[KillSwitch] last_location_* 저장 이벤트 로그 기록 실패: $e');
            }
          }
        } else {
          debugPrint('[KillSwitch] ⚠️ 위치 값 없음 - 종료 위치 저장 스킵');
        }
      } catch (e) {
        debugPrint('[KillSwitch] 종료 위치 저장 실패: $e');
      }

      //   if (userId != null) {
      //     // 마지막 위치 가져오기
      //     double? lastLocationLat;
      //     double? lastLocationLng;
      //
      //     if (lastLocation != null) {
      //       lastLocationLat = lastLocation.coords.latitude;
      //       lastLocationLng = lastLocation.coords.longitude;
      //     } else {
      //     }
      //
      //     if (lastLocationLat != null && lastLocationLng != null) {
      //       final created =
      //     }
      //   }
      // }
    } catch (e) {
      debugPrint('[KillSwitch] 세션 삭제 실패: $e');
    }
  }

  // 위치 저장 전용 메서드 (세션이 있으면 저장)
  Future<void> _manageLocation(bg.Location location) async {
    try {
      // location.extras에서 세션 ID 읽기 시도
      String? currentSessionId =
          location.extras?['movement_session_id'] as String?;

      debugPrint(
        '[manageLocation] 세션 ID 읽기 시도: $currentSessionId (location.extras에서: ${location.extras?['movement_session_id']})',
      );

      // location.extras에 없으면 SharedPreferences에서 직접 읽기 (헤드리스/백그라운드 공통)
      if (currentSessionId == null) {
        final prefs = await SharedPreferences.getInstance();
        currentSessionId = prefs.getString('current_movement_session_id');
        debugPrint(
          '[manageLocation] location.extras에 세션 ID 없음 - SharedPreferences에서 읽기: $currentSessionId',
        );
      }

      // 세션이 있으면 위치 저장 (세션 ID를 파라미터로 전달)
      if (currentSessionId != null) {
        _saveLocationDuringSession(
          location,
          sessionId: currentSessionId,
        ).catchError((error) {
          debugPrint('[manageLocation] 위치 저장 실패: $error');
        });
      } else {
        // 세션이 없으면 저장 안 함
        debugPrint('[manageLocation] 세션 없음 - 저장 안 함');
      }
    } catch (e) {
      debugPrint('[manageLocation] 위치 저장 프로세스 실패: $e');
    }
  }

  Future<void> startTracking() async {
    debugPrint('[startTracking] 위치 추적 시작...');

    if (!_isInitialized) {
      await initialize();
    }

    if (_isTracking) {
      debugPrint('[startTracking] 이미 추적 중');
      return;
    }

    try {
      // 현재 상태 확인 (이미 시작되었는지 체크)
      final state = await bg.BackgroundGeolocation.state;
      if (state.enabled == true) {
        _isTracking = true;
        debugPrint('[startTracking] 이미 활성화됨 - 하트비트만 전송');

        // updated_at 타이머 시작
        _startUpdatedAtTimer();

        // 위치 요청 통합: 한 번만 getCurrentPosition() 호출
        bg.Location? sharedLocation;
        try {
          sharedLocation = await bg.BackgroundGeolocation.getCurrentPosition(
            samples: 1, // 샘플 수 단축 (2 → 1)
            timeout: 5, // 타임아웃 단축 (10초 → 5초)
            extras: {'event': 'app_start_initial', 'foreground': true},
          );
        } catch (e) {
          debugPrint('[startTracking] 초기 위치 가져오기 실패: $e');
        }

        // 앱 시작 시 프리퍼런스 확인 및 처리 (위치 공유) - 비동기로 처리하여 UI 블로킹 방지
        _handleAppStartState(location: sharedLocation).catchError((error) {
          debugPrint('[startTracking] 앱 시작 상태 처리 실패 (비동기): $error');
        });

        // 하트비트는 비동기로 실행 (UI 블로킹 방지)
        _sendInitialHeartbeat(location: sharedLocation).catchError((error) {
          debugPrint('[startTracking] 하트비트 전송 실패 (비동기): $error');
        });
        return;
      }

      // 권한 확인
      debugPrint('[startTracking] 위치 권한 확인 중...');
      final permission = await bg.BackgroundGeolocation.requestPermission();
      if (permission == bg.Config.AUTHORIZATION_STATUS_ALWAYS) {
        debugPrint('[LocationService] 위치 권한 확인 완료 - 추적 시작');
        await bg.BackgroundGeolocation.start();
        _isTracking = true;
        debugPrint('[startTracking] 위치 추적 시작 완료');

        // updated_at 타이머 시작
        _startUpdatedAtTimer();

        // 시작 후 즉시 하트비트 보내기 (비동기로 실행)
        _sendInitialHeartbeat().catchError((error) {
          debugPrint('[startTracking] 하트비트 전송 실패 (비동기): $error');
        });
      } else {
        debugPrint('[startTracking] 위치 권한 부족: $permission');
      }
    } catch (e) {
      debugPrint('[startTracking] 위치 추적 시작 실패: $e');
      // "Waiting for previous start action to complete" 에러 무시
      // 이미 시작 중이면 상태만 업데이트
      final state = await bg.BackgroundGeolocation.state;
      if (state.enabled == true) {
        _isTracking = true;
        debugPrint('[startTracking] 이미 활성화됨 (에러 후 확인) - 하트비트만 전송');

        // updated_at 타이머 시작
        _startUpdatedAtTimer();

        // 이미 시작되어 있으면 하트비트만 보내기 (비동기로 실행)
        _sendInitialHeartbeat().catchError((error) {
          debugPrint('[startTracking] 하트비트 전송 실패 (비동기): $error');
        });
      }
    }
  }

  // 앱 시작 시 초기 하트비트 전송
  // location이 null이면 내부에서 위치를 가져오고, 제공되면 사용
  Future<void> _sendInitialHeartbeat({bg.Location? location}) async {
    try {
      debugPrint('[HEARTBEAT] 앱 시작 시 초기 하트비트 전송 시작');

      // 위치가 제공되지 않았으면 가져오기
      location ??= await bg.BackgroundGeolocation.getCurrentPosition(
          samples: 1, // 샘플 수 단축 (2 → 1)
          timeout: 5, // 타임아웃 단축 (15초 → 5초)
          extras: {'event': 'initial_heartbeat', 'foreground': true},
        );

      // TB_USER + 실시간 위치 업데이트 (앱 재시작 시에도 동일하게 처리)
      await _updateUserLocationRealtime(location);
      debugPrint('[HEARTBEAT] 앱 시작 시 초기 하트비트 전송 완료');
    } catch (error) {
      debugPrint('[HEARTBEAT] 앱 시작 시 초기 하트비트 전송 실패: $error');
    }
  }

  /// updated_at 타이머 시작
  void _startUpdatedAtTimer() {
    _updatedAtTimer?.cancel();
    _updatedAtTimer = Timer.periodic(
      const Duration(minutes: LocationConfig.updatedAtInterval),
      (timer) async {
        try {
          final userId = await AppCache.userId;
          final groupId = await AppCache.groupId;
          if (userId != null && groupId != null) {
            final firebaseLocationService = FirebaseLocationService();
            await firebaseLocationService.updateUpdatedAt(
              groupId: groupId,
              userId: userId,
            );
          }
        } catch (e) {
          debugPrint('[LocationService] updated_at 타이머 업데이트 실패: $e');
        }
      },
    );
    debugPrint(
      '[LocationService] updated_at 타이머 시작 (${LocationConfig.updatedAtInterval}분 주기)',
    );
  }

  Future<void> stopTracking() async {
    if (!_isTracking) return;

    // 타이머 정리
    _sessionTimeoutTimer?.cancel();
    _sessionTimeoutTimer = null;

    // updated_at 타이머 정리
    _updatedAtTimer?.cancel();
    _updatedAtTimer = null;

    await bg.BackgroundGeolocation.stop();
    _isTracking = false;
  }

  /// 데모 모드 등에서 이전 세션의 백그라운드 추적을 강제 중지.
  /// _isTracking 플래그와 무관하게 네이티브 플러그인을 직접 stop.
  Future<void> forceStopBackground() async {
    try {
      await bg.BackgroundGeolocation.stop();
      await bg.BackgroundGeolocation.removeListeners();
      _isTracking = false;
      _isInitialized = false;
      debugPrint('[LocationService] 백그라운드 위치 추적 강제 중지 완료');
    } catch (e) {
      debugPrint('[LocationService] forceStopBackground: $e');
    }
  }

  // 현재 위치 가져오기 (UI에서 내 위치로 이동 시 사용)
  Future<bg.Location?> getCurrentPosition() async {
    try {
      debugPrint('[LocationService] 현재 위치 가져오기 시작...');

      if (!_isInitialized) {
        await initialize();
      }

      final location = await bg.BackgroundGeolocation.getCurrentPosition(
        samples: 1,
        persist: true,
      );

      debugPrint(
        '[LocationService] 현재 위치 가져오기 성공: ${location.coords.latitude.toStringAsFixed(6)}, ${location.coords.longitude.toStringAsFixed(6)}',
      );

      return location;
    } catch (e) {
      debugPrint('[LocationService] 현재 위치 가져오기 실패: $e');
      return null;
    }
  }

  // 배터리 레벨 변환 (0.0-1.0 → 0-100)
  int? _getBatteryLevel(bg.Location location) {
    try {
      final level = location.battery.level;
      return (level * 100).toInt();
    } catch (e) {
      // 에러 발생 시 null 반환
    }
    return null;
  }

  // ============================================================================
  // 배터리 인식 GPS 주기 동적 조정 (DOC-T2-OFL-016 §7)
  // ============================================================================
  /// 현재 상태(프라이버시 등급, 네트워크, 배터리, SOS)에 따라 GPS 수집 주기를 동적으로 변경.
  /// 이전 주기와 동일하면 setConfig 호출을 생략하여 성능 오버헤드를 최소화한다.
  Future<void> _updateGpsInterval(bg.Location location) async {
    try {
      // 1. 프라이버시 등급 (SharedPreferences 캐시, 기본 'standard')
      final prefs = await SharedPreferences.getInstance();
      final privacyLevel = prefs.getString('privacy_level') ?? 'standard';

      // 2. 오프라인 여부
      final connectivityResult = await Connectivity().checkConnectivity();
      final isOffline = connectivityResult == ConnectivityResult.none;

      // 3. 배터리 잔량 (0-100)
      final batteryLevel = _getBatteryLevel(location) ?? 50;

      // 4. SOS 활성 상태 (SharedPreferences 캐시, 기본 false)
      final isSosActive = prefs.getBool('sos_active') ?? false;

      // 주기 계산
      final newIntervalSeconds = BatteryGpsManager.calculateInterval(
        privacyLevel: privacyLevel,
        isOffline: isOffline,
        batteryLevel: batteryLevel,
        isSosActive: isSosActive,
      );

      // 동일하면 스킵
      if (newIntervalSeconds == _lastGpsIntervalSeconds) return;

      final previousInterval = _lastGpsIntervalSeconds;
      _lastGpsIntervalSeconds = newIntervalSeconds;

      // BackgroundGeolocation 설정 업데이트 (밀리초 변환)
      await bg.BackgroundGeolocation.setConfig(
        bg.Config(
          locationUpdateInterval: newIntervalSeconds * 1000,
          fastestLocationUpdateInterval: newIntervalSeconds * 1000,
        ),
      );

      debugPrint(
        '[LocationService] GPS 주기 변경: ${previousInterval ?? 'initial'}s -> ${newIntervalSeconds}s '
        '(privacy=$privacyLevel, offline=$isOffline, battery=$batteryLevel%, sos=$isSosActive)',
      );
    } catch (e) {
      debugPrint('[LocationService] GPS 주기 업데이트 실패: $e');
    }
  }

  // 위치 재확인 (최대 3번 시도)

  // 위치 공유 상태 확인
  static Future<bool> isLocationSharingEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('location_sharing_enabled') ?? true;
  }

  // 위치 공유 상태 설정 (Firebase 동기화 포함)
  static Future<void> setLocationSharingEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('location_sharing_enabled', enabled);

    // Firebase 동기화
    final userId = await AppCache.userId;
    final groupId = await AppCache.groupId;
    if (userId != null && groupId != null) {
      try {
        final firebaseLocationService = FirebaseLocationService();
        await firebaseLocationService.updateUserSettings(
          groupId: groupId,
          userId: userId,
          locationSharingEnabled: enabled,
        );
      } catch (e) {
        debugPrint('[LocationService] Firebase 위치 공유 상태 업데이트 실패: $e');
      }
    }

    // 이벤트 로그 기록
    try {
      final apiService = ApiService();
      await apiService.recordEvent(
        eventType: EventTypes.deviceStatus,
        eventSubtype: enabled
            ? DeviceStatusEventSubtypes.locationSharingEnabled
            : DeviceStatusEventSubtypes.locationSharingDisabled,
      );
    } catch (e) {
      debugPrint('[LocationService] 위치 공유 이벤트 로그 기록 실패: $e');
    }
  }

  // Mock 위치 감지 상태 확인
  static Future<bool> isMockLocationDetected() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('mock_location_detected') ?? false;
  }

  // Mock 위치 감지 상태 설정 (Firebase 동기화 포함)
  static Future<void> setMockLocationDetected(bool detected) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('mock_location_detected', detected);

    // mock_detected_at 타임스탬프 저장
    if (detected) {
      await prefs.setInt(
        'mock_detected_at',
        DateTime.now().millisecondsSinceEpoch,
      );
    } else {
      await prefs.remove('mock_detected_at');
    }

    // Firebase 동기화
    final userId = await AppCache.userId;
    final groupId = await AppCache.groupId;
    if (userId != null && groupId != null) {
      try {
        final firebaseLocationService = FirebaseLocationService();
        final mockDetectedAt = detected
            ? prefs.getInt('mock_detected_at') ??
                  DateTime.now().millisecondsSinceEpoch
            : null;
        await firebaseLocationService.updateMockDetected(
          groupId: groupId,
          userId: userId,
          mockDetectedAt: mockDetectedAt,
        );
      } catch (e) {
        debugPrint('[LocationService] Firebase Mock 위치 감지 상태 업데이트 실패: $e');
      }
    }
  }

  Future<void> dispose() async {
    await stopTracking();
    await _heartbeatController?.close();
    _heartbeatController = null;
    await _batteryLevelController.close();
    _isInitialized = false;

    // updated_at 타이머 정리 (이중 방어)
    _updatedAtTimer?.cancel();
    _updatedAtTimer = null;
  }

  void clearLogs() {
    // SQLite 로그는 LogService에서 관리
    // 필요시 LogService().clearLogs() 호출
  }

  // 세션 중간 위치 저장
  // 공개 정적 메서드: 세션 중간 위치 저장 (헤드리스/포어그라운드 공통)
  static Future<void> saveLocationDuringSession(
    bg.Location location, {
    String? sessionId,
  }) async {
    final instance = LocationService();
    await instance._saveLocationDuringSession(location, sessionId: sessionId);
  }

  Future<void> _saveLocationDuringSession(
    bg.Location location, {
    String? sessionId,
  }) async {
    try {
      // 위치 공유 체크 제거 - 서버 저장은 항상 수행

      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');

      // 세션 ID: 파라미터로 전달받은 값 우선 사용, 없으면 SharedPreferences에서 읽기
      final currentSessionId =
          sessionId ?? prefs.getString('current_movement_session_id');

      debugPrint(
        '[위치 저장] userId: $userId, sessionId: $currentSessionId (전달받은 값: $sessionId)',
      );

      if (userId == null) {
        debugPrint('[위치 저장] userId 없음 - 저장 안 함');
        return;
      }

      // 세션 ID 검증: 세션이 없으면 저장하지 않음
      if (currentSessionId == null) {
        debugPrint('[위치 저장] 세션 ID 없음 - 저장 안 함 (세션이 종료되었거나 없음)');
        return;
      }

      // 세션 ID 일관성 검증: 전달받은 세션 ID와 SharedPreferences의 세션 ID가 일치하는지 확인
      final recheckSessionId = prefs.getString('current_movement_session_id');
      if (recheckSessionId != currentSessionId) {
        debugPrint(
          '[위치 저장] ⚠️ 세션 ID 불일치 - 현재 세션 ID로 저장: $recheckSessionId (요청: $currentSessionId)',
        );
        // 세션이 변경되었으면 현재 세션 ID로 저장
        if (recheckSessionId == null) {
          debugPrint('[위치 저장] ⚠️ 세션이 종료됨 - 저장 중단');
          return;
        }
        // 현재 세션 ID로 저장 (이전 세션 ID 무시)
      }

      // age 필터링 (30초)
      if (location.age > LocationConfig.maxLocationAge) {
        debugPrint(
          '[위치 저장] 위치가 너무 오래됨 (age: ${location.age}ms, 최대: ${LocationConfig.maxLocationAge}ms) - 저장 중단',
        );
        return;
      }

      // sample 필터링 (샘플링 위치 제외)
      if (location.sample == true) {
        debugPrint('[위치 저장] 샘플링 위치 감지 - 저장 중단');
        return;
      }

      // accuracy 필터링 (50m)
      final accuracy = location.coords.accuracy;
      if (accuracy > LocationConfig.maxLocationAccuracy) {
        debugPrint(
          '[위치 저장] 정확도가 너무 낮음 (accuracy: ${accuracy.toStringAsFixed(1)}m, 최대: ${LocationConfig.maxLocationAccuracy}m) - 저장 중단',
        );
        return;
      }

      // heading 필터링 (5도 차이)
      final currentHeading = location.coords.heading;
      if (currentHeading != -1) {
        // 이전에 저장한 heading 가져오기
        final lastHeading = prefs.getDouble('last_location_heading');

        if (lastHeading != null && lastHeading != -1) {
          // 바로 이전 heading과 비교 (원형 각도 계산)
          double headingDiff = (currentHeading - lastHeading).abs();
          if (headingDiff > 180) {
            headingDiff = 360 - headingDiff; // 원형 각도 보정 (359도 → 1도 = 2도 차이)
          }

          if (headingDiff < LocationConfig.minHeadingChange) {
            debugPrint(
              '[위치 저장] heading 변화 미미 (차이: ${headingDiff.toStringAsFixed(1)}도, 최소: ${LocationConfig.minHeadingChange}도) - 저장 중단',
            );
            return;
          }
        }
      }

      debugPrint(
        '[위치 저장] 저장 시작 - sessionId: $currentSessionId, accuracy: ${accuracy.toStringAsFixed(1)}m',
      );

      final apiService = ApiService();
      final batteryLevel = (location.battery.level * 100).toInt();

      // 최종 세션 ID 결정 (재확인 결과 사용)
      final finalSessionId = recheckSessionId ?? currentSessionId;

      // group_id 읽기
      final groupId = await AppCache.groupId;

      final saved = await apiService.saveLocation(
        userId: userId,
        latitude: location.coords.latitude,
        longitude: location.coords.longitude,
        accuracy: location.coords.accuracy,
        altitude: location.coords.altitude,
        speed: location.coords.speed,
        heading: location.coords.heading,
        batteryLevel: batteryLevel,
        movementSessionId: finalSessionId,
        activityType: location.activity.type,
        activityConfidence: location.activity.confidence,
        recordedAt: location.timestamp.toString(),
        groupId: groupId,
      );

      if (saved) {
        debugPrint('[위치 저장] 저장 성공 - sessionId: $currentSessionId');
        // 마지막 heading을 SharedPreferences에 저장
        await prefs.setDouble('last_location_heading', location.coords.heading);
      } else {
        debugPrint('[위치 저장] API 저장 실패 - 로컬 큐에 저장');
        await OfflineSyncService().pushLocation(
          userId: userId,
          latitude: location.coords.latitude,
          longitude: location.coords.longitude,
          tripId: groupId,
          accuracy: location.coords.accuracy,
          altitude: location.coords.altitude,
          speed: location.coords.speed,
          heading: location.coords.heading,
          batteryLevel: batteryLevel,
          batteryIsCharging: location.battery.isCharging,
          timestamp: DateTime.tryParse(location.timestamp),
        );
      }
    } catch (e) {
      debugPrint('[LocationService] _saveLocationDuringSession 실패: $e');
      // 에러 발생 시에도 로컬 큐에 저장 (네트워크 단절 등)
      try {
        final prefs = await SharedPreferences.getInstance();
        final userId = prefs.getString('user_id');
        if (userId != null) {
          final groupId = await AppCache.groupId;
          await OfflineSyncService().pushLocation(
            userId: userId,
            latitude: location.coords.latitude,
            longitude: location.coords.longitude,
            tripId: groupId,
            accuracy: location.coords.accuracy,
            altitude: location.coords.altitude,
            speed: location.coords.speed,
            heading: location.coords.heading,
            batteryLevel: (location.battery.level * 100).toInt(),
            batteryIsCharging: location.battery.isCharging,
            timestamp: DateTime.tryParse(location.timestamp),
          );
          debugPrint('[위치 저장] 예외 발생으로 인한 로컬 큐 저장 완료');
        }
      } catch (innerE) {
        debugPrint('[LocationService] 예외 처리 중 로컬 큐 저장 실패: $innerE');
      }
    }
  }
}

class LocationLog { // 이동 세션 ID (null이면 하트비트)

  LocationLog({
    required this.latitude,
    required this.longitude,
    this.accuracy,
    this.speed,
    this.heading,
    this.altitude,
    this.altitudeAccuracy,
    this.floor,
    required this.timestamp,
    required this.isMoving,
    this.uuid,
    this.event,
    this.odometer,
    this.activityType,
    this.activityConfidence,
    this.batteryLevel,
    this.batteryIsCharging,
    this.extras,
    this.movementSessionId,
  });
  final double latitude;
  final double longitude;
  final double? accuracy;
  final double? speed;
  final double? heading;
  final double? altitude;
  final double? altitudeAccuracy;
  final int? floor;
  final DateTime timestamp;
  final bool isMoving;
  final String? uuid;
  final String? event;
  final double? odometer;
  final String? activityType;
  final int? activityConfidence;
  final int? batteryLevel;
  final bool? batteryIsCharging;
  final Map<String, dynamic>? extras;
  final String? movementSessionId;

  // 하트비트인지 확인
  bool get isHeartbeat {
    // extras에 event가 heartbeat이거나 movement_session_id가 없으면 하트비트
    if (extras != null && extras!['event'] != null) {
      final eventType = extras!['event'] as String?;
      if (eventType == 'heartbeat' || eventType == 'initial_heartbeat') {
        return true;
      }
    }
    return movementSessionId == null;
  }

  String get formattedTime =>
      '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}';

  String get formattedDateTime =>
      '${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')} $formattedTime';
}
