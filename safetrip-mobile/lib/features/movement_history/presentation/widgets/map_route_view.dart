import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../models/timeline_event.dart';

class MapRouteView extends StatelessWidget {
  final List<TimelineEvent> events;
  final int? selectedIndex;
  final ValueChanged<int>? onEventSelected;
  final MapController? mapController;

  const MapRouteView({
    super.key,
    required this.events,
    this.selectedIndex,
    this.onEventSelected,
    this.mapController,
  });

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.map, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text('이동기록이 없습니다', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    final points = events
        .where((e) => e.latitude != 0 && e.longitude != 0)
        .map((e) => LatLng(e.latitude, e.longitude))
        .toList();

    final bounds = LatLngBounds.fromPoints(points);

    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        initialCenter: bounds.center,
        initialZoom: 14,
        minZoom: 3.0,
        maxZoom: 18.0,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
        onTap: (_, __) {},
      ),
      children: [
        TileLayer(
          urlTemplate:
              'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}@2x.png',
          subdomains: const ['a', 'b', 'c', 'd'],
          userAgentPackageName: 'com.urock.safe.trip',
          maxZoom: 19,
          keepBuffer: 3,
        ),
        // §6.2 폴리라인
        PolylineLayer(
          polylines: _buildPolylines(),
        ),
        // §6.3 체류 지점 + 이벤트 마커
        MarkerLayer(
          markers: _buildMarkers(),
        ),
      ],
    );
  }

  List<Polyline> _buildPolylines() {
    // 이동 세션별 폴리라인 (§6.2: 세션별 색상, 최대 8색 순환)
    final sessionColors = [
      Colors.blue, Colors.red, Colors.green, Colors.orange,
      Colors.purple, Colors.teal, Colors.pink, Colors.indigo,
    ];

    final Map<String, List<LatLng>> sessionPaths = {};
    for (final event in events) {
      if (event.sessionId != null && !event.isMasked) {
        sessionPaths.putIfAbsent(event.sessionId!, () => []);
        sessionPaths[event.sessionId!]!.add(LatLng(event.latitude, event.longitude));
      }
    }

    int colorIndex = 0;
    return sessionPaths.entries.map((entry) {
      final color = sessionColors[colorIndex % sessionColors.length];
      colorIndex++;
      return Polyline(
        points: entry.value,
        color: color.withValues(alpha: 0.8),
        strokeWidth: 3.0,
      );
    }).toList();
  }

  List<Marker> _buildMarkers() {
    final markers = <Marker>[];

    for (int i = 0; i < events.length; i++) {
      final event = events[i];
      if (event.isMasked) continue;

      IconData icon;
      Color color;
      switch (event.type) {
        case TimelineEventType.movementStart:
          icon = Icons.play_circle_filled;
          color = Colors.green;
        case TimelineEventType.movementEnd:
          icon = Icons.stop_circle;
          color = Colors.red;
        case TimelineEventType.stayPoint:
          icon = Icons.location_on;
          color = Colors.blue;
        case TimelineEventType.sosEvent:
          icon = Icons.warning_amber;
          color = Colors.red;
        default:
          continue; // 다른 타입은 마커 표시 안 함
      }

      final isSelected = i == selectedIndex;
      markers.add(Marker(
        point: LatLng(event.latitude, event.longitude),
        width: isSelected ? 48 : 32,
        height: isSelected ? 48 : 32,
        child: GestureDetector(
          onTap: () => onEventSelected?.call(i),
          child: Icon(icon, color: color, size: isSelected ? 32 : 24),
        ),
      ));
    }

    return markers;
  }
}
