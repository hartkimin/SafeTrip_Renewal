import 'package:latlong2/latlong.dart';
import '../models/demo_scenario.dart';

/// Generates interpolated marker positions from scenario location_tracks data.
///
/// Given a [currentSimMinutes] offset from trip start, interpolates between
/// adjacent track points to produce smooth marker movement.
class DemoLocationSimulator {
  /// Returns a map of memberId → current LatLng position
  /// at the given [currentSimMinutes] offset.
  static Map<String, LatLng> getPositions({
    required DemoScenario scenario,
    required int currentSimMinutes,
  }) {
    final result = <String, LatLng>{};

    // 1) location_tracks에 있는 멤버 직접 보간
    for (final entry in scenario.locationTracks.entries) {
      final memberId = entry.key;
      final points = entry.value;
      if (points.isEmpty) continue;

      final position = _interpolate(points, currentSimMinutes);
      result[memberId] = position;
    }

    // 2) groupRef가 있는 멤버 → 참조 경로 + 오프셋
    for (final member in scenario.members) {
      if (result.containsKey(member.id)) continue;
      if (member.role == 'guardian') continue;

      if (member.groupRef != null) {
        final refPoints = scenario.locationTracks[member.groupRef];
        if (refPoints != null && refPoints.isNotEmpty) {
          final basePos = _interpolate(refPoints, currentSimMinutes);
          result[member.id] = applyGroupOffset(basePos, member.id);
        }
      }
    }

    return result;
  }

  /// Returns member data in the format compatible with MarkerManager
  static List<Map<String, dynamic>> getMemberData({
    required DemoScenario scenario,
    required int currentSimMinutes,
  }) {
    final positions = getPositions(
      scenario: scenario,
      currentSimMinutes: currentSimMinutes,
    );

    return scenario.members
        .where((m) => m.role != 'guardian')
        .map((member) {
      final pos = positions[member.id];
      return {
        'user_id': member.id,
        'user_name': member.name,
        'role': member.role,
        'latitude': pos?.latitude ?? scenario.destination.lat,
        'longitude': pos?.longitude ?? scenario.destination.lng,
        'battery': member.battery ?? (75 + (member.id.hashCode.abs() % 25)),
        'is_online': member.isOnline,
        'is_minor': member.isMinor,
        'b2b_role_name': member.b2bRoleName,
        'last_updated': DateTime.now().toIso8601String(),
      };
    }).toList();
  }

  static LatLng _interpolate(List<DemoLocationPoint> points, int minutes) {
    // Before first point → use first point
    if (minutes <= points.first.t) return points.first.latLng;

    // After last point → use last point
    if (minutes >= points.last.t) return points.last.latLng;

    // Find bracketing points and interpolate
    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];

      if (minutes >= p0.t && minutes <= p1.t) {
        final range = p1.t - p0.t;
        if (range == 0) return p0.latLng;

        final fraction = (minutes - p0.t) / range;
        return LatLng(
          p0.lat + (p1.lat - p0.lat) * fraction,
          p0.lng + (p1.lng - p0.lng) * fraction,
        );
      }
    }

    return points.last.latLng;
  }

  /// S1 등 대규모 그룹에서 그룹 대표 경로에 멤버별 미세 오프셋 적용.
  /// 약 ±2m 범위 내 분산.
  static LatLng applyGroupOffset(LatLng base, String memberId) {
    final hash = memberId.hashCode.abs();
    final offsetLat = ((hash % 100) - 50) * 0.00002;
    final offsetLng = (((hash ~/ 100) % 100) - 50) * 0.00002;
    return LatLng(base.latitude + offsetLat, base.longitude + offsetLng);
  }
}
