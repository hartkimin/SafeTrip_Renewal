import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_spacing.dart';

/// 오프라인 배지 (§12.1)
/// 네트워크 연결 끊김 시 카드 상단에 표시
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key, this.lastSyncTime});

  final DateTime? lastSyncTime;

  @override
  Widget build(BuildContext context) {
    final syncText = lastSyncTime != null
        ? '마지막 동기화: ${DateFormat('HH:mm').format(lastSyncTime!)}'
        : '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.textTertiary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppSpacing.radius4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off, size: 14, color: AppColors.textTertiary),
          const SizedBox(width: 4),
          Text(
            '오프라인 $syncText',
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}
