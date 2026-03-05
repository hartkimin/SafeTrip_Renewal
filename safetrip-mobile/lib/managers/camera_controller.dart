import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/location_service.dart';

/// 카메라 제어 및 지도 뷰 조정을 담당하는 Manager 클래스
class CameraController {

  CameraController({
    required this.onCameraPositionChanged,
    required this.isMounted,
    required this.getBottomSheetHeight,
  });
  // 상태
  MapController? _mapController;
  LatLng? _lastCameraCenter;
  double _lastCameraZoom = 15.0;
  LatLng? _mainModeCameraCenter;
  double _mainModeCameraZoom = 15.0;
  bool _isUserManuallyZoomed = false;

  // 콜백 함수들
  final Function(LatLng, double) onCameraPositionChanged;
  final bool Function() isMounted;
  final double Function() getBottomSheetHeight;

  /// 맵 컨트롤러 설정
  void setMapController(MapController? controller) {
    _mapController = controller;
  }

  /// 맵 컨트롤러 가져오기
  MapController? get mapController => _mapController;

  /// 마지막 카메라 위치 가져오기
  LatLng? get lastCameraCenter => _lastCameraCenter;
  double get lastCameraZoom => _lastCameraZoom;

  /// 메인 모드 카메라 위치 가져오기
  LatLng? get mainModeCameraCenter => _mainModeCameraCenter;
  double get mainModeCameraZoom => _mainModeCameraZoom;

  /// 사용자가 수동으로 줌했는지 여부
  bool get isUserManuallyZoomed => _isUserManuallyZoomed;

  /// 카메라 위치 업데이트
  void updateCameraPosition(LatLng center, double zoom) {
    _lastCameraCenter = center;
    _lastCameraZoom = zoom;
    onCameraPositionChanged(center, zoom);
  }

  /// 사용자 수동 줌 플래그 설정
  void setUserManuallyZoomed(bool value) {
    _isUserManuallyZoomed = value;
  }

  /// 메인 모드 카메라 위치 저장
  void saveMainModeCameraPosition() {
    if (_lastCameraCenter != null) {
      _mainModeCameraCenter = _lastCameraCenter;
      _mainModeCameraZoom = _lastCameraZoom;
    }
  }

  /// 메인 모드 카메라 위치 복원
  void restoreMainModeCameraPosition() {
    _mainModeCameraCenter = null;
  }

