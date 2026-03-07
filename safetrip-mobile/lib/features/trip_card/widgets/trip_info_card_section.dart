import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../models/trip_card_data.dart';
import '../providers/trip_card_provider.dart';
import 'member_trip_card.dart';
import 'guardian_card.dart';
import 'no_trip_cta.dart';
import 'offline_banner.dart';
import 'trip_switch_bottom_sheet.dart';

/// 여행정보카드 최상위 컨테이너 (DOC-T3-TIC-024)
///
/// TripCardProvider의 상태를 watch하여:
/// - 멤버 여행 카드 (상태별 strategy)
/// - 가디언 여행 카드 (분리 섹션, C5)
/// - 탐색 모드 CTA (여행 없음)
/// - 오프라인 배지 (§12)
/// - 복수 active 경고 (P2-4)
/// 를 렌더링한다.
class TripInfoCardSection extends ConsumerStatefulWidget {
  const TripInfoCardSection({super.key});

  @override
  ConsumerState<TripInfoCardSection> createState() =>
      _TripInfoCardSectionState();
}

class _TripInfoCardSectionState extends ConsumerState<TripInfoCardSection> {
  @override
  void initState() {
    super.initState();
    // 최초 로드
    Future.microtask(() => ref.read(tripCardProvider.notifier).fetchCardView());
  }

  @override
  Widget build(BuildContext context) {
    final cardState = ref.watch(tripCardProvider);
    final data = cardState.data;

    // 로딩 중: 스켈레톤 (§10.1)
    if (cardState.isLoading && data.isEmpty) {
      return _buildSkeleton();
    }

    // 여행 없음: 탐색 모드 CTA (§04.4)
    if (data.isEmpty) {
      return const NoTripCta();
    }

    final primary = data.primaryTrip;
    final hasMultipleTrips =
        data.memberTrips.length + data.guardianTrips.length > 1;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 오프라인 배지 (§12, P1-4)
        if (cardState.isOffline)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: OfflineBanner(lastSyncTime: cardState.lastSyncTime),
          ),

        // 복수 active 경고 (P2-4)
        if (data.activeCount >= 2)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.semanticWarning.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.warning_amber,
                      size: 14, color: AppColors.semanticWarning),
                  const SizedBox(width: 4),
                  Text(
                    '진행 중인 여행 ${data.activeCount}개',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.semanticWarning,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // 메인 카드 (C1: 여행 컨텍스트 최우선)
        if (primary != null)
          MemberTripCardWidget(
            data: primary,
            showSwitchButton: hasMultipleTrips,
            onSwitch: () => _showSwitchSheet(data),
            onReactivate: primary.canReactivate
                ? () => _handleReactivate(primary.tripId)
                : null,
            onTap: () {
              // C4: 1터치 진입 — 이미 메인 화면에 있으므로 tripProvider 갱신
              // TODO: tripProvider와 연동하여 선택된 여행 컨텍스트 전환
            },
          ),

        // 가디언 여행 섹션 (C5: 분리 표시, P1-1)
        if (data.guardianTrips.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '가디언으로 참여 중인 여행',
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.textTertiary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          ...data.guardianTrips.map((g) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: GuardianCardWidget(data: g),
              )),
        ],
      ],
    );
  }

  Widget _buildSkeleton() {
    return Container(
      height: 80,
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(AppSpacing.radius12),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: 12, width: 120, color: AppColors.surfaceVariant),
          const SizedBox(height: 8),
          Container(height: 10, width: 200, color: AppColors.surfaceVariant),
          const SizedBox(height: 8),
          Container(height: 10, width: 150, color: AppColors.surfaceVariant),
        ],
      ),
    );
  }

  void _showSwitchSheet(TripCardViewData data) {
    showTripSwitchSheet(
      context,
      cardData: data,
      onSelect: (tripId) {
        // TODO: tripProvider와 연동하여 선택된 여행으로 컨텍스트 전환
        ref.read(tripCardProvider.notifier).fetchCardView();
      },
    );
  }

  Future<void> _handleReactivate(String tripId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('여행 재활성화'),
        content:
            const Text('이 여행을 다시 활성화하시겠습니까?\n재활성화는 1회만 가능합니다.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('재활성화')),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      final success =
          await ref.read(tripCardProvider.notifier).reactivateTrip(tripId);
      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  ref.read(tripCardProvider).error ?? '재활성화에 실패했습니다.')),
        );
      }
    }
  }
}
