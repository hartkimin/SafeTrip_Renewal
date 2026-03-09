import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';

import '../../../services/api_service.dart';
import '../../../services/offline_sync_service.dart';
import '../services/chat_websocket_service.dart';

// ---------------------------------------------------------------------------
// ChatState — 채팅 화면의 전체 상태
// ---------------------------------------------------------------------------

/// 채팅 탭의 불변 상태 스냅샷.
///
/// [messages]       : 서버에서 가져온 메시지 목록 (최신순)
/// [pendingMessages]: 오프라인 큐에 저장된 미전송 메시지 목록
/// [pinnedMessages] : 고정된 메시지 목록
/// [roomId]         : 현재 채팅방 ID
/// [isLoading]      : 초기 데이터 로딩 중 여부
/// [isSending]      : 메시지 전송 중 여부
/// [error]          : 오류 메시지
class ChatState {
  const ChatState({
    this.messages = const [],
    this.pendingMessages = const [],
    this.pinnedMessages = const [],
    this.roomId,
    this.tripId,
    this.isLoading = false,
    this.isSending = false,
    this.error,
  });

  final List<Map<String, dynamic>> messages;
  final List<Map<String, dynamic>> pendingMessages;
  final List<Map<String, dynamic>> pinnedMessages;
  final String? roomId;
  final String? tripId;
  final bool isLoading;
  final bool isSending;
  final String? error;

  ChatState copyWith({
    List<Map<String, dynamic>>? messages,
    List<Map<String, dynamic>>? pendingMessages,
    List<Map<String, dynamic>>? pinnedMessages,
    String? roomId,
    String? tripId,
    bool? isLoading,
    bool? isSending,
    String? error,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      pendingMessages: pendingMessages ?? this.pendingMessages,
      pinnedMessages: pinnedMessages ?? this.pinnedMessages,
      roomId: roomId ?? this.roomId,
      tripId: tripId ?? this.tripId,
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
      error: error,
    );
  }
}

// ---------------------------------------------------------------------------
// ChatNotifier — Riverpod StateNotifier
// ---------------------------------------------------------------------------

/// 채팅 상태를 관리하는 StateNotifier.
///
/// 세 계층을 조합하여 동작한다:
///   1. [ApiService]          — REST API 호출 (메시지 목록, 전송, 읽음 처리)
///   2. [ChatWebSocketService] — Socket.IO 실시간 수신
///   3. [OfflineSyncService]  — 오프라인 메시지 큐
class ChatNotifier extends StateNotifier<ChatState> {
  ChatNotifier({
    ApiService? apiService,
    ChatWebSocketService? wsService,
    OfflineSyncService? offlineService,
  })  : _apiService = apiService ?? ApiService(),
        _wsService = wsService ?? ChatWebSocketService(),
        _offlineService = offlineService ?? OfflineSyncService(),
        super(const ChatState());

  final ApiService _apiService;
  final ChatWebSocketService _wsService;
  final OfflineSyncService _offlineService;

  static const _uuid = Uuid();

  // ---- Lifecycle ----

  /// 채팅을 초기화한다.
  ///
  /// 1. tripId로 채팅방 조회
  /// 2. 메시지 로드
  /// 3. 고정 메시지 로드
  /// 4. 오프라인 대기 메시지 로드
  /// 5. WebSocket 연결 및 방 입장
  Future<void> initialize(String tripId) async {
    if (!mounted) return;
    state = state.copyWith(isLoading: true, error: null, tripId: tripId);

    try {
      // 1. 채팅방 조회 (trip 기반 첫 번째 방)
      String? roomId;
      try {
        final rooms = await _apiService.getChatRooms(tripId);
        if (rooms.isNotEmpty) {
          roomId = rooms.first['room_id'] as String? ??
              rooms.first['chat_room_id'] as String?;
        }
      } catch (_) {
        // 채팅방 조회 실패 시 tripId를 roomId로 폴백
      }
      roomId ??= tripId;

      if (!mounted) return;
      state = state.copyWith(roomId: roomId);

      // 2~4. 병렬 로드
      await Future.wait([
        _loadMessages(roomId),
        _loadPinnedMessages(roomId),
        _loadPendingMessages(),
      ]);

      // 5. WebSocket 연결
      _setupWebSocket(roomId);
    } catch (e) {
      debugPrint('[ChatProvider] 초기화 오류: $e');
      if (mounted) {
        state = state.copyWith(
          error: '채팅을 불러올 수 없습니다',
          isLoading: false,
        );
      }
    }
  }

