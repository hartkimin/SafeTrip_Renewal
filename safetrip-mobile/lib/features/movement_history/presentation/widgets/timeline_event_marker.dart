import 'package:flutter/material.dart';
import '../../models/timeline_event.dart';

class TimelineEventMarker extends StatelessWidget {
  final TimelineEvent event;
  final bool isSelected;
  final VoidCallback? onTap;

  const TimelineEventMarker({
    super.key,
    required this.event,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).colorScheme.primaryContainer : null,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            _buildMarkerIcon(),
            const SizedBox(width: 12),
            _buildTimeText(context),
            const SizedBox(width: 12),
            Expanded(child: _buildDescription(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildMarkerIcon() {
    switch (event.type) {
      case TimelineEventType.movementStart:
        return const Icon(Icons.play_circle_filled, color: Colors.green, size: 20);
      case TimelineEventType.movementEnd:
        return const Icon(Icons.stop_circle, color: Colors.red, size: 20);
      case TimelineEventType.stayPoint:
        return const Icon(Icons.location_on, color: Colors.blue, size: 20);
      case TimelineEventType.sosEvent:
        return const Icon(Icons.warning_amber, color: Colors.red, size: 20);
      case TimelineEventType.alertEvent:
        return const Icon(Icons.notifications, color: Colors.orange, size: 20);
      case TimelineEventType.scheduleEvent:
        return const Icon(Icons.calendar_today, color: Colors.purple, size: 20);
      case TimelineEventType.gpsGap:
        return const Icon(Icons.signal_wifi_off, color: Colors.grey, size: 20);
      case TimelineEventType.maskedSection:
        return const Icon(Icons.visibility_off, color: Colors.grey, size: 20);
    }
  }

  Widget _buildTimeText(BuildContext context) {
    final localTime = event.time.toLocal();
    final timeStr = '${localTime.hour.toString().padLeft(2, '0')}:${localTime.minute.toString().padLeft(2, '0')}';
    return Text(
      timeStr,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        fontWeight: FontWeight.w600,
        color: event.isMasked ? Colors.grey : null,
      ),
    );
  }

  Widget _buildDescription(BuildContext context) {
    String text;
    switch (event.type) {
      case TimelineEventType.movementStart:
        text = '출발';
      case TimelineEventType.movementEnd:
        text = '도착';
      case TimelineEventType.stayPoint:
        final place = event.placeName ?? '알 수 없는 장소';
        final dur = event.durationMinutes ?? 0;
        text = '$place ($dur분 체류)';
      case TimelineEventType.sosEvent:
        text = 'SOS 이벤트';
      case TimelineEventType.alertEvent:
        text = '안전 알림';
      case TimelineEventType.scheduleEvent:
        text = '일정 시간대';
      case TimelineEventType.gpsGap:
        text = 'GPS 신호 없음';
      case TimelineEventType.maskedSection:
        text = '비공개 구간';
    }
    return Text(
      text,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: event.isMasked ? Colors.grey : null,
      ),
    );
  }
}
