import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/demo_analytics.dart';
import '../../models/demo_scenario.dart';
import '../../providers/demo_state_provider.dart';

/// §3.5: 등급 비교 체험 패널
/// 3개 프라이버시 등급 전환 + 차이 시각화 (5행)
class DemoGradeCompare extends ConsumerWidget {
  const DemoGradeCompare({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const DemoGradeCompare(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final demoState = ref.watch(demoStateProvider);
    final currentGrade = demoState.currentGrade;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radius20),
        ),
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              Text(
                '프라이버시 등급 비교',
                style: AppTypography.titleLarge
                    .copyWith(color: AppColors.textPrimary),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '등급을 바꾸면 위치 공유와 가디언 공유 방식이 달라집니다',
                style: AppTypography.bodyMedium
                    .copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),

              // 3-tab toggle
              Row(
                children: DemoPrivacyGrade.values.map((grade) {
                  final isSelected = grade == currentGrade;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        ref.read(demoStateProvider.notifier).switchGrade(grade);
                        DemoAnalytics.gradeSwitched(_gradeName(grade));
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? _gradeColor(grade).withValues(alpha: 0.12)
                              : AppColors.surfaceVariant,
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radius8),
                          border: isSelected
                              ? Border.all(color: _gradeColor(grade), width: 1.5)
                              : null,
                        ),
                        child: Text(
                          _gradeLabel(grade),
                          style: AppTypography.labelSmall.copyWith(
                            color: isSelected
                                ? _gradeColor(grade)
                                : AppColors.textSecondary,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w400,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: AppSpacing.lg),

              // 5 comparison rows from §3.5
              _ComparisonRow(
                label: '위치 공유 범위',
                values: const ['24시간 실시간', '24시간\n(OFF시 저빈도)', '일정 연동\n시간대만'],
                currentGrade: currentGrade,
              ),
              _ComparisonRow(
                label: '가디언 공유',
                values: const ['항상 공유', '항상\n(OFF시 30분 스냅샷)', '스케줄 OFF\n비공유'],
                currentGrade: currentGrade,
              ),
              _ComparisonRow(
                label: '마커 표시',
                values: const ['실시간 갱신', '실시간 갱신', '체크포인트만\n핀 표시'],
                currentGrade: currentGrade,
              ),
              _ComparisonRow(
                label: '가디언 일시 중지',
                values: const ['불가', '최대 12시간', '최대 24시간'],
                currentGrade: currentGrade,
              ),
              _ComparisonRow(
                label: '지오펜스→가디언',
                values: const ['항상 전달', '스케줄 ON\n시만', '전달 안 함'],
                currentGrade: currentGrade,
              ),

              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }

  static String _gradeLabel(DemoPrivacyGrade grade) {
    switch (grade) {
      case DemoPrivacyGrade.safetyFirst:
        return '안전 최우선';
      case DemoPrivacyGrade.standard:
        return '표준';
      case DemoPrivacyGrade.privacyFirst:
        return '프라이버시\n우선';
    }
  }

  static String _gradeName(DemoPrivacyGrade grade) {
    switch (grade) {
      case DemoPrivacyGrade.safetyFirst:
        return 'safety_first';
      case DemoPrivacyGrade.standard:
        return 'standard';
      case DemoPrivacyGrade.privacyFirst:
        return 'privacy_first';
    }
  }

  static Color _gradeColor(DemoPrivacyGrade grade) {
    switch (grade) {
      case DemoPrivacyGrade.safetyFirst:
        return AppColors.privacySafetyFirst;
      case DemoPrivacyGrade.standard:
        return AppColors.privacyStandard;
      case DemoPrivacyGrade.privacyFirst:
        return AppColors.privacyFirst;
    }
  }
}

class _ComparisonRow extends StatelessWidget {
  const _ComparisonRow({
    required this.label,
    required this.values,
    required this.currentGrade,
  });

  final String label;
  final List<String> values; // [safetyFirst, standard, privacyFirst]
  final DemoPrivacyGrade currentGrade;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(AppSpacing.radius8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.textTertiary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              values[currentGrade.index],
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
