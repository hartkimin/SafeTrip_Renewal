# SafeTrip Backend API 명세서 — Admin Endpoints Addendum

| 항목 | 내용 |
|------|------|
| **문서 ID** | `DOC-T2-API-039` |
| **상위 인덱스** | [35_T2_API_명세서.md](./35_T2_API_명세서.md) |
| **범위** | Admin/Backoffice 전용 엔드포인트 |
| **버전** | v1.0 |
| **작성일** | 2026-03-05 |

> 본 문서는 백오피스(Backoffice) 관리자 전용 API 엔드포인트를 정의한다.
> 모든 Admin 엔드포인트는 인증(Firebase ID Token 또는 bypass 헤더)이 필요하다.

---

## §A1. 사용자 관리 (Users Admin)

> **기본 경로**: `/api/v1/users`

---

#### [GET] /api/v1/users/admin/list

**인증**: 필요  
**설명**: 전체 사용자 목록을 페이지네이션으로 조회한다.

**Query Parameters**

| 파라미터 | 타입 | 필수 | 기본값 | 설명 |
|---------|------|:----:|:------:|------|
| `page` | string | ✗ | `1` | 페이지 번호 |
| `limit` | string | ✗ | `20` | 페이지 당 항목 수 |
| `status` | string | ✗ | — | `banned` 등 필터 |

**Response 200**
```json
{
  "success": true,
  "data": [
    {
      "user_id": "string",
      "display_name": "string",
      "phone_number": "string",
      "created_at": "string (ISO 8601)",
      "last_active_at": "string (ISO 8601)",
      "trip_count": "number"
    }
  ],
  "total": "number",
  "page": "number",
  "limit": "number",
  "totalPages": "number"
}
```

---

#### [GET] /api/v1/users/admin/stats

**인증**: 필요  
**설명**: 사용자 통계 (총 사용자 수, 오늘 가입 수 등)를 반환한다.

**Response 200**
```json
{
  "success": true,
  "data": {
    "total": "number",
    "activeToday": "number",
    "newToday": "number"
  }
}
```

---

#### [POST] /api/v1/users/:userId/ban

**인증**: 필요  
**설명**: 사용자를 차단(ban) 또는 차단 해제한다.

**Path Parameters**

| 파라미터 | 타입 | 설명 |
|---------|------|------|
| `userId` | string | 대상 사용자의 Firebase UID |

**Request Body**
```json
{
  "reason": "string",
  "isBanned": "boolean"
}
```

**Response 200**
```json
{
  "success": true,
  "message": "string",
  "reason": "string"
}
```

---

## §A2. 여행 관리 (Trips Admin)

> **기본 경로**: `/api/v1/trips`

---

#### [GET] /api/v1/trips/admin/list

**인증**: 필요  
**설명**: 전체 여행 목록을 페이지네이션으로 조회한다.

**Query Parameters**

| 파라미터 | 타입 | 필수 | 기본값 | 설명 |
|---------|------|:----:|:------:|------|
| `page` | string | ✗ | `1` | 페이지 번호 |
| `limit` | string | ✗ | `20` | 페이지 당 항목 수 |

**Response 200**
```json
{
  "success": true,
  "data": [/* Trip objects */],
  "total": "number",
  "page": "number",
  "limit": "number",
  "totalPages": "number"
}
```

---

#### [GET] /api/v1/trips/admin/stats

**인증**: 필요  
**설명**: 여행 통계 (총 여행 수, 활성 여행, 오늘 생성 수)를 반환한다.

**Response 200**
```json
{
  "success": true,
  "data": {
    "total": "number",
    "active": "number",
    "createdToday": "number"
  }
}
```

---

## §A3. 긴급 SOS 관리 (Emergencies Admin)

> **기본 경로**: `/api/v1/emergencies`

---

#### [GET] /api/v1/emergencies  (Admin 모드)

**인증**: 필요  
**설명**: 전체 긴급 SOS 목록을 페이지네이션으로 조회한다. `status` 필터 지원.

**Query Parameters**

| 파라미터 | 타입 | 필수 | 기본값 | 설명 |
|---------|------|:----:|:------:|------|
| `status` | string | ✗ | — | `active`, `resolved` 등 |
| `page` | string | ✗ | `1` | 페이지 번호 |
| `limit` | string | ✗ | `20` | 페이지 당 항목 수 |

**Response 200**
```json
{
  "success": true,
  "data": [/* Emergency objects */],
  "total": "number",
  "page": "number",
  "limit": "number",
  "totalPages": "number"
}
```

---

#### [GET] /api/v1/emergencies/stats

**인증**: 필요  
**설명**: 긴급 SOS 통계를 반환한다.

**Response 200**
```json
{
  "success": true,
  "data": {
    "total": "number",
    "active": "number",
    "resolved": "number",
    "false_alarm": "number"
  }
}
```

---

## §A4. 결제 관리 (Payments Admin)

> **기본 경로**: `/api/v1/payments`

---

#### [GET] /api/v1/payments/admin/transactions

**인증**: 필요  
**설명**: 전체 결제 이력을 페이지네이션으로 조회한다.

**Query Parameters**

