# SafeTrip Backend API 명세서 — Part 2 (§6~§10)

| 항목 | 내용 |
|------|------|
| **문서 ID** | `DOC-T2-API-037` |
| **상위 인덱스** | [35_T2_API_명세서.md](./35_T2_API_명세서.md) |
| **범위** | §6 그룹 / §7 초대코드 / §8 가디언 / §9 위치 / §10 지오펜스 |
| **버전** | v1.0 |
| **작성일** | 2026-03-02 |

> Part 1: [36_T2_API_명세서_Part1.md](./36_T2_API_명세서_Part1.md) | Part 3: [38_T2_API_명세서_Part3.md](./38_T2_API_명세서_Part3.md)

---

## §6. 그룹 (Groups)

**Base URL**: `/api/v1/groups`

그룹(`tb_group`)은 여행(`tb_trip`)과 1:1로 연결되며, 멤버십(`tb_group_member`)을 통해 역할 기반 권한이 관리된다. 역할 계층: `captain` > `crew_chief` > `crew` > `guardian`.

> **라우트 마운트 순서**: `inviteCodesRoutes` → `POST /join/:invite_code` → 개별 경로(`/users/:userId/...`) → 와일드카드(`/:group_id`) 순으로 등록된다. 따라서 `join-by-code`, `preview-by-code` 등의 특수 경로가 `/:group_id`보다 먼저 매칭된다.

---

### §6.A 그룹 조회

---

#### [GET] /api/v1/groups/:group_id

**인증**: 불필요 (단, 토큰이 있으면 멤버 여부에 따라 `status != 'active'` 그룹 접근 여부가 달라짐)
**설명**: `group_id`(UUID)로 그룹 상세 정보를 조회한다. 비활성 그룹은 멤버가 아닌 경우 403 반환.

**Path Parameters**

| 파라미터 | 타입 | 설명 |
|---------|------|------|
| `group_id` | string (UUID) | 조회할 그룹 UUID |

**Response 200**
```json
{
  "success": true,
  "data": {
    "group_id": "string (UUID)",
    "group_name": "string",
    "group_description": "string | null",
    "group_type": "string",
    "status": "string",
    "invite_code": "string",
    "invite_link": "string | null",
    "owner_user_id": "string",
    "max_members": "number",
    "current_member_count": "number"
  }
}
```

| 필드 | 타입 | 설명 |
|------|------|------|
| `group_id` | string | 그룹 UUID |
| `group_name` | string | 그룹 이름 |
| `group_description` | string \| null | 그룹 설명 |
| `group_type` | string | 그룹 유형 |
| `status` | string | 그룹 상태 (`active` 등) |
| `invite_code` | string | 레거시 여행자 초대 코드 (`tb_group.invite_code`) |
| `invite_link` | string \| null | 초대 딥링크. 없으면 `null` |
| `owner_user_id` | string | 그룹 소유자(captain)의 Firebase UID |
| `max_members` | number | 최대 멤버 수 |
| `current_member_count` | number | 현재 활성 멤버 수 |

**Error Codes**

| Code | 설명 |
|------|------|
| 400 | `group_id` 누락 |
| 403 | 비활성 그룹에 비멤버 접근: `"Group not accessible"` |
| 404 | 그룹 없음: `"Group not found"` |
| 500 | 서버 내부 오류 |

---

#### [GET] /api/v1/groups/:group_id/my-permission

**인증**: 선택 (토큰 또는 `?user_id=` 쿼리 파라미터로 사용자 식별)
**설명**: 현재 사용자의 해당 그룹 내 역할 및 권한 정보를 반환한다.

**Path Parameters**

| 파라미터 | 타입 | 설명 |
|---------|------|------|
| `group_id` | string (UUID) | 그룹 UUID |

**Query Parameters**

| 파라미터 | 타입 | 필수 | 설명 |
|---------|------|:----:|------|
| `user_id` | string | 조건부 | 인증 토큰이 없는 경우 필수. Firebase UID |

**Response 200**
```json
{
  "success": true,
  "data": {
    "user_id": "string",
    "member_role": "string",
    "can_view_all_locations": "boolean",
    "is_admin": "boolean",
    "can_edit_schedule": "boolean",
    "can_edit_geofence": "boolean"
  }
}
```

| 필드 | 타입 | 설명 |
|------|------|------|
| `user_id` | string | 조회된 사용자의 Firebase UID |
| `member_role` | string | 역할 (`captain`, `crew_chief`, `crew`, `guardian`) |
| `can_view_all_locations` | boolean | 전체 위치 조회 권한 |
| `is_admin` | boolean | 관리자 여부 (`captain` 또는 `crew_chief`이면 `true`) |
| `can_edit_schedule` | boolean | 일정 편집 권한 |
| `can_edit_geofence` | boolean | 지오펜스 편집 권한 |

**Error Codes**

| Code | 설명 |
|------|------|
| 400 | `group_id` 또는 `user_id` 누락 |
| 500 | 서버 내부 오류 |

---

#### [GET] /api/v1/groups/users/:userId/recent-groups

**인증**: 불필요
**설명**: 사용자가 가장 최근에 참여한 그룹 1개를 반환한다. 관리자·여행자·보호자 역할을 모두 포함하여 조회한다. 참여 그룹이 없으면 `group: null` 반환.

**Path Parameters**

| 파라미터 | 타입 | 설명 |
|---------|------|------|
| `userId` | string | 조회할 사용자의 Firebase UID |

**Response 200**
```json
{
  "success": true,
  "data": {
    "group": {
      "group_id": "string (UUID)",
      "group_name": "string",
      "trip_id": "string (UUID)",
      "member_role": "string",
      "is_admin": "boolean"
    }
  }
}
```

> 참여 그룹이 없는 경우:
> ```json
> {
>   "success": true,
>   "data": {
>     "group": null
>   }
> }
> ```

| 필드 | 타입 | 설명 |
|------|------|------|
| `group_id` | string | 그룹 UUID |
| `group_name` | string | 그룹 이름 |
| `trip_id` | string | 해당 그룹에 연결된 여행 UUID |
| `member_role` | string | 해당 그룹에서의 역할 |
| `is_admin` | boolean | 관리자 여부 |

**Error Codes**

| Code | 설명 |
|------|------|
| 400 | `userId` 누락 |
| 500 | 서버 내부 오류 |

---

### §6.B 그룹 멤버 관리

---

#### [GET] /api/v1/groups/:group_id/members

**인증**: 선택 (토큰 또는 `?user_id=` 쿼리 파라미터로 사용자 식별)
**설명**: 그룹의 전체 멤버 목록을 반환한다. 비활성 그룹은 멤버가 아닌 경우 403.

**Path Parameters**

| 파라미터 | 타입 | 설명 |
|---------|------|------|
| `group_id` | string (UUID) | 그룹 UUID |

**Query Parameters**

| 파라미터 | 타입 | 필수 | 설명 |
|---------|------|:----:|------|
| `user_id` | string | 조건부 | 인증 토큰이 없는 경우. 비활성 그룹 접근 권한 검증에 사용 |

**Response 200**
```json
{
  "success": true,
  "data": {
    "members": [
      {
        "member_id": "string (UUID)",
        "user_id": "string",
        "group_id": "string (UUID)",
        "member_role": "string",
        "is_admin": "boolean",
        "can_edit_schedule": "boolean",
        "can_edit_geofence": "boolean",
        "can_view_all_locations": "boolean",
        "location_sharing_enabled": "boolean",
        "joined_at": "string (ISO 8601)"
      }
    ]
  }
}
```

**Error Codes**

| Code | 설명 |
|------|------|
| 400 | `group_id` 누락 |
| 403 | 비활성 그룹에 비멤버 접근: `"Group not accessible"` |
| 404 | 그룹 없음 |
| 500 | 서버 내부 오류 |

---

#### [POST] /api/v1/groups/:group_id/members

**인증**: 선택적 (`captain` 또는 `crew_chief` 역할 내부 검증. 라우트에 `authenticate` 미들웨어 없음. 컨트롤러 내부에서 `(req as any).userId || req.body.user_id`로 userId 추출 후 권한 검증)
**설명**: 전화번호로 사용자를 그룹에 초대한다. 대상 사용자가 `tb_user`에 존재해야 한다. 성공 시 `tb_group_member`에 추가되고 초대 링크를 반환한다.

**Path Parameters**

| 파라미터 | 타입 | 설명 |
|---------|------|------|
| `group_id` | string (UUID) | 그룹 UUID |

**Request Body**
```json
{
  "phone_number": "string",
  "role": "string",
  "is_admin": "boolean",
  "can_edit_schedule": "boolean",
  "can_edit_geofence": "boolean",
  "can_view_all_locations": "boolean"
}
```

| 필드 | 타입 | 필수 | 기본값 | 설명 |
|------|------|:----:|:------:|------|
| `phone_number` | string | ✅ | — | 초대할 사용자의 전화번호 (E.164 형식) |
| `role` | string | ✗ | — | 역할 직접 지정 (`crew_chief`, `crew`, `guardian`). 지정 시 `is_admin`보다 우선 적용 |
| `is_admin` | boolean | ✗ | `false` | `true`이면 `crew_chief`, `false`이면 `crew`로 설정. `role`이 없을 때 사용 |
| `can_edit_schedule` | boolean | ✗ | `false` | 일정 편집 권한 |
| `can_edit_geofence` | boolean | ✗ | `false` | 지오펜스 편집 권한 |
| `can_view_all_locations` | boolean | ✗ | `true` | 전체 위치 조회 권한 |

> **`captain` 역할은 직접 할당 불가**. 리더십 양도는 `POST /:groupId/transfer-leadership` 사용.

**Response 201**
```json
{
  "success": true,
  "data": {
    "member": {
      "member_id": "string (UUID)",
      "group_id": "string (UUID)",
      "user_id": "string",
      "member_role": "string",
      "is_admin": "boolean",
      "can_edit_schedule": "boolean",
      "can_edit_geofence": "boolean",
      "can_view_all_locations": "boolean",
      "joined_at": "string (ISO 8601)"
    },
    "invite_link": "string"
  },
  "message": "Member invited successfully"
}
```

| 필드 | 타입 | 설명 |
|------|------|------|
| `invite_link` | string | 딥링크. `tb_group.invite_link` 있으면 그 값, 없으면 `safetrip://group/join?code={invite_code}` |

**Error Codes**

| Code | 설명 |
|------|------|
| 400 | `phone_number` 누락 |
| 400 | 최대 멤버 수 초과: `"Group has reached maximum member limit"` |
| 403 | `captain` 또는 `crew_chief` 역할 아님: `"Permission denied: admin role required"` |
| 404 | 그룹 없음 |
| 404 | 전화번호로 사용자를 찾을 수 없음: `"User not found with the provided phone number"` |
| 500 | 서버 내부 오류 |

---

#### [PATCH] /api/v1/groups/:group_id/members/:user_id

**인증**: 선택적 (`captain` 또는 `crew_chief` 역할 내부 검증. 라우트에 `authenticate` 미들웨어 없음. 컨트롤러 내부에서 `(req as any).userId || req.body.user_id`로 userId 추출 후 권한 검증)
**설명**: 특정 멤버의 역할 또는 권한을 변경한다. `captain` 역할은 직접 할당 불가(transfer-leadership 사용). 그룹 소유자의 `is_admin`을 `false`로 변경하는 것도 불가.

**Path Parameters**

| 파라미터 | 타입 | 설명 |
|---------|------|------|
| `group_id` | string (UUID) | 그룹 UUID |
| `user_id` | string | 권한 변경 대상 사용자의 Firebase UID |

**Request Body** (최소 하나 이상의 필드 필수)
```json
{
  "member_role": "string",
  "is_admin": "boolean",
  "can_edit_schedule": "boolean",
  "can_edit_geofence": "boolean",
  "can_view_all_locations": "boolean",
  "location_sharing_enabled": "boolean"
}
```

| 필드 | 타입 | 필수 | 설명 |
|------|------|:----:|------|
| `member_role` | string | 조건부 | 새 역할 (`crew_chief`, `crew`, `guardian`). `captain` 불가 |
| `is_admin` | boolean | 조건부 | 관리자 여부 |
| `can_edit_schedule` | boolean | 조건부 | 일정 편집 권한 |
| `can_edit_geofence` | boolean | 조건부 | 지오펜스 편집 권한 |
| `can_view_all_locations` | boolean | 조건부 | 전체 위치 조회 권한 |
| `location_sharing_enabled` | boolean | 조건부 | 위치 공유 활성화 여부 |

**Response 200**
```json
{
  "success": true,
  "data": {
    "member_id": "string (UUID)",
    "group_id": "string (UUID)",
    "user_id": "string",
    "member_role": "string",
    "is_admin": "boolean",
    "can_edit_schedule": "boolean",
    "can_edit_geofence": "boolean",
    "can_view_all_locations": "boolean",
    "location_sharing_enabled": "boolean"
  }
}
```

**Error Codes**

| Code | 설명 |
|------|------|
| 400 | `group_id` 또는 `user_id` 누락 |
| 400 | 변경할 권한 필드가 하나도 없음: `"At least one permission field is required"` |
| 400 | `member_role = 'captain'` 시도: `"Cannot directly assign captain role. Use transfer-leadership API instead."` |
| 400 | 그룹 소유자의 `is_admin`을 `false`로 변경 시도: `"Group owner cannot remove their own admin status"` |
| 403 | `captain` 또는 `crew_chief` 역할 아님: `"Permission denied: admin role required"` |
| 500 | 서버 내부 오류 |

---

#### [DELETE] /api/v1/groups/:group_id/members/:user_id

**인증**: 선택적 (`captain` 또는 `crew_chief` 역할 내부 검증. 라우트에 `authenticate` 미들웨어 없음. 컨트롤러 내부에서 `(req as any).userId || req.body.user_id`로 userId 추출 후 권한 검증)
**설명**: 그룹에서 특정 멤버를 제거한다. 그룹 소유자(`owner_user_id`)는 제거 불가.

**Path Parameters**

| 파라미터 | 타입 | 설명 |
|---------|------|------|
| `group_id` | string (UUID) | 그룹 UUID |
| `user_id` | string | 제거 대상 사용자의 Firebase UID |

**Request Body**: 없음

**Response 200**
```json
{
  "success": true,
  "data": {
    "message": "Member removed successfully"
  }
}
```

**Error Codes**

