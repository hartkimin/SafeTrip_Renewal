# Chat Tab Phase 1~3 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement the full chat tab (Phase 1~3) per DOC-T3-CHT-020 v1.1, extending the existing ChatsModule with system messages, rich cards, polls, guardian channels, search, reactions, and file attachments.

**Architecture:** Extend existing NestJS `ChatsModule` (REST + WebSocket) and Flutter `BottomSheetChat`. New services: `SystemMessageService` (auto-insert), `PollService` (vote CRUD), `GuardianChatsModule` (1:1 channels). Frontend refactored to render multiple message types with Riverpod state management.

**Tech Stack:** NestJS/TypeORM/PostgreSQL (backend), Flutter/Riverpod/Socket.io (frontend), Firebase Auth/FCM/Storage

---

## Task 1: Phase 1 Backend — SystemMessageService + Extended sendMessage

**Files:**
- Create: `safetrip-server-api/src/modules/chats/system-message.service.ts`
- Modify: `safetrip-server-api/src/modules/chats/chats.service.ts`
- Modify: `safetrip-server-api/src/modules/chats/chats.module.ts`
- Modify: `safetrip-server-api/src/entities/chat.entity.ts`

**Step 1: Create SystemMessageService**

This service auto-inserts system messages into group chat when events occur. Other modules (emergencies, groups, trips) will call it.

```typescript
// safetrip-server-api/src/modules/chats/system-message.service.ts
import { Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { ChatMessage, ChatRoom } from '../../entities/chat.entity';
import { NotificationsService } from '../notifications/notifications.service';

export type SystemEventType =
    | 'member_join' | 'member_leave' | 'member_kicked'
    | 'role_change' | 'leader_transfer'
    | 'trip_start' | 'trip_end'
    | 'sos_alert' | 'sos_cancel'
    | 'attendance_start' | 'attendance_complete'
    | 'privacy_change' | 'schedule_change'
    | 'guardian_add' | 'guardian_remove'
    | 'pin_add' | 'pin_remove';

export type SystemEventLevel = 'INFO' | 'SCHEDULE' | 'WARNING' | 'CRITICAL' | 'CELEBRATION';

const EVENT_LEVEL_MAP: Record<SystemEventType, SystemEventLevel> = {
    member_join: 'INFO',
    member_leave: 'INFO',
    member_kicked: 'WARNING',
    role_change: 'INFO',
    leader_transfer: 'INFO',
    trip_start: 'CELEBRATION',
    trip_end: 'INFO',
    sos_alert: 'CRITICAL',
    sos_cancel: 'INFO',
    attendance_start: 'INFO',
    attendance_complete: 'INFO',
    privacy_change: 'INFO',
    schedule_change: 'SCHEDULE',
    guardian_add: 'INFO',
    guardian_remove: 'INFO',
    pin_add: 'INFO',
    pin_remove: 'INFO',
};

@Injectable()
export class SystemMessageService {
    private readonly logger = new Logger(SystemMessageService.name);

    constructor(
        @InjectRepository(ChatMessage) private messageRepo: Repository<ChatMessage>,
        @InjectRepository(ChatRoom) private roomRepo: Repository<ChatRoom>,
        private notifService: NotificationsService,
    ) {}

    async insert(tripId: string, eventType: SystemEventType, content: string, extra?: {
        locationData?: any;
        metadata?: any;
    }): Promise<ChatMessage | null> {
        try {
            const room = await this.roomRepo.findOne({
                where: { tripId, roomType: 'group', isActive: true },
            });
            if (!room) {
                this.logger.warn(`No active group room for trip ${tripId}`);
                return null;
            }

            const message = this.messageRepo.create({
                roomId: room.roomId,
                tripId,
                groupId: null,
                senderId: null,
                messageType: 'system',
                content,
                systemEventType: eventType,
                systemEventLevel: EVENT_LEVEL_MAP[eventType] || 'INFO',
                locationData: extra?.locationData,
                metadata: extra?.metadata,
            } as Partial<ChatMessage>);
            return this.messageRepo.save(message);
        } catch (error) {
            this.logger.error(`Failed to insert system message: ${error.message}`);
            return null;
        }
    }

    /** SOS 시스템 메시지 — CRITICAL 레벨, FCM PRIORITY_HIGH */
    async insertSosAlert(tripId: string, userName: string, locationData: {
        latitude: number; longitude: number; address?: string; batteryLevel?: number;
    }): Promise<ChatMessage | null> {
        const content = `${userName}님이 SOS를 발신했습니다.`;
        return this.insert(tripId, 'sos_alert', content, {
            locationData: {
                lat: locationData.latitude,
                lng: locationData.longitude,
                address: locationData.address,
                battery_level: locationData.batteryLevel,
            },
        });
    }

    async insertSosCancel(tripId: string, userName: string): Promise<ChatMessage | null> {
        const content = `${userName}님의 SOS가 해제되었습니다.`;
        return this.insert(tripId, 'sos_cancel', content);
    }
}
```

**Step 2: Extend ChatsService.sendMessage to support all message types**

Modify `chats.service.ts` to accept `mediaUrls`, `locationData`, `cardData`, and `systemEventType`:

```typescript
// In chats.service.ts — replace sendMessage method
async sendMessage(roomId: string, senderId: string, data: {
    messageType?: string;
    content?: string;
    mediaUrls?: any;
    locationData?: any;
    cardData?: any;
}) {
    const room = await this.roomRepo.findOne({ where: { roomId } });
    if (!room) throw new NotFoundException('Chat room not found');

    const message = this.messageRepo.create({
        roomId,
        tripId: room.tripId,
        senderId,
        messageType: data.messageType || 'text',
        content: data.content,
        mediaUrls: data.mediaUrls,
        locationData: data.locationData,
        metadata: data.cardData ? { cardData: data.cardData } : undefined,
    } as Partial<ChatMessage>);
    const saved = await this.messageRepo.save(message);

    this.handleChatNotification(room, senderId, saved).catch(err =>
        console.error('Chat FCM error:', err));

    return saved;
}
```

**Step 3: Update ChatsModule to register SystemMessageService and export it**

```typescript
// chats.module.ts — add SystemMessageService
import { SystemMessageService } from './system-message.service';

@Module({
    imports: [
        TypeOrmModule.forFeature([ChatRoom, ChatMessage, ChatReadStatus, ChatPoll, ChatPollVote, GroupMember, User]),
        NotificationsModule,
    ],
    controllers: [ChatsController],
    providers: [ChatsService, ChatsGateway, SystemMessageService],
    exports: [ChatsService, ChatsGateway, SystemMessageService],
})
export class ChatsModule {}
```

