# SafeTrip Chat Tab Implementation Design

| Item | Detail |
|------|--------|
| **Date** | 2026-03-07 |
| **Architecture Doc** | DOC-T3-CHT-020 v1.1 (`20_T3_채팅탭_원칙.md`) |
| **Scope** | Phase 1~3 (P0~P3 전체) |
| **Approach** | 기존 chats 모듈 순차 확장 (BIGINT PK + REST/WebSocket 패턴 유지) |

---

## 1. GAP Analysis

### Existing Implementation
- **Backend**: `ChatsModule` (REST 4 endpoints + WebSocket gateway)
- **Frontend**: `BottomSheetChat` (text messages + offline SQLite queue)
- **DB**: 4 tables in `06-schema-chat.sql` (tb_chat_message, tb_chat_poll, tb_chat_poll_vote, tb_chat_read_status)
- **Entity**: TypeORM entities with UUID PKs (ChatRoom, ChatMessage, ChatReadStatus, ChatPoll, ChatPollVote)

### Missing Features by Phase

**Phase 1 GAP (P0~P1):**
- SOS system message auto-insert (CRITICAL level)
- System message generation for all event types (join/leave/role change etc.)
- Image attachment upload
- Location card (mini map + address + share time)
- Pin/unpin announcements (max 3, captain/crew_leader only)
- Date dividers in message list
- Read status UI (✅/✓ indicators)
- WebSocket integration in Flutter
- Attachment menu [+] bottom sheet
- Message soft delete

**Phase 2 GAP (P2):**
- Poll CRUD (create/vote/close/auto-expire)
- Schedule card sharing
- Guardian channel (tb_guardian_message + dedicated module)
- Free/premium guardian feature branching
- Privacy level warnings for location cards
- SOS persistent banner (safety_first grade)
- Chat sub-tabs (Group Chat / Guardian Messages)

**Phase 3 GAP (P3):**
- Message full-text search (pg_trgm)
- Media gallery view
- Message reactions (emoji)
- File attachment (up to 50MB)

---

## 2. Architecture

```
┌─ Flutter (safetrip-mobile) ─────────────────────┐
│  BottomSheetChat (group chat — refactored)        │
│  GuardianChatScreen (guardian 1:1 messages)        │
│  ├── ChatProvider (Riverpod state management)     │
│  ├── WebSocketService (Socket.io client)          │
│  └── OfflineSyncService (SQLite queue — existing) │
└───────────────────────────────────────────────────┘
         ↕ REST API + WebSocket (Socket.io)
┌─ NestJS Backend (safetrip-server-api) ──────────┐
│  ChatsModule (extended)                            │
│  ├── ChatsController (group chat REST CRUD)       │
│  ├── ChatsService (business logic)                │
│  ├── ChatsGateway (WebSocket broadcast)           │
│  ├── SystemMessageService (auto-insert)           │
│  └── PollService (vote CRUD + scheduler)          │
│  GuardianChatsModule (new — Phase 2)              │
│  ├── GuardianChatsController                      │
│  └── GuardianChatsService                         │
└───────────────────────────────────────────────────┘
         ↕ TypeORM
┌─ PostgreSQL ──────────────────────────────────────┐
│  tb_chat_room (add migration if missing)           │
│  tb_chat_message (existing — BIGINT PK)            │
│  tb_chat_poll (existing)                           │
│  tb_chat_poll_vote (existing)                      │
│  tb_chat_read_status (existing)                    │
│  tb_guardian_message (new — Phase 2)               │
│  tb_chat_reaction (new — Phase 3)                  │
└────────────────────────────────────────────────────┘
```

---

## 3. Phase 1 Design (P0 + P1)

### 3.1 DB Migrations

**06a-migration-chat-room.sql** — Ensure tb_chat_room table exists:
```sql
CREATE TABLE IF NOT EXISTS tb_chat_room (
    room_id    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id    UUID NOT NULL REFERENCES tb_trip(trip_id),
    room_type  VARCHAR(20) NOT NULL DEFAULT 'group',
    room_name  VARCHAR(100),
    is_active  BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE tb_chat_message ADD COLUMN IF NOT EXISTS room_id UUID REFERENCES tb_chat_room(room_id);
```

### 3.2 Backend Endpoints (Extended)

| Method | Path | Description |
|--------|------|-------------|
| POST | /rooms/:roomId/messages | Send message (extended: messageType, mediaUrls, locationData, cardData) |
| PATCH | /messages/:messageId/pin | Pin message (captain/crew_leader only, max 3) |
| DELETE | /messages/:messageId/pin | Unpin message |
| GET | /rooms/:roomId/pinned | Get pinned messages (max 3) |
| DELETE | /messages/:messageId | Soft delete message |

