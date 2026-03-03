# Role Rename Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Rename member role values across the entire SafeTrip codebase: `leader`→`captain`, `full`→`crew_chief`, `normal`→`crew`, `view_only`→`guardian`.

**Architecture:** Three-layer change: (1) DB migration SQL with rollback, (2) Server TypeScript services/controllers, (3) Mobile Dart models/screens/utils. Dart enum consolidates legacy `UserRole.guardian` + `UserRole.viewOnly` into a single `UserRole.guardian` value. The `is_guardian` DB column name stays untouched (legacy).

**Tech Stack:** PostgreSQL (SQL migrations), Node.js/TypeScript (server), Flutter/Dart (mobile)

**Rename Mapping:**
| Old value | New value | Dart enum change |
|-----------|-----------|-----------------|
| `leader` | `captain` | `UserRole.leader` → `UserRole.captain` |
| `full` | `crew_chief` | `UserRole.full` → `UserRole.crewChief` |
| `normal` | `crew` | `UserRole.normal` → `UserRole.crew` |
| `view_only` | `guardian` | `UserRole.viewOnly` → merge into `UserRole.guardian` |

---

## Task 1: DB Migration Script

**Files:**
- Create: `safetrip-server-api/scripts/local/migration-role-rename.sql`

**Step 1: Write the migration script**

Create `/mnt/d/Project/15_SafeTrip_New/safetrip-server-api/scripts/local/migration-role-rename.sql`:

```sql
-- ============================================================
-- Role Rename Migration
-- leader→captain, full→crew_chief, normal→crew, view_only→guardian
-- ============================================================

-- ── FORWARD MIGRATION ────────────────────────────────────────
BEGIN;

-- 1. tb_group_member: DROP CHECK constraint, rename values, ADD new CHECK
ALTER TABLE tb_group_member DROP CONSTRAINT IF EXISTS tb_group_member_member_role_check;

UPDATE tb_group_member SET member_role = 'captain'    WHERE member_role = 'leader';
UPDATE tb_group_member SET member_role = 'crew_chief' WHERE member_role = 'full';
UPDATE tb_group_member SET member_role = 'crew'       WHERE member_role = 'normal';
UPDATE tb_group_member SET member_role = 'guardian'   WHERE member_role = 'view_only';

ALTER TABLE tb_group_member
  ADD CONSTRAINT tb_group_member_member_role_check
  CHECK (member_role IN ('captain', 'crew_chief', 'crew', 'guardian'));

-- 2. tb_invite_code: DROP CHECK constraint, rename values, ADD new CHECK
ALTER TABLE tb_invite_code DROP CONSTRAINT IF EXISTS tb_invite_code_target_role_check;

UPDATE tb_invite_code SET target_role = 'crew_chief' WHERE target_role = 'full';
UPDATE tb_invite_code SET target_role = 'crew'       WHERE target_role = 'normal';
UPDATE tb_invite_code SET target_role = 'guardian'   WHERE target_role = 'view_only';

ALTER TABLE tb_invite_code
  ADD CONSTRAINT tb_invite_code_target_role_check
  CHECK (target_role IN ('crew_chief', 'crew', 'guardian'));

COMMIT;

-- ── VALIDATION ───────────────────────────────────────────────
SELECT 'tb_group_member role counts:' AS info;
SELECT member_role, COUNT(*) FROM tb_group_member GROUP BY member_role ORDER BY member_role;

SELECT 'tb_invite_code target_role counts:' AS info;
SELECT target_role, COUNT(*) FROM tb_invite_code GROUP BY target_role ORDER BY target_role;

-- ── ROLLBACK (run separately to undo) ────────────────────────
-- BEGIN;
-- ALTER TABLE tb_group_member DROP CONSTRAINT IF EXISTS tb_group_member_member_role_check;
-- UPDATE tb_group_member SET member_role = 'leader'    WHERE member_role = 'captain';
-- UPDATE tb_group_member SET member_role = 'full'      WHERE member_role = 'crew_chief';
-- UPDATE tb_group_member SET member_role = 'normal'    WHERE member_role = 'crew';
-- UPDATE tb_group_member SET member_role = 'view_only' WHERE member_role = 'guardian';
-- ALTER TABLE tb_group_member
--   ADD CONSTRAINT tb_group_member_member_role_check
--   CHECK (member_role IN ('leader', 'full', 'normal', 'view_only'));
-- ALTER TABLE tb_invite_code DROP CONSTRAINT IF EXISTS tb_invite_code_target_role_check;
-- UPDATE tb_invite_code SET target_role = 'full'      WHERE target_role = 'crew_chief';
-- UPDATE tb_invite_code SET target_role = 'normal'    WHERE target_role = 'crew';
-- UPDATE tb_invite_code SET target_role = 'view_only' WHERE target_role = 'guardian';
-- ALTER TABLE tb_invite_code
--   ADD CONSTRAINT tb_invite_code_target_role_check
--   CHECK (target_role IN ('full', 'normal', 'view_only'));
-- COMMIT;
```

