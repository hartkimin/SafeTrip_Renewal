import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../features/chat/providers/chat_provider.dart';
import '../../../features/chat/screens/guardian_channel_list_screen.dart';
import '../../../features/chat/screens/media_gallery_screen.dart';
import '../../../features/chat/widgets/attachment_menu_widget.dart';
import '../../../features/chat/widgets/chat_message_bubble.dart';
import '../../../features/chat/widgets/date_divider_widget.dart';
import '../../../features/chat/widgets/location_card_widget.dart';
import '../../../features/chat/widgets/message_search_widget.dart';
import '../../../features/chat/widgets/pinned_notices_widget.dart';
import '../../../features/chat/widgets/poll_card_widget.dart';
import '../../../features/chat/widgets/schedule_card_widget.dart';
import '../../../features/chat/widgets/sos_card_widget.dart';
import '../../../features/chat/widgets/system_message_widget.dart';
import '../../../features/main/providers/connectivity_provider.dart';
import '../../../utils/app_cache.dart';

/// 채팅 탭 바텀시트 콘텐츠 (화면구성원칙 SS4 탭 3)
///
/// REST API + WebSocket 기반 그룹 채팅 UI.
/// DOC-T2-OFL-016 SS8.2 -- 오프라인 시 메시지를 SQLite 큐에 저장,
/// 전송 대기 중 인디케이터 표시.
///
/// 지원 메시지 유형 (DOC-T3-CHT-020):
///   - text      : 일반 텍스트 버블
///   - image     : 이미지 썸네일 + 텍스트
///   - system    : 시스템 이벤트 pill (멤버 입장/퇴장, 역할 변경 등)
///   - location  : 위치 공유 카드
///   - poll      : 투표 카드 (Phase 2)
///   - rich_card : 일정 공유 등 리치 카드 (Phase 2)
///   - CRITICAL  : SOS 카드 (system_event_level == 'CRITICAL')
///
/// 서브탭 구조 (Phase 2):
///   - [그룹 채팅] : 기존 그룹 채팅
///   - [보호자 메시지] : 가디언 1:1 채널 목록
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
  final TextEditingController _messageController = TextEditingController();
  String? _currentUserId;
  bool _providerInitialized = false;

  /// 현재 선택된 서브탭 인덱스 (0: 그룹 채팅, 1: 보호자 메시지)
  int _selectedTab = 0;

  /// 메시지 검색 위젯 표시 여부.
  bool _showSearch = false;

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;

    // ChatProvider 초기화는 첫 빌드 이후 수행 (ref 접근 필요)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeChatProvider();
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _initializeChatProvider() {
    if (_providerInitialized) return;
    _providerInitialized = true;

    final tripId = AppCache.tripIdSync;
    if (tripId != null) {
      ref.read(chatProvider.notifier).initialize(tripId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);
    final networkStatus = ref.watch(networkStateProvider);
    final isOffline = !networkStatus.isOnline;

    // DraggableScrollableSheet 요구사항: scrollController를 반드시
    // 최상위 스크롤 가능 위젯에 연결해야 한다.
    // 탭 전환 시에도 동일 ScrollController를 사용하여 시트 스냅이 동작한다.
    return ListView(
      controller: widget.scrollController,
      padding: EdgeInsets.zero,
      children: [
        // ---- 서브 탭 바 ----
        _buildSubTabBar(),

        // ---- 탭 내용 ----
        if (_selectedTab == 0) ...[
          // [그룹 채팅] 탭
          ..._buildGroupChatContent(chatState, isOffline),
        ] else ...[
          // [보호자 메시지] 탭
          _buildGuardianContent(),
        ],
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Sub-tab bar (세그먼트 컨트롤)
  // ---------------------------------------------------------------------------

  Widget _buildSubTabBar() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          _buildSubTab(0, '그룹 채팅'),
          _buildSubTab(1, '보호자 메시지'),
          // 검색 아이콘 버튼
          SizedBox(
            width: 40,
            height: 40,
            child: IconButton(
              onPressed: () => setState(() => _showSearch = !_showSearch),
              icon: Icon(
                _showSearch ? Icons.search_off : Icons.search,
                size: 20,
                color: _showSearch
                    ? AppColors.primaryTeal
                    : AppColors.textTertiary,
              ),
              padding: EdgeInsets.zero,
              tooltip: '메시지 검색',
            ),
          ),
          // 미디어 갤러리 아이콘 버튼
          SizedBox(
            width: 40,
            height: 40,
            child: IconButton(
              onPressed: () => _openMediaGallery(),
              icon: const Icon(
                Icons.photo_library_outlined,
                size: 20,
                color: AppColors.textTertiary,
              ),
              padding: EdgeInsets.zero,
              tooltip: '미디어 모아보기',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubTab(int index, String label) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? AppColors.primaryTeal : Colors.transparent,
                width: 2.5,
              ),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppTypography.labelMedium.copyWith(
              color: isSelected ? AppColors.primaryTeal : AppColors.textTertiary,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Group chat content (탭 0)
  // ---------------------------------------------------------------------------

  List<Widget> _buildGroupChatContent(ChatState chatState, bool isOffline) {
    return [
      // 메시지 검색 위젯
      if (_showSearch && chatState.roomId != null)
        MessageSearchWidget(
          roomId: chatState.roomId!,
          onResultTap: (msg) {
            // 검색 결과 탭 시 검색 닫기 (향후: 해당 메시지로 스크롤)
            setState(() => _showSearch = false);
          },
          onClose: () => setState(() => _showSearch = false),
        ),

      // 오프라인 배너
      if (isOffline) _buildOfflineBanner(),

      // 고정 공지 바 (최대 3개)
      if (chatState.pinnedMessages.isNotEmpty)
        PinnedNoticesWidget(pinnedMessages: chatState.pinnedMessages),

      // 대기 중 메시지 카운터
      if (chatState.pendingMessages.isNotEmpty)
        _buildPendingCounter(chatState),

      // 메시지 영역
      if (chatState.isLoading)
        const Padding(
          padding: EdgeInsets.only(top: 60),
          child: Center(child: CircularProgressIndicator()),
        )
      else if (chatState.messages.isEmpty && chatState.pendingMessages.isEmpty)
        _buildEmptyState(chatState)
      else
        ..._buildMessageList(chatState),

      // 하단 여백 (입력 영역 공간 확보)
      const SizedBox(height: 80),
    ];
  }

  // ---------------------------------------------------------------------------
  // Guardian content (탭 1) — 인라인 렌더링
  // ---------------------------------------------------------------------------

  Widget _buildGuardianContent() {
    return SizedBox(
      // GuardianChannelListScreen이 내부적으로 ListView를 사용하지만,
      // 여기서는 부모 ListView의 자식으로 포함되므로 고정 높이를 부여한다.
      height: MediaQuery.of(context).size.height * 0.6,
      child: const GuardianChannelListScreen(),
    );
  }

  // ---------------------------------------------------------------------------
  // Message list builder
  // ---------------------------------------------------------------------------

  List<Widget> _buildMessageList(ChatState state) {
    final items = <Widget>[];

    // 대기 중 메시지 (상단, pending 상태로 표시)
    for (final pending in state.pendingMessages) {
      items.add(ChatMessageBubble(
        message: pending,
        isMe: true,
        isPending: true,
      ));
    }

    // 서버 메시지 (날짜 구분선 포함)
    String? lastDate;
    for (final msg in state.messages) {
      final date = _extractDate(msg);
      if (date != lastDate) {
        items.add(DateDividerWidget(dateStr: date));
        lastDate = date;
      }
      items.add(_buildMessageWidget(msg));
    }

    // 메시지 입력 위젯
    items.add(_buildMessageInput(state));

    return items;
  }

  Widget _buildMessageWidget(Map<String, dynamic> msg) {
    final type = msg['message_type'] as String? ?? 'text';
    final eventLevel = msg['system_event_level'] as String?;

    // 시스템 메시지
    if (type == 'system') {
      // CRITICAL 등급 = SOS 카드
      if (eventLevel == 'CRITICAL') {
        return SosCardWidget(message: msg);
      }
      return SystemMessageWidget(
        content: msg['content'] as String? ?? '',
      );
    }

    // 위치 공유 카드
    if (type == 'location') {
      return LocationCardWidget(message: msg);
    }

    // 투표 카드 (Phase 2)
    if (type == 'poll') {
      return PollCardWidget(message: msg);
    }

    // 일정 공유 등 리치 카드 (Phase 2)
    if (type == 'rich_card' || type == 'schedule') {
      return ScheduleCardWidget(message: msg);
    }

    // 기본: 텍스트/이미지 버블
    final senderId =
        msg['sender_id'] as String? ?? msg['user_id'] as String? ?? '';
    final isMe = senderId == _currentUserId;
    return ChatMessageBubble(
      message: msg,
      isMe: isMe,
      currentUserId: _currentUserId,
      onReactionChanged: () {
        // 리액션 변경 후 메시지 목록 새로고침
        ref.read(chatProvider.notifier).refresh();
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Offline banner
  // ---------------------------------------------------------------------------

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
              '오프라인 -- 메시지가 연결 복구 후 전송됩니다',
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

  // ---------------------------------------------------------------------------
  // Pending counter
  // ---------------------------------------------------------------------------

  Widget _buildPendingCounter(ChatState state) {
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
            '전송 대기 중: ${state.pendingMessages.length}건',
            style: AppTypography.labelSmall.copyWith(
              color: Colors.orange.shade800,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Empty state
  // ---------------------------------------------------------------------------

  Widget _buildEmptyState(ChatState state) {
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
          _buildMessageInput(state),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Message input (with [+] attachment button)
  // ---------------------------------------------------------------------------

  Widget _buildMessageInput(ChatState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          // [+] 첨부 버튼
          SizedBox(
            width: 36,
            height: 36,
            child: IconButton(
              onPressed: () => _showAttachmentMenu(),
              icon: const Icon(Icons.add_circle_outline),
              color: AppColors.textTertiary,
              iconSize: 24,
              padding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(width: 4),

          // 텍스트 입력 필드
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
                  borderSide: const BorderSide(color: AppColors.surfaceVariant),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: AppColors.surfaceVariant),
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

          // 전송 버튼
          IconButton(
            onPressed: state.isSending ? null : _sendMessage,
            icon: state.isSending
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

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final networkStatus = ref.read(networkStateProvider);
    _messageController.clear();

    await ref.read(chatProvider.notifier).sendMessage(
          text,
          isOnline: networkStatus.isOnline,
        );
  }

  void _showAttachmentMenu() {
    AttachmentMenuWidget.show(context);
  }

  void _openMediaGallery() {
    final chatState = ref.read(chatProvider);
    final roomId = chatState.roomId;
    if (roomId == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MediaGalleryScreen(roomId: roomId),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// 메시지에서 날짜 문자열(YYYY-MM-DD)을 추출한다.
  String _extractDate(Map<String, dynamic> msg) {
    final createdAt =
        msg['created_at'] as String? ?? msg['sent_at'] as String?;
    if (createdAt == null) return '';
    final parsed = DateTime.tryParse(createdAt);
    if (parsed == null) return createdAt;
    final local = parsed.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }
}
