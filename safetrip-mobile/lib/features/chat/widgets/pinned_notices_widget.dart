import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

/// 고정 공지 바 위젯 (DOC-T3-CHT-020 SS9.2).
///
/// 채팅 상단에 최대 3개의 고정 메시지를 표시한다.
/// 각 항목은 pin 아이콘과 잘린 텍스트로 구성되며,
/// 전체 영역을 탭하면 접기/펼치기가 토글된다.
class PinnedNoticesWidget extends StatefulWidget {
  const PinnedNoticesWidget({
    super.key,
    required this.pinnedMessages,
    this.onTapMessage,
  });

  /// 고정 메시지 목록 (최대 3개).
  /// 각 항목의 키: `content`, `message_id`, `sender_name`
  final List<Map<String, dynamic>> pinnedMessages;

  /// 개별 고정 메시지 탭 콜백 (미래: 해당 메시지로 스크롤).
  final void Function(String messageId)? onTapMessage;

  @override
  State<PinnedNoticesWidget> createState() => _PinnedNoticesWidgetState();
}

class _PinnedNoticesWidgetState extends State<PinnedNoticesWidget> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    if (widget.pinnedMessages.isEmpty) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () => setState(() => _isExpanded = !_isExpanded),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.secondaryBeige.withValues(alpha: 0.5),
          border: const Border(
            bottom: BorderSide(
              color: AppColors.outlineVariant,
              width: 0.5,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더
            Row(
              children: [
                const Icon(
                  Icons.push_pin,
                  size: 14,
                  color: AppColors.secondaryAmber,
                ),
                const SizedBox(width: 4),
                Text(
                  '고정 공지 (${widget.pinnedMessages.length})',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Icon(
                  _isExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  size: 18,
                  color: AppColors.textTertiary,
                ),
              ],
            ),

            // 고정 메시지 목록 (접기/펼치기)
            if (_isExpanded) ...[
              const SizedBox(height: 6),
              for (final msg in widget.pinnedMessages) _buildPinnedItem(msg),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPinnedItem(Map<String, dynamic> msg) {
    final content = msg['content'] as String? ?? '';
    final messageId =
        msg['message_id'] as String? ?? msg['chat_message_id'] as String? ?? '';

    return GestureDetector(
      onTap: () {
        if (widget.onTapMessage != null && messageId.isNotEmpty) {
          widget.onTapMessage!(messageId);
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            const Text(
              '\u{1F4CC} ',
              style: TextStyle(fontSize: 12),
            ),
            Expanded(
              child: Text(
                content,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
