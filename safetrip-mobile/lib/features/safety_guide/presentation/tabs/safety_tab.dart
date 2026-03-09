import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../providers/safety_guide_providers.dart';
import '../widgets/travel_alert_badge.dart';

/// 안전 탭 (DOC-T3-SFG-021 §3.2.2)
/// 여행경보, 치안현황, 최근 공지(최대 5개), 지역별 경보
/// CRITICAL: travelAlertLevel == 4 -> 여행금지 빨간 배너 표시 (§6.1)
class SafetyTab extends ConsumerWidget {
  const SafetyTab({super.key, required this.scrollController});

  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final guideState = ref.watch(safetyGuideProvider);

    if (guideState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final safety = guideState.data?.safety;
    if (safety == null) {
      return _buildEmptyState();
    }

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        // CRITICAL: 4단계 여행금지 경고 배너 (§6.1)
        if (safety.travelAlertLevel == 4) _buildTravelBanWarning(),

        // 여행경보 섹션
        _buildSectionTitle(Icons.shield_outlined, '여행경보'),
        const SizedBox(height: AppSpacing.sm),
        if (safety.travelAlertLevel != null) ...[
          TravelAlertBadge(level: safety.travelAlertLevel!),
          const SizedBox(height: AppSpacing.sm),
        ],
        if (safety.travelAlertDescription != null)
          _buildContentCard(safety.travelAlertDescription!),
        const SizedBox(height: AppSpacing.lg),

        // 치안현황 섹션
        _buildSectionTitle(Icons.security, '치안현황'),
        const SizedBox(height: AppSpacing.sm),
        if (safety.securityStatus != null)
          _buildContentCard(safety.securityStatus!)
        else
          _buildNoDataCard('치안현황'),
        const SizedBox(height: AppSpacing.lg),

        // 최근 공지 섹션 (최대 5개)
        _buildSectionTitle(Icons.notifications_outlined, '최근 공지'),
        const SizedBox(height: AppSpacing.sm),
        if (safety.recentNotices.isEmpty)
          _buildNoDataCard('최근 공지')
        else
          ...safety.recentNotices.take(5).map(_buildNoticeCard),
        const SizedBox(height: AppSpacing.lg),

        // 지역별 경보
        if (safety.regionalAlerts.isNotEmpty) ...[
          _buildSectionTitle(Icons.map_outlined, '지역별 경보'),
          const SizedBox(height: AppSpacing.sm),
          ...safety.regionalAlerts.map(_buildRegionalAlertCard),
        ],
      ],
    );
  }

  /// §6.1: 4단계 여행금지 빨간 배너
  Widget _buildTravelBanWarning() {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: const Color(0xFFF44336).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppSpacing.radius8),
          border: Border.all(
            color: const Color(0xFFF44336),
            width: 1.5,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.dangerous,
              color: Color(0xFFF44336),
              size: 24,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                '외교부에서 여행금지를 권고하는 국가입니다. '
                '방문이 불가피한 경우 영사 확인서를 반드시 취득하세요.',
                style: AppTypography.bodyMedium.copyWith(
                  color: const Color(0xFFC62828),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primaryTeal),
        const SizedBox(width: AppSpacing.sm),
        Text(title, style: AppTypography.titleMedium),
      ],
    );
  }

  Widget _buildContentCard(String content) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppSpacing.radius8),
      ),
      child: Text(
        content,
        style: AppTypography.bodyMedium,
      ),
    );
  }

  Widget _buildNoticeCard(dynamic notice) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(AppSpacing.radius8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    notice.title ?? '제목 없음',
                    style: AppTypography.labelMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (notice.publishedAt != null)
                  Text(
                    notice.publishedAt!,
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
              ],
            ),
            if (notice.content != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                notice.content!,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRegionalAlertCard(dynamic alert) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(AppSpacing.radius8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (alert.alertLevel != null) ...[
              TravelAlertBadge(level: alert.alertLevel!),
              const SizedBox(width: AppSpacing.sm),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    alert.region ?? '지역 미상',
                    style: AppTypography.labelMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (alert.description != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      alert.description!,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoDataCard(String sectionName) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppSpacing.radius8),
      ),
      child: Text(
        '$sectionName 정보를 불러오지 못했습니다',
        style: AppTypography.bodySmall.copyWith(
          color: AppColors.textTertiary,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.shield_outlined,
              size: 48,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              '안전 정보를 불러오지 못했습니다',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