---

## Task 2: Update 01-init-schema.sql CHECK Constraints

**Files:**
- Modify: `safetrip-server-api/scripts/local/01-init-schema.sql`

**Step 1: Find and replace role values in schema**

In `01-init-schema.sql`, find the CHECK constraint for `member_role`:
```sql
CHECK (member_role IN ('leader', 'full', 'normal', 'view_only'))
```
Replace with:
```sql
CHECK (member_role IN ('captain', 'crew_chief', 'crew', 'guardian'))
```

Find the default value `DEFAULT 'normal'`:
```sql
member_role VARCHAR(20) DEFAULT 'normal'
```
Replace with:
```sql
member_role VARCHAR(20) DEFAULT 'crew'
```

Find tb_invite_code CHECK:
```sql
CHECK (target_role IN ('full', 'normal', 'view_only'))
```
Replace with:
```sql
CHECK (target_role IN ('crew_chief', 'crew', 'guardian'))
```

And default `DEFAULT 'normal'` for target_role:
```sql
target_role VARCHAR(20) DEFAULT 'normal'
```
→
```sql
target_role VARCHAR(20) DEFAULT 'crew'
```

---

## Task 3: Update 02-seed-test-data.sql

**Files:**
- Modify: `safetrip-server-api/scripts/local/02-seed-test-data.sql`

**Step 1: Replace role values in seed data**

Search for any occurrences of `'leader'`, `'full'`, `'normal'`, `'view_only'` in the seed file and replace:
- `'leader'` → `'captain'`
- `'full'` → `'crew_chief'`
- `'normal'` → `'crew'`
- `'view_only'` → `'guardian'`

---

## Task 4: Update permission.service.ts

**Files:**
- Modify: `safetrip-server-api/src/services/permission.service.ts`

**Step 1: Replace role strings and comments**

In `permission.service.ts`:

Line 38-40 (isGroupAdmin query):
```typescript
AND member_role IN ('leader', 'full') AND status = 'active'`,
```
→
```typescript
AND member_role IN ('captain', 'crew_chief') AND status = 'active'`,
```

Line 58-60 (isGroupLeader query):
```typescript
AND member_role = 'leader' AND status = 'active'`,
```
→
```typescript
AND member_role = 'captain' AND status = 'active'`,
```

Line 79 (comment):
```typescript
* @returns member_role 값 (leader, full, normal, view_only) 또는 null
```
→
```typescript
* @returns member_role 값 (captain, crew_chief, crew, guardian) 또는 null
```

---

## Task 5: Update groups.service.ts

**Files:**
- Modify: `safetrip-server-api/src/services/groups.service.ts`

**Step 1: Replace all role string values**

Replace every occurrence (use exact strings from the file):

```typescript
AND member_role = 'view_only'
```
→
```typescript
AND member_role = 'guardian'
```

