class SOS {

  SOS({
    required this.sosId,
    required this.userId,
    this.userName,
    this.tripId,
    this.groupId,
    required this.latitude,
    required this.longitude,
    this.address,
    required this.triggerType,
    this.message,
    required this.timestamp,
  });

  factory SOS.fromJson(Map<String, dynamic> json) {
    return SOS(
      sosId: json['sos_id'] ?? json['sosId'] ?? '',
      userId: json['user_id'] ?? json['userId'] ?? '',
      userName: json['user_name'] ?? json['userName'],
      tripId: json['trip_id'] ?? json['tripId'],
      groupId: json['group_id'] ?? json['groupId'],
      latitude: (json['latitude'] ?? (json['location']?['latitude'] ?? 0.0)).toDouble(),
      longitude: (json['longitude'] ?? (json['location']?['longitude'] ?? 0.0)).toDouble(),
      address: json['address'] ?? json['location']?['address'],
      triggerType: json['trigger_type'] ?? json['triggerType'] ?? 'manual',
      message: json['message'],
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now().toUtc(),
    );
  }
  final String sosId;
  final String userId;
  final String? userName;
  final String? tripId;
  final String? groupId;
  final double latitude;
  final double longitude;
  final String? address;
  final String triggerType;
  final String? message;
  final DateTime timestamp;

  Map<String, dynamic> toJson() {
    return {
      'sos_id': sosId,
      'user_id': userId,
      'user_name': null, // 서비스에서 추가
      'trip_id': tripId,
      'group_id': groupId,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'trigger_type': triggerType,
      'message': message,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