| Code | 설명 |
|------|------|
| 400 | `group_id` 또는 `user_id` 누락 |
| 400 | 그룹 소유자 제거 시도: `"Cannot remove group owner"` |
| 403 | `captain` 또는 `crew_chief` 역할 아님: `"Permission denied: admin role required"` |
| 500 | 서버 내부 오류 |

---

### §6.C 레거시 초대 코드 참여

---

#### [POST] /api/v1/groups/join/:invite_code

**인증**: 선택 (토큰 또는 Request Body의 `user_id`로 사용자 식별)
**설명**: 레거시 또는 신규 초대 코드로 그룹에 참여한다. `tb_invite_code`에서 먼저 검색하고 없으면 `tb_group.invite_code`(레거시)로 fallback한다.

> **신규 vs 레거시**: `tb_invite_code`에서 찾은 경우 `invite_code_type: 'role_based'`, `tb_group.invite_code`에서 찾은 경우 `invite_code_type: 'legacy'`가 반환된다.

**Path Parameters**

| 파라미터 | 타입 | 설명 |
|---------|------|------|
| `invite_code` | string | 참여할 초대 코드 |

**Request Body**

| 필드 | 타입 | 필수 | 설명 |
|------|------|:----:|------|
| `user_id` | string | ✗ | 인증 토큰이 없을 때 사용자 식별에 사용. 토큰 인증 시 불필요 |

**Response 200**
```json
{
  "success": true,
  "data": {
    "group": {
      "group_id": "string (UUID)",
      "group_name": "string",
      "group_description": "string | null",
      "group_type": "string"
    },
    "member": {
      "member_id": "string (UUID)",
      "group_id": "string (UUID)",
      "user_id": "string",
      "member_role": "string",
      "is_admin": "boolean",
      "can_edit_schedule": "boolean",
      "can_edit_geofence": "boolean",
      "can_view_all_locations": "boolean",
      "joined_at": "string (ISO 8601)"
    },
    "invite_code_type": "string"
  }
}
```

| 필드 | 타입 | 설명 |
|------|------|------|
| `invite_code_type` | string | `'role_based'` (신규 `tb_invite_code` 사용) 또는 `'legacy'` (`tb_group.invite_code` fallback) |

**Error Codes**

| Code | 설명 |
|------|------|
| 400 | `invite_code` 누락 |
| 400 | 최대 멤버 수 초과: `"Group has reached maximum member limit"` |
| 404 | 유효하지 않은 초대 코드: `"Invalid invite code or group not found"` |
| 500 | 서버 내부 오류 |

---

### §6.D 일정 (Schedules)

---

#### [GET] /api/v1/groups/:group_id/schedules

**인증**: 불필요
**설명**: 그룹의 일정 목록을 조회한다. `start_time`, `end_time`, `schedule_type`으로 필터링 가능.

**Path Parameters**

| 파라미터 | 타입 | 설명 |
|---------|------|------|
| `group_id` | string (UUID) | 그룹 UUID |

**Query Parameters**

| 파라미터 | 타입 | 필수 | 설명 |
|---------|------|:----:|------|
| `start_time` | string (ISO 8601) | ✗ | 조회 시작 시간 (이 시간 이후의 일정만 반환) |
| `end_time` | string (ISO 8601) | ✗ | 조회 종료 시간 (이 시간 이전의 일정만 반환) |
| `schedule_type` | string | ✗ | 일정 유형 필터 |

**Response 200**
```json
{
  "success": true,
  "data": {
    "schedules": [
      {
        "schedule_id": "string (UUID)",
        "group_id": "string (UUID)",
        "title": "string",
        "description": "string | null",
        "schedule_type": "string",
        "start_time": "string (ISO 8601)",
        "end_time": "string (ISO 8601) | null",
        "location_name": "string | null",
        "location_address": "string | null",
        "location_coords": "object | null",
        "reminder_enabled": "boolean",
        "reminder_time": "string | null",
        "geofence_enabled": "boolean",
        "geofence_id": "string (UUID) | null",
        "timezone": "string | null"
      }
    ]
  }
}
```

**Error Codes**

| Code | 설명 |
|------|------|
| 400 | `group_id` 누락 또는 유효하지 않은 파라미터 |
| 403 | 그룹 멤버 아님 (권한 필요 시) |
| 500 | 서버 내부 오류 |

---

#### [POST] /api/v1/groups/:group_id/schedules

**인증**: 선택적 (라우트에 `authenticate` 미들웨어 없음. 컨트롤러 내부에서 `(req as any).userId || req.body.user_id`로 userId 추출 후 권한 검증)
**설명**: 그룹에 새 일정을 생성한다. `geofence_enabled = true`이면 지오펜스도 함께 생성된다.

**Path Parameters**

| 파라미터 | 타입 | 설명 |
|---------|------|------|
| `group_id` | string (UUID) | 그룹 UUID |

**Request Body**
```json
{
  "title": "string",
  "description": "string",
  "schedule_type": "string",
  "start_time": "string",
  "end_time": "string",
  "location_name": "string",
  "location_address": "string",
  "location_coords": "object",
  "reminder_enabled": "boolean",
  "reminder_time": "string",
  "geofence_enabled": "boolean",
  "geofence_trigger_on_enter": "boolean",
  "geofence_trigger_on_exit": "boolean",
  "geofence_radius_meters": "number",
  "timezone": "string"
}
```

| 필드 | 타입 | 필수 | 설명 |
|------|------|:----:|------|
| `title` | string | ✅ | 일정 제목 |
| `schedule_type` | string | ✅ | 일정 유형 |
| `start_time` | string (ISO 8601) | ✅ | 시작 시각 |
| `description` | string | ✗ | 일정 설명 |
| `end_time` | string (ISO 8601) | ✗ | 종료 시각 |
| `location_name` | string | ✗ | 장소 이름 |
| `location_address` | string | ✗ | 장소 주소 |
| `location_coords` | object | ✗ | 좌표 객체 (`{ lat, lng }`) |
| `reminder_enabled` | boolean | ✗ | 알림 활성화 여부 |
| `reminder_time` | string | ✗ | 알림 시각 |
| `geofence_enabled` | boolean | ✗ | 지오펜스 활성화 여부. `true`이면 지오펜스 자동 생성 |
| `geofence_trigger_on_enter` | boolean | ✗ | 진입 시 트리거 여부 |
| `geofence_trigger_on_exit` | boolean | ✗ | 이탈 시 트리거 여부 |
| `geofence_radius_meters` | number | ✗ | 지오펜스 반경(m). `geofence_enabled = true` 시 사용 |
| `timezone` | string | ✗ | IANA 타임존 (예: `"Asia/Seoul"`) |

**Response 201**
```json
{
  "success": true,
  "data": {
    "schedule_id": "string (UUID)",
    "geofence_id": "string (UUID) | null"
  },
  "message": "Schedule created successfully"
}
```

| 필드 | 타입 | 설명 |
|------|------|------|
| `schedule_id` | string | 생성된 일정 UUID |
| `geofence_id` | string \| null | 연동 생성된 지오펜스 UUID. `geofence_enabled = false`이면 `null` |

**Error Codes**

| Code | 설명 |
|------|------|
| 400 | `title`, `schedule_type`, `start_time` 중 하나 이상 누락 |
| 400 | 유효하지 않은 필드 값 |
| 401 | 인증 토큰 없음 또는 만료 |
| 403 | 그룹 멤버 아님 또는 일정 생성 권한 없음 |
| 500 | 서버 내부 오류 |

---

#### [PATCH] /api/v1/groups/:group_id/schedules/:schedule_id

**인증**: 선택적 (라우트에 `authenticate` 미들웨어 없음. 컨트롤러 내부에서 `(req as any).userId || req.body.user_id`로 userId 추출 후 권한 검증)
**설명**: 기존 일정을 수정한다. `can_edit_schedule` 권한이 있는 멤버만 가능.

**Path Parameters**

| 파라미터 | 타입 | 설명 |
|---------|------|------|
| `group_id` | string (UUID) | 그룹 UUID |
| `schedule_id` | string (UUID) | 수정할 일정 UUID |

**Request Body**: `POST /schedules`와 동일한 필드 구조. 변경할 필드만 전달.

**Response 200**
```json
{
  "success": true,
  "data": {
    "schedule_id": "string (UUID)",
    "geofence_id": "string (UUID) | null"
  },
  "message": "Schedule updated successfully"
}
```

**Error Codes**

| Code | 설명 |
|------|------|
| 400 | `schedule_id` 또는 `group_id` 또는 `user_id` 누락 |
| 400 | 유효하지 않은 필드 값 |
| 401 | 인증 토큰 없음 또는 만료 |
| 403 | 권한 없음 |
| 404 | 일정 없음 |
| 500 | 서버 내부 오류 |

---

#### [DELETE] /api/v1/groups/:group_id/schedules/:schedule_id

**인증**: 선택적 (라우트에 `authenticate` 미들웨어 없음. 컨트롤러 내부에서 `(req as any).userId || req.body.user_id`로 userId 추출 후 권한 검증)
**설명**: 특정 일정을 삭제한다. `can_edit_schedule` 권한이 있는 멤버만 가능. 연동된 지오펜스도 함께 삭제될 수 있다.

**Path Parameters**

| 파라미터 | 타입 | 설명 |
|---------|------|------|
| `group_id` | string (UUID) | 그룹 UUID |
| `schedule_id` | string (UUID) | 삭제할 일정 UUID |

**Request Body**: 없음

**Response 200**
```json
{
  "success": true,
  "data": {
    "schedule_id": "string (UUID)"
  },
  "message": "Schedule deleted successfully"
}
```

**Error Codes**

| Code | 설명 |
|------|------|
| 400 | `schedule_id` 또는 `group_id` 또는 `user_id` 누락 |
| 401 | 인증 토큰 없음 또는 만료 |
| 403 | 권한 없음 |
| 404 | 일정 없음 |
| 500 | 서버 내부 오류 |

---

### §6.E 지오펜스 생성

---

#### [POST] /api/v1/groups/:group_id/geofences

**인증**: 선택적 (그룹 멤버이면 생성 가능. 수정·삭제는 `can_edit_geofence` 권한 필요. 라우트에 `authenticate` 미들웨어 없음. 컨트롤러 내부에서 `(req as any).userId || req.body.user_id`로 userId 추출 후 권한 검증)
**설명**: 그룹에 새 지오펜스를 생성한다. PostgreSQL에 저장 후 Firebase RTDB에 동기화된다.

**Path Parameters**

| 파라미터 | 타입 | 설명 |
|---------|------|------|
| `group_id` | string (UUID) | 그룹 UUID |

**Request Body**
```json
{
  "name": "string",
  "description": "string",
  "type": "string",
  "shape_type": "string",
  "center_latitude": "number",
  "center_longitude": "number",
  "radius_meters": "number",
  "polygon_coordinates": "array",
  "is_always_active": "boolean",
  "valid_from": "string",
  "valid_until": "string",
  "trigger_on_enter": "boolean",
  "trigger_on_exit": "boolean",
  "notify_group": "boolean",
  "notify_guardians": "boolean"
}
```

| 필드 | 타입 | 필수 | 기본값 | 설명 |
|------|------|:----:|:------:|------|
| `name` | string | ✅ | — | 지오펜스 이름 |
| `type` | string | ✅ | — | 지오펜스 유형 |
| `shape_type` | string | ✅ | — | 형태: `'circle'` 또는 `'polygon'` |
| `description` | string | ✗ | — | 설명 |
| `center_latitude` | number | 조건부 | — | 중심 위도. `shape_type = 'circle'` 시 필수 |
| `center_longitude` | number | 조건부 | — | 중심 경도. `shape_type = 'circle'` 시 필수 |
| `radius_meters` | number | 조건부 | — | 반경(m). `shape_type = 'circle'` 시 필수 |
| `polygon_coordinates` | array | 조건부 | — | 다각형 좌표 배열. `shape_type = 'polygon'` 시 필수 |
| `is_always_active` | boolean | ✗ | `true` | 항상 활성 여부 |
| `valid_from` | string (ISO 8601) | ✗ | `null` | 유효 시작 시각 |
| `valid_until` | string (ISO 8601) | ✗ | `null` | 유효 종료 시각 |
| `trigger_on_enter` | boolean | ✗ | `true` | 진입 시 트리거 |
| `trigger_on_exit` | boolean | ✗ | `true` | 이탈 시 트리거 |
| `notify_group` | boolean | ✗ | `false` | 그룹 알림 여부 |
| `notify_guardians` | boolean | ✗ | `false` | 보호자 알림 여부 |

**Response 201**
```json
{
  "success": true,
  "data": {
    "geofence_id": "string (UUID)"
  },
  "message": "Geofence created successfully"
}
```

**Error Codes**

| Code | 설명 |
|------|------|
| 400 | `name`, `type`, `shape_type` 중 하나 이상 누락 |
| 400 | `circle` 형태에서 `center_latitude`, `center_longitude`, `radius_meters` 누락 |
| 400 | `polygon` 형태에서 `polygon_coordinates` 누락 |
| 401 | 인증 토큰 없음 또는 만료 |
| 403 | 그룹 멤버 아님: `"Permission denied: not a member of this group"` |
| 500 | 서버 내부 오류 |

---

### §6.F 출석체크

---

#### [POST] /api/v1/groups/:group_id/attendance/start

**인증**: 필요 (`captain` 또는 `crew_chief` 역할)
**설명**: 그룹 전체 멤버에게 출석체크를 요청한다. Firebase RTDB를 통해 실시간으로 멤버들에게 알림이 전달된다.

**Path Parameters**

| 파라미터 | 타입 | 설명 |
|---------|------|------|
| `group_id` | string (UUID) | 그룹 UUID |

**Query Parameters**

| 파라미터 | 타입 | 필수 | 설명 |
|---------|------|:----:|------|
| `user_id` | string | 조건부 | 인증 토큰이 없는 경우 필수. 관리자 Firebase UID |

**Request Body**
```json
{
  "message": "string"
}
```

| 필드 | 타입 | 필수 | 기본값 | 설명 |
|------|------|:----:|:------:|------|
| `message` | string | ✗ | `"출석체크를 확인해주세요"` | 출석체크 안내 메시지 |

**Response 200**
```json
{
  "success": true,
  "data": {
    "message": "Attendance check started"
  }
}
```

**Error Codes**

| Code | 설명 |
|------|------|
| 400 | `group_id` 또는 `user_id` 누락 |
| 403 | `captain` 또는 `crew_chief` 역할 아님: `"Permission denied: admin role required"` |
| 500 | 서버 내부 오류 |

---

