# SafeTrip Backend API 명세서 — Part 3 (§11~§18)

| 항목 | 내용 |
|------|------|
| **문서 ID** | `DOC-T2-API-038` |
| **상위 인덱스** | [35_T2_API_명세서.md](./35_T2_API_명세서.md) |
| **범위** | §11 이동기록 / §12 FCM / §13 안전가이드 / §14 리더십 / §15 국가·이벤트·위치공유 / §16 공통타입 / §17~§18 이력·참조 |
| **버전** | v1.0 |
| **작성일** | 2026-03-02 |

> Part 1: [36_T2_API_명세서_Part1.md](./36_T2_API_명세서_Part1.md) | Part 2: [37_T2_API_명세서_Part2.md](./37_T2_API_명세서_Part2.md)

---

## §11 이동기록 (Movement Records)

**비고**: 독립적인 `movement-records.controller.ts` 및 `movement-records.routes.ts` 파일은 존재하지 않는다. 이동 세션 관련 엔드포인트 전체는 `§9 위치 (Locations)` 컨트롤러(`locations.controller.ts`)와 라우터(`locations.routes.ts`)에 통합되어 있다.

이동 세션 API는 다음 두 계층으로 구성된다.

### 11.1 이동 세션 데이터 모델 요약

이동 세션은 별도의 테이블이 아니라 `tb_location.movement_session_id` 컬럼 기준으로 `tb_location` 레코드를 그룹화하여 도출된다. 클라이언트가 세션 시작 시 UUID를 생성하여 `movement_session_id` 필드에 포함해 위치를 저장하면, 서버는 이 UUID를 기반으로 세션을 집계한다.

| 항목 | 내용 |
|------|------|
| 세션 ID 출처 | 클라이언트 생성 UUID, `POST /api/v1/locations` body의 `movement_session_id` |
| 세션 시작 신호 | `is_movement_start: true` 포함 위치 저장 |
| 세션 종료 신호 | `is_movement_end: true` 포함 위치 저장 또는 `PATCH .../complete` 호출 |
| 활성 세션 추적 | Firebase RTDB `realtime_users/{userId}/active_session_id` |
| 세션 유효 조건 | 종료된 세션은 위치 포인트 10개 이상이어야 요약 목록에 포함 |
| 거리 계산 | PostGIS `ST_Length(ST_MakeLine(geom ORDER BY recorded_at ASC)::geography) / 1000.0` |
| 이동 수단 분류 | `activity_type = 'in_vehicle'` 이 1건 이상이면 `"vehicle"`, 아니면 `"walking"` |

### 11.2 이동 세션 API 엔드포인트 인덱스

이동 세션 관련 모든 엔드포인트는 `§9`에 통합 문서화되어 있다. 아래 표는 참조용 인덱스이다.

| 메서드 | 경로 | §9 섹션 | 설명 |
|--------|------|---------|------|
| `POST` | `/api/v1/locations` | §9.1 | 위치 저장 (세션 포함) |
| `GET` | `/api/v1/locations/users/:userId/movement-sessions/summary` | §9.4 | 세션 요약 목록 (페이지네이션) |
| `GET` | `/api/v1/locations/users/:userId/movement-sessions/date-range` | §9.5 | 세션 날짜 범위 |
| `GET` | `/api/v1/locations/users/:userId/movement-sessions/by-date` | §9.6 | 날짜별 세션 목록 |
| `GET` | `/api/v1/locations/users/:userId/movement-sessions/:sessionId` | §9.7 | 세션 상세 (전체 좌표) |
| `PATCH` | `/api/v1/locations/users/:userId/movement-sessions/:sessionId/complete` | §9.8 | 세션 완료 처리 (스텁) |
| `GET` | `/api/v1/locations/users/:userId/movement-sessions/:sessionId/events` | §9.9 | 세션 이벤트 목록 |

### 11.3 세션 상태 흐름

```
[클라이언트 UUID 생성]
        |
        v
POST /locations  (is_movement_start: true, movement_session_id: <uuid>)
        |
        v
[위치 업데이트 반복]
POST /locations  (movement_session_id: <uuid>)
        |
        v
POST /locations  (is_movement_end: true, movement_session_id: <uuid>)
   또는
PATCH .../complete  (latitude, longitude, recorded_at)
        |
        v
[세션 종료 — RTDB active_session_id 제거]
```

> **주의**: `PATCH .../complete` 엔드포인트는 현재 호환성 유지용 스텁으로, 실제 DB 상태를 변경하지 않는다 (`§9.8` 참조). 세션 완료 여부의 실질적 판단은 클라이언트와 RTDB `active_session_id` 기반으로 이루어진다.

---

## §12 FCM 토큰 (Push Notification Tokens)

FCM(Firebase Cloud Messaging) 디바이스 토큰 관리 및 푸시 알림 발송 API.
토큰은 `tb_device_token` 테이블에 저장되며, 비활성화 시 `is_active = FALSE` 소프트 삭제를 적용한다.

> **구현 분포**: FCM 토큰 등록·삭제 엔드포인트는 `users.controller.ts` / `users.routes.ts`에 구현되어 있다. 알림 발송 엔드포인트는 `fcm.controller.ts` / `fcm.routes.ts`에 분리되어 있다.

### 12.1 FCM 토큰 등록 (테스트용 — 인증 불필요)

#### [PUT] /api/v1/users/:userId/fcm-token

**인증**: 불필요 (테스트 목적, 인증 미들웨어 미적용)
**설명**: 특정 사용자의 FCM 디바이스 토큰을 등록하거나 갱신한다. 해당 사용자의 활성 토큰이 이미 존재하면 덮어쓰기(UPDATE), 없으면 신규 삽입(INSERT)한다.

**Path Parameters**

| 파라미터 | 타입 | 설명 |
|---------|------|------|
| `userId` | string (UUID) | 사용자 ID |

**Request Body**

```json
{
  "device_token": "string",
  "platform": "string",
  "device_id": "string | null",
  "device_model": "string | null",
  "os_version": "string | null",
  "app_version": "string | null"
}
```

| 필드 | 타입 | 필수 | 설명 |
|------|------|:----:|------|
| `device_token` | string | ✅ | Firebase FCM 등록 토큰 |
| `platform` | string | ✅ | 플랫폼 식별자. `"android"` 또는 `"ios"` |
| `device_id` | string | ❌ | 기기 고유 식별자 |
| `device_model` | string | ❌ | 기기 모델명 (예: `"Pixel 7"`) |
| `os_version` | string | ❌ | OS 버전 (예: `"Android 14"`) |
| `app_version` | string | ❌ | 앱 버전 (예: `"1.0.0"`) |

