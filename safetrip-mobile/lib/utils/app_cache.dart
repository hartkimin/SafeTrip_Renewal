import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/geofence.dart';
import '../models/schedule.dart';

/// 앱 전역 정적 데이터를 메모리와 디스크에 캐싱하는 유틸리티 클래스
///
/// 포어그라운드와 백그라운드(헤드리스) 모두에서 사용 가능하며,
/// SharedPreferences 호출을 최소화하여 ANR을 방지합니다.
///
/// 정적 데이터: 앱 생명주기 동안 거의 변하지 않는 데이터
/// (user_id, user_name, user_role, group_id, phone_number 등)
class AppCache {
  // ============================================================================
  // 사용자 정보 (로그인 시 설정, 거의 변하지 않음)
  // ============================================================================
  static String? _userId;
  static String? _userName;
  static String? _userRole; // 'crew' | 'guardian' (user-level 역할 요약)
  static String? _memberRole; // 'captain' | 'crew_chief' | 'crew' | 'guardian' (새 스키마)
  static String? _phoneNumber;

  // ============================================================================
  // 그룹 정보 (가끔 변경됨)
  // ============================================================================
  static String? _groupId;
  static String? _tripId;

  // ============================================================================
  // 일정 및 장소 데이터 (스플래시에서 사전 로드)
  // ============================================================================
  static List<Schedule>? _cachedSchedules;
  static List<GeofenceData>? _cachedGeofences;

  // ============================================================================
  // 초기화 상태
  // ============================================================================
  static bool _initialized = false;

  /// 앱 시작 시 한 번만 호출하여 메모리 캐시 초기화
  ///
  /// 헤드리스 태스크에서도 안전하게 사용 가능 (이미 초기화된 경우 스킵)
  static Future<void> initialize() async {
    if (_initialized) {
      return; // 이미 초기화됨
    }

    try {
      final prefs = await SharedPreferences.getInstance();

      // 사용자 정보
      _userId = prefs.getString('user_id');
      _userName = prefs.getString('user_name');
      _userRole = prefs.getString('user_role');
      _memberRole = prefs.getString('member_role');
      _phoneNumber = prefs.getString('phone_number');

      // 그룹 정보
      _groupId = prefs.getString('group_id');
      _tripId = prefs.getString('trip_id');

      _initialized = true;

      debugPrint('[AppCache] 초기화 완료: userId=$_userId, userName=$_userName');
    } catch (e) {
      debugPrint('[AppCache] 초기화 실패: $e');
    }
  }

  // ============================================================================
  // Getter (메모리 캐시 우선, 없으면 디스크에서 읽기)
  // ============================================================================

  /// 사용자 ID
  static Future<String?> get userId async {
    if (_userId != null) return _userId;
    // 메모리 캐시 없으면 디스크에서 읽기 (헤드리스 안전)
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString('user_id');
    return _userId;
  }

  /// 사용자 이름
  static Future<String?> get userName async {
    if (_userName != null) return _userName;
    final prefs = await SharedPreferences.getInstance();
    _userName = prefs.getString('user_name');
    return _userName;
  }

  /// 사용자 역할 (crew/guardian) - user-level 역할 요약
  static Future<String?> get userRole async {
    if (_userRole != null) return _userRole;
    final prefs = await SharedPreferences.getInstance();
    _userRole = prefs.getString('user_role');
    return _userRole;
  }

  /// 멤버 역할 (captain/crew_chief/crew/guardian)
  static Future<String?> get memberRole async {
    if (_memberRole != null) return _memberRole;
    final prefs = await SharedPreferences.getInstance();
    _memberRole = prefs.getString('member_role');
    return _memberRole;
  }

  /// 전화번호
  static Future<String?> get phoneNumber async {
    if (_phoneNumber != null) return _phoneNumber;
    final prefs = await SharedPreferences.getInstance();
    _phoneNumber = prefs.getString('phone_number');
    return _phoneNumber;
  }

  /// 그룹 ID
  static Future<String?> get groupId async {
    if (_groupId != null) return _groupId;
    final prefs = await SharedPreferences.getInstance();
    _groupId = prefs.getString('group_id');
    return _groupId;
  }

