# SafeTrip 9개 버그 수정 및 기능 개선 구현 계획

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 여행 앱의 9개 이슈(역할 표시, 초대코드, 날짜 오프셋, 여행 목록, 국가명/여행명 구분, 장소 검색, 멤버 추가, 배터리 색상) 수정

**Architecture:** 서버 버그 먼저 수정(trip_id 누락, 날짜 오프셋) → Flutter UI 버그 수정 → 기능 개선 순서로 진행

**Tech Stack:** Flutter (Dart), Node.js/TypeScript, PostgreSQL, OpenStreetMap Nominatim API

---

## 이슈 목록 요약

| 이슈 | 근본 원인 | 수정 위치 |
|------|-----------|-----------|
| #1 역할 표시 오류 | trip_id NULL → getUserTrips 실패 | 서버 |
| #2 초대코드 생성/공유 없음 | API 연결 검증 필요 | 서버+Flutter |
| #3 참여코드 버튼 없음 | trip_id 버그로 모달이 비어 보임 | 서버 수정 후 자동 해결 |
| #4 날짜 하루 차이 | toISOString() 타임존 오프셋 | 서버 |
| #5 여행정보 안 보임 | trip_id NULL → INNER JOIN 실패 | 서버 |
| #6 국가명/여행명 구분 | destinationName이 countryName으로 혼용 | Flutter |
| #7 주소 검색 고도화 | geocoding 패키지(단일 결과) | Flutter |
| #8 멤버 추가 기능 없음 | AddMemberModal API 연결 문제 | Flutter+서버 |
| #9 배터리 색상 단계 | 3단계만 구현됨 | Flutter |

---

## Task 1: trip_id 누락 버그 수정 (이슈 #1, #5 해결)

**핵심 버그:** `addGroupMember()`가 `trip_id`를 저장하지 않음 → `getUserTrips` INNER JOIN 실패

**Files:**
- Modify: `safetrip-server-api/src/services/groups.service.ts:200-308` (addGroupMember)
- Modify: `safetrip-server-api/src/controllers/trips.controller.ts:203-210` (createTrip)
- Modify: 초대코드로 멤버 추가하는 모든 서버 코드
- Create: `safetrip-server-api/scripts/local/migration-add-trip-id-to-members.sql`

**Step 1: groups.service.ts의 addGroupMember에 trip_id 추가**

```typescript
// options 인터페이스에 trip_id 추가
async addGroupMember(
  groupId: string,
  userId: string,
  options: {
    trip_id?: string;    // ← 추가
    member_role?: string;
    is_admin?: boolean;
    can_edit_schedule?: boolean;
    can_edit_geofence?: boolean;
    can_view_all_locations?: boolean;
  } = {}
)
```

INSERT 문 변경:
```sql
-- Before (line 289-291):
INSERT INTO tb_group_member
(group_id, user_id, member_role, is_admin, is_guardian, can_edit_schedule, can_edit_geofence, can_view_all_locations, status, joined_at)
VALUES ($1, $2, $3, $4, $5, $6, $7, $8, 'active', CURRENT_TIMESTAMP)

-- After:
INSERT INTO tb_group_member
(group_id, user_id, trip_id, member_role, is_admin, is_guardian, can_edit_schedule, can_edit_geofence, can_view_all_locations, status, joined_at)
VALUES ($1, $2, $9, $3, $4, $5, $6, $7, $8, 'active', CURRENT_TIMESTAMP)
-- $9 = options.trip_id || null
```

UPDATE 문도 동일하게 trip_id 추가 (재가입, 업데이트 케이스)

**Step 2: trips.controller.ts의 createTrip에서 trip_id 전달**

```typescript
// 4. 그룹 멤버로 추가 (리더 권한) — trip_id 추가
await groupService.addGroupMember(groupId, userId, {
  trip_id: tripId,      // ← 추가
  member_role: 'leader',
  is_admin: true,
  can_edit_schedule: true,
  can_edit_geofence: true,
  can_view_all_locations: true,
});
```

**Step 3: 초대코드 참여 시 trip_id 설정 확인**
`invite-code.service.ts` 등에서 초대코드로 그룹 참여할 때 `trip_id`도 함께 저장하는지 확인하고 수정