```typescript
CASE WHEN gm.member_role IN ('leader', 'full') THEN TRUE ELSE FALSE END as is_admin,
CASE WHEN gm.member_role = 'view_only' THEN TRUE ELSE FALSE END as is_guardian,
```
→
```typescript
CASE WHEN gm.member_role IN ('captain', 'crew_chief') THEN TRUE ELSE FALSE END as is_admin,
CASE WHEN gm.member_role = 'guardian' THEN TRUE ELSE FALSE END as is_guardian,
```

(This pattern appears TWICE in the file - both the guardian-filtered query and the full query. Replace all occurrences.)

```typescript
AND gm.member_role != 'view_only'
```
→
```typescript
AND gm.member_role != 'guardian'
```

(Appears TWICE - replace both.)

CASE sort block (appears TWICE):
```typescript
CASE gm.member_role
          WHEN 'leader' THEN 1
          WHEN 'full' THEN 2
          WHEN 'normal' THEN 3
          ELSE 4
        END,
```
→
```typescript
CASE gm.member_role
          WHEN 'captain' THEN 1
          WHEN 'crew_chief' THEN 2
          WHEN 'crew' THEN 3
          ELSE 4
        END,
```

```typescript
// member_role 결정: 명시적 값 > is_admin 기반 추론 > 기본값 'normal'
    const memberRole = options.member_role
      || (options.is_admin ? 'full' : 'normal');
```
→
```typescript
// member_role 결정: 명시적 값 > is_admin 기반 추론 > 기본값 'crew'
    const memberRole = options.member_role
      || (options.is_admin ? 'crew_chief' : 'crew');
```

```typescript
const isAdmin = ['leader', 'full'].includes(memberRole);
    const isGuardian = memberRole === 'view_only';
```
→
```typescript
const isAdmin = ['captain', 'crew_chief'].includes(memberRole);
    const isGuardian = memberRole === 'guardian';
```

In updateMemberPermissions (line ~331):
```typescript
if (permissions.member_role === 'leader') {
      throw new Error('Cannot directly assign leader role. Use transferLeadership instead.');
    }
```
→
```typescript
if (permissions.member_role === 'captain') {
      throw new Error('Cannot directly assign captain role. Use transferLeadership instead.');
    }
```

```typescript
if (currentMember.rows[0].member_role === 'leader' && permissions.member_role && permissions.member_role !== 'leader') {
      throw new Error('Cannot change leader role directly. Use transferLeadership instead.');
    }
```
→
```typescript
if (currentMember.rows[0].member_role === 'captain' && permissions.member_role && permissions.member_role !== 'captain') {
      throw new Error('Cannot change captain role directly. Use transferLeadership instead.');
    }
```

```typescript
const syncIsAdmin = ['leader', 'full'].includes(permissions.member_role);
```
→
```typescript
const syncIsAdmin = ['captain', 'crew_chief'].includes(permissions.member_role);
```

```typescript
const syncIsGuardian = permissions.member_role === 'view_only';
```
→
```typescript
const syncIsGuardian = permissions.member_role === 'guardian';
```

Legacy fallback (line ~376):
```typescript
const syncRole = permissions.is_admin ? 'full' : 'normal';
```
→
```typescript
const syncRole = permissions.is_admin ? 'crew_chief' : 'crew';
```

In checkMemberPermission (line ~499):
```typescript
const isAdmin = ['leader', 'full'].includes(member.member_role);
```
→
```typescript
const isAdmin = ['captain', 'crew_chief'].includes(member.member_role);
```

In getRecentGroups (line ~643):
```typescript
CASE WHEN gm.member_role IN ('leader', 'full') THEN TRUE ELSE FALSE END AS is_admin
```
→
```typescript
CASE WHEN gm.member_role IN ('captain', 'crew_chief') THEN TRUE ELSE FALSE END AS is_admin
```

---