## §7. 초대코드 (Invite Codes)

**Base URL**: `/api/v1/groups`

본 섹션의 엔드포인트는 `tb_invite_code` 테이블 기반의 **역할별 초대코드(role-based invite code)** 체계를 다룬다. 이는 §6.C의 레거시 `tb_group.invite_code`와 별개이며, 역할(`target_role`)과 사용 횟수(`max_uses`) 제한 기능을 제공한다.

> **레거시 vs 신규**: `§6.C POST /join/:invite_code`는 두 체계를 모두 지원하는 통합 엔드포인트이다. 본 섹션의 `POST /join-by-code/:code`는 `tb_invite_code` 전용이며, 이미 멤버인 경우 used_count 증가 없이 기존 멤버 정보를 반환하는 멱등성 처리가 추가되어 있다.

> **인증**: `GET /preview-by-code/:code`는 인증 불필요. 나머지 엔드포인트는 Firebase 인증 필요.

---

#### [GET] /api/v1/groups/preview-by-code/:code

**인증**: 불필요
**설명**: 초대코드로 참여 전 여행 정보를 미리 조회한다. `used_count`는 증가하지 않는다. 만료되었거나 사용 횟수를 초과한 코드는 404 반환.

**Path Parameters**

| 파라미터 | 타입 | 설명 |
|---------|------|------|
| `code` | string | `tb_invite_code.code` (대소문자 무시) |

**Response 200**
```json
{
  "success": true,
  "data": {
    "target_role": "string",
    "uses_remaining": "number",
    "trip": {
      "trip_id": "string (UUID)",
      "group_id": "string (UUID)",
      "country_code": "string",
      "country_name": "string",
      "country_name_ko": "string",
      "destination_city": "string | null",
      "start_date": "string (YYYY-MM-DD)",
      "end_date": "string (YYYY-MM-DD)",
      "trip_type": "string",
      "status": "string",
      "title": "string"
    }
  }
}
```

| 필드 | 타입 | 설명 |
|------|------|------|
| `target_role` | string | 이 코드로 가입 시 부여되는 역할 (`crew_chief`, `crew`, `guardian`) |
| `uses_remaining` | number | 남은 사용 가능 횟수 (`max_uses - used_count`) |
| `trip` | object \| null | 그룹에 연결된 첫 번째 여행 정보. 연결된 여행이 없으면 `null` |
| `trip.title` | string | 그룹명 (`tb_group.group_name`) |
| `trip.country_name_ko` | string | 국가명 (현재 `country_name`과 동일 값) |

**Error Codes**

| Code | 설명 |
|------|------|
| 400 | `code` 누락 |
| 404 | 유효하지 않거나 만료되었거나 사용 횟수 초과: `"Invalid, expired, or used-up invite code"` |
| 500 | 서버 내부 오류 |

---

#### [POST] /api/v1/groups/join-by-code/:code

**인증**: 필요
**설명**: `tb_invite_code` 기반 초대코드로 그룹에 가입한다. 이미 활성 멤버인 경우 `used_count`를 증가시키지 않고 기존 멤버 정보를 반환한다 (`already_member: true`).

**Path Parameters**

| 파라미터 | 타입 | 설명 |
|---------|------|------|
| `code` | string | `tb_invite_code.code` (대소문자 무시) |

**Response 200**
```json
{
  "success": true,
  "data": {
    "group": {
      "group_id": "string (UUID)",
      "group_name": "string"
    },
    "member": {
      "member_id": "string (UUID)",
      "member_role": "string",
      "is_admin": "boolean"
    },
    "target_role": "string"
  }
}
```

> 이미 멤버인 경우 (`already_member: true`):
> ```json
> {
>   "success": true,
>   "data": {
>     "group": { "group_id": "string", "group_name": "string" },
>     "member": { "member_role": "string", "is_admin": "boolean" },
>     "target_role": "string",
>     "already_member": true
>   }
> }
> ```

| 필드 | 타입 | 설명 |
|------|------|------|
| `target_role` | string | 코드에 설정된 역할. 신규 가입 시 이 역할로 멤버 추가 |
| `already_member` | boolean | 기존 활성 멤버인 경우에만 `true`로 포함 |

**Error Codes**

| Code | 설명 |
|------|------|
| 400 | `code` 또는 `user_id` 누락 |
| 400 | 최대 멤버 수 초과: `"Group has reached maximum member limit"` |
| 401 | 인증 토큰 없음 또는 만료 |
| 404 | 유효하지 않거나 만료되었거나 사용 횟수 초과: `"Invalid, expired, or used-up invite code"` |
| 404 | 그룹 없음: `"Group not found"` |
| 500 | 서버 내부 오류 |

---

#### [POST] /api/v1/groups/:groupId/invite-codes

**인증**: 필요 (`captain` 또는 `crew_chief` 역할)
**설명**: 그룹의 역할별 초대코드를 새로 생성한다. 코드는 `tb_invite_code`에 저장된다.

**Path Parameters**

| 파라미터 | 타입 | 설명 |
|---------|------|------|
| `group_id` | string (UUID) | 그룹 UUID |

**Request Body**
```json
{
  "target_role": "string",
  "max_uses": "number",
  "expires_in_days": "number"
}
```

| 필드 | 타입 | 필수 | 설명 |
|------|------|:----:|------|
| `target_role` | string | ✅ | 이 코드로 가입 시 부여할 역할. `crew_chief`, `crew`, `guardian` 중 하나 |
| `max_uses` | number | ✗ | 최대 사용 횟수. 미지정 시 서비스 기본값 적용 |
| `expires_in_days` | number | ✗ | 만료까지의 일수. 미지정 시 서비스 기본값 적용 |

**Response 201**
```json
{
  "success": true,
  "data": {
    "invite_code_id": "string (UUID)",
    "group_id": "string (UUID)",
    "code": "string",
    "target_role": "string",
    "max_uses": "number",
    "used_count": "number",
    "expires_at": "string (ISO 8601) | null",
    "is_active": "boolean",
    "created_at": "string (ISO 8601)"
  },
  "message": "Invite code created"
}
```

| 필드 | 타입 | 설명 |
|------|------|------|
| `invite_code_id` | string | 생성된 초대코드 UUID (`tb_invite_code.invite_code_id`) |
| `code` | string | 실제 초대코드 문자열 |
| `target_role` | string | 부여될 역할 |
| `max_uses` | number | 최대 사용 횟수 |
| `used_count` | number | 현재 사용 횟수 (초기값 `0`) |
| `expires_at` | string \| null | 만료 시각. `expires_in_days` 미지정 시 `null` 가능 |
| `is_active` | boolean | 활성 여부 (초기값 `true`) |

**Error Codes**

| Code | 설명 |
|------|------|
| 400 | `groupId` 누락 |
| 400 | `target_role`이 `crew_chief`, `crew`, `guardian` 이외의 값: `"target_role must be one of: crew_chief, crew, guardian"` |
| 401 | 인증 토큰 없음 또는 만료 |
| 403 | `captain` 또는 `crew_chief` 역할 아님: `"Permission denied: admin role required"` |
| 500 | 서버 내부 오류 |

---

#### [GET] /api/v1/groups/:groupId/invite-codes

**인증**: 필요 (`captain` 또는 `crew_chief` 역할)
**설명**: 그룹에 발급된 전체 초대코드 목록을 반환한다. 비활성(`is_active = false`) 코드도 포함된다.

**Path Parameters**

| 파라미터 | 타입 | 설명 |
|---------|------|------|
| `group_id` | string (UUID) | 그룹 UUID |

**Response 200**
```json
{
  "success": true,
  "data": {
    "invite_codes": [
      {
        "invite_code_id": "string (UUID)",
        "group_id": "string (UUID)",
        "code": "string",
        "target_role": "string",
        "max_uses": "number",
        "used_count": "number",
        "expires_at": "string (ISO 8601) | null",
        "is_active": "boolean",
        "created_at": "string (ISO 8601)"
      }
    ]
  }
}
```

**Error Codes**

| Code | 설명 |
|------|------|
| 400 | `groupId` 누락 |
| 401 | 인증 토큰 없음 또는 만료 |
| 403 | `captain` 또는 `crew_chief` 역할 아님: `"Permission denied: admin role required"` |
| 500 | 서버 내부 오류 |

---

#### [DELETE] /api/v1/groups/:groupId/invite-codes/:codeId

**인증**: 필요 (`captain` 또는 `crew_chief` 역할)
**설명**: 특정 초대코드를 비활성화한다. 물리 삭제가 아닌 `is_active = false` 처리.

**Path Parameters**

| 파라미터 | 타입 | 설명 |
|---------|------|------|
| `group_id` | string (UUID) | 그룹 UUID |
| `codeId` | string (UUID) | 비활성화할 `tb_invite_code.invite_code_id` |

**Request Body**: 없음

**Response 200**
```json
{
  "success": true,
  "data": {
    "invite_code_id": "string (UUID)",
    "is_active": false
  },
  "message": "Invite code deactivated"
}
```

**Error Codes**

| Code | 설명 |
|------|------|
| 400 | `groupId` 또는 `codeId` 누락 |
| 401 | 인증 토큰 없음 또는 만료 |
| 403 | `captain` 또는 `crew_chief` 역할 아님: `"Permission denied: admin role required"` |
| 500 | 서버 내부 오류 |

---

## §8 가디언 시스템

> **가디언(Guardian)**: 여행 멤버의 안전을 모니터링하는 외부 보호자. 여행 그룹에 소속되지 않고 `tb_guardian_link`를 통해 특정 멤버와 1:1로 연결되며, 별도 채널(Firebase RTDB)로 멤버 및 캡틴과 소통한다.

### 8.1 개요

가디언 시스템은 **세 개의 활성 API 그룹**과 **하나의 레거시 그룹(deprecated)**으로 구성된다.

| 그룹 | Base URL | 설명 |
|------|----------|------|
| A. 가디언 링크 관리 | `/api/v1/trips/:tripId/guardians` | 링크 생성·수락·거절·해제·목록 조회 |
| B. 가디언 메시지 | `/api/v1/trips/:tripId/guardian-messages` | 멤버↔가디언, 가디언→캡틴 메시지 송수신 |
| C. 가디언 뷰 | `/api/v1/trips/:tripId/guardian-view` | 가디언이 볼 수 있는 멤버 프로필·일정·장소 |
| D. 레거시 가디언 | `/api/v1/guardians` | Phase 4 제거 예정 레거시 엔드포인트 |

**가디언 링크 상태(`tb_guardian_link.status`)**

| 값 | 설명 |
|----|------|
| `pending` | 초대 요청됨, 가디언 미응답 |
| `accepted` | 가디언이 수락함, 활성 연결 상태 |
| `rejected` | 가디언이 거절함 |

**가디언 제한 정책 (`validateGuardianLimit` 미들웨어)**
- 멤버당 여행별 최대 **3명** (pending + accepted 합산)
- 초과 시 400 에러 반환

**비즈니스 원칙 (v5.1 §09)**
- 멤버당 가디언 2명까지 무료
- 3~5번째 가디언: 1,900원/여행

**RTDB 채널 경로**

| 채널 종류 | channelId 형식 | RTDB 경로 |
|-----------|---------------|-----------|
| 멤버↔가디언 | `link_{linkId}` | `guardian_messages/{tripId}/{linkId}/messages` |
| 가디언→캡틴 | `captain_{guardianId}` | `guardian_captain_messages/{tripId}/{guardianId}/messages` |

---

### 8.A 가디언 링크 관리

**Base URL**: `/api/v1/trips/:tripId/guardians`
**인증**: 모든 엔드포인트에 Firebase 인증 필요

---

#### [POST] /api/v1/trips/:tripId/guardians

**인증**: 필요
**설명**: 멤버가 전화번호로 가디언을 초대한다. `validateGuardianLimit` 미들웨어가 사전 검증하여 pending+accepted 합산 3명을 초과하면 요청이 차단된다. 초대 대상 전화번호가 `tb_user`에 등록되어 있어야 한다.

**Path Parameters**

| 파라미터 | 타입 | 설명 |
|---------|------|------|
| `tripId` | string (UUID) | 여행 ID |

**Request Body**
```json
{
  "guardian_phone": "string"
}
```

| 필드 | 타입 | 필수 | 설명 |
|------|------|:----:|------|
| `guardian_phone` | string | ✅ | 초대할 가디언의 전화번호 (E.164 형식, 예: `+821012345678`) |

**Response 201**
```json
{
  "success": true,
  "data": {
    "link_id": "string (UUID)",
    "guardian_id": "string (UUID)",
    "status": "pending"
  },
  "message": "가디언 요청이 전송되었습니다"
}
```

| 필드 | 타입 | 설명 |
|------|------|------|
| `link_id` | string | 생성된 `tb_guardian_link.link_id` |
| `guardian_id` | string | 초대된 가디언의 `user_id` |
| `status` | string | 초기 상태: `"pending"` |

**Error Codes**

| Code | 설명 |
|------|------|
| 400 | `guardian_phone` 누락: `"guardian_phone is required"` |
| 400 | 멤버당 가디언 3명 초과: `"최대 3명까지 가디언 추가 가능합니다"` |
| 400 | 본인을 가디언으로 추가 시도: `"본인을 가디언으로 추가할 수 없습니다"` |
| 401 | 인증 토큰 없음 또는 만료 |
| 404 | 해당 전화번호로 가입된 사용자 없음: `"해당 전화번호로 가입된 사용자를 찾을 수 없습니다"` |
| 409 | 이미 동일한 가디언에게 요청한 상태: `"이미 요청한 가디언입니다"` |
| 500 | 서버 내부 오류 |

---

#### [PATCH] /api/v1/trips/:tripId/guardians/:linkId/respond

**인증**: 필요
**설명**: 가디언이 초대 요청을 수락하거나 거절한다. `status = 'pending'`인 링크에만 적용되며, 이미 처리된 링크는 404를 반환한다. 수락 시 `accepted_at` 타임스탬프가 기록된다.

**Path Parameters**

| 파라미터 | 타입 | 설명 |
|---------|------|------|
| `tripId` | string (UUID) | 여행 ID |
| `linkId` | string (UUID) | 대상 `tb_guardian_link.link_id` |

**Request Body**
```json
{
  "action": "accepted"
}
```

| 필드 | 타입 | 필수 | 설명 |
|------|------|:----:|------|
| `action` | string | ✅ | `"accepted"` 또는 `"rejected"` |