### 3.3 SystemMessageService

Auto-inserts system messages on events:

| Event | system_event_type | system_event_level | Template |
|-------|-------------------|-------------------|----------|
| Member join | member_join | INFO | "[name]님이 여행에 합류했습니다." |
| Member leave | member_leave | INFO | "[name]님이 여행을 떠났습니다." |
| Member kicked | member_kicked | WARNING | "[name]님이 여행에서 강퇴되었습니다." |
| Role change | role_change | INFO | "[name]님이 크루장으로 변경되었습니다." |
| Leader transfer | leader_transfer | INFO | "[name]님이 캡틴이 되었습니다." |
| Trip start | trip_start | CELEBRATION | "여행이 시작되었습니다." |
| Trip end | trip_end | INFO | "여행이 종료되었습니다." |
| SOS alert | sos_alert | CRITICAL | "[name]님이 SOS를 발신했습니다." |
| SOS cancel | sos_cancel | INFO | "[name]님의 SOS가 해제되었습니다." |
| Attendance start | attendance_start | INFO | "출석 체크가 시작되었습니다." |
| Attendance complete | attendance_complete | INFO | "출석 체크 완료: ✅ N명 / ❌ N명 / ⏳ N명" |
| Privacy change | privacy_change | INFO | "여행 프라이버시 등급이 [level]으로 변경되었습니다." |
| Schedule change | schedule_change | SCHEDULE | "[date] 일정이 변경되었습니다." |
| Guardian add | guardian_add | INFO | "[member]님의 가디언으로 [guardian]님이 연결되었습니다." |
| Guardian remove | guardian_remove | INFO | "[member]님의 가디언 [guardian]님이 해제되었습니다." |

### 3.4 SOS System Message (CRITICAL)

- SOS module calls `SystemMessageService.insertSosAlert(tripId, userId, locationData)`
- message_type='system', system_event_level='CRITICAL'
- location_data includes: lat, lng, address, battery_level
- FCM notification with PRIORITY_HIGH
- SOS card cannot be deleted (§12.2)

### 3.5 Pin/Unpin Logic

- Max 3 pinned messages per room
- Captain/crew_leader role check via GroupMember
- Pin/unpin triggers system message insertion
- Pinned message on SOS cannot be unpinned

### 3.6 Flutter UI Refactoring

```
BottomSheetChat (refactored)
├── _ChatHeader (trip name + online member count)
├── _PinnedNotices (max 3 pinned, tap → scroll to message)
├── _SosBanner (CRITICAL SOS active — safety_first only in P2)
├── _OfflineBanner (existing)
├── _MessageList (scrollable)
│   ├── _DateDivider ("오늘", "어제", "MM월 DD일")
│   ├── _TextBubble (text message — left/right alignment)
│   ├── _SystemMessage (centered, gray background)
│   ├── _SosCard (CRITICAL card with map/battery/actions)
│   ├── _LocationCard (mini map + address + "지도에서 보기")
│   ├── _ImageMessage (thumbnail + tap for full view)
│   └── _PendingBubble (⏳ pending indicator)
├── _AttachmentMenu ([+] bottom sheet: photo, location, schedule, file)
└── _MessageInput (text + [+] button + send button)
```

### 3.7 WebSocket Integration (Flutter)

- `socket_io_client` package for Socket.io
- Events: joinRoom, leaveRoom, newMessage, userJoined, userLeft
- Auto-reconnect with offline queue fallback

### 3.8 Read Status UI

- ✅ (read by all) / ✓ (sent, not read) / ⏳ (pending)
- markRead API call on chat screen enter + scroll to bottom

---

## 4. Phase 2 Design (P2)

### 4.1 Poll CRUD

| Method | Path | Description |
|--------|------|-------------|
| POST | /rooms/:roomId/polls | Create poll (captain/crew_leader only) |
| GET | /polls/:pollId | Get poll details + results |
| POST | /polls/:pollId/vote | Cast vote (single choice, before deadline) |
| PATCH | /polls/:pollId/vote | Change vote (before deadline) |
| POST | /polls/:pollId/close | Manual close (captain/crew_leader only) |

- NestJS @Cron scheduler for auto-close at closes_at
- Trip end auto-closes all active polls

### 4.2 Guardian Channel

**DB Migration (tb_guardian_message):**
```sql
CREATE TABLE tb_guardian_message (
    message_id   BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    trip_id      UUID NOT NULL REFERENCES tb_trip(trip_id),
    link_id      UUID NOT NULL REFERENCES tb_guardian_link(id),
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
CREATE INDEX idx_guardian_msg_link ON tb_guardian_message(link_id, sent_at DESC);
```

