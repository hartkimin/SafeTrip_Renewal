# Trip ID 통합 구현 계획 (여행전환 역할칩 + getUserTrips API)

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 여행전환 모달에서 유저가 속한 모든 여행을 역할 칩과 함께 표시한다.

**Architecture:** `tb_group_member`에 `trip_id` 컬럼을 추가하고 데이터를 마이그레이션한다. 새 통합 API `GET /api/v1/trips/users/:userId/trips`를 추가해 단일 쿼리로 모든 여행 정보를 반환한다. Flutter 앱에서 `AppCache.tripId`를 추가하고 `TripSwitchModal` 카드에 역할 칩을 표시한다.

**Tech Stack:** Node.js/TypeScript (Express + PostgreSQL), Flutter/Dart, SharedPreferences

**Design Doc:** `docs/plans/2026-02-26-trip-id-unification-design.md`

---

## Task 1: DB 마이그레이션 SQL 작성

**Files:**
- Create: `safetrip-server-api/scripts/local/migration-trip-id.sql`

**Step 1: 마이그레이션 파일 작성**

`safetrip-server-api/scripts/local/migration-trip-id.sql` 내용:

```sql
-- ============================================================================
-- Migration: tb_group_member에 trip_id 컬럼 추가
-- group_id 기반 멤버십 → trip_id 기반 멤버십 전환
-- ============================================================================

BEGIN;

-- 1) trip_id 컬럼 추가 (nullable — 마이그레이션 후 채움)
ALTER TABLE tb_group_member
  ADD COLUMN IF NOT EXISTS trip_id UUID REFERENCES tb_trip(trip_id) ON DELETE CASCADE;

-- 2) 기존 데이터 마이그레이션: group_id → 해당 그룹의 첫 번째 trip_id
UPDATE tb_group_member gm
SET trip_id = (
  SELECT t.trip_id
  FROM tb_trip t
  WHERE t.group_id = gm.group_id
  ORDER BY t.created_at ASC
  LIMIT 1
)
WHERE gm.trip_id IS NULL
  AND gm.group_id IS NOT NULL;

-- 3) 인덱스 추가 (유저별 trip 조회 최적화)
CREATE INDEX IF NOT EXISTS idx_group_member_trip_user
  ON tb_group_member(trip_id, user_id)
  WHERE status = 'active';

COMMIT;
```

**Step 2: 로컬 DB에 마이그레이션 적용**

```bash
cd /mnt/d/Project/15_SafeTrip_New
psql -h localhost -U safetrip -d safetrip -f safetrip-server-api/scripts/local/migration-trip-id.sql
```

또는 Docker를 사용 중이라면:
```bash
docker exec -i safetrip-postgres psql -U safetrip -d safetrip \
  < safetrip-server-api/scripts/local/migration-trip-id.sql
```

기대 결과: `UPDATE <N>` (기존 멤버 수만큼), `CREATE INDEX`

**Step 3: 마이그레이션 확인**

```bash
psql -h localhost -U safetrip -d safetrip -c \
  "SELECT member_id, group_id, trip_id, user_id, member_role
   FROM tb_group_member LIMIT 5;"
```

기대 결과: `trip_id` 컬럼에 UUID 값이 채워져 있음

**Step 4: 커밋**

```bash
cd /mnt/d/Project/15_SafeTrip_New
git add safetrip-server-api/scripts/local/migration-trip-id.sql
git commit -m "feat: add trip_id column migration to tb_group_member"
```

---

## Task 2: 서버 — `getUserTrips` 서비스 메서드 추가

**Files:**
- Modify: `safetrip-server-api/src/services/trip.service.ts` (파일 끝에 메서드 추가)

**Step 1: `getUserTrips` 메서드를 `tripService` 객체에 추가**

`safetrip-server-api/src/services/trip.service.ts` 파일의 마지막 `};` 직전에 아래를 추가한다:

```typescript
  /**
   * userId로 유저가 속한 모든 trip 목록 조회 (단일 JOIN 쿼리)
   * tb_group_member.trip_id 기반 — Task 1 마이그레이션 완료 후 사용 가능
   */
  async getUserTrips(userId: string): Promise<Array<{
    trip_id: string;
    group_id: string;
    group_name: string;
    member_role: string;
    is_admin: boolean;
    country_code: string | null;
    country_name: string | null;
    destination_city: string | null;
    start_date: string | null;
    end_date: string | null;
    trip_status: string;
    member_count: number;
    joined_at: Date;
  }>> {
    const db = getDatabase();
    try {
      const result = await db.query(
        `SELECT
          t.trip_id,
          t.group_id,
          g.group_name,
          gm.member_role,
          CASE WHEN gm.member_role IN ('leader', 'full') THEN TRUE ELSE FALSE END AS is_admin,
          t.country_code,
          t.country_name,
          t.destination_city,
          t.start_date::date::text AS start_date,
          t.end_date::date::text   AS end_date,
          t.status                 AS trip_status,
          (
            SELECT COUNT(*)::int
            FROM tb_group_member gm2
            WHERE gm2.trip_id = t.trip_id
              AND gm2.status = 'active'
          ) AS member_count,
          gm.joined_at
        FROM tb_group_member gm
        INNER JOIN tb_trip  t ON gm.trip_id  = t.trip_id
        INNER JOIN tb_group g ON t.group_id  = g.group_id
        WHERE gm.user_id = $1
          AND gm.status  = 'active'
          AND g.status   = 'active'
        ORDER BY gm.joined_at DESC`,
        [userId]
      );

      return result.rows.map(row => ({
        trip_id:          row.trip_id,
        group_id:         row.group_id,
        group_name:       row.group_name,
        member_role:      row.member_role,
        is_admin:         row.is_admin,
        country_code:     row.country_code,
        country_name:     row.country_name,
        destination_city: row.destination_city,
        start_date:       row.start_date,
        end_date:         row.end_date,
        trip_status:      row.trip_status,
        member_count:     row.member_count,
        joined_at:        row.joined_at,
      }));
    } catch (error) {
      logger.error('Error fetching user trips:', error);
      throw error;
    }
  },
```

**Step 2: 서버 컴파일 확인**

```bash
cd /mnt/d/Project/15_SafeTrip_New/safetrip-server-api
npx tsc --noEmit
```

기대 결과: 에러 없음

**Step 3: 커밋**

```bash
git add safetrip-server-api/src/services/trip.service.ts
git commit -m "feat: add getUserTrips service method (single JOIN query)"
```

---

## Task 3: 서버 — `getUserTrips` 컨트롤러 + 라우트 추가

**Files:**
- Modify: `safetrip-server-api/src/controllers/trips.controller.ts` (객체 끝에 추가)
- Modify: `safetrip-server-api/src/routes/trips.routes.ts` (라우트 추가)

**Step 1: `trips.controller.ts`에 `getUserTrips` 핸들러 추가**

`tripsController` 객체의 마지막 `};` 직전에 추가:

```typescript
  /**
   * GET /api/v1/trips/users/:userId/trips
   * 유저가 속한 모든 trip 목록 + 역할 정보 반환
   */
  getUserTrips: async (req: Request, res: Response) => {
    try {
      const userId = req.params.userId;

      if (!userId) {
        sendError(res, 'userId is required', 400);
        return;
      }

      const trips = await tripService.getUserTrips(userId);
      sendSuccess(res, trips);
    } catch (error: any) {
      logger.error('Failed to get user trips', {
        error: error.message,
        userId: req.params.userId,
      });
      sendError(res, error.message || 'Failed to get user trips', 500);
    }
  },
```

**Step 2: `trips.routes.ts`에 라우트 추가**

`router.get('/users/:user_id/countries', ...)` 바로 아래에 추가:

