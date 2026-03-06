import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// 여행 진행률 표시 위젯.
/// 완료된 일정 수 / 전체 일정 수를 기반으로 진행률 바를 표시한다.
/// tripStatus == 'active' 일 때만 표시한다.
class TripProgressBar extends StatelessWidget {
  const TripProgressBar({
    super.key,
    required this.completedCount,
    required this.totalCount,
  });

  final int completedCount;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    final percentage =
        totalCount > 0 ? (completedCount / totalCount) : 0.0;
    final percentText = (percentage * 100).round();

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenPaddingH,
        vertical: AppSpacing.sm,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.cardPadding,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.primaryTeal.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppSpacing.radius12),
        border: Border.all(
          color: AppColors.primaryTeal.withValues(alpha: 0.15),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 텍스트: "여행 진행률 65% (13/20 일정 완료)"
          Row(
            children: [
              const Icon(
                Icons.trending_up,
                size: 16,
                color: AppColors.primaryTeal,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    children: [
                      const TextSpan(
                        text:
                            '\uC5EC\uD589 \uC9C4\uD589\uB960 ', // 여행 진행률
                      ),
                      TextSpan(
                        text: '$percentText%',
                        style: const TextStyle(
                          color: AppColors.primaryTeal,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      TextSpan(
                        text:
                            ' ($completedCount/$totalCount \uC77C\uC815 \uC644\uB8CC)', // 일정 완료
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          // 진행률 바
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radius4),
            child: LinearProgressIndicator(
              value: percentage.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor:
                  AppColors.primaryTeal.withValues(alpha: 0.1),
              valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.primaryTeal),
            ),
          ),
        ],
      ),
    );
  }
}
