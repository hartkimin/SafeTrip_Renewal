import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../features/main/providers/connectivity_provider.dart';
import '../../../services/api_service.dart';
import '../../../services/offline_sync_service.dart';
import '../../../utils/app_cache.dart';

/// 채팅 탭 바텀시트 콘텐츠 (화면구성원칙 §4 탭 3)
///
/// REST API 기반 그룹 채팅 UI.
/// DOC-T2-OFL-016 §8.2 — 오프라인 시 메시지를 SQLite 큐에 저장,
/// "⏳ 전송 대기 중" 인디케이터 표시.
class BottomSheetChat extends ConsumerStatefulWidget {
  const BottomSheetChat({
    super.key,
    required this.scrollController,
  });

  final ScrollController scrollController;

  @override
  ConsumerState<BottomSheetChat> createState() => _BottomSheetChatState();
}

class _BottomSheetChatState extends ConsumerState<BottomSheetChat> {
  final ApiService _apiService = ApiService();
  final TextEditingController _messageController = TextEditingController();

  List<Map<String, dynamic>> _messages = [];
  List<Map<String, dynamic>> _pendingMessages = [];
  bool _isLoading = true;
  bool _isSending = false;
  String? _roomId;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final tripId = AppCache.tripIdSync;
    if (tripId == null) {
      setState(() => _isLoading = false);
      return;
    }

    // 채팅방 조회 — trip 기반으로 첫 번째 방 사용
    try {
      final rooms = await _apiService.getChatRooms(tripId);
      if (rooms.isNotEmpty) {
        _roomId = rooms.first['room_id'] as String? ??
            rooms.first['chat_room_id'] as String?;
      } else {
        _roomId = tripId;
      }
    } catch (_) {
      _roomId = tripId;
    }

    await Future.wait([_loadMessages(), _loadPendingMessages()]);
  }

  Future<void> _loadMessages() async {
    if (_roomId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    try {
      final messages = await _apiService.getChatMessages(_roomId!, limit: 50);
      if (mounted) {
        setState(() {
          _messages = messages;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadPendingMessages() async {
    final pending = await OfflineSyncService().getPendingChats(limit: 100);
    if (mounted) setState(() => _pendingMessages = pending);
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    final networkStatus = ref.read(networkStateProvider);
    final tripId = AppCache.tripIdSync;
    final senderId = _currentUserId ?? '';
    final localId = const Uuid().v4();

    _messageController.clear();

    if (!networkStatus.isOnline || _roomId == null) {
      // §8.2 오프라인: SQLite 큐에 저장
      final success = await OfflineSyncService().pushChat(
        tripId: tripId ?? _roomId ?? '',
        senderId: senderId,
        content: text,
        localId: localId,
      );
      if (mounted) {
        await _loadPendingMessages();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success
                ? '오프라인 — 연결 복구 시 전송됩니다'
                : '메시지 큐 한도 도달 (100건)'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    // 온라인: API 전송
    setState(() => _isSending = true);
    try {
      final result = await _apiService.sendChatMessage(
        roomId: _roomId!,
        content: text,
      );
      if (result != null && mounted) {
        setState(() {
          _messages.insert(0, {
            ...result,
            'sender_id': senderId,
            'content': text,
            'created_at': DateTime.now().toIso8601String(),
          });
        });
      }
    } catch (_) {
      // 전송 실패 → 오프라인 큐 폴백
      await OfflineSyncService().pushChat(
        tripId: tripId ?? _roomId ?? '',
        senderId: senderId,
        content: text,
        localId: localId,
      );
      if (mounted) await _loadPendingMessages();
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final networkStatus = ref.watch(networkStateProvider);
    final isOffline = !networkStatus.isOnline;

    // SnappingBottomSheet는 scrollController를 사용하는 스크롤 위젯을 기대함.
    // ListView를 최외곽에 배치하고, 내부에 채팅 UI를 구성.
    return ListView(
      controller: widget.scrollController,
      padding: EdgeInsets.zero,
      children: [
        // 오프라인 배너
        if (isOffline) _buildOfflineBanner(),

        // 대기 중 메시지 카운터
        if (_pendingMessages.isNotEmpty) _buildPendingCounter(),

        // 메시지 영역
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.only(top: 60),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_messages.isEmpty && _pendingMessages.isEmpty)
          _buildEmptyState()
        else
          ..._buildMessageItems(),

        // 하단 여백 (입력 영역 공간 확보)
        const SizedBox(height: 80),
      ],
    );
  }

  List<Widget> _buildMessageItems() {
    final items = <Widget>[];

    // 대기 중 메시지 (상단)
    for (final pending in _pendingMessages) {
      items.add(_buildMessageBubble(
        content: pending['content'] as String? ?? '',
        senderId: pending['sender_id'] as String? ?? '',
        timestamp: pending['created_at'] as String?,
        isPending: true,
      ));
    }

    // 서버 메시지
    for (final msg in _messages) {
      items.add(_buildMessageBubble(
        content: msg['content'] as String? ?? '',
        senderId:
            msg['sender_id'] as String? ?? msg['user_id'] as String? ?? '',
        timestamp:
            msg['created_at'] as String? ?? msg['sent_at'] as String?,
        isPending: false,
      ));
    }

    // 메시지 입력 위젯
    items.add(_buildMessageInput());

    return items;
  }

  Widget _buildOfflineBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        border: Border(bottom: BorderSide(color: Colors.orange.shade200)),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off, size: 16, color: Colors.orange.shade700),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              '오프라인 — 메시지가 연결 복구 후 전송됩니다',
              style: AppTypography.labelSmall.copyWith(
                color: Colors.orange.shade800,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Column(
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 48,
            color: AppColors.textTertiary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            '아직 메시지가 없습니다',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '그룹 멤버들에게 메시지를 보내보세요',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble({
    required String content,
    required String senderId,
    String? timestamp,
    bool isPending = false,
  }) {
    final isMe = senderId == _currentUserId;
    final timeStr = _formatTime(timestamp);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 4,
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe
              ? AppColors.primaryTeal.withValues(alpha: 0.15)
              : AppColors.surfaceVariant,
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
            Text(
              content,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
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
                // §8.2 — 전송 대기 중 아이콘
                if (isPending) ...[
                  const SizedBox(width: 4),
                  Icon(Icons.schedule, size: 12, color: Colors.orange.shade600),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingCounter() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 6,
      ),
      color: Colors.orange.shade50,
      child: Row(
        children: [
          Icon(Icons.schedule, size: 14, color: Colors.orange.shade700),
          const SizedBox(width: 6),
          Text(
            '전송 대기 중: ${_pendingMessages.length}건',
            style: AppTypography.labelSmall.copyWith(
              color: Colors.orange.shade800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
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
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: AppColors.surfaceVariant),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: AppColors.surfaceVariant),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: AppColors.primaryTeal),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
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
    );
  }

  String _formatTime(String? isoStr) {
    if (isoStr == null) return '';
    final dt = DateTime.tryParse(isoStr);
    if (dt == null) return '';
    final local = dt.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}
