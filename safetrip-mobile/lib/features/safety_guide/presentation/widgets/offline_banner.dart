import 'package:flutter/material.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

/// 오프라인 / 캐시 데이터 배너 (DOC-T3-SFG-021 §8.3, §6.1)
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({
    super.key,
    this.lastSyncTime,
    this.isStale = false,
  });

  final DateTime? lastSyncTime;
  final bool isStale;

  String _formatTime() {
    if (lastSyncTime == null) return '--';
    final m = lastSyncTime!.month.toString().padLeft(2, '0');
    final d = lastSyncTime!.day.toString().padLeft(2, '0');
    final h = lastSyncTime!.hour.toString().padLeft(2, '0');
    final min = lastSyncTime!.minute.toString().padLeft(2, '0');
    return '$m/$d $h:$min';
  }

  @override
  Widget build(BuildContext context) {
    final message = isStale
        ? '데이터가 최신이 아닐 수 있습니다 (최종 갱신: ${_formatTime()})'
        : '오프라인 -- 저장된 데이터를 표시합니다 (최종 갱신: ${_formatTime()})';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(AppSpacing.radius8),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Row(
        children: [
          Icon(
            isStale ? Icons.update : Icons.wifi_off,
            size: 16,
            color: Colors.amber.shade800,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: AppTypography.labelSmall.copyWith(
                color: Colors.amber.shade900,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
