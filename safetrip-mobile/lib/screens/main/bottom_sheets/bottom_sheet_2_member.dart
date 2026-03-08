import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../features/member/providers/member_tab_provider.dart';
import '../../../features/trip/providers/trip_provider.dart';
import '../../../features/trip/providers/attendance_provider.dart';
import '../../../models/attendance.dart';
import '../../../models/trip_member.dart';
import '../../../models/user.dart';
import '../../../features/demo/providers/demo_state_provider.dart';
import '../../../services/api_service.dart';
import '../../../widgets/member_card.dart';
import '../../../widgets/avatar_widget.dart';
import 'modals/add_member_modal.dart';

// =============================================================================
// BottomSheetMember — DOC-T3-MBR-019 SS3
// =============================================================================

/// 멤버 탭 바텀시트 콘텐츠 (DOC-T3-MBR-019 SS3)
///
/// 부모 [SnappingBottomSheet]로부터 [ScrollController]를 수신.
/// Riverpod [memberTabProvider]를 구독하여 멤버 목록, SOS/오프라인 알림,
/// 출석 체크 배너, 가디언 관리 기능을 제공한다.
class BottomSheetMember extends ConsumerStatefulWidget {
  const BottomSheetMember({
    super.key,
    required this.scrollController,
    this.onEnterDetail,
    this.onExitDetail,
  });

  final ScrollController scrollController;

  /// SS7.4: 세부 화면 진입 시 호출 (바텀시트 -> full)
  final VoidCallback? onEnterDetail;

  /// SS7.4: 세부 화면 종료 시 호출 (바텀시트 -> 이전 레벨 복원)
  final VoidCallback? onExitDetail;

  @override
  ConsumerState<BottomSheetMember> createState() => _BottomSheetMemberState();
}

