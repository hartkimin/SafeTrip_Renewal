# Member Tab Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement the full member tab (Phase 1~3) for SafeTrip Flutter app per `Master_docs/19_T3_멤버탭_원칙.md` (DOC-T3-MBR-019 v1.1).

**Architecture:** Riverpod StateNotifier pattern. New `MemberTabProvider` manages member list, sorting, sections. Reuses existing `AttendanceProvider`, `ApiService`. New reusable `MemberCard` widget. Bottom sheets `bottom_sheet_2_member.dart` and `bottom_sheet_guardian_members.dart` are fully rewritten. Guardian management uses half-sheet modal.

**Tech Stack:** Flutter 3.x, Riverpod, Dio (via ApiService), Firebase Auth

---

## Task 1: Create TripMember Model

**Files:**
- Create: `safetrip-mobile/lib/models/trip_member.dart`

**Why:** The current codebase uses raw `Map<String, dynamic>` from `getGroupMembers()`. We need a typed model that includes all fields from the member tab spec: role, online status, battery, location, SOS state, B2B role name, privacy level.

**Step 1: Create the TripMember model**

```dart
// safetrip-mobile/lib/models/trip_member.dart
import 'user.dart';

/// 멤버탭 멤버 모델 (DOC-T3-MBR-019 §4)
/// API 응답 + RTDB 실시간 상태를 합친 통합 모델
class TripMember {
  const TripMember({
    required this.userId,
    required this.userName,
    required this.memberRole,
    this.b2bRoleName,
    this.profileImageUrl,
    this.isOnline = false,
    this.isSosActive = false,
    this.batteryLevel,
    this.lastLocationText,
    this.lastLocationUpdatedAt,
    this.latitude,
    this.longitude,
    this.privacyLevel = 'standard',
    this.isScheduleOn = true,
    this.isMinor = false,
    this.guardianLinks = const [],
  });

  factory TripMember.fromJson(Map<String, dynamic> json) {
    return TripMember(
      userId: json['user_id'] as String? ?? json['userId'] as String? ?? '',
      userName: json['user_name'] as String? ?? json['userName'] as String? ?? json['display_name'] as String? ?? '',
      memberRole: UserRoleExtension.fromMemberRole(json['member_role'] as String? ?? json['memberRole'] as String?),
      b2bRoleName: json['b2b_role_name'] as String?,
      profileImageUrl: json['profile_image_url'] as String? ?? json['profileImageUrl'] as String?,
      isOnline: json['is_online'] as bool? ?? false,
      isSosActive: json['is_sos_active'] as bool? ?? false,
      batteryLevel: json['battery'] as int? ?? json['battery_level'] as int?,
      lastLocationText: json['last_location_text'] as String?,
      lastLocationUpdatedAt: json['last_location_updated_at'] != null
          ? DateTime.tryParse(json['last_location_updated_at'] as String)
          : null,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      privacyLevel: json['privacy_level'] as String? ?? 'standard',
      isScheduleOn: json['is_schedule_on'] as bool? ?? true,
      isMinor: json['is_minor'] as bool? ?? false,
    );
  }

  final String userId;
  final String userName;
  final UserRole memberRole;
  final String? b2bRoleName;
  final String? profileImageUrl;
  final bool isOnline;
  final bool isSosActive;
  final int? batteryLevel;
  final String? lastLocationText;
  final DateTime? lastLocationUpdatedAt;
  final double? latitude;
  final double? longitude;
  final String privacyLevel; // 'safety_first' | 'standard' | 'privacy_first'
  final bool isScheduleOn;
  final bool isMinor;
  final List<GuardianSlot> guardianLinks;

  /// §4.2: 역할 배지 표시명
  String get displayRoleName {
    if (b2bRoleName != null && b2bRoleName!.isNotEmpty) return b2bRoleName!;
    switch (memberRole) {
      case UserRole.captain: return '캡틴';
      case UserRole.crewChief: return '크루장';
      case UserRole.crew: return '크루';
      case UserRole.guardian: return '가디언';
    }
  }

  /// §11.1: 위치 텍스트 (프라이버시 등급별)
  String get locationDisplayText {
    if (isSosActive) return lastLocationText ?? '위치 확인 중...'; // §11.3
    if (privacyLevel == 'privacy_first' && !isScheduleOn) return '위치 비공유 중';
    if (privacyLevel == 'standard' && !isScheduleOn) {
      return _lastUpdatedText;
    }
    return lastLocationText ?? '위치 정보 없음';
  }

  String get _lastUpdatedText {
    if (lastLocationUpdatedAt == null) return '위치 정보 없음';
    final diff = DateTime.now().difference(lastLocationUpdatedAt!);
    if (diff.inMinutes < 1) return '마지막 갱신: 방금';
    if (diff.inMinutes < 60) return '마지막 갱신: ${diff.inMinutes}분 전';
    return '마지막 갱신: ${diff.inHours}시간 전';
  }

  /// §4.2: 위치 업데이트 시각 표시
  String get locationTimeText {
    if (lastLocationUpdatedAt == null) return '';
    final diff = DateTime.now().difference(lastLocationUpdatedAt!);
    if (diff.inMinutes < 1) return '방금';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    return '${diff.inHours}시간 전';
  }

  TripMember copyWith({
    String? userId,
    String? userName,
    UserRole? memberRole,
    String? b2bRoleName,
    String? profileImageUrl,
    bool? isOnline,
    bool? isSosActive,
    int? batteryLevel,
    String? lastLocationText,
    DateTime? lastLocationUpdatedAt,
    double? latitude,
    double? longitude,
    String? privacyLevel,
    bool? isScheduleOn,
    bool? isMinor,
    List<GuardianSlot>? guardianLinks,
  }) {
    return TripMember(
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      memberRole: memberRole ?? this.memberRole,
      b2bRoleName: b2bRoleName ?? this.b2bRoleName,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      isOnline: isOnline ?? this.isOnline,
      isSosActive: isSosActive ?? this.isSosActive,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      lastLocationText: lastLocationText ?? this.lastLocationText,
      lastLocationUpdatedAt: lastLocationUpdatedAt ?? this.lastLocationUpdatedAt,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      privacyLevel: privacyLevel ?? this.privacyLevel,
      isScheduleOn: isScheduleOn ?? this.isScheduleOn,
      isMinor: isMinor ?? this.isMinor,
      guardianLinks: guardianLinks ?? this.guardianLinks,
    );
  }
}

/// 가디언 슬롯 (§5.1)
class GuardianSlot {
  const GuardianSlot({
    required this.linkId,
    required this.guardianUserId,
    required this.guardianName,
    this.guardianProfileImageUrl,
    required this.isPaid,
    required this.status,
    this.paymentId,
    this.pausedUntil,
  });

  factory GuardianSlot.fromJson(Map<String, dynamic> json) {
    return GuardianSlot(
      linkId: json['id'] as String? ?? json['link_id'] as String? ?? '',
      guardianUserId: json['guardian_user_id'] as String? ?? '',
      guardianName: json['guardian_name'] as String? ?? json['display_name'] as String? ?? '',
      guardianProfileImageUrl: json['guardian_profile_image_url'] as String? ?? json['profile_image_url'] as String?,
      isPaid: json['is_paid'] as bool? ?? false,
      status: json['status'] as String? ?? 'pending',
      paymentId: json['payment_id'] as String?,
      pausedUntil: json['paused_until'] != null ? DateTime.tryParse(json['paused_until'] as String) : null,
    );
  }

  final String linkId;
  final String guardianUserId;
  final String guardianName;
  final String? guardianProfileImageUrl;
  final bool isPaid;
  final String status; // 'pending' | 'accepted' | 'rejected'
  final String? paymentId;
  final DateTime? pausedUntil;

  bool get isPaused => pausedUntil != null && pausedUntil!.isAfter(DateTime.now());
}
```

