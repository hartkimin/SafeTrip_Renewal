class MovementHistoryData {
  final List<MovementSessionData> sessions;
  final String date;
  final int total;
  final bool upgradeRequired;

  const MovementHistoryData({
    required this.sessions,
    required this.date,
    required this.total,
    this.upgradeRequired = false,
  });

  factory MovementHistoryData.fromJson(Map<String, dynamic> json) {
    return MovementHistoryData(
      sessions: (json['sessions'] as List? ?? [])
          .map((s) => MovementSessionData.fromJson(s as Map<String, dynamic>))
          .toList(),
      date: json['date'] as String? ?? '',
      total: json['total'] as int? ?? 0,
      upgradeRequired: json['upgrade_required'] as bool? ?? false,
    );
  }
}

class MovementSessionData {
  final String sessionId;
  final DateTime? startTime;
  final DateTime? endTime;
  final bool isCompleted;
  final int locationCount;

  const MovementSessionData({
    required this.sessionId,
    this.startTime,
    this.endTime,
    this.isCompleted = false,
    this.locationCount = 0,
  });

  factory MovementSessionData.fromJson(Map<String, dynamic> json) {
    return MovementSessionData(
      sessionId: json['session_id'] as String? ?? json['sessionId'] as String? ?? '',
      startTime: json['start_time'] != null
          ? DateTime.tryParse(json['start_time'].toString())
          : null,
      endTime: json['end_time'] != null
          ? DateTime.tryParse(json['end_time'].toString())
          : null,
      isCompleted: json['is_completed'] as bool? ?? json['isCompleted'] as bool? ?? false,
      locationCount: json['location_count'] as int? ?? 0,
    );
  }
}