## Task 6: Update leader-transfer.service.ts

**Files:**
- Modify: `safetrip-server-api/src/services/leader-transfer.service.ts`

**Step 1: Replace role strings**

Line 4-7 comment:
```typescript
 * 트랜잭션으로 old leader → full, new leader → leader, TB_GROUP.owner_user_id 변경, 이력 기록
```
→
```typescript
 * 트랜잭션으로 old captain → crew_chief, new captain → captain, TB_GROUP.owner_user_id 변경, 이력 기록
```

Line 21:
```typescript
if (currentLeader.rows.length === 0 || currentLeader.rows[0].member_role !== 'leader') {
      throw new Error('Only the current leader can transfer leadership');
    }
```
→
```typescript
if (currentLeader.rows.length === 0 || currentLeader.rows[0].member_role !== 'captain') {
      throw new Error('Only the current captain can transfer leadership');
    }
```

Line 40-41 comment + query:
```typescript
// 1. old leader → full
      await client.query(
        `UPDATE tb_group_member SET member_role = 'full', is_admin = TRUE WHERE group_id = $1 AND user_id = $2`,
```
→
```typescript
// 1. old captain → crew_chief
      await client.query(
        `UPDATE tb_group_member SET member_role = 'crew_chief', is_admin = TRUE WHERE group_id = $1 AND user_id = $2`,
```

Line 46-48 comment + query:
```typescript
// 2. new leader → leader
      await client.query(
        `UPDATE tb_group_member SET member_role = 'leader', is_admin = TRUE WHERE group_id = $1 AND user_id = $2`,
```
→
```typescript
// 2. new captain → captain
      await client.query(
        `UPDATE tb_group_member SET member_role = 'captain', is_admin = TRUE WHERE group_id = $1 AND user_id = $2`,
```

---

## Task 7: Update invite-code.service.ts

**Files:**
- Modify: `safetrip-server-api/src/services/invite-code.service.ts`

**Step 1: Replace role strings and type**

Line 6 (comment):
```typescript
 * Prefix: A=full, M=normal, V=view_only + 6자리 랜덤 = 7자리 코드
```
→
```typescript
 * Prefix: A=crew_chief, M=crew, V=guardian + 6자리 랜덤 = 7자리 코드
```

Line 16 (type):
```typescript
target_role: 'full' | 'normal' | 'view_only';
```
→
```typescript
target_role: 'crew_chief' | 'crew' | 'guardian';
```

Lines 23-25 (prefix mapping):
```typescript
const prefix = options.target_role === 'full' ? 'A'
      : options.target_role === 'view_only' ? 'V'
      : 'M';
```
→
```typescript
const prefix = options.target_role === 'crew_chief' ? 'A'
      : options.target_role === 'guardian' ? 'V'
      : 'M';
```

---

## Task 8: Update invite-codes.controller.ts

**Files:**
- Modify: `safetrip-server-api/src/controllers/invite-codes.controller.ts`

**Step 1: Replace role strings in validation and comments**

Line 11 comment:
```typescript
   * POST /api/v1/groups/:groupId/invite-codes
   * 역할별 초대코드 생성 (leader/full만)
```
→
```typescript
   * POST /api/v1/groups/:groupId/invite-codes
   * 역할별 초대코드 생성 (captain/crew_chief만)
```

Line 27:
```typescript
if (!target_role || !['full', 'normal', 'view_only'].includes(target_role)) {
        sendError(res, 'target_role must be one of: full, normal, view_only', 400);
```
→
```typescript
if (!target_role || !['crew_chief', 'crew', 'guardian'].includes(target_role)) {
        sendError(res, 'target_role must be one of: crew_chief, crew, guardian', 400);
```

Line 54 comment:
```typescript
   * GET /api/v1/groups/:groupId/invite-codes
   * 그룹의 초대코드 목록 (leader/full만)
```
→
```typescript
   * GET /api/v1/groups/:groupId/invite-codes
   * 그룹의 초대코드 목록 (captain/crew_chief만)
```

