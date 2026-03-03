# Guardian System Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Complete the Guardian system — verify existing file skeletons contain working implementations, fill gaps, wire up RTDB messaging, and deliver 4 Flutter UI screens.

**Architecture:** Guardians are stored in `TB_GROUP_MEMBER` with `member_role='guardian'` (existing), linked to specific members via `TB_GUARDIAN_LINK`. Messages use Firebase RTDB. Most file skeletons already exist; this plan verifies and completes them.

**Tech Stack:** Node.js/TypeScript backend (port 3001), PostgreSQL (pg.Pool), Firebase Realtime DB (admin SDK), Flutter/Dart frontend.

**Design doc:** `docs/plans/2026-02-27-guardian-system-design.md`

---

## Phase 1: Backend Audit & Completion

### Task 1: Read and audit existing guardian-link service

**Goal:** Understand what's already implemented vs. what's a stub.

**Files to read:**
- `safetrip-server-api/src/services/guardian-link.service.ts`
- `safetrip-server-api/src/services/guardian-view.service.ts`
- `safetrip-server-api/src/services/trip-settings.service.ts`
- `safetrip-server-api/src/services/guardian-message.service.ts`

**Step 1: Read all four service files**

Use the Read tool on each. For each function, note:
- Is it implemented (has SQL queries / logic)?
- Or is it a stub (returns dummy data or throws NotImplemented)?

**Step 2: Read controller files**

- `safetrip-server-api/src/controllers/trip-guardian.controller.ts`
- `safetrip-server-api/src/controllers/guardian-view.controller.ts`
- `safetrip-server-api/src/controllers/guardian-messages.controller.ts`

**Step 3: Read middleware**

- `safetrip-server-api/src/middleware/guardian-permission.middleware.ts`

**Step 4: Read route files to understand what's wired**

- `safetrip-server-api/src/routes/trip-guardian.routes.ts`
- `safetrip-server-api/src/routes/guardian-view.routes.ts`
- `safetrip-server-api/src/routes/guardian-messages.routes.ts`
- `safetrip-server-api/src/routes/trips.routes.ts` (for PATCH /settings)

**Step 5: Read index.ts to confirm routes are registered**

- `safetrip-server-api/src/index.ts`

**Step 6: Document gaps**

Create a mental checklist of which functions need implementation. Move to Task 2.

---

### Task 2: Implement guardian-link.service.ts (if gaps found)

**File:** `safetrip-server-api/src/services/guardian-link.service.ts`

Expected functions — implement any that are stubs:

**`createGuardianLink(tripId, memberId, guardianPhone)`**
```typescript
// 1. Look up guardian user by phone number
const guardianUser = await db.query(
  `SELECT user_id FROM tb_user WHERE phone_number = $1`, [guardianPhone]
);
if (!guardianUser.rows.length) throw new Error('USER_NOT_FOUND');

const guardianId = guardianUser.rows[0].user_id;

// 2. Check 3-guardian limit (pending + accepted count)
const count = await db.query(
  `SELECT COUNT(*) FROM tb_guardian_link
   WHERE trip_id = $1 AND member_id = $2 AND status IN ('pending','accepted')`,
  [tripId, memberId]
);
if (parseInt(count.rows[0].count) >= 3) throw new Error('GUARDIAN_LIMIT_EXCEEDED');

// 3. Insert (UNIQUE constraint handles duplicates)
const result = await db.query(
  `INSERT INTO tb_guardian_link (trip_id, member_id, guardian_id, status)
   VALUES ($1, $2, $3, 'pending')
   ON CONFLICT (trip_id, member_id, guardian_id) DO NOTHING
   RETURNING link_id, status, created_at`,
  [tripId, memberId, guardianId]
);
return result.rows[0];
```

**`respondToGuardianLink(linkId, guardianId, action: 'accepted'|'rejected')`**
```typescript
const result = await db.query(
  `UPDATE tb_guardian_link
   SET status = $1, accepted_at = CASE WHEN $1 = 'accepted' THEN NOW() ELSE NULL END
   WHERE link_id = $2 AND guardian_id = $3 AND status = 'pending'
   RETURNING *`,
  [action, linkId, guardianId]
);
if (!result.rows.length) throw new Error('LINK_NOT_FOUND');
return result.rows[0];
```

