class GeofenceEvent {

  GeofenceEvent({
    required this.geofenceId,
    required this.geofenceName,
    required this.geofenceType,
    required this.eventType,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
  });

  factory GeofenceEvent.fromJson(Map<String, dynamic> json) {
    return GeofenceEvent(
      geofenceId: json['geofence_id'] as String,
      geofenceName: json['geofence_name'] as String,
      geofenceType: json['geofence_type'] as String,
      eventType: json['event_type'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
  final String geofenceId;
  final String geofenceName;
  final String geofenceType; // 'safe', 'watch', 'danger', 'stationary'
  final String eventType; // 'enter', 'exit'
  final double latitude;
  final double longitude;
  final DateTime timestamp;

  Map<String, dynamic> toJson() {
    return {
      'geofence_id': geofenceId,
      'geofence_name': geofenceName,
      'geofence_type': geofenceType,
      'event_type': eventType,
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

