/// PostgreSQL raw query에서 int/String 혼용 반환 대응
int _parseInt(dynamic value) {
  if (value is int) return value;
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

/// TB_TRIP_CARD_VIEW 매핑 모델 (DOC-T3-TIC-024 §11.3)
///
/// 서버 GET /trips/card-view 응답의 memberTrips / guardianTrips 각 항목을
/// Dart 객체로 변환한다.
class MemberTripCard {
  const MemberTripCard({
    required this.tripId,
    required this.tripName,
    required this.status,
    required this.startDate,
    required this.endDate,
    required this.tripDays,
    required this.privacyLevel,
    required this.sharingMode,
    this.scheduleType,
    this.countryCode,
    this.countryName,
    this.destinationCity,
    this.hasMinorMembers = false,
    this.reactivationCount = 0,
    this.dDay,
    this.currentDay,
    this.memberCount = 0,
    this.canReactivate = false,
    required this.userRole,
    this.isAdmin = false,
    this.todayScheduleSummary,
    this.totalDistanceKm,
    this.visitedPlaces,
    this.groupId,
  });

  factory MemberTripCard.fromJson(Map<String, dynamic> json) {
    return MemberTripCard(
      tripId: json['trip_id'] as String? ?? '',
      tripName: json['trip_name'] as String? ?? '',
      status: json['status'] as String? ?? 'planning',
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: DateTime.parse(json['end_date'] as String),
      tripDays: json['trip_days'] as int? ?? 0,
      privacyLevel: json['privacy_level'] as String? ?? 'standard',
      sharingMode: json['sharing_mode'] as String? ?? 'voluntary',
      scheduleType: json['schedule_type'] as String?,
      countryCode: json['country_code'] as String?,
      countryName: json['country_name'] as String?,
      destinationCity: json['destination_city'] as String?,
      hasMinorMembers: json['has_minor_members'] as bool? ?? false,
      reactivationCount: json['reactivation_count'] as int? ?? 0,
      dDay: json['d_day'] as int?,
      currentDay: json['current_day'] as int?,
      memberCount: _parseInt(json['member_count']),
      canReactivate: json['can_reactivate'] as bool? ?? false,
      userRole: json['user_role'] as String? ?? 'crew',
      isAdmin: json['is_admin'] as bool? ?? false,
      todayScheduleSummary: json['today_schedule_summary'] as String?,
      totalDistanceKm: (json['total_distance_km'] as num?)?.toDouble(),
      visitedPlaces: json['visited_places'] as int?,
      groupId: json['group_id'] as String?,
    );
  }

  final String tripId;
  final String tripName;
  final String status; // planning | active | completed
  final DateTime startDate;
  final DateTime endDate;
  final int tripDays;
  final String privacyLevel; // safety_first | standard | privacy_first
  final String sharingMode;
  final String? scheduleType;
  final String? countryCode;
  final String? countryName;
  final String? destinationCity;
  final bool hasMinorMembers;
  final int reactivationCount;
  final int? dDay;
  final int? currentDay;
  final int memberCount;
  final bool canReactivate;
  final String userRole; // captain | crew_chief | crew
  final bool isAdmin;
  final String? todayScheduleSummary;
  final double? totalDistanceKm;
  final int? visitedPlaces;
  final String? groupId;

  /// D-day 표시 문자열 (§03.2)
  /// D-15~D-1, "여행 중", "완료"
  String get dDayDisplay {
    if (status == 'completed') return '완료';
    if (status == 'active') return '여행 중';
    if (dDay == null) return '';
    if (dDay! > 15) return ''; // D-16 이상은 비표시
    if (dDay! == 0) return '여행 중';
    return 'D-$dDay';
  }
}

class GuardianTripCard {
  const GuardianTripCard({
    required this.tripId,
    required this.tripName,
    required this.status,
    required this.startDate,
    required this.endDate,
    this.memberName,
    this.guardianType,
    this.isPaid = false,
    this.locationSharingStatus = false,
    this.privacyLevel,
    this.todayScheduleSummary,
  });

  factory GuardianTripCard.fromJson(Map<String, dynamic> json) {
    return GuardianTripCard(
      tripId: json['trip_id'] as String? ?? '',
      tripName: json['trip_name'] as String? ?? '',
      status: json['status'] as String? ?? 'planning',
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: DateTime.parse(json['end_date'] as String),
      memberName: json['member_name'] as String?,
      guardianType: json['guardian_type'] as String?,
      isPaid: json['is_paid'] as bool? ?? false,
      locationSharingStatus: json['location_sharing_status'] as bool? ?? false,
      privacyLevel: json['privacy_level'] as String?,
      todayScheduleSummary: json['today_schedule_summary'] as String?,
    );
  }

  final String tripId;
  final String tripName;
  final String status;
  final DateTime startDate;
  final DateTime endDate;
  final String? memberName;
  final String? guardianType; // personal | full
  final bool isPaid;
  final bool locationSharingStatus;
  final String? privacyLevel;
  final String? todayScheduleSummary;

  /// 무료 가디언인지 (§05.2)
  bool get isFreeGuardian => !isPaid;

  /// 전체 가디언인지 (§05.4)
  bool get isFullGuardian => guardianType == 'full';
}

/// 카드뷰 API 전체 응답
class TripCardViewData {
  const TripCardViewData({
    this.memberTrips = const [],
    this.guardianTrips = const [],
  });

  factory TripCardViewData.fromJson(Map<String, dynamic> json) {
    return TripCardViewData(
      memberTrips: (json['memberTrips'] as List<dynamic>?)
              ?.map((e) => MemberTripCard.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      guardianTrips: (json['guardianTrips'] as List<dynamic>?)
              ?.map((e) => GuardianTripCard.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  final List<MemberTripCard> memberTrips;
  final List<GuardianTripCard> guardianTrips;

  /// active 여행 수 (P2-4 복수 active 경고용)
  int get activeCount => memberTrips.where((t) => t.status == 'active').length;

  /// 현재 표시할 메인 카드 (C1: 가장 최근 active 여행 우선, §09.2)
  MemberTripCard? get primaryTrip {
    final active = memberTrips.where((t) => t.status == 'active').toList();
    if (active.isNotEmpty) return active.first; // 이미 start_date DESC 정렬
    final planning = memberTrips.where((t) => t.status == 'planning').toList();
    if (planning.isNotEmpty) return planning.first;
    return memberTrips.isNotEmpty ? memberTrips.first : null;
  }

  /// 여행이 하나도 없는 경우 (§04.4 탐색 모드)
  bool get isEmpty => memberTrips.isEmpty && guardianTrips.isEmpty;
}
