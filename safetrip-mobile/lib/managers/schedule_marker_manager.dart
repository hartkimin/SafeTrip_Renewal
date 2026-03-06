import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../core/theme/app_colors.dart';

/// 일정/장소 마커 관리 — Layer 3 (지도 원칙 §3, §10.2)
///
/// 여행 일정 장소를 지도 위에 핀 마커로 표시.
/// 일정 순서대로 폴리라인 경로 연결.
/// 일정 시작 시 해당 마커 강조.
class ScheduleMarkerManager {
  ScheduleMarkerManager({
    required this.onMarkersUpdated,
    required this.onPolylinesUpdated,
    this.onScheduleMarkerTap,
  });

  final void Function(List<Marker>) onMarkersUpdated;
  final void Function(List<Polyline>) onPolylinesUpdated;
  final void Function(String scheduleId)? onScheduleMarkerTap;

  final List<Marker> _markers = [];
  final List<Polyline> _polylines = [];
  String? _highlightedScheduleId;

  List<Marker> get markers => List.from(_markers);
  List<Polyline> get polylines => List.from(_polylines);

  /// 일정 데이터로 마커 + 폴리라인 갱신
  void updateSchedules(List<Map<String, dynamic>> schedules) {
    _markers.clear();
    _polylines.clear();

    final routePoints = <LatLng>[];

    for (int i = 0; i < schedules.length; i++) {
      final schedule = schedules[i];
      final lat = schedule['latitude'] as double?;
      final lng = schedule['longitude'] as double?;
      final scheduleId = schedule['schedule_id'] as String? ?? '$i';
      final placeName = schedule['place_name'] as String? ?? '';

      if (lat == null || lng == null) continue;

      final position = LatLng(lat, lng);
      routePoints.add(position);

      final isHighlighted = _highlightedScheduleId == scheduleId;

      _markers.add(Marker(
        key: ValueKey('schedule_$scheduleId'),
        point: position,
        width: isHighlighted ? 48 : 36,
        height: isHighlighted ? 48 : 36,
        child: GestureDetector(
          onTap: () => onScheduleMarkerTap?.call(scheduleId),
          child: _SchedulePin(
            index: i + 1,
            placeName: placeName,
            isHighlighted: isHighlighted,
          ),
        ),
      ));
    }

    // 경로 폴리라인 (2개 이상 장소일 때)
    if (routePoints.length >= 2) {
      _polylines.add(Polyline(
        points: routePoints,
        color: AppColors.primaryTeal.withValues(alpha: 0.6),
        strokeWidth: 3,
        pattern: const StrokePattern.dotted(),
      ));
    }

    onMarkersUpdated(List.from(_markers));
    onPolylinesUpdated(List.from(_polylines));
  }

  /// 일정 시작 시 해당 마커 강조 (§4 P2)
  void highlightSchedule(String scheduleId) {
    _highlightedScheduleId = scheduleId;
  }

  void clearHighlight() {
    _highlightedScheduleId = null;
  }

  void dispose() {
    _markers.clear();
    _polylines.clear();
  }
}

/// 일정 핀 위젯
class _SchedulePin extends StatelessWidget {
  const _SchedulePin({
    required this.index,
    required this.placeName,
    this.isHighlighted = false,
  });

  final int index;
  final String placeName;
  final bool isHighlighted;

  @override
  Widget build(BuildContext context) {
    final size = isHighlighted ? 40.0 : 30.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: isHighlighted
                ? AppColors.primaryTeal
                : AppColors.primaryTeal.withValues(alpha: 0.8),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white,
              width: isHighlighted ? 3 : 2,
            ),
            boxShadow: isHighlighted
                ? [BoxShadow(
                    color: AppColors.primaryTeal.withValues(alpha: 0.4),
                    blurRadius: 8,
                    spreadRadius: 2,
                  )]
                : null,
          ),
          child: Center(
            child: Text(
              '$index',
              style: TextStyle(
                color: Colors.white,
                fontSize: isHighlighted ? 16 : 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