**Response 200**
```json
{
  "success": true,
  "data": {
    "link_id": "string (UUID)",
    "status": "accepted"
  },
  "message": "가디언 요청을 수락했습니다"
}
```

| 필드 | 타입 | 설명 |
|------|------|------|
| `link_id` | string | 처리된 링크 ID |
| `status` | string | 처리 결과 상태: `"accepted"` 또는 `"rejected"` |

> `action = "rejected"` 시 응답 메시지: `"가디언 요청을 거절했습니다"`

**Error Codes**

| Code | 설명 |
|------|------|
| 400 | `action` 누락 또는 `accepted`/`rejected` 이외 값: `"action must be 'accepted' or 'rejected'"` |
| 401 | 인증 토큰 없음 또는 만료 |
| 404 | 링크 없음, 이미 처리됨, 또는 요청자가 가디언이 아님: `"처리할 수 없는 요청입니다 (존재하지 않거나 이미 처리됨)"` |
| 500 | 서버 내부 오류 |

---

#### [DELETE] /api/v1/trips/:tripId/guardians/:linkId

**인증**: 필요
**설명**: 가디언 링크를 영구 삭제한다. **멤버 본인** 또는 **가디언 본인** 모두 삭제할 수 있다 (두 조건을 OR로 검증). 링크 상태에 관계없이 삭제 가능.

**Path Parameters**

| 파라미터 | 타입 | 설명 |
|---------|------|------|
| `tripId` | string (UUID) | 여행 ID |
| `linkId` | string (UUID) | 삭제할 `tb_guardian_link.link_id` |

**Request Body**: 없음

**Response 200**
```json
{
  "success": true,
  "data": null,
  "message": "가디언 연결이 해제되었습니다"
}
```

**Error Codes**

| Code | 설명 |
|------|------|
| 401 | 인증 토큰 없음 또는 만료 |
| 404 | 링크 없음 또는 요청자가 member/guardian 모두 아님: `"해당 가디언 연결을 찾을 수 없거나 권한이 없습니다"` |
| 500 | 서버 내부 오류 |

---

#### [GET] /api/v1/trips/:tripId/guardians/me

**인증**: 필요
**설명**: 멤버 본인이 해당 여행에 등록한 가디언 목록을 조회한다. `pending`, `accepted`, `rejected` 모든 상태를 포함하며, 생성 시각 내림차순 정렬된다.

**Path Parameters**

| 파라미터 | 타입 | 설명 |
|---------|------|------|
| `tripId` | string (UUID) | 여행 ID |

**Response 200**
```json
{
  "success": true,
  "data": [
    {
      "link_id": "string (UUID)",
      "guardian_id": "string (UUID)",
      "status": "string",
      "created_at": "string (ISO 8601)",
      "accepted_at": "string (ISO 8601) | null",
      "display_name": "string",
      "phone_number": "string",
      "profile_image_url": "string | null"
    }
  ]
}
```

| 필드 | 타입 | 설명 |
|------|------|------|
| `link_id` | string | 가디언 링크 ID |
| `guardian_id` | string | 가디언의 `user_id` |
| `status` | string | `"pending"` / `"accepted"` / `"rejected"` |
| `created_at` | string | 초대 요청 시각 |
| `accepted_at` | string \| null | 수락 시각. 수락 전이면 `null` |
| `display_name` | string | 가디언 이름 |
| `phone_number` | string | 가디언 전화번호 |
| `profile_image_url` | string \| null | 가디언 프로필 이미지 URL |

**Error Codes**

| Code | 설명 |
|------|------|
| 401 | 인증 토큰 없음 또는 만료 |
| 500 | 서버 내부 오류 |

---

#### [GET] /api/v1/trips/:tripId/guardians/pending

**인증**: 필요
**설명**: 현재 로그인한 가디언에게 온 **pending 초대 목록**을 반환한다. `tripId` 경로 파라미터는 라우터 구조상 포함되지만 서비스 로직에서는 사용하지 않고, 가디언 `user_id` 기준으로 전체 여행의 pending 초대를 반환한다.

**Path Parameters**

| 파라미터 | 타입 | 설명 |
|---------|------|------|
| `tripId` | string (UUID) | 경로 파라미터 (서비스 로직 미사용 — 전체 여행 기준 조회). Flutter 클라이언트는 임의의 UUID 또는 플레이스홀더를 전달해도 무방하며, 응답은 `tripId`와 무관하게 로그인한 가디언의 전체 pending 초대를 반환한다. |

**Response 200**
```json
{
  "success": true,
  "data": [
    {
      "link_id": "string (UUID)",
      "trip_id": "string (UUID)",
      "member_id": "string (UUID)",
      "created_at": "string (ISO 8601)",
      "member_display_name": "string",
      "member_phone_number": "string",
      "member_profile_image_url": "string | null",
      "trip_country_code": "string",
      "trip_country_name": "string",
      "trip_destination_city": "string | null",
      "trip_start_date": "string (YYYY-MM-DD)",
      "trip_end_date": "string (YYYY-MM-DD)"
    }
  ]
}
```

| 필드 | 타입 | 설명 |
|------|------|------|
| `link_id` | string | 가디언 링크 ID |
| `trip_id` | string | 여행 ID |
| `member_id` | string | 초대한 멤버의 `user_id` |
| `created_at` | string | 초대 요청 시각 |
| `member_display_name` | string | 초대한 멤버 이름 |
| `member_phone_number` | string | 초대한 멤버 전화번호 |
| `member_profile_image_url` | string \| null | 초대한 멤버 프로필 이미지 |
| `trip_country_code` | string | 여행 국가 코드 |
| `trip_country_name` | string | 여행 국가명 |
| `trip_destination_city` | string \| null | 여행 목적지 도시 |
| `trip_start_date` | string | 여행 시작일 (`YYYY-MM-DD`) |
| `trip_end_date` | string | 여행 종료일 (`YYYY-MM-DD`) |

**Error Codes**

| Code | 설명 |
|------|------|
| 401 | 인증 토큰 없음 또는 만료 |
| 500 | 서버 내부 오류 |

---

#### [GET] /api/v1/trips/:tripId/guardians/linked-members

**인증**: 필요
**설명**: 가디언 본인이 해당 여행에서 `accepted` 상태로 연결된 멤버 목록을 반환한다. 가디언은 자신이 수락한 멤버의 정보만 볼 수 있으며, 다른 멤버는 보이지 않는다. `display_name` 오름차순 정렬.

**Path Parameters**

| 파라미터 | 타입 | 설명 |
|---------|------|------|
| `tripId` | string (UUID) | 여행 ID |

**Response 200**
```json
{
  "success": true,
  "data": [
    {
      "link_id": "string (UUID)",
      "member_id": "string (UUID)",
      "display_name": "string",
      "phone_number": "string",
      "profile_image_url": "string | null",
      "member_role": "string | null",
      "group_member_id": "string | null"
    }
  ]
}
```

| 필드 | 타입 | 설명 |
|------|------|------|
| `link_id` | string | 가디언 링크 ID |
| `member_id` | string | 멤버의 `user_id` |
| `display_name` | string | 멤버 이름 |
| `phone_number` | string | 멤버 전화번호 |
| `profile_image_url` | string \| null | 멤버 프로필 이미지 URL |
| `member_role` | string \| null | 그룹 내 역할 (`captain`, `crew_chief`, `crew` 등). 그룹 미소속 시 `null` |
| `group_member_id` | string \| null | `tb_group_member.member_id`. 그룹 미소속 시 `null` |

**Error Codes**

| Code | 설명 |
|------|------|
| 401 | 인증 토큰 없음 또는 만료 |
| 500 | 서버 내부 오류 |

---

### 8.B 가디언 메시지

**Base URL**: `/api/v1/trips/:tripId/guardian-messages`
**인증**: 모든 엔드포인트에 Firebase 인증 필요
**저장소**: Firebase Realtime Database (RTDB)

---

#### [POST] /api/v1/trips/:tripId/guardian-messages/member

**인증**: 필요
**설명**: 멤버와 가디언 사이의 링크 채널로 메시지를 전송한다. `requireMemberOwnsLinkFromBody` 미들웨어가 사전 검증하여 `link_id`가 존재하고, 요청자가 해당 링크의 `member_id` 또는 `guardian_id`이며, 링크 상태가 `accepted`인 경우에만 전송이 허용된다. 수신자는 발신자의 반대편 (멤버→가디언 또는 가디언→멤버)으로 자동 결정된다.

**RTDB 경로**: `guardian_messages/{tripId}/{linkId}/messages/{messageKey}`

**Path Parameters**

| 파라미터 | 타입 | 설명 |
|---------|------|------|
| `tripId` | string (UUID) | 여행 ID |

**Request Body**
```json
{
  "link_id": "string",
  "message": "string"
}
```

| 필드 | 타입 | 필수 | 설명 |
|------|------|:----:|------|
| `link_id` | string (UUID) | ✅ | 메시지를 보낼 가디언 링크 ID (`tb_guardian_link.link_id`) |
| `message` | string | ✅ | 메시지 본문 |

**Response 201**
```json
{
  "success": true,
  "data": {
    "message_key": "string",
    "channel_id": "link_{linkId}"
  },
  "message": "메시지가 전송되었습니다"
}
```

| 필드 | 타입 | 설명 |
|------|------|------|
| `message_key` | string | RTDB에 생성된 메시지 키 |
| `channel_id` | string | 채널 식별자: `link_{linkId}` 형식 |

**RTDB 메시지 객체 구조**
```json
{
  "sender_id": "string (user_id)",
  "receiver_id": "string (user_id)",
  "message": "string",
  "message_type": "to_member",
  "created_at": "number (Unix timestamp ms)",
  "read_at": null
}
```

> **⚠️ Flutter 구현 주의**: `message_type`은 멤버-가디언 링크 채널에서 발신자/수신자에 관계없이 항상 `"to_member"` 고정값이다. 메시지 버블의 좌/우(발신·수신) 방향은 `sender_id`와 클라이언트 본인의 `user_id`를 비교하여 판별해야 한다.

**Error Codes**

| Code | 설명 |
|------|------|
| 400 | `link_id` 누락: `"link_id is required"` |
| 400 | `message` 누락: `"message is required"` |
| 401 | 인증 토큰 없음 또는 만료 |
| 403 | 요청자가 링크의 member_id/guardian_id가 아님: `"해당 가디언 링크에 대한 권한이 없습니다"` |
| 403 | 링크 상태가 `accepted`가 아님: `"수락된 가디언 링크가 아닙니다"` |
| 404 | `link_id`에 해당하는 링크 없음: `"해당 가디언 링크를 찾을 수 없습니다"` |
| 500 | 서버 내부 오류 |

---

#### [POST] /api/v1/trips/:tripId/guardian-messages/captain

**인증**: 필요
**설명**: 가디언이 캡틴에게 메시지를 전송한다. `requireCanMessageCaptain` 미들웨어가 사전 검증하여 해당 여행에 `accepted` 링크가 1개 이상 있어야 하고, `tb_trip_settings.captain_receive_guardian_msg = true`이어야 한다 (설정이 없으면 기본값 `true`).

**RTDB 경로**: `guardian_captain_messages/{tripId}/{guardianId}/messages/{messageKey}`

**Path Parameters**

| 파라미터 | 타입 | 설명 |
|---------|------|------|
| `tripId` | string (UUID) | 여행 ID |

**Request Body**
```json
{
  "message": "string"
}
```

| 필드 | 타입 | 필수 | 설명 |
|------|------|:----:|------|
| `message` | string | ✅ | 메시지 본문 |

**Response 201**
```json
{
  "success": true,
  "data": {
    "message_key": "string",
    "channel_id": "captain_{guardianId}"
  },
  "message": "메시지가 전송되었습니다"
}
```

| 필드 | 타입 | 설명 |
|------|------|------|
| `message_key` | string | RTDB에 생성된 메시지 키 |
| `channel_id` | string | 채널 식별자: `captain_{guardianId}` 형식 |

**RTDB 메시지 객체 구조**
```json
{
  "sender_id": "string (guardianId)",
  "receiver_id": "string (captainId)",
  "message": "string",
  "message_type": "to_captain",
  "created_at": "number (Unix timestamp ms)",
  "read_at": null
}
```

**Error Codes**

| Code | 설명 |
|------|------|
| 400 | `message` 누락: `"message is required"` |
| 401 | 인증 토큰 없음 또는 만료 |
| 403 | 해당 여행에 accepted 링크 없음: `"해당 여행에 대한 가디언 권한이 없습니다"` |
| 403 | 캡틴이 가디언 메시지 수신을 비활성화: `"캡틴이 메시지 수신을 비활성화했습니다"` |
| 404 | 캡틴을 찾을 수 없음: `"캡틴을 찾을 수 없습니다"` |
| 500 | 서버 내부 오류 |

---

#### [GET] /api/v1/trips/:tripId/guardian-messages/:channelId

**인증**: 필요
**설명**: 채널 메시지 이력을 조회한다. 최근 50개를 `created_at` 오름차순으로 반환한다. `validateChannelAccess`로 접근 권한을 검증한다 — `link_{linkId}` 채널은 해당 링크의 `member_id`/`guardian_id`, `captain_{guardianId}` 채널은 `guardianId` 본인 또는 캡틴만 접근 가능.

**Path Parameters**

| 파라미터 | 타입 | 설명 |
|---------|------|------|
| `tripId` | string (UUID) | 여행 ID |
| `channelId` | string | 채널 ID (`link_{linkId}` 또는 `captain_{guardianId}`) |

**Response 200**
```json
{
  "success": true,
  "data": [
    {
      "message_id": "string",
      "sender_id": "string (user_id)",
      "receiver_id": "string (user_id)",
      "message": "string",
      "message_type": "string",
      "created_at": "number (Unix timestamp ms)",
      "read_at": "number | null"
    }
  ]
}
```

| 필드 | 타입 | 설명 |
|------|------|------|
| `message_id` | string | RTDB 메시지 키 |
| `sender_id` | string | 발신자 `user_id` |
| `receiver_id` | string | 수신자 `user_id` |
| `message` | string | 메시지 본문 |
| `message_type` | string | `"to_member"` 또는 `"to_captain"` |
| `created_at` | number | 전송 시각 (Unix 타임스탬프, 밀리초) |
| `read_at` | number \| null | 읽음 처리 시각. 미읽음이면 `null` |

> 채널에 메시지가 없으면 빈 배열 `[]` 반환.

**Error Codes**

| Code | 설명 |
|------|------|
| 401 | 인증 토큰 없음 또는 만료 |
| 403 | 채널 접근 권한 없음: `"해당 채널에 접근 권한이 없습니다"` |
| 500 | 서버 내부 오류 |