**Step 4: Verify backend compiles**

Run: `cd safetrip-server-api && npx tsc --noEmit 2>&1 | head -20`
Expected: No errors (or only pre-existing warnings)

**Step 5: Commit**

```bash
git add safetrip-server-api/src/modules/chats/system-message.service.ts \
        safetrip-server-api/src/modules/chats/chats.service.ts \
        safetrip-server-api/src/modules/chats/chats.module.ts
git commit -m "feat(chat): add SystemMessageService + extend sendMessage for rich types"
```

---

## Task 2: Phase 1 Backend — Pin/Unpin + Soft Delete + Pinned List APIs

**Files:**
- Modify: `safetrip-server-api/src/modules/chats/chats.controller.ts`
- Modify: `safetrip-server-api/src/modules/chats/chats.service.ts`

**Step 1: Add pin, unpin, pinned list, and delete endpoints to controller**

```typescript
// Add to chats.controller.ts

@Patch('messages/:messageId/pin')
@ApiOperation({ summary: '메시지 공지 고정 (캡틴/크루장, 최대 3건)' })
pinMessage(
    @CurrentUser() userId: string,
    @Param('messageId') messageId: string,
) {
    return this.chatsService.pinMessage(messageId, userId);
}

@Delete('messages/:messageId/pin')
@ApiOperation({ summary: '공지 고정 해제 (캡틴/크루장)' })
unpinMessage(
    @CurrentUser() userId: string,
    @Param('messageId') messageId: string,
) {
    return this.chatsService.unpinMessage(messageId, userId);
}

@Get('rooms/:roomId/pinned')
@ApiOperation({ summary: '고정 공지 목록 (최대 3건)' })
getPinnedMessages(@Param('roomId') roomId: string) {
    return this.chatsService.getPinnedMessages(roomId);
}

@Delete('messages/:messageId')
@ApiOperation({ summary: '메시지 삭제 (소프트 삭제)' })
deleteMessage(
    @CurrentUser() userId: string,
    @Param('messageId') messageId: string,
) {
    return this.chatsService.deleteMessage(messageId, userId);
}
```

**Step 2: Add pin/unpin/delete service methods**

```typescript
// Add to chats.service.ts

async pinMessage(messageId: string, userId: string) {
    const message = await this.messageRepo.findOne({ where: { messageId } });
    if (!message) throw new NotFoundException('Message not found');

    // Check captain/crew_chief role
    await this.assertLeaderRole(message.tripId, userId);

    // Max 3 pinned check
    const pinnedCount = await this.messageRepo.count({
        where: { roomId: message.roomId, isPinned: true },
    });
    if (pinnedCount >= 3) {
        throw new BadRequestException('현재 공지가 3건 가득 찼습니다. 기존 공지를 해제한 후 새 공지를 추가하세요.');
    }

    await this.messageRepo.update(messageId, {
        isPinned: true,
        pinnedBy: userId,
    });

    // System message for pin
    if (this.systemMessageService) {
        const user = await this.userRepo.findOne({ where: { userId } });
        await this.systemMessageService.insert(
            message.tripId,
            'pin_add',
            `${user?.displayName || '멤버'}님이 메시지를 공지로 고정했습니다.`,
        );
    }

    return this.messageRepo.findOne({ where: { messageId } });
}

async unpinMessage(messageId: string, userId: string) {
    const message = await this.messageRepo.findOne({ where: { messageId } });
    if (!message) throw new NotFoundException('Message not found');

    await this.assertLeaderRole(message.tripId, userId);

    // SOS system messages cannot be unpinned
    if (message.systemEventLevel === 'CRITICAL') {
        throw new BadRequestException('SOS 기록은 고정 해제할 수 없습니다.');
    }

    await this.messageRepo.update(messageId, {
        isPinned: false,
        pinnedBy: null,
    });

    if (this.systemMessageService) {
        const user = await this.userRepo.findOne({ where: { userId } });
        await this.systemMessageService.insert(
            message.tripId,
            'pin_remove',
            `${user?.displayName || '멤버'}님이 공지를 해제했습니다.`,
        );
    }

    return { success: true };
}

async getPinnedMessages(roomId: string) {
    return this.messageRepo.find({
        where: { roomId, isPinned: true, isDeleted: false },
        order: { sentAt: 'DESC' },
        take: 3,
    });
}

async deleteMessage(messageId: string, userId: string) {
    const message = await this.messageRepo.findOne({ where: { messageId } });
    if (!message) throw new NotFoundException('Message not found');

    // SOS cannot be deleted (§12.2)
    if (message.systemEventLevel === 'CRITICAL') {
        throw new BadRequestException('SOS 기록은 삭제할 수 없습니다.');
    }

    // Pinned messages: unpin first
    if (message.isPinned) {
        throw new BadRequestException('공지 해제 후 삭제 가능합니다.');
    }

    // Captain can delete any; others only their own
    const isSender = message.senderId === userId;
    if (!isSender) {
        await this.assertCaptainRole(message.tripId, userId);
    }

    await this.messageRepo.update(messageId, {
        isDeleted: true,
        deletedBy: userId,
        content: '삭제된 메시지입니다',
    });

    return { success: true };
}

/** Check captain or crew_chief role */
private async assertLeaderRole(tripId: string, userId: string) {
    const member = await this.memberRepo.findOne({
        where: { tripId, userId, status: 'active' },
    });
    if (!member || !['captain', 'crew_chief'].includes(member.memberRole)) {
        throw new ForbiddenException('캡틴 또는 크루장만 이 작업을 수행할 수 있습니다.');
    }
}

private async assertCaptainRole(tripId: string, userId: string) {
    const member = await this.memberRepo.findOne({
        where: { tripId, userId, memberRole: 'captain', status: 'active' },
    });
    if (!member) {
        throw new ForbiddenException('캡틴만 이 작업을 수행할 수 있습니다.');
    }
}
```

**Step 3: Inject SystemMessageService into ChatsService**

Add `private systemMessageService: SystemMessageService` to ChatsService constructor. Import `BadRequestException, ForbiddenException` from `@nestjs/common`.

**Step 4: Verify backend compiles**

Run: `cd safetrip-server-api && npx tsc --noEmit 2>&1 | head -20`

**Step 5: Commit**

```bash
git add safetrip-server-api/src/modules/chats/chats.controller.ts \
        safetrip-server-api/src/modules/chats/chats.service.ts
git commit -m "feat(chat): add pin/unpin/delete APIs with role-based access control"
```

