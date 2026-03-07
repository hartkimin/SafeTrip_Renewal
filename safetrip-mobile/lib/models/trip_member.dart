import 'user.dart';

/// 가디언 슬롯 모델 (멤버에 연결된 가디언 정보)
class GuardianSlot {
  const GuardianSlot({
    required this.linkId,
    required this.guardianUserId,
    required this.guardianName,
    this.guardianProfileImageUrl,
    this.isPaid = false,
    this.status = 'pending',
    this.paymentId,
    this.pausedUntil,
  });

  factory GuardianSlot.fromJson(Map<String, dynamic> json) {
    return GuardianSlot(
      linkId: json['link_id'] as String? ??
          json['linkId'] as String? ??
          '',
      guardianUserId: json['guardian_user_id'] as String? ??
          json['guardianUserId'] as String? ??
          json['guardian_id'] as String? ??
          '',
      guardianName: json['guardian_name'] as String? ??
          json['guardianName'] as String? ??
          json['display_name'] as String? ??
          '',
      guardianProfileImageUrl: json['guardian_profile_image_url'] as String? ??
          json['guardianProfileImageUrl'] as String? ??
          json['profile_image_url'] as String?,
      isPaid: json['is_paid'] as bool? ??
          json['isPaid'] as bool? ??
          false,
      status: json['status'] as String? ?? 'pending',
      paymentId: json['payment_id'] as String? ??
          json['paymentId'] as String?,
      pausedUntil: json['paused_until'] != null
          ? DateTime.tryParse(json['paused_until'] as String)
          : (json['pausedUntil'] != null
              ? DateTime.tryParse(json['pausedUntil'] as String)
              : null),
    );
  }

  final String linkId;
  final String guardianUserId;
  final String guardianName;
  final String? guardianProfileImageUrl;

  /// 유/무료 가디언 여부 (SS5.1 — free vs premium)
  final bool isPaid;

  /// 'pending' | 'accepted' | 'rejected'
  final String status;

  final String? paymentId;

  /// 가디언 일시정지 종료 시각
  final DateTime? pausedUntil;

  /// 현재 일시정지 상태 여부
  bool get isPaused =>
      pausedUntil != null && pausedUntil!.isAfter(DateTime.now());

  Map<String, dynamic> toJson() {
    return {
      'link_id': linkId,
      'guardian_user_id': guardianUserId,
      'guardian_name': guardianName,
      'guardian_profile_image_url': guardianProfileImageUrl,
      'is_paid': isPaid,
      'status': status,
      'payment_id': paymentId,
      'paused_until': pausedUntil?.toIso8601String(),
    };
  }
}

/// 여행 멤버 모델 (DOC-T3-MBR-019)
class TripMember {
  const TripMember({
    required this.userId,
    required this.userName,
    required this.memberRole,
    this.profileImageUrl,
    this.b2bRoleName,
    this.isOnline = false,
    this.isSosActive = false,
    this.lastLocationText,
    this.lastLocationUpdatedAt,
    this.latitude,
    this.longitude,
    this.batteryLevel,
    this.privacyLevel = 'standard',
    this.isScheduleOn = true,
    this.isMinor = false,
    this.guardianLinks = const [],
  });