```typescript
// GET /api/v1/trips/users/:userId/trips
// 유저가 속한 모든 trip 목록 조회 (역할 포함)
router.get('/users/:userId/trips', tripsController.getUserTrips);
```

**Step 3: 서버 재시작 후 curl 테스트**

서버를 재시작하고 실제 userId로 테스트:

```bash
# 서버 실행 중인지 확인
curl -s http://localhost:3001/health | jq .

# 실제 userId로 테스트 (emulator seed data의 첫 번째 유저 사용)
USER_ID="<실제_user_id>"
curl -s "http://localhost:3001/api/v1/trips/users/${USER_ID}/trips" | jq .
```

기대 결과:
```json
{
  "success": true,
  "data": [
    {
      "trip_id": "...",
      "group_id": "...",
      "group_name": "...",
      "member_role": "leader",
      ...
    }
  ]
}
```

**Step 4: 컴파일 확인 + 커밋**

```bash
cd /mnt/d/Project/15_SafeTrip_New/safetrip-server-api
npx tsc --noEmit

git add safetrip-server-api/src/controllers/trips.controller.ts \
        safetrip-server-api/src/routes/trips.routes.ts
git commit -m "feat: add GET /trips/users/:userId/trips endpoint"
```

---

## Task 4: Flutter — AppCache에 `tripId` 추가

**Files:**
- Modify: `safetrip-mobile/lib/utils/app_cache.dart`

**Step 1: `_tripId` 필드 추가**

`static String? _groupId;` 바로 아래에 추가:

```dart
static String? _tripId;
```

**Step 2: `initialize()`에서 `trip_id` 로드 추가**

`_groupId = prefs.getString('group_id');` 바로 아래에 추가:

```dart
_tripId = prefs.getString('trip_id');
```

**Step 3: async getter 추가**

`groupId` getter 바로 아래에 추가:

```dart
/// 트립 ID
static Future<String?> get tripId async {
  if (_tripId != null) return _tripId;
  final prefs = await SharedPreferences.getInstance();
  _tripId = prefs.getString('trip_id');
  return _tripId;
}
```

**Step 4: sync getter 추가**

`static String? get groupIdSync => _groupId;` 바로 아래에 추가:

```dart
/// 트립 ID (메모리에서만 읽기)
static String? get tripIdSync => _tripId;
```

**Step 5: `setTripId()` setter 추가**

`setGroupId()` 메서드 바로 아래에 추가:

```dart
/// 트립 ID 업데이트
static Future<void> setTripId(String tripId) async {
  try {
    _tripId = tripId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('trip_id', tripId);
    debugPrint('[AppCache] 트립 ID 업데이트: $tripId');
  } catch (e) {
    debugPrint('[AppCache] 트립 ID 업데이트 실패: $e');
  }
}
```

**Step 6: `clear()`에서 `_tripId` 초기화 추가**

`_groupId = null;` 바로 아래에 추가:

```dart
_tripId = null;
```

그리고 SharedPreferences clear 블록(있다면)에도 `trip_id` 제거 추가.

**Step 7: 컴파일 확인**

```bash
cd /mnt/d/Project/15_SafeTrip_New/safetrip-mobile
flutter analyze lib/utils/app_cache.dart
```

기대 결과: No issues found

**Step 8: 커밋**

```bash
git add safetrip-mobile/lib/utils/app_cache.dart
git commit -m "feat: add tripId to AppCache"
```

---

## Task 5: Flutter — `getUserTrips` API 메서드 추가

**Files:**
- Modify: `safetrip-mobile/lib/services/api_service.dart`

**Step 1: `getUserTrips()` 메서드 추가**

`getUserGroups()` 메서드 바로 아래에 추가:

