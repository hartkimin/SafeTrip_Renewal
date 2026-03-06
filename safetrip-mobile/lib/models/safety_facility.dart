/// 안전시설 모델 (지도 원칙 §3 Layer 1)
class SafetyFacility {
  SafetyFacility({
    required this.id,
    required this.name,
    required this.type,
    required this.latitude,
    required this.longitude,
    this.address,
    this.phone,
  });

  factory SafetyFacility.fromJson(Map<String, dynamic> json) {
    return SafetyFacility(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      type: SafetyFacilityType.fromString(json['type'] as String?),
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      address: json['address'] as String?,
      phone: json['phone'] as String?,
    );
  }

  final String id;
  final String name;
  final SafetyFacilityType type;
  final double latitude;
  final double longitude;
  final String? address;
  final String? phone;
}

enum SafetyFacilityType {
  hospital,
  police,
  embassy;

  static SafetyFacilityType fromString(String? value) {
    switch (value) {
      case 'hospital':
        return SafetyFacilityType.hospital;
      case 'police':
        return SafetyFacilityType.police;
      case 'embassy':
        return SafetyFacilityType.embassy;
      default:
        return SafetyFacilityType.hospital;
    }
  }
}
