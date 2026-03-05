class TripGroup {

  TripGroup({
    required this.groupId,
    required this.groupName,
    this.groupType = 'personal',
    required this.createdBy,
    this.isActive = true,
    this.maxMembers = 50,
    this.currentMemberCount = 1,
    this.inviteCode,
    required this.createdAt,
  });

  factory TripGroup.fromJson(Map<String, dynamic> json) {
    return TripGroup(
      groupId: json['group_id'] as String? ?? json['groupId'] as String? ?? '',
      groupName: json['group_name'] as String? ?? json['groupName'] as String? ?? '',
      groupType: json['group_type'] as String? ?? json['groupType'] as String? ?? 'personal',
      createdBy: json['created_by'] as String? ?? json['createdBy'] as String? ?? '',
      isActive: json['is_active'] as bool? ?? json['isActive'] as bool? ?? true,
      maxMembers: json['max_members'] as int? ?? json['maxMembers'] as int? ?? 50,
      currentMemberCount: json['current_member_count'] as int? ?? json['currentMemberCount'] as int? ?? 1,
      inviteCode: json['invite_code'] as String? ?? json['inviteCode'] as String?,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : (json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now()),
    );
  }
  final String groupId;
  final String groupName;
  final String groupType;
  final String createdBy;
  final bool isActive;
  final int maxMembers;
  final int currentMemberCount;
  final String? inviteCode;
  final DateTime createdAt;

  Map<String, dynamic> toJson() {
    return {
      'group_id': groupId,
      'group_name': groupName,
      'group_type': groupType,
      'created_by': createdBy,
      'is_active': isActive,
      'max_members': maxMembers,
      'current_member_count': currentMemberCount,
      'invite_code': inviteCode,
      'created_at': createdAt.toIso8601String(),
    };
  }

  TripGroup copyWith({
    String? groupId,
    String? groupName,
    String? groupType,
    String? createdBy,
    bool? isActive,
    int? maxMembers,
    int? currentMemberCount,
    String? inviteCode,
    DateTime? createdAt,
  }) {
    return TripGroup(
      groupId: groupId ?? this.groupId,
      groupName: groupName ?? this.groupName,
      groupType: groupType ?? this.groupType,
      createdBy: createdBy ?? this.createdBy,
      isActive: isActive ?? this.isActive,
      maxMembers: maxMembers ?? this.maxMembers,
      currentMemberCount: currentMemberCount ?? this.currentMemberCount,
      inviteCode: inviteCode ?? this.inviteCode,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
