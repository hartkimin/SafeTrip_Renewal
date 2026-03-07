import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../services/api_service.dart';

/// 메시지 리액션(이모지 반응) 바 위젯.
///
/// 메시지 버블 아래에 표시되며, 이모지별 그룹화된 반응과 수를 보여준다.
/// 탭하면 내 반응을 추가/제거한다.
class ReactionBarWidget extends StatelessWidget {
  const ReactionBarWidget({
    super.key,
    required this.messageId,
    required this.reactions,
    required this.currentUserId,
    required this.onReactionChanged,
  });

  /// 대상 메시지 ID.
  final String messageId;

  /// 반응 목록 (각 항목: `{emoji, user_id}` 또는 `{emoji, userId}`).
  final List<dynamic> reactions;

  /// 현재 로그인한 사용자 ID.
  final String currentUserId;

  /// 반응 변경 후 새로고침 콜백.
  final VoidCallback onReactionChanged;

  /// 기본 이모지 목록 (이모지 피커에 표시).
  static const defaultEmojis = ['\u{1F44D}', '\u{2764}\u{FE0F}', '\u{1F602}', '\u{1F62E}', '\u{1F622}', '\u{1F64F}'];

  @override
  Widget build(BuildContext context) {
    if (reactions.isEmpty) return const SizedBox.shrink();

    // 이모지별 그룹화
    final grouped = <String, List<String>>{};
    for (final r in reactions) {
      final emoji =
          (r is Map ? r['emoji'] : null) as String? ?? '';
      final userId =
          (r is Map ? (r['user_id'] ?? r['userId']) : null) as String? ?? '';
      if (emoji.isNotEmpty) {
        grouped.putIfAbsent(emoji, () => []).add(userId);
      }
    }

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: grouped.entries.map((entry) {
        final isMyReaction = entry.value.contains(currentUserId);
        return GestureDetector(
          onTap: () async {
            final api = ApiService();
            try {
              if (isMyReaction) {
                await api.dio.delete(
                  '/api/v1/chats/messages/$messageId/reactions/${entry.key}',
                );
              } else {
                await api.dio.post(
                  '/api/v1/chats/messages/$messageId/reactions',
                  data: {'emoji': entry.key},
                );
              }
              onReactionChanged();
            } catch (e) {
              debugPrint('Reaction error: $e');
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isMyReaction
                  ? AppColors.primaryTeal.withValues(alpha: 0.15)
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color:
                    isMyReaction ? AppColors.primaryTeal : Colors.grey.shade300,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(entry.key, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 2),
                Text(
                  '${entry.value.length}',
                  style: AppTypography.labelSmall.copyWith(
                    color: isMyReaction
                        ? AppColors.primaryTeal
                        : AppColors.textTertiary,
                    fontWeight:
                        isMyReaction ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  /// 이모지 피커 바텀 시트를 표시하고 선택된 이모지를 반환한다.
  static Future<String?> showEmojiPicker(BuildContext context) {
    return showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: defaultEmojis.map((emoji) {
            return GestureDetector(
              onTap: () => Navigator.pop(ctx, emoji),
              child: Text(emoji, style: const TextStyle(fontSize: 32)),
            );
          }).toList(),
        ),
      ),
    );
  }
}
