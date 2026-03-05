import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../constants/app_tokens.dart';
import '../models/geofence.dart';

/// 지오펜스 지도 렌더링을 담당하는 Manager 클래스
class GeofenceMapRenderer {

  GeofenceMapRenderer({
    required this.onGeofencesUpdated,
    required this.onMarkersUpdated,
    required this.isMounted,
  });
  // 상태
  List<CircleMarker> _geofenceCircles = [];

  // 콜백 함수들
  final Function(List<CircleMarker>) onGeofencesUpdated;
  final Function(List<Marker>) onMarkersUpdated;
  final bool Function() isMounted;

  // Getters
  List<CircleMarker> get geofenceCircles => List.from(_geofenceCircles);

  /// 지오펜스 지도 업데이트
  void updateGeofencesOnMap(List<GeofenceData> geofences) {
    try {
      debugPrint('[GeofenceMapRenderer] 지오펜스 업데이트 시작: ${geofences.length}개');

      // 지도에 원형 영역 표시 (CircleMarker 사용)
      final List<CircleMarker> circles = [];

      for (final geofence in geofences) {
        // 활성화된 지오펜스만 표시
        if (!geofence.isActive) {
          debugPrint('[GeofenceMapRenderer] 비활성화된 지오펜스 스킵: ${geofence.name}');
          continue;
        }

        if (geofence.shapeType == 'circle' &&
            geofence.centerLatitude != null &&
            geofence.centerLongitude != null &&
            geofence.radiusMeters != null) {
          Color fillColor;
          Color strokeColor;

          switch (geofence.type) {
            case 'safe':
              // 디자인: 안전지역은 teal/cyan 색상 (앱 프라이머리 컬러)
              fillColor = AppTokens.primaryTeal.withValues(alpha: 0.15);
              strokeColor = AppTokens.primaryTeal;
              break;
            case 'watch':
            case 'caution':
              fillColor = Colors.orange.withValues(alpha: 0.15);
              strokeColor = Colors.orange;
              break;
            case 'danger':
              // 디자인: 위험지역은 부드러운 레드/핑크 톤
              fillColor = AppTokens.semanticError.withValues(alpha: 0.15);
              strokeColor = AppTokens.semanticError;
              break;
            default:
              fillColor = AppTokens.primaryTeal.withValues(alpha: 0.15);
              strokeColor = AppTokens.primaryTeal;
          }

          // CircleMarker 생성 (원형 영역)
          final center = LatLng(
            geofence.centerLatitude!,
            geofence.centerLongitude!,
          );

          circles.add(
            CircleMarker(
              point: center,
              radius: geofence.radiusMeters!.toDouble(),
              color: fillColor,
              borderColor: strokeColor,
              borderStrokeWidth: 1,
              useRadiusInMeter: true, // 미터 단위로 반지름 사용
            ),
          );

          debugPrint(
            '[GeofenceMapRenderer] Circle 생성: ${geofence.name} (${geofence.type}, 반경: ${geofence.radiusMeters}m, center=(${geofence.centerLatitude}, ${geofence.centerLongitude}), fillColor=$fillColor, strokeColor=$strokeColor)',
          );
        } else {
          debugPrint(
            '[GeofenceMapRenderer] 지오펜스 데이터 불완전 - 스킵: ${geofence.name} (shapeType: ${geofence.shapeType}, centerLat: ${geofence.centerLatitude}, centerLon: ${geofence.centerLongitude}, radius: ${geofence.radiusMeters})',
          );
        }
      }

      if (isMounted()) {
        _geofenceCircles = circles;
        debugPrint(
          '[GeofenceMapRenderer] onGeofencesUpdated 콜백 호출: ${circles.length}개 Circle',
        );
        onGeofencesUpdated(circles);

        // 지오펜스 마커 제거를 위한 콜백 호출
        // (실제 마커 제거는 MarkerManager에서 처리)
        onMarkersUpdated([]);
        debugPrint('[GeofenceMapRenderer] 콜백 호출 완료');
      } else {
        debugPrint('[GeofenceMapRenderer] 위젯이 마운트되지 않아 업데이트 스킵');
      }

      debugPrint('[GeofenceMapRenderer] 지오펜스 업데이트 완료: ${circles.length}개');
    } catch (e) {
      debugPrint('[GeofenceMapRenderer] 지오펜스 업데이트 실패: $e');
    }
  }

  /// 리소스 정리
  void dispose() {
    _geofenceCircles.clear();
  }
}
