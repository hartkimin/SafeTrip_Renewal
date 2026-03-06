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

    for (final entry in scenario.locationTracks.entries) {
      final memberId = entry.key;
      final points = entry.value;
      if (points.isEmpty) continue;

      final position = _interpolate(points, currentSimMinutes);
      result[memberId] = position;
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
        'battery': 85, // simulated
        'is_online': true,
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
}