---

#### [PATCH] /api/v1/trips/:tripId/guardian-messages/:channelId/:messageId/read

**인증**: 필요
**설명**: RTDB의 특정 메시지에 `read_at` 타임스탬프를 기록하여 읽음 처리한다. 채널 접근 권한을 먼저 검증한다.

**Path Parameters**

| 파라미터 | 타입 | 설명 |
|---------|------|------|
| `tripId` | string (UUID) | 여행 ID |
| `channelId` | string | 채널 ID (`link_{linkId}` 또는 `captain_{guardianId}`) |
| `messageId` | string | 읽음 처리할 RTDB 메시지 키 |

**Request Body**: 없음

**Response 200**
```json
{
  "success": true,
  "data": null,
  "message": "읽음 처리 완료"
}
```

**Error Codes**

| Code | 설명 |
|------|------|
| 401 | 인증 토큰 없음 또는 만료 |
| 403 | 채널 접근 권한 없음: `"해당 채널에 접근 권한이 없습니다"` |
| 500 | 서버 내부 오류 |

---

### 8.C 가디언 뷰

**Base URL**: `/api/v1/trips/:tripId/guardian-view`
**인증**: 모든 엔드포인트에 Firebase 인증 필요
**권한**: 가디언은 자신이 `accepted` 링크로 연결된 멤버 및 여행 정보만 조회 가능. 다른 멤버의 정보는 보이지 않음.

---

#### [GET] /api/v1/trips/:tripId/guardian-view/:memberId

**인증**: 필요
**설명**: 가디언이 연결된 특정 멤버의 기본 프로필을 조회한다. `requireGuardianLinkForMember` 미들웨어가 해당 tripId + memberId에 대한 `accepted` 링크 존재 여부를 검증한다.

**Path Parameters**

| 파라미터 | 타입 | 설명 |
|---------|------|------|
| `tripId` | string (UUID) | 여행 ID |
| `memberId` | string (UUID) | 조회할 멤버의 `user_id` |

**Response 200**
```json
{
  "success": true,
  "data": {
    "user_id": "string (UUID)",
    "display_name": "string",
    "phone_number": "string",
    "profile_image_url": "string | null",
    "member_role": "string | null"
  }
}
```

| 필드 | 타입 | 설명 |
|------|------|------|
| `user_id` | string | 멤버의 `user_id` |
| `display_name` | string | 멤버 이름 |
| `phone_number` | string | 멤버 전화번호 |
| `profile_image_url` | string \| null | 멤버 프로필 이미지 URL |
| `member_role` | string \| null | 그룹 내 역할 (`captain`, `crew_chief`, `crew` 등). 그룹 미소속 시 `null` |

**Error Codes**

| Code | 설명 |
|------|------|
| 401 | 인증 토큰 없음 또는 만료 |
| 403 | 해당 멤버에 대한 accepted 링크 없음: `"해당 멤버에 대한 가디언 권한이 없습니다"` |
| 404 | 멤버 정보 없음: `"멤버 정보를 찾을 수 없습니다"` |
| 500 | 서버 내부 오류 |

---

#### [GET] /api/v1/trips/:tripId/guardian-view/itinerary

**인증**: 필요
**설명**: 가디언이 여행 일정(스케줄)을 읽기 전용으로 조회한다. `requireGuardianLinkForTrip` 미들웨어가 해당 tripId에 대한 `accepted` 링크가 1개 이상인지 검증한다. `tb_travel_schedule` 테이블에서 `start_time` 오름차순으로 반환.

> **주의**: 경로 `/itinerary`가 `/:memberId` 보다 먼저 등록되어 있어 NestJS가 `itinerary`를 `memberId`로 잘못 매핑하지 않는다.

**Path Parameters**

| 파라미터 | 타입 | 설명 |
|---------|------|------|
| `tripId` | string (UUID) | 여행 ID |

**Response 200**
```json
{
  "success": true,
  "data": [
    {
      "schedule_id": "string (UUID)",
      "title": "string",
      "description": "string | null",
      "schedule_type": "string",
      "start_time": "string (ISO 8601)",
      "end_time": "string (ISO 8601) | null",
      "location_name": "string | null",
      "location_address": "string | null"
    }
  ]
}
```

| 필드 | 타입 | 설명 |
|------|------|------|
| `schedule_id` | string | 일정 ID (`tb_travel_schedule.schedule_id`) |
| `title` | string | 일정 제목 |
| `description` | string \| null | 일정 설명 |
| `schedule_type` | string | 일정 유형 |
| `start_time` | string | 시작 시각 (ISO 8601) |
| `end_time` | string \| null | 종료 시각. 미설정 시 `null` |
| `location_name` | string \| null | 장소명 |
| `location_address` | string \| null | 장소 주소 |

**Error Codes**

| Code | 설명 |
|------|------|
| 401 | 인증 토큰 없음 또는 만료 |
| 403 | 해당 여행에 accepted 링크 없음: `"해당 여행에 대한 가디언 권한이 없습니다"` |
| 500 | 서버 내부 오류 |

---

#### [GET] /api/v1/trips/:tripId/guardian-view/places

**인증**: 필요
**설명**: 가디언이 여행에 설정된 장소(지오펜스)를 읽기 전용으로 조회한다. `requireGuardianLinkForTrip` 미들웨어로 권한 검증. `tb_geofence`에서 `is_active = TRUE`인 항목만 반환하며 `name` 오름차순 정렬.

**Path Parameters**

| 파라미터 | 타입 | 설명 |
|---------|------|------|
| `tripId` | string (UUID) | 여행 ID |

**Response 200**
```json
{
  "success": true,
  "data": [
    {
      "geofence_id": "string (UUID)",
      "name": "string",
      "center_latitude": "number",
      "center_longitude": "number",
      "radius_meters": "number | null",
      "shape_type": "string"
    }
  ]
}
```

| 필드 | 타입 | 설명 |
|------|------|------|
| `geofence_id` | string | 지오펜스 ID (`tb_geofence.geofence_id`) |
| `name` | string | 장소명 |
| `center_latitude` | number | 중심 위도 (float) |
| `center_longitude` | number | 중심 경도 (float) |
| `radius_meters` | number \| null | 반경 (미터). 미설정 시 `null` |
| `shape_type` | string | 지오펜스 형태 (예: `circle`, `polygon`) |

**Error Codes**

| Code | 설명 |
|------|------|
| 401 | 인증 토큰 없음 또는 만료 |
| 403 | 해당 여행에 accepted 링크 없음: `"해당 여행에 대한 가디언 권한이 없습니다"` |
| 500 | 서버 내부 오류 |

---

### 8.D 레거시 가디언 (Deprecated)

**Base URL**: `/api/v1/guardians`
**상태**: `@deprecated` — Phase 4에서 제거 예정. 새 시스템에서는 `tb_guardian_link` 기반 API(`§8.A~§8.C`)를 사용.

---

#### [GET] /api/v1/guardians/verify-code/:code

**인증**: 불필요
**설명**: 레거시 `tb_guardian` 테이블 기반의 보호자 초대 코드 존재 여부를 확인한다. 코드가 `pending` 상태이고 만료되지 않았으면 `exists: true` 반환.

**Path Parameters**

| 파라미터 | 타입 | 설명 |
|---------|------|------|
| `code` | string | 레거시 보호자 초대 코드 |

**Response 200**
```json
{
  "success": true,
  "data": {
    "exists": "boolean"
  }
}
```

| 필드 | 타입 | 설명 |
|------|------|------|
| `exists` | boolean | 유효한 초대 코드 존재 여부 |

**Error Codes**

| Code | 설명 |
|------|------|
| 400 | `code` 누락 |
| 500 | 서버 내부 오류 |

---

#### [POST] /api/v1/guardians/verify-phone

**인증**: 불필요
**설명**: 레거시 `tb_guardian` 테이블에서 초대 코드와 전화번호 일치 여부를 확인한다.

**Request Body**
```json
{
  "guardian_invite_code": "string",
  "guardian_phone": "string"
}
```

| 필드 | 타입 | 필수 | 설명 |
|------|------|:----:|------|
| `guardian_invite_code` | string | ✅ | 레거시 보호자 초대 코드 |
| `guardian_phone` | string | ✅ | 확인할 전화번호 |

**Response 200**
```json
{
  "success": true,
  "data": {
    "is_valid": "boolean",
    "traveler_phone": "string | undefined"
  }
}
```

| 필드 | 타입 | 설명 |
|------|------|------|
| `is_valid` | boolean | 전화번호 일치 여부 |
| `traveler_phone` | string \| undefined | 여행자(보호대상) 전화번호. 일치 시에만 포함될 수 있음 |

**Error Codes**

| Code | 설명 |
|------|------|
| 400 | `guardian_invite_code` 또는 `guardian_phone` 누락 |
| 500 | 서버 내부 오류 (DB 오류 포함) |

---

#### [GET] /api/v1/guardians/my-trips

**인증**: 필요
**설명**: 현재 로그인한 가디언이 연결된 모든 여행 목록을 반환한다. `tb_guardian_link`에서 `accepted` 및 `pending` 상태를 모두 포함하며, `accepted` 먼저, 이후 `created_at` 내림차순 정렬.

> **⚠️ 구현 주의**: `authenticate` 미들웨어가 적용되어 있으나, 컨트롤러 내부에서 표준 `req.userId` 대신 `req.user?.uid`를 직접 추출한다. 다른 인증 엔드포인트와 상이한 패턴이며, §8.D 전체가 deprecated 구간으로 정리 예정.

**Response 200**
```json
{
  "success": true,
  "data": [
    {
      "link_id": "string (UUID)",
      "trip_id": "string (UUID)",
      "member_id": "string (UUID)",
      "status": "string",
      "trip_country_name": "string",
      "trip_start_date": "string (YYYY-MM-DD)",
      "trip_end_date": "string (YYYY-MM-DD)"
    }
  ]
}
```

| 필드 | 타입 | 설명 |
|------|------|------|
| `link_id` | string | 가디언 링크 ID |
| `trip_id` | string | 여행 ID |
| `member_id` | string | 연결된 멤버의 `user_id` |
| `status` | string | `"accepted"` 또는 `"pending"` |
| `trip_country_name` | string | 여행 국가명 (`country_name` 없으면 `country_code` fallback) |
| `trip_start_date` | string | 여행 시작일 (`YYYY-MM-DD`) |
| `trip_end_date` | string | 여행 종료일 (`YYYY-MM-DD`) |

**Error Codes**

| Code | 설명 |
|------|------|
| 401 | 인증 토큰 없음 또는 만료: `"인증 정보가 없습니다"` |
| 500 | 서버 내부 오류: `"여행 목록 조회에 실패했습니다"` |

---

#### [GET] /api/v1/guardians/:guardianId/travelers

**인증**: 불필요 (TODO: 미들웨어 추가 예정)
**설명**: 레거시 엔드포인트. 특정 가디언 ID로 연결된 여행자(그룹 멤버) 목록을 조회한다. 현재 고정 `group_id`를 사용하므로 실사용 불가 상태.

**Path Parameters**

| 파라미터 | 타입 | 설명 |
|---------|------|------|
| `guardianId` | string (UUID) | 가디언 `user_id` |

**Response 200**
```json
{
  "success": true,
  "data": [
    {
      "traveler_id": "string (UUID)",
      "display_name": "string",
      "phone_number": "string",
      "can_view_all_locations": "boolean",
      "fcm_token_count": "number"
    }
  ]
}
```

**Error Codes**

| Code | 설명 |
|------|------|
| 500 | 서버 내부 오류 |

---

## §9 위치 (Locations)

**Base URL**: `/api/v1/locations`

**인증 주의**: 이 라우터에는 전역 `authenticate` 미들웨어가 적용되지 않는다. 각 핸들러는 `(req as any).userId || req.body.user_id` (POST) 또는 `req.query.user_id` (GET) 패턴으로 사용자를 식별한다. Firebase ID 토큰을 사용하는 경우 `authenticate` 미들웨어가 `req.userId`를 주입하나, 현재 라우트 정의에는 명시적 미들웨어 체인이 없다.

> **참고**: `saveLocation`은 `locationLimiter`(레이트 리밋 미들웨어)를 통해 마운트된다.

---

### 9.1 위치 저장

#### [POST] /api/v1/locations

**인증**: 선택적 (토큰 있으면 `req.userId` 사용, 없으면 `body.user_id` 필요)
**설명**: 사용자의 현재 위치를 `tb_location` 테이블에 저장한다. 세션 시작·종료 플래그와 activity 타입을 함께 기록하며, 저장 완료 후 비동기로 지오펜스 이벤트를 체크한다.

**Request Body**

```json
{
  "user_id": "string (옵션: 토큰 없을 때 필수)",
  "latitude": "number",
  "longitude": "number",
  "accuracy": "number | null",
  "altitude": "number | null",
  "speed": "number | null",
  "heading": "number | null",
  "battery_level": "integer | null",
  "network_type": "string | null",
  "tracking_mode": "string | null",
  "movement_session_id": "string (UUID) | null",
  "is_movement_start": "boolean",
  "is_movement_end": "boolean",
  "activity_type": "string | null",
  "activity_confidence": "integer | null",
  "recorded_at": "string (ISO 8601) | null",
  "group_id": "string (UUID) | null"
}
```

| 필드 | 타입 | 필수 | 설명 |
|------|------|:----:|------|
| `latitude` | number | ✅ | 위도 (`float`, parseFloat 적용) |
| `longitude` | number | ✅ | 경도 (`float`, parseFloat 적용) |
| `accuracy` | number \| null | - | GPS 정확도 (미터) |
| `altitude` | number \| null | - | 고도 (미터) |
| `speed` | number \| null | - | 속도 (m/s) |
| `heading` | number \| null | - | 방향 (0~360도) |
| `battery_level` | integer \| null | - | 배터리 잔량 (0~100) |
| `network_type` | string \| null | - | 네트워크 유형 (예: `wifi`, `cellular`) |
| `tracking_mode` | string \| null | - | 트래킹 모드 (기본값: `"normal"`) |
| `movement_session_id` | string \| null | - | 이동 세션 UUID. 신규 세션 시 클라이언트가 생성하여 전송 |
| `is_movement_start` | boolean | - | 이동 세션 시작 여부 (기본값: `false`) |
| `is_movement_end` | boolean | - | 이동 세션 종료 여부 (기본값: `false`) |
| `activity_type` | string \| null | - | 활동 유형 (예: `"walking"`, `"in_vehicle"`, `"on_bicycle"`) |
| `activity_confidence` | integer \| null | - | 활동 감지 신뢰도 (0~100) |
| `recorded_at` | string \| null | - | 기록 시각 (ISO 8601). 미전송 시 서버 수신 시각 사용 |
| `group_id` | string \| null | - | 그룹 ID (지오펜스 이벤트 체크 시 사용) |

