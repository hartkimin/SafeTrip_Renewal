import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

/// 실시간 채팅을 위한 Socket.IO 클라이언트 서비스.
///
/// 백엔드 `/chat` 네임스페이스에 연결하여 실시간 메시지 수신,
/// 유저 입장/퇴장 알림을 처리한다.
///
/// 이벤트 매핑 (backend ChatsGateway):
///   emit  : `joinRoom`, `leaveRoom`, `sendMessage`
///   listen: `newMessage`, `userJoined`, `userLeft`
class ChatWebSocketService {
  ChatWebSocketService();

  io.Socket? _socket;
  String? _currentRoomId;

  /// 외부에서 등록하는 콜백
  void Function(Map<String, dynamic> message)? onNewMessage;
  void Function(Map<String, dynamic> data)? onUserJoined;
  void Function(Map<String, dynamic> data)? onUserLeft;

  /// 현재 연결 상태
  bool get isConnected => _socket?.connected ?? false;

  /// 현재 접속 중인 방 ID
  String? get currentRoomId => _currentRoomId;

  /// Socket.IO 서버에 연결한다.
  ///
  /// [serverUrl]은 API 서버의 base URL (예: `http://10.0.2.2:3001`).
  /// `/chat` 네임스페이스에 자동 연결된다.
  /// Firebase ID 토큰을 auth 쿼리 파라미터로 전달한다.
  Future<void> connect(String serverUrl) async {
    // 이미 연결되어 있으면 중복 연결 방지
    if (_socket != null && _socket!.connected) {
      debugPrint('[ChatWS] 이미 연결되어 있음 — 스킵');
      return;
    }

    // Firebase ID 토큰 가져오기 (인증용)
    String? idToken;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        idToken = await user.getIdToken();
      }
    } catch (e) {
      debugPrint('[ChatWS] Firebase 토큰 가져오기 실패: $e');
    }

    // URL에 /chat 네임스페이스 추가
    final wsUrl = serverUrl.endsWith('/')
        ? '${serverUrl}chat'
        : '$serverUrl/chat';

    debugPrint('[ChatWS] 연결 시도: $wsUrl');

    _socket = io.io(
      wsUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setExtraHeaders(
            idToken != null ? {'Authorization': 'Bearer $idToken'} : {},
          )
          .setQuery(idToken != null ? {'token': idToken} : {})
          .enableReconnection()
          .setReconnectionAttempts(10)
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(5000)
          .build(),
    );

    // 연결 이벤트 리스너
    _socket!.onConnect((_) {
      debugPrint('[ChatWS] 연결 성공');
      // 이전에 접속해 있던 방이 있으면 자동 재입장
      if (_currentRoomId != null) {
        _emitJoinRoom(_currentRoomId!);
      }
    });

    _socket!.onDisconnect((_) {
      debugPrint('[ChatWS] 연결 해제');
    });

    _socket!.onConnectError((error) {
      debugPrint('[ChatWS] 연결 오류: $error');
    });

    _socket!.onReconnect((_) {
      debugPrint('[ChatWS] 재연결 성공');
      // 재연결 시 방 자동 재입장
      if (_currentRoomId != null) {
        _emitJoinRoom(_currentRoomId!);
      }
    });

    _socket!.onReconnectAttempt((attempt) {
      debugPrint('[ChatWS] 재연결 시도: $attempt');
    });

    _socket!.onReconnectError((error) {
      debugPrint('[ChatWS] 재연결 오류: $error');
    });

    // 비즈니스 이벤트 리스너
    _socket!.on('newMessage', (data) {
      debugPrint('[ChatWS] 새 메시지 수신');
      if (data is Map<String, dynamic>) {
        onNewMessage?.call(data);
      } else if (data is Map) {
        onNewMessage?.call(Map<String, dynamic>.from(data));
      }
    });

    _socket!.on('userJoined', (data) {
      debugPrint('[ChatWS] 유저 입장: $data');
      if (data is Map<String, dynamic>) {
        onUserJoined?.call(data);
      } else if (data is Map) {
        onUserJoined?.call(Map<String, dynamic>.from(data));
      }
    });

    _socket!.on('userLeft', (data) {
      debugPrint('[ChatWS] 유저 퇴장: $data');
      if (data is Map<String, dynamic>) {
        onUserLeft?.call(data);
      } else if (data is Map) {
        onUserLeft?.call(Map<String, dynamic>.from(data));
      }
    });

    // 연결 시작
    _socket!.connect();
  }

  /// 채팅방에 입장한다.
  ///
  /// 이전 방에 있었다면 먼저 퇴장 후 새 방에 입장한다.
  void joinRoom(String roomId) {
    if (_currentRoomId == roomId) {
      debugPrint('[ChatWS] 이미 해당 방에 접속 중: $roomId');
      return;
    }

    // 이전 방 퇴장
    if (_currentRoomId != null) {
      leaveRoom(_currentRoomId!);
    }

    _currentRoomId = roomId;

    if (_socket != null && _socket!.connected) {
      _emitJoinRoom(roomId);
    }
    // 연결되지 않은 상태라면 _currentRoomId만 설정해 두고,
    // onConnect / onReconnect 시 자동 입장
  }

  /// 채팅방에서 퇴장한다.
  void leaveRoom(String roomId) {
    if (_socket != null && _socket!.connected) {
      final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
      _socket!.emit('leaveRoom', {
        'roomId': roomId,
        'userId': userId,
      });
      debugPrint('[ChatWS] 방 퇴장: $roomId');
    }

    if (_currentRoomId == roomId) {
      _currentRoomId = null;
    }
  }

  /// WebSocket을 통해 메시지를 전송한다.
  ///
  /// REST API를 통한 전송이 기본이지만, 실시간성이 필요한 경우
  /// WebSocket으로 직접 전송할 수 있다.
  /// 서버는 `sendMessage` 이벤트를 받아 DB에 저장하고
  /// 방 전체에 `newMessage`를 브로드캐스트한다.
  void sendMessage({
    required String roomId,
    required String senderId,
    required String content,
  }) {
    if (_socket == null || !_socket!.connected) {
      debugPrint('[ChatWS] 연결되지 않아 메시지 전송 불가');
      return;
    }

    _socket!.emit('sendMessage', {
      'roomId': roomId,
      'senderId': senderId,
      'content': content,
    });
    debugPrint('[ChatWS] 메시지 전송: roomId=$roomId');
  }

  /// 소켓 연결을 해제하고 리소스를 정리한다.
  void dispose() {
    if (_currentRoomId != null) {
      leaveRoom(_currentRoomId!);
    }
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _currentRoomId = null;
    onNewMessage = null;
    onUserJoined = null;
    onUserLeft = null;
    debugPrint('[ChatWS] 리소스 해제 완료');
  }

  // ---- Private helpers ----

  void _emitJoinRoom(String roomId) {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    _socket?.emit('joinRoom', {
      'roomId': roomId,
      'userId': userId,
    });
    debugPrint('[ChatWS] 방 입장: $roomId (userId=$userId)');
  }
}
