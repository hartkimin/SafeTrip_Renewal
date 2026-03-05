import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 마지막 알려진 위치를 메모리와 디스크에 캐싱하는 유틸리티 클래스
///
/// 포어그라운드와 백그라운드(헤드리스) 모두에서 사용 가능하며,
/// SharedPreferences 호출을 최소화하여 ANR을 방지합니다.
class LocationCache {
  // SharedPreferences 키
  static const String _latKey = 'last_known_latitude';
  static const String _lngKey = 'last_known_longitude';
  static const String _updatedAtKey = 'last_known_location_updated_at';

  // 메모리 캐시
  static double? _cachedLat;
  static double? _cachedLng;
  static DateTime? _cachedUpdatedAt;

  /// 앱 시작 시 한 번만 호출하여 메모리 캐시 초기화
  static Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _cachedLat = prefs.getDouble(_latKey);
      _cachedLng = prefs.getDouble(_lngKey);

      final updatedAtStr = prefs.getString(_updatedAtKey);
      if (updatedAtStr != null) {
        _cachedUpdatedAt = DateTime.parse(updatedAtStr);
      }

      if (_cachedLat != null && _cachedLng != null) {
        debugPrint('[LocationCache] 초기화 완료: lat=$_cachedLat, lng=$_cachedLng');
      } else {
        debugPrint('[LocationCache] 초기화 완료: 저장된 위치 없음');
      }
    } catch (e) {
      debugPrint('[LocationCache] 초기화 실패: $e');
    }
  }

  /// 위치 저장 (메모리 + 디스크)
  ///
  /// 포어그라운드와 백그라운드 모두에서 호출 가능
  static Future<void> saveLocation(double latitude, double longitude) async {
    try {
      // 메모리 캐시 업데이트 (즉시)
      _cachedLat = latitude;
      _cachedLng = longitude;
      _cachedUpdatedAt = DateTime.now().toUtc();

      // 디스크 저장 (비동기)
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_latKey, latitude);
      await prefs.setDouble(_lngKey, longitude);
      await prefs.setString(_updatedAtKey, _cachedUpdatedAt!.toIso8601String());

      // debugPrint('[LocationCache] 위치 저장: lat=$latitude, lng=$longitude');
    } catch (e) {
      debugPrint('[LocationCache] 위치 저장 실패: $e');
    }
  }

  /// 위치 읽기 (메모리 캐시 우선, 없으면 디스크)
  ///
  /// Returns: (latitude, longitude) 튜플
  static Future<(double?, double?)> getLocation() async {
    // 메모리 캐시가 있으면 즉시 반환 (디스크 I/O 없음)
    if (_cachedLat != null && _cachedLng != null) {
      return (_cachedLat, _cachedLng);
    }

    // 메모리 캐시가 없으면 디스크에서 읽기
    try {
      final prefs = await SharedPreferences.getInstance();
      final lat = prefs.getDouble(_latKey);
      final lng = prefs.getDouble(_lngKey);

      // 메모리 캐시 업데이트
      _cachedLat = lat;
      _cachedLng = lng;

      return (lat, lng);
    } catch (e) {
      debugPrint('[LocationCache] 위치 읽기 실패: $e');
      return (null, null);
    }
  }

  /// 메모리 캐시만 읽기 (디스크 I/O 없음, 가장 빠름)
  static (double?, double?) getLocationFromMemory() {
    return (_cachedLat, _cachedLng);
  }

  /// 마지막 업데이트 시간
  static DateTime? get lastUpdatedAt => _cachedUpdatedAt;

  /// 위치가 있는지 확인
  static bool get hasLocation => _cachedLat != null && _cachedLng != null;

  /// 캐시 초기화 (테스트용)
  static void clear() {
    _cachedLat = null;
    _cachedLng = null;
    _cachedUpdatedAt = null;
  }
}