**Response 200**
```json
{
  "success": true,
  "data": {
    "token_id": "string (UUID)",
    "is_new": "boolean",
    "last_used_at": "string (ISO 8601)"
  }
}
```

| 필드 | 설명 |
|------|------|
| `is_new` | `true`: 신규 삽입, `false`: 기존 토큰 갱신 |
| `last_used_at` | 토큰 마지막 사용 시각 |

**Error Codes**

| Code | 설명 |
|------|------|
| 400 | `device_token` 또는 `platform` 누락: `"device_token and platform are required"` |
| 404 | 사용자 없음: `"User not found: {userId}"` |
| 500 | 서버 내부 오류 |

---

### 12.2 FCM 토큰 등록 (인증 필요)

#### [PUT] /api/v1/users/me/fcm-token

**인증**: 필요 (`authenticate` 미들웨어)
**설명**: 인증된 사용자(me) 의 FCM 토큰을 등록 또는 갱신한다. 동작 방식은 §12.1과 동일하며, `userId`는 JWT 토큰에서 추출한다.

> **⚠️ 라우트 순서 버그**: `users.routes.ts`에서 `PUT /:userId/fcm-token`이 `authenticate` 미들웨어 **이전**에 등록되어 있어, `/me/fcm-token` 요청이 `/:userId` 패턴에 먼저 매칭된다. 실제로 이 엔드포인트는 인증 없이 §12.1 핸들러(`registerFcmTokenForUser`)가 처리하며, `userId = "me"` 문자열로 DB 조회가 시도된다. 정상 동작을 위해 라우트 순서 수정이 필요하다.

**Request Body**: §12.1 Request Body와 동일

**Response 200**: §12.1 Response 200과 동일

**Error Codes**

| Code | 설명 |
|------|------|
| 401 | 인증 토큰 없음 또는 유효하지 않음 |
| 400 | `device_token` 또는 `platform` 누락 |
| 404 | 사용자 없음 |
| 500 | 서버 내부 오류 |

---

### 12.3 FCM 토큰 삭제 (소프트 삭제)

#### [DELETE] /api/v1/users/me/fcm-token/:tokenId

**인증**: 필요 (`authenticate` 미들웨어)
**설명**: 인증된 사용자의 특정 FCM 토큰을 비활성화(`is_active = FALSE`)한다. 레코드는 삭제되지 않으며, `tb_device_token.is_active` 플래그만 변경된다.

**Path Parameters**

| 파라미터 | 타입 | 설명 |
|---------|------|------|
| `tokenId` | string (UUID) | 삭제할 FCM 토큰 ID (`tb_device_token.token_id`) |

**Response 200**
```json
{
  "success": true,
  "data": {
    "message": "FCM token deleted successfully"
  }
}
```

**Error Codes**

| Code | 설명 |
|------|------|
| 401 | 인증 토큰 없음 또는 유효하지 않음 |
| 500 | 서버 내부 오류 |

---

### 12.4 FCM 푸시 알림 발송

#### [POST] /api/v1/fcm/travelers/:travelerId/notify

**인증**: ⚠️ 불필요 (테스트용 — `fcm.routes.ts`의 `authenticate` 미들웨어가 주석 처리되어 있음)
**설명**: 특정 여행자의 모든 활성 FCM 토큰(`is_active = TRUE`)으로 푸시 알림을 발송한다. FCM `sendEachForMulticast`를 사용하며, Android는 `high` 우선순위, iOS(APNs)는 `apns-priority: 10`으로 전송한다.

**Path Parameters**

| 파라미터 | 타입 | 설명 |
|---------|------|------|
| `travelerId` | string (UUID) | 알림을 받을 여행자의 사용자 ID |

**Request Body**

```json
{
  "title": "string",
  "body": "string",
  "data": "object | null"
}
```

| 필드 | 타입 | 필수 | 설명 |
|------|------|:----:|------|
| `title` | string | ✅ | 알림 제목 |
| `body` | string | ✅ | 알림 본문 |
| `data` | object | ❌ | 추가 데이터 페이로드 (key-value 맵) |

**Response 200**
```json
{
  "success": true,
  "data": {
    "fcm_sent": "boolean",
    "device_token_count": "integer",
    "success_count": "integer",
    "failure_count": "integer",
    "sent_at": "string (ISO 8601)"
  }
}
```

| 필드 | 설명 |
|------|------|
| `fcm_sent` | `failure_count === 0`이면 `true`, 1건 이상 실패 시 `false` |
| `device_token_count` | 발송 시도한 디바이스 토큰 수 |
| `success_count` | 발송 성공 토큰 수 |
| `failure_count` | 발송 실패 토큰 수 |

**Error Codes**

| Code | 설명 |
|------|------|
| 400 | `title` 또는 `body` 누락: `"title and body are required"` |
| 500 | 활성 FCM 토큰 없음: `"No active FCM tokens found for traveler"` — ⚠️ 의미상 404이나 코드가 500 반환 (버그) |
| 500 | Firebase 미초기화: `"Firebase not initialized"` |
| 500 | FCM 발송 오류 |

---

## §13 안전가이드 (Travel Guides & MOFA)

여행 안전 가이드 및 외교부(MOFA) 공공데이터 API 프록시.
가이드 데이터(`guides.*`)는 `tb_country.travel_guide_data` JSONB 컬럼을 직접 조회하며, MOFA 데이터(`mofa.*`)는 외교부 공공데이터 포털(`apis.data.go.kr/1262000`)을 서버에서 프록시한다.

### §13-A 안전가이드 (내부 DB 기반)

> 라우터: `guides.routes.ts`, 컨트롤러: `guides.controller.ts`, 서비스: `guide.service.ts`
> 데이터 출처: `TB_COUNTRY.travel_guide_data` (JSONB), `TB_MOFA_RISK`

---

### 13.1 국가별 가이드 조회

#### [GET] /api/v1/guides/:countryCode

**인증**: 불필요
**설명**: 국가 코드로 `TB_COUNTRY`의 여행 가이드 JSONB 데이터를 조회하고, `TB_MOFA_RISK`에서 현재 유효한(`is_current = TRUE`) 위험 정보를 함께 반환한다.

**Path Parameters**

| 파라미터 | 타입 | 설명 |
|---------|------|------|
| `countryCode` | string | ISO 3166-1 alpha-2 국가 코드 (예: `"TH"`, `"JP"`) — 대소문자 무관 |