**Response 201**
```json
{
  "success": true,
  "data": {
    "location_id": "string (UUID)",
    "movement_session_id": "string (UUID) | null"
  },
  "message": "Location saved successfully"
}
```

| 필드 | 타입 | 설명 |
|------|------|------|
| `location_id` | string | 저장된 위치 레코드의 ID (`tb_location.location_id`) |
| `movement_session_id` | string \| null | 이동 세션 ID (요청에 포함된 값 그대로 반환) |

**Error Codes**

| Code | 설명 |
|------|------|
| 400 | `latitude` 또는 `longitude` 누락: `"latitude and longitude are required"` |
| 400 | `user_id` 확인 불가: `"user_id is required"` |
| 500 | 서버 내부 오류 |

---

### 9.2 최신 위치 조회

#### [GET] /api/v1/locations/latest

**인증**: 선택적
**설명**: 사용자의 가장 최신 위치 기록 1건을 반환한다. `tb_location`에서 `recorded_at DESC LIMIT 1`으로 조회.

**Query Parameters**

| 파라미터 | 타입 | 필수 | 설명 |
|---------|------|:----:|------|
| `user_id` | string | ✅ | 대상 사용자 ID |

**Response 200**
```json
{
  "success": true,
  "data": {
    "latitude": "number",
    "longitude": "number",
    "accuracy": "number | null",
    "altitude": "number | null",
    "speed": "number | null",
    "heading": "number | null",
    "battery_level": "integer | null",
    "network_type": "string | null",
    "tracking_mode": "string | null",
    "recorded_at": "string (ISO 8601)",
    "address": "string | null",
    "city": "string | null",
    "country": "string | null",
    "movement_session_id": "string (UUID) | null"
  }
}
```

**Error Codes**

| Code | 설명 |
|------|------|
| 400 | `user_id` 누락: `"user_id is required"` |
| 404 | 위치 기록 없음: `"Location not found"` |
| 500 | 서버 내부 오류 |

---

### 9.3 위치 이력 조회

#### [GET] /api/v1/locations/history

**인증**: 선택적
**설명**: 사용자의 최근 위치 이력을 최대 `limit`건 반환한다. `recorded_at DESC` 정렬.

**Query Parameters**

| 파라미터 | 타입 | 필수 | 설명 |
|---------|------|:----:|------|
| `user_id` | string | ✅ | 대상 사용자 ID |
| `limit` | integer | - | 최대 반환 건수 (기본값: `100`) |

**Response 200**
```json
{
  "success": true,
  "data": {
    "locations": [
      {
        "latitude": "number",
        "longitude": "number",
        "accuracy": "number | null",
        "altitude": "number | null",
        "speed": "number | null",
        "heading": "number | null",
        "battery_level": "integer | null",
        "network_type": "string | null",
        "tracking_mode": "string | null",
        "recorded_at": "string (ISO 8601)",
        "address": "string | null",
        "city": "string | null",
        "country": "string | null",
        "movement_session_id": "string (UUID) | null"
      }
    ],
    "total": "integer"
  }
}
```

| 필드 | 타입 | 설명 |
|------|------|------|
| `locations` | array | 위치 기록 배열 (`recorded_at DESC`) |
| `total` | integer | 반환된 건수 (실제 배열 길이) |

**Error Codes**

| Code | 설명 |
|------|------|
| 400 | `user_id` 누락: `"user_id is required"` |
| 500 | 서버 내부 오류 |

---

### 9.4 이동 세션 요약 목록 조회

#### [GET] /api/v1/locations/users/:userId/movement-sessions/summary

**인증**: 선택적
**설명**: 사용자의 이동 세션 요약 목록을 페이지네이션하여 반환한다. 각 세션은 시작·종료 위치, 이동 거리, 지도 이미지 URL 등을 포함한다. 종료된 세션 중 위치 포인트가 10개 미만인 세션은 제외된다. `need_images` 파라미터를 사용해 지도 이미지 생성을 요청한 세션만 선택적으로 이미지를 포함시킬 수 있다. 진행 중인 세션은 이미지를 생성하지 않으며 `map_image_url: null`을 반환한다.

**Path Parameters**

| 파라미터 | 타입 | 설명 |
|---------|------|------|
| `userId` | string (UUID) | 사용자 ID |

**Query Parameters**

| 파라미터 | 타입 | 필수 | 설명 |
|---------|------|:----:|------|
| `page` | integer | - | 페이지 번호 (기본값: `1`) |
| `limit` | integer | - | 페이지당 건수 (기본값: `20`) |
| `need_images` | string | - | 이미지를 생성할 세션 ID 목록. 콤마 구분 (예: `"uuid1,uuid2"`) |
| `target_date` | string | - | 이미지 생성 대상 날짜 (YYYY-MM-DD 형식) |
| `timezone_offset` | integer | - | 시간대 오프셋 (시간 단위, 기본값: `0` = UTC). 예: 한국 `9` |

**Response 200**
```json
{
  "success": true,
  "data": {
    "sessions": [
      {
        "session_id": "string (UUID)",
        "location_count": "integer",
        "start_location": {
          "latitude": "number | null",
          "longitude": "number | null",
          "address": "string | null",
          "city": "string | null",
          "country": "string | null"
        },
        "end_location": {
          "latitude": "number | null",
          "longitude": "number | null",
          "address": "string | null",
          "city": "string | null",
          "country": "string | null"
        },
        "battery_level": "integer | null",
        "start_time": "string (ISO 8601) | null",
        "end_time": "string (ISO 8601) | null",
        "is_completed": "boolean",
        "is_ongoing": "boolean",
        "total_distance_km": "number | null",
        "event_count": "integer",
        "vehicle_type": "string",
        "map_image_url": "string (URL) | null",
        "map_image_base64": "string | null"
      }
    ],
    "page": "integer",
    "limit": "integer",
    "total": "integer"
  }
}
```

| 필드 | 타입 | 설명 |
|------|------|------|
| `session_id` | string | 이동 세션 UUID (`tb_location.movement_session_id`) |
| `location_count` | integer | 세션 내 위치 기록 수 |
| `start_location` | object | 세션 첫 번째 위치 정보 |
| `end_location` | object | 세션 마지막 위치 정보 |
| `battery_level` | integer \| null | 세션 종료 시점 배터리 잔량 |
| `start_time` | string \| null | 세션 시작 시각 (ISO 8601 UTC) |
| `end_time` | string \| null | 세션 종료 시각 (ISO 8601 UTC) |
| `is_completed` | boolean | 세션 완료 여부 (진행 중이면 `false`) |
| `is_ongoing` | boolean | 현재 진행 중인 세션 여부 (RTDB `active_session_id` 기준) |
| `total_distance_km` | number \| null | PostGIS `ST_Length`로 계산된 총 이동 거리 (km) |
| `event_count` | integer | `tb_event_log`에서 `event_type = 'session_event'`인 이벤트 수 |
| `vehicle_type` | string | `"vehicle"` (세션 중 `activity_type = 'in_vehicle'`이 1회 이상) 또는 `"walking"` |
| `map_image_url` | string \| null | Firebase Storage 지도 이미지 URL. 진행 중 세션 또는 `need_images` 미포함 세션은 `null` |
| `map_image_base64` | string \| null | 지도 이미지 Base64 (하위 호환용, Storage URL 없을 때만 포함) |

**Error Codes**

| Code | 설명 |
|------|------|
| 400 | `user_id` 확인 불가: `"user_id is required"` |
| 500 | 서버 내부 오류 |

---

### 9.5 이동 세션 날짜 범위 조회

#### [GET] /api/v1/locations/users/:userId/movement-sessions/date-range

**인증**: 선택적
**설명**: 사용자의 전체 이동 세션 중 최초 세션 시작일과 최종 세션 시작일(로컬 날짜)을 반환한다. 달력 UI에서 유효한 날짜 범위를 표시할 때 사용한다.

**Path Parameters**

| 파라미터 | 타입 | 설명 |
|---------|------|------|
| `userId` | string (UUID) | 사용자 ID |

**Query Parameters**

| 파라미터 | 타입 | 필수 | 설명 |
|---------|------|:----:|------|
| `timezone_offset` | integer | - | 시간대 오프셋 (시간 단위, 기본값: `0` = UTC) |

**Response 200**
```json
{
  "success": true,
  "data": {
    "start_date": "string (YYYY-MM-DD) | null",
    "end_date": "string (YYYY-MM-DD) | null"
  }
}
```

| 필드 | 타입 | 설명 |
|------|------|------|
| `start_date` | string \| null | 가장 오래된 세션의 시작 날짜 (로컬). 세션 없으면 `null` |
| `end_date` | string \| null | 가장 최근 세션의 시작 날짜 (로컬). 세션 없으면 `null` |

**Error Codes**

| Code | 설명 |
|------|------|
| 400 | `user_id` 확인 불가: `"user_id is required"` |
| 500 | 서버 내부 오류 |

---

### 9.6 날짜별 이동 세션 목록 조회

#### [GET] /api/v1/locations/users/:userId/movement-sessions/by-date

**인증**: 선택적
**설명**: 특정 날짜(로컬 날짜 기준)에 시작된 이동 세션 목록을 반환한다. SQL 레벨에서 `timezone_offset`을 적용하여 날짜 필터링하며, 세션 요약 형태로 지도 이미지를 선택적으로 포함한다.

**Path Parameters**

| 파라미터 | 타입 | 설명 |
|---------|------|------|
| `userId` | string (UUID) | 사용자 ID |

**Query Parameters**

| 파라미터 | 타입 | 필수 | 설명 |
|---------|------|:----:|------|
| `date` | string | ✅ | 조회 날짜 (YYYY-MM-DD 형식, 정규식 검증) |
| `timezone_offset` | integer | - | 시간대 오프셋 (시간 단위, 기본값: `0` = UTC) |
| `need_images` | string | - | 이미지를 생성할 세션 ID 목록 (콤마 구분) |

**Response 200**
```json
{
  "success": true,
  "data": {
    "sessions": [
      {
        "session_id": "string (UUID)",
        "location_count": "integer",
        "start_location": {
          "latitude": "number | null",
          "longitude": "number | null",
          "address": "string | null",
          "city": "string | null",
          "country": "string | null"
        },
        "end_location": {
          "latitude": "number | null",
          "longitude": "number | null",
          "address": "string | null",
          "city": "string | null",
          "country": "string | null"
        },
        "battery_level": "integer | null",
        "start_time": "string (ISO 8601) | null",
        "end_time": "string (ISO 8601) | null",
        "is_completed": "boolean",
        "is_ongoing": "boolean",
        "total_distance_km": "number | null",
        "event_count": "integer",
        "vehicle_type": "string",
        "map_image_url": "string (URL) | null",
        "map_image_base64": "string | null"
      }
    ],
    "date": "string (YYYY-MM-DD)",
    "total": "integer"
  }
}
```

**Error Codes**

| Code | 설명 |
|------|------|
| 400 | `user_id` 확인 불가: `"user_id is required"` |
| 400 | `date` 누락: `"date is required (YYYY-MM-DD format)"` |
| 400 | 날짜 형식 오류: `"Invalid date format. Use YYYY-MM-DD"` |
| 500 | 서버 내부 오류 |

---

### 9.7 이동 세션 상세 조회

#### [GET] /api/v1/locations/users/:userId/movement-sessions/:sessionId

**인증**: 선택적
**설명**: 특정 이동 세션의 상세 위치 좌표 목록을 반환한다. `recorded_at ASC` 정렬. 세션 시작·종료 시각은 첫/마지막 위치 레코드의 `recorded_at`에서 계산한다.

**Path Parameters**

| 파라미터 | 타입 | 설명 |
|---------|------|------|
| `userId` | string (UUID) | 사용자 ID |
| `sessionId` | string (UUID) | 이동 세션 ID |

**Response 200**
```json
{
  "success": true,
  "data": {
    "session_id": "string (UUID)",
    "start_time": "string (ISO 8601)",
    "end_time": "string (ISO 8601)",
    "is_completed": null,
    "locations": [
      {
        "latitude": "number",
        "longitude": "number",
        "accuracy": "number | null",
        "altitude": "number | null",
        "speed": "number | null",
        "heading": "number | null",
        "battery_level": "integer | null",
        "recorded_at": "string (ISO 8601)",
        "is_movement_start": "boolean",
        "is_movement_end": "boolean",
        "address": "string | null",
        "city": "string | null",
        "country": "string | null"
      }
    ]
  }
}
```

| 필드 | 타입 | 설명 |
|------|------|------|
| `session_id` | string | 이동 세션 UUID |
| `start_time` | string | 첫 번째 위치의 `recorded_at` (ISO 8601 UTC) |
| `end_time` | string | 마지막 위치의 `recorded_at` (ISO 8601 UTC) |
| `is_completed` | null | 항상 `null` (현재 버전에서 미계산) |
| `locations` | array | 세션 내 전체 위치 좌표 배열 (`recorded_at ASC`) |

**Error Codes**

| Code | 설명 |
|------|------|
| 400 | `user_id` 또는 `session_id` 누락 |
| 404 | 세션 또는 위치 데이터 없음: `"Movement session not found"` |
| 500 | 서버 내부 오류 |

---

### 9.8 이동 세션 완료 처리

#### [PATCH] /api/v1/locations/users/:userId/movement-sessions/:sessionId/complete

**인증**: 선택적
**설명**: 이동 세션 완료를 서버에 알리는 엔드포인트. 현재 구현은 `{ success: true }`만 반환하는 스텁(stub) 상태이며, 세션 완료 여부는 위치 데이터 시간 기반으로 클라이언트 측에서 판단한다.

> **구현 주의**: `locationService.completeMovementSession`이 항상 `{ success: true }`를 반환하는 호환성 유지용 스텁으로, `is_movement_end`나 세션 상태를 실제로 변경하지 않는다.

**Path Parameters**

| 파라미터 | 타입 | 설명 |
|---------|------|------|
| `userId` | string (UUID) | 사용자 ID |
| `sessionId` | string (UUID) | 이동 세션 ID |