Line 82 comment:
```typescript
   * DELETE /api/v1/groups/:groupId/invite-codes/:codeId
   * 초대코드 비활성화 (leader/full만)
```
→
```typescript
   * DELETE /api/v1/groups/:groupId/invite-codes/:codeId
   * 초대코드 비활성화 (captain/crew_chief만)
```

---

## Task 9: Update leader-transfer.controller.ts

**Files:**
- Modify: `safetrip-server-api/src/controllers/leader-transfer.controller.ts`

**Step 1: Replace comments referencing old role names**

Replace any occurrences of `leader` (as role description in comments) with `캡틴(captain)`, and `full` with `크루장(crew_chief)`.

Specifically:
- `리더십 양도 (현재 leader만)` → `리더십 양도 (현재 captain만)`
- `리더 양도 이력 조회 (leader/full만)` → `리더 양도 이력 조회 (captain/crew_chief만)`

---

## Task 10: Update models/user.dart (Dart enum core)

**Files:**
- Modify: `safetrip-mobile/lib/models/user.dart`

**Step 1: Rewrite the UserRole enum and extension**

Replace the entire enum and extension block (lines 50-123):

```dart
enum UserRole {
  traveler,    // 여행자 (레거시 호환)
  captain,     // 캡틴 - 최고관리자 (그룹 생성·삭제, 전체 권한)
  crewChief,   // 크루장 - 부관리자 (멤버 관리, 권한 위임 수신)
  crew,        // 크루 - 일반 멤버 (여행 참여, 위치 공유)
  guardian,    // 가디언 - 보호자 (위치 모니터링, SOS 수신)
}

/// UserRole 확장 메서드
extension UserRoleExtension on UserRole {
  /// 관리자 권한 여부 (captain 또는 crewChief)
  bool get isAdmin => this == UserRole.captain || this == UserRole.crewChief;

  /// 보호자/모니터링 전용 여부
  bool get isGuardian => this == UserRole.guardian;

  /// 여행자 여부 (guardian이 아닌 모든 역할)
  bool get isTraveler => !isGuardian;

  /// 서버 member_role 문자열로 변환
  String get memberRoleString {
    switch (this) {
      case UserRole.captain:
        return 'captain';
      case UserRole.crewChief:
        return 'crew_chief';
      case UserRole.crew:
        return 'crew';
      case UserRole.guardian:
        return 'guardian';
      case UserRole.traveler:
        return 'crew';
    }
  }

  /// 서버 member_role 문자열에서 UserRole 변환
  static UserRole fromMemberRole(String? memberRole) {
    switch (memberRole) {
      case 'captain':
        return UserRole.captain;
      case 'crew_chief':
        return UserRole.crewChief;
      case 'crew':
        return UserRole.crew;
      case 'guardian':
        return UserRole.guardian;
      default:
        return UserRole.traveler;
    }
  }

  /// 서버 user_role 문자열에서 UserRole 변환 (레거시 호환)
  static UserRole fromString(String? role) {
    switch (role) {
      case 'guardian':
        return UserRole.guardian;
      case 'traveler':
        return UserRole.traveler;
      case 'captain':
        return UserRole.captain;
      case 'crew_chief':
        return UserRole.crewChief;
      case 'crew':
        return UserRole.crew;
      default:
        return UserRole.traveler;
    }
  }
}
```

**Note:** `User.fromJson` uses `UserRole.values.firstWhere` with `e.toString().split('.').last == json['role']` — this uses the Dart enum name, NOT the server string. After rename, `UserRole.traveler` stays as `'traveler'` in this context, so `User.fromJson` still works as long as the stored value matches the new enum name. This is fine since this is only used for the local `User` class (not the member_role API).

---

## Task 11: Update utils/guardian_filter.dart

**Files:**
- Modify: `safetrip-mobile/lib/utils/guardian_filter.dart`

