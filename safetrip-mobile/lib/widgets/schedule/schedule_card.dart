import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../models/schedule.dart';

/// 일정 카드 위젯
/// 시간, 아이콘, 제목, 위치, 상태 배지를 표시한다.
/// status: 'current' | 'upcoming' | 'past' | 'future'
class ScheduleCard extends StatelessWidget {
  const ScheduleCard({
    super.key,
    required this.schedule,
    required this.status,
    this.canEdit = false,
    this.onTap,
    this.onMapTap,
  });

  final Schedule schedule;
  final String status;
  final bool canEdit;
  final VoidCallback? onTap;
  final VoidCallback? onMapTap;

  /// schedule_type -> FontAwesome 아이콘 매핑 (7 types)
  static IconData _iconForType(String type) {
    switch (type) {
      case 'move':
        return FontAwesomeIcons.plane;
      case 'stay':
        return FontAwesomeIcons.hotel;
      case 'meal':
        return FontAwesomeIcons.utensils;
      case 'sightseeing':
        return FontAwesomeIcons.locationDot;
      case 'shopping':
        return FontAwesomeIcons.bagShopping;
      case 'meeting':
        return FontAwesomeIcons.userGroup;
      case 'other':
      default:
        return FontAwesomeIcons.thumbtack;
    }
  }

  /// schedule_type -> 아이콘 배경색
  static Color _iconBgForType(String type) {
    switch (type) {
      case 'move':
        return const Color(0xFFE3F2FD);
      case 'stay':
        return const Color(0xFFF3E5F5);
      case 'meal':
        return const Color(0xFFFFF3E0);
      case 'sightseeing':
        return const Color(0xFFE8F5E9);
      case 'shopping':
        return const Color(0xFFFCE4EC);
      case 'meeting':
        return const Color(0xFFE0F2F1);
      case 'other':
      default:
        return const Color(0xFFF5F5F5);
    }
  }

  /// schedule_type -> 아이콘 색상
  static Color _iconColorForType(String type) {
    switch (type) {
      case 'move':
        return const Color(0xFF1565C0);
      case 'stay':
        return const Color(0xFF7B1FA2);
      case 'meal':
        return const Color(0xFFE65100);
      case 'sightseeing':
        return const Color(0xFF2E7D32);
      case 'shopping':
        return const Color(0xFFC62828);
      case 'meeting':
        return AppColors.primaryTeal;
      case 'other':
      default:
        return AppColors.textTertiary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPast = status == 'past';
    final isCurrent = status == 'current';
    final isUpcoming = status == 'upcoming';

    final timeFormat = DateFormat('HH:mm');
    final startStr = timeFormat.format(schedule.startTime);
    final endStr =
        schedule.endTime != null ? timeFormat.format(schedule.endTime!) : '';

    // 테두리 설정
    Border cardBorder;
    if (isCurrent) {
      cardBorder = Border.all(color: AppColors.primaryTeal, width: 2);
    } else if (isUpcoming) {
      cardBorder = Border.all(color: AppColors.secondaryAmber, width: 1.5);
    } else {
      cardBorder = Border.all(color: Colors.transparent, width: 0.5);
    }

    return Opacity(
      opacity: isPast ? 0.5 : 1.0,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenPaddingH,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radius12),
            border: cardBorder,
            boxShadow: [
              if (!isPast)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 좌측: 시간 컬럼 + 수직선
                _buildTimeColumn(startStr, endStr, isCurrent),
                // 우측: 콘텐츠
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.cardPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 상단: 아이콘 + 제목 + 상태배지 + 지도 버튼
                        Row(
                          children: [
                            _buildTypeIcon(),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    schedule.title,
                                    style: AppTypography.labelLarge.copyWith(
                                      color: AppColors.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (schedule.locationName != null &&
                                      schedule.locationName!.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        schedule.locationName!,
                                        style:
                                            AppTypography.bodySmall.copyWith(
                                          color: AppColors.textTertiary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            // 상태 배지
                            if (isCurrent || isUpcoming) ...[
                              const SizedBox(width: AppSpacing.sm),
                              _buildStatusBadge(),
                            ],
                            // 지도 버튼
                            if (schedule.locationCoords != null &&
                                onMapTap != null) ...[
                              const SizedBox(width: AppSpacing.xs),
                              _buildMapButton(),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 좌측 시간 컬럼 (시작~종료 + 수직 라인)
  Widget _buildTimeColumn(
      String startStr, String endStr, bool isCurrent) {
    return Container(
      width: 64,
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.cardPadding,
        horizontal: AppSpacing.sm,
      ),
      child: Column(
        children: [
          Text(
            startStr,
            style: AppTypography.labelMedium.copyWith(
              color: isCurrent
                  ? AppColors.primaryTeal
                  : AppColors.textSecondary,
              fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          if (endStr.isNotEmpty) ...[
            Expanded(
              child: Center(
                child: Container(
                  width: 1.5,
                  constraints: const BoxConstraints(minHeight: 8),
                  color: isCurrent
                      ? AppColors.primaryTeal.withValues(alpha: 0.4)
                      : AppColors.outlineVariant,
                ),
              ),
            ),
            Text(
              endStr,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ] else
            const Spacer(),
        ],
      ),
    );
  }

  /// 일정 타입 아이콘
  Widget _buildTypeIcon() {
    final icon = _iconForType(schedule.scheduleType);
    final bgColor = _iconBgForType(schedule.scheduleType);
    final iconColor = _iconColorForType(schedule.scheduleType);

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppSpacing.radius8),
      ),
      alignment: Alignment.center,
      child: FaIcon(icon, size: 16, color: iconColor),
    );
  }

  /// 상태 배지 ('진행 중' / '곧 시작')
  Widget _buildStatusBadge() {
    final isCurrent = status == 'current';
    final label = isCurrent ? '진행 중' : '곧 시작';
    final color =
        isCurrent ? AppColors.primaryTeal : AppColors.secondaryAmber;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      ),
      child: Text(
        label,
        style: AppTypography.labelSmall.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// 지도 보기 버튼
  Widget _buildMapButton() {
    return GestureDetector(
      onTap: onMapTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(AppSpacing.radius8),
        ),
        alignment: Alignment.center,
        child: const Icon(
          Icons.map_outlined,
          size: 18,
          color: AppColors.textTertiary,
        ),
      ),
    );
  }
}