  factory TripMember.fromJson(Map<String, dynamic> json) {
    // guardian_links / guardianLinks 파싱
    final rawGuardianLinks = json['guardian_links'] ?? json['guardianLinks'];
    final List<GuardianSlot> parsedGuardianLinks;
    if (rawGuardianLinks is List) {
      parsedGuardianLinks = rawGuardianLinks
          .map((e) => GuardianSlot.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      parsedGuardianLinks = [];
    }

    // member_role → UserRole 변환
    final roleStr = json['member_role'] as String? ??
        json['memberRole'] as String?;
    final role = UserRoleExtension.fromMemberRole(roleStr);

    // lastLocationUpdatedAt 파싱 (문자열 또는 int timestamp)
    DateTime? locationUpdatedAt;
    final rawLocationTime =
        json['last_location_updated_at'] ?? json['lastLocationUpdatedAt'];
    if (rawLocationTime is String) {
      locationUpdatedAt = DateTime.tryParse(rawLocationTime);
    } else if (rawLocationTime is int) {
      locationUpdatedAt =
          DateTime.fromMillisecondsSinceEpoch(rawLocationTime);
    }

    return TripMember(
      userId: json['user_id'] as String? ??
          json['userId'] as String? ??
          '',
      userName: json['user_name'] as String? ??
          json['userName'] as String? ??
          json['display_name'] as String? ??
          '',
      memberRole: role,
      profileImageUrl: json['profile_image_url'] as String? ??
          json['profileImageUrl'] as String?,
      b2bRoleName: json['b2b_role_name'] as String? ??
          json['b2bRoleName'] as String?,
      isOnline: json['is_online'] as bool? ??
          json['isOnline'] as bool? ??
          false,
      isSosActive: json['is_sos_active'] as bool? ??
          json['isSosActive'] as bool? ??
          false,
      lastLocationText: json['last_location_text'] as String? ??
          json['lastLocationText'] as String?,
      lastLocationUpdatedAt: locationUpdatedAt,
      latitude: _parseDouble(json['latitude']),
      longitude: _parseDouble(json['longitude']),
      batteryLevel: json['battery'] as int? ??
          json['battery_level'] as int? ??
          json['batteryLevel'] as int?,
      privacyLevel: json['privacy_level'] as String? ??
          json['privacyLevel'] as String? ??
          'standard',
      isScheduleOn: json['is_schedule_on'] as bool? ??
          json['isScheduleOn'] as bool? ??
          json['location_sharing_enabled'] as bool? ??
          true,
      isMinor: json['is_minor'] as bool? ??
          json['isMinor'] as bool? ??
          false,
      guardianLinks: parsedGuardianLinks,
    );
  }

  // -- Basic --
  final String userId;
  final String userName;
  final UserRole memberRole;
  final String? profileImageUrl;

  /// B2B 여행에서의 역할명 (SS6 — nullable, B2B 전용)
  final String? b2bRoleName;

  // -- Status --
  final bool isOnline;
  final bool isSosActive;

  // -- Location --
  final String? lastLocationText;
  final DateTime? lastLocationUpdatedAt;
  final double? latitude;
  final double? longitude;

  /// 배터리 잔량 (SS4.2 — 20% 이하 빨간색)
  final int? batteryLevel;

  // -- Privacy --
  /// 'safety_first' | 'standard' | 'privacy_first'
  final String privacyLevel;

  /// 위치 공유 ON/OFF
  final bool isScheduleOn;

  // -- Minor --
  /// 미성년자 여부 (SS10.2)
  final bool isMinor;

  // -- Guardian --
  final List<GuardianSlot> guardianLinks;

  // ---------------------------------------------------------------------------
  // Computed Getters
  // ---------------------------------------------------------------------------

  /// 표시용 역할 이름: B2B 역할명이 있으면 우선, 없으면 한글 역할명
  String get displayRoleName {
    if (b2bRoleName != null && b2bRoleName!.isNotEmpty) {
      return b2bRoleName!;
    }
    switch (memberRole) {
      case UserRole.captain:
        return '캡틴';
      case UserRole.crewChief:
        return '크루장';
      case UserRole.crew:
        return '크루';
      case UserRole.guardian:
        return '가디언';
    }
  }

  /// 프라이버시 정책을 반영한 위치 표시 텍스트 (SS11.1, SS11.3)
  String get locationDisplayText {
    // SOS 활성 시 실제 위치를 항상 표시 (SS11.3)
    if (isSosActive) {
      return lastLocationText ?? '위치 정보 없음';
    }

    // safety_first: 항상 실시간 위치 표시 (ON/OFF 무관, §11.1)
    if (privacyLevel == 'safety_first') {
      return lastLocationText ?? '위치 정보 없음';
    }

    // 위치 공유 OFF 상태
    if (!isScheduleOn) {
      if (privacyLevel == 'privacy_first') {
        return '위치 비공유 중';
      }
      // standard + OFF → 마지막 갱신 시각만 표시
      final timeText = locationTimeText;
      if (timeText != null) {
        return '마지막 갱신: $timeText';
      }
      return '위치 정보 없음';
    }

    // 위치 공유 ON — 실제 위치 텍스트 표시
    return lastLocationText ?? '위치 정보 없음';
  }

  /// 마지막 위치 갱신 시간 텍스트 ("방금" / "N분 전" / "N시간 전")
  String? get locationTimeText {
    if (lastLocationUpdatedAt == null) return null;

    final diff = DateTime.now().difference(lastLocationUpdatedAt!);
    if (diff.inMinutes < 1) return '방금';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    return '${diff.inDays}일 전';
  }

  // ---------------------------------------------------------------------------
  // copyWith
  // ---------------------------------------------------------------------------

  TripMember copyWith({
    String? userId,
    String? userName,
    UserRole? memberRole,
    String? profileImageUrl,
    String? b2bRoleName,
    bool? isOnline,
    bool? isSosActive,
    String? lastLocationText,
    DateTime? lastLocationUpdatedAt,
    double? latitude,
    double? longitude,
    int? batteryLevel,
    String? privacyLevel,
    bool? isScheduleOn,
    bool? isMinor,
    List<GuardianSlot>? guardianLinks,
  }) {
    return TripMember(
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      memberRole: memberRole ?? this.memberRole,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      b2bRoleName: b2bRoleName ?? this.b2bRoleName,
      isOnline: isOnline ?? this.isOnline,
      isSosActive: isSosActive ?? this.isSosActive,
      lastLocationText: lastLocationText ?? this.lastLocationText,
      lastLocationUpdatedAt:
          lastLocationUpdatedAt ?? this.lastLocationUpdatedAt,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      privacyLevel: privacyLevel ?? this.privacyLevel,
      isScheduleOn: isScheduleOn ?? this.isScheduleOn,
      isMinor: isMinor ?? this.isMinor,
      guardianLinks: guardianLinks ?? this.guardianLinks,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'user_name': userName,
      'member_role': memberRole.memberRoleString,
      'profile_image_url': profileImageUrl,
      'b2b_role_name': b2bRoleName,
      'is_online': isOnline,
      'is_sos_active': isSosActive,
      'last_location_text': lastLocationText,
      'last_location_updated_at':
          lastLocationUpdatedAt?.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'battery_level': batteryLevel,
      'privacy_level': privacyLevel,
      'is_schedule_on': isScheduleOn,
      'is_minor': isMinor,
      'guardian_links':
          guardianLinks.map((g) => g.toJson()).toList(),
    };
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// JSON 값을 double로 안전하게 파싱 (int, double, String 모두 처리)
  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}
