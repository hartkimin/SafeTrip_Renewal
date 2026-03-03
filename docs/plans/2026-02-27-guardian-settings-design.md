# Guardian Settings Design

**Date:** 2026-02-27
**Status:** Approved
**Scope:** `safetrip-mobile` Flutter app — settings screen guardian integration

---

## Problem Statement

1. **Bug:** `_captainReceiveGuardianMsg` is hardcoded to `true` in `SettingsScreen` — the actual server value is never loaded on screen open.
2. **Missing:** Guardian-role users see only the 앱/계정 sections in settings — no way to view pending invitations or manage linked members from settings.

---

## Solution Overview

### Approach B (Approved)

Extract a `_GuardianSection` StatefulWidget inside `screen_settings.dart`. It handles its own data loading and renders inline content based on the current user's role.

No new files are created.

---

## Architecture

### Files Modified

| File | Change |
|------|--------|
| `lib/screens/settings/screen_settings.dart` | Add `_GuardianSection` widget; fix toggle initial value load |
| `lib/services/api_service.dart` | Add `getTripSettings(tripId)` → GET `/api/v1/trips/:tripId/settings` |

---

## Component Design

### `_GuardianSection` (StatefulWidget, embedded in screen_settings.dart)

**Props received from parent:**
- `tripId: String`
- `userRole: String` — determines which sub-view to render

**State:**
- For guardian role: `List<GuardianInvitation> _pending`, `List<LinkedMember> _linked`, `bool _isLoading`
- For captain role: `bool _captainReceiveGuardianMsg`, `bool _isLoading` — loaded via `getTripSettings()`

**Render logic:**

```
if userRole == 'guardian':
  Section header: '가디언 연결'
  → if _pending.isNotEmpty: render each pending invitation as inline card
      (accept / reject buttons inline using AppTokens colors)
  → linked members list
      each member: AvatarWidget + name + phone + 연결 해제 IconButton
  → if both empty: empty state tile

if userRole == 'captain':
  Section header: '가디언 설정'
  → _buildGuardianMsgToggle (reads _captainReceiveGuardianMsg from API on load)
```

---

## Data Flow

### Guardian role — settings open

```
initState()
  → Future.wait([
      getPendingGuardianInvitations(tripId),
      getLinkedMembers(tripId),
    ])
  → setState({ _pending, _linked, _isLoading: false })
```

**respondToInvitation(action):**
- PATCH `/trips/:tripId/guardians/:linkId/respond`
- On success: remove from `_pending`, reload if accepted (member moves to `_linked`)

**removeLinkedMember(linkId):**
- DELETE `/trips/:tripId/guardians/:linkId`
- On success: remove from `_linked`

### Captain role — toggle initial value

```
initState()
  → getTripSettings(tripId)
  → setState({ _captainReceiveGuardianMsg: data['captain_receive_guardian_msg'] ?? true })
```

### New API method

```dart
/// GET /api/v1/trips/:tripId/settings
Future<Map<String, dynamic>?> getTripSettings(String tripId) async { ... }
```

Returns: `{ captain_receive_guardian_msg: bool, ... }`

---

## Settings Screen Layout (per role)

### guardian
```
[프로필 카드]
[가디언 연결]           ← _GuardianSection
  pending invitation cards (inline accept/reject)
  linked member tiles (inline disconnect)
[앱]
[계정]
```

### captain
```
[프로필 카드]
[위치]
[그룹 관리]
[가디언 설정]           ← _GuardianSection (toggle with API-loaded initial value)
[내 가디언]
[앱]
[계정]
```

### crew_chief / crew
```
[프로필 카드]
[위치]
[내 가디언]             ← unchanged
[앱]
[계정]
```

---

## UI Details

- All new tiles use existing `_buildTile()` pattern with `AppTokens`
- Pending invitation card: amber border, shield icon, member name + trip dates, accept (teal) / reject (red) buttons inline
- Linked member tile: `AvatarWidget` + name + phone + `Icons.link_off` button (red)
- Empty state: single tile with subtitle "연결된 멤버가 없습니다" (no full-page empty state — inline)
- Loading: `LinearProgressIndicator` at top of section (not full-screen)

---

## Error Handling

- API errors show `SnackBar` with descriptive message
- Toggle reverts on failure (existing pattern)
- Section load failure: section shows subtitle "불러오기 실패 — 새로고침" with retry tap

---

## Out of Scope

- `ScreenGuardianManage` redesign (separate task)
- Push notifications for pending invitations
- Real-time RTDB listener for new invitations in settings