**GuardianChatsModule endpoints:**

| Method | Path | Description |
|--------|------|-------------|
| GET | /trips/:tripId/guardian-channels | List my guardian channels |
| GET | /guardian-channels/:linkId/messages | Get messages (cursor-based) |
| POST | /guardian-channels/:linkId/messages | Send message |
| POST | /guardian-channels/:linkId/read | Mark as read |

**Free/Premium branching:**
- Free guardian: text + image only; location/schedule cards masked
- Premium guardian: full access to location and schedule cards
- Premium check: guardian_link.tier or subscription status

### 4.3 Schedule Card

- messageType='rich_card', cardData.type='schedule'
- Card data: schedule_id, title, start_at, end_at, location
- Tap → navigate to schedule detail screen

### 4.4 Privacy Level Warnings

- `privacy_first` + off-hours: confirm dialog before sending location card
- Location card sent during off-hours gets "비공유 시간 발송" badge
- Guardian channel: `privacy_first` off-hours → card content hidden

### 4.5 SOS Persistent Banner

- `safety_first` grade + active SOS → fixed banner at chat top
- Banner: "[🚨 SOS 활성 중 — name · address] [지도]"
- Removed when SOS cancelled

### 4.6 Chat Sub-Tabs (Flutter)

```
ChatTab
├── TabBar: [그룹 채팅] [보호자 메시지]
├── GroupChat (existing, refactored)
└── GuardianMessages (new)
    ├── GuardianChannelList (channel list with free/premium badges)
    └── GuardianChat1to1 (1:1 message screen)
```

- Guardian users see only [보호자 메시지] tab
- Members see both tabs

---

## 5. Phase 3 Design (P3)

### 5.1 Message Search

```sql
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE INDEX idx_chat_message_content_trgm
    ON tb_chat_message USING gin (content gin_trgm_ops)
    WHERE content IS NOT NULL AND deleted_by IS NULL;
```

| Method | Path | Description |
|--------|------|-------------|
| GET | /rooms/:roomId/messages/search?q=keyword | Full-text search |

### 5.2 Media Gallery

| Method | Path | Description |
|--------|------|-------------|
| GET | /rooms/:roomId/media | Image/video messages only, cursor-based |

### 5.3 Reactions

```sql
CREATE TABLE tb_chat_reaction (
    reaction_id  BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    message_id   BIGINT NOT NULL REFERENCES tb_chat_message(message_id) ON DELETE CASCADE,
    user_id      VARCHAR(128) NOT NULL REFERENCES tb_user(user_id) ON DELETE CASCADE,
    emoji        VARCHAR(10) NOT NULL,
    created_at   TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(message_id, user_id, emoji)
);
```

| Method | Path | Description |
|--------|------|-------------|
| POST | /messages/:messageId/reactions | Add reaction |
| DELETE | /messages/:messageId/reactions/:emoji | Remove reaction |
| GET | /messages/:messageId/reactions | List reactions |

### 5.4 File Attachment

- multipart/form-data support in sendMessage
- Max 50MB validation
- Firebase Storage upload → URL → media_urls JSONB
- Online-only (offline: disabled in UI)

---

## 6. Implementation Priority

| Step | Phase | Backend | Frontend | Commit |
|------|-------|---------|----------|--------|
| 1 | P1-BE | DB migration + SystemMessageService + pin/unpin/delete APIs | — | ✅ |
| 2 | P1-FE | — | Chat UI refactor (date dividers, system msgs, read status, attachment menu, WebSocket) | ✅ |
| 3 | P1-FE | — | Rich cards (SOS card, location card, image) | ✅ |
| 4 | P2-BE | Poll CRUD + scheduler + Guardian module + guardian DB | — | ✅ |
| 5 | P2-FE | — | Poll UI + Guardian channel UI + privacy warnings + SOS banner | ✅ |
| 6 | P3-BE | Search index + media API + reactions table + file upload | — | ✅ |
| 7 | P3-FE | — | Search UI + media gallery + reactions + file attachment | ✅ |

---

## 7. Key Architectural Decisions

1. **BIGINT PK maintained** — existing schema uses BIGINT; document's UUID adapted to BIGINT
2. **REST + WebSocket pattern** — unchanged from existing implementation
3. **Guardian messages in separate table** — `tb_guardian_message` (not reusing tb_chat_message) per architecture doc §6
4. **System messages via service** — `SystemMessageService` callable from any module (SOS, membership, etc.)
5. **TypeORM entities extended** — add new fields to existing entities, new entities for guardian/reaction
6. **Offline queue unchanged** — existing SQLite queue supports new message types
