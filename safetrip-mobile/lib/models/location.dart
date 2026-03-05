class Location { // RTDB is_moving

  Location({
    required this.userId,
    required this.userName,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.battery,
    this.speed,
    this.updatedAt,
    this.activityType,
    this.isMoving,
  });

  factory Location.fromJson(Map<String, dynamic> json) {
    // MQTT 메시지 형식 (user_id, user_name)과 앱 내부 형식 (userId, userName) 모두 지원
    final userId = json['user_id'] as String? ?? json['userId'] as String?;
    final userName = json['user_name'] as String? ?? json['userName'] as String?;
    
    if (userId == null || userName == null) {
      throw Exception('Location.fromJson: userId 또는 userName이 null입니다. JSON: $json');
    }
    
    // timestamp를 UTC로 파싱 (ISO8601 문자열이 UTC임을 보장)
    // getLocationHistory API는 recorded_at을 사용하므로 둘 다 지원
    final timestampStr = json['timestamp'] as String? ?? json['recorded_at'] as String?;
    if (timestampStr == null) {
      throw Exception('Location.fromJson: timestamp 또는 recorded_at이 null입니다. JSON: $json');
    }
    final parsedTimestamp = DateTime.parse(timestampStr);
    final utcTimestamp = parsedTimestamp.isUtc
        ? parsedTimestamp
        : parsedTimestamp.toUtc();
    
    // latitude와 longitude는 num 또는 String일 수 있음 (DB에서 문자열로 반환될 수 있음)
    double parseCoordinate(dynamic value) {
      if (value == null) {
        throw Exception('Location.fromJson: latitude 또는 longitude가 null입니다.');
      }
      if (value is num) {
        return value.toDouble();
      }
      if (value is String) {
        return double.parse(value);
      }
      throw Exception('Location.fromJson: latitude 또는 longitude 타입이 올바르지 않습니다: ${value.runtimeType}');
    }
    
    return Location(
      userId: userId,
      userName: userName,
      latitude: parseCoordinate(json['latitude']),
      longitude: parseCoordinate(json['longitude']),
      timestamp: utcTimestamp,
      battery: json['battery'] as int? ?? json['battery_level'] as int?,
      speed: json['speed'] != null ? parseCoordinate(json['speed']) : null,
      updatedAt: json['updated_at'] as int?,
      activityType: json['activity_type'] as String?,
      isMoving: json['is_moving'] as bool?,
    );
  }
  final String userId;
  final String userName;
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final int? battery;
  final double? speed; // m/s 단위
  final int? updatedAt; // RTDB updated_at (milliseconds since epoch)
  final String? activityType; // RTDB activity_type
  final bool? isMoving;

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'userName': userName,
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp.toIso8601String(),
      'battery': battery,
      'speed': speed,
    };
  }
}

