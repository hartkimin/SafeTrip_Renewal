import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../features/main/providers/connectivity_provider.dart';

/// 채팅 탭 바텀시트 콘텐츠 (화면구성원칙 §4 탭 3)
///
/// 채팅 기능 스켈레톤. 향후 실시간 채팅 구현 예정.
/// DOC-T2-OFL-016 §8.2 — 오프라인 시 "전송 대기 중" 인디케이터 표시.
class BottomSheetChat extends ConsumerWidget {
  const BottomSheetChat({
    super.key,
    required this.scrollController,
  });

  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final networkStatus = ref.watch(networkStateProvider);
    final isOffline = !networkStatus.isOnline;

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        // §8.2 — 오프라인 배너: 메시지 전송 대기 안내
        if (isOffline) _buildOfflineBanner(),
        const SizedBox(height: 60),
        Icon(
          Icons.chat_bubble_outline,
          size: 64,
          color: AppColors.textTertiary.withValues(alpha: 0.5),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          '채팅',
          style: AppTypography.titleLarge.copyWith(
            color: AppColors.textPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '그룹 채팅 기능이 준비 중입니다.\n멤버들과 실시간으로 소통할 수 있습니다.',
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textTertiary,
          ),
          textAlign: TextAlign.center,
        ),
        // §8.2 — 오프라인 시 대기 중 메시지 예시 (향후 실제 큐 연동)
        if (isOffline) ...[
          const SizedBox(height: AppSpacing.xl),
          _buildQueuedMessageHint(),
        ],
      ],
    );
  }

  /// §8.2 — 오프라인 상태 배너: 메시지가 연결 복구 후 전송됨을 안내.
  Widget _buildOfflineBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(AppSpacing.radius8),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off, size: 16, color: Colors.orange.shade700),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              '오프라인 — 메시지가 연결 복구 후 전송됩니다',
              style: AppTypography.labelSmall.copyWith(
                color: Colors.orange.shade800,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// §8.2 — 전송 대기 메시지 힌트: 오프라인 시 큐에 쌓인 메시지 아이콘 안내.
  Widget _buildQueuedMessageHint() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppSpacing.radius8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.schedule,
            size: 18,
            color: Colors.orange.shade600,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              '전송 대기 중 — 연결되면 자동 전송됩니다',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