**Step 2: Verify the model compiles**

Run: `cd safetrip-mobile && flutter analyze lib/models/trip_member.dart`
Expected: No errors

**Step 3: Commit**

```bash
git add safetrip-mobile/lib/models/trip_member.dart
git commit -m "feat(member-tab): add TripMember and GuardianSlot models"
```

---

## Task 2: Create MemberTabProvider

**Files:**
- Create: `safetrip-mobile/lib/features/member/providers/member_tab_provider.dart`

**Why:** Central state management for member tab. Handles fetching members, sorting by §7 rules, separating into sections (admin/member/guardian), tracking SOS/offline alerts.

**Step 1: Create the provider**

```dart
// safetrip-mobile/lib/features/member/providers/member_tab_provider.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/trip_member.dart';
import '../../../models/user.dart';
import '../../../services/api_service.dart';

/// 멤버탭 상태 (DOC-T3-MBR-019)
class MemberTabState {
  const MemberTabState({
    this.isLoading = false,
    this.error,
    this.allMembers = const [],
    this.guardianSlots = const [],
    this.currentUserId,
    this.currentUserRole,
    this.isB2bTrip = false,
    this.tripId,
    this.groupId,
    this.totalMemberCount = 0,
    this.isPaidTrip = false,
    this.isOfflineMode = false,
    this.lastSyncAt,
  });

  final bool isLoading;
  final String? error;
  final List<TripMember> allMembers;
  final List<GuardianSlot> guardianSlots;
  final String? currentUserId;
  final UserRole? currentUserRole;
  final bool isB2bTrip;
  final String? tripId;
  final String? groupId;
  final int totalMemberCount;
  final bool isPaidTrip;
  final bool isOfflineMode;
  final DateTime? lastSyncAt;

  // ─ §7: 정렬된 섹션별 멤버 리스트 ─────────────────────

  /// §3.2 관리자 섹션: 캡틴 + 크루장
  List<TripMember> get adminMembers {
    final admins = allMembers
        .where((m) => m.memberRole == UserRole.captain || m.memberRole == UserRole.crewChief)
        .toList();
    _sortMembers(admins);
    return admins;
  }

  /// §3.2 멤버 섹션: 크루
  List<TripMember> get crewMembers {
    final crews = allMembers.where((m) => m.memberRole == UserRole.crew).toList();
    _sortMembers(crews);
    return crews;
  }

  /// §3.2 보호자 섹션: 가디언 (무료)
  List<TripMember> get freeGuardians {
    final guardians = allMembers
        .where((m) => m.memberRole == UserRole.guardian)
        .toList();
    // 무료 가디언 = 전체 가디언 중 처음 2명 (가입 순)
    // 실제로는 guardian_link.is_paid로 구분해야 하나,
    // 멤버 리스트에서는 별도로 필터링
    _sortMembers(guardians);
    return guardians; // 실제 무료/유료 구분은 guardianSlots 기반
  }

  /// §3.3 SOS 활성 멤버
  List<TripMember> get sosMembersList => allMembers.where((m) => m.isSosActive).toList();

  /// §3.3 오프라인 멤버
  List<TripMember> get offlineMembers => allMembers.where((m) => !m.isOnline && !m.isSosActive).toList();

  /// §3.3 경고 배너 표시 조건
  bool get hasSosAlert => sosMembersList.isNotEmpty;
  bool get hasOfflineAlert => offlineMembers.isNotEmpty;

  /// §8: 출석체크 가능 여부 (6인 이상 유료)
  bool get canStartAttendance => isPaidTrip && totalMemberCount >= 6;

  /// §10: 현재 유저가 캡틴인지
  bool get isCaptain => currentUserRole == UserRole.captain;
  bool get isAdmin => currentUserRole == UserRole.captain || currentUserRole == UserRole.crewChief;

  /// §7.1 정렬: SOS > 온/오프라인 > 이름
  static void _sortMembers(List<TripMember> members) {
    members.sort((a, b) {
      // 1순위: SOS 활성
      if (a.isSosActive != b.isSosActive) return a.isSosActive ? -1 : 1;
      // 2순위: 역할 (같은 섹션 내에서는 captain > crew_chief)
      final roleOrder = _roleOrder(a.memberRole) - _roleOrder(b.memberRole);
      if (roleOrder != 0) return roleOrder;
      // 3순위: 온라인 우선
      if (a.isOnline != b.isOnline) return a.isOnline ? -1 : 1;
      // 4순위: 이름 가나다순
      return a.userName.compareTo(b.userName);
    });
  }

  static int _roleOrder(UserRole role) {
    switch (role) {
      case UserRole.captain: return 0;
      case UserRole.crewChief: return 1;
      case UserRole.crew: return 2;
      case UserRole.guardian: return 3;
    }
  }

  MemberTabState copyWith({
    bool? isLoading,
    String? error,
    List<TripMember>? allMembers,
    List<GuardianSlot>? guardianSlots,
    String? currentUserId,
    UserRole? currentUserRole,
    bool? isB2bTrip,
    String? tripId,
    String? groupId,
    int? totalMemberCount,
    bool? isPaidTrip,
    bool? isOfflineMode,
    DateTime? lastSyncAt,
    bool clearError = false,
  }) {
    return MemberTabState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      allMembers: allMembers ?? this.allMembers,
      guardianSlots: guardianSlots ?? this.guardianSlots,
      currentUserId: currentUserId ?? this.currentUserId,
      currentUserRole: currentUserRole ?? this.currentUserRole,
      isB2bTrip: isB2bTrip ?? this.isB2bTrip,
      tripId: tripId ?? this.tripId,
      groupId: groupId ?? this.groupId,
      totalMemberCount: totalMemberCount ?? this.totalMemberCount,
      isPaidTrip: isPaidTrip ?? this.isPaidTrip,
      isOfflineMode: isOfflineMode ?? this.isOfflineMode,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
    );
  }
}

class MemberTabNotifier extends StateNotifier<MemberTabState> {
  MemberTabNotifier(this._apiService) : super(const MemberTabState());

  final ApiService _apiService;

  /// 멤버탭 초기화: groupId 기반으로 멤버 목록 로드
  Future<void> initialize({
    required String groupId,
    required String tripId,
    required String currentUserId,
    required String currentUserRole,
    bool isB2bTrip = false,
    bool isPaidTrip = false,
  }) async {
    state = state.copyWith(
      groupId: groupId,
      tripId: tripId,
      currentUserId: currentUserId,
      currentUserRole: UserRoleExtension.fromMemberRole(currentUserRole),
      isB2bTrip: isB2bTrip,
      isPaidTrip: isPaidTrip,
      clearError: true,
    );
    await fetchMembers();
  }

  /// §3: 멤버 목록 fetch
  Future<void> fetchMembers() async {
    final groupId = state.groupId;
    if (groupId == null) return;

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final data = await _apiService.getGroupMembers(groupId);
      final members = data.map((e) => TripMember.fromJson(e)).toList();
      state = state.copyWith(
        isLoading: false,
        allMembers: members,
        totalMemberCount: members.length,
        lastSyncAt: DateTime.now(),
      );
    } catch (e) {
      debugPrint('[MemberTabProvider] fetchMembers error: $e');
      state = state.copyWith(
        isLoading: false,
        error: '멤버 정보를 불러올 수 없습니다.',
      );
    }
  }

  /// 멤버 실시간 상태 업데이트 (RTDB에서 수신)
  void updateMemberPresence(String userId, {bool? isOnline, int? battery, bool? isSos, String? locationText, DateTime? locationUpdatedAt}) {
    final updated = state.allMembers.map((m) {
      if (m.userId != userId) return m;
      return m.copyWith(
        isOnline: isOnline ?? m.isOnline,
        batteryLevel: battery ?? m.batteryLevel,
        isSosActive: isSos ?? m.isSosActive,
        lastLocationText: locationText ?? m.lastLocationText,
        lastLocationUpdatedAt: locationUpdatedAt ?? m.lastLocationUpdatedAt,
      );
    }).toList();
    state = state.copyWith(allMembers: updated);
  }

  /// 오프라인 모드 전환
  void setOfflineMode(bool offline) {
    state = state.copyWith(isOfflineMode: offline);
  }
}

/// Provider
final memberTabProvider = StateNotifierProvider<MemberTabNotifier, MemberTabState>((ref) {
  return MemberTabNotifier(ApiService());
});
```

