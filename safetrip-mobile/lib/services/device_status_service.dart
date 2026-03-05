import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_background_geolocation/flutter_background_geolocation.dart'
    as bg;
import 'api_service.dart';
import 'offline_sync_service.dart';
import '../constants/event_types.dart';

class DeviceStatusService {
  factory DeviceStatusService() => _instance;
  DeviceStatusService._internal();
  static final DeviceStatusService _instance = DeviceStatusService._internal();

  final ApiService _apiService = ApiService();
  final OfflineSyncService _offlineSyncService = OfflineSyncService();
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  StreamSubscription<PermissionStatus>? _permissionSubscription;

  PermissionStatus? _lastPermissionStatus;
  String? _lastNetworkType;
  final Set<int> _batteryWarningSent = {};
  bool _isInitialized = false;

  /// 디바이스 상태 모니터링 초기화
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // 네트워크 상태 모니터링
      _initNetworkMonitoring();

      // 위치 권한 상태 모니터링
      _initPermissionMonitoring();

      _isInitialized = true;
      debugPrint('[DeviceStatusService] 초기화 완료');

      // 초기 동기화 시도
      _offlineSyncService.syncData(_apiService);
    } catch (e) {
      debugPrint('[DeviceStatusService] 초기화 실패: $e');
    }
  }

  /// 네트워크 상태 모니터링
  void _initNetworkMonitoring() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      ConnectivityResult result,
    ) async {
      try {
        final currentType = _convertConnectivityResult(result);
        final previousType = _lastNetworkType;

        if (result != ConnectivityResult.none) {
          // 연결됨 -> 데이터 동기화 시도
          debugPrint('[DeviceStatusService] 네트워크 연결됨 -> 오프라인 데이터 동기화 시도');
          _offlineSyncService.syncData(_apiService);
        }

        if (previousType != null && previousType != currentType) {
          final location = await _getCurrentLocation();

          await _apiService.recordEvent(
            eventType: EventTypes.deviceStatus,
            eventSubtype: DeviceStatusEventSubtypes.networkChange,
            latitude: location?.coords.latitude,
            longitude: location?.coords.longitude,
            batteryLevel: await _getBatteryLevel(),
            batteryIsCharging: await _getBatteryCharging(),
            networkType: currentType,
            appVersion: await _getAppVersion(),
            eventData: {
              'network': {
                'previous_type': previousType,
                'current_type': currentType,
                'connectivity_status': result != ConnectivityResult.none
                    ? 'connected'
                    : 'disconnected',
              },
            },
          );
        }

        _lastNetworkType = currentType;
      } catch (e) {
        debugPrint('[DeviceStatusService] 네트워크 상태 모니터링 실패: $e');
      }
    });
  }

  /// 위치 권한 상태 모니터링
  void _initPermissionMonitoring() {
    // 주기적으로 권한 상태 체크 (1시간마다)
    Timer.periodic(const Duration(hours: 1), (timer) async {
      try {
        await _checkLocationPermission();
      } catch (e) {
        debugPrint('[DeviceStatusService] 위치 권한 체크 실패: $e');
      }
    });
  }

  /// 위치 권한 상태 체크
  Future<void> _checkLocationPermission() async {
    try {
      final currentStatus = await Permission.location.status;
      final previousStatus = _lastPermissionStatus;

      if (previousStatus != null &&
          previousStatus.isGranted &&
          !currentStatus.isGranted) {
        await _apiService.recordEvent(
          eventType: EventTypes.deviceStatus,
          eventSubtype: DeviceStatusEventSubtypes.locationPermissionDenied,
          batteryLevel: await _getBatteryLevel(),
          batteryIsCharging: await _getBatteryCharging(),
          networkType: await _getNetworkType(),
          appVersion: await _getAppVersion(),
          eventData: {
            'permission': {
              'type': 'location',
              'previous_status': previousStatus.toString(),
              'current_status': currentStatus.toString(),
            },
          },
        );
      }

      _lastPermissionStatus = currentStatus;
    } catch (e) {
      debugPrint('[DeviceStatusService] 위치 권한 체크 실패: $e');
    }
  }

  /// 배터리 경고 체크 (location_service.dart에서 호출)
  Future<void> checkBatteryWarning(int? batteryLevel) async {
    if (batteryLevel == null) return;

    try {
      final warningLevels = [20, 10, 5];
      final warningLevel = warningLevels.firstWhere(
        (level) => batteryLevel <= level,
        orElse: () => -1,
      );

      if (warningLevel != -1 && !_batteryWarningSent.contains(warningLevel)) {
        final location = await _getCurrentLocation();

        await _apiService.recordEvent(
          eventType: EventTypes.deviceStatus,
          eventSubtype: DeviceStatusEventSubtypes.batteryWarning,
          latitude: location?.coords.latitude,
          longitude: location?.coords.longitude,
          batteryLevel: batteryLevel,
          batteryIsCharging: await _getBatteryCharging(),
          networkType: await _getNetworkType(),
          appVersion: await _getAppVersion(),
          eventData: {
            'battery': {
              'level': batteryLevel,
              'is_charging': await _getBatteryCharging(),
              'warning_level': warningLevel,
            },
          },
        );

        _batteryWarningSent.add(warningLevel);
      }
    } catch (e) {
      debugPrint('[DeviceStatusService] 배터리 경고 체크 실패: $e');
    }
  }

  /// 배터리 충전 상태 변화 체크 (location_service.dart에서 호출)
  Future<void> checkBatteryChargingChange(
    bool? currentCharging,
    bool? previousCharging,
    bg.Location location,
  ) async {
    if (currentCharging != null &&
        (previousCharging == null || currentCharging != previousCharging)) {
      try {
        // 배터리 레벨 계산
        final batteryLevel = (location.battery.level * 100).toInt();

        await _apiService.recordEvent(
          eventType: EventTypes.deviceStatus,
          eventSubtype: DeviceStatusEventSubtypes.batteryCharging,
          latitude: location.coords.latitude,
          longitude: location.coords.longitude,
          batteryLevel: batteryLevel,
          batteryIsCharging: currentCharging,
          networkType: await _getNetworkType(),
          appVersion: await _getAppVersion(),
          eventData: {
            'battery': {
              'level': batteryLevel,
              'is_charging': currentCharging,
              'charging_state': currentCharging ? 'started' : 'stopped',
            },
          },
        );
      } catch (e) {
        debugPrint('[DeviceStatusService] 배터리 충전 상태 변화 체크 실패: $e');
      }
    }
  }

  /// ConnectivityResult를 문자열로 변환
  String _convertConnectivityResult(ConnectivityResult result) {
    switch (result) {
      case ConnectivityResult.wifi:
        return 'wifi';
      case ConnectivityResult.mobile:
        return 'mobile';
      case ConnectivityResult.ethernet:
        return 'ethernet';
      case ConnectivityResult.none:
        return 'none';
      default:
        return 'unknown';
    }
  }

  /// 현재 위치 가져오기
  Future<dynamic> _getCurrentLocation() async {
    try {
      // LocationService에서 현재 위치를 가져오는 메서드가 있다면 사용
      // 없으면 null 반환
      return null;
    } catch (e) {
      return null;
    }
  }

  /// 배터리 레벨 가져오기
  Future<int?> _getBatteryLevel() async {
    try {
      // flutter_background_geolocation의 Location 객체에서 가져와야 함
      // 여기서는 null 반환 (실제로는 location_service.dart에서 전달받음)
      return null;
    } catch (e) {
      return null;
    }
  }

  /// 배터리 충전 상태 가져오기
  Future<bool?> _getBatteryCharging() async {
    try {
      // flutter_background_geolocation의 Location 객체에서 가져와야 함
      // 여기서는 null 반환 (실제로는 location_service.dart에서 전달받음)
      return null;
    } catch (e) {
      return null;
    }
  }

  /// 네트워크 타입 가져오기
  Future<String?> _getNetworkType() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      return _convertConnectivityResult(connectivityResult);
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

  /// 리소스 정리
  void dispose() {
    // Stream 구독 정리 (MissingPluginException 방지)
    try {
      _connectivitySubscription?.cancel();
    } catch (e) {
      // MissingPluginException 등 네이티브 플러그인 관련 오류는 무시
      // dispose 시점에 네이티브 플러그인이 이미 정리된 경우 발생할 수 있음
      debugPrint('[DeviceStatusService] Connectivity Stream 정리 중 오류 (무시): $e');
    }
    
    try {
      _permissionSubscription?.cancel();
    } catch (e) {
      debugPrint('[DeviceStatusService] Permission Stream 정리 중 오류 (무시): $e');
    }
    
    _connectivitySubscription = null;
    _permissionSubscription = null;
    _isInitialized = false;
  }
}