**`deleteGuardianLink(linkId, requestUserId)`**
```typescript
// Either the member or the guardian can delete
const result = await db.query(
  `DELETE FROM tb_guardian_link
   WHERE link_id = $1 AND (member_id = $2 OR guardian_id = $2)
   RETURNING link_id`,
  [linkId, requestUserId]
);
if (!result.rows.length) throw new Error('LINK_NOT_FOUND');
```

**`getMyGuardians(tripId, memberId)`**
```typescript
// Returns guardians with user info + status
const result = await db.query(
  `SELECT gl.link_id, gl.status, gl.created_at, gl.accepted_at,
          u.user_id as guardian_id, u.display_name, u.profile_image_url, u.phone_number
   FROM tb_guardian_link gl
   JOIN tb_user u ON u.user_id = gl.guardian_id
   WHERE gl.trip_id = $1 AND gl.member_id = $2
   ORDER BY gl.created_at DESC`,
  [tripId, memberId]
);
return result.rows;
```

**`getPendingInvitations(guardianId)`**
```typescript
// Returns pending links with trip + member info
const result = await db.query(
  `SELECT gl.link_id, gl.trip_id, gl.member_id, gl.status, gl.created_at,
          u.display_name as member_name, u.profile_image_url as member_image,
          t.trip_name, t.country_name, t.start_date::text, t.end_date::text
   FROM tb_guardian_link gl
   JOIN tb_user u ON u.user_id = gl.member_id
   JOIN tb_trip t ON t.trip_id = gl.trip_id
   WHERE gl.guardian_id = $1 AND gl.status = 'pending'
   ORDER BY gl.created_at DESC`,
  [guardianId]
);
return result.rows;
```

**`getLinkedMembers(tripId, guardianId)`**
```typescript
// Returns accepted members for this guardian in this trip
const result = await db.query(
  `SELECT gl.link_id, gl.member_id, gl.accepted_at,
          u.display_name, u.profile_image_url, u.phone_number,
          gm.member_role
   FROM tb_guardian_link gl
   JOIN tb_user u ON u.user_id = gl.member_id
   LEFT JOIN tb_group_member gm ON gm.user_id = gl.member_id
     AND gm.trip_id = gl.trip_id AND gm.status = 'active'
   WHERE gl.trip_id = $1 AND gl.guardian_id = $2 AND gl.status = 'accepted'`,
  [tripId, guardianId]
);
return result.rows;
```

**Step: After implementing, restart backend and verify no TypeScript errors**

```bash
cd /mnt/d/Project/15_SafeTrip_New/safetrip-server-api
npm run build 2>&1 | head -50
```
Expected: No errors.

---

### Task 3: Implement guardian-view.service.ts (if gaps found)

**File:** `safetrip-server-api/src/services/guardian-view.service.ts`

**`getMemberProfile(tripId, guardianId, memberId)`**
```typescript
// Verify guardian link first
const link = await db.query(
  `SELECT link_id FROM tb_guardian_link
   WHERE trip_id = $1 AND guardian_id = $2 AND member_id = $3 AND status = 'accepted'`,
  [tripId, guardianId, memberId]
);
if (!link.rows.length) throw new Error('GUARDIAN_LINK_NOT_FOUND');

const result = await db.query(
  `SELECT u.user_id, u.display_name, u.profile_image_url, u.phone_number,
          gm.member_role
   FROM tb_user u
   LEFT JOIN tb_group_member gm ON gm.user_id = u.user_id AND gm.trip_id = $1
   WHERE u.user_id = $3`,
  [tripId, guardianId, memberId]
);
return result.rows[0];
```

**`getTripItinerary(tripId, guardianId)`**
```typescript
// Verify guardian has any accepted link for this trip
const link = await db.query(
  `SELECT link_id FROM tb_guardian_link
   WHERE trip_id = $1 AND guardian_id = $2 AND status = 'accepted' LIMIT 1`,
  [tripId, guardianId]
);
if (!link.rows.length) throw new Error('NOT_AUTHORIZED');

const result = await db.query(
  `SELECT schedule_id, schedule_name, schedule_date::text,
          start_time::text, end_time::text,
          location_name, location_address, location_lat, location_lng, order_index
   FROM tb_schedule
   WHERE trip_id = $1
   ORDER BY schedule_date, order_index, start_time`,
  [tripId]
);
return result.rows;
```

