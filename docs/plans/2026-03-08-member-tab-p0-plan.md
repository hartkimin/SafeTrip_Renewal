# 멤버탭 P0 원칙 준수 구현 계획

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 멤버탭에서 자기 자신 포함 전체 멤버가 올바르게 표시되도록 백엔드 API를 보강하고 프론트엔드 데이터 연결을 완성한다 (DOC-T3-MBR-019 §15 P0 항목 5건).

**Architecture:** 백엔드 `getMembers()`를 `tb_group_member JOIN tb_user` + RTDB 상태 병합 + `tb_guardian_link` 서브쿼리로 보강. 프론트엔드는 `fetchMembers()`의 ID 전달 버그 수정 + 보호자 섹션 개선. UI 위젯(`MemberCard`, `_StatusDot`, `_RoleBadge` 등)은 이미 구현 완료되어 데이터만 연결하면 동작.

**Tech Stack:** NestJS/TypeORM (backend), Firebase Admin RTDB (realtime status), Flutter/Riverpod (frontend)

---

## Task 1: 백엔드 `getMembers()` — JOIN 쿼리 + 가디언 링크 보강

**Files:**
- Modify: `safetrip-server-api/src/modules/groups/groups.service.ts:164-168` (getMembers 메서드)
- Modify: `safetrip-server-api/src/modules/groups/groups.module.ts:14-16` (imports에 User 추가)

**Step 1: `groups.module.ts`에 User 엔티티 import 추가**

`groups.module.ts`의 TypeOrmModule.forFeature 배열에 `User` 엔티티를 추가한다:

```typescript
// groups.module.ts 상단 import 추가
import { User } from '../../entities/user.entity';

// TypeOrmModule.forFeature 배열에 User 추가
TypeOrmModule.forFeature([Group, GroupMember, InviteCode, Trip, Schedule, GuardianLink, LocationSharing, User]),
```

**Step 2: `groups.service.ts`의 `getMembers()` 메서드를 raw SQL JOIN + 가디언 링크로 교체**

현재 코드 (groups.service.ts:164-168):
```typescript
async getMembers(tripId: string) {
    return this.memberRepo.find({
        where: { tripId, status: 'active' },
    });
}
```

새 코드로 전체 교체:
```typescript
async getMembers(tripId: string) {
    // 1. PostgreSQL: 멤버 + 유저 프로필 JOIN
    const members = await this.dataSource.query(`
        SELECT
            gm.user_id,
            COALESCE(u.display_name, '') AS user_name,
            u.profile_image_url,
            gm.member_role,
            gm.location_sharing_enabled AS is_schedule_on,
            u.privacy_level,
            u.date_of_birth,
            u.minor_status
        FROM tb_group_member gm
        LEFT JOIN tb_user u ON gm.user_id = u.user_id
        WHERE gm.trip_id = $1 AND gm.status = 'active'
        ORDER BY
            CASE gm.member_role
                WHEN 'captain' THEN 0
                WHEN 'crew_chief' THEN 1
                WHEN 'crew' THEN 2
            END,
            u.display_name ASC
    `, [tripId]);

    // 2. 각 멤버별 가디언 링크 조회
    const guardianLinks = await this.dataSource.query(`
        SELECT
            gl.link_id,
            gl.member_id AS member_user_id,
            gl.guardian_id AS guardian_user_id,
            COALESCE(gu.display_name, '') AS guardian_name,
            gu.profile_image_url AS guardian_profile_image_url,
            gl.is_paid,
            gl.status,
            gl.payment_id,
            gp.resume_at AS paused_until
        FROM tb_guardian_link gl
        LEFT JOIN tb_user gu ON gl.guardian_id = gu.user_id
        LEFT JOIN tb_guardian_pause gp
            ON gp.link_id = gl.link_id AND gp.is_active = true
        WHERE gl.trip_id = $1
          AND gl.status != 'rejected'
    `, [tripId]);

    // 3. 가디언 링크를 member_user_id로 그룹핑
    const guardianMap = new Map<string, any[]>();
    for (const gl of guardianLinks) {
        const key = gl.member_user_id;
        if (!guardianMap.has(key)) guardianMap.set(key, []);
        guardianMap.get(key)!.push({
            link_id: gl.link_id,
            guardian_user_id: gl.guardian_user_id,
            guardian_name: gl.guardian_name,
            guardian_profile_image_url: gl.guardian_profile_image_url,
            is_paid: gl.is_paid,
            status: gl.status,
            payment_id: gl.payment_id,
            paused_until: gl.paused_until,
        });
    }

    // 4. 멤버 데이터 조합 (미성년자 판별 포함)
    return members.map(m => ({
        user_id: m.user_id,
        user_name: m.user_name,
        profile_image_url: m.profile_image_url,
        member_role: m.member_role,
        is_online: false,           // Task 2에서 RTDB 병합
        is_sos_active: false,       // Task 2에서 RTDB 병합
        battery_level: null,        // Task 2에서 RTDB 병합
        last_location_text: null,   // Task 2에서 RTDB 병합
        last_location_updated_at: null,
        latitude: null,
        longitude: null,
        privacy_level: m.privacy_level || 'standard',
        is_schedule_on: m.is_schedule_on ?? true,
        is_minor: m.minor_status !== 'adult',
        guardian_links: guardianMap.get(m.user_id) || [],
    }));
}
```