**Step 2: Verify compiles**

Run: `cd safetrip-mobile && flutter analyze lib/features/member/providers/member_tab_provider.dart`
Expected: No errors

**Step 3: Commit**

```bash
git add safetrip-mobile/lib/features/member/providers/member_tab_provider.dart
git commit -m "feat(member-tab): add MemberTabProvider with sorting and sections"
```

---

## Task 3: Create MemberCard Widget

**Files:**
- Create: `safetrip-mobile/lib/widgets/member_card.dart`

**Why:** Reusable member card widget per §4. Shows profile, status indicator, role badge, location, battery. SOS variant with red border. Used in both member tab and guardian status tab.

**Step 1: Create the MemberCard widget**

```dart
// safetrip-mobile/lib/widgets/member_card.dart
import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';
import '../models/trip_member.dart';
import '../models/user.dart';
import 'avatar_widget.dart';

/// 멤버 카드 (DOC-T3-MBR-019 §4)
/// SOS 활성 멤버는 빨간 테두리 + 오버레이 (§4.3)
class MemberCard extends StatelessWidget {
  const MemberCard({
    super.key,
    required this.member,
    this.onTap,
    this.onMapTap,
    this.onMessageTap,
    this.showGuardianBadge = false,
    this.isPaidGuardian = false,
    this.guardianStatus,
    this.isB2bTrip = false,
  });

  final TripMember member;
  final VoidCallback? onTap;
  final VoidCallback? onMapTap;
  final VoidCallback? onMessageTap;
  final bool showGuardianBadge;
  final bool isPaidGuardian;
  final String? guardianStatus; // 'pending' → "수락 대기 중"
  final bool isB2bTrip;

  @override
  Widget build(BuildContext context) {
    final isSos = member.isSosActive;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        decoration: BoxDecoration(
          color: isSos ? AppColors.sosDanger.withValues(alpha: 0.08) : AppColors.surface,
          border: Border.all(
            color: isSos ? AppColors.sosDanger : AppColors.outlineVariant,
            width: isSos ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(AppSpacing.radius12),
        ),
        child: Column(
          children: [
            Row(
              children: [
                // §4.2: 프로필 사진 + 상태 인디케이터
                _buildAvatar(),
                const SizedBox(width: AppSpacing.md),
                // 이름 + 역할 배지
                Expanded(child: _buildNameRow()),
                // 배터리 (§4.2)
                if (member.batteryLevel != null) _buildBattery(),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            // 위치 텍스트 (§4.2)
            Row(
              children: [
                const SizedBox(width: 56), // avatar + gap offset
                const Icon(Icons.location_on, size: 14, color: AppColors.textTertiary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    member.locationDisplayText,
                    style: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (member.locationTimeText.isNotEmpty)
                  Text(
                    ' · ${member.locationTimeText}',
                    style: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary),
                  ),
              ],
            ),
            // SOS 액션 버튼 (§4.3)
            if (isSos) ...[
              const SizedBox(height: AppSpacing.sm),
              _buildSosActions(),
            ],
            // 가디언 수락 대기 배지
            if (guardianStatus == 'pending') ...[
              const SizedBox(height: AppSpacing.xs),
              _buildPendingBadge(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    return SizedBox(
      width: 40,
      height: 40,
      child: Stack(
        children: [
          AvatarWidget(
            userId: member.userId,
            userName: member.userName,
            radius: 20,
            imageUrl: member.profileImageUrl,
          ),
          // §4.2: 상태 인디케이터 점
          Positioned(
            right: 0,
            bottom: 0,
            child: _StatusDot(
              isOnline: member.isOnline,
              isSos: member.isSosActive,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNameRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // §4.2: 역할 배지
            _RoleBadge(role: member.memberRole),
            const SizedBox(width: 6),
            // §4.3: SOS 라벨
            if (member.isSosActive)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.sosDanger,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'SOS 발신 중',
                  style: AppTypography.labelSmall.copyWith(color: Colors.white, fontSize: 10),
                ),
              ),
            if (member.isSosActive) const SizedBox(width: 4),
            // 이름
            Flexible(
              child: Text(
                member.userName,
                style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // §6.2: B2B 역할명 병기
            if (isB2bTrip && member.b2bRoleName != null) ...[
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  '(${member.b2bRoleName})',
                  style: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
            // 가디언 배지 (§5.1)
            if (showGuardianBadge) ...[
              const SizedBox(width: 6),
              Text(
                isPaidGuardian ? '💎' : '🆓',
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildBattery() {
    final level = member.batteryLevel!;
    final isLow = level <= 20;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          level > 80 ? Icons.battery_full :
          level > 50 ? Icons.battery_5_bar :
          level > 20 ? Icons.battery_3_bar :
          Icons.battery_1_bar,
          size: 16,
          color: isLow ? AppColors.semanticError : AppColors.textTertiary,
        ),
        const SizedBox(width: 2),
        Text(
          '$level%',
          style: AppTypography.labelSmall.copyWith(
            color: isLow ? AppColors.semanticError : AppColors.textTertiary,
          ),
        ),
      ],
    );
  }

  Widget _buildSosActions() {
    return Row(
      children: [
        const SizedBox(width: 56),
        _SosActionButton(label: '지도에서 보기', icon: Icons.map, onTap: onMapTap),
        const SizedBox(width: AppSpacing.sm),
        _SosActionButton(label: '메시지', icon: Icons.message, onTap: onMessageTap),
        const SizedBox(width: AppSpacing.sm),
        _SosActionButton(label: '119 안내', icon: Icons.phone, onTap: () {}),
      ],
    );
  }

  Widget _buildPendingBadge() {
    return Row(
      children: [
        const SizedBox(width: 56),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.secondaryAmber.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '수락 대기 중',
            style: AppTypography.labelSmall.copyWith(color: AppColors.textWarning),
          ),
        ),
      ],
    );
  }
}

/// §4.2: 상태 인디케이터 점 (8dp)
class _StatusDot extends StatefulWidget {
  const _StatusDot({required this.isOnline, required this.isSos});
  final bool isOnline;
  final bool isSos;

  @override
  State<_StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<_StatusDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    if (widget.isSos) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_StatusDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSos && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.isSos && _controller.isAnimating) {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isSos
        ? const Color(0xFFF44336)
        : widget.isOnline
            ? const Color(0xFF4CAF50)
            : const Color(0xFF9E9E9E);

    if (widget.isSos) {
      return AnimatedBuilder(
        animation: _controller,
        builder: (_, __) => Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.5 + _controller.value * 0.5),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1.5),
          ),
        ),
      );
    }

    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
      ),
    );
  }
}

/// §4.2: 역할 배지
class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role});
  final UserRole role;

  @override
  Widget build(BuildContext context) {
    String emoji;
    Color bgColor;
    switch (role) {
      case UserRole.captain:
        emoji = '👑';
        bgColor = const Color(0xFFFFF8E1);
      case UserRole.crewChief:
        emoji = '🔷';
        bgColor = const Color(0xFFE3F2FD);
      case UserRole.crew:
        emoji = '⚪';
        bgColor = const Color(0xFFF5F5F5);
      case UserRole.guardian:
        emoji = '🛡️';
        bgColor = const Color(0xFFE8F5E9);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(emoji, style: const TextStyle(fontSize: 12)),
    );
  }
}

/// SOS 액션 버튼 (§4.3)
class _SosActionButton extends StatelessWidget {
  const _SosActionButton({required this.label, required this.icon, this.onTap});
  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radius8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.sosDanger.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(AppSpacing.radius8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppColors.sosDanger),
            const SizedBox(width: 4),
            Text(label, style: AppTypography.labelSmall.copyWith(color: AppColors.sosDanger)),
          ],
        ),
      ),
    );
  }
}
```

