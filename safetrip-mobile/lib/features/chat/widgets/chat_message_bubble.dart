import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../services/api_service.dart';
import 'reaction_bar_widget.dart';

/// 읽음 상태 열거형.
enum ReadStatus {
  /// 전송 대기 중 (오프라인 큐)
  pending,

  /// 전송 완료 (서버 수신)
  sent,

  /// 읽음 확인됨
  read,
}

/// 채팅 메시지 버블 위젯.
///
/// 내 메시지(오른쪽 정렬)와 상대 메시지(왼쪽 정렬)를 통합 처리한다.
///
/// 기능:
///   - 텍스트 메시지 표시
///   - 이미지 메시지 썸네일 표시
///   - 발신자 이름 (상대 메시지만)
///   - 타임스탬프
///   - 읽음 상태 인디케이터
///   - 삭제된 메시지 표시
///   - 롱 프레스 컨텍스트 메뉴 (미래 확장)
class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.isPending = false,
    this.onLongPress,
    this.reactions = const [],
    this.currentUserId,
    this.onReactionChanged,
  });

  /// 메시지 맵. 주요 키:
  ///   - `content` (String)
  ///   - `message_type` (String): 'text', 'image', 'location'
  ///   - `sender_name` (String?)
  ///   - `sender_id` (String?)
  ///   - `created_at` (String?)
  ///   - `is_read` (bool?)
  ///   - `is_deleted` (bool?)
  ///   - `image_url` (String?)
  final Map<String, dynamic> message;

  /// 본인이 보낸 메시지 여부.
  final bool isMe;

  /// 오프라인 큐에서 전송 대기 중인 메시지 여부.
  final bool isPending;

  /// 롱 프레스 콜백 (미래: 삭제, 고정, 반응 등).
  final VoidCallback? onLongPress;

  /// 이 메시지에 달린 리액션 목록.
  final List<dynamic> reactions;

  /// 현재 사용자 ID (리액션 표시용).
  final String? currentUserId;

  /// 리액션 변경 후 새로고침 콜백.
  final VoidCallback? onReactionChanged;

  @override
  Widget build(BuildContext context) {
    final content = message['content'] as String? ?? '';
    final senderName = message['sender_name'] as String?;
    final timestamp = message['created_at'] as String? ??
        message['sent_at'] as String?;
    final isDeleted = message['is_deleted'] as bool? ?? false;
    final messageType = message['message_type'] as String? ?? 'text';
    final imageUrl = message['image_url'] as String?;
    final readStatus = _resolveReadStatus();
    final timeStr = _formatTime(timestamp);
    final messageId = message['message_id'] as String? ??
        message['id'] as String? ??
        '';

    // 메시지 맵에 포함된 리액션 또는 외부에서 전달된 리액션
    final effectiveReactions = reactions.isNotEmpty
        ? reactions
        : (message['reactions'] as List<dynamic>? ?? <dynamic>[]);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onLongPress ?? () => _handleLongPress(context, messageId),
        child: Container(
          margin: EdgeInsets.only(
            left: isMe ? 60 : AppSpacing.md,
            right: isMe ? AppSpacing.md : 60,
            top: 2,
            bottom: 2,
          ),
          child: Column(
            crossAxisAlignment:
                isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              // 발신자 이름 (상대 메시지만)
              if (!isMe && senderName != null && senderName.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 2),
                  child: Text(
                    senderName,
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.textTertiary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

              // 메시지 버블
              Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.7,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: _bubbleColor(isDeleted),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isMe ? 16 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 16),
                  ),
                ),
                child: Column(
                  crossAxisAlignment:
                      isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    // 메시지 콘텐츠
                    if (isDeleted)
                      _buildDeletedContent()
                    else if (messageType == 'image' && imageUrl != null)
                      _buildImageContent(imageUrl, content)
                    else
                      _buildTextContent(content),

                    // 하단: 타임스탬프 + 읽음 상태
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (timeStr.isNotEmpty)
                          Text(
                            timeStr,
                            style: AppTypography.labelSmall.copyWith(
                              color: AppColors.textTertiary,
                              fontSize: 11,
                            ),
                          ),
                        if (isMe) ...[
                          const SizedBox(width: 4),
                          _buildReadStatusIcon(readStatus),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // 리액션 바 (버블 아래)
              if (effectiveReactions.isNotEmpty && messageId.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: ReactionBarWidget(
                    messageId: messageId,
                    reactions: effectiveReactions,
                    currentUserId: currentUserId ?? '',
                    onReactionChanged: onReactionChanged ?? () {},
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 롱 프레스 시 이모지 피커를 표시하고 선택 시 리액션을 추가한다.
  Future<void> _handleLongPress(
    BuildContext context,
    String messageId,
  ) async {
    if (messageId.isEmpty) return;
    final emoji = await ReactionBarWidget.showEmojiPicker(context);
    if (emoji == null) return;
    try {
      final api = ApiService();
      await api.dio.post(
        '/api/v1/chats/messages/$messageId/reactions',
        data: {'emoji': emoji},
      );
      onReactionChanged?.call();
    } catch (e) {
      debugPrint('Add reaction error: $e');
    }
  }

  Color _bubbleColor(bool isDeleted) {
    if (isDeleted) {
      return AppColors.surfaceVariant.withValues(alpha: 0.5);
    }
    if (isMe) {
      return AppColors.primaryTeal.withValues(alpha: 0.15);
    }
    return AppColors.surfaceVariant;
  }

  Widget _buildTextContent(String content) {
    return Text(
      content,
      style: AppTypography.bodyMedium.copyWith(
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildDeletedContent() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.block,
          size: 14,
          color: AppColors.textTertiary,
        ),
        const SizedBox(width: 4),
        Text(
          '삭제된 메시지입니다',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textTertiary,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _buildImageContent(String imageUrl, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.radius8),
          child: Container(
            constraints: const BoxConstraints(
              maxHeight: 200,
              maxWidth: 240,
            ),
            color: AppColors.surfaceVariant,
            child: Image.network(
              imageUrl,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return SizedBox(
                  height: 120,
                  width: 200,
                  child: Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                      strokeWidth: 2,
                      color: AppColors.primaryTeal,
                    ),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: 80,
                  width: 200,
                  color: AppColors.surfaceVariant,
                  child: const Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: AppColors.textTertiary,
                      size: 32,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        if (content.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            content,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildReadStatusIcon(ReadStatus status) {
    switch (status) {
      case ReadStatus.pending:
        return Icon(
          Icons.schedule,
          size: 14,
          color: Colors.orange.shade600,
        );
      case ReadStatus.sent:
        return const Icon(
          Icons.check,
          size: 14,
          color: AppColors.textTertiary,
        );
      case ReadStatus.read:
        return const Icon(
          Icons.done_all,
          size: 14,
          color: AppColors.primaryTeal,
        );
    }
  }

  ReadStatus _resolveReadStatus() {
    if (isPending) return ReadStatus.pending;
    final isRead = message['is_read'] as bool? ?? false;
    return isRead ? ReadStatus.read : ReadStatus.sent;
  }

  String _formatTime(String? isoStr) {
    if (isoStr == null) return '';
    final dt = DateTime.tryParse(isoStr);
    if (dt == null) return '';
    final local = dt.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}
