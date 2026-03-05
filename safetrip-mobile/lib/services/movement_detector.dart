import 'package:flutter/foundation.dart';
import 'package:flutter_background_geolocation/flutter_background_geolocation.dart'
    as bg;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/location_config.dart';
import '../utils/location_cache.dart';
import '../utils/map_utils.dart';

/// 기준점 기반 이동/정지 상태 판단 클래스
/// 라이브러리의 isMoving 대신 커스텀 로직으로 판단
class MovementDetector {
  factory MovementDetector() => _instance;
  MovementDetector._internal();
  static final MovementDetector _instance = MovementDetector._internal();

  // ============================================================================
  // 상태 변수
  // ============================================================================
  /// 정지 상태의 기준점 (위도)
  double? _stationaryCenterLat;

  /// 정지 상태의 기준점 (경도)
  double? _stationaryCenterLng;

  /// 기준점 설정 시각 (정지 판단 시작 시각)
  DateTime? _stationaryStartTime;

  /// 기준점 밖으로 나간 연속 카운트 (이동 판단용)
  int _outOfRadiusCount = 0;

  /// 현재 판단된 이동/정지 상태
  /// true: 이동, false: 정지, null: 초기 상태
  bool? _currentIsMoving;

  // ============================================================================
  // LocationConfig 값 사용
  // ============================================================================
  /// 정지 감지용 지오펜스 반경 (미터) - MovementDetector 전용
  double get _stationaryRadius => LocationConfig.stationaryRealRadius;

  /// 이동 감지 카운트 (기준점 밖으로 나간 연속 위치 개수)
  int get _movingDetectionCount => LocationConfig.movingDetectionCount;

  // ============================================================================
  // 메인 메서드
  // ============================================================================
  /// 위치 업데이트 및 이동/정지 상태 판단
  ///
  /// 반환값:
  /// - `true`: 이동 상태
  /// - `false`: 정지 상태
  /// - `null`: 초기 상태 (첫 위치 수신 전)
  Future<bool?> updateLocation(bg.Location location) async {
    final now = DateTime.now();

    // 초기 상태 처리
    if (_currentIsMoving == null) {
      // last_known_* 읽기
      final (knownLat, knownLng) = await LocationCache.getLocation();

      // last_known_location_updated_at 읽기 (null이면 프리퍼런스에서 직접)
      DateTime? knownUpdatedAt = LocationCache.lastUpdatedAt;
      if (knownUpdatedAt == null) {
        final prefs = await SharedPreferences.getInstance();
        final updatedAtStr = prefs.getString('last_known_location_updated_at');
        knownUpdatedAt = updatedAtStr != null
            ? DateTime.parse(updatedAtStr)
            : null;
      }

      if (knownLat != null && knownLng != null) {
        // 현재 위치와 last_known_* 거리 비교
        final distance = calculateDistanceInMeters(
          knownLat,
          knownLng,
          location.coords.latitude,
          location.coords.longitude,
        );

        if (distance < _stationaryRadius) {
          // 거리가 가까우면 last_known_*를 기준점으로 설정
          _stationaryCenterLat = knownLat;
          _stationaryCenterLng = knownLng;
          _stationaryStartTime = now; // 현재 시각으로 설정 (중요!)
          _currentIsMoving = false; // 정지 상태로 시작
          _outOfRadiusCount = 0;
          debugPrint(
            '[MovementDetector] 초기 상태 - last_known_*를 기준점으로 사용 (거리: ${distance.toStringAsFixed(1)}m): (${knownLat.toStringAsFixed(6)}, ${knownLng.toStringAsFixed(6)})',
          );
        } else {
          // 거리가 멀면 현재 위치를 기준점으로 설정
          _stationaryCenterLat = location.coords.latitude;
          _stationaryCenterLng = location.coords.longitude;
          _stationaryStartTime = now;
          _currentIsMoving = false; // 정지 상태로 시작
          _outOfRadiusCount = 0;
          debugPrint(
            '[MovementDetector] 초기 상태 - 현재 위치를 기준점으로 사용 (last_known_*와 거리: ${distance.toStringAsFixed(1)}m)',
          );
        }
      } else {
        // last_known_*가 없으면 현재 위치를 기준점으로 설정
        _stationaryCenterLat = location.coords.latitude;
        _stationaryCenterLng = location.coords.longitude;
        _stationaryStartTime = now;
        _currentIsMoving = false; // 정지 상태로 시작
        _outOfRadiusCount = 0;
        debugPrint('[MovementDetector] 초기 상태 - 현재 위치를 기준점으로 사용 (last_known_* 없음)');
      }
      return _currentIsMoving;
    }

    // 현재 상태에 따른 판단 로직 실행
    if (_currentIsMoving == true) {
      // 이동 중 → 정지 판단
      await _determineStationary(location, now);
    } else {
      // 정지 중 → 이동 판단
      await _determineMoving(location, now);
    }

    return _currentIsMoving;
  }