**`getTripPlaces(tripId, guardianId)`**
```typescript
// Same auth check as itinerary
const link = await db.query(
  `SELECT link_id FROM tb_guardian_link
   WHERE trip_id = $1 AND guardian_id = $2 AND status = 'accepted' LIMIT 1`,
  [tripId, guardianId]
);
if (!link.rows.length) throw new Error('NOT_AUTHORIZED');

const result = await db.query(
  `SELECT geofence_id, name, type, shape_type,
          center_latitude, center_longitude, radius_meters, is_active
   FROM tb_geofence
   WHERE trip_id = $1 AND is_active = true
   ORDER BY name`,
  [tripId]
);
return result.rows;
```

---

### Task 4: Implement trip-settings.service.ts and captain settings endpoint

**File:** `safetrip-server-api/src/services/trip-settings.service.ts`

**`getSettings(tripId)`**
```typescript
const result = await db.query(
  `SELECT trip_id, captain_receive_guardian_msg
   FROM tb_trip_settings WHERE trip_id = $1`,
  [tripId]
);
// Return defaults if no row exists yet
return result.rows[0] ?? { trip_id: tripId, captain_receive_guardian_msg: true };
```

**`updateCaptainReceiveMsg(tripId, enabled: boolean)`**
```typescript
await db.query(
  `INSERT INTO tb_trip_settings (trip_id, captain_receive_guardian_msg, updated_at)
   VALUES ($1, $2, NOW())
   ON CONFLICT (trip_id) DO UPDATE
   SET captain_receive_guardian_msg = $2, updated_at = NOW()`,
  [tripId, enabled]
);
```

**Verify PATCH /api/v1/trips/:tripId/settings is in trips.routes.ts:**

The route should look like:
```typescript
router.patch('/:tripId/settings', authenticate, requireTripCaptain, updateTripSettings);
```

If missing, add to `safetrip-server-api/src/routes/trips.routes.ts`.

**Controller function in trips.controller.ts:**
```typescript
export async function updateTripSettings(req: Request, res: Response) {
  const { tripId } = req.params;
  const { captain_receive_guardian_msg } = req.body;

  if (typeof captain_receive_guardian_msg !== 'boolean') {
    return res.status(400).json({ error: 'captain_receive_guardian_msg must be boolean' });
  }

  await tripSettingsService.updateCaptainReceiveMsg(tripId, captain_receive_guardian_msg);
  const settings = await tripSettingsService.getSettings(tripId);
  res.json({ success: true, settings });
}
```

**Step: Test with curl after server restart:**
```bash
# Get trip ID from DB first
TRIP_ID="your-trip-id"
TOKEN="your-captain-firebase-token"

curl -X PATCH http://localhost:3001/api/v1/trips/$TRIP_ID/settings \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"captain_receive_guardian_msg": false}'
```
Expected: `{"success": true, "settings": {"trip_id": "...", "captain_receive_guardian_msg": false}}`

---

### Task 5: Implement guardian-message.service.ts (RTDB)

**File:** `safetrip-server-api/src/services/guardian-message.service.ts`

This service writes guardian messages to Firebase Realtime DB.

**Setup — get RTDB instance:**
```typescript
import { getDatabase } from 'firebase-admin/database';

function getRTDB() {
  return getDatabase(); // Uses already-initialized firebase-admin app
}
```

**`sendMessageToMember(tripId, linkId, senderId, receiverId, message)`**
```typescript
export async function sendMessageToMember(
  tripId: string, linkId: string,
  senderId: string, receiverId: string, message: string
) {
  const db = getRTDB();
  const ref = db.ref(`guardian_messages/${tripId}/${linkId}/messages`);
  const newMsgRef = ref.push();
  await newMsgRef.set({
    sender_id: senderId,
    receiver_id: receiverId,
    message,
    message_type: 'to_member',
    created_at: Date.now(),
    read_at: null,
  });
  return { message_id: newMsgRef.key, created_at: Date.now() };
}
```