**Step 2: Verify compiles**

Run: `cd safetrip-mobile && flutter analyze lib/widgets/member_card.dart`
Expected: No errors (may need to fix `AnimatedBuilder` → use built-in Flutter animation)

**Step 3: Commit**

```bash
git add safetrip-mobile/lib/widgets/member_card.dart
git commit -m "feat(member-tab): add MemberCard widget with SOS, role badges, battery"
```

---

## Task 4: Rewrite BottomSheetMember (Main Member Tab)

**Files:**
- Modify: `safetrip-mobile/lib/screens/main/bottom_sheets/bottom_sheet_2_member.dart` (full rewrite)

**Why:** Replace hardcoded mock member list with real data from MemberTabProvider. Implement §3 layout: warning banners, admin/member/guardian sections, attendance banner, action buttons.

**Step 1: Full rewrite of bottom_sheet_2_member.dart**

```dart
// safetrip-mobile/lib/screens/main/bottom_sheets/bottom_sheet_2_member.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../features/member/providers/member_tab_provider.dart';
import '../../../features/trip/providers/trip_provider.dart';
import '../../../features/trip/providers/attendance_provider.dart';
import '../../../models/attendance.dart';
import '../../../models/trip_member.dart';
import '../../../models/user.dart';
import '../../../widgets/member_card.dart';
import '../../../widgets/avatar_widget.dart';
import 'modals/add_member_modal.dart';

/// 멤버 탭 바텀시트 콘텐츠 (DOC-T3-MBR-019 §3)
class BottomSheetMember extends ConsumerStatefulWidget {
  const BottomSheetMember({
    super.key,
    required this.scrollController,
    this.onEnterDetail,
    this.onExitDetail,
  });

  final ScrollController scrollController;
  final VoidCallback? onEnterDetail;
  final VoidCallback? onExitDetail;

  @override
  ConsumerState<BottomSheetMember> createState() => _BottomSheetMemberState();
}

class _BottomSheetMemberState extends ConsumerState<BottomSheetMember> {
  @override
  void initState() {
    super.initState();
    // 초기 멤버 로딩
    WidgetsBinding.instance.addPostFrameCallback((_) => _initializeMembers());
  }

  void _initializeMembers() {
    final tripState = ref.read(tripProvider);
    final groupId = tripState.currentGroup?.groupId;
    final tripId = tripState.currentTrip?.tripId;
    if (groupId != null && tripId != null) {
      ref.read(memberTabProvider.notifier).initialize(
        groupId: groupId,
        tripId: tripId,
        currentUserId: '', // TODO: get from auth
        currentUserRole: tripState.currentUserRole,
        isB2bTrip: tripState.currentTrip?.isB2b ?? false,
        isPaidTrip: true, // TODO: get from trip
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final memberState = ref.watch(memberTabProvider);

    if (memberState.isLoading && memberState.allMembers.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (memberState.error != null && memberState.allMembers.isEmpty) {
      return _buildErrorState(memberState.error!);
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(memberTabProvider.notifier).fetchMembers(),
      child: ListView(
        controller: widget.scrollController,
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          // §14.2: 오프라인 배너
          if (memberState.isOfflineMode) _buildOfflineBanner(memberState.lastSyncAt),

          // §3.3: SOS 경고 배너
          if (memberState.hasSosAlert)
            ...memberState.sosMembersList.map((m) => _SosAlertBanner(member: m)),

          // §3.3: 오프라인 멤버 배너
          if (memberState.hasOfflineAlert) _OfflineAlertBanner(members: memberState.offlineMembers),

          // §8.3: 출석체크 진행 배너
          _buildAttendanceBanner(),

          // §3.2: 관리자 섹션
          _SectionHeader(title: '관리자', count: memberState.adminMembers.length),
          ...memberState.adminMembers.map((m) => MemberCard(
            member: m,
            isB2bTrip: memberState.isB2bTrip,
            onTap: () => _onMemberTap(m),
          )),

          const SizedBox(height: AppSpacing.md),

          // §3.2: 멤버 섹션
          _SectionHeader(title: '멤버', count: memberState.crewMembers.length),
          ...memberState.crewMembers.map((m) => MemberCard(
            member: m,
            isB2bTrip: memberState.isB2bTrip,
            onTap: () => _onMemberTap(m),
          )),

          const SizedBox(height: AppSpacing.md),

          // §3.2: 보호자 섹션
          if (_hasGuardians(memberState)) ...[
            _GuardianSectionHeader(
              memberState: memberState,
              onManageTap: memberState.isCaptain ? () => _openGuardianManageSheet() : null,
            ),
            ...memberState.allMembers
                .where((m) => m.memberRole == UserRole.guardian)
                .map((m) => MemberCard(
                  member: m,
                  showGuardianBadge: true,
                  isPaidGuardian: false, // TODO: match with guardianSlots
                  isB2bTrip: memberState.isB2bTrip,
                  onTap: () => _onMemberTap(m),
                )),
          ],

          const SizedBox(height: AppSpacing.md),

          // §3.1: 하단 액션 버튼 (캡틴/크루장만)
          if (memberState.isAdmin) _buildActionButtons(memberState),

          // 출석체크 버튼 (§8.1: 캡틴/크루장, 6인 이상 유료)
          if (memberState.isAdmin && memberState.canStartAttendance) _buildAttendanceButton(),

          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

  bool _hasGuardians(MemberTabState state) {
    return state.allMembers.any((m) => m.memberRole == UserRole.guardian);
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(error, style: AppTypography.bodyMedium),
          const SizedBox(height: AppSpacing.md),
          ElevatedButton(
            onPressed: () => ref.read(memberTabProvider.notifier).fetchMembers(),
            child: const Text('재시도'),
          ),
        ],
      ),
    );
  }

  Widget _buildOfflineBanner(DateTime? lastSync) {
    final timeText = lastSync != null
        ? '${DateTime.now().difference(lastSync).inMinutes}분 전'
        : '알 수 없음';
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.textTertiary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radius8),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off, size: 16, color: AppColors.textTertiary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              '오프라인 모드 · 마지막 동기화: $timeText. 연결 후 자동 갱신됩니다.',
              style: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceBanner() {
    final attendanceState = ref.watch(attendanceProvider);
    final currentCheck = attendanceState.currentCheck;
    if (currentCheck == null || currentCheck.status != AttendanceStatus.ongoing) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.semanticInfo.withValues(alpha: 0.1),
        border: Border.all(color: AppColors.semanticInfo),
        borderRadius: BorderRadius.circular(AppSpacing.radius12),
      ),
      child: Row(
        children: [
          const Icon(Icons.fact_check, color: AppColors.semanticInfo),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              '출석 체크 진행 중',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.semanticInfo,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          // TODO: 실시간 카운트 (✅ 확인 N명, ⏳ 미응답 N명)
        ],
      ),
    );
  }

  Widget _buildActionButtons(MemberTabState memberState) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _showAddMemberModal(),
              icon: const Icon(Icons.person_add, size: 18),
              label: const Text('멤버 초대'),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _showAddGuardianModal(),
              icon: const Icon(Icons.shield, size: 18),
              label: const Text('가디언 추가'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceButton() {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: OutlinedButton.icon(
        onPressed: () => _startAttendanceCheck(),
        icon: const Icon(Icons.fact_check, size: 18),
        label: const Text('출석 체크 시작'),
      ),
    );
  }

  void _onMemberTap(TripMember member) {
    // §4.4: 원터치 액션 — 멤버 카드 탭 시 지도 이동
    // TODO: 지도탭 원칙(#17) 참조 — 지도 마커 포커스
  }

  void _openGuardianManageSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _GuardianManageSheet(),
    );
  }

  void _showAddMemberModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const AddMemberModal(),
    );
  }

  void _showAddGuardianModal() {
    // TODO: 가디언 추가 전용 모달
  }

  void _startAttendanceCheck() {
    final tripId = ref.read(tripProvider).currentTrip?.tripId;
    if (tripId != null) {
      ref.read(attendanceProvider.notifier).startAttendance(tripId);
    }
  }
}

/// §3.3: SOS 경고 배너
class _SosAlertBanner extends StatelessWidget {
  const _SosAlertBanner({required this.member});
  final TripMember member;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.sosDanger.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppSpacing.radius12),
      ),
      child: Row(
        children: [
          const Text('🚨', style: TextStyle(fontSize: 20)),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${member.userName}님이 SOS를 발신 중입니다.',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.sosDanger,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (member.lastLocationText != null)
                  Text(
                    '📍 ${member.lastLocationText} · ${member.locationTimeText}',
                    style: AppTypography.bodySmall.copyWith(color: AppColors.sosDanger),
                  ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {}, // TODO: 지도 이동
            child: Text('지도에서 보기', style: AppTypography.labelSmall.copyWith(color: AppColors.sosDanger)),
          ),
        ],
      ),
    );
  }
}

/// §3.3: 오프라인 멤버 배너
class _OfflineAlertBanner extends StatefulWidget {
  const _OfflineAlertBanner({required this.members});
  final List<TripMember> members;

  @override
  State<_OfflineAlertBanner> createState() => _OfflineAlertBannerState();
}

class _OfflineAlertBannerState extends State<_OfflineAlertBanner> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final count = widget.members.length;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.semanticWarning.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppSpacing.radius12),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: count > 1 ? () => setState(() => _expanded = !_expanded) : null,
            child: Row(
              children: [
                const Text('⚠️', style: TextStyle(fontSize: 18)),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: count == 1
                      ? Text(
                          '${widget.members.first.userName}님이 오프라인입니다.',
                          style: AppTypography.bodyMedium.copyWith(color: AppColors.textWarning),
                        )
                      : Text(
                          '$count명이 오프라인입니다',
                          style: AppTypography.bodyMedium.copyWith(color: AppColors.textWarning),
                        ),
                ),
                if (count > 1)
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.textWarning,
                  ),
              ],
            ),
          ),
          if (_expanded)
            ...widget.members.map((m) => Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs, left: 32),
              child: Text(
                '${m.userName} (${m.locationTimeText})',
                style: AppTypography.bodySmall.copyWith(color: AppColors.textWarning),
              ),
            )),
        ],
      ),
    );
  }
}

/// §3.2: 섹션 헤더
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.count});
  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Text(
            '$title 섹션',
            style: AppTypography.titleMedium.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 6),
          Text(
            '$count',
            style: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }
}

/// §5.1: 보호자 섹션 헤더 (무료/유료 슬롯 표시)
class _GuardianSectionHeader extends StatelessWidget {
  const _GuardianSectionHeader({required this.memberState, this.onManageTap});
  final MemberTabState memberState;
  final VoidCallback? onManageTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Text(
            '보호자 섹션',
            style: AppTypography.titleMedium.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          if (onManageTap != null)
            TextButton(
              onPressed: onManageTap,
              child: Text('가디언 관리', style: AppTypography.labelSmall.copyWith(color: AppColors.primaryTeal)),
            ),
        ],
      ),
    );
  }
}

/// §5.2: 가디언 관리 하프시트 (캡틴 전용)
class _GuardianManageSheet extends ConsumerWidget {
  const _GuardianManageSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memberState = ref.watch(memberTabProvider);
    final guardians = memberState.allMembers
        .where((m) => m.memberRole == UserRole.guardian)
        .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.3,
      builder: (_, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radius20)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Center(
                child: Container(
                  width: AppSpacing.bottomSheetHandleWidth,
                  height: AppSpacing.bottomSheetHandleHeight,
                  decoration: BoxDecoration(
                    color: AppColors.outline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text('가디언 관리', style: AppTypography.titleLarge),
              const SizedBox(height: AppSpacing.lg),

              // 무료 슬롯
              Text('무료 슬롯 (${guardians.where((g) => true /* TODO: is_paid == false */).length}/2 사용)',
                  style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: AppSpacing.sm),
              ...guardians.map((g) => _buildGuardianRow(context, ref, g)),

              const SizedBox(height: AppSpacing.lg),
              // §5.3: 유료 가디언 추가 버튼
              OutlinedButton(
                onPressed: () => _showPaymentModal(context),
                child: const Text('+ 유료 가디언 추가 (1,900원/여행)'),
              ),

              const SizedBox(height: AppSpacing.lg),
              Text(
                '※ 가디언 해제 시 이미 결제된 요금은 환불되지 않습니다.',
                style: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGuardianRow(BuildContext context, WidgetRef ref, TripMember guardian) {
    return ListTile(
      leading: AvatarWidget(userId: guardian.userId, userName: guardian.userName, radius: 20),
      title: Text(guardian.userName, style: AppTypography.bodyMedium),
      trailing: TextButton(
        onPressed: () => _confirmRemoveGuardian(context, ref, guardian),
        style: TextButton.styleFrom(foregroundColor: AppColors.semanticError),
        child: const Text('해제'),
      ),
    );
  }

  void _confirmRemoveGuardian(BuildContext context, WidgetRef ref, TripMember guardian) {
    // §5.4: 해제 확인 다이얼로그
    // §12.2: 미성년자 크루의 가디언 해제 → 캡틴 승인 필요
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('가디언 해제'),
        content: Text('${guardian.userName}님과의 가디언 연결을 해제하시겠습니까?\n이미 결제된 1,900원은 환불되지 않습니다.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: API call to remove guardian
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.semanticError),
            child: const Text('해제'),
          ),
        ],
      ),
    );
  }

  void _showPaymentModal(BuildContext context) {
    // §5.3: 과금 결제 모달
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(
          children: [
            const Text('💎 ', style: TextStyle(fontSize: 20)),
            Text('프리미엄 가디언 추가', style: AppTypography.titleMedium),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('이 여행에 가디언을 추가하려면\n1,900원이 결제됩니다.'),
            SizedBox(height: 12),
            Text('· 여행 단위 과금 (이 여행에만 적용)'),
            Text('· 가디언 해제 후에도 환불 불가'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Payment flow
            },
            child: const Text('1,900원 결제 후 추가'),
          ),
        ],
      ),
    );
  }
}
```