---

## Task 3: Phase 1 Backend — Hook SOS into SystemMessageService

**Files:**
- Modify: `safetrip-server-api/src/modules/emergencies/emergencies.module.ts`
- Modify: `safetrip-server-api/src/modules/emergencies/emergencies.service.ts`

**Step 1: Import ChatsModule in EmergenciesModule**

```typescript
// emergencies.module.ts — add to imports
import { ChatsModule } from '../chats/chats.module';
// Add ChatsModule to imports array
```

**Step 2: Inject SystemMessageService into EmergenciesService**

```typescript
// emergencies.service.ts — add to constructor
import { SystemMessageService } from '../chats/system-message.service';

constructor(
    // ... existing injections ...
    private systemMessageService: SystemMessageService,
) {}
```

**Step 3: Call insertSosAlert in createEmergency**

After `await this.sosRepo.save(sos)` in the `createEmergency` method, add:

```typescript
// Insert SOS system message to group chat
const sender = await this.userRepo.findOne({ where: { userId } });
await this.systemMessageService.insertSosAlert(tripId, sender?.displayName || 'Traveler', {
    latitude: data.latitude || 0,
    longitude: data.longitude || 0,
    address: data.description,
    batteryLevel: undefined,
});
```

**Step 4: Call insertSosCancel in resolveEmergency**

After the resolve logic, add:

```typescript
// Insert SOS cancel system message
const senderUser = await this.userRepo.findOne({ where: { userId: emergency.userId } });
await this.systemMessageService.insertSosCancel(
    emergency.tripId,
    senderUser?.displayName || 'Traveler',
);
```

**Step 5: Verify and commit**

```bash
cd safetrip-server-api && npx tsc --noEmit 2>&1 | head -20
git add safetrip-server-api/src/modules/emergencies/
git commit -m "feat(chat): hook SOS create/resolve into SystemMessageService (CRITICAL)"
```

---

## Task 4: Phase 1 Frontend — Flutter Chat Provider + WebSocket Service

**Files:**
- Create: `safetrip-mobile/lib/features/chat/providers/chat_provider.dart`
- Create: `safetrip-mobile/lib/features/chat/services/chat_websocket_service.dart`

**Step 1: Create ChatWebSocketService**

```dart
// safetrip-mobile/lib/features/chat/services/chat_websocket_service.dart
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:firebase_auth/firebase_auth.dart';
import '../../../services/api_service.dart';

class ChatWebSocketService {
  IO.Socket? _socket;
  String? _currentRoomId;
  Function(Map<String, dynamic>)? onNewMessage;
  Function(String)? onUserJoined;
  Function(String)? onUserLeft;

  void connect(String serverUrl) {
    _socket = IO.io(
      '$serverUrl/chat',
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build(),
    );

    _socket!.onConnect((_) {
      if (_currentRoomId != null) {
        _joinRoom(_currentRoomId!);
      }
    });

    _socket!.on('newMessage', (data) {
      if (data is Map<String, dynamic>) {
        onNewMessage?.call(data);
      }
    });

    _socket!.on('userJoined', (data) {
      if (data is Map<String, dynamic>) {
        onUserJoined?.call(data['userId'] as String? ?? '');
      }
    });

    _socket!.on('userLeft', (data) {
      if (data is Map<String, dynamic>) {
        onUserLeft?.call(data['userId'] as String? ?? '');
      }
    });

    _socket!.connect();
  }

  void joinRoom(String roomId) {
    _currentRoomId = roomId;
    if (_socket?.connected == true) {
      _joinRoom(roomId);
    }
  }

  void _joinRoom(String roomId) {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    _socket?.emit('joinRoom', {'roomId': roomId, 'userId': userId});
  }

  void leaveRoom(String roomId) {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    _socket?.emit('leaveRoom', {'roomId': roomId, 'userId': userId});
    _currentRoomId = null;
  }

  void dispose() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }
}
```

**Step 2: Create ChatProvider (Riverpod StateNotifier)**

```dart
// safetrip-mobile/lib/features/chat/providers/chat_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../services/api_service.dart';
import '../../../services/offline_sync_service.dart';
import '../services/chat_websocket_service.dart';

class ChatState {
  final List<Map<String, dynamic>> messages;
  final List<Map<String, dynamic>> pendingMessages;
  final List<Map<String, dynamic>> pinnedMessages;
  final String? roomId;
  final bool isLoading;
  final bool isSending;

  const ChatState({
    this.messages = const [],
    this.pendingMessages = const [],
    this.pinnedMessages = const [],
    this.roomId,
    this.isLoading = true,
    this.isSending = false,
  });

  ChatState copyWith({
    List<Map<String, dynamic>>? messages,
    List<Map<String, dynamic>>? pendingMessages,
    List<Map<String, dynamic>>? pinnedMessages,
    String? roomId,
    bool? isLoading,
    bool? isSending,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      pendingMessages: pendingMessages ?? this.pendingMessages,
      pinnedMessages: pinnedMessages ?? this.pinnedMessages,
      roomId: roomId ?? this.roomId,
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
    );
  }
}

class ChatNotifier extends StateNotifier<ChatState> {
  final ApiService _api = ApiService();
  final ChatWebSocketService _ws = ChatWebSocketService();

  ChatNotifier() : super(const ChatState());

  Future<void> initialize(String tripId) async {
    try {
      final rooms = await _api.getChatRooms(tripId);
      String? roomId;
      if (rooms.isNotEmpty) {
        roomId = rooms.first['room_id'] as String? ??
            rooms.first['chat_room_id'] as String?;
      }
      roomId ??= tripId;

      state = state.copyWith(roomId: roomId);

      // Load messages + pinned + pending in parallel
      await Future.wait([
        _loadMessages(roomId),
        _loadPinnedMessages(roomId),
        _loadPendingMessages(),
      ]);

      // Connect WebSocket
      _ws.onNewMessage = _onNewMessage;
      _ws.connect(_api.baseUrl);
      _ws.joinRoom(roomId);
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> _loadMessages(String roomId) async {
    try {
      final messages = await _api.getChatMessages(roomId, limit: 50);
      state = state.copyWith(messages: messages, isLoading: false);
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> _loadPinnedMessages(String roomId) async {
    try {
      final response = await _api.request('GET', '/api/v1/chats/rooms/$roomId/pinned');
      if (response != null && response is List) {
        state = state.copyWith(pinnedMessages: List<Map<String, dynamic>>.from(response));
      }
    } catch (_) {}
  }

  Future<void> _loadPendingMessages() async {
    final pending = await OfflineSyncService().getPendingChats(limit: 100);
    state = state.copyWith(pendingMessages: pending);
  }

  void _onNewMessage(Map<String, dynamic> msg) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    // Skip if it's our own message (already added locally)
    if (msg['sender_id'] == currentUserId) return;
    state = state.copyWith(messages: [msg, ...state.messages]);
  }

  Future<bool> sendMessage(String content, {
    String messageType = 'text',
    Map<String, dynamic>? locationData,
    Map<String, dynamic>? cardData,
    bool isOnline = true,
  }) async {
    if (state.roomId == null) return false;

    if (!isOnline) {
      final tripId = state.roomId!;
      final senderId = FirebaseAuth.instance.currentUser?.uid ?? '';
      await OfflineSyncService().pushChat(
        tripId: tripId, senderId: senderId,
        content: content, localId: DateTime.now().millisecondsSinceEpoch.toString(),
      );
      await _loadPendingMessages();
      return true;
    }

    state = state.copyWith(isSending: true);
    try {
      final result = await _api.sendChatMessage(
        roomId: state.roomId!,
        content: content,
        messageType: messageType,
      );
      if (result != null) {
        state = state.copyWith(
          messages: [result, ...state.messages],
          isSending: false,
        );
      }
      return true;
    } catch (_) {
      state = state.copyWith(isSending: false);
      return false;
    }
  }

  void dispose() {
    if (state.roomId != null) {
      _ws.leaveRoom(state.roomId!);
    }
    _ws.dispose();
    super.dispose();
  }
}

final chatProvider = StateNotifierProvider.autoDispose<ChatNotifier, ChatState>((ref) {
  return ChatNotifier();
});
```

