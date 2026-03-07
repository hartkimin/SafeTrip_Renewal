import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../models/trip_card_data.dart';
import 'd_day_badge.dart';

/// active 상태 카드 콘텐츠 (§04.2)
class ActiveCardContent extends StatelessWidget {
  const ActiveCardContent({super.key, required this.card});

  final MemberTripCard card;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1행: [진행 중] + 국기+여행명 + 여행 중 + 멤버수
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
            DDayBadge(status: card.status),
            const SizedBox(width: 8),
            const Icon(Icons.people_outline, size: 14, color: AppColors.textTertiary),
            const SizedBox(width: 2),
            Text(
              '${card.memberCount}명',
              style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary),
            ),
          ],
        ),
        const SizedBox(height: 4),
        // 2행: 날짜 + N일째 진행 중
        Text(
          '\u{1F4C5} ${_formatDate(card.startDate)} ~ ${_formatDate(card.endDate)} | ${card.currentDay ?? 1}일째 진행 중',
          style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 4),
        // 3행: 오늘 일정 요약 (P2-2)
        if (card.todayScheduleSummary != null &&
            card.todayScheduleSummary!.isNotEmpty)
          Row(
            children: [
              Text(
                '오늘 일정: ',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.textTertiary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Expanded(
                child: Text(
                  card.todayScheduleSummary!,
                  style: AppTypography.labelSmall
                      .copyWith(color: AppColors.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
        color: AppColors.tripActive.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        '진행 중',
        style: TextStyle(
          color: AppColors.tripActive,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
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
