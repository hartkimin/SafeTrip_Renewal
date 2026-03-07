import 'package:flutter/material.dart';
import '../../models/timeline_event.dart';
import 'timeline_event_marker.dart';

class TimelineView extends StatelessWidget {
  final List<TimelineEvent> events;
  final int? selectedIndex;
  final ValueChanged<int>? onEventSelected;
  final ScrollController? scrollController;

  const TimelineView({
    super.key,
    required this.events,
    this.selectedIndex,
    this.onEventSelected,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.timeline, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text('이동기록이 없습니다', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: events.length,
      separatorBuilder: (_, __) => _buildConnectorLine(),
      itemBuilder: (context, index) {
        final event = events[index];
        return TimelineEventMarker(
          event: event,
          isSelected: index == selectedIndex,
          onTap: () => onEventSelected?.call(index),
        );
      },
    );
  }

  Widget _buildConnectorLine() {
    return Padding(
      padding: const EdgeInsets.only(left: 25),
      child: Container(
        width: 2,
        height: 24,
        color: Colors.grey.shade300,
      ),
    );
  }
}