**Response 200**
```json
{
  "success": true,
  "data": {
    "country_code": "string",
    "country_name_ko": "string | null",
    "travel_guide_data": {
      "country_info": "object | null",
      "emergency_contacts": "object | null",
      "travel_alert": "object | null",
      "safety_incidents": "object | null",
      "entry_exit": "object | null",
      "cultural_safety": "object | null",
      "transportation": "object | null",
      "health_medical": "object | null",
      "additional_safety": "object | null",
      "ui_config": {
        "sections": "string[]",
        "custom_sections": "string[]",
        "custom_page": "string | null"
      }
    },
    "mofa_risk": {
      "risk_level": "string",
      "risk_description": "string | null",
      "special_alerts": "object | null",
      "is_current": "boolean"
    },
    "last_updated": "string (ISO 8601) | null"
  }
}
```

> `mofa_risk` 필드는 `TB_MOFA_RISK`에 해당 국가의 유효한 레코드가 없으면 응답에 포함되지 않는다(`undefined`).

**Error Codes**

| Code | 설명 |
|------|------|
| 400 | `countryCode` 누락 |
| 404 | 해당 국가 가이드 없음: `"Guide not found for the specified country"` |
| 500 | 서버 내부 오류 |

---

### 13.2 가이드 검색

#### [GET] /api/v1/guides/search

**인증**: 불필요
**설명**: `travel_guide_data` JSONB 전체를 대소문자 무관(`ILIKE`) 전문 검색한다. 매칭된 섹션 이름 목록과 스니펫(전후 50자)을 반환한다.

**Query Parameters**

| 파라미터 | 타입 | 필수 | 설명 |
|---------|------|:----:|------|
| `q` | string | ✅ | 검색어 |
| `country` | string | ❌ | 국가 코드 필터 (ISO alpha-2). 지정 시 해당 국가만 검색 |

**Response 200**
```json
{
  "success": true,
  "data": {
    "query": "string",
    "country": "string | null",
    "results": [
      {
        "country_code": "string",
        "country_name_ko": "string | null",
        "matched_sections": ["string"],
        "snippet": "string"
      }
    ],
    "count": "integer"
  }
}
```

| 필드 | 설명 |
|------|------|
| `matched_sections` | 검색어가 포함된 섹션 이름 배열. 가능한 값: `"country_info"`, `"emergency_contacts"`, `"travel_alert"`, `"safety_incidents"`, `"entry_exit"`, `"cultural_safety"`, `"transportation"`, `"health_medical"`, `"additional_safety"` |
| `snippet` | 첫 번째 매칭 섹션에서 검색어 전후 50자를 추출한 문자열 |

**Error Codes**

| Code | 설명 |
|------|------|
| 400 | `q` 파라미터 누락: `"Query parameter (q) is required"` |
| 500 | 서버 내부 오류 |

---

### 13.3 긴급 연락처 조회

#### [GET] /api/v1/guides/:countryCode/emergency

**인증**: 불필요
**설명**: `TB_COUNTRY.travel_guide_data->'emergency_contacts'` JSONB 필드를 직접 추출하여 반환한다. 한국 대사관 정보, 영사콜센터, 현지 긴급 번호를 포함한다.

**Path Parameters**

| 파라미터 | 타입 | 설명 |
|---------|------|------|
| `countryCode` | string | ISO alpha-2 국가 코드 |

**Response 200**
```json
{
  "success": true,
  "data": {
    "korean_embassy": {
      "name": "string",
      "phone": "string",
      "emergency_24h": "string",
      "address": "string",
      "email": "string | null",
      "website": "string | null",
      "working_hours": "string | null"
    },
    "consular_call_center": {
      "seoul_24h": "string",
      "description": "string"
    },
    "local_emergency": {
      "police": "string",
      "fire": "string",
      "ambulance": "string",
      "tourist_police": "string | null"
    }
  }
}
```

> 각 객체(`korean_embassy`, `consular_call_center`, `local_emergency`)는 해당 데이터가 없으면 `null`로 반환된다.

**Error Codes**

| Code | 설명 |
|------|------|
| 400 | `countryCode` 누락 |
| 404 | 해당 국가 없음 또는 긴급 연락처 미등록: `"Emergency contacts not found for the specified country"` |
| 500 | 서버 내부 오류 |

---

### §13-B 외교부 MOFA 공공데이터 (외부 API 프록시)

> 라우터: `mofa.routes.ts`, 컨트롤러: `mofa.controller.ts`, 서비스: `mofa-api.service.ts`
> 데이터 출처: 외교부 공공데이터 포털 (`https://apis.data.go.kr/1262000`)
> **캐싱**: 인메모리 캐시 적용. 여행경보·안전공지·사건사고: 30분 TTL, 국기: 7일 TTL, 나머지: 6~24시간 TTL.
> **국가 코드 유효성**: 모든 MOFA 엔드포인트에서 `countryCode`는 정확히 2자리 ISO alpha-2 코드여야 한다.

---

### 13.4 국가 종합 요약 (MOFA)

#### [GET] /api/v1/mofa/country/:countryCode/summary

**인증**: 불필요
**설명**: 여행경보(`TravelAlarmService2`), 국가 기본정보(`CountryBasicService`, XML), 일반사항(`OverviewGnrlInfoService`), 국기(`CountryFlagService2`) 4개 외교부 API를 병렬 호출하여 통합 반환한다.

**Path Parameters**

| 파라미터 | 타입 | 설명 |
|---------|------|------|
| `countryCode` | string | ISO alpha-2 국가 코드 (정확히 2자리) |

**Response 200**
```json
{
  "success": true,
  "data": {
    "country_code": "string",
    "travel_alarm": "array",
    "country_basic": {
      "items": "array",
      "totalCount": "integer"
    },
    "overview_info": {
      "items": "array",
      "totalCount": "integer"
    },
    "country_flag": "object | null"
  }
}
```

> 외부 API 호출 실패 시 해당 필드는 빈 배열(`[]`), 빈 결과 객체(`{ items: [], totalCount: 0 }`), 또는 `null`로 대체되며 전체 요청은 성공한다.

**Error Codes**

| Code | 설명 |
|------|------|
| 400 | `countryCode`가 없거나 2자리가 아님: `"Valid 2-letter country code is required"` |
| 500 | 서버 내부 오류 |

---

### 13.5 국가 안전 정보 (MOFA)

#### [GET] /api/v1/mofa/country/:countryCode/safety

**인증**: 불필요
**설명**: 국가별 안전공지(`CountrySafetyService6`), 사건사고 유형(`CountryAccidentService2`), 치안환경(`SecurityEnvironmentService`) 3개 API를 병렬 호출한다.

**Path Parameters**: §13.4와 동일

**Response 200**
```json
{
  "success": true,
  "data": {
    "country_code": "string",
    "safety_notices": {
      "items": "array",
      "totalCount": "integer"
    },
    "accidents": {
      "items": "array",
      "totalCount": "integer"
    },
    "security_env": {
      "items": "array",
      "totalCount": "integer"
    }
  }
}
```

**Error Codes**: §13.4와 동일