| 파라미터 | 타입 | 필수 | 기본값 | 설명 |
|---------|------|:----:|:------:|------|
| `page` | string | ✗ | `1` | 페이지 번호 |
| `limit` | string | ✗ | `20` | 페이지 당 항목 수 |
| `status` | string | ✗ | — | `completed`, `pending` 등 |

**Response 200**
```json
{
  "success": true,
  "data": [/* Payment objects */],
  "total": "number",
  "page": "number",
  "limit": "number",
  "totalPages": "number"
}
```

---

#### [GET] /api/v1/payments/admin/stats

**인증**: 필요  
**설명**: 결제 통계 (총 거래 수, 완료/대기 수, 총 매출)를 반환한다.

**Response 200**
```json
{
  "success": true,
  "data": {
    "total": "number",
    "completed": "number",
    "pending": "number",
    "totalRevenue": "number"
  }
}
```

---

## §A5. 이벤트 로그 (Event Log)

> **기본 경로**: `/api/v1/events`

#### [GET] /api/v1/events

**인증**: 불필요 (Public)  
**설명**: 이벤트 로그를 조회한다. 감사 로그(Audit Log) 용도.

**Query Parameters**

| 파라미터 | 타입 | 필수 | 기본값 | 설명 |
|---------|------|:----:|:------:|------|
| `user_id` | string | ✗ | — | 특정 사용자 이벤트 필터 |
| `group_id` | string | ✗ | — | 특정 그룹 이벤트 필터 |
| `event_type` | string | ✗ | — | 이벤트 유형 필터 |
| `event_subtype` | string | ✗ | — | 이벤트 하위 유형 필터 |
| `since` | string | ✗ | — | ISO 8601 이후 이벤트만 |
| `limit` | string | ✗ | `100` | 최대 반환 건수 |
| `offset` | string | ✗ | `0` | 오프셋 |

**Response 200**
```json
{
  "success": true,
  "data": {
    "events": [
      {
        "event_id": "string (UUID)",
        "user_id": "string",
        "group_id": "string | null",
        "event_type": "string",
        "event_subtype": "string | null",
        "latitude": "number | null",
        "longitude": "number | null",
        "address": "string | null",
        "battery_level": "number | null",
        "occurred_at": "string (ISO 8601)",
        "created_at": "string (ISO 8601)"
      }
    ],
    "count": "number"
  }
}
```

---

## §A6. B2B 파트너 관리 (B2B Admin)

> **기본 경로**: `/api/v1/b2b`

---

#### [GET] /api/v1/b2b/organizations

**인증**: 필요  
**설명**: 전체 B2B 조직 목록을 조회한다.

**Response 200**
```json
{
  "success": true,
  "data": [
    {
      "orgId": "string (UUID)",
      "orgName": "string",
      "orgType": "school | corporate | agency | government",
      "businessNumber": "string | null",
      "contactName": "string | null",
      "contactEmail": "string | null",
      "contactPhone": "string | null",
      "isActive": "boolean",
      "createdAt": "string (ISO 8601)"
    }
  ],
  "total": "number"
}
```

---

#### [GET] /api/v1/b2b/organizations/:orgId

**인증**: 필요  
**설명**: B2B 조직 상세 정보를 조회한다.

**Path Parameters**

| 파라미터 | 타입 | 설명 |
|---------|------|------|
| `orgId` | string (UUID) | 조직 ID |

**Response 200**
```json
{
  "orgId": "string (UUID)",
  "orgName": "string",
  "orgType": "string",
  "businessNumber": "string | null",
  "contactName": "string | null",
  "contactEmail": "string | null",
  "contactPhone": "string | null",
  "isActive": "boolean",
  "createdAt": "string (ISO 8601)"
}
```

---

#### [GET] /api/v1/b2b/organizations/:orgId/contracts

**인증**: 필요  
**설명**: 해당 조직의 계약 목록을 조회한다.

**Response 200**
```json
[
  {
    "contractId": "string (UUID)",
    "contractCode": "string",
    "contractType": "school | corporate | travel_agency | insurance",
    "companyName": "string",
    "status": "active | suspended | expired",
    "maxTrips": "number | null",
    "slaLevel": "standard | premium | enterprise",
    "startedAt": "string (date)",
    "expiresAt": "string (date)",
    "createdAt": "string (ISO 8601)"
  }
]
```

---

#### [GET] /api/v1/b2b/organizations/:orgId/admins

**인증**: 필요  
**설명**: 해당 조직의 관리자 목록을 조회한다.

**Response 200**
```json
[
  {
    "adminId": "string (UUID)",
    "orgId": "string (UUID)",
    "userId": "string",
    "adminRole": "org_admin | trip_manager | viewer",
    "isActive": "boolean",
    "createdAt": "string (ISO 8601)"
  }
]
```

---

#### [GET] /api/v1/b2b/organizations/:orgId/dashboard-config

**인증**: 필요  
**설명**: 조직의 대시보드 설정을 조회한다.

#### [POST] /api/v1/b2b/organizations/:orgId/dashboard-config

**인증**: 필요  
**설명**: 조직의 대시보드 설정을 저장/수정한다.

**Request Body**
```json
{
  "key": "string",
  "value": "any (JSON)",
  "contractId": "string (UUID, optional)"
}
```