**Step 3: Verify Flutter compiles**

Run: `cd safetrip-mobile && flutter analyze lib/features/chat/ 2>&1 | tail -5`
Note: `socket_io_client` package may need to be added to pubspec.yaml first:
```bash
cd safetrip-mobile && flutter pub add socket_io_client
```

**Step 4: Commit**

```bash
git add safetrip-mobile/lib/features/chat/
git commit -m "feat(chat): add ChatProvider + WebSocket service for real-time messaging"
```

---

## Task 5: Phase 1 Frontend — Refactor BottomSheetChat with Rich Message Types

**Files:**
- Modify: `safetrip-mobile/lib/screens/main/bottom_sheets/bottom_sheet_3_chat.dart`
- Create: `safetrip-mobile/lib/features/chat/widgets/chat_message_bubble.dart`
- Create: `safetrip-mobile/lib/features/chat/widgets/system_message_widget.dart`
- Create: `safetrip-mobile/lib/features/chat/widgets/sos_card_widget.dart`
- Create: `safetrip-mobile/lib/features/chat/widgets/location_card_widget.dart`
- Create: `safetrip-mobile/lib/features/chat/widgets/pinned_notices_widget.dart`
- Create: `safetrip-mobile/lib/features/chat/widgets/date_divider_widget.dart`
- Create: `safetrip-mobile/lib/features/chat/widgets/attachment_menu_widget.dart`

**Step 1: Create message type widgets**

Each widget renders a specific message type. Key widgets:

`date_divider_widget.dart` — "오늘", "어제", "3월 15일" centered gray text
`system_message_widget.dart` — centered gray background text for system events
`sos_card_widget.dart` — CRITICAL red card with location, battery, action buttons
`location_card_widget.dart` — mini map placeholder + address + "지도에서 보기"
`pinned_notices_widget.dart` — up to 3 pinned notices at chat top
`attachment_menu_widget.dart` — [+] button bottom sheet (photo, location, schedule, file)
`chat_message_bubble.dart` — unified bubble for text/image with read status (✅/✓/⏳)

**Step 2: Refactor BottomSheetChat to use ChatProvider**

Replace local state (`_messages`, `_pendingMessages`) with `ref.watch(chatProvider)`. Replace `_buildMessageBubble` with a dispatcher that picks the right widget based on `message_type`:

```dart
Widget _buildMessageWidget(Map<String, dynamic> msg) {
  final type = msg['message_type'] as String? ?? 'text';
  final eventLevel = msg['system_event_level'] as String?;

  if (type == 'system') {
    if (eventLevel == 'CRITICAL') {
      return SosCardWidget(message: msg);
    }
    return SystemMessageWidget(content: msg['content'] as String? ?? '');
  }
  if (type == 'location') {
    return LocationCardWidget(locationData: msg['location_data']);
  }
  // Default: text/image bubble
  return ChatMessageBubble(
    message: msg,
    isMe: msg['sender_id'] == _currentUserId,
  );
}
```

**Step 3: Add date dividers between messages**

Insert `DateDividerWidget` whenever the date changes between consecutive messages.

**Step 4: Add read status indicators**

In `ChatMessageBubble`, show:
- ✅ if read (future: check read_status endpoint)
- ✓ if sent
- ⏳ if pending

**Step 5: Add attachment menu**

Replace plain text input with Row containing [+] button that shows `AttachmentMenuWidget` as a bottom sheet.

**Step 6: Verify and commit**

```bash
cd safetrip-mobile && flutter analyze lib/ 2>&1 | tail -10
git add safetrip-mobile/lib/features/chat/widgets/ \
        safetrip-mobile/lib/screens/main/bottom_sheets/bottom_sheet_3_chat.dart
git commit -m "feat(chat): refactor chat UI with rich message types, date dividers, read status"
```

---

## Task 6: Phase 1 Frontend — API Service Extensions for Chat

**Files:**
- Modify: `safetrip-mobile/lib/services/api_service.dart`

**Step 1: Add new chat API methods**

```dart
// Add to api_service.dart

/// Pin/unpin messages
Future<Map<String, dynamic>?> pinChatMessage(String messageId) async {
  return await _patch('/api/v1/chats/messages/$messageId/pin', {});
}

Future<bool> unpinChatMessage(String messageId) async {
  final result = await _delete('/api/v1/chats/messages/$messageId/pin');
  return result != null;
}

Future<List<Map<String, dynamic>>> getPinnedMessages(String roomId) async {
  return await _getList('/api/v1/chats/rooms/$roomId/pinned');
}

/// Delete message
Future<bool> deleteChatMessage(String messageId) async {
  final result = await _delete('/api/v1/chats/messages/$messageId');
  return result != null;
}

/// Send message with type
Future<Map<String, dynamic>?> sendChatMessageExtended({
  required String roomId,
  required String content,
  String messageType = 'text',
  Map<String, dynamic>? locationData,
  Map<String, dynamic>? cardData,
}) async {
  return await _post('/api/v1/chats/rooms/$roomId/messages', {
    'content': content,
    'message_type': messageType,
    if (locationData != null) 'location_data': locationData,
    if (cardData != null) 'card_data': cardData,
  });
}
```