```dart
/// 유저가 속한 모든 trip 목록 조회 (역할 포함).
/// 단일 API 호출로 group_name, member_role, 날짜, 국가 등 모든 정보를 반환한다.
Future<List<Map<String, dynamic>>> getUserTrips(String userId) async {
  try {
    final response = await _dio.get(
      '/api/v1/trips/users/$userId/trips',
    );
    debugPrint('[API] getUserTrips ${jsonEncode(response.data)}');
    if (response.data['success'] == true && response.data['data'] != null) {
      final data = response.data['data'];
      if (data is List) {
        return List<Map<String, dynamic>>.from(data);
      }
    }
    return [];
  } catch (e) {
    debugPrint('[API] getUserTrips 실패: $e');
    return [];
  }
}
```

**Step 2: 컴파일 확인**

```bash
cd /mnt/d/Project/15_SafeTrip_New/safetrip-mobile
flutter analyze lib/services/api_service.dart
```

**Step 3: 커밋**

```bash
git add safetrip-mobile/lib/services/api_service.dart
git commit -m "feat: add getUserTrips API method"
```

---

## Task 6: Flutter — `screen_main.dart`의 `_loadUserTripList()` 리팩터링

**Files:**
- Modify: `safetrip-mobile/lib/screens/main/screen_main.dart`

**현재 문제:** `_loadUserTripList()`가 `getUserGroups()` → 각 그룹별 `getTripByGroupId()` + `getGroupMembers()` N+1 호출 구조.

**Step 1: `_loadUserTripList()` 본문 교체**

기존 `Future<void> _loadUserTripList() async { ... }` 전체를 아래로 교체:

```dart
/// 유저의 모든 여행 그룹을 단일 API 호출로 로드해 _tripList에 반영.
Future<void> _loadUserTripList() async {
  try {
    final userId = AppCache.userIdSync;
    if (userId == null) return;

    final apiService = ApiService();
    final trips = await apiService.getUserTrips(userId);

    if (!mounted || trips.isEmpty) {
      _buildSingleTripEntry();
      return;
    }

    final List<TripSummary> tripSummaries = trips.map((trip) {
      final countryCode = trip['country_code'] as String?;
      final destinationName = countryCode != null
          ? _countryCodeToName[countryCode.toUpperCase()]
          : null;

      DateTime? startDate;
      DateTime? endDate;
      if (trip['start_date'] != null) {
        startDate = DateTime.tryParse(trip['start_date'] as String);
      }
      if (trip['end_date'] != null) {
        endDate = DateTime.tryParse(trip['end_date'] as String);
      }

      return TripSummary(
        groupId: trip['group_id'] as String? ?? '',
        tripId: trip['trip_id'] as String? ?? '',
        tripName: trip['group_name'] as String? ?? '여행',
        userRole: trip['member_role'] as String? ?? 'normal',
        countryCode: countryCode,
        startDate: startDate,
        endDate: endDate,
        destinationName: destinationName,
        memberCount: trip['member_count'] as int? ?? 0,
        guardianCount: 0,
        userName: AppCache.userNameSync ?? '',
        userId: userId,
      );
    }).toList();

    if (mounted) {
      setState(() {
        _tripList = tripSummaries;
      });
    }
  } catch (e) {
    debugPrint('[MainScreen] 여행 목록 로드 실패: $e');
    _buildSingleTripEntry();
  }
}
```

**Step 2: `_switchTrip()`에서 `AppCache.tripId` 업데이트 추가**

`_switchTrip(String groupId)` 메서드를 찾아 기존 `AppCache.setGroupId(groupId)` 호출 뒤에 다음을 추가:

```dart
// 선택된 groupId에 해당하는 tripId 저장
final selectedTrip = _tripList.firstWhere(
  (t) => t.groupId == groupId,
  orElse: () => _tripList.first,
);
if (selectedTrip.tripId != null && selectedTrip.tripId!.isNotEmpty) {
  await AppCache.setTripId(selectedTrip.tripId!);
}
```

**Step 3: 컴파일 확인**

```bash
cd /mnt/d/Project/15_SafeTrip_New/safetrip-mobile
flutter analyze lib/screens/main/screen_main.dart
```