**`sendMessageToCaptain(tripId, guardianId, captainId, message)`**
```typescript
export async function sendMessageToCaptain(
  tripId: string, guardianId: string,
  captainId: string, message: string
) {
  const db = getRTDB();
  const ref = db.ref(`guardian_captain_messages/${tripId}/${guardianId}/messages`);
  const newMsgRef = ref.push();
  await newMsgRef.set({
    sender_id: guardianId,
    receiver_id: captainId,
    message,
    created_at: Date.now(),
    read_at: null,
  });
  return { message_id: newMsgRef.key, created_at: Date.now() };
}
```

**Controller — `guardian-messages.controller.ts`:**
```typescript
// POST /trips/:tripId/guardian-messages/member
export async function sendToMember(req: Request, res: Response) {
  const { tripId } = req.params;
  const { link_id, message } = req.body;
  const senderId = req.userId!;

  // Get receiver from link
  const link = await db.query(
    `SELECT member_id, guardian_id FROM tb_guardian_link WHERE link_id = $1`,
    [link_id]
  );
  if (!link.rows.length) return res.status(404).json({ error: 'Link not found' });

  const { member_id, guardian_id } = link.rows[0];
  const receiverId = senderId === guardian_id ? member_id : guardian_id;

  const result = await guardianMessageService.sendMessageToMember(
    tripId, link_id, senderId, receiverId, message
  );
  res.json({ success: true, ...result });
}

// POST /trips/:tripId/guardian-messages/captain
export async function sendToCaptain(req: Request, res: Response) {
  const { tripId } = req.params;
  const { message } = req.body;
  const guardianId = req.userId!;

  // Get captain of this trip
  const captain = await db.query(
    `SELECT gm.user_id FROM tb_group_member gm
     JOIN tb_trip t ON t.group_id = gm.group_id
     WHERE t.trip_id = $1 AND gm.member_role = 'captain' AND gm.status = 'active'
     LIMIT 1`,
    [tripId]
  );
  if (!captain.rows.length) return res.status(404).json({ error: 'Captain not found' });

  const result = await guardianMessageService.sendMessageToCaptain(
    tripId, guardianId, captain.rows[0].user_id, message
  );
  res.json({ success: true, ...result });
}
```

**Verify routes are wired in guardian-messages.routes.ts:**
```typescript
router.post('/member', authenticate, /* requireGuardianOwnsLink, */ sendToMember);
router.post('/captain', authenticate, requireGuardianLinkForTrip, requireCanMessageCaptain, sendToCaptain);
```

---

### Task 6: Build TypeScript and smoke-test all endpoints

**Step 1: Build**
```bash
cd /mnt/d/Project/15_SafeTrip_New/safetrip-server-api
npm run build 2>&1 | tail -20
```
Expected: Exit 0, no errors.

**Step 2: Start server**
```bash
npm run dev > /tmp/safetrip-backend.log 2>&1 &
sleep 3 && tail -20 /tmp/safetrip-backend.log
```
Expected: "Server running on port 3001"

**Step 3: Test guardian list endpoint**
```bash
# Replace TOKEN with a valid Firebase token for a trip member
curl -s http://localhost:3001/api/v1/trips/YOUR_TRIP_ID/guardians/me \
  -H "Authorization: Bearer $TOKEN" | jq .
```
Expected: JSON array (possibly empty).

**Step 4: Test trip settings GET**
```bash
curl -s http://localhost:3001/api/v1/trips/YOUR_TRIP_ID/settings \
  -H "Authorization: Bearer $TOKEN" | jq .
```
Expected: `{"trip_id": "...", "captain_receive_guardian_msg": true}`

**Step 5: Test guardian-view itinerary**
```bash
curl -s http://localhost:3001/api/v1/trips/YOUR_TRIP_ID/guardian-view/itinerary \
  -H "Authorization: Bearer $GUARDIAN_TOKEN" | jq .
```
Expected: `[]` or array of schedules (401 is a problem, 200 with data is success).

**Step 6: Commit**
```bash
cd /mnt/d/Project/15_SafeTrip_New/safetrip-server-api
git add -A
git commit -m "feat: complete guardian system backend implementation"
```

---

## Phase 2: Flutter UI Screens

