import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../core/theme/app_colors.dart';
import '../models/safety_facility.dart';

/// 안전시설 마커 관리 — Layer 1 (지도 원칙 §3, §10.2)
///
/// 병원(녹색 십자), 경찰서(파란 방패), 대사관(빨간 국기) 마커 표시.
/// 데이터는 백엔드 API에서 로드, 로컬 캐시 지원.
class SafetyFacilityManager {
  SafetyFacilityManager({
    required this.onMarkersUpdated,
  });

  final void Function(List<Marker>) onMarkersUpdated;

  final List<SafetyFacility> _facilities = [];
  final List<Marker> _markers = [];

  List<Marker> get markers => List.from(_markers);

  /// 안전시설 데이터 업데이트
  void updateFacilities(List<SafetyFacility> facilities) {
    _facilities.clear();
    _facilities.addAll(facilities);
    _rebuildMarkers();
  }

  /// JSON 리스트로부터 업데이트 (API 응답)
  void updateFromJson(List<Map<String, dynamic>> jsonList) {
    final facilities = jsonList.map(SafetyFacility.fromJson).toList();
    updateFacilities(facilities);
  }

  void _rebuildMarkers() {
    _markers.clear();

    for (final facility in _facilities) {
      _markers.add(Marker(
        key: ValueKey('safety_${facility.id}'),
        point: LatLng(facility.latitude, facility.longitude),
        width: 32,
        height: 32,
        child: _SafetyFacilityPin(
          type: facility.type,
          name: facility.name,
        ),
      ));
    }

    onMarkersUpdated(List.from(_markers));
  }

  void dispose() {
    _facilities.clear();
    _markers.clear();
  }
}

class _SafetyFacilityPin extends StatelessWidget {
  const _SafetyFacilityPin({
    required this.type,
    required this.name,
  });

  final SafetyFacilityType type;
  final String name;

  IconData get _icon {
    switch (type) {
      case SafetyFacilityType.hospital:
        return Icons.local_hospital;
      case SafetyFacilityType.police:
        return Icons.local_police;
      case SafetyFacilityType.embassy:
        return Icons.flag;
    }
  }

  Color get _color {
    switch (type) {
      case SafetyFacilityType.hospital:
        return Colors.green;
      case SafetyFacilityType.police:
        return Colors.blue;
      case SafetyFacilityType.embassy:
        return AppColors.semanticError;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: name,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: _color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 3, offset: Offset(0, 1)),
          ],
        ),
        child: Icon(_icon, color: Colors.white, size: 16),
      ),
    );
  }
}
