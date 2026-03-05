class GeofenceData {

  GeofenceData({
    required this.geofenceId,
    this.tripId,
    this.groupId,
    required this.name,
    this.description,
    required this.type,
    required this.shapeType,
    this.centerLatitude,
    this.centerLongitude,
    this.radiusMeters,
    this.isAlwaysActive = true,
    this.triggerOnEnter = true,
    this.triggerOnExit = true,
    this.isActive = true,
  });

  factory GeofenceData.fromJson(Map<String, dynamic> json) {
    // 숫자 타입 안전 변환 (String 또는 num 모두 처리)
    double? parseDouble(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value);
      return null;
    }

    int? parseInt(dynamic value) {
      if (value == null) {
        return null;
      }
      
      if (value is int) {
        return value;
      }
      if (value is num) {
        return value.toInt();
      }
      if (value is String) {
        return int.tryParse(value);
      }
      
      return null;
    }

    return GeofenceData(
      geofenceId: json['geofence_id'] as String,
      tripId: json['trip_id'] as String?,
      groupId: json['group_id'] as String?,
      name: json['name'] as String,
      description: json['description'] as String?,
      type: json['type'] as String,
      shapeType: json['shape_type'] as String,
      centerLatitude: parseDouble(json['center_latitude']),
      centerLongitude: parseDouble(json['center_longitude']),
      radiusMeters: parseInt(json['radius_meters']),
      isAlwaysActive: json['is_always_active'] as bool? ?? true,
      triggerOnEnter: json['trigger_on_enter'] as bool? ?? true,
      triggerOnExit: json['trigger_on_exit'] as bool? ?? true,
      isActive: json['is_active'] as bool? ?? true,
    );
  }
  final String geofenceId;
  final String? tripId;
  final String? groupId;
  final String name;
  final String? description;
  final String type; // 'safe', 'watch', 'danger', 'stationary'
  final String shapeType; // 'circle', 'polygon'
  final double? centerLatitude;
  final double? centerLongitude;
  final int? radiusMeters;
  final bool isAlwaysActive;
  final bool triggerOnEnter;
  final bool triggerOnExit;
  final bool isActive;

  Map<String, dynamic> toJson() {
    return {
      'geofence_id': geofenceId,
      'trip_id': tripId,
      'group_id': groupId,
      'name': name,
      'description': description,
      'type': type,
      'shape_type': shapeType,
      'center_latitude': centerLatitude,
      'center_longitude': centerLongitude,
      'radius_meters': radiusMeters,
      'is_always_active': isAlwaysActive,
      'trigger_on_enter': triggerOnEnter,
      'trigger_on_exit': triggerOnExit,
      'is_active': isActive,
    };
  }
}
