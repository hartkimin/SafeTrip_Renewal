import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';
import '../models/trip_member.dart';
import '../models/user.dart';
import 'avatar_widget.dart';

/// 멤버 카드 위젯 (DOC-T3-MBR-019 SS4)
///
/// 여행 멤버 한 명의 정보를 카드 형태로 표시한다.
/// - 프로필 사진 + 상태 표시등 (온라인/오프라인/SOS)
/// - 역할 배지 + 이름 + B2B 역할명
/// - 위치 정보 + 배터리 잔량
/// - SOS 활성 시: 빨간 테두리 + 액션 버튼 행
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

  /// SOS "지도에서 보기" 탭 콜백
  final VoidCallback? onMapTap;

  /// SOS "메시지" 탭 콜백
  final VoidCallback? onMessageTap;

  /// 가디언 배지 표시 여부 (SS5.1)
  final bool showGuardianBadge;

  /// 유료 가디언 여부 (true: 💎, false: 🆓)
  final bool isPaidGuardian;

  /// 가디언 상태 ('pending' 이면 "수락 대기 중" 배지 표시)
  final String? guardianStatus;

  /// B2B 여행 여부 (true 이면 B2B 역할명 표시)
  final bool isB2bTrip;

  @override
  Widget build(BuildContext context) {
    final isSos = member.isSosActive;

    return GestureDetector(
      onTap: onTap,
      child: Container(
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
            // -- 상단 행: 아바타 + 역할배지 + 이름 --
            _buildHeaderRow(),

            const SizedBox(height: AppSpacing.sm),

            // -- 하단 행: 위치 + 배터리 --
            _buildLocationRow(),

            // -- SOS 활성 시 추가 영역 --
            if (isSos) ...[
              const SizedBox(height: AppSpacing.sm),
              _buildSosSection(),
            ],
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Header Row: Avatar + Status Dot + Role Badge + Name + Guardian/Pending
  // ---------------------------------------------------------------------------

  Widget _buildHeaderRow() {
    return Row(
      children: [
        // 아바타 + 상태 표시등
        _buildAvatarWithStatus(),

        const SizedBox(width: AppSpacing.sm),

        // 역할 배지
        _RoleBadge(role: member.memberRole),

        const SizedBox(width: AppSpacing.xs),

        // 이름
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

        // B2B 역할명 (SS6) — 20자 초과 말줄임 + 롱탭 Tooltip (§6.2)
        if (isB2bTrip &&
            member.b2bRoleName != null &&
            member.b2bRoleName!.isNotEmpty) ...[
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            flex: 0,
            child: Tooltip(
              message: member.b2bRoleName!,
              child: Text(
                '(${member.b2bRoleName!.length > 20 ? '${member.b2bRoleName!.substring(0, 20)}...' : member.b2bRoleName!})',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textTertiary,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ),
        ],

        // 가디언 유/무료 배지 (SS5.1)
        if (showGuardianBadge) ...[
          const SizedBox(width: AppSpacing.xs),
          Text(
            isPaidGuardian ? '\u{1F48E}' : '\u{1F193}', // 💎 or 🆓
            style: const TextStyle(fontSize: 14),
          ),
        ],

        // SOS 발신 중 라벨 (SS4.3)
        if (member.isSosActive) ...[
          const SizedBox(width: AppSpacing.sm),
          _buildSosLabel(),
        ],

        // 가디언 수락 대기 중 배지
        if (guardianStatus == 'pending') ...[
          const SizedBox(width: AppSpacing.sm),
          _buildPendingBadge(),
        ],
      ],
    );
  }

  Widget _buildAvatarWithStatus() {
    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AvatarWidget(
            userId: member.userId,
            userName: member.userName,
            profileImageUrl: member.profileImageUrl,
            radius: 20, // 40dp circle
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
    );
  }

  Widget _buildSosLabel() {
    return Container(
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
    );
  }

  Widget _buildPendingBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.secondaryAmber.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppSpacing.radius4),
        border: Border.all(
          color: AppColors.secondaryAmber,
          width: 0.5,
        ),
      ),
      child: Text(
        '수락 대기 중',
        style: AppTypography.labelSmall.copyWith(
          color: AppColors.textWarning,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Location Row: pin icon + location text + time + battery
  // ---------------------------------------------------------------------------

  Widget _buildLocationRow() {
    return Row(
      children: [
        // 위치 아이콘
        const Icon(
          Icons.location_on_outlined,
          size: 14,
          color: AppColors.textTertiary,
        ),
        const SizedBox(width: 2),

        // 위치 텍스트
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
                if (member.locationTimeText != null &&
                    member.isOnline &&
                    !member.isSosActive) ...[
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

        // 배터리 표시
        if (member.batteryLevel != null) ...[
          const SizedBox(width: AppSpacing.sm),
          _buildBatteryIndicator(member.batteryLevel!),
        ],
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

  // ---------------------------------------------------------------------------
  // SOS Section (SS4.3): action buttons
  // ---------------------------------------------------------------------------

  Widget _buildSosSection() {
    return Row(
      children: [
        Expanded(
          child: _SosActionButton(
            icon: Icons.map_outlined,
            label: '지도에서 보기',
            onTap: onMapTap,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _SosActionButton(
            icon: Icons.message_outlined,
            label: '메시지',
            onTap: onMessageTap,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _SosActionButton(
            icon: Icons.phone_outlined,
            label: '119 안내',
            onTap: () async {
              final uri = Uri(scheme: 'tel', path: '119');
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri);
              }
            },
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// _StatusDot — 8dp online/offline/SOS indicator (SS4.2)
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

// =============================================================================
// _RoleBadge — role chip (SS4.2)
// =============================================================================

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final (String emoji, Color bgColor, String label) = switch (role) {
      UserRole.captain => ('\u{1F451}', const Color(0xFFFFF8E1), '캡틴'),
      UserRole.crewChief => ('\u{1F537}', const Color(0xFFE3F2FD), '크루장'),
      UserRole.crew => ('\u{26AA}', const Color(0xFFF5F5F5), '크루'),
      UserRole.guardian => ('\u{1F6E1}', const Color(0xFFE8F5E9), '가디언'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppSpacing.radius8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 10)),
          const SizedBox(width: 2),
          Text(
            label,
            style: AppTypography.labelSmall.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// _SosActionButton — SOS action row button (SS4.3)
// =============================================================================

class _SosActionButton extends StatelessWidget {
  const _SosActionButton({
    required this.icon,
    required this.label,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radius8),
        child: Container(
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.sm,
            horizontal: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            border: Border.all(
              color: AppColors.sosDanger.withValues(alpha: 0.3),
            ),
            borderRadius: BorderRadius.circular(AppSpacing.radius8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: AppColors.sosDanger),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.sosDanger,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
