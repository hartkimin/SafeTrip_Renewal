import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

/// 일정 공유 카드 위젯 (DOC-T3-CHT-020 SS7.5).
///
/// 채팅 메시지 목록에서 일정(schedule) 공유 메시지를 카드로 렌더링한다:
///   - 일정 제목
///   - 시작/종료 시간
///   - 장소
///   - [일정 상세 보기] 버튼
class ScheduleCardWidget extends StatelessWidget {
  const ScheduleCardWidget({super.key, required this.message});

  /// 일정 메시지 맵. 필요한 키:
  ///   - `metadata.cardData` 또는 `card_data` (Map): schedule 데이터
  ///     - `title` (String): 일정 제목
  ///     - `start_at` (String?): 시작 시각 ISO 8601
  ///     - `end_at` (String?): 종료 시각 ISO 8601
  ///     - `location` (String?): 장소명
  final Map<String, dynamic> message;

  @override
  Widget build(BuildContext context) {
    final cardData =
        message['metadata']?['cardData'] as Map<String, dynamic>? ??
            message['card_data'] as Map<String, dynamic>? ??
            <String, dynamic>{};
    final title = cardData['title'] as String? ?? '일정';
    final startAt = cardData['start_at'] as String?;
    final endAt = cardData['end_at'] as String?;
    final location = cardData['location'] as String?;

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
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---- 헤더 ----
            Row(
              children: [
                const Icon(Icons.calendar_today,
                    size: 18, color: AppColors.primaryTeal),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: AppTypography.labelMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            // ---- 시간 정보 ----
            if (startAt != null) ...[
              Row(
                children: [
                  const Icon(Icons.access_time,
                      size: 14, color: AppColors.textTertiary),
                  const SizedBox(width: 4),
                  Text(
                    _formatTime(startAt, endAt),
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
            ],

            // ---- 장소 정보 ----
            if (location != null) ...[
              Row(
                children: [
                  const Icon(Icons.location_on,
                      size: 14, color: AppColors.textTertiary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      location,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.sm),

            // ---- 상세 보기 버튼 ----
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  // TODO: Navigate to schedule detail
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('일정 탭에서 확인할 수 있습니다'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryTeal,
                  side: BorderSide(
                    color: AppColors.primaryTeal.withValues(alpha: 0.4),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radius8),
                  ),
                ),
                child: const Text('일정 상세 보기'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 시작/종료 시각을 `M월 D일 HH:mm ~ HH:mm` 형식으로 변환한다.
  String _formatTime(String start, String? end) {
    final s = DateTime.tryParse(start)?.toLocal();
    if (s == null) return start;
    final date = '${s.month}월 ${s.day}일';
    final time =
        '${s.hour}:${s.minute.toString().padLeft(2, '0')}';
    if (end != null) {
      final e = DateTime.tryParse(end)?.toLocal();
      if (e != null) {
        return '$date $time ~ ${e.hour}:${e.minute.toString().padLeft(2, '0')}';
      }
    }
    return '$date $time';
  }
}
