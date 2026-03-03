# Guardian System Design

**Date:** 2026-02-27
**Status:** Approved

---

## Overview

Guardians are external protectors linked 1:1 to specific group members — not group members themselves. A guardian can see their connected member's location, SOS alerts, trip itinerary/places, and exchange messages with the member and optionally the trip captain.

**Key principle:** Guardians are stored in `TB_GROUP_MEMBER` with `member_role='guardian'` (existing approach maintained) and linked to specific members via `TB_GUARDIAN_LINK`.

---

## Data Model

### PostgreSQL (Existing Tables — No New Tables Needed)

```sql
-- TB_GUARDIAN_LINK (already exists)
link_id       UUID PK
trip_id       UUID FK→TB_TRIP
member_id     VARCHAR FK→TB_USER   -- protected member (traveler)
guardian_id   VARCHAR FK→TB_USER   -- guardian user
status        VARCHAR CHECK IN ('pending', 'accepted', 'rejected')
created_at    TIMESTAMPTZ
accepted_at   TIMESTAMPTZ?
UNIQUE(trip_id, member_id, guardian_id)

-- TB_TRIP_SETTINGS (already exists)
trip_id                      UUID PK
captain_receive_guardian_msg BOOLEAN DEFAULT true
updated_at                   TIMESTAMPTZ
```

### Firebase Realtime DB (New — Guardian Messages)

```
/guardian_messages/{tripId}/{linkId}/
  messages/{messageId}/
    sender_id    : string
    receiver_id  : string
    message      : string
    message_type : 'to_member'   -- member ↔ guardian
    created_at   : number (ms timestamp)
    read_at      : number?

/guardian_captain_messages/{tripId}/{guardianId}/
  messages/{messageId}/
    sender_id    : string
    receiver_id  : string        -- captain user_id
    message      : string
    created_at   : number (ms timestamp)
    read_at      : number?
```

**RTDB security rules:** Only participants of a given `linkId` can read/write that channel.

---

## Guardian Rules

| Rule | Detail |
|------|--------|
| Who can add a guardian | The member themselves (captain/crew_chief/crew) adds guardians for themselves |
| Limit | Max 3 guardians per member per trip (pending + accepted count together) |
| Duplicate prevention | UNIQUE(trip_id, member_id, guardian_id) at DB level |
| Acceptance flow | Member invites → guardian receives notification → guardian accepts/rejects |
| Multiple links | One user can be a guardian for multiple members in the same trip |

---

## Guardian Permissions

| Action | Condition |
|--------|-----------|
| View connected member's location | Accepted guardian_link |
| Receive member's SOS alerts | Accepted guardian_link |
| View member's basic profile | Accepted guardian_link |
| View trip itinerary/schedules | At least 1 accepted guardian_link for trip |
| View trip places/geofences | At least 1 accepted guardian_link for trip |
| Message connected member | Accepted guardian_link |
| Message trip captain | captain_receive_guardian_msg = true |

**Not allowed:** Group member list, group chat, other members' locations, any edit/management functions.

---

## Backend API

### New Endpoints

```
PATCH  /api/v1/trips/:tripId/settings
  Auth: authenticate → requireTripCaptain
  Body: { captain_receive_guardian_msg: boolean }
  Logic: UPSERT TB_TRIP_SETTINGS

POST   /api/v1/trips/:tripId/guardian-messages/captain
  Auth: authenticate → requireGuardianLinkForTrip → requireCanMessageCaptain
  Body: { message: string }
  Logic: Write to RTDB /guardian_captain_messages/{tripId}/{guardianId}/messages

POST   /api/v1/trips/:tripId/guardian-messages/member
  Auth: authenticate → requireGuardianOwnsLink (or is the member in the link)
  Body: { link_id: string, message: string }
  Logic: Write to RTDB /guardian_messages/{tripId}/{linkId}/messages

GET    /api/v1/trips/:tripId/guardian-view/:memberId
  Auth: authenticate → requireGuardianLinkForMember
  Returns: { display_name, profile_image_url, member_role, latest_location? }

GET    /api/v1/trips/:tripId/guardian-view/itinerary
  Auth: authenticate → requireGuardianLinkForTrip
  Returns: TB_SCHEDULE rows for trip (read-only)

GET    /api/v1/trips/:tripId/guardian-view/places
  Auth: authenticate → requireGuardianLinkForTrip
  Returns: TB_GEOFENCE rows for trip (read-only)
```

