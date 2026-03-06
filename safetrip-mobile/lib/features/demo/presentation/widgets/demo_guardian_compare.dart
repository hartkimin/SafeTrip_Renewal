import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../models/demo_scenario.dart';
import '../../providers/demo_state_provider.dart';

/// §3.3: 가디언 무료/유료 비교 뷰 — 캡틴 역할일 때만 표시
class DemoGuardianCompare extends ConsumerWidget {
  const DemoGuardianCompare({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const DemoGuardianCompare(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final demoState = ref.watch(demoStateProvider);

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
                '가디언 서비스 비교',
                style: AppTypography.titleLarge
                    .copyWith(color: AppColors.textPrimary),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '무료 가디언과 유료 가디언의 차이를 비교해 보세요',
                style: AppTypography.bodyMedium
                    .copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Comparison cards side by side
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Free tier
                  Expanded(
                    child: _TierCard(
                      title: '무료 가디언',
                      price: '무료',
                      priceSubtext: '최대 2명',
                      color: AppColors.textTertiary,
                      features: const [
                        _Feature('당일 위치 확인', true),
                        _Feature('기본 알림', true),
                        _Feature('24시간 이력', true),
                        _Feature('전체 이동기록', false),
                        _Feature('확장 알림', false),
                        _Feature('히스토리 분석', false),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  // Paid tier
                  Expanded(
                    child: _TierCard(
                      title: '유료 가디언',
                      price: '₩1,900',
                      priceSubtext: '/여행 (3~5번째)',
                      color: AppColors.primaryTeal,
                      isHighlighted: true,
                      features: const [
                        _Feature('당일 위치 확인', true),
                        _Feature('기본 알림', true),
                        _Feature('24시간 이력', true),
                        _Feature('전체 이동기록', true),
                        _Feature('확장 알림', true),
                        _Feature('히스토리 분석', true),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              // Upgrade CTA
              if (!demoState.isGuardianUpgraded) ...[
                SizedBox(
                  width: double.infinity,
                  height: AppSpacing.buttonHeight,
                  child: ElevatedButton(
                    onPressed: () => _showUpgradeDialog(context, ref),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryTeal,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radius12),
                      ),
                    ),
                    child: Text(
                      '업그레이드 체험하기',
                      style: AppTypography.labelLarge.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.semanticSuccess.withValues(alpha: 0.1),
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radius12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_circle,
                          color: AppColors.semanticSuccess, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        '유료 가디언 체험 중',
                        style: AppTypography.labelMedium.copyWith(
                          color: AppColors.semanticSuccess,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }

  void _showUpgradeDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('유료 가디언 체험'),
        content: const Text(
          '실제 앱에서는 가디언 추가 시 1,900원/여행의 결제가 필요합니다.\n\n'
          '데모에서는 결제 없이 유료 기능을 체험해 보실 수 있습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(demoStateProvider.notifier).toggleGuardianUpgrade();
              Navigator.pop(ctx);
            },
            child: const Text('계속 체험하기'),
          ),
        ],
      ),
    );
  }
}

class _Feature {
  const _Feature(this.label, this.included);
  final String label;
  final bool included;
}

class _TierCard extends StatelessWidget {
  const _TierCard({
    required this.title,
    required this.price,
    required this.priceSubtext,
    required this.color,
    required this.features,
    this.isHighlighted = false,
  });

  final String title;
  final String price;
  final String priceSubtext;
  final Color color;
  final List<_Feature> features;
  final bool isHighlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isHighlighted
            ? color.withValues(alpha: 0.05)
            : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppSpacing.radius12),
        border: isHighlighted
            ? Border.all(color: color, width: 1.5)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.labelMedium.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            price,
            style: AppTypography.titleLarge.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            priceSubtext,
            style: AppTypography.bodySmall
                .copyWith(color: AppColors.textTertiary),
          ),
          const SizedBox(height: 12),
          ...features.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(
                      f.included
                          ? Icons.check_circle
                          : Icons.cancel,
                      size: 14,
                      color: f.included
                          ? AppColors.semanticSuccess
                          : AppColors.textDisabled,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        f.label,
                        style: AppTypography.bodySmall.copyWith(
                          color: f.included
                              ? AppColors.textPrimary
                              : AppColors.textDisabled,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
