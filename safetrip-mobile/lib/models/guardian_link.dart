class GuardianLink {

  const GuardianLink({
    required this.linkId,
    required this.guardianId,
    required this.status,
    required this.createdAt,
    this.acceptedAt,
    required this.displayName,
    required this.phoneNumber,
    this.profileImageUrl,
  });

  factory GuardianLink.fromJson(Map<String, dynamic> json) {
    return GuardianLink(
      linkId: json['link_id'] as String? ?? '',
      guardianId: json['guardian_id'] as String,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      acceptedAt: json['accepted_at'] != null
          ? DateTime.parse(json['accepted_at'] as String)
          : null,
      displayName: json['display_name'] as String? ?? '',
      phoneNumber: json['phone_number'] as String? ?? '',
      profileImageUrl: json['profile_image_url'] as String?,
    );
  }
  final String linkId;
  final String guardianId;
  final String status; // pending | accepted | rejected
  final DateTime createdAt;
  final DateTime? acceptedAt;
  final String displayName;
  final String phoneNumber;
  final String? profileImageUrl;
}

class LinkedMember {

  const LinkedMember({
    required this.linkId,
    required this.memberId,
    required this.displayName,
    required this.phoneNumber,
    this.profileImageUrl,
    this.memberRole,
  });

  factory LinkedMember.fromJson(Map<String, dynamic> json) {
    return LinkedMember(
      linkId: json['link_id'] as String? ?? '',
      memberId: json['member_id'] as String,
      displayName: json['display_name'] as String? ?? '',
      phoneNumber: json['phone_number'] as String? ?? '',
      profileImageUrl: json['profile_image_url'] as String?,
      memberRole: json['member_role'] as String?,
    );
  }
  final String linkId;
  final String memberId;
  final String displayName;
  final String phoneNumber;
  final String? profileImageUrl;
  final String? memberRole;
}

class GuardianInvitation {

  const GuardianInvitation({
    required this.linkId,
    required this.tripId,
    required this.memberId,
    required this.createdAt,
    required this.memberDisplayName,
    required this.memberPhoneNumber,
    this.memberProfileImageUrl,
    required this.tripCountryCode,
    required this.tripCountryName,
    this.tripDestinationCity,
    required this.tripStartDate,
    required this.tripEndDate,
  });

  factory GuardianInvitation.fromJson(Map<String, dynamic> json) {
    return GuardianInvitation(
      linkId: json['link_id'] as String? ?? '',
      tripId: json['trip_id'] as String,
      memberId: json['member_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      memberDisplayName: json['member_display_name'] as String? ?? '',
      memberPhoneNumber: json['member_phone_number'] as String? ?? '',
      memberProfileImageUrl: json['member_profile_image_url'] as String?,
      tripCountryCode: json['trip_country_code'] as String? ?? '',
      tripCountryName: json['trip_country_name'] as String? ?? '',
      tripDestinationCity: json['trip_destination_city'] as String?,
      tripStartDate: json['trip_start_date'] as String? ?? '',
      tripEndDate: json['trip_end_date'] as String? ?? '',
    );
  }
  final String linkId;
  final String tripId;
  final String memberId;
  final DateTime createdAt;
  final String memberDisplayName;
  final String memberPhoneNumber;
  final String? memberProfileImageUrl;
  final String tripCountryCode;
  final String tripCountryName;
  final String? tripDestinationCity;
  final String tripStartDate;
  final String tripEndDate;
}
