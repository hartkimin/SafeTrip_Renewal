enum TimelineEventType {
  movementStart,
  movementEnd,
  stayPoint,
  sosEvent,
  alertEvent,
  scheduleEvent,
  gpsGap,
  maskedSection,
}

class TimelineEvent {
  final TimelineEventType type;
  final DateTime time;
  final DateTime? endTime;
  final double latitude;
  final double longitude;
  final String? sessionId;
  final int? durationMinutes;
  final String? placeName;
  final bool isMasked;

  const TimelineEvent({
    required this.type,
    required this.time,
    this.endTime,
    required this.latitude,
    required this.longitude,
    this.sessionId,
    this.durationMinutes,
    this.placeName,
    this.isMasked = false,
  });

  factory TimelineEvent.fromJson(Map<String, dynamic> json) {
    return TimelineEvent(
      type: _parseEventType(json['type'] ?? ''),
      time: DateTime.parse(json['time'].toString()),
      endTime: json['end_time'] != null ? DateTime.tryParse(json['end_time'].toString()) : null,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      sessionId: json['session_id'],
      durationMinutes: json['duration_minutes'],
      placeName: json['place_name'],
      isMasked: json['is_masked'] ?? false,
    );
  }

  static TimelineEventType _parseEventType(String type) {
    switch (type) {
      case 'movement_start': return TimelineEventType.movementStart;
      case 'movement_end': return TimelineEventType.movementEnd;
      case 'stay_point': return TimelineEventType.stayPoint;
      case 'sos_event': return TimelineEventType.sosEvent;
      case 'alert_event': return TimelineEventType.alertEvent;
      case 'schedule_event': return TimelineEventType.scheduleEvent;
      case 'gps_gap': return TimelineEventType.gpsGap;
      case 'masked_section': return TimelineEventType.maskedSection;
      default: return TimelineEventType.gpsGap;
    }
  }
}