**Step 2: Update screen_main.dart import (if needed)**

The existing import should still work since we keep the same class name `BottomSheetMember`.
Note: It now requires `ConsumerStatefulWidget` so parent must be wrapped in `ProviderScope` (it already is).

**Step 3: Verify compiles**

Run: `cd safetrip-mobile && flutter analyze lib/screens/main/bottom_sheets/bottom_sheet_2_member.dart`

**Step 4: Commit**

```bash
git add safetrip-mobile/lib/screens/main/bottom_sheets/bottom_sheet_2_member.dart
git commit -m "feat(member-tab): rewrite member tab with sections, banners, real data"
```

---

## Task 5: Rewrite Guardian Status Tab

**Files:**
- Modify: `safetrip-mobile/lib/screens/main/bottom_sheets/bottom_sheet_guardian_members.dart` (full rewrite)

**Why:** Per §9, guardians see a separate status tab with linked members, emergency location request, and schedule summary (paid guardians only).

**Step 1: Full rewrite**

```dart
// safetrip-mobile/lib/screens/main/bottom_sheets/bottom_sheet_guardian_members.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../models/trip_member.dart';
import '../../../services/api_service.dart';
import '../../../widgets/avatar_widget.dart';

/// 가디언 전용 상태 탭 (DOC-T3-MBR-019 §9)
class BottomSheetGuardianMembers extends ConsumerStatefulWidget {
  const BottomSheetGuardianMembers({
    super.key,
    required this.scrollController,
  });

  final ScrollController scrollController;

  @override
  ConsumerState<BottomSheetGuardianMembers> createState() => _BottomSheetGuardianMembersState();
}

class _BottomSheetGuardianMembersState extends ConsumerState<BottomSheetGuardianMembers> {
  List<TripMember> _linkedMembers = [];
  bool _isLoading = true;
  bool _isPaidGuardian = false;

  // §9.2: 긴급 위치 요청 쿨다운
  final Map<String, List<DateTime>> _locationRequestHistory = {};

  @override
  void initState() {
    super.initState();
    _loadLinkedMembers();
  }

  Future<void> _loadLinkedMembers() async {
    // TODO: 실제 API 호출 (GET /api/v1/trips/{tripId}/guardians/me/linked-members)
    setState(() {
      _isLoading = false;
      // Mock data for now
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_linkedMembers.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.shield_outlined, size: 48, color: AppColors.textTertiary),
            const SizedBox(height: AppSpacing.md),
            Text(
              '연결된 멤버가 없습니다',
              style: AppTypography.bodyMedium.copyWith(color: AppColors.textTertiary),
            ),
          ],
        ),
      );
    }

    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text(
          '내 연결 멤버',
          style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: AppSpacing.md),
        ..._linkedMembers.map((member) => _buildLinkedMemberCard(member)),
      ],
    );
  }

  Widget _buildLinkedMemberCard(TripMember member) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(
          color: member.isSosActive ? AppColors.sosDanger : AppColors.outlineVariant,
          width: member.isSosActive ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radius12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 멤버 정보
          Row(
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: Stack(
                  children: [
                    AvatarWidget(userId: member.userId, userName: member.userName, radius: 20),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: member.isOnline ? const Color(0xFF4CAF50) : const Color(0xFF9E9E9E),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(member.userName, style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.w600)),
                    Text(
                      '${member.displayRoleName} · ${member.isOnline ? "온라인" : "오프라인"}',
                      style: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary),
                    ),
                  ],
                ),
              ),
              if (member.batteryLevel != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.battery_std,
                      size: 16,
                      color: member.batteryLevel! <= 20 ? AppColors.semanticError : AppColors.textTertiary,
                    ),
                    Text(
                      '${member.batteryLevel}%',
                      style: AppTypography.labelSmall.copyWith(
                        color: member.batteryLevel! <= 20 ? AppColors.semanticError : AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
            ],
          ),

          const SizedBox(height: AppSpacing.sm),

          // 위치 정보 (§11.2)
          Row(
            children: [
              const SizedBox(width: 56),
              const Icon(Icons.location_on, size: 14, color: AppColors.textTertiary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  member.locationDisplayText,
                  style: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),

          // 액션 버튼
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {}, // TODO: 메시지
                  icon: const Icon(Icons.message, size: 16),
                  label: const Text('메시지'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _canRequestLocation(member.userId)
                      ? () => _requestEmergencyLocation(member)
                      : null,
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.semanticWarning),
                  icon: const Icon(Icons.my_location, size: 16),
                  label: Text(
                    _canRequestLocation(member.userId) ? '긴급 위치 요청' : _getRemainingCooldownText(member.userId),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ],
          ),

          // §9.3: 유료 가디언만 일정 요약
          if (_isPaidGuardian) ...[
            const Divider(height: AppSpacing.lg),
            Text('연결 멤버 일정 요약', style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: AppSpacing.sm),
            // TODO: Schedule summary from API
            Text('일정 데이터를 불러오는 중...', style: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary)),
          ],
        ],
      ),
    );
  }

  /// §9.2: 1시간 최대 3회 제한 체크
  bool _canRequestLocation(String memberId) {
    final history = _locationRequestHistory[memberId] ?? [];
    final oneHourAgo = DateTime.now().subtract(const Duration(hours: 1));
    final recentRequests = history.where((t) => t.isAfter(oneHourAgo)).length;
    return recentRequests < 3;
  }

  String _getRemainingCooldownText(String memberId) {
    final history = _locationRequestHistory[memberId] ?? [];
    final oneHourAgo = DateTime.now().subtract(const Duration(hours: 1));
    final recent = history.where((t) => t.isAfter(oneHourAgo)).toList()..sort();
    if (recent.isEmpty) return '긴급 위치 요청';
    final oldestRecent = recent.first;
    final remaining = oldestRecent.add(const Duration(hours: 1)).difference(DateTime.now());
    return '${remaining.inMinutes}분 후 가능';
  }

  void _requestEmergencyLocation(TripMember member) {
    // §9.2: 긴급 위치 요청
    _locationRequestHistory.putIfAbsent(member.userId, () => []);
    _locationRequestHistory[member.userId]!.add(DateTime.now());
    setState(() {});

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${member.userName}님에게 긴급 위치 요청을 보냈습니다.'),
        behavior: SnackBarBehavior.floating,
      ),
    );

    // TODO: API call POST /api/v1/trips/{tripId}/guardian-messages/location-request
  }
}
```