### Existing Endpoints (Verify & Patch if Needed)

```
POST   /trips/:tripId/guardians                      -- member invites guardian
PATCH  /trips/:tripId/guardians/:linkId/respond      -- guardian accepts/rejects
DELETE /trips/:tripId/guardians/:linkId              -- unlink
GET    /trips/:tripId/guardians/me                   -- member's guardian list
GET    /trips/:tripId/guardians/pending              -- guardian's pending invites
GET    /trips/:tripId/guardians/linked-members       -- guardian's connected travelers
```

### Key Middleware (Already Exists — Verify)

```typescript
requireGuardianLinkForMember  // guardian can access specific member's data
requireGuardianLinkForTrip    // guardian has accepted link for trip
requireCanMessageCaptain      // guardian can message trip captain
requireMemberOwnsLink         // member owns guardian link
validateGuardianLimit         // max 3 guardians per member per trip
requireTripCaptain            // user is captain of trip
```

---

## Flutter UI

### Screen 1: Member's Guardian Management (`my_guardians_screen.dart`)

**Access:** Member tab → "가디언 관리" button on member's own profile card
**Contents:**
- Header: "내 가디언 (2/3)" counter
- Guardian cards: avatar, name, phone, status badge (수락됨/대기중), unlink button
- "+ 가디언 추가" button (disabled when count = 3)
  - Opens user search modal (reuse existing search UI)
- Empty state text when no guardians

### Screen 2: Guardian's Connected Members View (`guardian_members_view.dart`)

**Access:** Guardian users see this as main screen on app entry (or dedicated tab)
**Contents:**
- Per connected member card: name, role, real-time location status
- "메시지 보내기" and "위치 보기" buttons
- "캡틴에게 메시지" button:
  - Active when `captain_receive_guardian_msg = true`
  - Disabled with tooltip "캡틴이 메시지를 받지 않고 있습니다" when false

### Screen 3: Guardian's Itinerary Tab (`guardian_itinerary_tab.dart`)

**Access:** Bottom tab in guardian main screen
**Contents:** Reuses existing schedule/itinerary UI, all edit controls hidden (read-only)
**API:** `GET /trips/:tripId/guardian-view/itinerary`

### Screen 4: Captain Settings — Guardian Message Toggle

**Access:** Trip settings screen → new "가디언" section
**Contents:**
```dart
SwitchListTile(
  title: Text('가디언 메시지 수신'),
  subtitle: Text('OFF 시 모든 가디언의 메시지가 차단됩니다'),
  value: captainReceiveGuardianMsg,
  onChanged: _updateSetting,
)
```
**API:** `PATCH /api/v1/trips/:tripId/settings`

---

## Implementation Order

1. **Backend:** Verify/complete existing guardian API endpoints
2. **Backend:** Add captain settings PATCH endpoint
3. **Backend:** Add guardian message endpoints (RTDB writes)
4. **Flutter:** Screen 1 — Member guardian management
5. **Flutter:** Screen 2 — Guardian connected members view
6. **Flutter:** Screen 3 — Guardian itinerary tab
7. **Flutter:** Screen 4 — Captain settings toggle

---

## Constraints & Edge Cases

- Guardians are NOT in the group member list (filtered out at API and UI level)
- When a member leaves a trip → their `TB_GUARDIAN_LINK` records auto-deleted (CASCADE)
- Trip deletion → all guardian links and RTDB messages cascade-deleted
- Captain `captain_receive_guardian_msg` is trip-wide toggle, not per-guardian
- Messages blocked during OFF period are NOT restored when captain turns it ON
- Guardians have read-only access to itinerary/places — no edit permissions
- Guardian invitation via phone number search (reuses existing `/api/v1/users/search?q=`)
