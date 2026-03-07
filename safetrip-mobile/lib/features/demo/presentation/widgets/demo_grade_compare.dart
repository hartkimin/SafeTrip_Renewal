import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/demo_analytics.dart';
import '../../models/demo_scenario.dart';
import '../../providers/demo_state_provider.dart';

/// §3.5: 등급 비교 체험 패널 — 3열 나란히 비교 테이블
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
                '등급을 탭하면 위치 공유와 가디언 공유 방식이 변경됩니다',
                style: AppTypography.bodyMedium
                    .copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),

              // 3-column header (§3.5 스펙: 3열 나란히)
              Row(
                children: [
                  const SizedBox(width: 80), // 항목명 컬럼 너비
                  ...DemoPrivacyGrade.values.map((grade) {
                    final isSelected = grade == currentGrade;
                    final color = _gradeColor(grade);
                    return Expanded(
                      child: GestureDetector(
                        onTap: () {
                          ref
                              .read(demoStateProvider.notifier)
                              .switchGrade(grade);
                          DemoAnalytics.gradeSwitched(_gradeName(grade));
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          padding: const EdgeInsets.symmetric(
                              vertical: 8, horizontal: 4),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? color.withValues(alpha: 0.12)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(
                                AppSpacing.radius8),
                            border: isSelected
                                ? Border.all(color: color, width: 1.5)
                                : null,
                          ),
                          child: Column(
                            children: [
                              Text(
                                _gradeLabel(grade),
                                style: AppTypography.labelSmall.copyWith(
                                  color: isSelected
                                      ? color
                                      : AppColors.textSecondary,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w400,
                                  fontSize: 10,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              if (isSelected) ...[
                                const SizedBox(height: 2),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: color,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '현재',
                                    style: AppTypography.labelSmall.copyWith(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),

              // 5 comparison rows — 3열 나란히 (§5 기준)
              _ComparisonRow(
                label: '위치 공유\n범위',
                values: const [
                  '24시간\n실시간',
                  '24시간',
                  '일정 연동\n시간대만',
                ],
                currentGrade: currentGrade,
              ),
              _ComparisonRow(
                label: '가디언\n공유',
                values: const [
                  '항상 공유',
                  'ON시\n실시간',
                  'OFF시\n비공유',
                ],
                currentGrade: currentGrade,
              ),
              _ComparisonRow(
                label: '마커 표시',
                values: const [
                  '실시간\n갱신',
                  '실시간\n갱신',
                  '체크포인트\n만',
                ],
                currentGrade: currentGrade,
              ),
              _ComparisonRow(
                label: '가디언\n일시중지',
                values: const [
                  '불가',
                  '최대\n12시간',
                  '최대\n24시간',
                ],
                currentGrade: currentGrade,
              ),
              _ComparisonRow(
                label: '지오펜스\n→가디언',
                values: const [
                  '항상',
                  'ON시만',
                  '전달\n안 함',
                ],
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
        return '안전\n최우선';
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

/// 3열 비교 행: 항목명 + 3등급 값을 나란히 표시
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
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          // 항목명 컬럼
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.textTertiary,
                fontWeight: FontWeight.w600,
                fontSize: 10,
              ),
            ),
          ),
          // 3열 값
          ...List.generate(3, (index) {
            final grade = DemoPrivacyGrade.values[index];
            final isSelected = grade == currentGrade;
            return Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                decoration: BoxDecoration(
                  color: isSelected
                      ? DemoGradeCompare._gradeColor(grade)
                          .withValues(alpha: 0.08)
                      : AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  values[index],
                  style: AppTypography.bodySmall.copyWith(
                    color: isSelected
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.w400,
                    fontSize: 11,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