---

### 13.6 국가 입국 정보 (MOFA)

#### [GET] /api/v1/mofa/country/:countryCode/entry

**인증**: 불필요
**설명**: 입국허가요건·비자 정보(`EntranceVisaService2`)를 반환한다.

**Path Parameters**: §13.4와 동일

**Response 200**
```json
{
  "success": true,
  "data": {
    "country_code": "string",
    "entrance_visa": {
      "items": "array",
      "totalCount": "integer"
    }
  }
}
```

**Error Codes**: §13.4와 동일

---

### 13.7 국가 의료 정보 (MOFA)

#### [GET] /api/v1/mofa/country/:countryCode/medical

**인증**: 불필요
**설명**: 의료환경 정보(`MedicalEnvironmentService`)를 반환한다.

**Path Parameters**: §13.4와 동일

**Response 200**
```json
{
  "success": true,
  "data": {
    "country_code": "string",
    "medical_env": {
      "items": "array",
      "totalCount": "integer"
    }
  }
}
```

**Error Codes**: §13.4와 동일

---

### 13.8 국가 연락처 정보 (MOFA)

#### [GET] /api/v1/mofa/country/:countryCode/contacts

**인증**: 불필요
**설명**: 재외공관(`EmbassyService2`)과 현지연락처(`LocalContactService2`)를 병렬 호출하여 반환한다.

**Path Parameters**: §13.4와 동일

**Response 200**
```json
{
  "success": true,
  "data": {
    "country_code": "string",
    "embassy": {
      "items": "array",
      "totalCount": "integer"
    },
    "local_contact": {
      "items": "array",
      "totalCount": "integer"
    }
  }
}
```

**Error Codes**: §13.4와 동일

---

### 13.9 국가 전체 통합 조회 (MOFA)

#### [GET] /api/v1/mofa/country/:countryCode/all

**인증**: 불필요
**설명**: §13.4 ~ §13.8의 5개 통합 메서드를 모두 병렬 호출하여 한 번에 반환한다.

**Path Parameters**: §13.4와 동일

**Response 200**
```json
{
  "success": true,
  "data": {
    "country_code": "string",
    "summary": {
      "travel_alarm": "array",
      "country_basic": "object",
      "overview_info": "object",
      "country_flag": "object | null"
    },
    "safety": {
      "safety_notices": "object",
      "accidents": "object",
      "security_env": "object"
    },
    "entry": {
      "entrance_visa": "object"
    },
    "medical": {
      "medical_env": "object"
    },
    "contacts": {
      "embassy": "object",
      "local_contact": "object"
    }
  }
}
```

> 개별 섹션 호출 실패 시 해당 키 값은 `null`로 대체된다.

**Error Codes**: §13.4와 동일

---

### 13.10 MOFA 캐시 초기화

#### [DELETE] /api/v1/mofa/cache

**인증**: 불필요 (관리용)
**설명**: 서버 인메모리 MOFA API 캐시를 전체 삭제한다. 운영 환경에서는 접근 제한 적용을 권장한다.

**Request Body**: 없음

**Response 200**
```json
{
  "success": true,
  "data": null,
  "message": "MOFA API cache cleared successfully"
}
```

**Error Codes**

| Code | 설명 |
|------|------|
| 500 | 서버 내부 오류 |

---

## §14 리더십 양도 (Leadership Transfer)

그룹 Captain이 다른 활성 멤버에게 리더십을 양도하는 API.
`tb_leader_transfer_log`에 이력을 기록하며, 단일 트랜잭션으로 역할 변경과 그룹 소유자(`tb_group.owner_user_id`) 업데이트를 원자적으로 처리한다.

> **라우터 마운트**: `leader-transfer.routes.ts`는 그룹 라우터(`/api/v1/groups`)에 마운트된다.

### 14.1 리더십 양도

#### [POST] /api/v1/groups/:groupId/transfer-leadership

**인증**: 불필요 (`req.userId`는 JWT 또는 `req.body.user_id` fallback으로 추출)
**설명**: 현재 Captain이 다른 활성 멤버에게 리더십을 양도한다. 트랜잭션 내에서 다음을 원자적으로 실행한다:
1. 기존 Captain → `member_role = 'crew_chief'`, `is_admin = FALSE`
2. 대상 멤버 → `member_role = 'captain'`, `is_admin = TRUE`
3. `tb_group.owner_user_id` → `to_user_id`로 변경
4. `tb_leader_transfer_log` 이력 삽입

**Path Parameters**

| 파라미터 | 타입 | 설명 |
|---------|------|------|
| `groupId` | string (UUID) | 그룹 ID |

**Request Body**

```json
{
  "user_id": "string",
  "to_user_id": "string"
}
```

| 필드 | 타입 | 필수 | 설명 |
|------|------|:----:|------|
| `user_id` | string (UUID) | ✅ | 현재 Captain의 사용자 ID (JWT 미사용 시 body에 포함) |
| `to_user_id` | string (UUID) | ✅ | 리더십을 넘겨받을 대상 멤버의 사용자 ID |

**Response 200**
```json
{
  "success": true,
  "data": {
    "success": true,
    "from_user_id": "string (UUID)",
    "to_user_id": "string (UUID)"
  },
  "message": "Leadership transferred successfully"
}
```

**Error Codes**

| Code | 설명 |
|------|------|
| 400 | `groupId`, `user_id`, 또는 `to_user_id` 누락 |
| 403 | 요청자가 현재 Captain이 아님: `"Only the current captain can transfer leadership"` |
| 404 | 대상 사용자가 해당 그룹의 활성 멤버가 아님: `"Target user is not an active member of this group"` |
| 500 | 서버 내부 오류 |

---

### 14.2 리더 양도 이력 조회

#### [GET] /api/v1/groups/:groupId/transfer-history

**인증**: 불필요 (`req.userId`는 JWT 또는 `req.query.user_id`에서 추출)
**설명**: 그룹의 리더 양도 전체 이력을 최신순으로 반환한다. `captain` 또는 `crew_chief` 권한(`is_admin = TRUE`)이 필요하다.

**Path Parameters**

| 파라미터 | 타입 | 설명 |
|---------|------|------|
| `groupId` | string (UUID) | 그룹 ID |

**Query Parameters**

| 파라미터 | 타입 | 필수 | 설명 |
|---------|------|:----:|------|
| `user_id` | string (UUID) | 조건부 | JWT 미사용 시 사실상 필수. 미전달 시 `undefined`로 권한 조회 → 403 반환 |

**Response 200**
```json
{
  "success": true,
  "data": {
    "transfer_history": [
      {
        "transfer_id": "string (UUID)",
        "from_user_id": "string (UUID)",
        "to_user_id": "string (UUID)",
        "transferred_at": "string (ISO 8601)",
        "from_display_name": "string | null",
        "to_display_name": "string | null"
      }
    ]
  }
}
```