**Step 1: Replace 'view_only' with 'guardian'**

There are 3 occurrences of `member_role == 'view_only'`. Replace ALL:

```dart
currentUserMember['member_role'] == 'view_only'
```
→
```dart
currentUserMember['member_role'] == 'guardian'
```

This pattern appears on lines 35, 120, and 163 (approximately). Use `replace_all: true` in Edit tool.

---

## Task 12: Update utils/app_cache.dart

**Files:**
- Modify: `safetrip-mobile/lib/utils/app_cache.dart`

**Step 1: Update comment**

```dart
static String? _memberRole; // 'leader' | 'full' | 'normal' | 'view_only' (신규 역할)
```
→
```dart
static String? _memberRole; // 'captain' | 'crew_chief' | 'crew' | 'guardian' (신규 역할)
```

---

## Task 13: Update screens/settings/screen_settings.dart

**Files:**
- Modify: `safetrip-mobile/lib/screens/settings/screen_settings.dart`

**Step 1: Replace role string comparisons and comment**

Line 24 (comment):
```dart
final String userRole; // leader / full / normal / view_only
```
→
```dart
final String userRole; // captain / crew_chief / crew / guardian
```

Lines 49-53 (getters):
```dart
bool get _isAdmin =>
      widget.userRole == 'leader' || widget.userRole == 'full';
  bool get _isLeader => widget.userRole == 'leader';
  bool get _showLocation =>
      widget.userRole != 'view_only' && widget.userRole != 'guardian';
```
→
```dart
bool get _isAdmin =>
      widget.userRole == 'captain' || widget.userRole == 'crew_chief';
  bool get _isLeader => widget.userRole == 'captain';
  bool get _showLocation => widget.userRole != 'guardian';
```

---

## Task 14: Update screens/main/bottom_sheets/modals/leader_transfer_modal.dart

**Files:**
- Modify: `safetrip-mobile/lib/screens/main/bottom_sheets/modals/leader_transfer_modal.dart`

**Step 1: Replace role strings and comments**

Line 6 (comment):
```dart
/// leader가 full 역할 멤버에게 리더십을 양도하는 UI
```
→
```dart
/// captain이 crew_chief 역할 멤버에게 리더십을 양도하는 UI
```

Lines 46 (eligibility filter):
```dart
return (role == 'full' || role == 'normal') &&
```
→
```dart
return (role == 'crew_chief' || role == 'crew') &&
```

Lines 268-272 (roleName display):
```dart
final roleName = role == 'full'
                            ? '공동관리자'
                            : role == 'normal'
                                ? '일반 멤버'
                                : role;
```
→
```dart
final roleName = role == 'crew_chief'
                            ? '크루장'
                            : role == 'crew'
                                ? '크루'
                                : role;
```

Line 98 (confirmation dialog text):
```dart
const TextSpan(
                text: '양도 후 나의 역할은 공동관리자(full)로 변경됩니다.',
              ),
```
→
```dart
const TextSpan(
                text: '양도 후 나의 역할은 크루장(crew_chief)으로 변경됩니다.',
              ),
```

Line 229 (info text):
```dart
'리더 권한을 양도할 멤버를 선택하세요.\n양도 후 나의 역할은 공동관리자로 변경됩니다.',
```
→
```dart
'리더 권한을 양도할 멤버를 선택하세요.\n양도 후 나의 역할은 크루장으로 변경됩니다.',
```

---

## Task 15: Update screens/main/bottom_sheets/modals/add_member_modal.dart

**Files:**
- Modify: `safetrip-mobile/lib/screens/main/bottom_sheets/modals/add_member_modal.dart`

**Step 1: Replace role strings and labels**

Line 70 (default):
```dart
String selectedRole = 'normal';
```
→
```dart
String selectedRole = 'crew';
```