**Request Body**

```json
{
  "latitude": "number",
  "longitude": "number",
  "recorded_at": "string (ISO 8601)"
}
```

| 필드 | 타입 | 필수 | 설명 |
|------|------|:----:|------|
| `latitude` | number | ✅ | 종료 위치 위도 |
| `longitude` | number | ✅ | 종료 위치 경도 |
| `recorded_at` | string | ✅ | 종료 시각 (ISO 8601) |

**Response 200**
```json
{
  "success": true,
  "data": {
    "success": true
  }
}
```

**Error Codes**

| Code | 설명 |
|------|------|
| 400 | `latitude`, `longitude`, `recorded_at` 중 누락 |
| 500 | 서버 내부 오류 |

---

### 9.9 이동 세션 이벤트 목록 조회

#### [GET] /api/v1/locations/users/:userId/movement-sessions/:sessionId/events

**인증**: 선택적
**설명**: 특정 이동 세션에서 기록된 `session_event` 타입 이벤트 목록을 반환한다. `tb_event_log`에서 `event_type = 'session_event'`이고 해당 `movement_session_id`인 레코드를 `occurred_at ASC` 정렬로 반환한다.

**Path Parameters**

| 파라미터 | 타입 | 설명 |
|---------|------|------|
| `userId` | string (UUID) | 사용자 ID |
| `sessionId` | string (UUID) | 이동 세션 ID |

**Response 200**
```json
{
  "success": true,
  "data": {
    "session_id": "string (UUID)",
    "events": [
      {
        "event_id": "string (UUID)",
        "event_type": "string",
        "event_subtype": "string | null",
        "latitude": "number | null",
        "longitude": "number | null",
        "address": "string | null",
        "battery_level": "integer | null",
        "battery_is_charging": "boolean | null",
        "network_type": "string | null",
        "event_data": "object | null",
        "occurred_at": "string (ISO 8601)"
      }
    ],
    "count": "integer"
  }
}
```

| 필드 | 타입 | 설명 |
|------|------|------|
| `session_id` | string | 요청한 세션 ID |
| `events` | array | `session_event` 이벤트 목록 (`occurred_at ASC`) |
| `events[].event_type` | string | 이벤트 유형. 이 엔드포인트에서는 항상 `"session_event"` |
| `events[].event_subtype` | string \| null | 세부 유형 |
| `events[].event_data` | object \| null | 이벤트 추가 데이터 (JSON) |
| `count` | integer | 이벤트 총 수 |

**Error Codes**

| Code | 설명 |
|------|------|
| 400 | `user_id` 또는 `session_id` 누락 |
| 500 | 서버 내부 오류 |

---

### 9.10 위치 공유 설정 (그룹 서브 리소스)

위치 공유 관련 API는 그룹 라우터(`/api/v1/groups`)에 마운트된 서브 라우터로 제공된다. `§6 그룹` 외에 아래 세 엔드포인트를 추가로 포함한다.

#### [GET] /api/v1/groups/:groupId/location-sharing

**인증**: 선택적 (이 라우터에는 `authenticate` 미들웨어 없음. 토큰이 있으면 `req.userId` 사용, 없으면 `req.query.user_id` 필요)
**설명**: 그룹의 마스터 위치 공유 ON/OFF 상태와 각 멤버별 공유 설정을 반환한다. 요청자가 해당 그룹의 멤버가 아니면 403.

**Path Parameters**

| 파라미터 | 타입 | 설명 |
|---------|------|------|
| `groupId` | string (UUID) | 그룹 ID |

**Response 200**
```json
{
  "success": true,
  "data": {
    "group_id": "string (UUID)",
    "master_enabled": "boolean",
    "members": [
      {
        "user_id": "string (UUID)",
        "enabled": "boolean"
      }
    ]
  }
}
```

**Error Codes**

| Code | 설명 |
|------|------|
| 400 | `groupId` 또는 `user_id` 누락: `"groupId and user_id are required"` |
| 403 | 그룹 멤버 아님: `"Not a member of this group"` |
| 500 | 서버 내부 오류 |

---

#### [PUT] /api/v1/groups/:groupId/location-sharing/master

**인증**: 선택적 (토큰 없으면 `req.body.user_id` 필요)
**설명**: 그룹 전체의 위치 공유 마스터 스위치를 ON/OFF한다.

**Path Parameters**

| 파라미터 | 타입 | 설명 |
|---------|------|------|
| `groupId` | string (UUID) | 그룹 ID |

**Request Body**

```json
{
  "enabled": "boolean"
}
```

| 필드 | 타입 | 필수 | 설명 |
|------|------|:----:|------|
| `enabled` | boolean | ✅ | `true` = 위치 공유 활성화, `false` = 비활성화 |

**Response 200**
```json
{
  "success": true,
  "data": {},
  "message": "Location sharing master switch updated"
}
```

**Error Codes**

| Code | 설명 |
|------|------|
| 400 | `groupId` / `user_id` 누락 또는 `enabled`가 boolean이 아님 |
| 500 | 서버 내부 오류 |

---

#### [PUT] /api/v1/groups/:groupId/location-sharing/:targetUserId

**인증**: 선택적 (토큰 없으면 `req.body.user_id` 필요)
**설명**: 그룹 내 특정 멤버의 위치 공유 여부를 개별 토글한다. 요청자가 그룹 멤버여야 한다.

**Path Parameters**

| 파라미터 | 타입 | 설명 |
|---------|------|------|
| `groupId` | string (UUID) | 그룹 ID |
| `targetUserId` | string (UUID) | 공유 설정을 변경할 대상 멤버 ID |

**Request Body**

```json
{
  "enabled": "boolean"
}
```

| 필드 | 타입 | 필수 | 설명 |
|------|------|:----:|------|
| `enabled` | boolean | ✅ | `true` = 해당 멤버 위치 공유 활성화 |

**Response 200**
```json
{
  "success": true,
  "data": {},
  "message": "Member sharing setting updated"
}
```

**Error Codes**

| Code | 설명 |
|------|------|
| 400 | `groupId`, `targetUserId`, `user_id` 중 누락: `"groupId, targetUserId, and user_id are required"` |
| 400 | `enabled`가 boolean이 아님: `"enabled (boolean) is required"` |
| 403 | 그룹 멤버 아님: `"Not a member of this group"` |
| 500 | 서버 내부 오류 |

---

## §10 지오펜스 (Geofences)

**Base URL**: `/api/v1/geofences` (목록·상세·수정·삭제·이벤트 기록)
**생성**: `POST /api/v1/groups/:group_id/geofences` (그룹 서브 리소스)

**인증**: 이 라우터에는 전역 `authenticate` 미들웨어가 없다. 컨트롤러 내부에서 `(req as any).userId || req.body.user_id`로 식별. 생성 시 그룹 멤버십 확인 (`groupService.checkMemberPermission`).

**데이터 저장소**: PostgreSQL `tb_geofence` (기본 데이터) + Firebase RTDB `realtime_geofences/{groupId}/{geofenceId}` (실시간 동기화). 수정/삭제 시 RTDB도 자동 동기화된다.

---

### 10.1 지오펜스 생성

#### [POST] /api/v1/groups/:group_id/geofences

**인증**: 선택적 (그룹 멤버십 검증 필수)
**설명**: 그룹에 신규 지오펜스를 생성한다. 생성 후 Firebase RTDB에 자동 동기화된다. `circle` 타입은 중심 좌표와 반경이 필수이며, `polygon` 타입은 좌표 배열이 필수이다.

**Path Parameters**

| 파라미터 | 타입 | 설명 |
|---------|------|------|
| `group_id` | string (UUID) | 그룹 ID |

**Request Body**

```json
{
  "name": "string",
  "description": "string | null",
  "type": "string",
  "shape_type": "string",
  "center_latitude": "number",
  "center_longitude": "number",
  "radius_meters": "integer | null",
  "polygon_coordinates": "array | null",
  "is_always_active": "boolean",
  "valid_from": "string (ISO 8601) | null",
  "valid_until": "string (ISO 8601) | null",
  "trigger_on_enter": "boolean",
  "trigger_on_exit": "boolean",
  "notify_group": "boolean",
  "notify_guardians": "boolean"
}
```

| 필드 | 타입 | 필수 | 설명 |
|------|------|:----:|------|
| `name` | string | ✅ | 지오펜스 이름 (trim 적용) |
| `type` | string | ✅ | 지오펜스 유형: `"safe"` \| `"watch"` \| `"danger"` |
| `shape_type` | string | ✅ | 형태: `"circle"` \| `"polygon"` |
| `center_latitude` | number | ✅ (circle) | 중심 위도 (-90 ~ 90) |
| `center_longitude` | number | ✅ (circle) | 중심 경도 (-180 ~ 180) |
| `radius_meters` | integer | ✅ (circle) | 반경 (미터) |
| `polygon_coordinates` | array | ✅ (polygon) | 다각형 꼭짓점 좌표 배열 |
| `description` | string \| null | - | 설명 |
| `is_always_active` | boolean | - | 항상 활성 여부 (기본값: `true`) |
| `valid_from` | string \| null | - | 유효 시작 시각 (ISO 8601 UTC, `::timestamptz` 캐스트) |
| `valid_until` | string \| null | - | 유효 종료 시각 (ISO 8601 UTC) |
| `trigger_on_enter` | boolean | - | 진입 시 트리거 여부 (기본값: `true`) |
| `trigger_on_exit` | boolean | - | 이탈 시 트리거 여부 (기본값: `true`) |
| `notify_group` | boolean | - | 그룹 알림 여부 (기본값: `false`) |
| `notify_guardians` | boolean | - | 가디언 알림 여부 (기본값: `false`) |
| `user_id` | string | 조건부 | 인증 토큰 미사용 시 필수. 요청자 Firebase UID |

**Response 201**
```json
{
  "success": true,
  "data": {
    "geofence_id": "string (UUID)"
  },
  "message": "Geofence created successfully"
}
```

**Error Codes**

| Code | 설명 |
|------|------|
| 400 | 요청자 식별 불가: `"user_id is required"` (토큰 없고 `user_id` 미전달 시) |
| 400 | `name`, `type`, `shape_type` 누락: `"name, type, and shape_type are required"` |
| 400 | circle 필수 필드 누락: `"center_latitude, center_longitude, and radius_meters are required for circle geofence"` |
| 400 | polygon 필수 필드 누락: `"polygon_coordinates is required for polygon geofence"` |
| 403 | 그룹 멤버 아님: `"Permission denied: not a member of this group"` |
| 500 | 서버 내부 오류 |

---

### 10.2 지오펜스 목록 조회

#### [GET] /api/v1/geofences

**인증**: 선택적
**설명**: 그룹의 활성 지오펜스 목록을 Firebase RTDB `realtime_geofences/{groupId}`에서 조회한다. `is_active = true`인 지오펜스만 포함한다.

**Query Parameters**

| 파라미터 | 타입 | 필수 | 설명 |
|---------|------|:----:|------|
| `group_id` | string (UUID) | ✅ | 그룹 ID |

**Response 200**
```json
{
  "success": true,
  "data": {
    "geofences": [
      {
        "geofence_id": "string (UUID)",
        "trip_id": "string (UUID) | null",
        "group_id": "string (UUID)",
        "name": "string",
        "description": "string | null",
        "type": "string",
        "shape_type": "string",
        "center_latitude": "number | null",
        "center_longitude": "number | null",
        "radius_meters": "integer | null",
        "polygon_coordinates": "array | null",
        "is_always_active": "boolean",
        "valid_from": "string (ISO 8601) | null",
        "valid_until": "string (ISO 8601) | null",
        "trigger_on_enter": "boolean",
        "trigger_on_exit": "boolean",
        "dwell_time_seconds": "integer",
        "notify_group": "boolean",
        "notify_guardians": "boolean",
        "is_active": "boolean"
      }
    ],
    "total": "integer"
  }
}
```

| 필드 | 타입 | 설명 |
|------|------|------|
| `type` | string | `"safe"` \| `"watch"` \| `"danger"` \| `"stationary"` |
| `shape_type` | string | `"circle"` \| `"polygon"` |
| `dwell_time_seconds` | integer | 체류 감지 시간 (초). 기본값 `60` |
| `polygon_coordinates` | array \| null | polygon 타입의 꼭짓점 좌표 배열. circle 타입은 `null` |

**Error Codes**

| Code | 설명 |
|------|------|
| 400 | `group_id` 누락: `"group_id is required"` |
| 500 | 서버 내부 오류 |

---

### 10.3 지오펜스 상세 조회

#### [GET] /api/v1/geofences/:id

**인증**: 선택적
**설명**: 특정 지오펜스를 PostgreSQL `tb_geofence`에서 직접 조회한다. `is_active = true`인 레코드만 반환하며, Firebase RTDB가 아닌 PostgreSQL이 기준이다.

**Path Parameters**

| 파라미터 | 타입 | 설명 |
|---------|------|------|
| `id` | string (UUID) | 지오펜스 ID |

**Query Parameters**

| 파라미터 | 타입 | 필수 | 설명 |
|---------|------|:----:|------|
| `group_id` | string (UUID) | ✅ | 그룹 ID (소유 확인용) |

**Response 200**

`§10.2` 지오펜스 객체와 동일한 구조의 단일 객체:

```json
{
  "success": true,
  "data": {
    "geofence_id": "string (UUID)",
    "trip_id": "string (UUID) | null",
    "group_id": "string (UUID)",
    "name": "string",
    "description": "string | null",
    "type": "string",
    "shape_type": "string",
    "center_latitude": "number | null",
    "center_longitude": "number | null",
    "radius_meters": "integer | null",
    "polygon_coordinates": "array | null",
    "is_always_active": "boolean",
    "valid_from": "string (ISO 8601) | null",
    "valid_until": "string (ISO 8601) | null",
    "trigger_on_enter": "boolean",
    "trigger_on_exit": "boolean",
    "dwell_time_seconds": "integer",
    "notify_group": "boolean",
    "notify_guardians": "boolean",
    "is_active": "boolean"
  }
}
```

**Error Codes**

| Code | 설명 |
|------|------|
| 400 | `geofence_id` 또는 `group_id` 누락 |
| 404 | 지오펜스 없음: `"Geofence not found"` |
| 500 | 서버 내부 오류 |

---

### 10.4 지오펜스 수정

#### [PATCH] /api/v1/geofences/:id