**Error Codes**

| Code | 설명 |
|------|------|
| 400 | `groupId` 누락 |
| 403 | 권한 없음: `"Permission denied: admin role required"` |
| 500 | 서버 내부 오류 |

---

## §15 국가 (Countries)

`TB_COUNTRY` 테이블에서 활성 국가 목록을 제공하는 API.
국가 목록은 `country_name_ko` 오름차순(NULLS LAST) → `country_name_en` 오름차순으로 정렬된다.

> **알려진 이슈**: `tb_country` 테이블 미생성 상태에서는 `500` 오류가 발생할 수 있다 (`GET /api/v1/countries` 500 에러 — 메모리 §tb_country 참조).

### 15.1 국가 목록 조회

#### [GET] /api/v1/countries

**인증**: 불필요
**설명**: `TB_COUNTRY`에서 `is_active = TRUE` AND `deleted_at IS NULL` 조건의 모든 활성 국가를 반환한다.

**Request Body**: 없음

**Response 200**
```json
{
  "success": true,
  "data": [
    {
      "country_code": "string",
      "country_name_ko": "string | null",
      "country_name_en": "string",
      "country_name_local": "string | null",
      "flag_emoji": "string | null",
      "iso_alpha2": "string | null"
    }
  ]
}
```

| 필드 | 설명 |
|------|------|
| `country_code` | 내부 국가 코드 키 (`TB_COUNTRY.country_code`) |
| `country_name_ko` | 국가명 (한국어). 없으면 `null` |
| `country_name_en` | 국가명 (영어) |
| `country_name_local` | 현지어 국가명. 없으면 `null` |
| `flag_emoji` | 국기 이모지 (예: `"🇹🇭"`). 없으면 `null` |
| `iso_alpha2` | ISO 3166-1 alpha-2 코드 (예: `"TH"`). 없으면 `null` |

**Error Codes**

| Code | 설명 |
|------|------|
| 500 | 서버 내부 오류 (DB 접속 실패 또는 `tb_country` 테이블 미존재 시 포함) |

---

## §15.5 이벤트 로그 (Event Log)

통합 이벤트 로그를 기록·조회하는 API. 지오펜스 진입/이탈, SOS, 이동 세션, 디바이스 상태 등 앱에서 발생하는 모든 이벤트를 단일 엔드포인트로 기록한다. 서버는 `event_type` / `event_subtype` 값을 검증하지 않으므로, 앱에서 새 이벤트 타입을 추가해도 서버 수정이 필요 없다.

> **테이블**: `TB_EVENT_LOG`
> **기본 경로**: `/api/v1/events`
> **관련 상수**: `src/constants/event-types.ts`, `src/constants/event-notification-config.ts`

### 15.5.1 이벤트 로그 기록

#### [POST] /api/v1/events

**인증**: 불필요 (내부 앱 전용)
**설명**: 앱에서 발생한 이벤트를 `TB_EVENT_LOG`에 저장한다. `location_id`가 있으면 `TB_LOCATION`에서 공통 정보(주소, 배터리, 네트워크)를 자동으로 보완한다. 저장 완료 후 비동기로 FCM 알림을 트리거한다.

**Request Body**

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| `user_id` | `string` | Y | 이벤트 발생 사용자 ID |
| `event_type` | `string` | Y | 이벤트 타입 (§16.7 참조) |
| `event_subtype` | `string` | N | 이벤트 서브타입 (§16.7 참조) |
| `group_id` | `string` | N | 관련 그룹 ID. 없으면 활성 그룹에서 자동 조회 |
| `latitude` | `number` | N | 위도 |
| `longitude` | `number` | N | 경도 |
| `address` | `string` | N | 주소 문자열 |
| `battery_level` | `number` | N | 배터리 잔량 (0–100) |
| `battery_is_charging` | `boolean` | N | 충전 중 여부 |
| `network_type` | `string` | N | 네트워크 타입 (예: `wifi`, `cellular`) |
| `app_version` | `string` | N | 앱 버전 문자열 |
| `geofence_id` | `string` | N | 관련 지오펜스 ID |
| `movement_session_id` | `string` | N | 관련 이동 세션 ID |
| `location_id` | `string` | N | 관련 위치 로그 ID |
| `sos_id` | `string` | N | 관련 SOS ID |
| `event_data` | `object` | N | 이벤트 부가 데이터 (JSONB) |
| `occurred_at` | `string (ISO8601)` | N | 이벤트 발생 시각. 없으면 서버 수신 시각 사용 |

**Response 200**
```json
{
  "success": true,
  "data": {
    "event_id": "uuid",
    "message": "Event log recorded successfully"
  }
}
```

**Error Codes**

| Code | 설명 |
|------|------|
| 400 | `user_id` 또는 `event_type` 누락 |
| 500 | 서버 내부 오류 |

---

### 15.5.2 이벤트 로그 조회

#### [GET] /api/v1/events

**인증**: 불필요 (내부 앱 전용)
**설명**: 필터 조건으로 `TB_EVENT_LOG`를 조회한다. 기본 최대 100건 반환, `occurred_at` 내림차순 정렬.

**Query Parameters**

| 파라미터 | 타입 | 설명 |
|----------|------|------|
| `user_id` | `string` | 사용자 ID 필터 |
| `group_id` | `string` | 그룹 ID 필터 |
| `event_type` | `string` | 이벤트 타입 필터 |
| `event_subtype` | `string` | 이벤트 서브타입 필터 |
| `since` | `string (ISO8601)` | 이 시각 이후 이벤트만 조회 |
| `limit` | `number` | 최대 반환 건수 (기본 100) |
| `offset` | `number` | 페이지 오프셋 (`limit`와 함께 사용) |

**Response 200**
```json
{
  "success": true,
  "data": {
    "events": [
      {
        "event_id": "uuid",
        "user_id": "string",
        "group_id": "string | null",
        "event_type": "string",
        "event_subtype": "string | null",
        "latitude": "number | null",
        "longitude": "number | null",
        "address": "string | null",
        "battery_level": "number | null",
        "battery_is_charging": "boolean | null",
        "network_type": "string | null",
        "app_version": "string | null",
        "geofence_id": "string | null",
        "movement_session_id": "string | null",
        "location_id": "string | null",
        "sos_id": "string | null",
        "event_data": "object | null",
        "occurred_at": "string (ISO8601)",
        "created_at": "string (ISO8601)"
      }
    ],
    "count": "number"
  }
}
```

**Error Codes**

| Code | 설명 |
|------|------|
| 500 | 서버 내부 오류 |

---