**Step 4: 마이그레이션 스크립트 작성**
```sql
-- migration-add-trip-id-to-members.sql
-- trip_id가 NULL인 tb_group_member 레코드에 대해
-- 해당 group_id의 가장 이른 trip을 찾아서 trip_id 설정
UPDATE tb_group_member gm
SET trip_id = (
  SELECT t.trip_id
  FROM tb_trip t
  WHERE t.group_id = gm.group_id
  ORDER BY t.created_at ASC
  LIMIT 1
)
WHERE gm.trip_id IS NULL
  AND EXISTS (
    SELECT 1 FROM tb_trip t2 WHERE t2.group_id = gm.group_id
  );

-- 결과 확인
SELECT COUNT(*) as null_count FROM tb_group_member WHERE trip_id IS NULL;
```

**Step 5: 마이그레이션 실행**
```bash
psql -h localhost -p 5433 -U postgres -d safetrip -f scripts/local/migration-add-trip-id-to-members.sql
```

**Step 6: 서버 재시작 및 API 테스트**
```bash
curl -H "Authorization: Bearer <token>" http://localhost:3001/api/v1/trips/users/<userId>/trips
# Expected: 여행 목록 반환 (빈 배열 아님)
```

**Step 7: 테스트**
- 새 여행 생성 → tb_group_member.trip_id 확인
- getUserTrips API → 여행 목록 반환 확인

**Step 8: Commit**
```bash
git add src/services/groups.service.ts src/controllers/trips.controller.ts scripts/
git commit -m "fix: set trip_id in tb_group_member on trip creation and join"
```

---

## Task 2: 날짜 하루 차이 버그 수정 (이슈 #4)

**Root cause:** `trip.start_date.toISOString().split('T')[0]`에서 서버 타임존이 UTC+9이면 날짜가 하루 당겨짐

**Files:**
- Modify: `safetrip-server-api/src/services/trip.service.ts` (getTripByGroupId)

**Step 1: getTripByGroupId SQL 쿼리 수정**

`trip.service.ts`의 `getTripByGroupId` 함수에서 SQL에 `::date::text` 캐스트 추가:
```sql
-- Before:
SELECT t.trip_id, ..., t.start_date, t.end_date, ...

-- After:
SELECT t.trip_id, ...,
  t.start_date::date::text AS start_date,
  t.end_date::date::text AS end_date, ...
```

**Step 2: trips.controller.ts의 toISOString() 제거**

`trips.controller.ts`의 `getTripByGroupId` 핸들러 (lines 120-124):
```typescript
// Before:
sendSuccess(res, {
  ...trip,
  start_date: trip.start_date.toISOString().split('T')[0],
  end_date: trip.end_date.toISOString().split('T')[0],
});

// After (SQL에서 이미 string으로 반환):
sendSuccess(res, trip);
```

`getTripsByUserId` 등 다른 곳에서 `toISOString()`을 사용하는 곳도 동일하게 수정

**Step 3: TypeScript 타입 업데이트**
`getTripByGroupId` 반환 타입에서 `start_date: Date`를 `start_date: string`으로 변경

**Step 4: 테스트**
```bash
curl http://localhost:3001/api/v1/trips/groups/<groupId>
# Expected: start_date가 입력한 날짜와 동일
```

**Step 5: Commit**
```bash
git commit -m "fix: use ::date::text cast to prevent timezone offset on date columns"
```

---

## Task 3: 국가명과 여행명 구분 (이슈 #6)

**Root cause:** `countryName: _destinationName` 전달 시 도시명과 국가명이 혼용됨

**Files:**
- Modify: `safetrip-mobile/lib/screens/main/screen_main.dart` (TripInfoCard 호출 부분)
- Modify: `safetrip-mobile/lib/widgets/trip_info_card.dart` (UI 명확화)

**Step 1: screen_main.dart에 _countryName 필드 추가**

`_currentUserRole` 필드 선언부 근처에 추가:
```dart
String? _countryName; // 순수 국가명 (예: '일본', '태국') — countryCode 기반
```

`_loadTripInfo()` setState 블록에서:
```dart
// 국가명은 countryCode 기반 로컬 매핑만 사용 (도시명 혼용 방지)
_countryName = resolvedCountryCode != null
    ? _countryCodeToName[resolvedCountryCode.toUpperCase()]
    : null;
// _destinationName은 기존대로 유지 (이미지 검색 등 기존 용도)
```

**Step 2: TripInfoCard 호출 시 countryName에 _countryName 전달**

`screen_main.dart` line 3780 (TripInfoCard 빌드):
```dart
// Before:
countryName: _destinationName,

// After:
countryName: _countryName,
```

**Step 3: TripInfoCard의 국가명 표시 개선**

