import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// 과금 인라인 배너 (화면구성원칙 §8)
///
/// "유료 가디언 N명 연결 중" 등 현재 유료 사용 상태를 인라인으로 표시한다.
class PaywallBanner extends StatelessWidget {
  const PaywallBanner({
    super.key,
    required this.message,
    this.onTap,
  });

  /// 표시 메시지 (예: '유료 가디언 2명 연결 중')
  final String message;

  /// 탭 시 상세 과금 정보 모달 오픈
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.primaryTeal.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppSpacing.radius8),
          border: Border.all(
            color: AppColors.primaryTeal.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.workspace_premium,
              size: 16,
              color: AppColors.primaryTeal,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                message,
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.primaryTeal,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (onTap != null)
              const Icon(
                Icons.chevron_right,
                size: 16,
                color: AppColors.primaryTeal,
              ),
          ],
        ),
      ),
    );
  }
}