class _BottomSheetMemberState extends ConsumerState<BottomSheetMember> {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeMembers();
    });
  }

  // ---------------------------------------------------------------------------
  // Initialization
  // ---------------------------------------------------------------------------

  Future<void> _initializeMembers() async {
    if (_initialized) return;

    // 데모 모드에서는 API 서버가 없으므로 멤버 API 호출 skip
    if (ref.read(isDemoModeProvider)) {
      _initialized = true;
      return;
    }

    final tripState = ref.read(tripProvider);

    // SharedPreferences에서 userId, role, groupId, tripId 읽기
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    final userRoleStr = prefs.getString('user_role') ?? 'crew';
    final userRole = UserRoleExtension.fromMemberRole(userRoleStr);

    // tripProvider.currentGroup이 설정되어 있으면 사용, 아니면 SharedPreferences에서 읽기
    final groupId =
        tripState.currentGroup?.groupId ?? prefs.getString('group_id');
    final tripId =
        tripState.currentTrip?.tripId ?? prefs.getString('trip_id');

    if (groupId == null || groupId.isEmpty) {
      debugPrint('[BottomSheetMember] groupId is null, skipping initialize');
      return;
    }

    // B2B, 유료 여행 여부 판단
    final isB2b = tripState.currentTrip?.isB2b ?? false;
    final isPaid = tripState.totalMemberCount >= 6; // 유료 기준: 6인 이상

    await ref.read(memberTabProvider.notifier).initialize(
          groupId: groupId,
          tripId: tripId ?? groupId,
          currentUserId: userId ?? '',
          currentUserRole: userRole,
          isB2bTrip: isB2b,
          isPaidTrip: isPaid,
        );

    // 출석 상태 조회
    if (tripId != null && tripId.isNotEmpty) {
      ref.read(attendanceProvider.notifier).fetchAttendances(tripId);
    }

    _initialized = true;
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final memberState = ref.watch(memberTabProvider);
    final attendState = ref.watch(attendanceProvider);

    // --- Loading --- scrollController 반드시 연결 (DraggableScrollableSheet 드래그 동작 필수)
    if (memberState.isLoading && memberState.allMembers.isEmpty) {
      return ListView(
        controller: widget.scrollController,
        children: const [
          SizedBox(height: 120),
          Center(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.xxl),
              child: CircularProgressIndicator(color: AppColors.primaryTeal),
            ),
          ),
        ],
      );
    }

    // --- Error ---
    if (memberState.error != null && memberState.allMembers.isEmpty) {
      return ListView(
        controller: widget.scrollController,
        children: [
          const SizedBox(height: 80),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: AppColors.semanticError),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    memberState.error ?? '멤버 정보를 불러올 수 없습니다.',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  OutlinedButton.icon(
                    onPressed: () {
                      ref.read(memberTabProvider.notifier).fetchMembers();
                    },
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('재시도'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryTeal,
                      side: const BorderSide(color: AppColors.primaryTeal),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppSpacing.radius8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    // --- Content ---
    return RefreshIndicator(
      color: AppColors.primaryTeal,
      onRefresh: () async {
        await ref.read(memberTabProvider.notifier).fetchMembers();
      },
      child: ListView(
        controller: widget.scrollController,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenPaddingH,
          vertical: AppSpacing.md,
        ),
        children: [
          // (1) 오프라인 모드 배너 (SS14.2)
          if (memberState.isOfflineMode) _buildOfflineModeBanner(),

          // (2) SOS 경고 배너 (SS3.3)
          if (memberState.hasSosAlert)
            ...memberState.sosMembersList.map(
              (m) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _SosAlertBanner(member: m),
              ),
            ),

          // (3) 오프라인 멤버 배너 (SS3.3)
          if (memberState.hasOfflineAlert)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _OfflineAlertBanner(
                offlineMembers: memberState.offlineMembers,
              ),
            ),

          // (4) 출석 체크 진행 배너 (SS8.3)
          if (attendState.currentCheck?.status == AttendanceStatus.ongoing)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: _AttendanceBanner(
                check: attendState.currentCheck!,
                totalMembers: memberState.totalMemberCount,
                presentCount: attendState.presentCount,
                absentCount: attendState.absentCount,
                unknownCount: attendState.unknownCount,
              ),
            ),

          // (5) 관리자 섹션
          if (memberState.adminMembers.isNotEmpty) ...[
            _SectionHeader(
              title: '관리자',
              count: memberState.adminMembers.length,
            ),
            const SizedBox(height: AppSpacing.sm),
            ...memberState.adminMembers.map(
              (m) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.cardGap),
                child: MemberCard(
                  member: m,
                  isB2bTrip: memberState.isB2bTrip,
                  onTap: () => _onMemberTap(m),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],

          // (6) 멤버 섹션
          if (memberState.crewMembers.isNotEmpty) ...[
            _SectionHeader(
              title: '멤버',
              count: memberState.crewMembers.length,
            ),
            const SizedBox(height: AppSpacing.sm),
            ...memberState.crewMembers.map(
              (m) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.cardGap),
                child: MemberCard(
                  member: m,
                  isB2bTrip: memberState.isB2bTrip,
                  onTap: () => _onMemberTap(m),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],

          // (7) 보호자 섹션 (가디언 슬롯이 있을 때만)
          if (memberState.guardianSlots.isNotEmpty) ...[
            _GuardianSectionHeader(
              guardianCount: memberState.guardianSlots.length,
              isCaptain: memberState.isCaptain,
              onManageTap: () => _showGuardianManageSheet(context),
              freeCount: memberState.guardianSlots.where((s) => !s.isPaid && s.status == 'accepted').length,
              paidCount: memberState.guardianSlots.where((s) => s.isPaid && s.status == 'accepted').length,
            ),
            const SizedBox(height: AppSpacing.sm),
            ...memberState.guardianSlots.map(
              (slot) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.cardGap),
                child: _GuardianSlotCard(slot: slot),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],

          // (8) 관리자 액션 버튼 영역
          if (memberState.isAdmin) ...[
            const SizedBox(height: AppSpacing.sm),
            _buildAdminActions(context, memberState),
          ],

          // 하단 여백 (바텀 네비게이션 가림 방지)
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Offline Mode Banner (SS14.2)
  // ---------------------------------------------------------------------------

  Widget _buildOfflineModeBanner() {
    final memberState = ref.read(memberTabProvider);
    final lastSync = memberState.lastSyncAt;

    // 마지막 동기화 시간 텍스트 계산
    String syncText = '알 수 없음';
    if (lastSync != null) {
      final diff = DateTime.now().difference(lastSync);
      if (diff.inMinutes < 1) {
        syncText = '방금';
      } else if (diff.inMinutes < 60) {
        syncText = '${diff.inMinutes}분 전';
      } else if (diff.inHours < 24) {
        syncText = '${diff.inHours}시간 전';
      } else {
        syncText = '${diff.inDays}일 전';
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.semanticWarning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radius8),
        border: Border.all(
          color: AppColors.semanticWarning.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off, size: 18, color: AppColors.semanticWarning),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              '[오프라인 모드] 마지막 동기화: $syncText. 연결 후 자동 갱신됩니다.',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textWarning,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Admin Actions (SS3 하단)
  // ---------------------------------------------------------------------------

  Widget _buildAdminActions(BuildContext context, MemberTabState state) {
    return Column(
      children: [
        // 멤버 초대 + 가디언 추가 버튼 행
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _showAddMemberModal(context, state),
                icon: const Icon(Icons.person_add_alt_1, size: 18),
                label: const Text('멤버 초대'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryTeal,
                  side: const BorderSide(color: AppColors.primaryTeal),
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radius8),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _showGuardianManageSheet(context),
                icon: const Text('\u{1F6E1}', style: TextStyle(fontSize: 16)),
                label: const Text('가디언 추가'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.guardian,
                  side: const BorderSide(color: AppColors.guardian),
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radius8),
                  ),
                ),
              ),
            ),
          ],
        ),

        // 출석 체크 시작 버튼 (관리자 + canStartAttendance)
        if (state.isAdmin) ...[
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _onStartAttendance(context, state),
              icon: const Icon(Icons.fact_check_outlined, size: 18),
              label: const Text('출석 체크 시작'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.semanticInfo,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radius8),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Callbacks
  // ---------------------------------------------------------------------------

  void _onMemberTap(TripMember member) {
    // §7.4: 세부 화면 진입 → full 전환
    widget.onEnterDetail?.call();

    // 멤버 프로필 모달 표시
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MemberDetailSheet(member: member),
    ).then((_) {
      // §7.4: 세부 화면 종료 → 이전 레벨 복원
      widget.onExitDetail?.call();
    });
  }

  void _showAddMemberModal(BuildContext context, MemberTabState state) {
    final groupId = state.groupId;
    if (groupId == null || groupId.isEmpty) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddMemberModal(groupId: groupId, tripId: state.tripId ?? ''),
    ).then((result) {
      if (result == true) {
        // 멤버 추가 후 목록 새로고침
        ref.read(memberTabProvider.notifier).fetchMembers();
      }
    });
  }

  void _onStartAttendance(BuildContext context, MemberTabState state) {
    // SS12: 5인 이하 출석체크 시도 차단
    if (!state.canStartAttendance) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('6인 이상 유료 여행에서만 사용 가능합니다.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final tripId = state.tripId;
    if (tripId == null || tripId.isEmpty) return;

    ref.read(attendanceProvider.notifier).startAttendance(tripId);
  }

  void _showGuardianManageSheet(BuildContext context) {
    final state = ref.read(memberTabProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        // 현재 사용자의 미성년자 여부 확인 (§10.2)
        final currentMember = state.allMembers
            .where((m) => m.userId == state.currentUserId)
            .firstOrNull;
        final isCurrentUserMinor = currentMember?.isMinor ?? false;

        return _GuardianManageSheet(
          guardianSlots: state.guardianSlots,
          isCaptain: state.isCaptain,
          isMinor: isCurrentUserMinor,
          tripId: state.tripId ?? '',
          onRefresh: () {
            ref.read(memberTabProvider.notifier).fetchMembers();
          },
        );
      },
    );
  }
}

// =============================================================================
// _SosAlertBanner (SS3.3) — Red SOS banner per member
// =============================================================================

class _SosAlertBanner extends StatelessWidget {
  const _SosAlertBanner({required this.member});

  final TripMember member;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.sosDanger.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radius12),
        border: Border.all(color: AppColors.sosDanger, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '\u{1F6A8}',
                style: TextStyle(fontSize: 18),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: member.userName,
                        style: AppTypography.bodyLarge.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.sosDanger,
                        ),
                      ),
                      TextSpan(
                        text: ' SOS\uB97C \uBC1C\uC2E0 \uC911',
                        style: AppTypography.bodyLarge.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.sosDanger,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (member.lastLocationText != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Icon(
                  Icons.location_on,
                  size: 14,
                  color: AppColors.sosDanger.withValues(alpha: 0.7),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    member.lastLocationText!,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.sosDanger.withValues(alpha: 0.8),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                // TODO: 지도에서 SOS 멤버 위치로 이동
              },
              icon: const Icon(Icons.map_outlined, size: 16),
              label: const Text('지도에서 보기'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.sosDanger,
                side: const BorderSide(color: AppColors.sosDanger),
                padding: const EdgeInsets.symmetric(vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radius8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// _OfflineAlertBanner (SS3.3) — Orange offline members banner
// =============================================================================

class _OfflineAlertBanner extends StatefulWidget {
  const _OfflineAlertBanner({required this.offlineMembers});

  final List<TripMember> offlineMembers;

  @override
  State<_OfflineAlertBanner> createState() => _OfflineAlertBannerState();
}

class _OfflineAlertBannerState extends State<_OfflineAlertBanner> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final count = widget.offlineMembers.length;
    if (count == 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.secondaryAmber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radius12),
        border: Border.all(
          color: AppColors.secondaryAmber.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: count >= 2 ? () => setState(() => _isExpanded = !_isExpanded) : null,
            child: Row(
              children: [
                const Text(
                  '\u{26A0}\u{FE0F}',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    count == 1
                        ? '${widget.offlineMembers.first.userName}\uB2D8\uC774 \uC624\uD504\uB77C\uC778 \uC0C1\uD0DC\uC785\uB2C8\uB2E4'
                        : '$count\uBA85\uC758 \uBA64\uBC84\uAC00 \uC624\uD504\uB77C\uC778 \uC0C1\uD0DC\uC785\uB2C8\uB2E4',
                    style: AppTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textWarning,
                    ),
                  ),
                ),
                if (count >= 2)
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                    color: AppColors.textWarning,
                  ),
              ],
            ),
          ),
          // 2명 이상일 때 확장 가능한 목록
          if (_isExpanded && count >= 2) ...[
            const SizedBox(height: AppSpacing.sm),
            ...widget.offlineMembers.map(
              (m) => Padding(
                padding: const EdgeInsets.only(
                  left: AppSpacing.lg,
                  bottom: AppSpacing.xs,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.textTertiary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      m.userName,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (m.locationTimeText != null) ...[
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        '(\uB9C8\uC9C0\uB9C9 ${m.locationTimeText})',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// =============================================================================
// _AttendanceBanner (SS8.3) — Teal attendance in-progress banner
// =============================================================================

class _AttendanceBanner extends ConsumerStatefulWidget {
  const _AttendanceBanner({
    required this.check,
    required this.totalMembers,
    required this.presentCount,
    required this.absentCount,
    required this.unknownCount,
  });

  final AttendanceCheck check;
  final int totalMembers;
  final int presentCount;
  final int absentCount;
  final int unknownCount;

  @override
  ConsumerState<_AttendanceBanner> createState() => _AttendanceBannerState();
}

class _AttendanceBannerState extends ConsumerState<_AttendanceBanner> {
  Timer? _timer;
  Timer? _responseTimer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _calculateRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _calculateRemaining();
    });

    // 출석 응답 실시간 폴링 (5초 간격)
    _fetchResponsesNow();
    _responseTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _fetchResponsesNow();
    });
  }

  void _fetchResponsesNow() {
    if (!mounted) return;
    final aState = ref.read(attendanceProvider);
    if (aState.currentCheck != null) {
      ref.read(attendanceProvider.notifier).fetchResponses(
            aState.currentCheck!.tripId,
            aState.currentCheck!.id,
          );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _responseTimer?.cancel();
    super.dispose();
  }

  void _calculateRemaining() {
    // 출석 체크 시작 후 10분(600초) 제한 기준
    const attendanceDuration = Duration(minutes: 10);
    final elapsed = DateTime.now().difference(widget.check.createdAt);
    final remaining = attendanceDuration - elapsed;

    if (mounted) {
      setState(() {
        _remaining = remaining.isNegative ? Duration.zero : remaining;
      });
    }
  }

  String get _timeText {
    final minutes = _remaining.inMinutes;
    final seconds = _remaining.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  /// 미응답 수 = 전체 멤버 - 확인 - 부재
  int get _pendingCount {
    final responded = widget.presentCount + widget.absentCount;
    final pending = widget.totalMembers - responded;
    return pending < 0 ? 0 : pending;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.semanticInfo.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radius12),
        border: Border.all(
          color: AppColors.semanticInfo.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('\u2705', style: TextStyle(fontSize: 16)),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  '\uCD9C\uC11D \uCCB4\uD06C \uC9C4\uD589 \uC911',
                  style: AppTypography.bodyLarge.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.semanticInfo,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: AppColors.semanticInfo.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppSpacing.radius4),
                ),
                child: Text(
                  '\uB0A8\uC740 \uC2DC\uAC04: $_timeText',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.semanticInfo,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              _AttendanceStat(
                emoji: '\u2705',
                label: '\uD655\uC778',
                count: widget.presentCount,
                color: AppColors.semanticSuccess,
              ),
              const SizedBox(width: AppSpacing.md),
              _AttendanceStat(
                emoji: '\u23F3',
                label: '\uBBF8\uC751\uB2F5',
                count: _pendingCount,
                color: AppColors.secondaryAmber,
              ),
              const SizedBox(width: AppSpacing.md),
              _AttendanceStat(
                emoji: '\u274C',
                label: '\uBD80\uC7AC',
                count: widget.absentCount,
                color: AppColors.semanticError,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AttendanceStat extends StatelessWidget {
  const _AttendanceStat({
    required this.emoji,
    required this.label,
    required this.count,
    required this.color,
  });

  final String emoji;
  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 4),
        Text(
          '$label $count\uBA85',
          style: AppTypography.bodySmall.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// _SectionHeader — section title + count
// =============================================================================

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.count,
  });

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: AppTypography.titleMedium.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          ),
          child: Text(
            '$count',
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// _GuardianSectionHeader — section title + "가디언 관리" button (captain only)
// =============================================================================

class _GuardianSectionHeader extends StatelessWidget {
  const _GuardianSectionHeader({
    required this.guardianCount,
    required this.isCaptain,
    this.onManageTap,
    this.freeCount = 0,
    this.paidCount = 0,
  });

  final int guardianCount;
  final bool isCaptain;
  final VoidCallback? onManageTap;
  final int freeCount;
  final int paidCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text(
          '\u{1F6E1}',
          style: TextStyle(fontSize: 16),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          '\uBCF4\uD638\uC790',
          style: AppTypography.titleMedium.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          ),
          child: Text(
            '$guardianCount',
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          '\u{1F193} $freeCount/2  \u{1F48E} $paidCount/3',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textTertiary,
          ),
        ),
        const Spacer(),
        if (isCaptain)
          TextButton(
            onPressed: onManageTap,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primaryTeal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              minimumSize: const Size(0, 32),
            ),
            child: Text(
              '\uAC00\uB514\uC5B8 \uAD00\uB9AC',
              style: AppTypography.labelMedium.copyWith(
                color: AppColors.primaryTeal,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}

// =============================================================================
// _GuardianSlotCard — compact card for a guardian slot
// =============================================================================

class _GuardianSlotCard extends StatelessWidget {
  const _GuardianSlotCard({required this.slot});

  final GuardianSlot slot;

  @override
  Widget build(BuildContext context) {
    final isPending = slot.status == 'pending';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radius12),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(
        children: [
          AvatarWidget(
            userId: slot.guardianUserId,
            userName: slot.guardianName,
            profileImageUrl: slot.guardianProfileImageUrl,
            radius: 18,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      slot.guardianName,
                      style: AppTypography.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      slot.isPaid ? '\u{1F48E}' : '\u{1F193}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
                if (isPending)
                  Text(
                    '\uC218\uB77D \uB300\uAE30 \uC911',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.secondaryAmber,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                if (slot.isPaused)
                  Text(
                    '\uC77C\uC2DC\uC815\uC9C0 \uC911',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
              ],
            ),
          ),
          // 가디언 역할 배지
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(AppSpacing.radius8),
            ),
            child: Text(
              '\uAC00\uB514\uC5B8',
              style: AppTypography.labelSmall.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.guardian,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// _GuardianManageSheet (SS5.2) — DraggableScrollableSheet for guardian mgmt
// =============================================================================

class _GuardianManageSheet extends StatelessWidget {
  const _GuardianManageSheet({
    required this.guardianSlots,
    required this.isCaptain,
    required this.isMinor,
    required this.tripId,
    this.onRefresh,
  });

  final List<GuardianSlot> guardianSlots;
  final bool isCaptain;
  final bool isMinor;
  final String tripId;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final freeSlots = guardianSlots.where((s) => !s.isPaid).toList();
    final paidSlots = guardianSlots.where((s) => s.isPaid).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppSpacing.bottomSheetRadius),
            ),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenPaddingH,
              vertical: AppSpacing.md,
            ),
            children: [
              // 핸들바
              Center(
                child: Container(
                  width: AppSpacing.bottomSheetHandleWidth,
                  height: AppSpacing.bottomSheetHandleHeight,
                  margin: const EdgeInsets.only(bottom: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.outline,
                    borderRadius: BorderRadius.circular(
                      AppSpacing.bottomSheetHandleHeight / 2,
                    ),
                  ),
                ),
              ),

              // 타이틀
              Text(
                '\uAC00\uB514\uC5B8 \uAD00\uB9AC',
                style: AppTypography.titleLarge.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // 무료 슬롯 섹션
              _buildSlotSectionHeader(
                '\uBB34\uB8CC \uC2AC\uB86F (${freeSlots.length}/2 \uC0AC\uC6A9)',
                false,
              ),
              const SizedBox(height: AppSpacing.sm),
              if (freeSlots.isEmpty)
                _buildEmptySlotMessage('\uBB34\uB8CC \uAC00\uB514\uC5B8\uC774 \uC5C6\uC2B5\uB2C8\uB2E4')
              else
                ...freeSlots.map(
                  (slot) => _buildGuardianRow(context, slot),
                ),

              const SizedBox(height: AppSpacing.lg),

              // 유료 슬롯 섹션
              _buildSlotSectionHeader(
                '\uC720\uB8CC \uC2AC\uB86F (${paidSlots.length}/3 \uC0AC\uC6A9) \u2014 1,900\uC6D0/\uC5EC\uD589',
                true,
              ),
              const SizedBox(height: AppSpacing.sm),
              if (paidSlots.isEmpty)
                _buildEmptySlotMessage('\uC720\uB8CC \uAC00\uB514\uC5B8\uC774 \uC5C6\uC2B5\uB2C8\uB2E4')
              else
                ...paidSlots.map(
                  (slot) => _buildGuardianRow(context, slot),
                ),

              const SizedBox(height: AppSpacing.md),

              // + 유료 가디언 추가 버튼
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showPaymentModal(context),
                  icon: const Text('\u{1F48E}', style: TextStyle(fontSize: 16)),
                  label: const Text('\uC720\uB8CC \uAC00\uB514\uC5B8 \uCD94\uAC00'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryTeal,
                    side: const BorderSide(color: AppColors.primaryTeal),
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radius8),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // 안내 문구
              Text(
                '\u203B \uAC00\uB514\uC5B8 \uD574\uC81C \uC2DC \uC774\uBBF8 \uACB0\uC81C\uB41C \uC694\uAE08\uC740 \uD658\uBD88\uB418\uC9C0 \uC54A\uC2B5\uB2C8\uB2E4.',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSlotSectionHeader(String text, bool isPaid) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: isPaid
            ? AppColors.primaryTeal.withValues(alpha: 0.08)
            : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppSpacing.radius4),
      ),
      child: Text(
        text,
        style: AppTypography.labelMedium.copyWith(
          color: isPaid ? AppColors.primaryTeal : AppColors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildEmptySlotMessage(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Center(
        child: Text(
          text,
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textTertiary,
          ),
        ),
      ),
    );
  }

  Widget _buildGuardianRow(BuildContext context, GuardianSlot slot) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radius8),
          border: Border.all(color: AppColors.outlineVariant),
        ),
        child: Row(
          children: [
            AvatarWidget(
              userId: slot.guardianUserId,
              userName: slot.guardianName,
              profileImageUrl: slot.guardianProfileImageUrl,
              radius: 16,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    slot.guardianName,
                    style: AppTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (slot.status == 'pending')
                    Text(
                      '\uC218\uB77D \uB300\uAE30 \uC911',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.secondaryAmber,
                      ),
                    ),
                ],
              ),
            ),
            if (isCaptain)
              TextButton(
                onPressed: () => _showRemoveGuardianDialog(context, slot),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.semanticError,
                  minimumSize: const Size(0, 32),
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                ),
                child: Text(
                  '\uD574\uC81C',
                  style: AppTypography.labelMedium.copyWith(
                    color: AppColors.semanticError,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Payment Modal (SS5.3)
  // ---------------------------------------------------------------------------

  void _showPaymentModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radius16),
        ),
        title: Text(
          '\u{1F48E} \uD504\uB9AC\uBBF8\uC5C4 \uAC00\uB514\uC5B8 \uCD94\uAC00',
          style: AppTypography.titleMedium.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '\uC774 \uC5EC\uD589\uC5D0 \uAC00\uB514\uC5B8\uC744 \uCD94\uAC00\uD558\uB824\uBA74\n1,900\uC6D0\uC774 \uACB0\uC81C\uB429\uB2C8\uB2E4.',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _buildBulletItem('\uC2E4\uC2DC\uAC04 \uC704\uCE58 \uACF5\uC720 \uBAA8\uB2C8\uD130\uB9C1'),
            _buildBulletItem('SOS \uC54C\uB9BC \uC218\uC2E0'),
            _buildBulletItem('\uC5EC\uD589 \uC885\uB8CC \uC2DC\uAE4C\uC9C0 \uC720\uD6A8'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              '\uCDE8\uC18C',
              style: AppTypography.labelMedium.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              // TODO: 결제 프로세스 연동
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryTeal,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radius8),
              ),
            ),
            child: const Text('1,900\uC6D0 \uACB0\uC81C \uD6C4 \uCD94\uAC00'),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Remove Guardian Dialog (SS5.4)
  // ---------------------------------------------------------------------------

  void _showRemoveGuardianDialog(BuildContext context, GuardianSlot slot) {
    // §10.2: 미성년자 멤버는 캡틴 승인 요청으로 분기
    if (isMinor) {
      _showMinorReleaseRequestDialog(context, slot);
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radius16),
        ),
        title: Text(
          '\uAC00\uB514\uC5B8 \uD574\uC81C',
          style: AppTypography.titleMedium.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          '${slot.guardianName}\uB2D8\uACFC\uC758 \uAC00\uB514\uC5B8 \uC5F0\uACB0\uC744 \uD574\uC81C\uD558\uC2DC\uACA0\uC2B5\uB2C8\uAE4C?\n\uC774\uBBF8 \uACB0\uC81C\uB41C 1,900\uC6D0\uC740 \uD658\uBD88\uB418\uC9C0 \uC54A\uC2B5\uB2C8\uB2E4.',
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              '\uCDE8\uC18C',
              style: AppTypography.labelMedium.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ApiService().removeGuardianLink(tripId, slot.linkId);
                onRefresh?.call();
              } catch (e) {
                debugPrint('[GuardianManageSheet] Guardian removal failed: $e');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.semanticError,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radius8),
              ),
            ),
            child: const Text('\uD574\uC81C'),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Minor Guardian Release Request Dialog (§10.2)
  // ---------------------------------------------------------------------------

  void _showMinorReleaseRequestDialog(BuildContext context, GuardianSlot slot) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radius16),
        ),
        title: Text(
          '가디언 해제 요청',
          style: AppTypography.titleMedium.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          '미성년자 멤버의 가디언 해제는 캡틴 승인이 필요합니다.\n'
          '캡틴에게 ${slot.guardianName}님 가디언 해제 요청을 보내시겠습니까?',
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              '취소',
              style: AppTypography.labelMedium.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ApiService().requestGuardianRelease(tripId, slot.linkId);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('캡틴에게 가디언 해제 요청을 보냈습니다.'),
                    ),
                  );
                }
              } catch (e) {
                debugPrint('[GuardianManageSheet] Release request failed: $e');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryTeal,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radius8),
              ),
            ),
            child: const Text('요청 전송'),
          ),
        ],
      ),
    );
  }

  Widget _buildBulletItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '\u2022 ',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// _MemberDetailSheet (§7.4) — Member profile detail modal
// =============================================================================

class _MemberDetailSheet extends StatelessWidget {
  const _MemberDetailSheet({required this.member});
  final TripMember member;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppColors.outline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                member.userName,
                style: AppTypography.titleLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                member.displayRoleName,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

}
