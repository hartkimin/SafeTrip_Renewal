import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

/// 채팅 메시지 목록 내 날짜 구분선 위젯.
///
/// 날짜가 변경되는 시점에 표시되며, 가운데 정렬된 텍스트와
/// 양 옆 수평선으로 구성된다.
///
/// 날짜 포맷:
///   - 오늘: "오늘"
///   - 어제: "어제"
///   - 그 외: "M월 d일" (예: "3월 15일")
class DateDividerWidget extends StatelessWidget {
  const DateDividerWidget({
    super.key,
    required this.dateStr,
  });

  /// ISO 8601 날짜 문자열 또는 "YYYY-MM-DD" 형식의 날짜.
  final String dateStr;

  @override
  Widget build(BuildContext context) {
    final label = _formatDateLabel(dateStr);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          const Expanded(
            child: Divider(
              color: AppColors.outlineVariant,
              thickness: 0.5,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Text(
              label,
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ),
          const Expanded(
            child: Divider(
              color: AppColors.outlineVariant,
              thickness: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  /// 날짜 문자열을 사용자 친화적 레이블로 변환한다.
  String _formatDateLabel(String dateStr) {
    final parsed = DateTime.tryParse(dateStr);
    if (parsed == null) return dateStr;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(parsed.year, parsed.month, parsed.day);

    final diff = today.difference(target).inDays;

    if (diff == 0) return '오늘';
    if (diff == 1) return '어제';
    return '${parsed.month}월 ${parsed.day}일';
  }
}