`trip_info_card.dart`에서 국가명 Row(lines 610-631)를 더 명확하게 표시:
```dart
// 국가명을 '국가' 레이블과 함께 표시
if (widget.countryName != null) ...[
  Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (widget.countryCode != null) CountryFlag...,
      if (widget.countryCode != null) const SizedBox(width: 4),
      Text(
        widget.countryName!,  // 국가명만 표시
        style: // 기존 스타일 유지
      ),
    ],
  ),
  const SizedBox(height: 2),
],
```

**Step 4: TripSummary에 countryName 필드 추가 (선택적)**
`trip_list_accordion.dart`의 TripSummary 클래스에도 `countryName` nullable 필드 추가

**Step 5: 테스트**
- 한국→일본 여행 생성 후 카드 확인
- 국가명("일본")과 여행명(사용자 입력)이 별도 표시되는지 확인

**Step 6: Commit**
```bash
git commit -m "fix: display country name and trip name separately in TripInfoCard"
```

---

## Task 4: 초대코드 관리 UI 검증 및 수정 (이슈 #2)

**현황:** `InviteCodeManagementModal`에 생성/복사/공유 코드가 구현되어 있으나 API 연결 검증 필요

**Files:**
- Check: `safetrip-server-api/src/routes/` (invite code 라우트)
- Check: `safetrip-server-api/src/controllers/` (invite code 핸들러)
- Fix if needed: API 연결 문제

**Step 1: 서버 초대코드 라우트 확인**
```bash
grep -r "invite-codes" /mnt/d/Project/15_SafeTrip_New/safetrip-server-api/src/routes/
```
`GET/POST /api/v1/groups/:groupId/invite-codes` 라우트가 있는지 확인

**Step 2: 라우트 없으면 추가**
`groups.routes.ts` 또는 `invite-codes.routes.ts`에:
```typescript
router.get('/groups/:groupId/invite-codes', authenticate, inviteCodeController.listInviteCodes);
router.post('/groups/:groupId/invite-codes', authenticate, inviteCodeController.createInviteCode);
```

**Step 3: 초대코드 생성 API 테스트**
```bash
curl -X POST -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"target_role":"normal","max_uses":5,"expires_in_days":7}' \
  http://localhost:3001/api/v1/groups/<groupId>/invite-codes
# Expected: 초대코드 생성 성공
```

**Step 4: 초대코드 목록 API 테스트**
```bash
curl -H "Authorization: Bearer <token>" \
  http://localhost:3001/api/v1/groups/<groupId>/invite-codes
# Expected: 초대코드 목록 반환
```

**Step 5: Flutter UI에서 `InviteCodeManagementModal` 접근 경로 확인**
- Member tab → 멤버 추가 → AddMemberModal → 초대코드 탭 경로가 올바른지 확인
- 또는 직접 초대코드 관리 버튼이 있는지 확인

**Step 6: Commit**

---

## Task 5: 배터리 색상 단계별 표시 (이슈 #9)

**Files:**
- Modify: `safetrip-mobile/lib/screens/main/bottom_sheets/bottom_sheet_2_member.dart`

**Step 1: _getBatteryColor() 업데이트**

```dart
Color _getBatteryColor(int level, bool isCharging) {
  if (isCharging) return Colors.blue;
  if (level > 80) return const Color(0xFF2E7D32);  // 진한 녹색
  if (level > 60) return const Color(0xFF43A047);  // 녹색
  if (level > 40) return const Color(0xFF8BC34A);  // 연두색
  if (level > 20) return const Color(0xFFFFA000);  // 주황색
  if (level > 10) return const Color(0xFFE65100);  // 진한 주황
  return const Color(0xFFD32F2F);                   // 빨간색
}
```

**Step 2: _getBatteryIcon() 업데이트**

```dart
IconData _getBatteryIcon(int level, bool isCharging) {
  if (isCharging) return Icons.battery_charging_full;
  if (level > 80) return Icons.battery_full;
  if (level > 60) return Icons.battery_5_bar;      // 또는 battery_full
  if (level > 40) return Icons.battery_3_bar;
  if (level > 20) return Icons.battery_2_bar;
  if (level > 10) return Icons.battery_1_bar;
  return Icons.battery_0_bar;
}
```

**Step 3: Commit**
```bash
git commit -m "feat: add granular battery level color stages (6 levels)"
```

---

## Task 6: 장소 검색 고도화 및 지도 핀 역지오코딩 (이슈 #7)