  // ============================================================================
  // 정지 판단 로직 (이동 → 정지)
  // ============================================================================
  /// 이동 중 상태에서 정지 상태로 전환 판단
  Future<void> _determineStationary(bg.Location location, DateTime now) async {
    // 기준점이 없으면 last_known_* 또는 현재 위치를 기준점으로 설정
    if (_stationaryCenterLat == null || _stationaryCenterLng == null) {
      // last_known_* 읽기
      final (knownLat, knownLng) = await LocationCache.getLocation();

      // last_known_location_updated_at 읽기 (null이면 프리퍼런스에서 직접)
      DateTime? knownUpdatedAt = LocationCache.lastUpdatedAt;
      if (knownUpdatedAt == null) {
        final prefs = await SharedPreferences.getInstance();
        final updatedAtStr = prefs.getString('last_known_location_updated_at');
        knownUpdatedAt = updatedAtStr != null
            ? DateTime.parse(updatedAtStr)
            : null;
      }

      if (knownLat != null && knownLng != null) {
        // 현재 위치와 last_known_* 거리 비교
        final distance = calculateDistanceInMeters(
          knownLat,
          knownLng,
          location.coords.latitude,
          location.coords.longitude,
        );

        if (distance < _stationaryRadius) {
          // 거리가 가까우면 last_known_*를 기준점으로 설정
          _stationaryCenterLat = knownLat;
          _stationaryCenterLng = knownLng;
          _stationaryStartTime = now; // 현재 시각으로 설정 (중요!)
          _outOfRadiusCount = 0;
          debugPrint(
            '[MovementDetector] 기준점 설정 (last_known_* 사용, 거리: ${distance.toStringAsFixed(1)}m): (${knownLat.toStringAsFixed(6)}, ${knownLng.toStringAsFixed(6)})',
          );
        } else {
          // 거리가 멀면 현재 위치를 기준점으로 설정
          _stationaryCenterLat = location.coords.latitude;
          _stationaryCenterLng = location.coords.longitude;
          _stationaryStartTime = now;
          _outOfRadiusCount = 0;
          debugPrint(
            '[MovementDetector] 기준점 설정 (현재 위치 사용, last_known_*와 거리: ${distance.toStringAsFixed(1)}m): (${_stationaryCenterLat!.toStringAsFixed(6)}, ${_stationaryCenterLng!.toStringAsFixed(6)})',
          );
        }
      } else {
        // last_known_*가 없으면 현재 위치를 기준점으로 설정
        _stationaryCenterLat = location.coords.latitude;
        _stationaryCenterLng = location.coords.longitude;
        _stationaryStartTime = now;
        _outOfRadiusCount = 0;
        debugPrint(
          '[MovementDetector] 기준점 설정 (현재 위치 사용, last_known_* 없음): (${_stationaryCenterLat!.toStringAsFixed(6)}, ${_stationaryCenterLng!.toStringAsFixed(6)})',
        );
      }
      return;
    }

    // 기준점과의 거리 계산
    final distance = calculateDistanceInMeters(
      _stationaryCenterLat!,
      _stationaryCenterLng!,
      location.coords.latitude,
      location.coords.longitude,
    );

    if (distance < _stationaryRadius) {
      // 기준점 이내 → 정지 판단 확인
      if (_stationaryStartTime != null) {
        final elapsed = now.difference(_stationaryStartTime!);
        final timeout = await getStopRealTimeout();
        if (elapsed >= timeout) {
          // 타임아웃 경과 → 정지 상태로 전환
          _currentIsMoving = false;
          _outOfRadiusCount = 0;
          debugPrint(
            '[MovementDetector] 정지 상태로 전환 (경과: ${elapsed.inMinutes}분, 거리: ${distance.toStringAsFixed(1)}m, 타임아웃: ${timeout.inMinutes}분)',
          );
        }
      }
    } else {
      // 기준점 밖으로 나감 → 기준점 리셋
      _stationaryCenterLat = null;
      _stationaryCenterLng = null;
      _stationaryStartTime = null;
      _outOfRadiusCount = 0;
      debugPrint(
        '[MovementDetector] 기준점 밖으로 나감 - 기준점 리셋 (거리: ${distance.toStringAsFixed(1)}m)',
      );
    }
  }