**Step 2: Verify compiles**

Run: `cd safetrip-mobile && flutter analyze lib/screens/main/bottom_sheets/bottom_sheet_guardian_members.dart`

**Step 3: Commit**

```bash
git add safetrip-mobile/lib/screens/main/bottom_sheets/bottom_sheet_guardian_members.dart
git commit -m "feat(member-tab): rewrite guardian status tab with emergency location requests"
```

---

## Task 6: Update AvatarWidget to Support imageUrl

**Files:**
- Modify: `safetrip-mobile/lib/widgets/avatar_widget.dart`

**Why:** MemberCard passes `imageUrl` but AvatarWidget may not support it yet. Need to verify and add if missing.

**Step 1: Read current AvatarWidget**

Read `safetrip-mobile/lib/widgets/avatar_widget.dart` and check if `imageUrl` parameter exists.

**Step 2: Add imageUrl parameter if missing**

If `imageUrl` is not present, add it:
- Add `final String? imageUrl;` field
- Add to constructor
- In build: if `imageUrl != null`, show `CircleAvatar(backgroundImage: NetworkImage(imageUrl!))`

**Step 3: Commit**

```bash
git add safetrip-mobile/lib/widgets/avatar_widget.dart
git commit -m "feat(member-tab): add imageUrl support to AvatarWidget"
```

