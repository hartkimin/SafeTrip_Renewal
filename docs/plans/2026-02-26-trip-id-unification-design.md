# Trip ID 통합 설계 (여행전환 역할칩 + trip_id 단위화)

**날짜:** 2026-02-26
**상태:** 승인됨

## 배경 및 문제

- 여행전환 모달(`TripSwitchModal`)에서 유저가 속한 모든 여행 목록이 표시되지 않음
- 서버에 `GET /groups/users/:userId/groups` 엔드포인트가 없어 `getUserGroups()` 호출이 실패 → 단일 그룹만 표시됨
- 카드에 유저의 역할 칩(리더/여행자 등)이 표시되지 않음
- `group_id`와 `trip_id`가 분리되어 있어 혼란 → `trip_id`를 단일 식별자로 통합

## 전제 조건

- 현재 1 group = 1 trip 구조가 대부분 (다국가 여행은 현재 고려 안 함)
- `tb_group_member.group_id`는 하위호환을 위해 유지 (deprecated)

---

## 설계

### 1. DB 스키마 마이그레이션

`tb_group_member`에 `trip_id` 컬럼을 추가하고 기존 데이터를 마이그레이션한다.

```sql
-- 1) trip_id 컬럼 추가
ALTER TABLE tb_group_member
  ADD COLUMN trip_id UUID REFERENCES tb_trip(trip_id) ON DELETE CASCADE;

-- 2) 기존 데이터 마이그레이션 (group_id → 첫 번째 trip의 trip_id)
UPDATE tb_group_member gm
SET trip_id = (
  SELECT t.trip_id
  FROM tb_trip t
  WHERE t.group_id = gm.group_id
  ORDER BY t.created_at ASC
  LIMIT 1
);

-- 3) 인덱스 추가
CREATE INDEX IF NOT EXISTS idx_group_member_trip_id
  ON tb_group_member(trip_id, user_id);
```

`group_id` 컬럼은 삭제하지 않고 deprecated 유지.

---

### 2. 새 통합 API

**엔드포인트:** `GET /api/v1/trips/users/:userId/trips`

단일 JOIN 쿼리로 유저의 모든 여행(trip) 정보를 반환한다.

#### 쿼리 전략
```sql
SELECT
  t.trip_id,
  t.group_id,
  g.group_name,
  gm.member_role,
  CASE WHEN gm.member_role IN ('leader', 'full') THEN TRUE ELSE FALSE END AS is_admin,
  t.country_code,
  t.country_name,
  t.destination_city,
  t.start_date,
  t.end_date,
  t.status AS trip_status,
  gm.joined_at,
  (
    SELECT COUNT(*)
    FROM tb_group_member gm2
    WHERE gm2.trip_id = t.trip_id AND gm2.status = 'active'
  ) AS member_count
FROM tb_group_member gm
INNER JOIN tb_trip t ON gm.trip_id = t.trip_id
INNER JOIN tb_group g ON t.group_id = g.group_id
WHERE gm.user_id = :userId
  AND gm.status = 'active'
  AND g.status = 'active'
ORDER BY gm.joined_at DESC
```

#### 응답 구조
```json
{
  "success": true,
  "data": [
    {
      "trip_id": "uuid",
      "group_id": "uuid",
      "group_name": "도쿄 여행팀",
      "member_role": "leader",
      "is_admin": true,
      "country_code": "JPN",
      "country_name": "일본",
      "destination_city": "도쿄",
      "start_date": "2025-03-01",
      "end_date": "2025-03-07",
      "trip_status": "upcoming",
      "member_count": 5,
      "joined_at": "2025-01-10T00:00:00Z"
    }
  ]
}
```

#### 신규 파일
- `safetrip-server-api/src/routes/trips.routes.ts` — `GET /users/:userId/trips` 라우트 추가
- `safetrip-server-api/src/controllers/trips.controller.ts` — `getUserTrips` 핸들러
- `safetrip-server-api/src/services/trip.service.ts` — `getUserTrips` 서비스 메서드 추가

기존 `/groups/:group_id/*` 엔드포인트는 그대로 유지. 서버 내부에서 `trip_id → group_id` 역참조 헬퍼 제공.

---

### 3. AppCache 변경

```dart
// 추가
static Future<void> setTripId(String tripId) async { ... }
static String? get tripIdSync { ... }

// 기존 setGroupId / groupIdSync 유지 (하위호환)
```

앱 초기화 및 여행 전환 시 `tripId`를 primary key로 저장.
기존 API 호출 시에는 `AppCache.groupIdSync`를 계속 사용 (서버가 group_id 기반이므로).

---

### 4. Flutter — API 클라이언트 변경

`api_service.dart`에 `getUserTrips()` 메서드 추가:

```dart
Future<List<Map<String, dynamic>>> getUserTrips(String userId) async {
  // GET /api/v1/trips/users/:userId/trips
  // 반환: trip_id, group_id, group_name, member_role, country_code,
  //        start_date, end_date, trip_status, member_count
}
```

기존 `getUserGroups()`는 `getUserTrips()`로 교체.
`_loadUserTripList()`에서 N+1 API 호출(getTripByGroupId, getGroupMembers) 제거 — 통합 API 단일 호출로 대체.

---

### 5. Flutter — TripSwitchModal 역할 칩

`_buildTripCard()`의 여행지 행 오른쪽에 역할 칩 추가:

| member_role | 라벨 | 아이콘 | 스타일 |
|---|---|---|---|
| `leader` | 리더 | ⭐ solidStar | primaryTeal 배경, 흰 텍스트 |
| `full` | 운영자 | 🛡 shield | teal10 배경, teal 텍스트 |
| `normal` | 여행자 | ✈ plane | bgBasic03 배경, text04 |
| `view_only` | 모니터링 | 👁 eye | softYellowWeak 배경, text08 |

---

## 구현 범위 요약

| # | 레이어 | 파일 | 내용 |
|---|---|---|---|
| 1 | DB | migration SQL | `tb_group_member`에 `trip_id` 추가 + 데이터 마이그레이션 |
| 2 | 서버 | `trip.service.ts` | `getUserTrips()` 메서드 추가 |
| 3 | 서버 | `trips.controller.ts` | `getUserTrips` 컨트롤러 추가 |
| 4 | 서버 | `trips.routes.ts` | `GET /users/:userId/trips` 라우트 추가 |
| 5 | 앱 | `app_cache.dart` | `tripId` getter/setter 추가 |
| 6 | 앱 | `api_service.dart` | `getUserTrips()` 추가, `getUserGroups()` 교체 |
| 7 | 앱 | `screen_main.dart` | `_loadUserTripList()` N+1 → 단일 API 호출로 교체 |
| 8 | 앱 | `trip_switch_modal.dart` | `_buildTripCard()`에 역할 칩 위젯 추가 |

## 변경하지 않는 것

- `tb_group`, `tb_trip`, `tb_group_member` 테이블 구조 (컬럼 추가만)
- 기존 `/groups/:group_id/*` 서버 API 전체
- `TripSummary` 모델 (`userRole` 필드 이미 존재)
- `AppCache.groupId` (하위호환 유지)