  // ============================================================================
  // 이동 판단 로직 (정지 → 이동)
  // ============================================================================
  /// 정지 중 상태에서 이동 상태로 전환 판단
  Future<void> _determineMoving(bg.Location location, DateTime now) async {
    if (_stationaryCenterLat == null || _stationaryCenterLng == null) {
      // 기준점이 없으면 last_known_* 또는 현재 위치를 기준점으로 설정
      final (knownLat, knownLng) = await LocationCache.getLocation();

      // last_known_location_updated_at 읽기 (null이면 프리퍼런스에서 직접)
      DateTime? knownUpdatedAt = LocationCache.lastUpdatedAt;
      if (knownUpdatedAt == null) {
        final prefs = await SharedPreferences.getInstance();
        final updatedAtStr = prefs.getString('last_known_location_updated_at');
        knownUpdatedAt = updatedAtStr != null
            ? DateTime.parse(updatedAtStr)
            : null;
      }

      if (knownLat != null && knownLng != null) {
        // 현재 위치와 last_known_* 거리 비교
        final distance = calculateDistanceInMeters(
          knownLat,
          knownLng,
          location.coords.latitude,
          location.coords.longitude,
        );

        if (distance < _stationaryRadius) {
          // 거리가 가까우면 last_known_*를 기준점으로 설정
          _stationaryCenterLat = knownLat;
          _stationaryCenterLng = knownLng;
          _stationaryStartTime = now; // 현재 시각으로 설정 (중요!)
          _outOfRadiusCount = 0;
          debugPrint(
            '[MovementDetector] 기준점 설정 (last_known_* 사용, 거리: ${distance.toStringAsFixed(1)}m): (${knownLat.toStringAsFixed(6)}, ${knownLng.toStringAsFixed(6)})',
          );
        } else {
          // 거리가 멀면 현재 위치를 기준점으로 설정
          _stationaryCenterLat = location.coords.latitude;
          _stationaryCenterLng = location.coords.longitude;
          _stationaryStartTime = now;
          _outOfRadiusCount = 0;
          debugPrint(
            '[MovementDetector] 기준점 설정 (현재 위치 사용, last_known_*와 거리: ${distance.toStringAsFixed(1)}m): (${_stationaryCenterLat!.toStringAsFixed(6)}, ${_stationaryCenterLng!.toStringAsFixed(6)})',
          );
        }
      } else {
        // last_known_*가 없으면 현재 위치를 기준점으로 설정
        _stationaryCenterLat = location.coords.latitude;
        _stationaryCenterLng = location.coords.longitude;
        _stationaryStartTime = now;
        _outOfRadiusCount = 0;
        debugPrint(
          '[MovementDetector] 기준점 설정 (현재 위치 사용, last_known_* 없음): (${_stationaryCenterLat!.toStringAsFixed(6)}, ${_stationaryCenterLng!.toStringAsFixed(6)})',
        );
      }
      return;
    }

    // 기준점과의 거리 계산
    final distance = calculateDistanceInMeters(
      _stationaryCenterLat!,
      _stationaryCenterLng!,
      location.coords.latitude,
      location.coords.longitude,
    );

    if (distance >= _stationaryRadius) {
      // 기준점 밖으로 나감 → 카운트 증가
      _outOfRadiusCount++;
      debugPrint(
        '[MovementDetector] 기준점 밖으로 나감 (거리: ${distance.toStringAsFixed(1)}m, 카운트: $_outOfRadiusCount/$_movingDetectionCount)',
      );

      if (_outOfRadiusCount >= _movingDetectionCount) {
        // 연속 카운트 달성 → 이동 상태로 전환
        _currentIsMoving = true;
        _outOfRadiusCount = 0;
        _stationaryCenterLat = null;
        _stationaryCenterLng = null;
        _stationaryStartTime = null;
        debugPrint('[MovementDetector] 이동 상태로 전환 (연속 $_movingDetectionCount개 달성)');
      }
    } else {
      // 기준점 이내로 돌아옴 → 카운트 리셋
      if (_outOfRadiusCount > 0) {
        _outOfRadiusCount = 0;
        debugPrint(
          '[MovementDetector] 기준점 이내로 돌아옴 - 카운트 리셋 (거리: ${distance.toStringAsFixed(1)}m)',
        );
      }
    }
  }