에러가 있으면 `TripSummary`에 `tripId` 필드가 없어서 발생할 수 있음 → Task 7에서 추가함.

**Step 4: 커밋 (Task 7 이후에 함께)**

---

## Task 7: Flutter — `TripSummary` 모델에 `tripId` 필드 추가

**Files:**
- Modify: `safetrip-mobile/lib/widgets/trip_list_accordion.dart`

**Step 1: `TripSummary` 클래스에 `tripId` 필드 추가**

```dart
class TripSummary {
  final String groupId;
  final String? tripId;          // ← 추가
  final String tripName;
  final String userRole;
  // ... 나머지 기존 필드들 유지
```

**Step 2: 생성자에 `tripId` 추가**

```dart
const TripSummary({
  required this.groupId,
  this.tripId,                   // ← 추가
  required this.tripName,
  // ... 나머지 기존 파라미터들 유지
```

**Step 3: 컴파일 확인**

```bash
flutter analyze lib/widgets/trip_list_accordion.dart
```

**Step 4: Tasks 6+7 함께 커밋**

```bash
git add safetrip-mobile/lib/widgets/trip_list_accordion.dart \
        safetrip-mobile/lib/screens/main/screen_main.dart
git commit -m "feat: add tripId to TripSummary, refactor _loadUserTripList to single API call"
```

---

## Task 8: Flutter — `TripSwitchModal` 역할 칩 추가

**Files:**
- Modify: `safetrip-mobile/lib/widgets/trip_switch_modal.dart`

**Step 1: `_buildRoleChip()` 위젯 메서드 추가**

`_TripSwitchModalState` 클래스 안에 추가:

```dart
Widget _buildRoleChip(String memberRole) {
  final String label;
  final IconData icon;
  final Color bgColor;
  final Color textColor;
  final Color iconColor;

  switch (memberRole) {
    case 'leader':
      label = '리더';
      icon = FontAwesomeIcons.solidStar;
      bgColor = AppTokens.primaryTeal;
      textColor = Colors.white;
      iconColor = const Color(0xFFFFC60A);
      break;
    case 'full':
      label = '운영자';
      icon = FontAwesomeIcons.shield;
      bgColor = AppTokens.bgTeal02;
      textColor = AppTokens.primaryTeal;
      iconColor = AppTokens.primaryTeal;
      break;
    case 'view_only':
      label = '모니터링';
      icon = FontAwesomeIcons.eye;
      bgColor = AppTokens.softYellowWeak;
      textColor = AppTokens.text08;
      iconColor = AppTokens.text08;
      break;
    case 'normal':
    default:
      label = '여행자';
      icon = FontAwesomeIcons.planeDeparture;
      bgColor = AppTokens.bgBasic03;
      textColor = AppTokens.text04;
      iconColor = AppTokens.text04;
      break;
  }

  return Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppTokens.spacing6,
      vertical: AppTokens.spacing2,
    ),
    decoration: BoxDecoration(
      color: bgColor,
      borderRadius: BorderRadius.circular(AppTokens.radius6),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FaIcon(icon, size: 10, color: iconColor),
        const SizedBox(width: 3),
        Text(
          label,
          style: AppTokens.textStyle(
            fontSize: AppTokens.fontSize11,
            fontWeight: AppTokens.fontWeightMedium,
            color: textColor,
          ),
        ),
      ],
    ),
  );
}
```

**Step 2: `_buildTripInfo()`에서 역할 칩 삽입**

`_buildTripInfo()` 메서드 내 국기+여행지 Row의 `Flexible` 위젯 뒤에 칩을 추가:

