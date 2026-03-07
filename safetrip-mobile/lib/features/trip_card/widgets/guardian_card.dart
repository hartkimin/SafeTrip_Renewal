import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../models/trip_card_data.dart';
import 'privacy_badge.dart';

/// 가디언 카드 (§05, C5)
/// 무료/유료/전체 가디언에 따라 표시 정보가 다르다.
class GuardianCardWidget extends StatelessWidget {
  const GuardianCardWidget({super.key, required this.data, this.onTap});

  final GuardianTripCard data;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(AppSpacing.radius12),
          border: Border.all(color: AppColors.guardian.withValues(alpha: 0.3)),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1행: [가디언] + 멤버 이름/여행명 + 상태 + [상세보기]
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.guardian.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    data.isFullGuardian
                        ? '전체 가디언'
                        : (data.isPaid ? '유료 가디언' : '가디언'),
                    style: const TextStyle(
                      color: AppColors.guardian,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    data.isFullGuardian
                        ? data.tripName
                        : '${data.memberName ?? ''}의 여행',
                    style: AppTypography.titleMedium.copyWith(fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  data.status == 'active' ? '여행 중' : '예정',
                  style: AppTypography.labelSmall.copyWith(
                    color: data.status == 'active'
                        ? AppColors.tripActive
                        : AppColors.tripPlanning,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                // 유료 가디언: 프라이버시 배지 (§05.3)
                if (data.isPaid && data.privacyLevel != null) ...[
                  const SizedBox(width: 6),
                  PrivacyBadge(level: data.privacyLevel!),
                ],
              ],
            ),
            const SizedBox(height: 4),
            // 2행: 날짜
            Text(
              '\u{1F4C5} ${_formatDate(data.startDate)} ~ ${_formatDate(data.endDate)}',
              style:
                  AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 4),
            // 3행: 상태 정보
            Text(
              _statusLine(),
              style: AppTypography.labelSmall
                  .copyWith(color: AppColors.textTertiary),
            ),
            // 유료 가디언: 오늘 일정 (§05.3)
            if (data.isPaid && data.todayScheduleSummary != null) ...[
              const SizedBox(height: 4),
              Text(
                '오늘: ${data.todayScheduleSummary}',
                style: AppTypography.labelSmall
                    .copyWith(color: AppColors.textSecondary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            // 무료 가디언: 유료 전환 유도 (§05.2, P1-3)
            if (data.isFreeGuardian && !data.isFullGuardian) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.secondaryAmber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSpacing.radius8),
                ),
                child: Column(
                  children: [
                    Text(
                      '유료 가디언으로 전환하면 일정 요약, 프라이버시 등급 정보를 추가로 확인할 수 있습니다.',
                      style: AppTypography.bodySmall
                          .copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 4),
                    TextButton(
                      onPressed: () {
                        // TODO: 유료 전환 플로우
                      },
                      child: const Text('유료로 전환 (1,900원/여행)'),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _statusLine() {
    if (data.isFullGuardian) {
      return '전체 멤버 위치 공유 현황 확인';
    }
    return '현재 상태: ${data.locationSharingStatus ? '위치 공유 중' : '위치 비공유'}';
  }

  String _formatDate(DateTime d) =>
      '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';
}
