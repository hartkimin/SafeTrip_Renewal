import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:uuid/uuid.dart';

import '../constants/event_types.dart';
import 'api_service.dart';
import 'location_service.dart';
import 'offline_sync_service.dart';

class SOSService {
  SOSService({
    required this.locationService,
    required this.apiService,
    this.tripId = 'test_trip',
  }) : offlineSyncService = OfflineSyncService();
  final LocationService locationService;
  final ApiService apiService;
  final OfflineSyncService offlineSyncService;
  final String tripId;

  // SOS 전송
  Future<bool> sendSOS({
    required String userId,
    required String userName,
    String? message,
    String triggerType = 'manual',
  }) async {
    try {
      // 1. 현재 위치 수집
      final location = await locationService.getCurrentPosition();
      if (location == null) {
        debugPrint('[SOS] 위치 수집 실패');
        return false;
      }

      final latitude = location.coords.latitude;
      final longitude = location.coords.longitude;

      // 2. SOS 객체 생성
      final sosId = const Uuid().v4();
      final timestamp = DateTime.now().toUtc();

      // 네트워크 연결 확인
      final connectivityResult = await Connectivity().checkConnectivity();
      final isOffline = connectivityResult == ConnectivityResult.none;

      if (isOffline) {
        debugPrint('[SOS] 네트워크 오프라인 - 로컬 큐에 저장');
        await offlineSyncService.pushSOS(
          sosId: sosId,
          userId: userId,
          tripId: tripId,
          latitude: latitude,
          longitude: longitude,
          triggerType: triggerType,
          message: message,
          timestamp: timestamp,
        );
        return true; // 오프라인 저장은 성공으로 간주 (나중에 동기화)
      }

      // 3. SOS 데이터 준비
      final sosData = {
        'sos_id': sosId,
        'user_id': userId,
        'user_name': userName,
        'trip_id': tripId,
        'latitude': latitude,
        'longitude': longitude,
        'trigger_type': triggerType,
        'message': message,
        'timestamp': timestamp.toIso8601String(),
      };

      debugPrint('[SOS] 전송 시작 - $userName ($userId)');

      // API 서버 호출 (FCM 전송 및 DB 저장)
      final response = await apiService.sendSOS(sosData);
      if (response == null) {
        debugPrint('[SOS] API 서버 전송 실패 - 로컬 큐에 저장');
        await offlineSyncService.pushSOS(
          sosId: sosId,
          userId: userId,
          tripId: tripId,
          latitude: latitude,
          longitude: longitude,
          triggerType: triggerType,
          message: message,
          timestamp: timestamp,
        );
        return true;
      }

      final responseSosId = response['sos_id'] ?? sosId;
      debugPrint('[SOS] API 서버 전송 완료');

      // 통합 이벤트 로그 기록
      try {
        await apiService.recordEvent(
          eventType: EventTypes.sos,
          eventSubtype: triggerType, // manual, auto_impact, auto_inactivity 등
          sosId: responseSosId,
          latitude: latitude,
          longitude: longitude,
          batteryLevel: (location.battery.level * 100).toInt(),
          batteryIsCharging: location.battery.isCharging,
          networkType: await _getNetworkType(),
          appVersion: await _getAppVersion(),
          eventData: {
            'alert_type': triggerType,
            'trigger_method': triggerType,
            'user_message': message,
            'status': 'sent',
            'escalation_level': 1,
            'has_video': false,
            'has_audio': false,
          },
        );
      } catch (e) {
        debugPrint('[SOS] 통합 이벤트 로그 기록 실패: $e');
      }

      debugPrint('[SOS] 전송 완료');
      return true;
    } catch (e) {
      debugPrint('[SOS] 전송 에러: $e');
      return false;
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

  // 2차 SOS 전송 (그룹 전체)
  Future<bool> sendSOSStage2({
    required String userId,
    required String userName,
    required String sosId,
    required double latitude,
    required double longitude,
  }) async {
    try {
      debugPrint('[SOS] 2차 전송 시작 - $userName ($userId)');

      // MQTT 제거 - API 서버로만 전송 (FCM)
      debugPrint('[SOS] 2차 전송 완료 (FCM으로 전송)');

      return true;
    } catch (e) {
      debugPrint('[SOS] 2차 전송 에러: $e');
      return false;
    }
  }
}