**Step 2: Commit**

```bash
git add safetrip-mobile/lib/services/api_service.dart
git commit -m "feat(chat): add pin/unpin/delete/extended-send API methods"
```

---

## Task 7: Phase 2 Backend — Poll CRUD + Auto-Close Scheduler

**Files:**
- Create: `safetrip-server-api/src/modules/chats/poll.service.ts`
- Modify: `safetrip-server-api/src/modules/chats/chats.controller.ts`
- Modify: `safetrip-server-api/src/modules/chats/chats.module.ts`

**Step 1: Create PollService**

```typescript
// safetrip-server-api/src/modules/chats/poll.service.ts
import { Injectable, NotFoundException, BadRequestException, ForbiddenException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, LessThanOrEqual } from 'typeorm';
import { Cron, CronExpression } from '@nestjs/schedule';
import { ChatMessage, ChatRoom, ChatPoll, ChatPollVote } from '../../entities/chat.entity';
import { GroupMember } from '../../entities/group-member.entity';

@Injectable()
export class PollService {
    constructor(
        @InjectRepository(ChatPoll) private pollRepo: Repository<ChatPoll>,
        @InjectRepository(ChatPollVote) private voteRepo: Repository<ChatPollVote>,
        @InjectRepository(ChatMessage) private messageRepo: Repository<ChatMessage>,
        @InjectRepository(ChatRoom) private roomRepo: Repository<ChatRoom>,
        @InjectRepository(GroupMember) private memberRepo: Repository<GroupMember>,
    ) {}

    async createPoll(roomId: string, userId: string, data: {
        title: string; options: { id: number; text: string }[];
        closesAt?: string;
    }) {
        const room = await this.roomRepo.findOne({ where: { roomId } });
        if (!room) throw new NotFoundException('Room not found');

        // Role check
        const member = await this.memberRepo.findOne({
            where: { tripId: room.tripId, userId, status: 'active' },
        });
        if (!member || !['captain', 'crew_chief'].includes(member.memberRole)) {
            throw new ForbiddenException('캡틴 또는 크루장만 투표를 생성할 수 있습니다.');
        }

        // Create message of type 'poll'
        const message = this.messageRepo.create({
            roomId, tripId: room.tripId, senderId: userId,
            messageType: 'poll', content: data.title,
        } as Partial<ChatMessage>);
        const savedMsg = await this.messageRepo.save(message);

        // Create poll record
        const poll = this.pollRepo.create({
            messageId: savedMsg.messageId,
            tripId: room.tripId,
            creatorId: userId,
            title: data.title,
            options: data.options,
            closesAt: data.closesAt ? new Date(data.closesAt) : null,
        });
        return this.pollRepo.save(poll);
    }

    async getPoll(pollId: string) {
        const poll = await this.pollRepo.findOne({ where: { pollId } });
        if (!poll) throw new NotFoundException('Poll not found');

        const votes = await this.voteRepo.find({ where: { pollId } });
        const results = (poll.options as any[]).map((opt: any) => ({
            ...opt,
            count: votes.filter(v => v.selectedOptions.includes(opt.id)).length,
        }));

        return { ...poll, results, totalVotes: votes.length };
    }

    async castVote(pollId: string, userId: string, optionId: number) {
        const poll = await this.pollRepo.findOne({ where: { pollId } });
        if (!poll) throw new NotFoundException('Poll not found');
        if (poll.isClosed) throw new BadRequestException('투표가 종료되었습니다.');
        if (poll.closesAt && new Date() > poll.closesAt) {
            throw new BadRequestException('투표가 종료되었습니다.');
        }

        // Upsert vote
        const existing = await this.voteRepo.findOne({ where: { pollId, userId } });
        if (existing) {
            await this.voteRepo.update(existing.voteId, { selectedOptions: [optionId] });
        } else {
            const vote = this.voteRepo.create({ pollId, userId, selectedOptions: [optionId] });
            await this.voteRepo.save(vote);
        }

        return this.getPoll(pollId);
    }

    async closePoll(pollId: string, userId: string) {
        const poll = await this.pollRepo.findOne({ where: { pollId } });
        if (!poll) throw new NotFoundException('Poll not found');

        const member = await this.memberRepo.findOne({
            where: { tripId: poll.tripId, userId, status: 'active' },
        });
        if (!member || !['captain', 'crew_chief'].includes(member.memberRole)) {
            throw new ForbiddenException('캡틴 또는 크루장만 투표를 종료할 수 있습니다.');
        }

        await this.pollRepo.update(pollId, { isClosed: true, closedBy: userId });
        return this.getPoll(pollId);
    }

    /** Auto-close expired polls every minute */
    @Cron(CronExpression.EVERY_MINUTE)
    async autoCloseExpiredPolls() {
        await this.pollRepo
            .createQueryBuilder()
            .update()
            .set({ isClosed: true })
            .where('is_closed = false AND closes_at <= :now', { now: new Date() })
            .execute();
    }
}
```

**Step 2: Add poll routes to controller**

```typescript
// Add to chats.controller.ts

@Post('rooms/:roomId/polls')
@ApiOperation({ summary: '투표 생성 (캡틴/크루장)' })
createPoll(
    @CurrentUser() userId: string,
    @Param('roomId') roomId: string,
    @Body() body: { title: string; options: any[]; closesAt?: string },
) {
    return this.pollService.createPoll(roomId, userId, body);
}

@Get('polls/:pollId')
@ApiOperation({ summary: '투표 상세 + 결과 조회' })
getPoll(@Param('pollId') pollId: string) {
    return this.pollService.getPoll(pollId);
}

@Post('polls/:pollId/vote')
@ApiOperation({ summary: '투표 응답' })
castVote(
    @CurrentUser() userId: string,
    @Param('pollId') pollId: string,
    @Body() body: { optionId: number },
) {
    return this.pollService.castVote(pollId, userId, body.optionId);
}

@Post('polls/:pollId/close')
@ApiOperation({ summary: '투표 수동 종료 (캡틴/크루장)' })
closePoll(
    @CurrentUser() userId: string,
    @Param('pollId') pollId: string,
) {
    return this.pollService.closePoll(pollId, userId);
}
```

**Step 3: Register PollService in module + inject in controller**

**Step 4: Verify and commit**