**Step 3: 서버 컴파일 확인**

Run: `cd safetrip-server-api && npx tsc --noEmit 2>&1 | head -20`
Expected: 에러 없음 또는 기존 에러만

**Step 4: 커밋**

```bash
git add safetrip-server-api/src/modules/groups/groups.service.ts safetrip-server-api/src/modules/groups/groups.module.ts
git commit -m "feat(backend): enrich getMembers with user profile + guardian links JOIN"
```

---

## Task 2: 백엔드 `getMembers()` — RTDB 실시간 상태 병합

**Files:**
- Modify: `safetrip-server-api/src/modules/groups/groups.service.ts` (constructor + getMembers)

**Step 1: `groups.service.ts` constructor에 Firebase Admin 주입 추가**

constructor에 `@Inject(FIREBASE_APP)` 파라미터를 추가한다:

```typescript
// 상단 import 추가
import { FIREBASE_APP } from '../../config/firebase/firebase.module';
import * as admin from 'firebase-admin';

// constructor 수정 — 기존 파라미터 유지, 마지막에 추가
constructor(
    @InjectRepository(Group) private groupRepo: Repository<Group>,
    @InjectRepository(GroupMember) private memberRepo: Repository<GroupMember>,
    @InjectRepository(InviteCode) private inviteCodeRepo: Repository<InviteCode>,
    @InjectRepository(Trip) private tripRepo: Repository<Trip>,
    @InjectRepository(Schedule) private scheduleRepo: Repository<Schedule>,
    @InjectRepository(GuardianLink) private guardianLinkRepo: Repository<GuardianLink>,
    @InjectRepository(LocationSharing) private locationSharingRepo: Repository<LocationSharing>,
    private dataSource: DataSource,
    @Inject(FIREBASE_APP) private firebaseApp: admin.app.App,
) { }
```

**Step 2: `getMembers()` 반환 직전에 RTDB 병합 로직 추가**

Task 1의 `return members.map(...)` 직전에 RTDB 조회 코드를 삽입하고, 병합 결과를 반환:

```typescript
// Task 1의 "4. 멤버 데이터 조합" 부분을 아래로 교체:

// 4. RTDB에서 실시간 상태 일괄 조회
let rtdbData: Record<string, any> = {};
try {
    const rtdbRef = this.firebaseApp.database()
        .ref(`trips/${tripId}/members`);
    const snapshot = await rtdbRef.once('value');
    rtdbData = snapshot.val() || {};
} catch (e) {
    // RTDB 실패해도 기본 데이터는 반환 (graceful degradation)
    console.warn(`[getMembers] RTDB read failed for trip ${tripId}:`, e);
}

// 5. 멤버 데이터 조합 (RTDB 병합 + 미성년자 판별)
return members.map(m => {
    const rtdb = rtdbData[m.user_id] || {};
    return {
        user_id: m.user_id,
        user_name: m.user_name,
        profile_image_url: m.profile_image_url,
        member_role: m.member_role,
        is_online: rtdb.online ?? false,
        is_sos_active: rtdb.sos_active ?? false,
        battery_level: rtdb.battery ?? null,
        last_location_text: rtdb.location_text ?? null,
        last_location_updated_at: rtdb.location_updated_at ?? null,
        latitude: rtdb.latitude ?? null,
        longitude: rtdb.longitude ?? null,
        privacy_level: m.privacy_level || 'standard',
        is_schedule_on: m.is_schedule_on ?? true,
        is_minor: m.minor_status !== 'adult',
        guardian_links: guardianMap.get(m.user_id) || [],
    };
});
```

**Step 3: 서버 컴파일 확인**

Run: `cd safetrip-server-api && npx tsc --noEmit 2>&1 | head -20`
Expected: 에러 없음

**Step 4: 커밋**

```bash
git add safetrip-server-api/src/modules/groups/groups.service.ts
git commit -m "feat(backend): merge RTDB realtime status into getMembers response"
```

---

## Task 3: 프론트엔드 — `fetchMembers()` ID 전달 버그 수정

**Files:**
- Modify: `safetrip-mobile/lib/features/member/providers/member_tab_provider.dart:242-252` (fetchMembers)

**문제:**
`fetchMembers()`가 `_apiService.getGroupMembers(state.groupId)`를 호출하지만, 컨트롤러의 `@Get(':tripId/members')` 라우트는 path param을 `tripId`로 사용하여 `WHERE trip_id = $1` 쿼리를 실행한다. `groupId`와 `tripId`가 다르면 멤버가 0건 반환된다.

**Step 1: `fetchMembers()` 수정 — tripId 우선 사용**

