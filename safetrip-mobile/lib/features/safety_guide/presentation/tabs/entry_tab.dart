import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../providers/safety_guide_providers.dart';

/// 입국 탭 (DOC-T3-SFG-021 §3.2.4)
/// 비자 요건, 필요 서류(체크리스트), 세관 안내, 여권 유효기간
class EntryTab extends ConsumerWidget {
  const EntryTab({super.key, required this.scrollController});

  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final guideState = ref.watch(safetyGuideProvider);

    if (guideState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final entry = guideState.data?.entry;
    if (entry == null) {
      return _buildEmptyState();
    }

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        // 비자 요건
        _buildSectionTitle(Icons.article_outlined, '비자 요건'),
        const SizedBox(height: AppSpacing.sm),
        if (entry.visaRequirement != null)
          _buildContentCard(entry.visaRequirement!)
        else
          _buildNoDataCard('비자 요건'),
        const SizedBox(height: AppSpacing.lg),

        // 여권 유효기간
        _buildSectionTitle(Icons.badge_outlined, '여권 유효기간'),
        const SizedBox(height: AppSpacing.sm),
        if (entry.passportValidity != null)
          _buildContentCard(entry.passportValidity!)
        else
          _buildNoDataCard('여권 유효기간'),
        const SizedBox(height: AppSpacing.lg),

        // 필요 서류 체크리스트
        _buildSectionTitle(Icons.checklist_outlined, '필요 서류'),
        const SizedBox(height: AppSpacing.sm),
        if (entry.requiredDocuments.isEmpty)
          _buildNoDataCard('필요 서류')
        else
          _buildDocumentChecklist(entry.requiredDocuments),
        const SizedBox(height: AppSpacing.lg),

        // 세관 안내
        _buildSectionTitle(Icons.inventory_outlined, '세관 안내'),
        const SizedBox(height: AppSpacing.sm),
        if (entry.customsInfo != null)
          _buildContentCard(entry.customsInfo!)
        else
          _buildNoDataCard('세관 안내'),
      ],
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

  /// 서류 체크리스트 (체크마크 포함)
  Widget _buildDocumentChecklist(List<String> documents) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppSpacing.radius8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: documents.map((doc) {
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 18,
                  color: AppColors.semanticSuccess,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    doc,
                    style: AppTypography.bodyMedium,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
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
            Icon(
              Icons.article_outlined,
              size: 48,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              '입국 정보를 불러오지 못했습니다',
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
