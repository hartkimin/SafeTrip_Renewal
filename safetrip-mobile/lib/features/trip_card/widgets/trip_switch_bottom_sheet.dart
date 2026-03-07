import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../models/trip_card_data.dart';

/// 여행 전환 바텀시트 (§09, P0-6)
/// 복수 여행 참여 시 전환 목록 표시
class TripSwitchBottomSheet extends StatelessWidget {
  const TripSwitchBottomSheet({
    super.key,
    required this.cardData,
    required this.onSelect,
  });

  final TripCardViewData cardData;
  final void Function(String tripId) onSelect;

  @override
  Widget build(BuildContext context) {
    final active =
        cardData.memberTrips.where((t) => t.status == 'active').toList();
    final planning =
        cardData.memberTrips.where((t) => t.status == 'planning').toList();
    final completed = cardData.memberTrips
        .where((t) => t.status == 'completed')
        .take(5)
        .toList();
    final guardian = cardData.guardianTrips;

    return Container(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppSpacing.radius20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 핸들
          Center(
            child: Container(
              width: AppSpacing.bottomSheetHandleWidth,
              height: AppSpacing.bottomSheetHandleHeight,
              decoration: BoxDecoration(
                color: AppColors.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text('여행 전환', style: AppTypography.titleMedium),
          const SizedBox(height: AppSpacing.md),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                if (active.isNotEmpty) ...[
                  _sectionHeader('진행 중인 여행'),
                  ...active.map((t) => _tripItem(t.tripId, t.tripName,
                      '${t.currentDay ?? 1}일째', AppColors.tripActive)),
                ],
                if (planning.isNotEmpty) ...[
                  _sectionHeader('예정된 여행'),
                  ...planning.map((t) => _tripItem(
                      t.tripId, t.tripName, t.dDayDisplay, AppColors.tripPlanning)),
                ],
                if (guardian.isNotEmpty) ...[
                  _sectionHeader('가디언으로 참여 중'),
                  ...guardian.map((t) => _tripItem(
                        t.tripId,
                        t.isFullGuardian
                            ? t.tripName
                            : '${t.memberName ?? ''}의 여행',
                        t.status == 'active' ? '여행 중' : '예정',
                        AppColors.guardian,
                      )),
                ],
                if (completed.isNotEmpty) ...[
                  _sectionHeader('완료된 여행 (최근 5개)'),
                  ...completed.map((t) => _tripItem(
                      t.tripId, t.tripName, '완료', AppColors.tripCompleted)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding:
          const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.xs),
      child: Text(
        title,
        style: AppTypography.labelSmall.copyWith(
          color: AppColors.textTertiary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _tripItem(String tripId, String name, String badge, Color color) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      title: Text(name, style: AppTypography.bodyMedium),
      trailing: Text(
        badge,
        style: AppTypography.labelSmall
            .copyWith(color: color, fontWeight: FontWeight.w600),
      ),
      onTap: () => onSelect(tripId),
    );
  }
}

/// 바텀시트 표시 헬퍼
void showTripSwitchSheet(
  BuildContext context, {
  required TripCardViewData cardData,
  required void Function(String tripId) onSelect,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => TripSwitchBottomSheet(
      cardData: cardData,
      onSelect: (tripId) {
        Navigator.pop(context);
        onSelect(tripId);
      },
    ),
  );
}