`member_tab_provider.dart` 242행 부근의 `fetchMembers()` 내부:

현재:
```dart
final data = await _apiService.getGroupMembers(groupId);
```

변경:
```dart
// tripId 우선 사용 (백엔드 라우트가 tripId 기준)
final id = state.tripId ?? groupId;
final data = await _apiService.getGroupMembers(id);
```

**Step 2: 앱 빌드 확인**

Run: `cd safetrip-mobile && flutter analyze lib/features/member/providers/member_tab_provider.dart 2>&1 | tail -5`
Expected: No issues found

**Step 3: 커밋**

```bash
git add safetrip-mobile/lib/features/member/providers/member_tab_provider.dart
git commit -m "fix(flutter): use tripId instead of groupId for member list API call"
```

---

## Task 4: 프론트엔드 — 보호자 섹션 가디언 슬롯 카운트 헤더 개선

**Files:**
- Modify: `safetrip-mobile/lib/screens/main/bottom_sheets/bottom_sheet_2_member.dart` (보호자 섹션 헤더)

**Step 1: `_GuardianSectionHeader` 위젯에 무료/유료 카운트 표시 추가**

현재 `_GuardianSectionHeader`의 구현을 찾아서 무료/유료 가디언 슬롯 카운트를 표시하도록 수정:

```dart
// _GuardianSectionHeader에 freeCount, paidCount 파라미터 추가
class _GuardianSectionHeader extends StatelessWidget {
  const _GuardianSectionHeader({
    required this.guardianCount,
    required this.isCaptain,
    this.onManageTap,
    this.freeCount = 0,
    this.paidCount = 0,
  });

  final int guardianCount;
  final bool isCaptain;
  final VoidCallback? onManageTap;
  final int freeCount;
  final int paidCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '보호자',
          style: AppTypography.titleSmall.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        // 무료/유료 슬롯 카운트 (§5.1)
        Text(
          '🆓 $freeCount/2  💎 $paidCount/3',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textTertiary,
          ),
        ),
        const Spacer(),
        if (isCaptain)
          GestureDetector(
            onTap: onManageTap,
            child: Text(
              '관리',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.primaryTeal,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}
```

**Step 2: 보호자 섹션 호출 부분에서 freeCount/paidCount 전달**

`build()` 메서드 내 보호자 섹션 부분:

```dart
// (7) 보호자 섹션
if (memberState.guardianSlots.isNotEmpty) ...[
  _GuardianSectionHeader(
    guardianCount: memberState.guardianSlots.length,
    isCaptain: memberState.isCaptain,
    onManageTap: () => _showGuardianManageSheet(context),
    freeCount: memberState.guardianSlots.where((s) => !s.isPaid && s.status == 'accepted').length,
    paidCount: memberState.guardianSlots.where((s) => s.isPaid && s.status == 'accepted').length,
  ),
```

**Step 3: 앱 빌드 확인**

Run: `cd safetrip-mobile && flutter analyze lib/screens/main/bottom_sheets/bottom_sheet_2_member.dart 2>&1 | tail -5`
Expected: No issues found

**Step 4: 커밋**

```bash
git add safetrip-mobile/lib/screens/main/bottom_sheets/bottom_sheet_2_member.dart
git commit -m "feat(flutter): show free/paid guardian slot counts in member tab"
```

---

## Task 5: 통합 테스트 — 서버 기동 + API 응답 검증

**Step 1: 백엔드 서버 기동**

Run: `cd safetrip-server-api && npm run dev > /tmp/safetrip-backend.log 2>&1 &`
Wait 5 seconds, then: `curl -s http://localhost:3001/api/v1/health | head -5`
Expected: 서버 응답 확인

**Step 2: 멤버 목록 API 직접 테스트**

기존 테스트 상태(`/tmp/safetrip-test-state.json`)에서 trip_id를 추출하여 API 호출:

Run:
```bash
TRIP_ID=$(cat /tmp/safetrip-test-state.json 2>/dev/null | jq -r '.trip_id // empty')
if [ -n "$TRIP_ID" ]; then
  TOKEN=$(cat /tmp/safetrip-test-state.json | jq -r '.token // empty')
  curl -s -H "Authorization: Bearer $TOKEN" \
    "http://localhost:3001/api/v1/groups/$TRIP_ID/members" | jq '.data[0] | keys'
else
  echo "No test state found — manual verification needed"
fi
```

Expected: 응답에 `user_id`, `user_name`, `member_role`, `guardian_links` 등 키가 포함

**Step 3: 앱 hot restart 후 멤버탭 확인**

Flutter 앱을 hot restart하고 멤버탭에서:
- 자기 자신이 관리자 또는 멤버 섹션에 표시되는지 확인
- 역할 배지가 올바르게 표시되는지 확인
- 프로필 사진/이름이 표시되는지 확인

**Step 4: 최종 커밋**

모든 확인 후 변경사항이 남아있다면:
```bash
git add -A
git commit -m "test: verify member tab P0 compliance — API enrichment + Flutter data flow"
```