```bash
cd safetrip-server-api && npx tsc --noEmit 2>&1 | head -20
git add safetrip-server-api/src/modules/chats/
git commit -m "feat(chat): add Poll CRUD with auto-close scheduler (Phase 2)"
```

---

## Task 8: Phase 2 Backend — Guardian Chat Module

**Files:**
- Create: `safetrip-server-api/sql/12-schema-guardian-message.sql`
- Create: `safetrip-server-api/src/entities/guardian-message.entity.ts`
- Create: `safetrip-server-api/src/modules/guardian-chats/guardian-chats.module.ts`
- Create: `safetrip-server-api/src/modules/guardian-chats/guardian-chats.controller.ts`
- Create: `safetrip-server-api/src/modules/guardian-chats/guardian-chats.service.ts`
- Modify: `safetrip-server-api/src/app.module.ts`

**Step 1: Create SQL migration**

```sql
-- safetrip-server-api/sql/12-schema-guardian-message.sql
CREATE TABLE IF NOT EXISTS tb_guardian_message (
    message_id   BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    trip_id      UUID NOT NULL REFERENCES tb_trip(trip_id),
    link_id      UUID NOT NULL REFERENCES tb_guardian_link(link_id),
    sender_type  VARCHAR(20) NOT NULL CHECK (sender_type IN ('member','guardian')),
    sender_id    VARCHAR(128) NOT NULL REFERENCES tb_user(user_id),
    message_type VARCHAR(20) NOT NULL DEFAULT 'text'
                 CHECK (message_type IN ('text','location_card','system')),
    content      TEXT,
    card_data    JSONB,
    is_read      BOOLEAN DEFAULT FALSE,
    sent_at      TIMESTAMPTZ DEFAULT NOW(),
    created_at   TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_guardian_msg_link ON tb_guardian_message(link_id, sent_at DESC);
CREATE INDEX IF NOT EXISTS idx_guardian_msg_trip ON tb_guardian_message(trip_id);
```

**Step 2: Create TypeORM entity**

```typescript
// safetrip-server-api/src/entities/guardian-message.entity.ts
import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn, Index } from 'typeorm';

@Entity('tb_guardian_message')
@Index('idx_guardian_msg_link', ['linkId', 'sentAt'])
export class GuardianMessage {
    @PrimaryGeneratedColumn('increment', { name: 'message_id', type: 'bigint' })
    messageId: string;

    @Column({ name: 'trip_id', type: 'uuid' })
    tripId: string;

    @Column({ name: 'link_id', type: 'uuid' })
    linkId: string;

    @Column({ name: 'sender_type', type: 'varchar', length: 20 })
    senderType: string; // 'member' | 'guardian'

    @Column({ name: 'sender_id', type: 'varchar', length: 128 })
    senderId: string;

    @Column({ name: 'message_type', type: 'varchar', length: 20, default: 'text' })
    messageType: string; // 'text' | 'location_card' | 'system'

    @Column({ name: 'content', type: 'text', nullable: true })
    content: string | null;

    @Column({ name: 'card_data', type: 'jsonb', nullable: true })
    cardData: any;

    @Column({ name: 'is_read', type: 'boolean', default: false })
    isRead: boolean;

    @CreateDateColumn({ name: 'sent_at', type: 'timestamptz' })
    sentAt: Date;

    @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
    createdAt: Date;
}
```

**Step 3: Create GuardianChatsService**

```typescript
// safetrip-server-api/src/modules/guardian-chats/guardian-chats.service.ts
import { Injectable, NotFoundException, ForbiddenException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, LessThan } from 'typeorm';
import { GuardianMessage } from '../../entities/guardian-message.entity';
import { GuardianLink } from '../../entities/guardian.entity';
import { GroupMember } from '../../entities/group-member.entity';
import { NotificationsService } from '../notifications/notifications.service';

@Injectable()
export class GuardianChatsService {
    constructor(
        @InjectRepository(GuardianMessage) private msgRepo: Repository<GuardianMessage>,
        @InjectRepository(GuardianLink) private linkRepo: Repository<GuardianLink>,
        @InjectRepository(GroupMember) private memberRepo: Repository<GroupMember>,
        private notifService: NotificationsService,
    ) {}

    /** List guardian channels for a user in a trip */
    async getChannels(tripId: string, userId: string) {
        // Find links where user is either member or guardian
        const links = await this.linkRepo.find({
            where: [
                { tripId, memberId: userId, status: 'accepted' },
                { tripId, guardianId: userId, status: 'accepted' },
            ],
        });
        return links;
    }

    async getMessages(linkId: string, userId: string, cursor?: string, limit = 50) {
        // Verify access
        await this.assertChannelAccess(linkId, userId);

        const where: any = { linkId };
        if (cursor) {
            where.sentAt = LessThan(new Date(cursor));
        }
        return this.msgRepo.find({
            where,
            order: { sentAt: 'DESC' },
            take: limit,
        });
    }

    async sendMessage(linkId: string, userId: string, data: {
        content?: string; messageType?: string; cardData?: any;
    }) {
        const link = await this.assertChannelAccess(linkId, userId);

        // Determine sender type
        const senderType = link.memberId === userId ? 'member' : 'guardian';

        // Free guardian: block location_card sending
        if (senderType === 'guardian' && !link.isPaid && data.messageType === 'location_card') {
            throw new ForbiddenException('무료 가디언은 위치 카드를 수신할 수 없습니다.');
        }

        const message = this.msgRepo.create({
            tripId: link.tripId,
            linkId,
            senderType,
            senderId: userId,
            messageType: data.messageType || 'text',
            content: data.content,
            cardData: data.cardData,
        });
        const saved = await this.msgRepo.save(message);

        // Notify the other party
        const recipientId = senderType === 'member' ? link.guardianId : link.memberId;
        if (recipientId) {
            this.notifService.send(recipientId, {
                title: '보호자 메시지',
                body: data.content || '[카드]',
                notificationType: 'CHAT',
                referenceId: saved.messageId,
                referenceType: 'GUARDIAN_MESSAGE',
                tripId: link.tripId,
            }).catch(err => console.error('Guardian chat FCM error:', err));
        }

        return saved;
    }

    async markRead(linkId: string, userId: string) {
        await this.assertChannelAccess(linkId, userId);
        await this.msgRepo
            .createQueryBuilder()
            .update()
            .set({ isRead: true })
            .where('link_id = :linkId AND sender_id != :userId AND is_read = false', { linkId, userId })
            .execute();
        return { success: true };
    }

    private async assertChannelAccess(linkId: string, userId: string): Promise<GuardianLink> {
        const link = await this.linkRepo.findOne({ where: { linkId } });
        if (!link) throw new NotFoundException('Guardian channel not found');
        if (link.memberId !== userId && link.guardianId !== userId) {
            throw new ForbiddenException('이 보호자 채널에 접근 권한이 없습니다.');
        }
        return link;
    }
}
```

