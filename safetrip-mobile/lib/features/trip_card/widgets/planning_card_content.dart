import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../models/trip_card_data.dart';
import 'privacy_badge.dart';
import 'd_day_badge.dart';

/// planning 상태 카드 콘텐츠 (§04.1)
class PlanningCardContent extends StatelessWidget {
  const PlanningCardContent({super.key, required this.card});

  final MemberTripCard card;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1행: [예정] + 국기+여행명 + D-N + 멤버수
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
            DDayBadge(status: card.status, dDay: card.dDay),
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
        // 2행: 날짜
        Text(
          '\u{1F4C5} ${_formatDate(card.startDate)} ~ ${_formatDate(card.endDate)} (${card.tripDays}일)',
          style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 4),
        // 3행: 프라이버시 배지
        PrivacyBadge(level: card.privacyLevel),
      ],
    );
  }

  Widget _statusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.tripPlanning.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        '예정',
        style: TextStyle(
          color: AppColors.tripPlanning,
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