## §15.6 위치 공유 설정 (Location Sharing)

> **→ §9.10 위치 공유 설정 참조**: 이 API는 §9.10에 완전히 문서화되어 있다.
> 기본 경로: `GET/PUT /api/v1/groups/:groupId/location-sharing[/master | /:targetUserId]`

---

## §16 공통 타입 정의

여러 API에서 공통으로 사용되는 Enum 값, 상태 코드, 타입을 정의한다.

---

### 16.1 역할 (member_role) Enum

`TB_GROUP_MEMBER.member_role` 컬럼의 허용 값. `captain` 역할은 리더십 이전 API(`POST /api/v1/groups/:groupId/transfer-leadership`) 외에 직접 할당할 수 없다.

| 값 | 설명 | 관련 API |
|----|------|---------|
| `captain` | 여행 캡틴. 그룹당 1인 유일. 최고 권한 | §14 리더십 이전, §6 그룹 조회 |
| `crew_chief` | 부캡틴(크루장). 관리자 권한 (`is_admin = TRUE`). 복수 허용 | §6 그룹 멤버 수정 |
| `crew` | 일반 크루. 기본 역할 | §6 그룹 멤버 추가 |
| `guardian` | 가디언. `TB_GUARDIAN_LINK`와 연동된 보호자 역할 | §8 가디언 시스템 |

> DB 제약: `CHECK (member_role IN ('captain', 'crew_chief', 'crew', 'guardian'))` (`TB_GROUP_MEMBER`)

---

### 16.2 여행 상태 (trip status) Enum

`TB_TRIP.status` 컬럼의 허용 값.

| 값 | 설명 | 관련 API |
|----|------|---------|
| `planning` | 여행 계획 중 | §5 여행 생성/조회 |
| `active` | 여행 진행 중 | §5 여행 조회 |
| `completed` | 여행 완료. 비즈니스 원칙 §02.6에 따라 24시간 내 1회 `active` 재활성화 가능 | §5 여행 조회 |

> **주의**: DB 스키마(`TB_TRIP`) 코멘트에 `planning | active | completed`로 명시. 코드 내 `'cancelled'`는 그룹(`TB_GROUP`) 상태에 해당하며 여행 자체 상태와 구분된다.

---

### 16.3 그룹 멤버 상태 (group member status) Enum

`TB_GROUP_MEMBER.status` 컬럼의 허용 값.

| 값 | 설명 |
|----|------|
| `active` | 활성 멤버. 위치·권한 조회 대상 |
| `removed` | 그룹에서 제거된 멤버 |

---

### 16.4 가디언 링크 상태 (guardian link status) Enum

`TB_GUARDIAN_LINK.status` 컬럼의 허용 값.

| 값 | 설명 | 관련 API |
|----|------|---------|
| `pending` | 가디언 초대 발송됨, 응답 대기 중 | §8.1 가디언 초대 |
| `accepted` | 가디언이 초대 수락 | §8.2 가디언 응답 |
| `rejected` | 가디언이 초대 거절 | §8.2 가디언 응답 |
| `cancelled` | 멤버가 초대를 취소 | §8 가디언 시스템 |

> DB 제약: `CHECK (status IN ('pending', 'accepted', 'rejected', 'cancelled'))` (`TB_GUARDIAN_LINK`)

---

### 16.5 지오펜스 관련 Enum

#### 16.5.1 지오펜스 위험 등급 (geofence type)

`TB_GEOFENCE.type` 컬럼의 허용 값.

| 값 | 설명 | 관련 API |
|----|------|---------|
| `safe` | 안전 구역 — 진입 시 안전 알림 | §10 지오펜스 |
| `watch` | 주의 구역 — 진입/이탈 시 주의 알림 | §10 지오펜스 |
| `danger` | 위험 구역 — 진입 시 긴급 알림 | §10 지오펜스 |
| `stationary` | 정박 구역 (숙소 등) | §10 지오펜스 |

> DB 소스: `geofence.service.ts` 인터페이스 `type: 'safe' | 'watch' | 'danger' | 'stationary'`

> **⚠️ 생성/수정 제약**: `stationary`는 읽기 전용 시스템 타입이다. 지오펜스 생성(`POST /groups/:group_id/geofences`) 및 수정(`PATCH /geofences/:id`) API의 서비스 레이어에서 `'safe' | 'watch' | 'danger'`만 허용하며, `stationary` 전송 시 무시되거나 오류 발생할 수 있다.

#### 16.5.2 지오펜스 형태 (geofence shape_type)

`TB_GEOFENCE.shape_type` 컬럼의 허용 값.

| 값 | 설명 | 필수 추가 필드 |
|----|------|--------------|
| `circle` | 원형 지오펜스 | `center_latitude`, `center_longitude`, `radius_meters` |
| `polygon` | 다각형 지오펜스 | `polygon_coordinates` (GeoJSON 좌표 배열) |

> DB 소스: `geofence.service.ts` 인터페이스 `shape_type: 'circle' | 'polygon'`

---

### 16.6 프라이버시 등급 (privacy_level) Enum

`TB_TRIP.privacy_level` 컬럼의 허용 값. 비즈니스 원칙 v5.1 §03.6 기반.

| 값 | 한국어 명칭 | 설명 |
|----|------------|------|
| `safety_first` | 안전최우선 | 위치 공유 강제. 미성년자 포함 여행 시 자동 적용 |
| `standard` | 표준 | 기본값. 자발적 공유 |
| `privacy_first` | 프라이버시우선 | 위치 공유 최소화 |

> DB 제약: `TB_TRIP.privacy_level VARCHAR(20) DEFAULT 'standard'` — `safety_first | standard | privacy_first`

---

### 16.7 이벤트 로그 타입 (event_type / event_subtype) Enum

`TB_EVENT_LOG.event_type` 및 `event_subtype` 컬럼의 권장 값. 서버는 검증하지 않으므로 앱에서 신규 타입을 자유롭게 추가할 수 있다.

#### event_type

| 값 | 설명 |
|----|------|
| `geofence` | 지오펜스 진입/이탈 이벤트 |
| `session` | 이동 세션 시작/종료 이벤트 |
| `session_event` | 이동 중 특이 이벤트 (급가속, 과속 등) |
| `device_status` | 디바이스 상태 변경 이벤트 |
| `sos` | SOS 긴급 이벤트 |

#### event_subtype (event_type별)

**`geofence`**

| 값 | 설명 |
|----|------|
| `enter` | 지오펜스 진입 (DWELL 10초 이상 체류 시도 포함) |
| `exit` | 지오펜스 이탈 |
| `dwell` | 지오펜스 내 장시간 체류 |

**`session`**