**Step 4: Create controller and module, register in AppModule**

Controller routes:
- `GET /guardian-chats/trip/:tripId/channels`
- `GET /guardian-chats/channels/:linkId/messages`
- `POST /guardian-chats/channels/:linkId/messages`
- `POST /guardian-chats/channels/:linkId/read`

**Step 5: Run migration and verify**

```bash
cd safetrip-server-api && npx tsc --noEmit 2>&1 | head -20
git add safetrip-server-api/sql/12-schema-guardian-message.sql \
        safetrip-server-api/src/entities/guardian-message.entity.ts \
        safetrip-server-api/src/modules/guardian-chats/ \
        safetrip-server-api/src/app.module.ts
git commit -m "feat(chat): add Guardian Chat module with 1:1 channels (Phase 2)"
```

---

## Task 9: Phase 2 Frontend — Poll UI + Guardian Channels + Sub-Tabs

**Files:**
- Create: `safetrip-mobile/lib/features/chat/widgets/poll_card_widget.dart`
- Create: `safetrip-mobile/lib/features/chat/widgets/poll_create_dialog.dart`
- Create: `safetrip-mobile/lib/features/chat/widgets/schedule_card_widget.dart`
- Create: `safetrip-mobile/lib/features/chat/screens/guardian_channel_list_screen.dart`
- Create: `safetrip-mobile/lib/features/chat/screens/guardian_chat_screen.dart`
- Modify: `safetrip-mobile/lib/screens/main/bottom_sheets/bottom_sheet_3_chat.dart`

**Step 1: Create PollCardWidget**

Renders poll card with progress bars, vote counts, countdown timer, and "투표하기" button.

**Step 2: Create PollCreateDialog**

Bottom sheet for creating polls: question, up to 5 options, deadline selector. Only shown to captain/crew_chief.

**Step 3: Create ScheduleCardWidget**

Renders schedule card with title, date/time, location, "일정 상세 보기" button.

**Step 4: Create GuardianChannelListScreen**

List of guardian channels with free/premium badges, last message preview, unread count.

**Step 5: Create GuardianChatScreen**

1:1 message screen between member and guardian. Reuses message bubble patterns.

**Step 6: Add sub-tabs to BottomSheetChat**

Add TabBar with [그룹 채팅] and [보호자 메시지] tabs. Guardian users see only [보호자 메시지].

**Step 7: Add privacy warning dialog for location cards**

When user sends location card in `privacy_first` off-hours, show confirm dialog:
"현재 위치 비공유 시간대입니다. 위치 카드를 보내시겠습니까?"

**Step 8: Add SOS persistent banner for safety_first grade**

When active SOS exists on a `safety_first` trip, show fixed red banner at chat top.

**Step 9: Verify and commit**

```bash
cd safetrip-mobile && flutter analyze lib/ 2>&1 | tail -10
git add safetrip-mobile/lib/features/chat/
git commit -m "feat(chat): add Poll UI, Guardian channels, sub-tabs, privacy warnings (Phase 2)"
```

---

## Task 10: Phase 3 Backend — Search + Media Gallery + Reactions + File Upload

**Files:**
- Create: `safetrip-server-api/sql/13-schema-chat-reaction.sql`
- Create: `safetrip-server-api/src/entities/chat-reaction.entity.ts`
- Modify: `safetrip-server-api/src/modules/chats/chats.controller.ts`
- Modify: `safetrip-server-api/src/modules/chats/chats.service.ts`
- Modify: `safetrip-server-api/src/modules/chats/chats.module.ts`
- Modify: `safetrip-server-api/src/entities/chat.entity.ts`

**Step 1: Create reaction table migration**

```sql
-- safetrip-server-api/sql/13-schema-chat-reaction.sql
CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE TABLE IF NOT EXISTS tb_chat_reaction (
    reaction_id  BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    message_id   BIGINT NOT NULL REFERENCES tb_chat_message(message_id) ON DELETE CASCADE,
    user_id      VARCHAR(128) NOT NULL REFERENCES tb_user(user_id) ON DELETE CASCADE,
    emoji        VARCHAR(10) NOT NULL,
    created_at   TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(message_id, user_id, emoji)
);

-- Full-text search index on chat messages
CREATE INDEX IF NOT EXISTS idx_chat_message_content_trgm
    ON tb_chat_message USING gin (content gin_trgm_ops)
    WHERE content IS NOT NULL AND deleted_by IS NULL;
```

**Step 2: Create ChatReaction entity**

```typescript
// safetrip-server-api/src/entities/chat-reaction.entity.ts
import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn, Index } from 'typeorm';

@Entity('tb_chat_reaction')
@Index('idx_chat_reaction_unique', ['messageId', 'userId', 'emoji'], { unique: true })
export class ChatReaction {
    @PrimaryGeneratedColumn('increment', { name: 'reaction_id', type: 'bigint' })
    reactionId: string;

    @Column({ name: 'message_id', type: 'bigint' })
    messageId: string;

    @Column({ name: 'user_id', type: 'varchar', length: 128 })
    userId: string;

    @Column({ name: 'emoji', type: 'varchar', length: 10 })
    emoji: string;

    @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
    createdAt: Date;
}
```

**Step 3: Add search, media, reaction endpoints to controller**

```typescript
// Add to chats.controller.ts

@Get('rooms/:roomId/messages/search')
@ApiOperation({ summary: '메시지 검색 (P3)' })
searchMessages(
    @Param('roomId') roomId: string,
    @Query('q') query: string,
    @Query('cursor') cursor?: string,
    @Query('limit') limit?: number,
) {
    return this.chatsService.searchMessages(roomId, query, cursor, limit);
}

@Get('rooms/:roomId/media')
@ApiOperation({ summary: '미디어 모아보기 (P3)' })
getMedia(
    @Param('roomId') roomId: string,
    @Query('cursor') cursor?: string,
    @Query('limit') limit?: number,
) {
    return this.chatsService.getMedia(roomId, cursor, limit);
}

@Post('messages/:messageId/reactions')
@ApiOperation({ summary: '리액션 추가' })
addReaction(
    @CurrentUser() userId: string,
    @Param('messageId') messageId: string,
    @Body() body: { emoji: string },
) {
    return this.chatsService.addReaction(messageId, userId, body.emoji);
}

@Delete('messages/:messageId/reactions/:emoji')
@ApiOperation({ summary: '리액션 제거' })
removeReaction(
    @CurrentUser() userId: string,
    @Param('messageId') messageId: string,
    @Param('emoji') emoji: string,
) {
    return this.chatsService.removeReaction(messageId, userId, emoji);
}

@Get('messages/:messageId/reactions')
@ApiOperation({ summary: '리액션 목록' })
getReactions(@Param('messageId') messageId: string) {
    return this.chatsService.getReactions(messageId);
}
```