### Task 7: Audit existing Flutter guardian screens

**Files to read:**
- `safetrip-mobile/lib/screens/trip/screen_guardian_home.dart`
- `safetrip-mobile/lib/screens/trip/screen_guardian_manage.dart`
- `safetrip-mobile/lib/screens/trip/screen_guardian_messages.dart`
- `safetrip-mobile/lib/services/api_service.dart` (guardian methods section)
- `safetrip-mobile/lib/models/guardian_link.dart`

**For each screen, note:**
- Is the UI complete (has actual widgets)?
- Or is it a stub (`return Scaffold(body: Text('TODO'))`)?
- Are API calls being made?

**Also read:**
- `safetrip-mobile/lib/screens/main/bottom_sheets/bottom_sheet_2_member.dart`
  (to see where to add the "내 가디언 관리" button)

Move to Task 8 after audit.

---

### Task 8: Complete screen_guardian_manage.dart (Member's Guardian Management)

**File:** `safetrip-mobile/lib/screens/trip/screen_guardian_manage.dart`

This screen lets a member manage their own guardians (add/remove, see status).

**Full widget structure:**
```dart
class ScreenGuardianManage extends StatefulWidget {
  final String tripId;
  const ScreenGuardianManage({super.key, required this.tripId});

  @override
  State<ScreenGuardianManage> createState() => _ScreenGuardianManageState();
}

class _ScreenGuardianManageState extends State<ScreenGuardianManage> {
  List<Map<String, dynamic>> _guardians = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGuardians();
  }

  Future<void> _loadGuardians() async {
    try {
      final data = await ApiService.instance.getMyGuardians(widget.tripId);
      setState(() {
        _guardians = List<Map<String, dynamic>>.from(data);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  int get _activeCount => _guardians
      .where((g) => g['status'] == 'accepted' || g['status'] == 'pending')
      .length;

  Future<void> _addGuardian() async {
    if (_activeCount >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('가디언은 최대 3명까지 추가할 수 있습니다')),
      );
      return;
    }
    // Reuse existing user search modal
    // showModalBottomSheet(... AddGuardianSearchModal ...)
    // On user selected: ApiService.instance.addGuardian(widget.tripId, phone)
    // Then _loadGuardians()
  }

  Future<void> _removeGuardian(String linkId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('가디언 연결 해제'),
        content: const Text('이 가디언과의 연결을 해제하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('해제')),
        ],
      ),
    );
    if (confirmed != true) return;
    await ApiService.instance.removeGuardianLink(widget.tripId, linkId);
    _loadGuardians();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('내 가디언 ($_activeCount/3)'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _guardians.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.shield_outlined, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('아직 가디언이 없습니다', style: TextStyle(color: Colors.grey)),
                      SizedBox(height: 8),
                      Text('추가 버튼을 눌러 가디언을 초대하세요', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _guardians.length,
                  itemBuilder: (ctx, i) {
                    final g = _guardians[i];
                    final isPending = g['status'] == 'pending';
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundImage: g['profile_image_url'] != null
                              ? NetworkImage(g['profile_image_url']) : null,
                          child: g['profile_image_url'] == null
                              ? const Icon(Icons.person) : null,
                        ),
                        title: Text(g['display_name'] ?? ''),
                        subtitle: Text(g['phone_number'] ?? ''),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isPending ? Colors.orange.shade100 : Colors.green.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                isPending ? '대기중' : '수락됨',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isPending ? Colors.orange.shade800 : Colors.green.shade800,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.red),
                              onPressed: () => _removeGuardian(g['link_id']),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: _activeCount < 3
          ? FloatingActionButton.extended(
              onPressed: _addGuardian,
              icon: const Icon(Icons.add),
              label: const Text('가디언 추가'),
            )
          : null,
    );
  }
}
```

**Step: Add navigation from bottom_sheet_2_member.dart**

In the member's own card section, add a button:
```dart
// Find where the current user's own member card is rendered
// Add this button to the member's own card actions:
OutlinedButton.icon(
  onPressed: () => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => ScreenGuardianManage(tripId: widget.tripId),
    ),
  ),
  icon: const Icon(Icons.shield, size: 16),
  label: const Text('가디언 관리'),
),
```

