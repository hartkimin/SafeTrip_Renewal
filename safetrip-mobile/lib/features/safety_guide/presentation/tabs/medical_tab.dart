import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../providers/safety_guide_providers.dart';

/// 의료 탭 (DOC-T3-SFG-021 §3.2.3)
/// 병원 목록, 보험 안내, 약국 정보, 긴급의료 가이드
class MedicalTab extends ConsumerWidget {
  const MedicalTab({super.key, required this.scrollController});

  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final guideState = ref.watch(safetyGuideProvider);

    if (guideState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final medical = guideState.data?.medical;
    if (medical == null) {
      return _buildEmptyState();
    }

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        // 긴급의료 가이드
        _buildSectionTitle(Icons.medical_services_outlined, '긴급의료 가이드'),
        const SizedBox(height: AppSpacing.sm),
        if (medical.emergencyGuide != null)
          _buildContentCard(medical.emergencyGuide!)
        else
          _buildNoDataCard('긴급의료 가이드'),
        const SizedBox(height: AppSpacing.lg),

        // 병원 목록
        _buildSectionTitle(Icons.local_hospital_outlined, '주요 병원'),
        const SizedBox(height: AppSpacing.sm),
        if (medical.hospitals.isEmpty)
          _buildNoDataCard('병원 목록')
        else
          ...medical.hospitals.map(_buildHospitalCard),
        const SizedBox(height: AppSpacing.lg),

        // 보험 안내
        _buildSectionTitle(Icons.health_and_safety_outlined, '보험 안내'),
        const SizedBox(height: AppSpacing.sm),
        if (medical.insuranceGuide != null)
          _buildContentCard(medical.insuranceGuide!)
        else
          _buildNoDataCard('보험 안내'),
        const SizedBox(height: AppSpacing.lg),

        // 약국 정보
        _buildSectionTitle(Icons.local_pharmacy_outlined, '약국 정보'),
        const SizedBox(height: AppSpacing.sm),
        if (medical.pharmacyInfo != null)
          _buildContentCard(medical.pharmacyInfo!)
        else
          _buildNoDataCard('약국 정보'),
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

  Widget _buildHospitalCard(Map<String, dynamic> hospital) {
    final name = hospital['name'] as String? ?? '병원명 미상';
    final address = hospital['address'] as String?;
    final phone = hospital['phone'] as String?;
    final notes = hospital['notes'] as String?;

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
            // 병원명
            Text(
              name,
              style: AppTypography.labelMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            // 주소
            if (address != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 14,
                    color: AppColors.textTertiary,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      address,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            // 전화번호
            if (phone != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  Icon(
                    Icons.phone_outlined,
                    size: 14,
                    color: AppColors.textTertiary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    phone,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.primaryTeal,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
            // 참고사항
            if (notes != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                notes,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ],
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
            Icon(
              Icons.medical_services_outlined,
              size: 48,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              '의료 정보를 불러오지 못했습니다',
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