| 값 | 설명 |
|----|------|
| `start` | 이동 세션 시작 |
| `end` | 이동 세션 정상 종료 |
| `kill` | 이동 세션 강제 종료 |
| `premature_end` | 이동 세션 비정상 조기 종료 |

**`session_event`**

| 값 | 설명 |
|----|------|
| `rapid_acceleration` | 급가속 감지 |
| `rapid_deceleration` | 급감속/급정지 감지 |
| `speeding` | 과속 감지 |

**`device_status`**

| 값 | 설명 |
|----|------|
| `battery_warning` | 배터리 부족 경고 |
| `battery_charging` | 충전 시작 |
| `mock_location` | 가상 위치 감지 |
| `location_permission_denied` | 위치 권한 거부 |
| `network_change` | 네트워크 환경 변경 |
| `app_lifecycle` | 앱 포그라운드/백그라운드 전환 |
| `location_sharing_enabled` | 위치 공유 활성화 |
| `location_sharing_disabled` | 위치 공유 비활성화 |
| `geofencing_enabled` | 지오펜싱 활성화 |
| `geofencing_disabled` | 지오펜싱 비활성화 |
| `online` | 디바이스 온라인 복귀 |
| `offline` | 디바이스 오프라인 감지 |

**`sos`**

| 값 | 설명 |
|----|------|
| `emergency` | 일반 긴급 상황 |
| `crime` | 범죄 피해 |
| `medical` | 의료 응급 |

---

### 16.8 위치 공유 가시성 타입 (visibility_type) Enum

`TB_LOCATION_SHARING.visibility_type` 컬럼의 허용 값 (비즈니스 원칙 v5.1 §04.4).

| 값 | 설명 |
|----|------|
| `all` | 전체 공개 — 그룹의 모든 멤버가 위치 조회 가능. 기본값 |
| `admin_only` | 관리자 전용 — `captain` / `crew_chief`만 위치 조회 가능 |
| `specified` | 지정 멤버 — `target_user_id`로 지정한 멤버만 가능. 복수 멤버 지정 시 동일 `(trip_id, user_id)` 조합으로 N개 행 생성 |

> DB 제약: `CHECK (visibility_type IN ('all', 'admin_only', 'specified'))` (`TB_LOCATION_SHARING`)

---

### 16.9 출석 체크 상태 Enum

#### 16.9.1 출석 체크 세션 상태 (attendance_check status)

`TB_ATTENDANCE_CHECK.status` 컬럼의 허용 값.

| 값 | 설명 |
|----|------|
| `ongoing` | 출석 체크 진행 중 |
| `completed` | 출석 체크 완료 |
| `cancelled` | 출석 체크 취소 |

> DB 제약: `CHECK (status IN ('ongoing', 'completed', 'cancelled'))` (`TB_ATTENDANCE_CHECK`)

#### 16.9.2 출석 체크 응답 타입 (attendance_response response_type)

`TB_ATTENDANCE_RESPONSE.response_type` 컬럼의 허용 값.

| 값 | 설명 |
|----|------|
| `present` | 현재 위치 확인 완료 |
| `absent` | 미응답 / 비출석 (deadline_at 경과 시 자동 처리) |
| `unknown` | 아직 응답 전 (기본값) |

> DB 제약: `CHECK (response_type IN ('present', 'absent', 'unknown'))` (`TB_ATTENDANCE_RESPONSE`)

---

### 16.10 여행 유형 (trip_type) Enum

`TB_TRIP.trip_type` 컬럼의 허용 값.

| 값 | 설명 |
|----|------|
| `group` | 그룹 여행 |
| `solo` | 개인 여행 |

> DB 소스: `TB_TRIP.trip_type VARCHAR(20)` — `group | solo`

---

## §17 변경 이력

| 날짜 | 버전 | 내용 |
|------|------|------|
| 2026-03-02 | v1.0 | 최초 작성. `safetrip-server-api` 컨트롤러 전수 분석 기반. §1~§16 전체 (Auth·Users·Trips·Groups·InviteCodes·Guardians·Locations·Geofences·MovementRecords·FCM·Guides·MOFA·LeaderTransfer·Countries·EventLog·CommonTypes). 총 엔드포인트 약 120개 이상 문서화. |

---

## §18 관련 문서 참조

| 문서 | 경로 | 관계 |
|------|------|------|
| 비즈니스 원칙 v5.1 | `Master_docs/01_T1_SafeTrip_비즈니스_원칙_v5.1.md` | 기준 문서 (역할·가디언 과금·여행 기간 등) |
| DB 설계 v3.4 | `Master_docs/07_T2_DB_설계_및_관계_v3_4.md` | 테이블 스키마 원본 |
| 아키텍처 구조 v3.0 | `Master_docs/08_T2_SafeTrip_아키텍처_구조_v3_0.md` | 엔드포인트 목록 §19 (경로만 기재) |
| 멤버탭 원칙 | `Master_docs/19_T3_멤버탭_원칙.md` | 가디언 UI 규칙 §03.1 |
| 마스터 원칙 거버넌스 v2.0 | `Master_docs/Master_SafeTrip_마스터_원칙_거버넌스_v2_0.md` | 문서 거버넌스 |


---

## §11~§18 Remaining Endpoints (Generated)


### Path: /api/v1/users/me/fcm-token
#### [PUT] /api/v1/users/me/fcm-token
**Summary**: FCM 토큰 등록/갱신 (본인)


### Path: /api/v1/users/me/fcm-token/{tokenId}
#### [DELETE] /api/v1/users/me/fcm-token/{tokenId}
**Summary**: FCM 토큰 비활성화 (본인)
**Parameters**:
- tokenId (path): string


### Path: /api/v1/users/{userId}/fcm-token
#### [PUT] /api/v1/users/{userId}/fcm-token
**Summary**: 테스트용 특정 사용자 FCM 토큰 등록/갱신
**Parameters**:
- userId (path): string


### Path: /api/v1/api/v1/locations/users/{userId}/movement-sessions/{sessionId}/events
#### [GET] /api/v1/api/v1/locations/users/{userId}/movement-sessions/{sessionId}/events
**Summary**: 9.9 이동 세션 이벤트 목록 조회
**Parameters**:
- userId (path): string
- sessionId (path): string


### Path: /api/v1/api/v1/geofences/events
#### [POST] /api/v1/api/v1/geofences/events
**Summary**: 10.6 지오펜스 이벤트 기록


### Path: /api/v1/emergencies
#### [POST] /api/v1/emergencies
**Summary**: 긴급 상황 생성 (SOS 포함, 5분 쿨다운)


### Path: /api/v1/emergencies/trip/{tripId}
#### [GET] /api/v1/emergencies/trip/{tripId}
**Summary**: 긴급 상황 이력 조회
**Parameters**:
- tripId (path): string


