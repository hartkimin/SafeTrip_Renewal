import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// 과금 모달 재사용 컴포넌트 (화면구성원칙 §8)
///
/// 유료 기능(추가 가디언 등)의 결제를 유도하는 바텀시트 모달.
class PaywallModal {
  PaywallModal._();

  /// 과금 모달을 표시한다.
  ///
  /// [title]: 모달 제목 (예: '추가 가디언 연결')
  /// [description]: 설명 메시지
  /// [priceLabel]: 가격 표시 (예: '월 1,900원/명')
  /// [onConfirm]: 결제 확인 콜백
  static Future<void> show({
    required BuildContext context,
    required String title,
    required String description,
    required String priceLabel,
    required VoidCallback onConfirm,
    String confirmLabel = '결제하고 연결',
    String cancelLabel = '취소',
    String? warningText,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PaywallContent(
        title: title,
        description: description,
        priceLabel: priceLabel,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        warningText: warningText ?? '결제 즉시 적용되며, 환불이 불가합니다.',
        onConfirm: () {
          Navigator.pop(ctx);
          onConfirm();
        },
      ),
    );
  }
}

class _PaywallContent extends StatelessWidget {
  const _PaywallContent({
    required this.title,
    required this.description,
    required this.priceLabel,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.warningText,
    required this.onConfirm,
  });

  final String title;
  final String description;
  final String priceLabel;
  final String confirmLabel;
  final String cancelLabel;
  final String warningText;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radius24),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 핸들
          Container(width: 40, height: 4, color: AppColors.outline),
          const SizedBox(height: AppSpacing.lg),

          // 제목
          Text(title, style: AppTypography.titleLarge),
          const SizedBox(height: AppSpacing.md),

          // 설명
          Text(description, style: AppTypography.bodyMedium),
          const SizedBox(height: AppSpacing.xl),

          // 가격 카드
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primaryTeal),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(title, style: AppTypography.titleMedium),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    priceLabel,
                    style: AppTypography.titleLarge.copyWith(
                      color: AppColors.primaryTeal,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  warningText,
                  style: const TextStyle(
                    color: AppColors.sosDanger,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          // 버튼 Row
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(cancelLabel),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: ElevatedButton(
                  onPressed: onConfirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryTeal,
                  ),
                  child: Text(
                    confirmLabel,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}