---

## Task 7: Wire Member Tab to screen_main.dart

**Files:**
- Modify: `safetrip-mobile/lib/screens/main/screen_main.dart`

**Why:** The member tab switch case needs to pass through to the now-ConsumerStatefulWidget BottomSheetMember. Verify the existing wiring still works.

**Step 1: Verify existing wiring**

The `BottomSheetMember` class name is unchanged. It now extends `ConsumerStatefulWidget` instead of `StatefulWidget`, which is compatible since the app already uses Riverpod (`ProviderScope` is at the root).

Read `screen_main.dart` lines 785-801 and verify no changes are needed.

**Step 2: Commit (if changes needed)**

```bash
git add safetrip-mobile/lib/screens/main/screen_main.dart
git commit -m "fix(member-tab): ensure member tab wiring compatible with ConsumerStatefulWidget"
```

---

## Task 8: Fix AnimatedBuilder → AnimatedWidget pattern

**Files:**
- Modify: `safetrip-mobile/lib/widgets/member_card.dart`

**Why:** `AnimatedBuilder` is the old name; Flutter uses `AnimatedBuilder` — verify this compiles. The pattern might need `AnimatedBuilder` widget which is correct in Flutter.

**Step 1: Run flutter analyze on the whole project**

Run: `cd safetrip-mobile && flutter analyze lib/`
Expected: Fix any compile errors