**Step 4: Add service methods**

```typescript
// Add to chats.service.ts

async searchMessages(roomId: string, query: string, cursor?: string, limit = 20) {
    const qb = this.messageRepo.createQueryBuilder('m')
        .where('m.roomId = :roomId', { roomId })
        .andWhere('m.isDeleted = false')
        .andWhere('m.content ILIKE :query', { query: `%${query}%` });
    if (cursor) {
        qb.andWhere('m.sentAt < :cursor', { cursor: new Date(cursor) });
    }
    qb.orderBy('m.sentAt', 'DESC').take(limit || 20);
    return qb.getMany();
}

async getMedia(roomId: string, cursor?: string, limit = 30) {
    const qb = this.messageRepo.createQueryBuilder('m')
        .where('m.roomId = :roomId', { roomId })
        .andWhere('m.isDeleted = false')
        .andWhere('m.messageType IN (:...types)', { types: ['image', 'video'] });
    if (cursor) {
        qb.andWhere('m.sentAt < :cursor', { cursor: new Date(cursor) });
    }
    qb.orderBy('m.sentAt', 'DESC').take(limit || 30);
    return qb.getMany();
}

async addReaction(messageId: string, userId: string, emoji: string) {
    const existing = await this.reactionRepo.findOne({
        where: { messageId, userId, emoji },
    });
    if (existing) return existing;

    const reaction = this.reactionRepo.create({ messageId, userId, emoji });
    return this.reactionRepo.save(reaction);
}

async removeReaction(messageId: string, userId: string, emoji: string) {
    await this.reactionRepo.delete({ messageId, userId, emoji });
    return { success: true };
}

async getReactions(messageId: string) {
    return this.reactionRepo.find({ where: { messageId } });
}
```

**Step 5: Register ChatReaction in module**

**Step 6: Verify and commit**

```bash
cd safetrip-server-api && npx tsc --noEmit 2>&1 | head -20
git add safetrip-server-api/sql/13-schema-chat-reaction.sql \
        safetrip-server-api/src/entities/chat-reaction.entity.ts \
        safetrip-server-api/src/modules/chats/
git commit -m "feat(chat): add search, media gallery, reactions, file endpoints (Phase 3)"
```

---

## Task 11: Phase 3 Frontend — Search + Media Gallery + Reactions + File

**Files:**
- Create: `safetrip-mobile/lib/features/chat/widgets/message_search_widget.dart`
- Create: `safetrip-mobile/lib/features/chat/screens/media_gallery_screen.dart`
- Create: `safetrip-mobile/lib/features/chat/widgets/reaction_bar_widget.dart`
- Create: `safetrip-mobile/lib/features/chat/widgets/file_attachment_widget.dart`
- Modify: `safetrip-mobile/lib/features/chat/widgets/chat_message_bubble.dart`
- Modify: `safetrip-mobile/lib/services/api_service.dart`

**Step 1: Create MessageSearchWidget**

Search bar that appears when 🔍 icon is tapped. Shows search results with highlighted matches. Tap result scrolls to message.

**Step 2: Create MediaGalleryScreen**

Grid view of all images/videos in the chat. Tap for full-screen viewer.

**Step 3: Create ReactionBarWidget**

- Long-press message → emoji selection panel (6 default emojis: 👍 ❤️ 😂 😮 😢 🙏)
- Shows reaction count badges below messages
- Tap badge to see who reacted

**Step 4: Create FileAttachmentWidget**

- File picker integration (file_picker package)
- Size validation (max 50MB)
- Upload progress indicator
- Online-only (disabled when offline)

**Step 5: Add API methods for search, media, reactions**

```dart
// Add to api_service.dart

Future<List<Map<String, dynamic>>> searchChatMessages(
    String roomId, String query, {String? cursor, int limit = 20}) async {
  return await _getList('/api/v1/chats/rooms/$roomId/messages/search?q=$query&limit=$limit');
}

Future<List<Map<String, dynamic>>> getChatMedia(
    String roomId, {String? cursor, int limit = 30}) async {
  return await _getList('/api/v1/chats/rooms/$roomId/media?limit=$limit');
}

Future<Map<String, dynamic>?> addReaction(String messageId, String emoji) async {
  return await _post('/api/v1/chats/messages/$messageId/reactions', {'emoji': emoji});
}

Future<bool> removeReaction(String messageId, String emoji) async {
  final result = await _delete('/api/v1/chats/messages/$messageId/reactions/$emoji');
  return result != null;
}
```

**Step 6: Update ChatMessageBubble to include reaction badges**

**Step 7: Verify and commit**

```bash
cd safetrip-mobile && flutter analyze lib/ 2>&1 | tail -10
git add safetrip-mobile/lib/features/chat/ \
        safetrip-mobile/lib/services/api_service.dart
git commit -m "feat(chat): add search, media gallery, reactions, file attachment UI (Phase 3)"
```

---

## Task 12: Integration Testing + Final Verification

**Files:**
- Modify: All files from Tasks 1-11

**Step 1: Verify backend compiles and starts**

```bash
cd safetrip-server-api && npx tsc --noEmit
cd safetrip-server-api && npm run start:dev &
# Wait for "Nest application successfully started"
# Test endpoints:
curl http://localhost:3001/api/v1/chats/trip/test-trip-id/rooms
```

**Step 2: Verify Flutter compiles**

```bash
cd safetrip-mobile && flutter analyze lib/
cd safetrip-mobile && flutter build apk --debug 2>&1 | tail -5
```

**Step 3: Run SQL migrations**

```bash
# Apply new migrations to database
psql -U postgres -d safetrip -f safetrip-server-api/sql/12-schema-guardian-message.sql
psql -U postgres -d safetrip -f safetrip-server-api/sql/13-schema-chat-reaction.sql
```

**Step 4: Final commit with all Phase 1~3 changes**

Verify all changes are committed per-task. Run `git log --oneline -10` to confirm commit history.
