import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../features/main/providers/connectivity_provider.dart';

/// 안전가이드 탭 바텀시트 콘텐츠 (화면구성원칙 §4 탭 4)
///
/// 긴급연락처·대사관 정보·현지 안전 가이드 스켈레톤.
/// DOC-T2-OFL-016 §8.2 — 오프라인 시 "캐시 데이터 기준" 배너 표시.
class BottomSheetGuide extends ConsumerWidget {
  const BottomSheetGuide({
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
        // §8.2 — 오프라인 캐시 데이터 배너
        if (isOffline)
          _buildCacheBanner(lastSyncTime: networkStatus.lastSyncTime),
        // 긴급연락처 섹션
        _buildSection(
          icon: Icons.emergency_outlined,
          title: '긴급연락처',
          items: const [
            _GuideItem('경찰', '현지 경찰 번호'),
            _GuideItem('소방서', '현지 소방서 번호'),
            _GuideItem('구급차', '현지 구급차 번호'),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        // 대사관 정보 섹션
        _buildSection(
          icon: Icons.account_balance_outlined,
          title: '대사관 정보',
          items: const [
            _GuideItem('대한민국 대사관', '주소 및 연락처 로딩 중...'),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        // 현지 안전 정보 섹션
        _buildSection(
          icon: Icons.shield_outlined,
          title: '현지 안전 정보',
          items: const [
            _GuideItem('여행 경보 단계', '정보를 불러오는 중...'),
            _GuideItem('현지 주의사항', '정보를 불러오는 중...'),
          ],
        ),
      ],
    );
  }

  /// §8.2 — 캐시 데이터 안내 배너 (amber 배경).
  Widget _buildCacheBanner({DateTime? lastSyncTime}) {
    final dateLabel = _formatDate(lastSyncTime);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Container(
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
            Icon(Icons.cached, size: 16, color: Colors.amber.shade800),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                '캐시 데이터 ($dateLabel 기준)',
                style: AppTypography.labelSmall.copyWith(
                  color: Colors.amber.shade900,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Format [DateTime] to 'MM/DD HH:MM', or '--' if null.
  static String _formatDate(DateTime? dateTime) {
    if (dateTime == null) return '--';
    final m = dateTime.month.toString().padLeft(2, '0');
    final d = dateTime.day.toString().padLeft(2, '0');
    final h = dateTime.hour.toString().padLeft(2, '0');
    final min = dateTime.minute.toString().padLeft(2, '0');
    return '$m/$d $h:$min';
  }

  Widget _buildSection({
    required IconData icon,
    required String title,
    required List<_GuideItem> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: AppColors.primaryTeal),
            const SizedBox(width: AppSpacing.sm),
            Text(title, style: AppTypography.titleMedium),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        ...items.map(
          (item) => Padding(
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
                  Text(
                    item.title,
                    style: AppTypography.labelMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.subtitle,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GuideItem {
  const _GuideItem(this.title, this.subtitle);
  final String title;
  final String subtitle;
}