  /// 메시지를 전송한다.
  ///
  /// [isOnline]이 false이면 오프라인 큐에만 저장한다.
  /// 온라인일 때는 REST API로 전송 후 서버 응답 메시지를 목록에 추가한다.
  /// WebSocket `newMessage` 이벤트로 중복 수신될 수 있으므로,
  /// [_onNewMessage]에서 sender_id 기반 중복 방지를 처리한다.
  Future<bool> sendMessage(
    String content, {
    String messageType = 'text',
    bool isOnline = true,
  }) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return false;

    final senderId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final localId = _uuid.v4();
    final roomId = state.roomId;
    final tripId = state.tripId;

    if (!isOnline || roomId == null) {
      // 오프라인: SQLite 큐에 저장
      final success = await _offlineService.pushChat(
        tripId: tripId ?? roomId ?? '',
        senderId: senderId,
        content: trimmed,
        localId: localId,
        messageType: messageType,
      );
      if (mounted) {
        await _loadPendingMessages();
      }
      return success;
    }

    // 온라인: REST API 전송
    if (mounted) state = state.copyWith(isSending: true);

    try {
      final result = await _apiService.sendChatMessage(
        roomId: roomId,
        content: trimmed,
        messageType: messageType,
      );

      if (result != null && mounted) {
        // 낙관적 업데이트 — 서버 응답 메시지를 목록 앞에 추가
        final optimistic = <String, dynamic>{
          ...result,
          'sender_id': senderId,
          'content': trimmed,
          'message_type': messageType,
          'created_at': DateTime.now().toUtc().toIso8601String(),
          '_local_id': localId,
        };
        state = state.copyWith(
          messages: [optimistic, ...state.messages],
          isSending: false,
        );
        return true;
      }

      if (mounted) state = state.copyWith(isSending: false);
      return false;
    } catch (e) {
      debugPrint('[ChatProvider] 메시지 전송 실패 — 오프라인 큐 폴백: $e');
      // 전송 실패 시 오프라인 큐에 저장
      await _offlineService.pushChat(
        tripId: tripId ?? roomId,
        senderId: senderId,
        content: trimmed,
        localId: localId,
        messageType: messageType,
      );
      if (mounted) {
        await _loadPendingMessages();
        state = state.copyWith(isSending: false);
      }
      return false;
    }
  }

  /// 메시지 목록을 새로고침한다 (pull-to-refresh 등).
  Future<void> refresh() async {
    final roomId = state.roomId;
    if (roomId == null) return;

    await Future.wait([
      _loadMessages(roomId),
      _loadPinnedMessages(roomId),
      _loadPendingMessages(),
    ]);
  }

  /// 읽음 처리를 서버에 알린다.
  Future<void> markAsRead() async {
    final roomId = state.roomId;
    if (roomId == null || state.messages.isEmpty) return;

    final lastMsgId = state.messages.first['message_id'] as String? ??
        state.messages.first['chat_message_id'] as String?;
    if (lastMsgId == null) return;

    try {
      await _apiService.markChatRead(
        roomId: roomId,
        lastReadMessageId: lastMsgId,
      );
    } catch (e) {
      debugPrint('[ChatProvider] 읽음 처리 실패: $e');
    }
  }

  /// 리소스를 정리한다 (화면 이탈 시 호출).
  @override
  void dispose() {
    _wsService.dispose();
    super.dispose();
  }

  // ---- Private: Data loading ----

  Future<void> _loadMessages(String roomId) async {
    try {
      final messages = await _apiService.getChatMessages(roomId, limit: 50);
      if (mounted) {
        state = state.copyWith(messages: messages, isLoading: false);
      }
    } catch (e) {
      debugPrint('[ChatProvider] 메시지 로드 실패: $e');
      if (mounted) state = state.copyWith(isLoading: false);
    }
  }

  Future<void> _loadPinnedMessages(String roomId) async {
    try {
      final pinned = await _apiService.getPinnedMessages(roomId);
      if (mounted) {
        state = state.copyWith(pinnedMessages: pinned);
      }
    } catch (e) {
      debugPrint('[ChatProvider] 고정 메시지 로드 실패: $e');
      if (mounted) {
        state = state.copyWith(pinnedMessages: const []);
      }
    }
  }

  Future<void> _loadPendingMessages() async {
    try {
      final pending = await _offlineService.getPendingChats(limit: 100);
      if (mounted) {
        state = state.copyWith(pendingMessages: pending);
      }
    } catch (e) {
      debugPrint('[ChatProvider] 대기 메시지 로드 실패: $e');
    }
  }

  // ---- Private: WebSocket ----

  void _setupWebSocket(String roomId) {
    // 콜백 등록
    _wsService.onNewMessage = _onNewMessage;
    _wsService.onUserJoined = _onUserJoined;
    _wsService.onUserLeft = _onUserLeft;

    // 서버 연결 — ApiService의 baseUrl 사용
    _wsService.connect(_apiService.baseUrl).then((_) {
      _wsService.joinRoom(roomId);
    }).catchError((e) {
      debugPrint('[ChatProvider] WebSocket 연결 실패: $e');
    });
  }

  /// WebSocket으로 새 메시지가 수신되었을 때의 처리.
  ///
  /// 중복 방지: 동일한 message_id가 이미 목록에 있으면 무시한다.
  /// 자신이 보낸 메시지는 [sendMessage]에서 낙관적으로 추가했으므로,
  /// _local_id 또는 message_id로 중복 여부를 판단한다.
  void _onNewMessage(Map<String, dynamic> msg) {
    if (!mounted) return;

    final msgId = msg['message_id'] as String? ??
        msg['chat_message_id'] as String?;
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final senderId = msg['sender_id'] as String?;

    // 자신이 보낸 메시지 → 이미 낙관적 추가되었으므로 업데이트만
    if (senderId == currentUserId && msgId != null) {
      final existingIndex = state.messages.indexWhere((m) {
        final mId = m['message_id'] as String? ??
            m['chat_message_id'] as String?;
        return mId == msgId;
      });
      if (existingIndex >= 0) {
        // 이미 존재 — 서버 데이터로 교체
        final updated = List<Map<String, dynamic>>.from(state.messages);
        updated[existingIndex] = msg;
        state = state.copyWith(messages: updated);
        return;
      }
    }

    // 중복 확인
    if (msgId != null) {
      final alreadyExists = state.messages.any((m) {
        final mId = m['message_id'] as String? ??
            m['chat_message_id'] as String?;
        return mId == msgId;
      });
      if (alreadyExists) return;
    }

    // 새 메시지를 목록 앞에 추가
    state = state.copyWith(messages: [msg, ...state.messages]);
  }

  void _onUserJoined(Map<String, dynamic> data) {
    debugPrint('[ChatProvider] 유저 입장: ${data['userId']}');
    // 향후 참여자 목록 UI 업데이트에 사용 가능
  }

  void _onUserLeft(Map<String, dynamic> data) {
    debugPrint('[ChatProvider] 유저 퇴장: ${data['userId']}');
    // 향후 참여자 목록 UI 업데이트에 사용 가능
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

/// 채팅 상태 관리 프로바이더.
///
/// `autoDispose`를 사용하여 화면 이탈 시 자동으로 WebSocket 연결을 해제한다.
final chatProvider =
    StateNotifierProvider.autoDispose<ChatNotifier, ChatState>(
  (ref) => ChatNotifier(),
);