  // ============================================================================
  // 동적 타임아웃 계산
  // ============================================================================
  /// 보호자 지오펜스 안이면 지오펜스 전용 타임아웃 사용
  /// 반환값: Duration (보호자 지오펜스 안: stopGeofenceTimeout, 밖: stopRealTimeout)
  Future<Duration> getStopRealTimeout() async {
    const baseTimeout = Duration(minutes: LocationConfig.stopRealTimeout);

    try {
      final prefs = await SharedPreferences.getInstance();
      final guardianGeofenceId = prefs.getString('last_guardian_geofence_id');

      if (guardianGeofenceId != null) {
        // 보호자 지오펜스 안: stopGeofenceTimeout 사용
        return const Duration(minutes: LocationConfig.stopGeofenceTimeout);
      } else {
        // 보호자 지오펜스 밖: 기본값
        return baseTimeout;
      }
    } catch (e) {
      // 에러 시 기본값 사용
      return baseTimeout;
    }
  }

  // ============================================================================
  // 상태 리셋 및 복원
  // ============================================================================
  /// 상태 초기화 (테스트 또는 재시작 시 사용)
  void reset() {
    _stationaryCenterLat = null;
    _stationaryCenterLng = null;
    _stationaryStartTime = null;
    _outOfRadiusCount = 0;
    _currentIsMoving = null;
    debugPrint('[MovementDetector] 상태 리셋');
  }

  /// 상태 복원 (앱 재시작 시 세션 복원용)
  /// [isMoving] 이동 상태 (true: 이동 중, false: 정지 중)
  /// [lat] 기준점 위도
  /// [lng] 기준점 경도
  void restoreState(bool isMoving, double lat, double lng) {
    _currentIsMoving = isMoving;
    _stationaryCenterLat = lat;
    _stationaryCenterLng = lng;
    _stationaryStartTime = DateTime.now();
    _outOfRadiusCount = 0;
    debugPrint(
      '[MovementDetector] 상태 복원 - isMoving: $isMoving, 기준점: (${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)})',
    );
  }

  /// 현재 상태 반환
  bool? get currentState => _currentIsMoving;
}
