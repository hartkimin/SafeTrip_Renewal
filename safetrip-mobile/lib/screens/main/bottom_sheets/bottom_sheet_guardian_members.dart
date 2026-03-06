import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../features/trip/providers/trip_provider.dart';
import '../../../models/trip_member.dart';
import '../../../services/api_service.dart';
import '../../../widgets/avatar_widget.dart';

// =============================================================================
// BottomSheetGuardianMembers -- DOC-T3-MBR-019 SS9
// =============================================================================

/// Guardian-only member status tab (DOC-T3-MBR-019 SS9)
///
/// Displays the linked member(s) that this guardian is monitoring.
/// Features:
/// - Linked member card with location, battery, online status
/// - Emergency location request (rate-limited: 3 per hour per member)
/// - Message button
/// - Schedule summary (paid guardian only)
/// - SOS active state with red border
class BottomSheetGuardianMembers extends ConsumerStatefulWidget {
  const BottomSheetGuardianMembers({
    super.key,
    required this.scrollController,
  });

  final ScrollController scrollController;

  @override
  ConsumerState<BottomSheetGuardianMembers> createState() =>
      _BottomSheetGuardianMembersState();
}

class _BottomSheetGuardianMembersState
    extends ConsumerState<BottomSheetGuardianMembers> {
  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------

  List<TripMember> _linkedMembers = [];
  bool _isLoading = true;
  String? _error;
  bool _isPaidGuardian = false;

  /// Emergency location request timestamps per member (memberId -> timestamps).
  /// Used for rate limiting: max 3 requests per hour per member.
  final Map<String, List<DateTime>> _locationRequestHistory = {};

  /// Rate limit constants
  static const int _maxRequestsPerHour = 3;
  static const Duration _rateLimitWindow = Duration(hours: 1);

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadLinkedMembers();
    });
  }

  // ---------------------------------------------------------------------------
  // Data Loading
  // ---------------------------------------------------------------------------

  Future<void> _loadLinkedMembers() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final tripState = ref.read(tripProvider);
      final tripId = tripState.currentTrip?.tripId;

      if (tripId == null || tripId.isEmpty) {
        setState(() {
          _isLoading = false;
          _error = null;
          _linkedMembers = [];
        });
        return;
      }

      final apiService = ApiService();
      final data = await apiService.getMyGuardians(tripId);

      if (!mounted) return;

      // Parse linked members from the API response.
      // Each item in data represents a guardian link containing the linked member info.
      final List<TripMember> members = [];
      bool paidFlag = false;

      for (final item in data) {
        // Determine if this guardian link is paid
        final isPaid = item['is_paid'] as bool? ??
            item['isPaid'] as bool? ??
            false;
        if (isPaid) paidFlag = true;

        // The linked member info may be nested under 'member' or at top level
        final memberData = item['member'] as Map<String, dynamic>? ?? item;
        try {
          final member = TripMember.fromJson(memberData);
          members.add(member);
        } catch (e) {
          debugPrint('[GuardianMembers] Failed to parse member: $e');
        }
      }

      setState(() {
        _linkedMembers = members;
        _isPaidGuardian = paidFlag;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('[GuardianMembers] _loadLinkedMembers Error: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Rate Limiting: Emergency Location Request
  // ---------------------------------------------------------------------------

  /// Checks whether the guardian can request emergency location for [memberId].
  /// Returns true if fewer than [_maxRequestsPerHour] requests in the past hour.
  bool _canRequestLocation(String memberId) {
    final history = _locationRequestHistory[memberId];
    if (history == null || history.isEmpty) return true;

    final cutoff = DateTime.now().subtract(_rateLimitWindow);
    final recentRequests = history.where((t) => t.isAfter(cutoff)).length;
    return recentRequests < _maxRequestsPerHour;
  }

  /// Returns a human-readable cooldown text such as "N분 후 가능".
  /// Returns null if no cooldown is active.
  String? _getRemainingCooldownText(String memberId) {
    final history = _locationRequestHistory[memberId];
    if (history == null || history.isEmpty) return null;

    final cutoff = DateTime.now().subtract(_rateLimitWindow);
    final recentRequests =
        history.where((t) => t.isAfter(cutoff)).toList()..sort();

    if (recentRequests.length < _maxRequestsPerHour) return null;

    // The oldest request in the window determines when the next slot opens.
    final oldestInWindow = recentRequests.first;
    final nextAvailable = oldestInWindow.add(_rateLimitWindow);
    final remaining = nextAvailable.difference(DateTime.now());

    if (remaining.isNegative) return null;

    final minutes = remaining.inMinutes + 1; // round up
    return '$minutes분 후 다시 요청 가능합니다';
  }

  /// Handles emergency location request for [member].
  /// Adds timestamp, shows appropriate SnackBar for offline members.
  void _requestEmergencyLocation(TripMember member) {
    if (!_canRequestLocation(member.userId)) return;

    setState(() {
      _locationRequestHistory
          .putIfAbsent(member.userId, () => [])
          .add(DateTime.now());
    });

    final messenger = ScaffoldMessenger.of(context);

    if (!member.isOnline) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            '연결 멤버가 오프라인입니다. 온라인 전환 시 알림이 전달됩니다.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text('${member.userName}님에게 긴급 위치 요청을 보냈습니다.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    // TODO: Call actual emergency location request API when available
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final tripState = ref.watch(tripProvider);
    final tripName = tripState.currentTripName;

    // --- Loading ---
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.xxl),
          child: CircularProgressIndicator(color: AppColors.primaryTeal),
        ),
      );
    }

    // --- Error ---
    if (_error != null) {
      return _buildErrorState();
    }

    // --- Empty ---
    if (_linkedMembers.isEmpty) {
      return _buildEmptyState();
    }

    // --- Content ---
    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenPaddingH,
        AppSpacing.md,
        AppSpacing.screenPaddingH,
        AppSpacing.xxl + AppSpacing.navigationBarHeight,
      ),
      children: [
        // Header
        _buildHeader(tripName),
        const SizedBox(height: AppSpacing.md),

        // Linked member cards
        for (int i = 0; i < _linkedMembers.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.cardGap),
          _buildLinkedMemberCard(_linkedMembers[i]),
        ],
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Header
  // ---------------------------------------------------------------------------

  Widget _buildHeader(String tripName) {
    return Row(
      children: [
        const Icon(
          Icons.shield_outlined,
          size: 20,
          color: AppColors.primaryTeal,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '내 연결 멤버',
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (tripName.isNotEmpty) ...[
                  TextSpan(
                    text: ' \u2014 ',
                    style: AppTypography.titleMedium.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                  TextSpan(
                    text: tripName,
                    style: AppTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.w400,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
        // Refresh button
        IconButton(
          onPressed: _loadLinkedMembers,
          icon: const Icon(Icons.refresh, size: 20),
          color: AppColors.textTertiary,
          tooltip: '새로고침',
          splashRadius: 20,
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Linked Member Card (SS9.1)
  // ---------------------------------------------------------------------------

  Widget _buildLinkedMemberCard(TripMember member) {
    final isSos = member.isSosActive;
    final canRequest = _canRequestLocation(member.userId);
    final cooldownText = _getRemainingCooldownText(member.userId);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: isSos
            ? AppColors.sosDanger.withValues(alpha: 0.08)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radius12),
        border: Border.all(
          color: isSos ? AppColors.sosDanger : AppColors.outlineVariant,
          width: isSos ? 2.0 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row 1: Avatar + Name + Role + Battery + SOS label
          _buildMemberHeaderRow(member),

          const SizedBox(height: AppSpacing.sm),

          // Row 2: Location + Online status
          _buildLocationRow(member),

          const SizedBox(height: AppSpacing.md),

          // Row 3: Action buttons (message + emergency location)
          _buildActionButtonRow(member, canRequest, cooldownText),

          // Paid guardian: Schedule summary section
          if (_isPaidGuardian) ...[
            const SizedBox(height: AppSpacing.md),
            const Divider(height: 1, color: AppColors.outlineVariant),
            const SizedBox(height: AppSpacing.md),
            _buildScheduleSummary(member),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Member Header Row: Avatar + Status Dot + Name (Role) + Battery + SOS
  // ---------------------------------------------------------------------------

  Widget _buildMemberHeaderRow(TripMember member) {
    return Row(
      children: [
        // Avatar with status dot
        SizedBox(
          width: 44,
          height: 44,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              AvatarWidget(
                userId: member.userId,
                userName: member.userName,
                profileImageUrl: member.profileImageUrl,
                radius: 20,
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: _StatusDot(
                  isOnline: member.isOnline,
                  isSosActive: member.isSosActive,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(width: AppSpacing.sm),

        // Name + Role
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: Text(
                  member.userName,
                  style: AppTypography.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                '(${member.displayRoleName})',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),

        // SOS label
        if (member.isSosActive) ...[
          const SizedBox(width: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.sosDanger,
              borderRadius: BorderRadius.circular(AppSpacing.radius4),
            ),
            child: Text(
              'SOS 발신 중',
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.sosText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Location Row: location icon + text + time + battery + online badge
  // ---------------------------------------------------------------------------

  Widget _buildLocationRow(TripMember member) {
    return Row(
      children: [
        // Location pin icon
        const Icon(
          Icons.location_on_outlined,
          size: 14,
          color: AppColors.textTertiary,
        ),
        const SizedBox(width: 2),

        // Location text + time
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: member.locationDisplayText,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
                if (member.locationTimeText != null) ...[
                  TextSpan(
                    text: ' \u00B7 ${member.locationTimeText}',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ],
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),

        // Battery indicator
        if (member.batteryLevel != null) ...[
          const SizedBox(width: AppSpacing.sm),
          _buildBatteryIndicator(member.batteryLevel!),
        ],

        // Online/Offline badge
        const SizedBox(width: AppSpacing.sm),
        _buildOnlineBadge(member.isOnline),
      ],
    );
  }

  Widget _buildBatteryIndicator(int level) {
    final isLow = level <= 20;
    final color = isLow ? AppColors.semanticError : AppColors.textTertiary;

    IconData icon;
    if (level > 80) {
      icon = Icons.battery_full;
    } else if (level > 50) {
      icon = Icons.battery_5_bar;
    } else if (level > 20) {
      icon = Icons.battery_3_bar;
    } else {
      icon = Icons.battery_1_bar;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 2),
        Text(
          '$level%',
          style: AppTypography.bodySmall.copyWith(
            color: color,
            fontWeight: isLow ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildOnlineBadge(bool isOnline) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: isOnline ? AppColors.semanticSuccess : AppColors.textDisabled,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          isOnline ? '온라인' : '오프라인',
          style: AppTypography.bodySmall.copyWith(
            color: isOnline ? AppColors.semanticSuccess : AppColors.textDisabled,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Action Button Row (SS9.2): Message + Emergency Location Request
  // ---------------------------------------------------------------------------

  Widget _buildActionButtonRow(
    TripMember member,
    bool canRequest,
    String? cooldownText,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Message button
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  // TODO: Navigate to guardian message screen
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${member.userName}님에게 메시지 보내기'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                icon: const Icon(Icons.message_outlined, size: 16),
                label: const Text('메시지'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryTeal,
                  side: const BorderSide(color: AppColors.primaryTeal),
                  textStyle: AppTypography.labelMedium,
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.sm,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radius8),
                  ),
                ),
              ),
            ),

            const SizedBox(width: AppSpacing.sm),

            // Emergency location request button
            Expanded(
              child: ElevatedButton.icon(
                onPressed:
                    canRequest ? () => _requestEmergencyLocation(member) : null,
                icon: const Icon(Icons.my_location, size: 16),
                label: const Text('긴급 위치 요청'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondaryAmber,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      AppColors.secondaryAmber.withValues(alpha: 0.3),
                  disabledForegroundColor: Colors.white70,
                  textStyle: AppTypography.labelMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.sm,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radius8),
                  ),
                ),
              ),
            ),
          ],
        ),

        // Rate limit cooldown text
        if (!canRequest && cooldownText != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.xs),
            child: Text(
              cooldownText,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textWarning,
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Schedule Summary (SS9.3 -- Paid Guardian Only)
  // ---------------------------------------------------------------------------

  Widget _buildScheduleSummary(TripMember member) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.calendar_today_outlined,
              size: 14,
              color: AppColors.primaryTeal,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              '연결 멤버 일정 요약',
              style: AppTypography.labelMedium.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),

        // Placeholder schedule items
        // TODO: Replace with actual schedule data from API
        _buildScheduleItem(
          time: '오늘 15:00',
          description: '일정 정보를 불러오는 중...',
          icon: Icons.place_outlined,
        ),
      ],
    );
  }

  Widget _buildScheduleItem({
    required String time,
    required String description,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: AppColors.textTertiary),
          const SizedBox(width: AppSpacing.xs),
          Text(
            time,
            style: AppTypography.bodySmall.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              description,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textTertiary,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Empty State
  // ---------------------------------------------------------------------------

  Widget _buildEmptyState() {
    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.3,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.shield_outlined,
                  size: 64,
                  color: AppColors.textDisabled.withValues(alpha: 0.5),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  '연결된 멤버가 없습니다',
                  style: AppTypography.bodyLarge.copyWith(
                    color: AppColors.textTertiary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '여행 멤버가 가디언으로 초대하면\n이 화면에서 멤버 상태를 확인할 수 있습니다.',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textDisabled,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Error State
  // ---------------------------------------------------------------------------

  Widget _buildErrorState() {
    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.3,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 48,
                  color: AppColors.semanticError,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  '멤버 정보를 불러올 수 없습니다',
                  style: AppTypography.bodyLarge.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton.icon(
                  onPressed: _loadLinkedMembers,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('다시 시도'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryTeal,
                    side: const BorderSide(color: AppColors.primaryTeal),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// _StatusDot -- 8dp online/offline/SOS indicator (from MemberCard SS4.2)
// =============================================================================

class _StatusDot extends StatefulWidget {
  const _StatusDot({
    required this.isOnline,
    required this.isSosActive,
  });

  final bool isOnline;
  final bool isSosActive;

  @override
  State<_StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<_StatusDot>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void initState() {
    super.initState();
    _setupAnimation();
  }

  @override
  void didUpdateWidget(covariant _StatusDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isSosActive != widget.isSosActive) {
      _setupAnimation();
    }
  }

  void _setupAnimation() {
    if (widget.isSosActive) {
      _controller ??= AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1000),
      );
      _controller!.repeat(reverse: true);
    } else {
      _controller?.stop();
      _controller?.dispose();
      _controller = null;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Color get _dotColor {
    if (widget.isSosActive) return const Color(0xFFF44336);
    if (widget.isOnline) return const Color(0xFF4CAF50);
    return const Color(0xFF9E9E9E);
  }

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: _dotColor,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
      ),
    );

    if (widget.isSosActive && _controller != null) {
      return AnimatedBuilder(
        animation: _controller!,
        builder: (context, child) {
          return Opacity(
            opacity: 0.5 + _controller!.value * 0.5,
            child: child,
          );
        },
        child: dot,
      );
    }

    return dot;
  }
}
