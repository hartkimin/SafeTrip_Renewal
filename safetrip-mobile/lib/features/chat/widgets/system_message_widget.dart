import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

/// 시스템 이벤트 메시지 위젯.
///
/// 멤버 입장/퇴장, 역할 변경, 여행 시작/종료, 출석 등
/// 시스템이 자동 생성한 메시지를 가운데 정렬된 회색 배경 pill로 표시한다.
///
/// DOC-T3-CHT-020 시스템 메시지 유형:
///   - member_join / member_leave
///   - role_change
///   - trip_start / trip_end
///   - attendance
///   - sos_activated / sos_resolved
class SystemMessageWidget extends StatelessWidget {
  const SystemMessageWidget({
    super.key,
    required this.content,
  });

  /// 시스템 메시지 본문 (한국어 텍스트를 그대로 표시).
  final String content;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.xs,
      ),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          ),
          child: Text(
            content,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textTertiary,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