Lines 108-111 (dropdown items):
```dart
items: const [
                  DropdownMenuItem(value: 'full', child: Text('공동관리자')),
                  DropdownMenuItem(value: 'normal', child: Text('일반 멤버')),
                  DropdownMenuItem(value: 'view_only', child: Text('모니터링 전용')),
                ],
```
→
```dart
items: const [
                  DropdownMenuItem(value: 'crew_chief', child: Text('크루장')),
                  DropdownMenuItem(value: 'crew', child: Text('크루')),
                  DropdownMenuItem(value: 'guardian', child: Text('가디언')),
                ],
```

---

## Task 16: Update screens/main/bottom_sheets/bottom_sheet_2_member.dart

**Files:**
- Modify: `safetrip-mobile/lib/screens/main/bottom_sheets/bottom_sheet_2_member.dart`

**Step 1: Replace role string comparisons**

Lines 887-890 (admin button visibility):
```dart
if (_getCurrentUserRole() ==
                                                    'leader' ||
                                                _getCurrentUserRole() ==
                                                    'full')
```
→
```dart
if (_getCurrentUserRole() ==
                                                    'captain' ||
                                                _getCurrentUserRole() ==
                                                    'crew_chief')
```

Lines 2055, 2058, 2061 (default role fallback):
```dart
if (_currentUserId == null) return 'normal';
```
→
```dart
if (_currentUserId == null) return 'crew';
```

```dart
return (user['member_role'] as String?) ?? 'normal';
```
→
```dart
return (user['member_role'] as String?) ?? 'crew';
```

```dart
return 'normal';
```
→
```dart
return 'crew';
```

Lines 2067-2068:
```dart
final isLeader = role == 'leader';
    final isLeaderOrFull = isLeader || role == 'full';
```
→
```dart
final isLeader = role == 'captain';
    final isLeaderOrFull = isLeader || role == 'crew_chief';
```

Line 2100 comment:
```dart
// 초대코드 관리 (leader, full)
```
→
```dart
// 초대코드 관리 (captain, crew_chief)
```

Line 2112-2113 comment:
```dart
// 리더 양도 (leader만)
```
→
```dart
// 리더 양도 (captain만)
```

---

## Task 17: Update screens/main/screen_main.dart

**Files:**
- Modify: `safetrip-mobile/lib/screens/main/screen_main.dart`

**Step 1: Replace role string values (NOT legacy userRole references)**

Line ~658-661 (view_only fallback mapping):
```dart
} else {
          // view_only(보호자)는 getGroupMembers에서 제외됨 → 캐시 fallback
          final savedRole = AppCache.userRoleSync ?? '';
          if (savedRole == 'guardian') {
            resolvedUserRole = 'view_only';
          }
```
→
```dart
} else {
          // guardian(보호자)는 getGroupMembers에서 제외됨 → 캐시 fallback
          final savedRole = AppCache.userRoleSync ?? '';
          if (savedRole == 'guardian') {
            resolvedUserRole = 'guardian';
          }
```

Line ~668:
```dart
if (creatorId == currentUserId && resolvedUserRole == 'traveler') {
          resolvedUserRole = 'leader';
```
→
```dart
if (creatorId == currentUserId && resolvedUserRole == 'traveler') {
          resolvedUserRole = 'captain';
```

Line ~700-702 (guardian count):
```dart
_guardianCount = members
            .where((m) =>
                (m['user_role'] as String?) == 'guardian' ||
                (m['member_role'] as String?) == 'view_only')
            .length;
```
→
```dart
_guardianCount = members
            .where((m) =>
                (m['user_role'] as String?) == 'guardian' ||
                (m['member_role'] as String?) == 'guardian')
            .length;
```

Line ~753:
```dart
userRole: data['member_role'] as String? ?? 'normal',
```
→
```dart
userRole: data['member_role'] as String? ?? 'crew',
```

**Note:** Lines referencing `userRole == 'guardian'` (checking if current user is a guardian for location service init) do NOT need change — these already use `'guardian'` which is the new value for `view_only`.