  /// 트립 ID
  static Future<String?> get tripId async {
    if (_tripId != null) return _tripId;
    final prefs = await SharedPreferences.getInstance();
    _tripId = prefs.getString('trip_id');
    return _tripId;
  }

  // ============================================================================
  // 메모리 캐시만 읽기 (동기, 가장 빠름, 헤드리스에서 주로 사용)
  // ============================================================================

  /// 사용자 ID (메모리에서만 읽기)
  static String? get userIdSync => _userId;

  /// 사용자 이름 (메모리에서만 읽기)
  static String? get userNameSync => _userName;

  /// 사용자 역할 (메모리에서만 읽기)
  static String? get userRoleSync => _userRole;

  /// 멤버 역할 (메모리에서만 읽기)
  static String? get memberRoleSync => _memberRole;

  /// 그룹 ID (메모리에서만 읽기)
  static String? get groupIdSync => _groupId;

  /// 트립 ID (메모리에서만 읽기)
  static String? get tripIdSync => _tripId;

  /// 일정 목록 (메모리 캐시)
  static List<Schedule>? get cachedSchedules => _cachedSchedules;

  /// 장소 목록 (메모리 캐시)
  static List<GeofenceData>? get cachedGeofences => _cachedGeofences;

  // ============================================================================
  // Setter (메모리 + 디스크 업데이트)
  // ============================================================================

  /// 사용자 정보 업데이트
  static Future<void> setUserInfo({
    String? userId,
    String? userName,
    String? userRole,
    String? memberRole,
    String? phoneNumber,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (userId != null) {
        _userId = userId;
        await prefs.setString('user_id', userId);
      }
      if (userName != null) {
        _userName = userName;
        await prefs.setString('user_name', userName);
      }
      if (userRole != null) {
        _userRole = userRole;
        await prefs.setString('user_role', userRole);
      }
      if (memberRole != null) {
        _memberRole = memberRole;
        await prefs.setString('member_role', memberRole);
      }
      if (phoneNumber != null) {
        _phoneNumber = phoneNumber;
        await prefs.setString('phone_number', phoneNumber);
      }

      debugPrint('[AppCache] 사용자 정보 업데이트: userId=$userId, userName=$userName');
    } catch (e) {
      debugPrint('[AppCache] 사용자 정보 업데이트 실패: $e');
    }
  }

  /// 그룹 ID 업데이트
  static Future<void> setGroupId(String groupId) async {
    try {
      _groupId = groupId;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('group_id', groupId);
      debugPrint('[AppCache] 그룹 ID 업데이트: $groupId');
    } catch (e) {
      debugPrint('[AppCache] 그룹 ID 업데이트 실패: $e');
    }
  }

  /// 트립 ID 업데이트
  static Future<void> setTripId(String tripId) async {
    try {
      _tripId = tripId;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('trip_id', tripId);
      debugPrint('[AppCache] 트립 ID 업데이트: $tripId');
    } catch (e) {
      debugPrint('[AppCache] 트립 ID 업데이트 실패: $e');
    }
  }

  /// 일정 목록 캐시 업데이트
  static void setCachedSchedules(List<Schedule> schedules) {
    _cachedSchedules = schedules;
    debugPrint('[AppCache] 일정 목록 캐시 업데이트: ${schedules.length}개');
  }

  /// 장소 목록 캐시 업데이트
  static void setCachedGeofences(List<GeofenceData> geofences) {
    _cachedGeofences = geofences;
    debugPrint('[AppCache] 장소 목록 캐시 업데이트: ${geofences.length}개');
  }

  // ============================================================================
  // 유틸리티
  // ============================================================================

  /// 초기화 여부 확인
  static bool get isInitialized => _initialized;

  /// 캐시 초기화 (로그아웃 시 사용)
  static Future<void> clear() async {
    _userId = null;
    _userName = null;
    _userRole = null;
    _memberRole = null;
    _phoneNumber = null;
    _groupId = null;
    _tripId = null;
    _cachedSchedules = null;
    _cachedGeofences = null;
    _initialized = false;

    debugPrint('[AppCache] 캐시 초기화 완료');
  }
}
