class SessionStats {
  final String sessionId;
  final double totalDistanceKm;
  final double avgSpeed;
  final double maxSpeed;
  final int durationMinutes;
  final int locationCount;

  const SessionStats({
    required this.sessionId,
    required this.totalDistanceKm,
    required this.avgSpeed,
    required this.maxSpeed,
    required this.durationMinutes,
    required this.locationCount,
  });

  factory SessionStats.fromJson(Map<String, dynamic> json) {
    return SessionStats(
      sessionId: json['session_id'] ?? '',
      totalDistanceKm: (json['total_distance_km'] as num?)?.toDouble() ?? 0,
      avgSpeed: (json['avg_speed'] as num?)?.toDouble() ?? 0,
      maxSpeed: (json['max_speed'] as num?)?.toDouble() ?? 0,
      durationMinutes: json['duration_minutes'] ?? 0,
      locationCount: json['location_count'] ?? 0,
    );
  }
}