**인증**: 선택적
**설명**: 지오펜스 정보를 부분 수정한다 (지정된 필드만 동적으로 UPDATE). 수정 후 `is_active = true`이면 RTDB에 동기화하고, `is_active = false`이면 RTDB에서 삭제한다. 좌표는 범위 검증 적용.

**Path Parameters**

| 파라미터 | 타입 | 설명 |
|---------|------|------|
| `id` | string (UUID) | 지오펜스 ID |

**Query Parameters**

| 파라미터 | 타입 | 필수 | 설명 |
|---------|------|:----:|------|
| `group_id` | string (UUID) | ✅ | 그룹 ID (소유 확인용) |

**Request Body** (모든 필드 선택적)

```json
{
  "name": "string",
  "description": "string | null",
  "type": "string",
  "shape_type": "string",
  "center_latitude": "number",
  "center_longitude": "number",
  "radius_meters": "integer",
  "polygon_coordinates": "array | null",
  "is_always_active": "boolean",
  "valid_from": "string (ISO 8601) | null",
  "valid_until": "string (ISO 8601) | null",
  "trigger_on_enter": "boolean",
  "trigger_on_exit": "boolean",
  "notify_group": "boolean",
  "notify_guardians": "boolean",
  "is_active": "boolean"
}
```

**Response 200**
```json
{
  "success": true,
  "data": {
    "geofence_id": "string (UUID)",
    "message": "Geofence updated successfully"
  }
}
```

**Error Codes**

| Code | 설명 |
|------|------|
| 400 | `geofence_id` 또는 `group_id` 누락 |
| 400 | 좌표 범위 초과: `"Invalid center_latitude"` / `"Invalid center_longitude"` |
| 404 | 지오펜스 없음: `"Geofence not found"` |
| 500 | 서버 내부 오류 |

---

### 10.5 지오펜스 삭제

#### [DELETE] /api/v1/geofences/:id

**인증**: 선택적
**설명**: 지오펜스를 논리 삭제(`is_active = false`)하고 Firebase RTDB에서 해당 항목을 제거한다.

**Path Parameters**

| 파라미터 | 타입 | 설명 |
|---------|------|------|
| `id` | string (UUID) | 지오펜스 ID |

**Query Parameters**

| 파라미터 | 타입 | 필수 | 설명 |
|---------|------|:----:|------|
| `group_id` | string (UUID) | ✅ | 그룹 ID (소유 확인용) |

**Response 200**
```json
{
  "success": true,
  "data": {
    "geofence_id": "string (UUID)",
    "message": "Geofence deleted successfully"
  }
}
```

**Error Codes**

| Code | 설명 |
|------|------|
| 400 | `geofence_id` 또는 `group_id` 누락 |
| 404 | 지오펜스 없음: `"Geofence not found"` |
| 500 | 서버 내부 오류 |

---

### 10.6 지오펜스 이벤트 기록

#### [POST] /api/v1/geofences/events

**인증**: 불필요
**설명**: `flutter_background_geolocation` 플러그인이 자동으로 호출하는 엔드포인트. 기기가 지오펜스 경계를 진입(`ENTER`) 또는 이탈(`EXIT`)할 때 이 API를 통해 이벤트를 서버에 기록한다. `params.user_id`에서 사용자를 식별하며, 이벤트는 `tb_event_log`에 저장된다.

> **라우트 순서 주의**: `POST /events`와 `GET /:id`는 HTTP 메서드가 달라 NestJS가 독립적으로 매칭한다. 라우트 정의 순서와 무관하게 `POST /api/v1/geofences/events`는 정상적으로 라우팅된다.

**Request Body**

```json
{
  "geofence": {
    "identifier": "string (geofence_id)",
    "action": "string"
  },
  "location": {
    "coords": {
      "latitude": "number",
      "longitude": "number"
    },
    "uuid": "string"
  },
  "params": {
    "user_id": "string"
  }
}
```

| 필드 | 타입 | 필수 | 설명 |
|------|------|:----:|------|
| `geofence` | object | ✅ | 지오펜스 식별 정보 |
| `geofence.identifier` | string | ✅ | 지오펜스 ID (`tb_geofence.geofence_id`) |
| `geofence.action` | string | ✅ | `"ENTER"` 또는 `"EXIT"` |
| `location` | object | ✅ | 이벤트 발생 위치 |
| `location.coords.latitude` | number | ✅ | 이벤트 발생 위도 |
| `location.coords.longitude` | number | ✅ | 이벤트 발생 경도 |
| `params.user_id` | string | ✅ | 사용자 ID (`location.uuid`로 fallback) |

**Response 200**
```json
{
  "success": true,
  "data": {
    "message": "Geofence event recorded"
  }
}
```

**Error Codes**

| Code | 설명 |
|------|------|
| 400 | `geofence` 또는 `location` 누락: `"geofence and location are required"` |
| 400 | `user_id` 확인 불가: `"user_id is required"` |
| 500 | 서버 내부 오류 |

---



---

## §7 Trips, Guardians, Locations, Geofences


### Path: /api/v1/trips
#### [POST] /api/v1/trips
**Summary**: 여행 생성 (그룹+captain+채팅방 자동 생성)

#### [GET] /api/v1/trips
**Summary**: 내 여행 목록 조회


### Path: /api/v1/trips/{tripId}
#### [GET] /api/v1/trips/{tripId}
**Summary**: 여행 상세 조회
**Parameters**:
- tripId (path): string

#### [PATCH] /api/v1/trips/{tripId}
**Summary**: 여행 수정
**Parameters**:
- tripId (path): string


### Path: /api/v1/trips/preview/{code}
#### [GET] /api/v1/trips/preview/{code}
**Summary**: 초대 코드로 여행 미리보기
**Parameters**:
- code (path): string


### Path: /api/v1/trips/invite/{inviteCode}
#### [GET] /api/v1/trips/invite/{inviteCode}
**Summary**: 여행자용 초대 코드로 여행 정보 조회
**Parameters**:
- inviteCode (path): string


### Path: /api/v1/trips/verify-invite-code/{code}
#### [GET] /api/v1/trips/verify-invite-code/{code}
**Summary**: 초대 코드 유효성 검증
**Parameters**:
- code (path): string


### Path: /api/v1/trips/join
#### [POST] /api/v1/trips/join
**Summary**: 초대 코드로 그룹에 참여


### Path: /api/v1/trips/{tripId}/schedules
#### [GET] /api/v1/trips/{tripId}/schedules
**Summary**: 여행 일정 목록 조회
**Parameters**:
- tripId (path): string

#### [POST] /api/v1/trips/{tripId}/schedules
**Summary**: 일정 추가
**Parameters**:
- tripId (path): string


### Path: /api/v1/trips/{tripId}/schedules/items
#### [POST] /api/v1/trips/{tripId}/schedules/items
**Summary**: 일정 아이템 추가
**Parameters**:
- tripId (path): string


### Path: /api/v1/trips/{tripId}/invite
#### [POST] /api/v1/trips/{tripId}/invite
**Summary**: 여행 초대 생성
**Parameters**:
- tripId (path): string


### Path: /api/v1/trips/invite/accept
#### [POST] /api/v1/trips/invite/accept
**Summary**: 초대 수락


### Path: /api/v1/trips/guardian/request
#### [POST] /api/v1/trips/guardian/request
**Summary**: 가디언 승인 요청


### Path: /api/v1/trips/guardian/approval-status
#### [GET] /api/v1/trips/guardian/approval-status
**Summary**: 내 가디언 승인 상태 조회


### Path: /api/v1/trips/{tripId}/guardians
#### [POST] /api/v1/trips/{tripId}/guardians
**Summary**: 가디언 추가 (초대)
**Parameters**:
- tripId (path): string


### Path: /api/v1/trips/{tripId}/guardians/{linkId}/respond
#### [PATCH] /api/v1/trips/{tripId}/guardians/{linkId}/respond
**Summary**: 가디언 연결 수락/거절
**Parameters**:
- tripId (path): string
- linkId (path): string


### Path: /api/v1/trips/{tripId}/guardians/{linkId}
#### [DELETE] /api/v1/trips/{tripId}/guardians/{linkId}
**Summary**: 가디언 연결 취소/끊기
**Parameters**:
- tripId (path): string
- linkId (path): string


### Path: /api/v1/trips/{tripId}/guardians/me
#### [GET] /api/v1/trips/{tripId}/guardians/me
**Summary**: 나의 가디언 목록 조회 (여행자 시점)
**Parameters**:
- tripId (path): string


### Path: /api/v1/trips/{tripId}/guardians/pending
#### [GET] /api/v1/trips/{tripId}/guardians/pending
**Summary**: 대기 중인 가디언 초대 목록 조회 (가디언 시점)
**Parameters**:
- tripId (path): string


### Path: /api/v1/trips/{tripId}/guardians/linked-members
#### [GET] /api/v1/trips/{tripId}/guardians/linked-members
**Summary**: 연결된 멤버 목록 조회 (가디언 시점)
**Parameters**:
- tripId (path): string


### Path: /api/v1/trips/{tripId}/guardians/{linkId}/location-request
#### [POST] /api/v1/trips/{tripId}/guardians/{linkId}/location-request
**Summary**: 긴급 위치 요청 (시간당 3회 제한)
**Parameters**:
- linkId (path): string
- tripId (path): string


### Path: /api/v1/trips/{tripId}/guardians/location-request/{requestId}
#### [PATCH] /api/v1/trips/{tripId}/guardians/location-request/{requestId}
**Summary**: 위치 요청 응답
**Parameters**:
- requestId (path): string


### Path: /api/v1/trips/{tripId}/guardians/{linkId}/snapshots
#### [GET] /api/v1/trips/{tripId}/guardians/{linkId}/snapshots
**Summary**: 30분 스냅샷 목록
**Parameters**:
- linkId (path): string


### Path: /api/v1/trips/{tripId}/locations/batch
#### [POST] /api/v1/trips/{tripId}/locations/batch
**Summary**: 9.A.1 위치 데이터 저장 (단건/다건 배치)
**Parameters**:
- tripId (path): string


### Path: /api/v1/trips/{tripId}/locations
#### [GET] /api/v1/trips/{tripId}/locations
**Summary**: 9.A.2 특정 멤버의 위치 이력 조회
**Parameters**:
- tripId (path): string
- user_id (query): string
- start_time (query): string
- end_time (query): string


### Path: /api/v1/trips/{tripId}/locations/latest
#### [GET] /api/v1/trips/{tripId}/locations/latest
**Summary**: 9.A.3 그룹 멤버 최신 위치 조회
**Parameters**:
- tripId (path): string


### Path: /api/v1/trips/{tripId}/locations/sharing-settings
#### [GET] /api/v1/trips/{tripId}/locations/sharing-settings
**Summary**: 9.A.4 내 위치 공유 설정 조회
**Parameters**:
- tripId (path): string

#### [PATCH] /api/v1/trips/{tripId}/locations/sharing-settings
**Summary**: 9.A.5 내 위치 공유 설정 변경
**Parameters**:
- tripId (path): string


### Path: /api/v1/trips/{tripId}/locations/schedules
#### [POST] /api/v1/trips/{tripId}/locations/schedules
**Summary**: 일정 기반 공유 스케줄 설정
**Parameters**:
- tripId (path): string


### Path: /api/v1/trips/{tripId}/locations/stay-points
#### [GET] /api/v1/trips/{tripId}/locations/stay-points
**Summary**: 체류 지점 조회
**Parameters**:
- tripId (path): string


### Path: /api/v1/api/v1/locations/users/{userId}/movement-sessions/summary
#### [GET] /api/v1/api/v1/locations/users/{userId}/movement-sessions/summary
**Summary**: 9.4 이동 세션 요약 목록 조회
**Parameters**:
- userId (path): string
- need_images (query): string
- target_date (query): string


### Path: /api/v1/api/v1/locations/users/{userId}/movement-sessions/date-range
#### [GET] /api/v1/api/v1/locations/users/{userId}/movement-sessions/date-range
**Summary**: 9.5 이동 세션 날짜 범위 조회
**Parameters**:
- userId (path): string


### Path: /api/v1/api/v1/locations/users/{userId}/movement-sessions/by-date
#### [GET] /api/v1/api/v1/locations/users/{userId}/movement-sessions/by-date
**Summary**: 9.6 날짜별 이동 세션 목록 조회
**Parameters**:
- userId (path): string
- date (query): string
- need_images (query): string


### Path: /api/v1/api/v1/locations/users/{userId}/movement-sessions/{sessionId}
#### [GET] /api/v1/api/v1/locations/users/{userId}/movement-sessions/{sessionId}
**Summary**: 9.7 이동 세션 상세 조회
**Parameters**:
- userId (path): string
- sessionId (path): string


### Path: /api/v1/api/v1/locations/users/{userId}/movement-sessions/{sessionId}/complete
#### [PATCH] /api/v1/api/v1/locations/users/{userId}/movement-sessions/{sessionId}/complete
**Summary**: 9.8 이동 세션 완료 처리
**Parameters**:
- userId (path): string
- sessionId (path): string


### Path: /api/v1/api/v1/locations/users/{userId}/movement-sessions/{sessionId}/events
#### [GET] /api/v1/api/v1/locations/users/{userId}/movement-sessions/{sessionId}/events
**Summary**: 9.9 이동 세션 이벤트 목록 조회
**Parameters**:
- userId (path): string
- sessionId (path): string


### Path: /api/v1/api/v1/groups/{group_id}/geofences
#### [POST] /api/v1/api/v1/groups/{group_id}/geofences
**Summary**: 10.1 지오펜스 생성 (그룹 멤버 등재 확인, 권한 확인 생략)
**Parameters**:
- group_id (path): string


### Path: /api/v1/api/v1/geofences
#### [GET] /api/v1/api/v1/geofences
**Summary**: 10.2 지오펜스 목록 조회
**Parameters**:
- group_id (query): string


### Path: /api/v1/api/v1/geofences/{id}
#### [GET] /api/v1/api/v1/geofences/{id}
**Summary**: 10.3 지오펜스 상세 조회
**Parameters**:
- id (path): string
- group_id (query): string

#### [PATCH] /api/v1/api/v1/geofences/{id}
**Summary**: 10.4 지오펜스 수정
**Parameters**:
- id (path): string
- group_id (query): string

#### [DELETE] /api/v1/api/v1/geofences/{id}
**Summary**: 10.5 지오펜스 삭제
**Parameters**:
- id (path): string
- group_id (query): string


### Path: /api/v1/api/v1/geofences/events
#### [POST] /api/v1/api/v1/geofences/events
**Summary**: 10.6 지오펜스 이벤트 기록


