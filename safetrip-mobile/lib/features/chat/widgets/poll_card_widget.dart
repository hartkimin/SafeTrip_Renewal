import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

/// 투표 카드 위젯 (DOC-T3-CHT-020 SS7.4).
///
/// 채팅 메시지 목록에서 투표(poll) 메시지를 카드 형태로 렌더링한다:
///   - 투표 제목/질문
///   - 선택지별 프로그레스 바 + 득표 수 + 비율
///   - 총 투표 수 & 마감 시한 타이머
///   - 마감 시 "마감됨" 배지 표시
class PollCardWidget extends StatelessWidget {
  const PollCardWidget({super.key, required this.message});

  /// 투표 메시지 맵. 필요한 키:
  ///   - `metadata.cardData` 또는 `card_data` (Map): poll 데이터
  ///     - `title` (String): 투표 제목
  ///     - `options` (List): 선택지 목록
  ///     - `is_closed` (bool): 마감 여부
  ///     - `total_votes` (int): 총 투표 수
  ///     - `closes_at` (String?): 마감 시각 ISO 8601
  final Map<String, dynamic> message;

  @override
  Widget build(BuildContext context) {
    final cardData =
        message['metadata']?['cardData'] as Map<String, dynamic>? ??
            message['card_data'] as Map<String, dynamic>? ??
            <String, dynamic>{};
    final title = cardData['title'] as String? ?? '투표';
    final options = (cardData['options'] as List<dynamic>?) ?? [];
    final isClosed = cardData['is_closed'] == true;
    final totalVotes = (cardData['total_votes'] as int?) ?? 0;
    final closesAt = cardData['closes_at'] as String?;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radius12),
          border: Border.all(color: AppColors.outlineVariant),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---- 헤더 ----
            Row(
              children: [
                const Icon(Icons.poll_outlined,
                    size: 20, color: AppColors.primaryTeal),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: AppTypography.labelMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (isClosed)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(AppSpacing.radius8),
                    ),
                    child: Text(
                      '마감됨',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            // ---- 선택지 목록 ----
            ...options.asMap().entries.map((entry) {
              final option = entry.value;
              final optionText = option is String
                  ? option
                  : (option['text'] as String? ?? '');
              final votes =
                  option is String ? 0 : ((option['votes'] as int?) ?? 0);
              final percentage =
                  totalVotes > 0 ? (votes / totalVotes * 100).round() : 0;

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(optionText,
                              style: AppTypography.bodyMedium),
                        ),
                        Text(
                          '$votes표 ($percentage%)',
                          style: AppTypography.labelSmall.copyWith(
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: totalVotes > 0 ? votes / totalVotes : 0,
                        backgroundColor: AppColors.surfaceVariant,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.primaryTeal),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              );
            }),

            const Divider(height: 16),

            // ---- 푸터 ----
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '총 $totalVotes표',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
                if (closesAt != null && !isClosed)
                  Text(
                    '마감: ${_formatDeadline(closesAt)}',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// ISO 8601 날짜 문자열을 `M/D HH:mm` 형식으로 변환한다.
  String _formatDeadline(String dateStr) {
    final date = DateTime.tryParse(dateStr);
    if (date == null) return dateStr;
    final local = date.toLocal();
    return '${local.month}/${local.day} ${local.hour}:${local.minute.toString().padLeft(2, '0')}';
  }
}