**Step: Hot reload app and navigate to the screen**

Expected: Screen shows "내 가디언 (0/3)" with empty state and FAB.

---

### Task 9: Complete screen_guardian_home.dart (Guardian's Main View)

**File:** `safetrip-mobile/lib/screens/trip/screen_guardian_home.dart`

This is the main screen for guardian users — shows their linked members and trip info.

**Key sections to implement (if stubs):**

**Tab 1 - Connected Members:**
```dart
// Calls: ApiService.instance.getLinkedMembers(tripId)
// Shows: cards with name, role, location status, message button
// "캡틴에게 메시지" button — disabled if captain_receive_guardian_msg = false

FutureBuilder(
  future: Future.wait([
    ApiService.instance.getLinkedMembers(tripId),
    ApiService.instance.getTripSettings(tripId),
  ]),
  builder: (context, snapshot) {
    if (!snapshot.hasData) return const CircularProgressIndicator();
    final members = snapshot.data![0] as List;
    final settings = snapshot.data![1] as Map;
    final captainMsgEnabled = settings['captain_receive_guardian_msg'] == true;

    return Column(
      children: [
        ...members.map((m) => _MemberCard(member: m, tripId: tripId)),
        const Divider(),
        Tooltip(
          message: captainMsgEnabled ? '' : '캡틴이 메시지를 받지 않고 있습니다',
          child: ElevatedButton.icon(
            onPressed: captainMsgEnabled ? _openCaptainChat : null,
            icon: const Icon(Icons.message),
            label: const Text('캡틴에게 메시지'),
          ),
        ),
      ],
    );
  },
)
```

**Tab 2 - Itinerary (read-only):**
```dart
// Calls: ApiService.instance.getGuardianItinerary(tripId)
// Reuse existing schedule list widget but with all edit controls removed
// Simplest: ScheduleListView(schedules: schedules, readOnly: true)
```

**Step: Verify guardian users are routed to this screen**

In the main trip screen routing logic, check:
```dart
if (currentUserRole == UserRole.guardian) {
  return ScreenGuardianHome(tripId: tripId);
}
```

If missing, add this routing condition.

---

### Task 10: Add captain settings toggle to trip settings screen

**Step 1: Find the trip settings screen**

Search for the existing settings screen:
```bash
grep -r "trip.*setting\|setting.*screen\|SettingScreen\|settings_screen" \
  safetrip-mobile/lib/screens/ --include="*.dart" -l
```

**Step 2: Read the settings screen file**

Identify where to add the guardian section.

**Step 3: Add the toggle**

In the settings screen's build method, add a new section:

```dart
// Add api call in initState:
final settings = await ApiService.instance.getTripSettings(widget.tripId);
setState(() => _captainReceiveGuardianMsg = settings['captain_receive_guardian_msg'] ?? true);

// Add to the settings list UI:
ListTile(
  title: const Text('가디언'),
  tileColor: Colors.grey.shade50,
  dense: true,
),
SwitchListTile(
  title: const Text('가디언 메시지 수신'),
  subtitle: const Text('OFF 시 모든 가디언의 메시지가 차단됩니다'),
  value: _captainReceiveGuardianMsg,
  onChanged: isCaptain ? (value) async {
    await ApiService.instance.updateTripSettings(
      widget.tripId, {'captain_receive_guardian_msg': value}
    );
    setState(() => _captainReceiveGuardianMsg = value);
  } : null,
),
```

**Step 4: Add `updateTripSettings` to api_service.dart if missing**
```dart
Future<void> updateTripSettings(String tripId, Map<String, dynamic> settings) async {
  await _patch('/trips/$tripId/settings', settings);
}

Future<Map<String, dynamic>> getTripSettings(String tripId) async {
  final response = await _get('/trips/$tripId/settings');
  return Map<String, dynamic>.from(response);
}
```

---

### Task 11: Handle pending guardian invitations (Guardian's view)

**Step 1: Find where to show pending invitations for a guardian**

Guardian users should see a notification/banner for pending invitations when they open the app.

**Step 2: Add pending invitations check to guardian home screen**

