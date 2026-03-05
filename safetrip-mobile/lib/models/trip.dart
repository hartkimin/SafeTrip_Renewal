class Trip {

  Trip({
    required this.tripId,
    required this.groupId,
    required this.tripName,
    this.destination,
    this.destinationCountryCode,
    required this.startDate,
    required this.endDate,
    required this.status,
    this.sharingMode = 'voluntary',
    this.privacyLevel = 'standard',
    this.hasMinorMembers = false,
    required this.createdAt,
    this.updatedAt,
  });

  factory Trip.fromJson(Map<String, dynamic> json) {
    return Trip(
      tripId: json['trip_id'] as String? ?? json['tripId'] as String? ?? '',
      groupId: json['group_id'] as String? ?? json['groupId'] as String? ?? '',
      tripName: json['trip_name'] as String? ?? json['tripName'] as String? ?? (json['group'] != null ? json['group']['group_name'] as String? ?? '' : ''),
      destination: json['destination'] as String? ?? json['destination_city'] as String?,
      destinationCountryCode: json['destination_country_code'] as String? ?? json['destinationCountryCode'] as String? ?? json['country_code'] as String?,
      startDate: json['start_date'] != null ? DateTime.parse(json['start_date']) : (json['startDate'] != null ? DateTime.parse(json['startDate']) : DateTime.now()),
      endDate: json['end_date'] != null ? DateTime.parse(json['end_date']) : (json['endDate'] != null ? DateTime.parse(json['endDate']) : DateTime.now()),
      status: TripStatusExtension.fromString(json['status'] as String?),
      sharingMode: json['sharing_mode'] as String? ?? json['sharingMode'] as String? ?? 'voluntary',
      privacyLevel: json['privacy_level'] as String? ?? json['privacyLevel'] as String? ?? 'standard',
      hasMinorMembers: json['has_minor_members'] as bool? ?? json['hasMinorMembers'] as bool? ?? false,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : (json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now()),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : (json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null),
    );
  }
  final String tripId;
  final String groupId;
  final String tripName;
  final String? destination;
  final String? destinationCountryCode;
  final DateTime startDate;
  final DateTime endDate;
  final TripStatus status;
  final String sharingMode;
  final String privacyLevel;
  final bool hasMinorMembers;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Map<String, dynamic> toJson() {
    return {
      'trip_id': tripId,
      'group_id': groupId,
      'trip_name': tripName,
      'destination': destination,
      'destination_country_code': destinationCountryCode,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'status': status.toString().split('.').last,
      'sharing_mode': sharingMode,
      'privacy_level': privacyLevel,
      'has_minor_members': hasMinorMembers,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  Trip copyWith({
    String? tripId,
    String? groupId,
    String? tripName,
    String? destination,
    String? destinationCountryCode,
    DateTime? startDate,
    DateTime? endDate,
    TripStatus? status,
    String? sharingMode,
    String? privacyLevel,
    bool? hasMinorMembers,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Trip(
      tripId: tripId ?? this.tripId,
      groupId: groupId ?? this.groupId,
      tripName: tripName ?? this.tripName,
      destination: destination ?? this.destination,
      destinationCountryCode: destinationCountryCode ?? this.destinationCountryCode,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      status: status ?? this.status,
      sharingMode: sharingMode ?? this.sharingMode,
      privacyLevel: privacyLevel ?? this.privacyLevel,
      hasMinorMembers: hasMinorMembers ?? this.hasMinorMembers,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

enum TripStatus {
  planning,
  active,
  completed,
  cancelled,
}

extension TripStatusExtension on TripStatus {
  static TripStatus fromString(String? status) {
    switch (status) {
      case 'active':
        return TripStatus.active;
      case 'completed':
        return TripStatus.completed;
      case 'cancelled':
        return TripStatus.cancelled;
      case 'planning':
      default:
        return TripStatus.planning;
    }
  }
}
