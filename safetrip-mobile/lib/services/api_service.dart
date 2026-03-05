import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'device_id_service.dart';

/// SafeTrip 백엔드 API 서비스
class ApiService {
  late final Dio _dio;
  final String baseUrl;

  ApiService({String? baseUrl})
    : baseUrl =
          baseUrl ??
          (dotenv.env['API_SERVER_URL'] ??
              'http://safetrip-api-alb-1981037397.ap-northeast-2.elb.amazonaws.com') {
    _dio = Dio(
      BaseOptions(
        baseUrl: this.baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    // 인증 토큰 인터셉터
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          try {
            final user = FirebaseAuth.instance.currentUser;
            if (user != null) {
              final freshToken = await user.getIdToken();
              if (freshToken != null && freshToken.isNotEmpty) {
                options.headers['Authorization'] = 'Bearer $freshToken';
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('firebase_id_token', freshToken);
              }
            } else {
              final prefs = await SharedPreferences.getInstance();
              final savedToken = prefs.getString('firebase_id_token');
              if (savedToken != null && savedToken.isNotEmpty) {
                options.headers['Authorization'] = 'Bearer $savedToken';
              }
            }
          } catch (e) {
            debugPrint('[ApiService] Token Interceptor Error: $e');
          }
          handler.next(options);
        },
      ),
    );
  }

  // Firebase ID Token으로 서버와 사용자 동기화
  Future<Map<String, dynamic>?> syncUserWithFirebase(
    String idToken,
    String phoneCountryCode, {
    bool isTestDevice = false,
    String? testPhoneNumber,
  }) async {
    try {
      final installId = await DeviceIdService.getInstallId();

      final data = <String, dynamic>{
        'id_token': idToken,
        'phone_country_code': phoneCountryCode,
        'install_id': installId,
      };

      if (isTestDevice) {
        data['is_test_device'] = true;
        if (testPhoneNumber != null) {
          data['test_phone_number'] = testPhoneNumber;
        }
      }

      final response = await _dio.post(
        '/api/v1/auth/firebase-verify',
        data: data,
      );

      if (response.data['success'] == true && response.data['data'] != null) {
        final userData = response.data['data'] as Map<String, dynamic>;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('firebase_id_token', idToken);
        return userData;
      }
      return null;
    } catch (e) {
      debugPrint('[ApiService] syncUserWithFirebase Error: $e');
      return null;
    }
  }

  // 사용자 프로필 업데이트
  Future<Map<String, dynamic>?> updateUserProfile(
    String userId,
    String displayName, {
    String? birthDate,
    String? profilePhotoUrl,
    String? emergencyContact,
  }) async {
    try {
      final data = <String, dynamic>{'display_name': displayName};
      if (birthDate != null) data['date_of_birth'] = birthDate;
      if (profilePhotoUrl != null) data['profile_image_url'] = profilePhotoUrl;
      if (emergencyContact != null) {
        data['emergency_contact'] = emergencyContact;
      }

      final response = await _dio.put('/api/v1/users/$userId', data: data);
      return response.data['data'];
    } catch (e) {
      debugPrint('[ApiService] updateUserProfile Error: $e');
      rethrow;
    }
  }

  // 약관 동의 저장
  Future<bool> saveConsent({
    required String role,
    required bool termsOfService,
    required bool privacyPolicy,
    required bool locationTerms,
    required bool marketingConsent,
  }) async {
    try {
      final response = await _dio.post(
        '/api/v1/users/consent',
        data: {
          'role': role,
          'terms_of_service': termsOfService,
          'privacy_policy': privacyPolicy,
          'location_terms': locationTerms,
          'marketing_consent': marketingConsent,
        },
      );
      return response.data['success'] == true;
    } catch (e) {
      debugPrint('[ApiService] saveConsent Error: $e');
      return false;
    }
  }

  // 여행 생성
  Future<Map<String, dynamic>?> createTrip({
    required String title,
    required String countryCode,
    required String tripType,
    required String startDate,
    required String endDate,
    String? countryName,
    String? privacyLevel,
    String? sharingMode,
  }) async {
    try {
      final data = <String, dynamic>{
        'title': title,
        'country_code': countryCode,
        'trip_type': tripType,
        'start_date': startDate,
        'end_date': endDate,
      };
      if (countryName != null) data['country_name'] = countryName;
      if (privacyLevel != null) data['privacy_level'] = privacyLevel;
      if (sharingMode != null) data['sharing_mode'] = sharingMode;

      final response = await _dio.post('/api/v1/trips', data: data);
      if (response.data['success'] == true && response.data['data'] != null) {
        return response.data['data'] as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('[ApiService] createTrip Error: $e');
      return null;
    }
  }

  // 사용자 조회
  Future<Map<String, dynamic>?> getUserById(String userId) async {
    try {
      final response = await _dio.get('/api/v1/users/$userId');
      if (response.data['success'] == true) {
        return response.data['data'];
      }
      return null;
    } catch (e) {
      debugPrint('[ApiService] getUserById Error: $e');
      return null;
    }
  }

  // 내 권한 조회
  Future<Map<String, dynamic>?> getMyPermission(String groupId) async {
    try {
      final response = await _dio.get('/api/v1/groups/$groupId/my-permission');
      if (response.data['success'] == true) {
        return response.data['data'];
      }
      return null;
    } catch (e) {
      debugPrint('[ApiService] getMyPermission Error: $e');
      return null;
    }
  }

  // 그룹 멤버 목록 조회
  Future<List<Map<String, dynamic>>> getGroupMembers(String groupId) async {
    try {
      final response = await _dio.get('/api/v1/groups/$groupId/members');
      if (response.data['success'] == true && response.data['data'] != null) {
        return List<Map<String, dynamic>>.from(response.data['data']);
      }
      return [];
    } catch (e) {
      debugPrint('[ApiService] getGroupMembers Error: $e');
      return [];
    }
  }

  // 국가 목록 조회
  Future<List<Map<String, dynamic>>> getCountries() async {
    try {
      final response = await _dio.get('/api/v1/meta/countries');
      if (response.data['success'] == true && response.data['data'] != null) {
        return List<Map<String, dynamic>>.from(response.data['data']);
      }
      return [];
    } catch (e) {
      debugPrint('[ApiService] getCountries Error: $e');
      return [];
    }
  }

  // SOS 전송
  Future<Map<String, dynamic>?> sendSOS(Map<String, dynamic> sosData) async {
    try {
      final response = await _dio.post('/api/v1/sos', data: sosData);
      if (response.data['success'] == true) {
        return response.data['data'];
      }
      return null;
    } catch (e) {
      debugPrint('[ApiService] sendSOS Error: $e');
      return null;
    }
  }

  /// 오프라인 위치 데이터 벌크 동기화
  Future<bool> syncOfflineLocations(
    List<Map<String, dynamic>> locations,
  ) async {
    try {
      final response = await _dio.post(
        '/api/v1/location/sync',
        data: {'locations': locations},
      );
      return response.data['success'] == true;
    } catch (e) {
      debugPrint('[ApiService] syncOfflineLocations Error: $e');
      return false;
    }
  }

  // 이벤트 기록
  Future<bool> recordEvent({
    required String eventType,
    required String eventSubtype,
    String? movementSessionId,
    String? sosId,
    String? geofenceId,
    double? latitude,
    double? longitude,
    String? address,
    int? batteryLevel,
    bool? batteryIsCharging,
    String? networkType,
    String? appVersion,
    Map<String, dynamic>? eventData,
    DateTime? occurredAt,
  }) async {
    try {
      final data = <String, dynamic>{
        'event_type': eventType,
        'event_subtype': eventSubtype,
        'movement_session_id': movementSessionId,
        'sos_id': sosId,
        'geofence_id': geofenceId,
        'latitude': latitude,
        'longitude': longitude,
        'address': address,
        'battery_level': batteryLevel,
        'battery_is_charging': batteryIsCharging,
        'network_type': networkType,
        'app_version': appVersion,
        'event_data': eventData,
        'occurred_at': occurredAt?.toIso8601String(),
      };

      final response = await _dio.post('/api/v1/events', data: data);
      return response.data['success'] == true;
    } catch (e) {
      debugPrint('[ApiService] recordEvent Error: $e');
      return false;
    }
  }

  // 위치 저장
  Future<bool> saveLocation({
    required String userId,
    required double latitude,
    required double longitude,
    String? address,
    double? accuracy,
    double? altitude,
    double? speed,
    double? heading,
    int? batteryLevel,
    String? movementSessionId,
    String? activityType,
    int? activityConfidence,
    String? recordedAt,
    String? groupId,
  }) async {
    try {
      final data = <String, dynamic>{
        'user_id': userId,
        'latitude': latitude,
        'longitude': longitude,
        'address': address,
        'accuracy': accuracy,
        'altitude': altitude,
        'speed': speed,
        'heading': heading,
        'battery_level': batteryLevel,
        'movement_session_id': movementSessionId,
        'activity_type': activityType,
        'activity_confidence': activityConfidence,
        'recorded_at': recordedAt,
        'group_id': groupId,
      };

      final response = await _dio.post('/api/v1/locations', data: data);
      return response.data['success'] == true;
    } catch (e) {
      debugPrint('[ApiService] saveLocation Error: $e');
      return false;
    }
  }

  // FCM 토큰 등록
  Future<bool> registerFCMToken(String token, {String? deviceId}) async {
    try {
      final response = await _dio.post(
        '/api/v1/fcm/token',
        data: {'token': token, 'deviceId': deviceId},
      );
      return response.data['success'] == true;
    } catch (e) {
      debugPrint('[ApiService] registerFCMToken Error: $e');
      return false;
    }
  }

  // FCM 토큰 무효화 (로그아웃/앱 삭제 시)
  Future<bool> invalidateFCMToken(String token) async {
    try {
      final response = await _dio.delete(
        '/api/v1/fcm/token',
        data: {'token': token},
      );
      return response.data['success'] == true;
    } catch (e) {
      debugPrint('[ApiService] invalidateFCMToken Error: $e');
      return false;
    }
  }

  // 초대 코드로 여행 미리보기
  Future<Map<String, dynamic>?> previewByInviteCode(String code) async {
    try {
      final response = await _dio.get('/api/v1/groups/preview/$code');
      if (response.data['success'] == true) {
        return response.data['data'];
      }
      return null;
    } catch (e) {
      debugPrint('[ApiService] previewByInviteCode Error: $e');
      return null;
    }
  }

  // ===== 출석 (Attendance) =====

  Future<List<Map<String, dynamic>>> getAttendances(String tripId) async {
    try {
      final response = await _dio.get('/api/v1/trips/$tripId/attendances');
      if (response.data['success'] == true && response.data['data'] != null) {
        return List<Map<String, dynamic>>.from(response.data['data']);
      }
      return [];
    } catch (e) {
      debugPrint('[ApiService] getAttendances Error: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> startAttendance(String tripId) async {
    try {
      final response = await _dio.post('/api/v1/trips/$tripId/attendances');
      return response.data as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[ApiService] startAttendance Error: $e');
      rethrow;
    }
  }

  Future<bool> respondAttendance(
    String tripId,
    String checkId,
    String responseType,
  ) async {
    try {
      final response = await _dio.post(
        '/api/v1/trips/$tripId/attendances/$checkId/respond',
        data: {'response_type': responseType},
      );
      return response.data['success'] == true;
    } catch (e) {
      debugPrint('[ApiService] respondAttendance Error: $e');
      return false;
    }
  }

  Future<bool> closeAttendance(String tripId, String checkId) async {
    try {
      final response = await _dio.post(
        '/api/v1/trips/$tripId/attendances/$checkId/close',
      );
      return response.data['success'] == true;
    } catch (e) {
      debugPrint('[ApiService] closeAttendance Error: $e');
      return false;
    }
  }

  // ===== 그룹 (Group) =====

  Future<List<Map<String, dynamic>>> getGroups() async {
    try {
      final response = await _dio.get('/api/v1/groups');
      if (response.data['success'] == true && response.data['data'] != null) {
        return List<Map<String, dynamic>>.from(response.data['data']);
      }
      return [];
    } catch (e) {
      debugPrint('[ApiService] getGroups Error: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> createGroup(Map<String, dynamic> data) async {
    try {
      final response = await _dio.post('/api/v1/groups', data: data);
      return response.data as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[ApiService] createGroup Error: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getTrips(String groupId) async {
    try {
      final response = await _dio.get('/api/v1/groups/$groupId/trips');
      if (response.data['success'] == true && response.data['data'] != null) {
        return List<Map<String, dynamic>>.from(response.data['data']);
      }
      return [];
    } catch (e) {
      debugPrint('[ApiService] getTrips Error: $e');
      return [];
    }
  }

  // ===== 지오펜스 (Geofence) =====

  Future<List<Map<String, dynamic>>> getGeofences({
    required String groupId,
  }) async {
    try {
      final response = await _dio.get('/api/v1/groups/$groupId/geofences');
      if (response.data['success'] == true && response.data['data'] != null) {
        return List<Map<String, dynamic>>.from(response.data['data']);
      }
      return [];
    } catch (e) {
      debugPrint('[ApiService] getGeofences Error: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getGeofenceById({
    required String geofenceId,
    String? groupId,
  }) async {
    try {
      final response = await _dio.get('/api/v1/geofences/$geofenceId');
      if (response.data['success'] == true) {
        return response.data['data'] as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      debugPrint('[ApiService] getGeofenceById Error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> createGeofence({
    required String groupId,
    String? userId,
    required String name,
    String? description,
    String? type,
    String? shapeType,
    required double centerLatitude,
    required double centerLongitude,
    num? radiusMeters,
    bool? isAlwaysActive,
    bool? triggerOnEnter,
    bool? triggerOnExit,
    bool? notifyGroup,
    bool? notifyGuardians,
  }) async {
    try {
      final data = <String, dynamic>{
        'group_id': groupId,
        'name': name,
        'center_latitude': centerLatitude,
        'center_longitude': centerLongitude,
      };
      if (userId != null) data['user_id'] = userId;
      if (description != null) data['description'] = description;
      if (type != null) data['type'] = type;
      if (shapeType != null) data['shape_type'] = shapeType;
      if (radiusMeters != null) data['radius_meters'] = radiusMeters;
      if (isAlwaysActive != null) data['is_always_active'] = isAlwaysActive;
      if (triggerOnEnter != null) data['trigger_on_enter'] = triggerOnEnter;
      if (triggerOnExit != null) data['trigger_on_exit'] = triggerOnExit;
      if (notifyGroup != null) data['notify_group'] = notifyGroup;
      if (notifyGuardians != null) data['notify_guardians'] = notifyGuardians;
      final response = await _dio.post('/api/v1/geofences', data: data);
      if (response.data['success'] == true) {
        return response.data['data'] as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      debugPrint('[ApiService] createGeofence Error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> updateGeofence({
    required String geofenceId,
    String? groupId,
    String? name,
    String? description,
    String? type,
    String? shapeType,
    double? centerLatitude,
    double? centerLongitude,
    num? radiusMeters,
    bool? triggerOnEnter,
    bool? triggerOnExit,
    bool? notifyGroup,
    bool? notifyGuardians,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (groupId != null) data['group_id'] = groupId;
      if (name != null) data['name'] = name;
      if (description != null) data['description'] = description;
      if (type != null) data['type'] = type;
      if (shapeType != null) data['shape_type'] = shapeType;
      if (centerLatitude != null) data['center_latitude'] = centerLatitude;
      if (centerLongitude != null) data['center_longitude'] = centerLongitude;
      if (radiusMeters != null) data['radius_meters'] = radiusMeters;
      if (triggerOnEnter != null) data['trigger_on_enter'] = triggerOnEnter;
      if (triggerOnExit != null) data['trigger_on_exit'] = triggerOnExit;
      if (notifyGroup != null) data['notify_group'] = notifyGroup;
      if (notifyGuardians != null) data['notify_guardians'] = notifyGuardians;
      final response = await _dio.put(
        '/api/v1/geofences/$geofenceId',
        data: data,
      );
      if (response.data['success'] == true) {
        return response.data['data'] as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      debugPrint('[ApiService] updateGeofence Error: $e');
      return null;
    }
  }

  // ===== 스케줄 (Schedule) =====

  Future<Map<String, dynamic>?> createSchedule({
    String? groupId,
    String? userId,
    String? tripId,
    required String title,
    String? description,
    String? scheduleType,
    dynamic startTime,
    dynamic endTime,
    String? locationName,
    String? locationAddress,
    Map<String, dynamic>? locationCoords,
    bool? reminderEnabled,
    int? reminderTime,
    bool? geofenceEnabled,
    bool? geofenceTriggerOnEnter,
    bool? geofenceTriggerOnExit,
    num? geofenceRadiusMeters,
    String? timezone,
  }) async {
    try {
      final data = <String, dynamic>{'title': title};
      if (groupId != null) data['group_id'] = groupId;
      if (userId != null) data['user_id'] = userId;
      if (tripId != null) data['trip_id'] = tripId;
      if (description != null) data['description'] = description;
      if (scheduleType != null) data['schedule_type'] = scheduleType;
      if (startTime != null) {
        data['start_time'] = startTime is DateTime
            ? startTime.toIso8601String()
            : startTime;
      }
      if (endTime != null) {
        data['end_time'] = endTime is DateTime
            ? endTime.toIso8601String()
            : endTime;
      }
      if (locationName != null) data['location_name'] = locationName;
      if (locationAddress != null) data['location_address'] = locationAddress;
      if (locationCoords != null) data['location_coords'] = locationCoords;
      if (reminderEnabled != null) data['reminder_enabled'] = reminderEnabled;
      if (reminderTime != null) data['reminder_time'] = reminderTime;
      if (geofenceEnabled != null) data['geofence_enabled'] = geofenceEnabled;
      if (geofenceTriggerOnEnter != null) {
        data['geofence_trigger_on_enter'] = geofenceTriggerOnEnter;
      }
      if (geofenceTriggerOnExit != null) {
        data['geofence_trigger_on_exit'] = geofenceTriggerOnExit;
      }
      if (geofenceRadiusMeters != null) {
        data['geofence_radius_meters'] = geofenceRadiusMeters;
      }
      if (timezone != null) data['timezone'] = timezone;
      final response = await _dio.post('/api/v1/schedules', data: data);
      if (response.data['success'] == true) {
        return response.data['data'] as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      debugPrint('[ApiService] createSchedule Error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> updateSchedule({
    required String scheduleId,
    String? groupId,
    String? userId,
    String? title,
    String? description,
    String? scheduleType,
    String? startTime,
    String? endTime,
    String? locationName,
    String? locationAddress,
    Map<String, dynamic>? locationCoords,
    bool? reminderEnabled,
    int? reminderTime,
    bool? geofenceEnabled,
    bool? geofenceTriggerOnEnter,
    bool? geofenceTriggerOnExit,
    num? geofenceRadiusMeters,
    String? timezone,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (groupId != null) data['group_id'] = groupId;
      if (userId != null) data['user_id'] = userId;
      if (title != null) data['title'] = title;
      if (description != null) data['description'] = description;
      if (scheduleType != null) data['schedule_type'] = scheduleType;
      if (startTime != null) data['start_time'] = startTime;
      if (endTime != null) data['end_time'] = endTime;
      if (locationName != null) data['location_name'] = locationName;
      if (locationAddress != null) data['location_address'] = locationAddress;
      if (locationCoords != null) data['location_coords'] = locationCoords;
      if (reminderEnabled != null) data['reminder_enabled'] = reminderEnabled;
      if (reminderTime != null) data['reminder_time'] = reminderTime;
      if (geofenceEnabled != null) data['geofence_enabled'] = geofenceEnabled;
      if (geofenceTriggerOnEnter != null) {
        data['geofence_trigger_on_enter'] = geofenceTriggerOnEnter;
      }
      if (geofenceTriggerOnExit != null) {
        data['geofence_trigger_on_exit'] = geofenceTriggerOnExit;
      }
      if (geofenceRadiusMeters != null) {
        data['geofence_radius_meters'] = geofenceRadiusMeters;
      }
      if (timezone != null) data['timezone'] = timezone;
      final response = await _dio.put(
        '/api/v1/schedules/$scheduleId',
        data: data,
      );
      if (response.data['success'] == true) {
        return response.data['data'] as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      debugPrint('[ApiService] updateSchedule Error: $e');
      return null;
    }
  }

  Future<bool> deleteSchedule({
    String? groupId,
    required String scheduleId,
  }) async {
    try {
      final response = await _dio.delete('/api/v1/schedules/$scheduleId');
      return response.data['success'] == true;
    } catch (e) {
      debugPrint('[ApiService] deleteSchedule Error: $e');
      return false;
    }
  }

  Future<bool> updateScheduleGeofenceId({
    required String scheduleId,
    String? geofenceId,
  }) async {
    try {
      final response = await _dio.patch(
        '/api/v1/schedules/$scheduleId/geofence',
        data: {'geofence_id': geofenceId},
      );
      return response.data['success'] == true;
    } catch (e) {
      debugPrint('[ApiService] updateScheduleGeofenceId Error: $e');
      return false;
    }
  }

  // ===== 초대 코드 (Invite Code) =====

  Future<Map<String, dynamic>?> createInviteCode({
    required String groupId,
    String? targetRole,
    int? maxUses,
    int? expiresInDays,
  }) async {
    try {
      final data = <String, dynamic>{'group_id': groupId};
      if (targetRole != null) data['target_role'] = targetRole;
      if (maxUses != null) data['max_uses'] = maxUses;
      if (expiresInDays != null) data['expires_in_days'] = expiresInDays;
      final response = await _dio.post(
        '/api/v1/groups/$groupId/invite-codes',
        data: data,
      );
      if (response.data['success'] == true) {
        return response.data['data'] as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      debugPrint('[ApiService] createInviteCode Error: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getInviteCodesByGroup(
    String groupId,
  ) async {
    try {
      final response = await _dio.get('/api/v1/groups/$groupId/invite-codes');
      if (response.data['success'] == true && response.data['data'] != null) {
        return List<Map<String, dynamic>>.from(response.data['data']);
      }
      return [];
    } catch (e) {
      debugPrint('[ApiService] getInviteCodesByGroup Error: $e');
      return [];
    }
  }

  Future<bool> deactivateInviteCode({
    String? groupId,
    required String codeId,
  }) async {
    try {
      final response = await _dio.delete('/api/v1/invite-codes/$codeId');
      return response.data['success'] == true;
    } catch (e) {
      debugPrint('[ApiService] deactivateInviteCode Error: $e');
      return false;
    }
  }

  // ===== 사용자/멤버 (User/Member) =====

  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    try {
      final response = await _dio.get(
        '/api/v1/users/search',
        queryParameters: {'q': query},
      );
      if (response.data['success'] == true && response.data['data'] != null) {
        return List<Map<String, dynamic>>.from(response.data['data']);
      }
      return [];
    } catch (e) {
      debugPrint('[ApiService] searchUsers Error: $e');
      return [];
    }
  }

  Future<bool> inviteUserToGroup({
    required String groupId,
    required String targetUserId,
    String? role,
  }) async {
    try {
      final data = <String, dynamic>{'user_id': targetUserId};
      if (role != null) data['role'] = role;
      final response = await _dio.post(
        '/api/v1/groups/$groupId/members',
        data: data,
      );
      return response.data['success'] == true;
    } catch (e) {
      debugPrint('[ApiService] inviteUserToGroup Error: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> transferLeadership({
    required String groupId,
    required String toUserId,
  }) async {
    try {
      final response = await _dio.post(
        '/api/v1/groups/$groupId/transfer-leadership',
        data: {'target_user_id': toUserId},
      );
      if (response.data['success'] == true) {
        return response.data['data'] as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      debugPrint('[ApiService] transferLeadership Error: $e');
      return null;
    }
  }

  // ===== 위치 공유/프라이버시 (Location Sharing) =====

  Future<bool> updateLocationSharingStatus({
    String? userId,
    String? groupId,
    required bool enabled,
  }) async {
    try {
      final endpoint = userId != null
          ? '/api/v1/users/$userId/location-sharing'
          : '/api/v1/groups/$groupId/location-sharing';
      final response = await _dio.put(endpoint, data: {'is_sharing': enabled});
      return response.data['success'] == true;
    } catch (e) {
      debugPrint('[ApiService] updateLocationSharingStatus Error: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>?> getSharingSettings(
    String tripId,
    String userId,
  ) async {
    try {
      final response = await _dio.get(
        '/api/v1/trips/$tripId/sharing',
        queryParameters: {'user_id': userId},
      );
      if (response.data['success'] == true && response.data['data'] != null) {
        return List<Map<String, dynamic>>.from(response.data['data']);
      }
      return null;
    } catch (e) {
      debugPrint('[ApiService] getSharingSettings Error: $e');
      return null;
    }
  }

  Future<bool> updateSharing(
    String tripId,
    String userId,
    bool isSharing,
    String visibility,
  ) async {
    try {
      final response = await _dio.put(
        '/api/v1/trips/$tripId/sharing',
        data: {
          'user_id': userId,
          'is_sharing': isSharing,
          'visibility_type': visibility,
        },
      );
      return response.data['success'] == true;
    } catch (e) {
      debugPrint('[ApiService] updateSharing Error: $e');
      return false;
    }
  }

  // ===== 세션/위치 이력 (Session/Location History) =====

  Future<List<Map<String, dynamic>>> getLocationHistory(
    String userId, {
    int limit = 100,
  }) async {
    try {
      final response = await _dio.get(
        '/api/v1/users/$userId/locations',
        queryParameters: {'limit': limit},
      );
      if (response.data['success'] == true && response.data['data'] != null) {
        return List<Map<String, dynamic>>.from(response.data['data']);
      }
      return [];
    } catch (e) {
      debugPrint('[ApiService] getLocationHistory Error: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getSessionDateRange({
    required String userId,
  }) async {
    try {
      final response = await _dio.get(
        '/api/v1/sessions/date-range',
        queryParameters: {'user_id': userId},
      );
      if (response.data['success'] == true) {
        return response.data['data'] as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      debugPrint('[ApiService] getSessionDateRange Error: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getMovementSessionsByDate({
    required String userId,
    required String date,
    List<String>? needImages,
  }) async {
    try {
      final queryParams = <String, dynamic>{'user_id': userId, 'date': date};
      if (needImages != null) queryParams['need_images'] = needImages.join(',');

      final response = await _dio.get(
        '/api/v1/sessions',
        queryParameters: queryParams,
      );
      if (response.data['success'] == true && response.data['data'] != null) {
        return List<Map<String, dynamic>>.from(response.data['data']);
      }
      return [];
    } catch (e) {
      debugPrint('[ApiService] getMovementSessionsByDate Error: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getMovementSessionDetail({
    required String userId,
    required String sessionId,
  }) async {
    try {
      final response = await _dio.get(
        '/api/v1/sessions/$sessionId',
        queryParameters: {'user_id': userId},
      );
      if (response.data['success'] == true) {
        return response.data['data'] as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      debugPrint('[ApiService] getMovementSessionDetail Error: $e');
      return null;
    }
  }

  // ===== 타임존/국가 코드 (Timezone/Country) =====

  Future<List<Map<String, dynamic>>> getTimezonesByGroupId(
    String groupId,
  ) async {
    try {
      final response = await _dio.get('/api/v1/groups/$groupId/timezones');
      if (response.data['success'] == true && response.data['data'] != null) {
        return List<Map<String, dynamic>>.from(response.data['data']);
      }
      return [];
    } catch (e) {
      debugPrint('[ApiService] getTimezonesByGroupId Error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getCountryCodesByGroupId(
    String groupId,
  ) async {
    try {
      final response = await _dio.get('/api/v1/groups/$groupId/country-codes');
      if (response.data['success'] == true && response.data['data'] != null) {
        return List<Map<String, dynamic>>.from(response.data['data']);
      }
      return [];
    } catch (e) {
      debugPrint('[ApiService] getCountryCodesByGroupId Error: $e');
      return [];
    }
  }
}
