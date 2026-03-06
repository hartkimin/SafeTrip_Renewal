import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../core/theme/app_colors.dart';

/// 이벤트/알림 마커 관리 — Layer 4 (지도 원칙 §3, §10.2)
///
/// 지오펜스 이탈 경보 마커, 출석 체크 위치 마커.
/// 캡틴/크루장 전용 레이어.
class EventMarkerManager {
  EventMarkerManager({
    required this.onMarkersUpdated,
    this.onEventMarkerTap,
  });

  final void Function(List<Marker>) onMarkersUpdated;
  final void Function(String eventId)? onEventMarkerTap;

  final List<Marker> _markers = [];

  List<Marker> get markers => List.from(_markers);

  /// 지오펜스 이탈 경보 마커 추가
  void addGeofenceExitAlert({
    required String eventId,
    required String memberName,
    required LatLng position,
  }) {
    // 중복 방지
    _markers.removeWhere((m) {
      final key = m.key is ValueKey<String> ? (m.key as ValueKey<String>).value : null;
      return key == 'event_$eventId';
    });

    _markers.add(Marker(
      key: ValueKey('event_$eventId'),
      point: position,
      width: 36,
      height: 36,
      child: GestureDetector(
        onTap: () => onEventMarkerTap?.call(eventId),
        child: _AlertPin(memberName: memberName),
      ),
    ));

    onMarkersUpdated(List.from(_markers));
  }

  /// 이벤트 마커 제거
  void removeEvent(String eventId) {
    _markers.removeWhere((m) {
      final key = m.key is ValueKey<String> ? (m.key as ValueKey<String>).value : null;
      return key == 'event_$eventId';
    });
    onMarkersUpdated(List.from(_markers));
  }

  /// 전체 이벤트 마커 초기화
  void clear() {
    _markers.clear();
    onMarkersUpdated([]);
  }

  void dispose() {
    _markers.clear();
  }
}

/// 경보 핀 위젯 (빨간 삼각형)
class _AlertPin extends StatelessWidget {
  const _AlertPin({required this.memberName});

  final String memberName;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '$memberName 지오펜스 이탈',
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: AppColors.semanticError,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: const Icon(
          Icons.warning,
          color: Colors.white,
          size: 18,
        ),
      ),
    );
  }
}