### Path: /api/v1/emergencies/{emergencyId}/resolve
#### [PATCH] /api/v1/emergencies/{emergencyId}/resolve
**Summary**: 긴급 상황 해제
**Parameters**:
- emergencyId (path): string


### Path: /api/v1/emergencies/{emergencyId}/acknowledge
#### [PATCH] /api/v1/emergencies/{emergencyId}/acknowledge
**Summary**: 긴급 상황 확인
**Parameters**:
- emergencyId (path): string


### Path: /api/v1/emergencies/contacts
#### [GET] /api/v1/emergencies/contacts
**Summary**: 비상 연락처 목록

#### [POST] /api/v1/emergencies/contacts
**Summary**: 비상 연락처 추가


### Path: /api/v1/emergencies/contacts/{contactId}
#### [DELETE] /api/v1/emergencies/contacts/{contactId}
**Summary**: 비상 연락처 삭제
**Parameters**:
- contactId (path): string


### Path: /api/v1/chats/trip/{tripId}/rooms
#### [GET] /api/v1/chats/trip/{tripId}/rooms
**Summary**: 채팅방 목록 조회
**Parameters**:
- tripId (path): string


### Path: /api/v1/chats/rooms/{roomId}/messages
#### [GET] /api/v1/chats/rooms/{roomId}/messages
**Summary**: 채팅 메시지 조회 (커서 기반)
**Parameters**:
- roomId (path): string
- cursor (query): string
- limit (query): number

#### [POST] /api/v1/chats/rooms/{roomId}/messages
**Summary**: 채팅 메시지 전송
**Parameters**:
- roomId (path): string


### Path: /api/v1/chats/rooms/{roomId}/read
#### [POST] /api/v1/chats/rooms/{roomId}/read
**Summary**: 읽음 상태 갱신
**Parameters**:
- roomId (path): string


### Path: /api/v1/fcm/send
#### [POST] /api/v1/fcm/send
**Summary**: 단일 기기 푸시 발송 (테스트)


### Path: /api/v1/fcm/send-multicast
#### [POST] /api/v1/fcm/send-multicast
**Summary**: 다중 기기 푸시 발송 (테스트)


### Path: /api/v1/fcm/history
#### [GET] /api/v1/fcm/history
**Summary**: 내 알림 이력 조회
**Parameters**:
- page (query): string
- limit (query): string


### Path: /api/v1/fcm/history/unread-count
#### [GET] /api/v1/fcm/history/unread-count
**Summary**: 안 읽은 알림 개수 조회


### Path: /api/v1/fcm/history/{notificationId}/read
#### [POST] /api/v1/fcm/history/{notificationId}/read
**Summary**: 알림 읽음 처리
**Parameters**:
- notificationId (path): string


### Path: /api/v1/payments/transaction
#### [POST] /api/v1/payments/transaction
**Summary**: 결제 시작


### Path: /api/v1/payments/transaction/{id}/verify
#### [POST] /api/v1/payments/transaction/{id}/verify
**Summary**: 영수증 검증 및 결제 완료
**Parameters**:
- id (path): string


### Path: /api/v1/payments/transactions
#### [GET] /api/v1/payments/transactions
**Summary**: 결제 이력 조회


### Path: /api/v1/payments/subscription
#### [GET] /api/v1/payments/subscription
**Summary**: 활성 구독 조회

#### [POST] /api/v1/payments/subscription
**Summary**: 구독 생성


### Path: /api/v1/b2b/organizations
#### [GET] /api/v1/b2b/organizations
**Summary**: B2B 조직 목록


### Path: /api/v1/b2b/organizations/{orgId}
#### [GET] /api/v1/b2b/organizations/{orgId}
**Summary**: B2B 조직 상세
**Parameters**:
- orgId (path): string


### Path: /api/v1/b2b/organizations/{orgId}/contracts
#### [GET] /api/v1/b2b/organizations/{orgId}/contracts
**Summary**: 조직 계약 목록
**Parameters**:
- orgId (path): string


### Path: /api/v1/b2b/organizations/{orgId}/admins
#### [GET] /api/v1/b2b/organizations/{orgId}/admins
**Summary**: 조직 관리자 목록
**Parameters**:
- orgId (path): string


### Path: /api/v1/b2b/organizations/{orgId}/dashboard-config
#### [GET] /api/v1/b2b/organizations/{orgId}/dashboard-config
**Summary**: 대시보드 설정 조회
**Parameters**:
- orgId (path): string

#### [POST] /api/v1/b2b/organizations/{orgId}/dashboard-config
**Summary**: 대시보드 설정 저장
**Parameters**:
- orgId (path): string


### Path: /api/v1/countries
#### [GET] /api/v1/countries
**Summary**: 활성 국가 목록 조회


### Path: /api/v1/guides/search
#### [GET] /api/v1/guides/search
**Summary**: 가이드 검색
**Parameters**:
- q (query): string
- country (query): string


### Path: /api/v1/guides/{countryCode}
#### [GET] /api/v1/guides/{countryCode}
**Summary**: 국가별 가이드 조회
**Parameters**:
- countryCode (path): string


### Path: /api/v1/guides/{countryCode}/emergency
#### [GET] /api/v1/guides/{countryCode}/emergency
**Summary**: 긴급 연락처 조회
**Parameters**:
- countryCode (path): string


### Path: /api/v1/events
#### [POST] /api/v1/events
**Summary**: 이벤트 로그 기록

#### [GET] /api/v1/events
**Summary**: 이벤트 로그 조회


### Path: /api/v1/mofa/country/{countryCode}/summary
#### [GET] /api/v1/mofa/country/{countryCode}/summary
**Summary**: 국가 종합 요약 (MOFA)
**Parameters**:
- countryCode (path): string


### Path: /api/v1/mofa/country/{countryCode}/safety
#### [GET] /api/v1/mofa/country/{countryCode}/safety
**Summary**: 국가 안전 정보 (MOFA)
**Parameters**:
- countryCode (path): string


### Path: /api/v1/mofa/country/{countryCode}/entry
#### [GET] /api/v1/mofa/country/{countryCode}/entry
**Summary**: 국가 입국 정보 (MOFA)
**Parameters**:
- countryCode (path): string


### Path: /api/v1/mofa/country/{countryCode}/medical
#### [GET] /api/v1/mofa/country/{countryCode}/medical
**Summary**: 국가 의료 정보 (MOFA)
**Parameters**:
- countryCode (path): string


### Path: /api/v1/mofa/country/{countryCode}/contacts
#### [GET] /api/v1/mofa/country/{countryCode}/contacts
**Summary**: 국가 연락처 정보 (MOFA)
**Parameters**:
- countryCode (path): string


