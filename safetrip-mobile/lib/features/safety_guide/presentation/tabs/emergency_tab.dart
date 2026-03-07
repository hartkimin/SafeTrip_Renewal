import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../models/guide_data.dart';
import '../../providers/safety_guide_providers.dart';
import '../widgets/emergency_call_button.dart';

/// 긴급연락 탭 (DOC-T3-SFG-021 §3.2.5)
///
/// **핵심 탭 -- 가장 빠른 접근 보장 (S6: 즉시 행동)**
/// - EmergencyCallButton으로 각 연락처 표시
/// - 표시 순서: 경찰 -> 소방/구급 -> 대사관 -> 영사콜센터
/// - 항상 최소 영사콜센터(하드코딩 폴백) 표시
/// - 긴급연락처는 다른 탭 데이터와 별도로 즉시 로드
class EmergencyTab extends ConsumerWidget {
  const EmergencyTab({super.key, required this.scrollController});

  final ScrollController scrollController;

  /// 연락처 유형 정렬 순서 (경찰 -> 소방 -> 구급차 -> 대사관 -> 영사콜센터 -> 기타)
  static const _typeOrder = {
    'police': 0,
    'fire': 1,
    'ambulance': 2,
    'embassy': 3,
    'consulate_call_center': 4,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final guideState = ref.watch(safetyGuideProvider);

    if (guideState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // 긴급연락처: 데이터 존재 -> 사용, 없으면 -> 하드코딩 폴백
    final emergency =
        guideState.data?.emergency ?? GuideEmergency.fallback();
    final contacts = List<EmergencyContactItem>.from(emergency.contacts);

    // 정렬: 경찰 -> 소방 -> 구급 -> 대사관 -> 영사콜센터 -> 기타
    contacts.sort((a, b) {
      final orderA = _typeOrder[a.contactType] ?? 99;
      final orderB = _typeOrder[b.contactType] ?? 99;
      return orderA.compareTo(orderB);
    });

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        // 안내 헤더
        _buildHeader(),
        const SizedBox(height: AppSpacing.lg),

        // 긴급연락처 버튼 목록
        ...contacts.map(
          (contact) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: EmergencyCallButton(
              phoneNumber: contact.phoneNumber,
              label: contact.typeLabel,
              sublabel: contact.descriptionKo,
              is24h: contact.is24h,
            ),
          ),
        ),

        const SizedBox(height: AppSpacing.lg),

        // 하단 안내문
        _buildFooterNotice(),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFFF44336).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.radius8),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.emergency,
            color: Color(0xFFE53935),
            size: 24,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '긴급연락처',
                  style: AppTypography.titleMedium.copyWith(
                    color: const Color(0xFFC62828),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '전화번호를 탭하면 바로 전화가 연결됩니다',
                  style: AppTypography.bodySmall.copyWith(
                    color: const Color(0xFFE53935),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterNotice() {
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
              Icon(
                Icons.info_outline,
                size: 16,
                color: AppColors.textTertiary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                '참고사항',
                style: AppTypography.labelMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '- 영사콜센터(+82-2-3210-0404)는 24시간 운영됩니다\n'
            '- 현지 긴급번호는 국가별로 다를 수 있습니다\n'
            '- 오프라인에서도 저장된 연락처를 확인할 수 있습니다',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textTertiary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