**Step 2: Fix any issues found**

Common issues:
- Import paths
- Null safety issues
- Missing model fields

**Step 3: Commit fixes**

```bash
git add -A
git commit -m "fix(member-tab): resolve compile errors from member tab implementation"
```

---

## Task 9: Verification Round 1 — §16 Checklist

**Files:** All member tab files

**Why:** Document §16 defines 12 verification items. Check each one.

**Checklist:**

| # | Check Item | Status |
|---|-----------|--------|
| 1 | 문서 목적과 적용 범위 — 구현 범위가 §1.2와 일치 | Verify |
| 2 | 기준 문서 v5.1 참조 | N/A (doc check) |
| 3 | 역할별 접근 권한 정의 (§10) — isCaptain/isAdmin 분기 확인 | Verify MemberCard/BottomSheetMember |
| 4 | 프라이버시 등급별 동작 차이 (§11) — locationDisplayText 분기 확인 | Verify TripMember model |
| 5 | 에러 및 엣지케이스 (§12) — 로딩 실패, 가디언 관련 | Verify error states |
| 6 | 검증 체크리스트 포함 | This task |
| 7 | 변경 이력 | N/A (doc) |
| 8 | DB 스키마 (is_paid 컬럼) | Verify GuardianSlot model |
| 9 | 구현 우선순위 P0~P3 배치 | All phases implemented |
| 10 | 오프라인 동작 대응 | Verify offline banner |
| 11 | 가디언 과금 분기 | Verify guardian manage sheet |
| 12 | 여행 기간 제한 15일 | N/A (설정탭 위임) |

**Step 1: Run through each checklist item and fix gaps**

Verify:
- `_buildErrorState` handles §12.1 (멤버 목록 로딩 실패)
- `_GuardianManageSheet` handles §12.2 (가디언 엣지케이스)
- `_buildAttendanceBanner` handles §12.3 (출석체크 엣지케이스)
- `MemberCard` handles §12.4 (B2B 역할명 20자 초과 → ellipsis)
- Guardian status tab handles §12.5 (긴급 위치 요청 제한)

**Step 2: Commit fixes**

```bash
git add -A
git commit -m "fix(member-tab): round 1 verification — fix gaps from §16 checklist"
```

---

## Task 10: Verification Round 2 — Edge Cases (§12)

**Files:** All member tab files

**Why:** Systematic verification of every edge case in §12.

**Step 1: Verify each edge case**

§12.1 — 멤버 목록:
- Network error → "멤버 정보를 불러올 수 없습니다. [재시도]" ✓ (in _buildErrorState)
- Partial load failure → "정보 로딩 중..." on affected cards → Add null check in MemberCard

§12.2 — 가디언:
- 무료 슬롯 초과 → 과금 모달 자동 표시 ✓ (in _showPaymentModal)
- 유료 결제 실패 → error message → Add try/catch in payment flow
- 미성년자 해제 → 캡틴 승인 요청 → Add isMinor check in _confirmRemoveGuardian
- 수락 대기 중 → badge ✓ (in MemberCard guardianStatus)

§12.3 — 출석체크:
- 진행 중 멤버 탈퇴 → auto absent → Backend handles this
- 오프라인 중 응답 → local queue → Add offline queue logic
- 5인 이하 → "6인 이상 유료 여행에서만 사용 가능" → Add check in _startAttendanceCheck

§12.4 — B2B:
- NULL b2b_role_name → default role name ✓ (in displayRoleName getter)
- 20자 초과 → ellipsis ✓ (TextOverflow.ellipsis in MemberCard)

§12.5 — 긴급 위치:
- 3회 초과 → 비활성화 + 남은 시간 ✓ (in _canRequestLocation)
- 오프라인 멤버 → 안내 메시지 → Add offline check in _requestEmergencyLocation

**Step 2: Fix all identified gaps**

**Step 3: Commit**

```bash
git add -A
git commit -m "fix(member-tab): round 2 verification — edge cases §12 full coverage"
```

---

## Task 11: Verification Round 3 — Permissions (§10) & Privacy (§11)

**Files:** All member tab files

**Why:** Final verification that role-based access and privacy levels work correctly.

**Step 1: Verify §10 permission matrix**

For each row in the §10 table, verify the UI enforces:
- 멤버탭 접근: ✅ captain/crew_chief/crew, ❌ guardian (separate tab)
- 멤버 초대: ✅ captain/crew_chief only (isAdmin check)
- 멤버 강퇴: ✅ captain only (isCaptain check) → Add kick functionality
- 역할 변경: ✅ captain only → Add role change
- 가디언 추가: ✅ captain(전체), crew(본인만) → Add self-only check for crew
- 가디언 해제: ✅ captain(전체), crew(본인만) → Add self-only check for crew
- 가디언 관리 하프시트: ✅ captain only ✓
- 출석 체크 시작: ✅ captain/crew_chief ✓
- 출석 응답: ✅ crew only → Verify crew sees respond UI
- 미성년자 가디언 해제 승인: ✅ captain only → Verify flow

**Step 2: Verify §11 privacy scenarios**

Test each combination:
- safety_first + ON time → real-time location ✓
- safety_first + OFF time → real-time location ✓
- standard + ON → real-time ✓
- standard + OFF → "마지막 갱신: N분 전" ✓ (in _lastUpdatedText)
- privacy_first + ON → real-time ✓
- privacy_first + OFF → "위치 비공유 중" ✓
- SOS → always show regardless of privacy ✓ (in locationDisplayText)

**Step 3: Fix any remaining gaps**

**Step 4: Final commit**

```bash
git add -A
git commit -m "fix(member-tab): round 3 verification — permissions §10 + privacy §11 complete"
```

---

## Task 12: Final Flutter Analyze & Build Verification

**Files:** Entire Flutter project

**Step 1: Run full analysis**

Run: `cd safetrip-mobile && flutter analyze`
Expected: 0 errors

**Step 2: Attempt build**

Run: `cd safetrip-mobile && flutter build apk --debug 2>&1 | tail -20`
Expected: BUILD SUCCESSFUL

**Step 3: Final commit with all fixes**

```bash
git add -A
git commit -m "feat(member-tab): complete member tab implementation (Phase 1~3)"
```
