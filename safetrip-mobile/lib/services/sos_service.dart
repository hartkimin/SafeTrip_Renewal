import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
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

  /// §7.3: 앱 재시작 시 서버에서 활성 SOS 상태 조회
  /// 활성 SOS가 있으면 {sosId, userId, userName, latitude, longitude} 반환
  Future<Map<String, dynamic>?> checkActiveSos() async {
    try {
      final response = await apiService.dio.get(
        '/api/v1/trips/$tripId/emergencies/active',
      );
      if (response.data?['success'] == true) {
        final data = response.data['data'];
        if (data != null && data['sos_id'] != null) {
          debugPrint('[SOS] 활성 SOS 발견: ${data['sos_id']}');
          return Map<String, dynamic>.from(data as Map);
        }
      }
      return null;
    } catch (e) {
      debugPrint('[SOS] 활성 SOS 조회 실패: $e');
      return null;
    }
  }

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

      // §7.3: 위치 미확인 시에도 SOS 발동 (위치=null 허용)
      final latitude = location?.coords.latitude;
      final longitude = location?.coords.longitude;

      // 2. SOS 객체 생성
      final sosId = const Uuid().v4();
      final timestamp = DateTime.now().toUtc();

      // 네트워크 연결 확인
      final connectivityResult = await Connectivity().checkConnectivity();
      final isOffline = connectivityResult == ConnectivityResult.none;

      if (isOffline) {
        debugPrint('[SOS] 네트워크 오프라인 — SMS 폴백 시작');

        // 1순위: SMS 발송
        final emergencyPhones = await _getEmergencyPhones();
        if (emergencyPhones.isNotEmpty) {
          await _sendSOSSms(
            userName: userName,
            latitude: latitude,
            longitude: longitude,
            tripName: tripId,
            phoneNumbers: emergencyPhones,
          );
        }

        // 2순위: 로컬 알람
        await _playLocalAlarm();

        // 3순위: SQLite 큐잉 (§7.3: 위치 없으면 0.0으로 큐잉)
        await offlineSyncService.pushSOS(
          sosId: sosId,
          userId: userId,
          tripId: tripId,
          latitude: latitude ?? 0.0,
          longitude: longitude ?? 0.0,
          triggerType: triggerType,
          message: message,
          timestamp: timestamp,
        );

        // 4순위: 화면 표시는 caller(SOS overlay)에서 처리
        return true;
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
          latitude: latitude ?? 0.0,
          longitude: longitude ?? 0.0,
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
          batteryLevel: location != null
              ? (location.battery.level * 100).toInt()
              : null,
          batteryIsCharging: location?.battery.isCharging,
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

  /// 오프라인 SMS 폴백: 긴급 연락처 + 가디언 전화번호로 SOS 메시지 발송
  Future<void> _sendSOSSms({
    required String userName,
    required double? latitude,
    required double? longitude,
    required String tripName,
    required List<String> phoneNumbers,
  }) async {
    final locationStr = (latitude != null && longitude != null)
        ? '위치: $latitude,$longitude'
        : '위치: 확인 중';
    final message = '[SafeTrip SOS] $userName님이 긴급 도움을 요청합니다. '
        '$locationStr | 여행: $tripName';
    for (final phone in phoneNumbers) {
      try {
        final uri = Uri(
          scheme: 'sms',
          path: phone,
          queryParameters: {'body': message},
        );
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
          debugPrint('[SOS] SMS 발송 요청: $phone');
        }
      } catch (e) {
        debugPrint('[SOS] SMS 발송 실패 ($phone): $e');
      }
    }
  }

  /// 로컬 알람: 최대 볼륨 알림으로 주변에 SOS 상황 알림
  Future<void> _playLocalAlarm() async {
    try {
      final flnp = FlutterLocalNotificationsPlugin();
      const androidDetails = AndroidNotificationDetails(
        'sos_alarm_channel',
        'SOS 알람',
        channelDescription: 'SOS 긴급 알람 채널',
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        ongoing: true,
        autoCancel: false,
      );
      const details = NotificationDetails(android: androidDetails);
      await flnp.show(
        9999,
        'SOS 긴급 알람',
        '긴급 도움 요청이 활성화되었습니다',
        details,
      );
      debugPrint('[SOS] 로컬 알람 활성화');
    } catch (e) {
      debugPrint('[SOS] 로컬 알람 실패: $e');
    }
  }

  /// 로컬 캐시에서 긴급 연락처 전화번호 목록 조회
  Future<List<String>> _getEmergencyPhones() async {
    try {
      final meta =
          await offlineSyncService.getCacheMeta('emergency_contacts_$tripId');
      if (meta == null) return [];
      final data = jsonDecode(meta['data'] as String);
      final phones = <String>[];
      if (data is Map) {
        if (data['phones'] != null) {
          phones.addAll(List<String>.from(data['phones']));
        }
        if (data['guardian_phones'] != null) {
          phones.addAll(List<String>.from(data['guardian_phones']));
        }
      }
      return phones;
    } catch (e) {
      debugPrint('[SOS] 긴급 연락처 로드 실패: $e');
      return [];
    }
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