In `screen_guardian_home.dart`, in `initState`:
```dart
// Load pending invitations
final pending = await ApiService.instance.getPendingGuardianInvitations();
if (pending.isNotEmpty) {
  // Show banner or bottom sheet listing pending invites
  // Each with Accept / Reject buttons
}
```

**Pending invitation card:**
```dart
Card(
  color: Colors.blue.shade50,
  child: ListTile(
    title: Text('${invitation['member_name']}님이 가디언을 요청했습니다'),
    subtitle: Text('${invitation['trip_name']} · ${invitation['country_name']}'),
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton(
          onPressed: () => _respondToInvitation(invitation['link_id'], 'rejected'),
          child: const Text('거절'),
        ),
        ElevatedButton(
          onPressed: () => _respondToInvitation(invitation['link_id'], 'accepted'),
          child: const Text('수락'),
        ),
      ],
    ),
  ),
)
```

```dart
Future<void> _respondToInvitation(String linkId, String action) async {
  await ApiService.instance.respondToGuardianInvitation(
    invitation['trip_id'], linkId, action
  );
  _reload(); // Refresh the screen
}
```

---

### Task 12: Final integration test

**Step 1: Start backend**
```bash
cd /mnt/d/Project/15_SafeTrip_New/safetrip-server-api
npm run dev > /tmp/safetrip-backend.log 2>&1 &
```

**Step 2: Flutter hot reload**
```bash
cd /mnt/d/Project/15_SafeTrip_New/safetrip-mobile
flutter run
```

**Step 3: Test flow as member**
1. Open app as captain/crew member
2. Navigate to member tab → own card → "가디언 관리"
3. Tap "+ 가디언 추가" → search for another user's phone
4. Verify 3-person limit is enforced

**Step 4: Test flow as guardian**
1. Login as the invited guardian user
2. Should see pending invitation
3. Accept it
4. Should now see the connected member in "연결된 멤버" tab
5. Should see "일정" tab with trip schedules (read-only)
6. "캡틴에게 메시지" button should be active

**Step 5: Test captain settings**
1. Login as captain
2. Open trip settings
3. Toggle "가디언 메시지 수신" to OFF
4. Login as guardian → "캡틴에게 메시지" button should be disabled

**Step 6: Commit final**
```bash
cd /mnt/d/Project/15_SafeTrip_New
git add safetrip-mobile/lib/screens/trip/
git add safetrip-mobile/lib/services/api_service.dart
git commit -m "feat: complete Guardian system UI - member manage, guardian home, captain settings"
```

---

## Appendix: Key File Paths

### Backend
```
safetrip-server-api/src/
  services/
    guardian-link.service.ts      ← main guardian CRUD
    guardian-view.service.ts      ← read-only access for guardians
    trip-settings.service.ts      ← captain_receive_guardian_msg UPSERT
    guardian-message.service.ts   ← RTDB message writes
  controllers/
    trip-guardian.controller.ts
    guardian-view.controller.ts
    guardian-messages.controller.ts
    trips.controller.ts           ← add updateTripSettings here
  routes/
    trip-guardian.routes.ts       ← /trips/:tripId/guardians/*
    guardian-view.routes.ts       ← /trips/:tripId/guardian-view/*
    guardian-messages.routes.ts   ← /trips/:tripId/guardian-messages/*
    trips.routes.ts               ← PATCH /trips/:tripId/settings
  middleware/
    guardian-permission.middleware.ts
```

### Flutter
```
safetrip-mobile/lib/
  screens/trip/
    screen_guardian_home.dart     ← guardian main view (tabs: members, itinerary)
    screen_guardian_manage.dart   ← member manages own guardians
    screen_guardian_messages.dart ← chat screen
  screens/main/bottom_sheets/
    bottom_sheet_2_member.dart    ← add "가디언 관리" button to member's own card
  services/
    api_service.dart              ← guardian API methods
  models/
    guardian_link.dart            ← GuardianLink, LinkedMember, GuardianInvitation
```

### RTDB Paths
```
/guardian_messages/{tripId}/{linkId}/messages/{msgId}/
  sender_id, receiver_id, message, message_type, created_at, read_at

/guardian_captain_messages/{tripId}/{guardianId}/messages/{msgId}/
  sender_id, receiver_id, message, created_at, read_at
```