  /// 모든 마커에 맞게 카메라 조정
  Future<void> fitAllMarkers(List<Marker> markers, {bool force = false}) async {
    // 강제 실행이 아니고 사용자가 수동으로 줌했으면 스킵
    if (!force && _isUserManuallyZoomed) {
      return;
    }

    if (markers.isEmpty || _mapController == null) {
      return;
    }

    // 모든 마커의 위치 수집 (지오펜스 마커 제외)
    final positions = markers
        .where((marker) {
          final markerKey = marker.key is ValueKey<String>
              ? (marker.key as ValueKey<String>).value
              : null;
          return markerKey != null && !markerKey.startsWith('geofence_');
        })
        .map((marker) => marker.point)
        .toList();

    if (positions.isEmpty) {
      return;
    }

    // 최소/최대 위도, 경도 계산
    double minLat = positions[0].latitude;
    double maxLat = positions[0].latitude;
    double minLng = positions[0].longitude;
    double maxLng = positions[0].longitude;

    for (final position in positions) {
      if (position.latitude < minLat) minLat = position.latitude;
      if (position.latitude > maxLat) maxLat = position.latitude;
      if (position.longitude < minLng) minLng = position.longitude;
      if (position.longitude > maxLng) maxLng = position.longitude;
    }

    // 경계 계산 (패딩 추가)
    final latDiff = maxLat - minLat;
    final lngDiff = maxLng - minLng;

    // 최소 범위 보장 (너무 작으면 확대)
    const minLatDiff = 0.01; // 약 1km
    const minLngDiff = 0.01; // 약 1km

    final adjustedMinLat =
        minLat -
        (latDiff < minLatDiff ? (minLatDiff - latDiff) / 2 : latDiff * 0.1);
    final adjustedMaxLat =
        maxLat +
        (latDiff < minLatDiff ? (minLatDiff - latDiff) / 2 : latDiff * 0.1);
    final adjustedMinLng =
        minLng -
        (lngDiff < minLngDiff ? (minLngDiff - lngDiff) / 2 : lngDiff * 0.1);
    final adjustedMaxLng =
        maxLng +
        (lngDiff < minLngDiff ? (minLngDiff - lngDiff) / 2 : lngDiff * 0.1);

    // 카메라 업데이트
    _mapController!.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds(
          LatLng(adjustedMinLat, adjustedMinLng),
          LatLng(adjustedMaxLat, adjustedMaxLng),
        ),
        padding: const EdgeInsets.all(100.0),
      ),
    );
  }

  /// 사용자 경로에 맞게 카메라 조정
  Future<void> fitUserBounds(
    List<LatLng> points, {
    bool force = false,
    BuildContext? context,
  }) async {
    // 강제 실행이 아니고 사용자가 수동으로 줌했으면 스킵
    if (!force && _isUserManuallyZoomed) {
      return;
    }

    if (points.isEmpty || _mapController == null) return;

    double minLat = points[0].latitude;
    double maxLat = points[0].latitude;
    double minLng = points[0].longitude;
    double maxLng = points[0].longitude;

    for (final point in points) {
      minLat = minLat < point.latitude ? minLat : point.latitude;
      maxLat = maxLat > point.latitude ? maxLat : point.latitude;
      minLng = minLng < point.longitude ? minLng : point.longitude;
      maxLng = maxLng > point.longitude ? maxLng : point.longitude;
    }

    // 픽셀 패딩만 사용
    const double padding = 50.0;

    _mapController!.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds(
          LatLng(minLat, minLng),
          LatLng(maxLat, maxLng),
        ),
        padding: const EdgeInsets.all(padding),
      ),
    );
  }

  /// 시작 마커와 종료 마커를 맵 위쪽에 보이도록 카메라 조정
  Future<void> fitStartEndMarkers(
    LatLng startMarker,
    LatLng endMarker, {
    bool force = false,
    BuildContext? context,
  }) async {
    // 강제 실행이 아니고 사용자가 수동으로 줌했으면 스킵
    if (!force && _isUserManuallyZoomed) {
      return;
    }

    if (_mapController == null) return;

    // 시작과 종료 마커의 bounds 계산
    final minLat = startMarker.latitude < endMarker.latitude
        ? startMarker.latitude
        : endMarker.latitude;
    final maxLat = startMarker.latitude > endMarker.latitude
        ? startMarker.latitude
        : endMarker.latitude;
    final minLng = startMarker.longitude < endMarker.longitude
        ? startMarker.longitude
        : endMarker.longitude;
    final maxLng = startMarker.longitude > endMarker.longitude
        ? startMarker.longitude
        : endMarker.longitude;

    // 픽셀 패딩만 사용
    const double padding = 80.0;

    _mapController!.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds(
          LatLng(minLat, minLng),
          LatLng(maxLat, maxLng),
        ),
        padding: const EdgeInsets.all(padding),
      ),
    );
  }

  /// 내 위치로 이동
  Future<void> moveToMyLocation(LocationService? locationService) async {
    if (_mapController == null) {
      return;
    }

    try {
      // LocationService를 통해 현재 위치 가져오기
      final location = await locationService?.getCurrentPosition();

      if (location != null) {
        _mapController!.move(
          LatLng(location.coords.latitude, location.coords.longitude),
          20.0,
        );
      }
    } catch (e) {
      debugPrint('[CameraController] 위치 가져오기 실패: $e');
    }
  }

  /// 리소스 정리
  void dispose() {
    _mapController = null;
    _lastCameraCenter = null;
    _mainModeCameraCenter = null;
  }
}
