import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../services/api_service.dart';

/// 1:1 보호자 메시지 화면 (DOC-T3-CHT-020 SS8).
///
/// [linkId]로 식별되는 가디언 링크 채널에서 메시지를 주고받는다.
/// 프리미엄 가디언인 경우 [isPaid] = true로 Premium 배지를 표시한다.
class GuardianChatScreen extends StatefulWidget {
  const GuardianChatScreen({
    super.key,
    required this.linkId,
    this.isPaid = false,
  });

  /// 가디언 링크 ID (채널 식별자).
  final String linkId;

  /// 프리미엄 가디언 여부.
  final bool isPaid;

  @override
  State<GuardianChatScreen> createState() => _GuardianChatScreenState();
}

class _GuardianChatScreenState extends State<GuardianChatScreen> {
  final ApiService _api = ApiService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
    _loadMessages();
    _markRead();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    try {
      final result = await _api.dio
          .get('/api/v1/guardian-chats/channels/${widget.linkId}/messages');
      final data = result.data;
      setState(() {
        _messages = (data is List ? data : (data['data'] ?? []))
            .cast<Map<String, dynamic>>();
        // oldest first for display (API returns newest first)
        _messages = _messages.reversed.toList();
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (e) {
      debugPrint('[GuardianChat] 메시지 로드 실패: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _markRead() async {
    try {
      await _api.dio
          .post('/api/v1/guardian-chats/channels/${widget.linkId}/read');
    } catch (e) {
      debugPrint('[GuardianChat] 읽음 처리 실패: $e');
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;
    _messageController.clear();
    setState(() => _isSending = true);
    try {
      final result = await _api.dio.post(
        '/api/v1/guardian-chats/channels/${widget.linkId}/messages',
        data: {'content': text, 'messageType': 'text'},
      );
      final msg =
          result.data is Map ? result.data as Map<String, dynamic> : <String, dynamic>{};
      setState(() {
        _messages.add(msg);
        _isSending = false;
      });
      _scrollToBottom();
    } catch (e) {
      debugPrint('[GuardianChat] 메시지 전송 실패: $e');
      setState(() => _isSending = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('보호자 메시지'),
            if (widget.isPaid) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primaryTeal,
                  borderRadius: BorderRadius.circular(AppSpacing.radius8),
                ),
                child: Text(
                  'Premium',
                  style: AppTypography.labelSmall.copyWith(
                    color: Colors.white,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      body: Column(
        children: [
          // ---- 메시지 목록 ----
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? Center(
                        child: Text(
                          '아직 메시지가 없습니다',
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.textTertiary,
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(AppSpacing.md),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          final senderId =
                              msg['sender_id'] ?? msg['senderId'] ?? '';
                          final isMe = senderId == _currentUserId;
                          final content = msg['content'] as String? ?? '';

                          return Align(
                            alignment: isMe
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.of(context).size.width * 0.7,
                              ),
                              decoration: BoxDecoration(
                                color: isMe
                                    ? AppColors.primaryTeal
                                    : AppColors.surfaceVariant,
                                borderRadius: BorderRadius.circular(
                                    AppSpacing.radius16),
                              ),
                              child: Text(
                                content,
                                style: AppTypography.bodyMedium.copyWith(
                                  color: isMe
                                      ? Colors.white
                                      : AppColors.textPrimary,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),

          // ---- 메시지 입력 ----
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(
                top: BorderSide(color: AppColors.outlineVariant),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                    decoration: InputDecoration(
                      hintText: '메시지를 입력하세요',
                      hintStyle: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textTertiary,
                      ),
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radius24),
                        borderSide:
                            const BorderSide(color: AppColors.surfaceVariant),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radius24),
                        borderSide:
                            const BorderSide(color: AppColors.surfaceVariant),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radius24),
                        borderSide:
                            const BorderSide(color: AppColors.primaryTeal),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      isDense: true,
                    ),
                    style: AppTypography.bodyMedium,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _isSending ? null : _sendMessage,
                  icon: _isSending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send, color: AppColors.primaryTeal),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