```dart
// 국기 + 여행지 + 역할 칩
Row(
  children: [
    if (trip.countryCode != null && trip.countryCode!.isNotEmpty) ...[
      ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: SizedBox(
          width: 16,
          height: 11,
          child: CountryFlag.fromCountryCode(trip.countryCode!),
        ),
      ),
      const SizedBox(width: AppTokens.spacing4),
    ],
    if (trip.destinationName != null)
      Flexible(
        child: Text(
          trip.destinationName!,
          style: AppTokens.textStyle(
            fontSize: AppTokens.fontSize12,
            color: AppTokens.text04,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    const SizedBox(width: AppTokens.spacing6),   // ← 추가
    _buildRoleChip(trip.userRole),                // ← 추가
  ],
),
```

**Step 3: 앱 실행하여 UI 확인**

에뮬레이터 또는 기기에서 앱을 실행 후:
1. 메인 화면 상단 여행정보 카드 → 여행전환 버튼 탭
2. 여행 목록 카드에 역할 칩이 표시되는지 확인
3. 여러 여행에 속해 있으면 목록이 모두 표시되는지 확인

**Step 4: 커밋**

```bash
git add safetrip-mobile/lib/widgets/trip_switch_modal.dart
git commit -m "feat: add role chip to TripSwitchModal card"
```

---

## Task 9: 여행 전환 시 `AppCache.tripId` 저장 확인

**Files:**
- Modify: `safetrip-mobile/lib/screens/main/screen_main.dart`

**Step 1: `_switchTrip()` 메서드 확인**

Task 6에서 추가한 `AppCache.setTripId()` 호출이 제대로 동작하는지 로그로 확인:

```dart
debugPrint('[MainScreen] 여행 전환: groupId=$groupId, tripId=${selectedTrip.tripId}');
```

**Step 2: 앱 실행 → 여행전환 → 로그 확인**

```
flutter run
```

여행전환 모달에서 다른 여행 선택 후 `flutter logs` 또는 디버그 콘솔에서:
```
[MainScreen] 여행 전환: groupId=<uuid>, tripId=<uuid>
[AppCache] 트립 ID 업데이트: <uuid>
```

**Step 3: 커밋 (변경사항이 있을 경우)**

```bash
git add safetrip-mobile/lib/screens/main/screen_main.dart
git commit -m "fix: persist tripId to AppCache on trip switch"
```

---

## Task 10: 전체 통합 테스트 + 회귀 확인

**Step 1: 서버 테스트**

```bash
# 1. 새 엔드포인트
curl -s "http://localhost:3001/api/v1/trips/users/${USER_ID}/trips" | jq '.data | length'
# 기대: 유저가 속한 trip 개수

# 2. 기존 엔드포인트 정상 작동 확인
curl -s "http://localhost:3001/api/v1/groups/${GROUP_ID}/members" | jq '.success'
# 기대: true

curl -s "http://localhost:3001/api/v1/trips/groups/${GROUP_ID}" | jq '.success'
# 기대: true
```

**Step 2: Flutter 체크리스트**

- [ ] 여행전환 버튼 탭 → 전체화면 모달 오픈
- [ ] 유저가 속한 모든 여행이 카드로 표시됨
- [ ] 각 카드에 역할 칩 표시 (리더/운영자/여행자/모니터링)
- [ ] 카드 탭 → 선택됨 (체크 아이콘)
- [ ] '여행 선택하기' 버튼 → 메인 화면 전환 및 여행 정보 반영
- [ ] AppCache.tripId에 선택된 trip_id 저장 확인

**Step 3: 최종 커밋**

```bash
git add docs/plans/
git commit -m "docs: add trip-id unification plan and design docs"
```

---

## 구현 순서 요약

```
Task 1 (DB 마이그레이션)
  └─ Task 2 (서버 서비스)
      └─ Task 3 (서버 컨트롤러+라우트)
          ├─ Task 4 (AppCache tripId)
          ├─ Task 5 (API 클라이언트)
          └─ Task 7 (TripSummary 모델)
              └─ Task 6 (screen_main 리팩터링)
                  └─ Task 8 (역할 칩 UI)
                      └─ Task 9 (전환 시 tripId 저장)
                          └─ Task 10 (통합 테스트)
```