---

## Task 18: Scan and Update Remaining Dart Files

**Files:**
- Modify: any remaining files with role strings

**Step 1: Check and update the following files for role string occurrences**

Run a grep to confirm each file's changes needed:

Files confirmed to need changes based on the search:
- `safetrip-mobile/lib/screens/settings/screen_settings_location.dart` — check for role comparisons
- `safetrip-mobile/lib/widgets/trip_info_card.dart` — check for role labels
- `safetrip-mobile/lib/widgets/trip_list_accordion.dart` — check for role labels
- `safetrip-mobile/lib/widgets/trip_switch_modal.dart` — check for role comparisons
- `safetrip-mobile/lib/services/api_service.dart` — check for role strings in API calls
- `safetrip-mobile/lib/screens/trip/screen_trip_guardian_approval.dart`
- `safetrip-mobile/lib/screens/trip/screen_trip_join_code.dart`
- `safetrip-mobile/lib/screens/trip/screen_trip_confirm.dart`
- `safetrip-mobile/lib/screens/main/bottom_sheets/modals/invite_code_management_modal.dart`
- `safetrip-mobile/lib/screens/main/bottom_sheets/modals/invite_modal.dart`
- `safetrip-mobile/lib/managers/firebase_location_manager.dart`
- `safetrip-mobile/lib/services/location_service.dart`
- `safetrip-mobile/lib/services/user_location_status_service.dart`
- `safetrip-mobile/lib/screens/main/screen_attendance_check.dart`

For each file:
1. Read the file
2. Find any role value strings (`'leader'`, `'full'`, `'normal'`, `'view_only'`, `'viewOnly'`) that refer to member roles
3. Replace with new values (`'captain'`, `'crew_chief'`, `'crew'`, `'guardian'`)
4. Also update any Korean UI labels: `공동관리자`→`크루장`, `일반 멤버`→`크루`, `모니터링 전용`→`가디언`, `리더`→`캡틴`

**IMPORTANT:** Do NOT change:
- `'guardian'` in `AppCache.userRoleSync` context (this is legacy `user_role` field, coincidentally the same string as new guardian role — leave as is)
- `is_guardian` column name references
- `guardian_filter.dart` class/method names

---

## Task 19: Update invite_code_management_modal.dart and invite_modal.dart

**Files:**
- Modify: `safetrip-mobile/lib/screens/main/bottom_sheets/modals/invite_code_management_modal.dart`
- Modify: `safetrip-mobile/lib/screens/main/bottom_sheets/modals/invite_modal.dart`

**Step 1: Read both files and replace role strings**

In `invite_code_management_modal.dart`, look for:
- `'full'` → `'crew_chief'`
- `'normal'` → `'crew'`
- `'view_only'` → `'guardian'`
- UI labels: `공동관리자`→`크루장`, `일반 멤버`→`크루`, `모니터링 전용`→`가디언`
- Prefix descriptions: `A=full` → `A=crew_chief`, `M=normal` → `M=crew`, `V=view_only` → `V=guardian`

---

## Task 20: Update safetrip-document database-schema.sql

**Files:**
- Modify: `safetrip-document/03-database/database-schema.sql`

**Step 1: Replace role values in documentation schema**

Find and replace CHECK constraints and comments mentioning old role names.

---

## Execution Order

Execute tasks in this order (tasks 2-3 can be skipped in production if schema is already applied via migration):
1. Task 1 (DB migration script) — create first, run last in production
2. Task 2 (init schema) — dev environment only
3. Task 3 (seed data) — dev environment only
4. Tasks 4-9 (server TypeScript) — can run in parallel
5. Tasks 10-19 (mobile Dart) — can run in parallel after Task 10
6. Task 20 (docs) — last

**Production deployment order:**
1. Run `migration-role-rename.sql` on DB
2. Deploy updated server
3. Publish updated mobile app
