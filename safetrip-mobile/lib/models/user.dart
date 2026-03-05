class User {

  User({
    required this.userId,
    required this.userName,
    this.fcmToken,
    required this.role,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      userId: json['userId'] as String,
      userName: json['userName'] as String,
      fcmToken: json['fcmToken'] as String?,
      role: UserRole.values.firstWhere(
        (e) => e.toString().split('.').last == json['role'],
        orElse: () => UserRole.crew,
      ),
    );
  }
  final String userId;
  final String userName;
  final String? fcmToken;
  final UserRole role;

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'userName': userName,
      'fcmToken': fcmToken,
      'role': role.toString().split('.').last,
    };
  }

  User copyWith({
    String? userId,
    String? userName,
    String? fcmToken,
    UserRole? role,
  }) {
    return User(
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      fcmToken: fcmToken ?? this.fcmToken,
      role: role ?? this.role,
    );
  }
}

enum UserRole {
  captain,   // 리더
  crewChief, // 공동관리자
  crew,      // 일반 멤버
  guardian,  // 보호자/모니터링
}

/// UserRole 확장 메서드
extension UserRoleExtension on UserRole {
  /// 관리자 권한 여부 (captain 또는 crewChief)
  bool get isAdmin => this == UserRole.captain || this == UserRole.crewChief;

  /// 보호자 여부
  bool get isGuardian => this == UserRole.guardian;

  /// 여행자 여부 (guardian이 아닌 모든 역할)
  bool get isTraveler => !isGuardian;

  /// 서버 member_role 문자열로 변환
  String get memberRoleString {
    switch (this) {
      case UserRole.captain:
        return 'captain';
      case UserRole.crewChief:
        return 'crew_chief';
      case UserRole.crew:
        return 'crew';
      case UserRole.guardian:
        return 'guardian';
    }
  }

  /// 서버 member_role 문자열에서 UserRole 변환
  static UserRole fromMemberRole(String? memberRole) {
    switch (memberRole) {
      case 'captain':
        return UserRole.captain;
      case 'crew_chief':
        return UserRole.crewChief;
      case 'crew':
        return UserRole.crew;
      case 'guardian':
        return UserRole.guardian;
      default:
        return UserRole.crew;
    }
  }
}