**현황:** `geocoding` 패키지 사용, 단일 결과, 지도 탭 시 역지오코딩 없음

**Files:**
- Modify: `safetrip-mobile/lib/screens/main/bottom_sheets/modals/add_place_direct_modal.dart`

**Step 1: Nominatim 검색 메서드 추가**

```dart
// HTTP 클라이언트 추가 (http 패키지 또는 기존 dio 사용)
Future<List<Map<String, dynamic>>> _searchNominatim(String query) async {
  final url = Uri.parse(
    'https://nominatim.openstreetmap.org/search'
    '?q=${Uri.encodeComponent(query)}'
    '&format=json&limit=5&accept-language=ko'
    '&addressdetails=1'
  );
  // dio 또는 http로 GET 요청
  // 응답: [{display_name, lat, lon, address: {...}}, ...]
  // 반환: [{name, address, lat, lon}] 형태로 변환
}
```

**Step 2: 역지오코딩 메서드 추가**

```dart
Future<String?> _reverseGeocode(double lat, double lng) async {
  final url = Uri.parse(
    'https://nominatim.openstreetmap.org/reverse'
    '?lat=$lat&lon=$lng&format=json&accept-language=ko'
  );
  // 응답: {display_name: '...', address: {...}}
  // display_name 또는 address 조합 반환
}
```

**Step 3: 검색 결과 드롭다운을 다중 결과 표시로 교체**

기존 `locationFromAddress()` 호출을 `_searchNominatim()` 호출로 교체:
```dart
// Before: 단일 Location → 단일 결과
// After: Nominatim List → 다중 결과 드롭다운
setState(() => _searchResults = nominatimResults);
```

**Step 4: 지도 탭 시 역지오코딩으로 주소 필드 자동 채우기**

기존 `onTap` 콜백에 역지오코딩 추가:
```dart
onTap: (tapPosition, point) async {
  setState(() {
    _selectedLatLng = point;
    _isLoadingAddress = true;  // 로딩 인디케이터
  });
  final address = await _reverseGeocode(point.latitude, point.longitude);
  if (mounted) {
    setState(() {
      if (address != null) _addressController.text = address;
      _isLoadingAddress = false;
    });
  }
},
```

**Step 5: 검색 중 로딩 인디케이터 추가**

**Step 6: Commit**
```bash
git commit -m "feat: enhance place search with Nominatim multi-result and reverse geocoding"
```

---

## Task 7: 멤버 추가 기능 검증 및 수정 (이슈 #8)

**현황:** `AddMemberModal`이 코드로 구현되어 있으나 API 연결 필요

**Files:**
- Check: `safetrip-server-api/src/routes/` (searchUsers 라우트)
- Modify if needed: 관련 파일들

**Step 1: searchUsers API 확인**
```bash
grep -r "searchUsers\|search.*users\|users.*search" \
  /mnt/d/Project/15_SafeTrip_New/safetrip-server-api/src/routes/
```

**Step 2: 없으면 추가**
`users.routes.ts`에:
```typescript
router.get('/users/search', authenticate, userController.searchUsers);
```

컨트롤러:
```typescript
searchUsers: async (req, res) => {
  const { q } = req.query;
  // tb_user에서 이름/이메일/전화번호로 검색
  // 결과 반환
}
```

**Step 3: 멤버 역할별 초대 기능 확인**
- Leader/Full 권한 사용자만 멤버 추가 가능한지 UI에서 권한 체크
- `screen_main.dart`의 멤버 추가 버튼에 역할 체크 추가 (leader/full만 표시)

**Step 4: 테스트**

**Step 5: Commit**

---

## Task 8: 최종 검증 및 통합 테스트

**Step 1: 서버 재시작**
```bash
# 기존 서버 종료 후 재시작
pkill -f "ts-node|node.*index" || true
cd /mnt/d/Project/15_SafeTrip_New/safetrip-server-api
npm run dev &
```

**Step 2: API 통합 테스트**
```bash
# 1. Trip 생성 → trip_id 확인
# 2. getUserTrips → 목록 반환 확인
# 3. getTripByGroupId → 날짜 정확도 확인
# 4. createInviteCode → 생성 확인
```

**Step 3: Flutter 빌드 테스트**
```bash
cd /mnt/d/Project/15_SafeTrip_New/safetrip-mobile
flutter analyze
```

**Step 4: 최종 Commit**
```bash
git add -A
git commit -m "feat: fix 9 issues - role display, trip list, date offset, battery stages, place search"
```
