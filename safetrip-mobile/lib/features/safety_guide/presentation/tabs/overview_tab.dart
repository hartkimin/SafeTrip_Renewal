import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../providers/safety_guide_providers.dart';
import '../widgets/travel_alert_badge.dart';

/// 개요 탭 (DOC-T3-SFG-021 §3.2.1)
/// 국가 기본 정보: 국기, 이름, 여행경보, 수도, 통화, 언어, 시간대
class OverviewTab extends ConsumerWidget {
  const OverviewTab({super.key, required this.scrollController});

  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final guideState = ref.watch(safetyGuideProvider);

    if (guideState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final overview = guideState.data?.overview;
    if (overview == null) {
      return _buildEmptyState();
    }

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        // 국기 + 국가명 헤더
        _buildCountryHeader(overview),
        const SizedBox(height: AppSpacing.lg),

        // 여행경보 배지
        if (overview.travelAlertLevel != null) ...[
          TravelAlertBadge(level: overview.travelAlertLevel!),
          const SizedBox(height: AppSpacing.lg),
        ],

        // 기본 정보 카드들
        _buildInfoCard(
          icon: Icons.location_city,
          label: '수도',
          value: overview.capital,
        ),
        const SizedBox(height: AppSpacing.sm),
        _buildInfoCard(
          icon: Icons.monetization_on_outlined,
          label: '통화',
          value: overview.currency,
        ),
        const SizedBox(height: AppSpacing.sm),
        _buildInfoCard(
          icon: Icons.translate,
          label: '공용어',
          value: overview.language,
        ),
        const SizedBox(height: AppSpacing.sm),
        _buildInfoCard(
          icon: Icons.access_time,
          label: '시간대',
          value: overview.timezone,
        ),
      ],
    );
  }

  Widget _buildCountryHeader(dynamic overview) {
    return Row(
      children: [
        if (overview.flagEmoji != null)
          Text(
            overview.flagEmoji!,
            style: const TextStyle(fontSize: 40),
          ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                overview.countryNameKo ?? overview.countryCode,
                style: AppTypography.titleLarge,
              ),
              if (overview.countryNameEn != null)
                Text(
                  overview.countryNameEn!,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    String? value,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppSpacing.radius8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primaryTeal),
          const SizedBox(width: AppSpacing.md),
          Text(
            label,
            style: AppTypography.labelMedium.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value ?? '정보 없음',
              style: AppTypography.bodyMedium.copyWith(
                color: value != null
                    ? AppColors.textPrimary
                    : AppColors.textTertiary,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
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
            Icon(
              Icons.info_outline,
              size: 48,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              '정보를 불러오지 못했습니다',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '국가를 선택하거나 네트워크 연결을 확인해 주세요',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textTertiary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
