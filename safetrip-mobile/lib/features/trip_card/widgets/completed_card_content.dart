import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../models/trip_card_data.dart';

/// completed 상태 카드 콘텐츠 (§04.3, P2-1 재활성화, P3-1 통계)
class CompletedCardContent extends StatelessWidget {
  const CompletedCardContent({
    super.key,
    required this.card,
    this.onReactivate,
  });

  final MemberTripCard card;
  final VoidCallback? onReactivate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1행: [완료] + 국기+여행명 + 완료 + 멤버수
        Row(
          children: [
            _statusBadge(),
            const SizedBox(width: 6),
            if (card.countryCode != null) ...[
              Text(
                _countryFlag(card.countryCode!),
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(width: 4),
            ],
            Expanded(
              child: Text(
                card.tripName,
                style: AppTypography.titleMedium.copyWith(fontSize: 15),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.tripCompleted.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                '완료',
                style: TextStyle(
                  color: AppColors.tripCompleted,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.people_outline, size: 14, color: AppColors.textTertiary),
            const SizedBox(width: 2),
            Text(
              '${card.memberCount}명',
              style: AppTypography.labelSmall
                  .copyWith(color: AppColors.textTertiary),
            ),
          ],
        ),
        const SizedBox(height: 4),
        // 2행: 날짜
        Text(
          '\u{1F4C5} ${_formatDate(card.startDate)} ~ ${_formatDate(card.endDate)} (${card.tripDays}일)',
          style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 4),
        // 3행: 통계 (P3-1) + 재활성화 (P2-1)
        Row(
          children: [
            if (card.totalDistanceKm != null)
              _statChip(
                  '이동 거리: ${card.totalDistanceKm!.toStringAsFixed(1)}km'),
            if (card.visitedPlaces != null) ...[
              const SizedBox(width: 6),
              _statChip('방문지: ${card.visitedPlaces}곳'),
            ],
            const Spacer(),
            // 재활성화 버튼 (P2-1: 캡틴만, §04.5)
            if (card.canReactivate && card.userRole == 'captain')
              TextButton.icon(
                onPressed: onReactivate,
                icon: const Icon(Icons.refresh, size: 14),
                label: const Text('재활성화'),
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  textStyle: AppTypography.labelSmall,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _statusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.tripCompleted.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        '완료',
        style: TextStyle(
          color: AppColors.tripCompleted,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _statChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style:
            AppTypography.labelSmall.copyWith(color: AppColors.textTertiary),
      ),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';

  String _countryFlag(String countryCode) {
    if (countryCode.length != 2) return '\u{1F30F}';
    final first = countryCode.codeUnitAt(0) - 0x41 + 0x1F1E6;
    final second = countryCode.codeUnitAt(1) - 0x41 + 0x1F1E6;
    return String.fromCharCode(first) + String.fromCharCode(second);
  }
}
