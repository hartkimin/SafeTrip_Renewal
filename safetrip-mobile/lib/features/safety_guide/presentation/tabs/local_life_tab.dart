import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../providers/safety_guide_providers.dart';

/// 현지생활 탭 (DOC-T3-SFG-021 §3.2.6)
/// 교통, SIM 카드, 팁 문화, 전압, 물가, 문화 참고사항
class LocalLifeTab extends ConsumerWidget {
  const LocalLifeTab({super.key, required this.scrollController});

  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final guideState = ref.watch(safetyGuideProvider);

    if (guideState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final localLife = guideState.data?.localLife;
    if (localLife == null) {
      return _buildEmptyState();
    }

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        // 교통
        _buildInfoItem(
          icon: Icons.directions_bus_outlined,
          title: '교통',
          content: localLife.transport,
        ),
        const SizedBox(height: AppSpacing.sm),

        // SIM 카드
        _buildInfoItem(
          icon: Icons.sim_card_outlined,
          title: 'SIM 카드 / 통신',
          content: localLife.simCard,
        ),
        const SizedBox(height: AppSpacing.sm),

        // 팁 문화
        _buildInfoItem(
          icon: Icons.payments_outlined,
          title: '팁 문화',
          content: localLife.tippingCulture,
        ),
        const SizedBox(height: AppSpacing.sm),

        // 전압
        _buildInfoItem(
          icon: Icons.electrical_services_outlined,
          title: '전압 / 플러그',
          content: localLife.voltage,
        ),
        const SizedBox(height: AppSpacing.sm),

        // 물가 참고
        _buildInfoItem(
          icon: Icons.attach_money,
          title: '물가 참고',
          content: localLife.costReference,
        ),
        const SizedBox(height: AppSpacing.sm),

        // 문화 참고사항
        _buildInfoItem(
          icon: Icons.temple_buddhist_outlined,
          title: '문화 참고사항',
          content: localLife.culturalNotes,
        ),
      ],
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String title,
    String? content,
  }) {
    return Container(
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
              Icon(icon, size: 20, color: AppColors.primaryTeal),
              const SizedBox(width: AppSpacing.sm),
              Text(
                title,
                style: AppTypography.labelMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            content ?? '정보를 불러오지 못했습니다',
            style: AppTypography.bodyMedium.copyWith(
              color: content != null
                  ? AppColors.textPrimary
                  : AppColors.textTertiary,
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
            const Icon(
              Icons.location_city_outlined,
              size: 48,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              '현지생활 정보를 불러오지 못했습니다',
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
