# SafeTrip Backend API 명세서 — Part 1 (§3~§5)

| 항목 | 내용 |
|------|------|
| **문서 ID** | `DOC-T2-API-036` |
| **상위 인덱스** | [35_T2_API_명세서.md](./35_T2_API_명세서.md) |
| **범위** | §3 인증 / §4 사용자 / §5 여행 |
| **버전** | v1.0 |
| **작성일** | 2026-03-02 |

> Part 2: [37_T2_API_명세서_Part2.md](./37_T2_API_명세서_Part2.md) | Part 3: [38_T2_API_명세서_Part3.md](./38_T2_API_명세서_Part3.md)

---

## §3. 인증 (Auth)

> **기본 경로**: `/api/v1/auth`
> **Rate Limit**: `authLimiter` — 15분 / 20회 / IP
> **미들웨어**: 두 엔드포인트 모두 `authenticate` 미들웨어 **미적용** (인증 없이 호출 가능)

---

#### [POST] /api/v1/auth/firebase-verify

**인증**: 불필요
**설명**: Firebase ID Token을 검증하고 `tb_user`에 사용자를 조회/생성(upsert)한다. 로그인 및 앱 최초 실행 시 호출.

**Request Body**
```json
{
  "id_token": "string",
  "phone_country_code": "string",
  "install_id": "string",
  "is_test_device": "boolean",
  "test_phone_number": "string"
}
```

| 필드 | 타입 | 필수 | 설명 |
|------|------|:----:|------|
| `id_token` | string | ✅ | Firebase Authentication에서 발급된 ID Token |
| `phone_country_code` | string | ✗ | 전화번호 국가 코드. 미전달 시 기본값 `+82` 적용 |
| `install_id` | string | ✗ | 앱 설치 단위 식별자. 기기 변경 감지 용도 |
| `is_test_device` | boolean | ✗ | 테스트 기기 Anonymous Auth 여부. `true`일 때만 `test_phone_number` 사용 |
| `test_phone_number` | string | ✗ | 테스트 전화번호. `is_test_device=true` 시에만 유효하며 `+82109999000[1-9]` 패턴만 허용 |

> **테스트 기기 처리**: Firebase Anonymous Auth 토큰에는 `phone_number`가 없다. `is_test_device=true` + 허용된 `test_phone_number` 조합을 전달하면 해당 번호로 fallback 처리된다.

**Response 200**
```json
{
  "success": true,
  "data": {
    "user_id": "string (Firebase UID)",
    "phone_number": "string (E.164 형식, 예: +821012345678)",
    "phone_country_code": "string",
    "display_name": "string",
    "profile_image_url": "string | null",
    "install_id": "string | null",
    "location_sharing_mode": "string",
    "last_verification_at": "string (ISO 8601)",
    "created_at": "string (ISO 8601)",
    "last_active_at": "string (ISO 8601)",
    "user_role": "string ('crew' | 'guardian')",
    "is_new_user": "boolean"
  }
}
```

| 필드 | 타입 | 설명 |
|------|------|------|
| `user_id` | string | Firebase UID (`tb_user.user_id`) |
| `phone_number` | string | E.164 형식 전화번호 (예: `+821012345678`) |
| `phone_country_code` | string | 국가 코드 (예: `+82`) |
| `display_name` | string | 표시 이름. 신규 사용자는 빈 문자열(`""`) |
| `profile_image_url` | string \| null | 프로필 이미지 URL |
| `install_id` | string \| null | 앱 설치 ID |
| `location_sharing_mode` | string | 위치 공유 모드 |
| `last_verification_at` | string | 마지막 Firebase 토큰 검증 시각 |
| `created_at` | string | 계정 생성 시각 |
| `last_active_at` | string | 마지막 활동 시각 |
| `user_role` | string | `'guardian'` (가디언 링크 존재 시) 또는 `'crew'` |
| `is_new_user` | boolean | `true` = 이번 호출로 신규 생성된 사용자 |

**동작 상세**

| 케이스 | 동작 |
|--------|------|
| 신규 사용자 (전화번호 미존재) | `tb_user` INSERT, `is_new_user: true` 반환 |
| 기존 사용자, UID 동일 | `last_verification_at`, `last_active_at`, `install_id` 갱신, `is_new_user: false` 반환 |
| 기존 사용자, UID 변경 (기기 변경/에뮬레이터 리셋) | 트랜잭션으로 `tb_user.user_id` PK 및 모든 FK 참조 테이블 CASCADE 업데이트 |

**Error Codes**

| Code | 조건 |
|------|------|
| 400 | `id_token` 필드 없음: `"id_token is required"` |
| 400 | 토큰에 `phone_number` 없고 `is_test_device` 조건도 불충족: `"Phone number not found in token"` |
| 401 | Firebase ID Token 서명 검증 실패 또는 만료: `"Invalid or expired token"` |
| 500 | DB 오류 등 서버 내부 오류 |

---

#### [POST] /api/v1/auth/logout

**인증**: 불필요
**설명**: 로그아웃 처리. 서버 측 상태 변경 없이 성공 응답만 반환한다. 실제 토큰 무효화는 클라이언트에서 Firebase `signOut()`으로 처리해야 한다.

**Request Body**: 없음

**Response 200**
```json
{
  "success": true,
  "data": {
    "message": "Logout successful"
  }
}
```

**Error Codes**: 없음 (항상 200 반환)

---

## §4. 사용자 (Users)

> **기본 경로**: `/api/v1/users`
>
> 사용자 프로필 조회·수정, FCM 디바이스 토큰 관리, 약관 동의 기록 API를 제공한다.
> 일부 엔드포인트(테스트용 등록, ID/전화번호 조회, 프로필 수정)는 인증 없이 호출 가능하며,
> 나머지(`/me`, `/search`, `/me/fcm-token`, `/:id/terms`)는 Firebase ID Token이 필요하다.
>
> **§4.A 사용자(Users)** — `users.controller.ts` / `users.routes.ts`
> **§4.B 여행자(Travelers)** — `travelers.controller.ts` / `travelers.routes.ts`
> Travelers는 Users와 독립적인 라우터이나 TB_USER / TB_GROUP_MEMBER를 함께 다루므로 같은 섹션에 포함한다.

---

### §4.A 사용자 (Users)

---

#### [POST] /api/v1/users/register

**인증**: 불필요
**설명**: 테스트용 사용자 등록. `tb_user`에 UPSERT한다. (프로덕션에서는 `/api/v1/auth/firebase-verify` 사용 권장)

**Request Body**
```json
{
  "user_id": "string",
  "display_name": "string",
  "phone_number": "string",
  "phone_country_code": "string"
}
```

| 필드 | 타입 | 필수 | 설명 |
|------|------|:----:|------|
| `user_id` | string | ✅ | Firebase UID (UUID 형식) |
| `display_name` | string | ✗ | 표시 이름. 미전달 시 `User_<user_id 앞 5자>` 자동 생성 |
| `phone_number` | string | ✗ | E.164 형식 전화번호. 미전달 시 `user_id`의 숫자 추출로 자동 생성 |
| `phone_country_code` | string | ✗ | 국가 코드. 미전달 시 기본값 `+82` |

**Response 201**
```json
{
  "success": true,
  "data": {
    "user_id": "string",
    "phone_number": "string",
    "phone_country_code": "string",
    "display_name": "string",
    "profile_image_url": "string | null",
    "location_sharing_mode": "string",
    "last_verification_at": "string (ISO 8601)",
    "created_at": "string (ISO 8601)",
    "last_active_at": "string (ISO 8601)"
  },
  "message": "User registered successfully"
}
```

**Error Codes**

| Code | 설명 |
|------|------|
| 400 | `user_id` 누락: `"user_id is required"` |
| 500 | DB 오류 등 서버 내부 오류 |

---

#### [GET] /api/v1/users/by-phone

**인증**: 불필요
**설명**: 전화번호로 사용자를 조회한다.

**Query Parameters**

| 파라미터 | 타입 | 필수 | 기본값 | 설명 |
|---------|------|:----:|:------:|------|
| `phone_number` | string | ✅ | — | E.164 형식(`+821012345678`) 또는 로컬 번호 |
| `phone_country_code` | string | 조건부 | — | `phone_number`가 `+` 로 시작하지 않을 때 필수. 예: `+82` |

> **E.164 변환**: `phone_number`가 `+`로 시작하지 않으면 `phone_country_code + phone_number` 로 E.164를 구성하여 조회한다.

**Response 200**
```json
{
  "success": true,
  "data": {
    "user_id": "string",
    "phone_number": "string",
    "phone_country_code": "string",
    "display_name": "string",
    "profile_image_url": "string | null",
    "location_sharing_mode": "string",
    "last_verification_at": "string (ISO 8601)",
    "created_at": "string (ISO 8601)",
    "last_active_at": "string (ISO 8601)",
    "user_role": "string ('crew' | 'guardian')"
  }
}
```

**Error Codes**

| Code | 설명 |
|------|------|
| 400 | `phone_number` 누락 |
| 400 | `phone_number`가 E.164 형식이 아닌데 `phone_country_code` 미전달 |
| 404 | 해당 전화번호 사용자 없음 |
| 500 | 서버 내부 오류 |

---

#### [GET] /api/v1/users/search

**인증**: 필요
**설명**: 표시 이름 또는 전화번호로 사용자를 검색한다. 본인(요청자)은 결과에서 제외된다. 최대 20건 반환.

**Query Parameters**

| 파라미터 | 타입 | 필수 | 기본값 | 설명 |
|---------|------|:----:|:------:|------|
| `q` | string | ✅ | — | 검색어. 최소 2자 이상. `display_name` 또는 `phone_number` 부분 일치(ILIKE) |

**Response 200**
```json
{
  "success": true,
  "data": [
    {
      "user_id": "string",
      "display_name": "string",
      "phone_number": "string",
      "phone_country_code": "string",
      "profile_image_url": "string | null"
    }
  ]
}
```

**Error Codes**

| Code | 설명 |
|------|------|
| 400 | `q` 누락 또는 2자 미만: `"q must be at least 2 characters"` |
| 401 | 인증 토큰 없음 또는 만료 |
| 500 | 서버 내부 오류 |

---

#### [GET] /api/v1/users/:userId

**인증**: 불필요
**설명**: userId(Firebase UID)로 특정 사용자를 조회한다.

**Path Parameters**

| 파라미터 | 타입 | 설명 |
|---------|------|------|
| `userId` | string | 조회할 사용자의 Firebase UID |

> **주의**: `userId = "me"` 를 전달하면 `401` 반환. 인증된 본인 조회는 `GET /api/v1/users/me`를 사용해야 한다.

**Response 200**
```json
{
  "success": true,
  "data": {
    "user_id": "string",
    "phone_number": "string",
    "phone_country_code": "string",
    "display_name": "string",
    "profile_image_url": "string | null",
    "date_of_birth": "string (YYYY-MM-DD) | null",
    "location_sharing_mode": "string",
    "last_verification_at": "string (ISO 8601)",
    "created_at": "string (ISO 8601)",
    "last_active_at": "string (ISO 8601)",
    "user_role": "string ('crew' | 'guardian')"
  }
}
```

**Error Codes**

| Code | 설명 |
|------|------|
| 401 | `userId === "me"` 전달 시: `"Use /api/v1/users/me with authentication"` |
| 404 | 사용자 없음 (또는 soft-deleted) |
| 500 | 서버 내부 오류 |

---

#### [PUT] /api/v1/users/:userId

**인증**: 불필요
**설명**: 테스트용 엔드포인트. userId로 사용자 프로필을 업데이트한다. `display_name`은 필수이며, `profile_image_url`, `date_of_birth`는 선택 필드다. 인증된 환경에서는 `PATCH /api/v1/users/me` 사용 권장.

**Path Parameters**

| 파라미터 | 타입 | 설명 |
|---------|------|------|
| `userId` | string | 업데이트할 사용자의 Firebase UID |

**Request Body**
```json
{
  "display_name": "string",
  "profile_image_url": "string",
  "date_of_birth": "string"
}
```

| 필드 | 타입 | 필수 | 설명 |
|------|------|:----:|------|
| `display_name` | string | ✅ | 표시 이름 |
| `profile_image_url` | string | ✗ | 프로필 이미지 URL. 빈 문자열(`""`) 또는 `null` 전달 시 무시됨 |
| `date_of_birth` | string | ✗ | 생년월일 (YYYY-MM-DD). 빈 문자열 또는 `null` 전달 시 무시됨 |

**Response 200**
```json
{
  "success": true,
  "data": {
    "user_id": "string",
    "phone_number": "string",
    "phone_country_code": "string",
    "display_name": "string",
    "profile_image_url": "string | null",
    "date_of_birth": "string | null",
    "location_sharing_mode": "string",
    "last_verification_at": "string (ISO 8601)",
    "created_at": "string (ISO 8601)",
    "last_active_at": "string (ISO 8601)",
    "user_role": "string ('crew' | 'guardian')"
  }
}
```

**Error Codes**

| Code | 설명 |
|------|------|
| 400 | `display_name` 누락 |
| 404 | 사용자 없음 (또는 soft-deleted) |
| 500 | 서버 내부 오류 |

---

#### [PUT] /api/v1/users/:userId/fcm-token

**인증**: 불필요
**설명**: 테스트용 FCM 디바이스 토큰 등록. 인증된 환경에서는 `PUT /api/v1/users/me/fcm-token` 사용 권장. 사용자에게 이미 활성 토큰이 존재하면 업데이트, 없으면 신규 INSERT한다.

**Path Parameters**

| 파라미터 | 타입 | 설명 |
|---------|------|------|
| `userId` | string | 토큰을 등록할 사용자의 Firebase UID |

**Request Body**
```json
{
  "device_token": "string",
  "platform": "string",
  "device_id": "string",
  "device_model": "string",
  "os_version": "string",
  "app_version": "string"
}
```

| 필드 | 타입 | 필수 | 설명 |
|------|------|:----:|------|
| `device_token` | string | ✅ | FCM 디바이스 토큰 |
| `platform` | string | ✅ | `"ios"` 또는 `"android"` |
| `device_id` | string | ✗ | 기기 고유 식별자 |
| `device_model` | string | ✗ | 기기 모델명 (예: `"Pixel 7"`) |
| `os_version` | string | ✗ | OS 버전 (예: `"14.0"`) |
| `app_version` | string | ✗ | 앱 버전 (예: `"1.0.0"`) |

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

| 필드 | 타입 | 설명 |
|------|------|------|
| `token_id` | string | `tb_device_token.token_id` |
| `is_new` | boolean | `true` = 신규 INSERT, `false` = 기존 토큰 UPDATE |
| `last_used_at` | string | 토큰 마지막 사용 시각 |

**Error Codes**

| Code | 설명 |
|------|------|
| 400 | `device_token` 또는 `platform` 누락 |
| 500 | 사용자 미존재(`"User not found: <userId>"`) 또는 DB 오류 |

---

#### [GET] /api/v1/users/me

**인증**: 필요

> ⚠️ **Known Issue**: `users.routes.ts`에서 `GET /:userId`가 `router.use(authenticate)` 이전에 등록되어, `GET /me` 요청이 `userId = 'me'`로 `getUserById` 핸들러에 먼저 매칭된다. `getMe` 컨트롤러는 사실상 도달 불가하며, 이 엔드포인트는 실제로 항상 401을 반환한다. (라우트 등록 순서 수정 필요)

**설명**: 인증된 본인의 사용자 프로필을 조회한다.

**Response 200**
```json
{
  "success": true,
  "data": {
    "user_id": "string",
    "phone_number": "string",
    "phone_country_code": "string",
    "display_name": "string",
    "profile_image_url": "string | null",
    "date_of_birth": "string (YYYY-MM-DD) | null",
    "location_sharing_mode": "string",
    "last_verification_at": "string (ISO 8601)",
    "created_at": "string (ISO 8601)",
    "last_active_at": "string (ISO 8601)",
    "user_role": "string ('crew' | 'guardian')"
  }
}
```

**Error Codes**

| Code | 설명 |
|------|------|
| 401 | 인증 토큰 없음 또는 만료 |
| 404 | 사용자 없음 (또는 soft-deleted) |
| 500 | 서버 내부 오류 |

---

#### [PATCH] /api/v1/users/me

**인증**: 필요
**설명**: 인증된 본인의 프로필을 부분 업데이트한다. 허용 필드: `display_name`, `profile_image_url`, `date_of_birth`, `location_sharing_mode`. 전달하지 않은 필드는 변경되지 않는다.

**Request Body**
```json
{
  "display_name": "string",
  "profile_image_url": "string",
  "date_of_birth": "string",
  "location_sharing_mode": "string"
}
```

| 필드 | 타입 | 필수 | 설명 |
|------|------|:----:|------|
| `display_name` | string | ✗ | 표시 이름 |
| `profile_image_url` | string | ✗ | 프로필 이미지 URL |
| `date_of_birth` | string | ✗ | 생년월일 (YYYY-MM-DD) |
| `location_sharing_mode` | string | ✗ | 위치 공유 모드 |

> 위 4개 필드 중 아무것도 전달하지 않으면 현재 사용자 정보를 그대로 반환한다 (변경 없음).

**Response 200**
```json
{
  "success": true,
  "data": {
    "user_id": "string",
    "phone_number": "string",
    "phone_country_code": "string",
    "display_name": "string",
    "profile_image_url": "string | null",
    "date_of_birth": "string | null",
    "location_sharing_mode": "string",
    "last_verification_at": "string (ISO 8601)",
    "created_at": "string (ISO 8601)",
    "last_active_at": "string (ISO 8601)",
    "user_role": "string ('crew' | 'guardian')"
  }
}
```

**Error Codes**

| Code | 설명 |
|------|------|
| 401 | 인증 토큰 없음 또는 만료 |
| 500 | 서버 내부 오류 |

---

#### [PUT] /api/v1/users/me/fcm-token

**인증**: 필요

> ⚠️ **Known Issue**: `users.routes.ts`에서 `PUT /:userId/fcm-token`이 `authenticate` 미들웨어 **이전**에 등록되어, `PUT /me/fcm-token` 요청이 `userId = 'me'`로 `registerFcmTokenForUser` 핸들러에 먼저 매칭된다. 인증 없이 호출 가능하며, `updateFcmToken` 컨트롤러는 사실상 도달 불가이다.

**설명**: 인증된 본인의 FCM 디바이스 토큰을 등록 또는 업데이트한다. 이미 활성 토큰이 있으면 UPDATE, 없으면 INSERT.

**Request Body**
```json
{
  "device_token": "string",
  "platform": "string",
  "device_id": "string",
  "device_model": "string",
  "os_version": "string",
  "app_version": "string"
}
```

| 필드 | 타입 | 필수 | 설명 |
|------|------|:----:|------|
| `device_token` | string | ✅ | FCM 디바이스 토큰 |
| `platform` | string | ✅ | `"ios"` 또는 `"android"` |
| `device_id` | string | ✗ | 기기 고유 식별자 |
| `device_model` | string | ✗ | 기기 모델명 |
| `os_version` | string | ✗ | OS 버전 |
| `app_version` | string | ✗ | 앱 버전 |

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

**Error Codes**

| Code | 설명 |
|------|------|
| 400 | `device_token` 또는 `platform` 누락 |
| 401 | 인증 토큰 없음 또는 만료 |
| 500 | 사용자 미존재 또는 DB 오류 |

---

#### [DELETE] /api/v1/users/me/fcm-token/:tokenId

**인증**: 필요
**설명**: 인증된 본인의 특정 FCM 토큰을 비활성화한다 (`is_active = FALSE`). 물리 삭제는 수행하지 않는다.

**Path Parameters**

| 파라미터 | 타입 | 설명 |
|---------|------|------|
| `tokenId` | string (UUID) | 비활성화할 `tb_device_token.token_id` |

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
| 401 | 인증 토큰 없음 또는 만료 |
| 500 | 서버 내부 오류 |

---

#### [PATCH] /api/v1/users/:id/terms

**인증**: 필요
**설명**: 약관 동의를 기록한다. `tb_user.terms_agreed_at`, `terms_version`을 갱신한다. 요청자 본인의 `:id`만 허용 (타인 ID 사용 시 403).

**Path Parameters**

| 파라미터 | 타입 | 설명 |
|---------|------|------|
| `id` | string | 약관 동의를 기록할 사용자의 Firebase UID. 반드시 인증된 본인 UID와 일치해야 함 |

**Request Body**
```json
{
  "terms_version": "string"
}
```

| 필드 | 타입 | 필수 | 설명 |
|------|------|:----:|------|
| `terms_version` | string | ✅ | 동의한 약관 버전 (예: `"1.0"`) |

**Response 200**
```json
{
  "success": true,
  "data": {
    "terms_agreed_at": "string (ISO 8601)"
  }
}
```

**Error Codes**

| Code | 설명 |
|------|------|
| 400 | `terms_version` 누락 |
| 401 | 인증 토큰 없음 또는 만료 |
| 403 | `:id`가 인증된 본인 UID와 불일치 |
| 500 | 사용자 없음: `"User not found"` — ⚠️ 의미상 404이나 코드가 500 반환 (버그) |
| 500 | 서버 내부 오류 |

---

### §4.B 여행자 (Travelers)

> **기본 경로**: `/api/v1/travelers`
>
> 여행자 등록 및 여행자의 마지막 위치 조회 API를 제공한다.
> 여행자 등록은 테스트용 엔드포인트로 인증 없이 호출 가능하다.

---

#### [POST] /api/v1/travelers/register

**인증**: 불필요
**설명**: 테스트용 여행자 등록. `tb_group_member`에 해당 사용자가 없으면 `crew` 역할로 추가한다. `trip_id`, `group_id` 미전달 시 고정된 테스트용 UUID 사용.

**Request Body**
```json
{
  "user_id": "string",
  "trip_id": "string",
  "group_id": "string"
}
```

| 필드 | 타입 | 필수 | 설명 |
|------|------|:----:|------|
| `user_id` | string | ✅ | 여행자로 등록할 사용자의 Firebase UID |
| `trip_id` | string | ✗ | 여행 UUID. 미전달 시 기본값 `00000000-0000-0000-0000-000000000001` |
| `group_id` | string | ✗ | 그룹 UUID. 미전달 시 기본값 `00000000-0000-0000-0000-000000000002` |

**Response 201**
```json
{
  "success": true,
  "data": {
    "user_id": "string",
    "trip_id": "string (UUID)",
    "group_id": "string (UUID)",
    "display_name": "string"
  },
  "message": "Traveler registered successfully"
}
```

**Error Codes**

| Code | 설명 |
|------|------|
| 400 | `user_id` 누락 |
| 500 | 서버 내부 오류 |

---

#### [GET] /api/v1/travelers/:travelerId/last-location

**인증**: 필요
**설명**: 특정 여행자의 마지막 위치 정보를 조회한다. 가디언이 여행자 위치를 조회하는 데 사용된다.

> **참고**: 가디언 권한 검증 로직은 현재 미구현(TODO). 인증만 통과하면 조회 가능.

**Path Parameters**

| 파라미터 | 타입 | 설명 |
|---------|------|------|
| `travelerId` | string | 위치를 조회할 여행자의 Firebase UID (`tb_location.user_id`) |

**Response 200**
```json
{
  "success": true,
  "data": {
    "traveler_id": "string",
    "latitude": "number",
    "longitude": "number",
    "recorded_at": "string (ISO 8601)",
    "address": "string | null"
  }
}
```

| 필드 | 타입 | 설명 |
|------|------|------|
| `traveler_id` | string | 조회한 여행자의 Firebase UID |
| `latitude` | number | 위도 (float) |
| `longitude` | number | 경도 (float) |
| `recorded_at` | string | 위치 기록 시각 |
| `address` | string \| null | 역지오코딩 주소 (없으면 null) |

**Error Codes**

| Code | 설명 |
|------|------|
| 401 | 인증 토큰 없음 또는 만료 |
| 404 | 해당 여행자의 위치 기록 없음 |
| 500 | 서버 내부 오류 |

---

## §5. 여행 (Trips)

> **기본 경로**: `/api/v1/trips`
>
> 여행 생성·조회·참여·초대 코드 관리·설정 변경 등 핵심 도메인 API를 제공한다.
> 초대 코드 기반 조회·미리보기는 인증 없이 호출 가능하며,
> 여행 생성·설정 변경·마이 트립 조회는 Firebase ID Token이 필요하다.
> 보호자 승인 흐름 관련 엔드포인트는 인증 미들웨어 없이도 동작하나,
> `user_id`를 토큰 또는 Request Body/Query Parameter로 반드시 전달해야 한다.

> **초대코드 체계 구분**: SafeTrip에는 두 가지 초대코드 체계가 공존한다.
>
> | 체계 | 저장 테이블 | 생성 시점 | 사용 엔드포인트 |
> |------|------------|----------|----------------|
> | 그룹 초대코드 | `tb_group.invite_code` | 여행 생성 시 자동 | `/trips/invite/:inviteCode`, `/trips/join`, `/trips/verify-invite-code/:code` |
> | 범용 초대코드 | `tb_invite_code` 별도 테이블 | `POST /groups/:groupId/invite-codes` 호출 시 | `/trips/preview/:code` |

---

### §5.A 여행 미리보기 및 조회

---

#### [GET] /api/v1/trips/preview/:code

**인증**: 불필요
**설명**: 초대 코드(`tb_invite_code`)로 여행 미리보기 정보를 반환한다. 코드 prefix로 참여 역할을 결정한다 (`A` → `crew_chief`, `V` → `guardian`, `M` 또는 기타 → `crew`).

> **초대 코드 유효 조건**: `is_active = TRUE`, `expires_at > NOW()`, `used_count < max_uses`

**Path Parameters**

| 파라미터 | 타입 | 설명 |
|---------|------|------|
| `code` | string | 초대 코드 (6~20자) |

**Response 200**
```json
{
  "success": true,
  "data": {
    "trip_id": "string (UUID)",
    "trip_name": "string",
    "country_name": "string",
    "start_date": "string (YYYY-MM-DD)",
    "end_date": "string (YYYY-MM-DD)",
    "captain_name": "string",
    "member_count": "number",
    "role": "string ('crew_chief' | 'crew' | 'guardian')"
  }
}
```

| 필드 | 타입 | 설명 |
|------|------|------|
| `trip_id` | string | 여행 UUID |
| `trip_name` | string | 그룹명 (`group_name`). 없으면 `country_name` fallback |
| `country_name` | string | 여행 국가명 (`tb_trip.country_name`) |
| `start_date` | string | 여행 시작일 (YYYY-MM-DD) |
| `end_date` | string | 여행 종료일 (YYYY-MM-DD) |
| `captain_name` | string | 그룹 소유자(`owner_user_id`)의 `display_name`. 없으면 `phone_number` fallback |
| `member_count` | number | 현재 활성 멤버 수 (`tb_group_member.status = 'active'`) |
| `role` | string | 초대 코드 prefix 기반 참여 예정 역할 |

**Error Codes**

| Code | 설명 |
|------|------|
| 400 | `code` 길이 6자 미만 또는 20자 초과: `"Invalid invite code"` |
| 404 | 코드가 존재하지 않거나 만료됨: `"Trip not found or invalid code"` |
| 500 | 서버 내부 오류 |

---

#### [GET] /api/v1/trips/invite/:inviteCode

**인증**: 불필요
**설명**: 여행자용 초대 코드(`tb_group.invite_code`)로 여행 정보를 조회한다. 그룹의 start_date 기준 첫 번째 여행을 반환한다.

**Path Parameters**

| 파라미터 | 타입 | 설명 |
|---------|------|------|
| `inviteCode` | string | 여행자용 그룹 초대 코드 (`tb_group.invite_code`) |

**Response 200**
```json
{
  "success": true,
  "data": {
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
    "title": "string",
    "invite_code": "string"
  }
}
```

| 필드 | 타입 | 설명 |
|------|------|------|
| `trip_id` | string | 여행 UUID |
| `group_id` | string | 그룹 UUID |
| `country_code` | string | 국가 코드 |
| `country_name` | string | 국가명 (`tb_trip.country_name`) |
| `country_name_ko` | string | 국가명 한국어 (현재 `country_name`과 동일 값) |
| `destination_city` | string \| null | 목적지 도시 |
| `start_date` | string | 여행 시작일 (YYYY-MM-DD) |
| `end_date` | string | 여행 종료일 (YYYY-MM-DD) |
| `trip_type` | string | 여행 유형 |
| `status` | string | 여행 상태 |
| `title` | string | 그룹명 (`tb_group.group_name`) |
| `invite_code` | string | 조회에 사용된 초대 코드 |

**Error Codes**

| Code | 설명 |
|------|------|
| 400 | `inviteCode` 누락 |
| 404 | 유효하지 않은 초대 코드 또는 그룹/여행 없음 |
| 500 | 서버 내부 오류 |

---

#### [GET] /api/v1/trips/guardian-invite/:inviteCode

**인증**: 불필요
**설명**: 보호자용 초대 코드(`tb_guardian.guardian_invite_code`)로 여행 정보 및 보호 대상 여행자 정보를 조회한다.

**Path Parameters**

| 파라미터 | 타입 | 설명 |
|---------|------|------|
| `inviteCode` | string | 보호자용 초대 코드 (`tb_guardian.guardian_invite_code`) |

**Response 200**
```json
{
  "success": true,
  "data": {
    "trip": {
      "trip_id": "string (UUID)",
      "country_name": "string",
      "start_date": "string (YYYY-MM-DD)",
      "end_date": "string (YYYY-MM-DD)"
    },
    "traveler": {
      "user_id": "string",
      "display_name": "string",
      "phone_number": "string"
    }
  }
}
```

> **참고**: `trip` 및 `traveler` 객체의 세부 필드는 `guardianService.getGuardianByInviteCode()` 구현에 따라 달라질 수 있다.

**Error Codes**

| Code | 설명 |
|------|------|
| 400 | `inviteCode` 누락 |
| 404 | 유효하지 않은 보호자 초대 코드 |
| 500 | 서버 내부 오류 |

---

#### [GET] /api/v1/trips/verify-invite-code/:code

**인증**: 불필요
**설명**: 여행자용 초대 코드(`tb_group.invite_code`)의 존재 여부를 확인한다. 실제 참여 전 유효성 사전 검증 용도.

**Path Parameters**

| 파라미터 | 타입 | 설명 |
|---------|------|------|
| `code` | string | 검증할 초대 코드 |

**Response 200**
```json
{
  "success": true,
  "data": {
    "exists": "boolean",
    "expired": "boolean (optional)"
  }
}
```

| 필드 | 타입 | 설명 |
|------|------|------|
| `exists` | boolean | 코드가 유효하면 `true`, 없으면 `false` |
| `expired` | boolean | 코드가 만료된 경우에만 포함되며 `true` |

**Error Codes**

| Code | 설명 |
|------|------|
| 400 | `code` 누락 |
| 500 | 서버 내부 오류 |

---

#### [GET] /api/v1/trips/:tripId

**인증**: 불필요
**설명**: `trip_id`(UUID)로 여행 상세 정보를 조회한다.

**Path Parameters**

| 파라미터 | 타입 | 설명 |
|---------|------|------|
| `tripId` | string (UUID) | 조회할 여행의 UUID |

**Response 200**
```json
{
  "success": true,
  "data": {
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
```

| 필드 | 타입 | 설명 |
|------|------|------|
| `trip_id` | string | 여행 UUID |
| `group_id` | string | 그룹 UUID |
| `country_code` | string | 국가 코드 |
| `country_name` | string | 국가명 |
| `country_name_ko` | string | 국가명 한국어 (현재 `country_name`과 동일 값) |
| `destination_city` | string \| null | 목적지 도시 |
| `start_date` | string | 여행 시작일 (YYYY-MM-DD) |
| `end_date` | string | 여행 종료일 (YYYY-MM-DD) |
| `trip_type` | string | 여행 유형 |
| `status` | string | 여행 상태 |
| `title` | string | 그룹명 (`tb_group.group_name`) |

**Error Codes**

| Code | 설명 |
|------|------|
| 404 | 해당 `tripId` 여행 없음 |
| 500 | 서버 내부 오류 |

---

#### [GET] /api/v1/trips/groups/:group_id

**인증**: 불필요
**설명**: `group_id`로 연결된 여행 중 `start_date`가 가장 빠른 첫 번째 여행 정보를 조회한다.

**Path Parameters**

| 파라미터 | 타입 | 설명 |
|---------|------|------|
| `group_id` | string (UUID) | 그룹 UUID |

**Response 200**
```json
{
  "success": true,
  "data": {
    "trip_id": "string (UUID)",
    "group_id": "string (UUID)",
    "country_code": "string",
    "country_name": "string",
    "destination_city": "string | null",
    "start_date": "string (YYYY-MM-DD)",
    "end_date": "string (YYYY-MM-DD)",
    "trip_type": "string",
    "status": "string"
  }
}
```

**Error Codes**

| Code | 설명 |
|------|------|
| 400 | `group_id` 누락 |
| 404 | 해당 그룹에 연결된 여행 없음 |
| 500 | 서버 내부 오류 |

---

#### [GET] /api/v1/trips/users/:user_id/trips

**인증**: 필요
**설명**: 인증된 사용자가 속한 모든 여행 목록을 역할 정보와 함께 반환한다. `tb_group_member.trip_id` 기반으로 JOIN하며, 가입일(`joined_at`) 내림차순 정렬.

**Path Parameters**

| 파라미터 | 타입 | 설명 |
|---------|------|------|
| `user_id` | string | 조회할 사용자의 Firebase UID |

**Response 200**
```json
{
  "success": true,
  "data": [
    {
      "trip_id": "string (UUID)",
      "group_id": "string (UUID)",
      "group_name": "string",
      "member_role": "string",
      "is_admin": "boolean",
      "country_code": "string | null",
      "country_name": "string | null",
      "destination_city": "string | null",
      "start_date": "string (YYYY-MM-DD) | null",
      "end_date": "string (YYYY-MM-DD) | null",
      "trip_status": "string",
      "member_count": "number",
      "joined_at": "string (ISO 8601)"
    }
  ]
}
```

| 필드 | 타입 | 설명 |
|------|------|------|
| `trip_id` | string | 여행 UUID |
| `group_id` | string | 그룹 UUID |
| `group_name` | string | 그룹명 (`tb_group.group_name`) |
| `member_role` | string | 해당 여행에서의 역할 (`captain`, `crew_chief`, `crew`, `guardian`) |
| `is_admin` | boolean | `member_role`이 `captain` 또는 `crew_chief`이면 `true` |
| `country_code` | string \| null | 국가 코드 |
| `country_name` | string \| null | 국가명 |
| `destination_city` | string \| null | 목적지 도시 |
| `start_date` | string \| null | 여행 시작일 (YYYY-MM-DD) |
| `end_date` | string \| null | 여행 종료일 (YYYY-MM-DD) |
| `trip_status` | string | 여행 상태 (`tb_trip.status`) |
| `member_count` | number | 해당 여행의 활성 멤버 수 |
| `joined_at` | string | 해당 그룹 가입 시각 |

**Error Codes**

| Code | 설명 |
|------|------|
| 400 | `user_id` 누락 |
| 401 | 인증 토큰 없음 또는 만료 |
| 500 | 서버 내부 오류 |

---

### §5.B 국가 및 타임존 조회

---

#### [GET] /api/v1/trips/groups/:group_id/countries

**인증**: 불필요
**설명**: `group_id`로 연결된 모든 여행의 국가 코드 목록을 `start_date` 오름차순으로 반환한다. 각 국가별 집계된 여행 기간(min start_date ~ max end_date)도 포함된다.

**Path Parameters**

| 파라미터 | 타입 | 설명 |
|---------|------|------|
| `group_id` | string (UUID) | 그룹 UUID |

**Response 200**
```json
{
  "success": true,
  "data": {
    "group_id": "string (UUID)",
    "countries": [
      {
        "country_code": "string",
        "start_date": "string (YYYY-MM-DD)",
        "end_date": "string (YYYY-MM-DD)"
      }
    ],
    "country_codes": ["string"],
    "count": "number"
  }
}
```

| 필드 | 타입 | 설명 |
|------|------|------|
| `group_id` | string | 요청한 그룹 UUID |
| `countries` | array | 국가별 상세 목록 (코드 + 날짜 범위) |
| `country_codes` | array | `countries[].country_code` 만 추출한 배열 (하위 호환성 유지) |
| `count` | number | 국가 수 |

**Error Codes**

| Code | 설명 |
|------|------|
| 400 | `group_id` 누락 |
| 500 | 서버 내부 오류 |

---

#### [GET] /api/v1/trips/users/:user_id/countries

**인증**: 불필요
**설명**: `user_id`가 속한 모든 그룹의 여행 국가 코드를 중복 제거 후 `start_date` 오름차순으로 반환한다.

**Path Parameters**

| 파라미터 | 타입 | 설명 |
|---------|------|------|
| `user_id` | string | Firebase UID |

**Response 200**
```json
{
  "success": true,
  "data": {
    "user_id": "string",
    "country_codes": ["string"],
    "count": "number"
  }
}
```

**Error Codes**

| Code | 설명 |
|------|------|
| 400 | `user_id` 누락 |
| 500 | 서버 내부 오류 |

---

#### [GET] /api/v1/trips/groups/:group_id/timezones

**인증**: 불필요
**설명**: `group_id`로 연결된 모든 여행의 타임존 정보를 반환한다. 한국(`KOR`, `Asia/Seoul`)이 항상 첫 번째로 포함되며, 이후 여행 일정 순(start_date ASC)으로 정렬된다. 동일 타임존은 중복 제거.

> **TB_COUNTRY 의존성**: `TB_COUNTRY.is_active = TRUE`이고 `timezone IS NOT NULL`인 국가만 포함된다. `tb_country` 테이블이 없는 환경에서는 500 에러가 발생할 수 있다.

**Path Parameters**

| 파라미터 | 타입 | 설명 |
|---------|------|------|
| `group_id` | string (UUID) | 그룹 UUID |

**Response 200**
```json
{
  "success": true,
  "data": {
    "group_id": "string (UUID)",
    "timezones": [
      {
        "timezone": "string",
        "country_code": "string",
        "country_name_ko": "string | null",
        "country_name_en": "string",
        "utc_offset": "string | null",
        "is_current": "boolean",
        "order": "number",
        "start_date": "string (YYYY-MM-DD, optional)",
        "end_date": "string (YYYY-MM-DD, optional)"
      }
    ],
    "count": "number"
  }
}
```

| 필드 | 타입 | 설명 |
|------|------|------|
| `timezone` | string | IANA 타임존 이름 (예: `"Asia/Seoul"`) |
| `country_code` | string | 국가 코드 |
| `country_name_ko` | string \| null | 국가명 한국어 |
| `country_name_en` | string | 국가명 영어 |
| `utc_offset` | string \| null | UTC 오프셋 (예: `"+09:00"`) |
| `is_current` | boolean | 한국 타임존이면 `true` |
| `order` | number | 정렬 순서 (한국=0, 이후 여행 순) |
| `start_date` | string \| null | 해당 국가 여행 시작일. 한국은 미포함 |
| `end_date` | string \| null | 해당 국가 여행 종료일. 한국은 미포함 |

**Error Codes**

| Code | 설명 |
|------|------|
| 400 | `group_id` 누락 |
| 500 | 서버 내부 오류 (TB_COUNTRY 없음 포함) |

---

### §5.C 여행 생성 및 참여

---

#### [POST] /api/v1/trips

**인증**: 필요
**설명**: 새 여행을 생성한다. 내부적으로 `tb_group`을 먼저 생성하고, `tb_trip`을 연결한 뒤, 생성자를 `captain` 역할로 `tb_group_member`에 추가한다. 그룹 초대 코드는 자동 생성(6~8자리 영숫자 대문자).

**Request Body**
```json
{
  "title": "string",
  "country_code": "string",
  "country_name": "string",
  "trip_type": "string",
  "start_date": "string",
  "end_date": "string"
}
```

| 필드 | 타입 | 필수 | 설명 |
|------|------|:----:|------|
| `title` | string | ✅ | 여행 제목 (`tb_group.group_name`으로 저장) |
| `country_code` | string | ✅ | 국가 코드 (예: `"KOR"`, `"JPN"`) |
| `country_name` | string | ✗ | 국가명. 미전달 또는 빈 문자열이면 `country_code` 대문자값 사용 |
| `trip_type` | string | ✅ | 여행 유형 |
| `start_date` | string | ✅ | 여행 시작일 (YYYY-MM-DD) |
| `end_date` | string | ✅ | 여행 종료일 (YYYY-MM-DD) |

**Response 200**
```json
{
  "success": true,
  "data": {
    "trip_id": "string (UUID)",
    "group_id": "string (UUID)",
    "invite_code": "string"
  }
}
```

| 필드 | 타입 | 설명 |
|------|------|------|
| `trip_id` | string | 생성된 여행 UUID (`tb_trip.trip_id`) |
| `group_id` | string | 생성된 그룹 UUID (`tb_group.group_id`) |
| `invite_code` | string | 생성된 여행자 초대 코드 (6~8자리 영숫자 대문자) |

**Error Codes**

| Code | 설명 |
|------|------|
| 400 | 필수 필드(`title`, `country_code`, `trip_type`, `start_date`, `end_date`) 중 하나 이상 누락 |
| 401 | 인증 토큰 없음 또는 만료 |
| 500 | 서버 내부 오류 |

---

#### [POST] /api/v1/trips/join

**인증**: 불필요 (단, `user_id`를 토큰 또는 Request Body로 전달해야 함)
**설명**: 여행자 초대 코드로 그룹에 `crew` 역할로 참여한다. 이미 멤버인 경우에도 `joined_at`이 업데이트된다.

> **최대 멤버 수 제한**: 신규 멤버 추가 시 `tb_group.current_member_count >= tb_group.max_members`이면 400 반환.

**Request Body**
```json
{
  "invite_code": "string",
  "user_id": "string"
}
```

| 필드 | 타입 | 필수 | 설명 |
|------|------|:----:|------|
| `invite_code` | string | ✅ | 그룹 초대 코드 (`tb_group.invite_code`) |
| `user_id` | string | 조건부 | 인증 토큰이 없는 경우 필수. Firebase UID |

**Response 200**
```json
{
  "success": true,
  "data": {
    "group_id": "string (UUID)",
    "member_id": "string (UUID)"
  }
}
```

| 필드 | 타입 | 설명 |
|------|------|------|
| `group_id` | string | 참여한 그룹 UUID |
| `member_id` | string | 생성/업데이트된 `tb_group_member.member_id` |

**Error Codes**

| Code | 설명 |
|------|------|
| 400 | `user_id` 누락 |
| 400 | `invite_code` 누락 |
| 400 | 그룹 최대 멤버 수 초과: `"Group has reached maximum member limit"` |
| 404 | 유효하지 않은 초대 코드 |
| 500 | 서버 내부 오류 |

---

#### [POST] /api/v1/trips/guardian-join

**인증**: 불필요 (단, `user_id`를 토큰 또는 Request Body로 전달해야 함)
**설명**: 보호자 초대 코드로 보호자로 참여한다. `tb_guardian.guardian_user_id`를 설정하고 `invite_status`를 `accepted`로 변경한다. 해당 여행 그룹에 `guardian` 역할 멤버로도 추가된다.

> **이미 승인된 보호자**: `invite_status = 'accepted'`이고 동일 `user_id`이면 400 반환.

**Request Body**
```json
{
  "invite_code": "string",
  "user_id": "string"
}
```

| 필드 | 타입 | 필수 | 설명 |
|------|------|:----:|------|
| `invite_code` | string | ✅ | 보호자 초대 코드 (`tb_guardian.guardian_invite_code`) |
| `user_id` | string | 조건부 | 인증 토큰이 없는 경우 필수. Firebase UID |

**Response 200**
```json
{
  "success": true,
  "data": {
    "guardian_id": "string (UUID)",
    "group_id": "string (UUID) | null"
  }
}
```

| 필드 | 타입 | 설명 |
|------|------|------|
| `guardian_id` | string | `tb_guardian.guardian_id` |
| `group_id` | string \| null | 참여한 그룹 UUID. 여행 정보가 없으면 `null` |

**Error Codes**

| Code | 설명 |
|------|------|
| 400 | `user_id` 누락 |
| 400 | `invite_code` 누락 |
| 400 | 이미 승인된 보호자: `"Guardian is already accepted"` |
| 404 | 유효하지 않은 보호자 초대 코드 |
| 500 | 서버 내부 오류 |

---

### §5.D 보호자 승인 흐름

---

#### [POST] /api/v1/trips/guardian-approval/request

**인증**: 불필요 (단, `user_id`를 토큰 또는 Request Body로 전달해야 함)
**설명**: 여행자가 보호자에게 승인 요청을 보낸다. `tb_guardian` 레코드를 생성하고 보호자 초대 코드를 반환한다.

> **SMS 전송 미구현**: 보호자 초대 코드를 SMS로 전송하는 기능은 TODO 상태. 현재 응답에서 코드를 직접 확인해야 한다.

**Request Body**
```json
{
  "invite_code": "string",
  "guardian_phone": "string",
  "user_id": "string"
}
```

| 필드 | 타입 | 필수 | 설명 |
|------|------|:----:|------|
| `invite_code` | string | ✅ | 여행자용 그룹 초대 코드 (`tb_group.invite_code`) |
| `guardian_phone` | string | ✅ | 보호자 전화번호 (E.164 형식) |
| `user_id` | string | 조건부 | 인증 토큰이 없는 경우 필수. 여행자의 Firebase UID |

**Response 200**
```json
{
  "success": true,
  "data": {
    "guardian_id": "string (UUID)",
    "guardian_invite_code": "string",
    "message": "Guardian approval request sent"
  }
}
```

| 필드 | 타입 | 설명 |
|------|------|------|
| `guardian_id` | string | 생성된 `tb_guardian.guardian_id` |
| `guardian_invite_code` | string | 보호자용 초대 코드 (보호자에게 전달해야 함) |
| `message` | string | 고정 메시지 `"Guardian approval request sent"` |

**Error Codes**

| Code | 설명 |
|------|------|
| 400 | `user_id` 누락 |
| 400 | `invite_code` 또는 `guardian_phone` 누락 |
| 404 | 유효하지 않은 초대 코드 |
| 500 | 보호자 초대 레코드 생성 실패 또는 서버 내부 오류 |

---

#### [GET] /api/v1/trips/guardian-approval/status

> ⚠️ **Known Issue**: `trips.routes.ts`에서 `GET /:tripId`가 이 라우트보다 먼저 등록되어 있어,
> NestJS 라우팅 우선순위상 이 엔드포인트는 현재 `GET /:tripId`(`tripId='guardian-approval'`)로
> 매칭된다. 결과적으로 항상 404를 반환한다. 라우트 등록 순서 수정이 필요하다.

**인증**: 불필요 (단, `user_id`를 토큰 또는 Query Parameter로 전달해야 함)
**설명**: 여행자의 가장 최근 보호자 승인 요청 상태를 조회한다. (`pending`, `approved`, `rejected`, `none`)

> **상태 변환**: `tb_guardian.invite_status = 'accepted'`는 응답에서 `'approved'`로 변환하여 반환한다.

**Query Parameters**

| 파라미터 | 타입 | 필수 | 기본값 | 설명 |
|---------|------|:----:|:------:|------|
| `user_id` | string | 조건부 | — | 인증 토큰이 없는 경우 필수. 여행자의 Firebase UID |

**Response 200**
```json
{
  "success": true,
  "data": {
    "status": "string",
    "guardian_invite_code": "string | null",
    "accepted_at": "string (ISO 8601) | null",
    "created_at": "string (ISO 8601)"
  }
}
```

| 필드 | 타입 | 설명 |
|------|------|------|
| `status` | string | `'pending'` / `'approved'` / `'rejected'` / `'none'` |
| `guardian_invite_code` | string \| null | 보호자 초대 코드. `status = 'none'`이면 미포함 |
| `accepted_at` | string \| null | 승인 시각. 미승인 시 `null` |
| `created_at` | string | 요청 생성 시각. `status = 'none'`이면 미포함 |

> **`status = 'none'`인 경우** (승인 요청 없을 때):
> ```json
> {
>   "success": true,
>   "data": {
>     "status": "none"
>   }
> }
> ```

**Error Codes**

| Code | 설명 |
|------|------|
| 400 | `user_id` 누락 |
| 500 | 서버 내부 오류 |

---

#### [GET] /api/v1/trips/guardian-approval/pending

> ⚠️ **Known Issue**: `trips.routes.ts`에서 `GET /:tripId`가 이 라우트보다 먼저 등록되어 있어,
> NestJS 라우팅 우선순위상 이 엔드포인트는 현재 `GET /:tripId`(`tripId='guardian-approval'`)로
> 매칭된다. 결과적으로 항상 404를 반환한다. 라우트 등록 순서 수정이 필요하다.

**인증**: 불필요
**설명**: 보호자가 초대 코드를 사용해 승인 대기 중인 여행자 참여 요청 목록을 조회한다. 만료되지 않은 `pending` 상태 요청만 반환한다.

**Query Parameters**

| 파라미터 | 타입 | 필수 | 기본값 | 설명 |
|---------|------|:----:|:------:|------|
| `invite_code` | string | ✅ | — | 보호자 초대 코드 (`tb_guardian.guardian_invite_code`). 대소문자 구분 없음 |

**Response 200**
```json
{
  "success": true,
  "data": [
    {
      "request_id": "string (UUID)",
      "traveler_user_id": "string",
      "guardian_invite_code": "string",
      "invite_status": "string",
      "created_at": "string (ISO 8601)",
      "traveler_name": "string | null",
      "traveler_phone": "string | null",
      "date_of_birth": "string (YYYY-MM-DD) | null",
      "trip_id": "string (UUID) | null",
      "country_code": "string | null",
      "country_name": "string | null",
      "destination_city": "string | null",
      "start_date": "string (YYYY-MM-DD) | null",
      "end_date": "string (YYYY-MM-DD) | null"
    }
  ]
}
```

| 필드 | 타입 | 설명 |
|------|------|------|
| `request_id` | string | `tb_guardian.guardian_id` |
| `traveler_user_id` | string | 여행자 Firebase UID |
| `guardian_invite_code` | string | 조회에 사용된 보호자 초대 코드 |
| `invite_status` | string | 현재 상태 (`pending`) |
| `traveler_name` | string \| null | 여행자 표시 이름 |
| `traveler_phone` | string \| null | 여행자 전화번호 |
| `date_of_birth` | string \| null | 여행자 생년월일 |
| `trip_id` | string \| null | 연결된 여행 UUID |
| `country_code` | string \| null | 국가 코드 |
| `country_name` | string \| null | 국가명 |
| `destination_city` | string \| null | 목적지 도시 |
| `start_date` | string \| null | 여행 시작일 (YYYY-MM-DD) |
| `end_date` | string \| null | 여행 종료일 (YYYY-MM-DD) |

**Error Codes**

| Code | 설명 |
|------|------|
| 400 | `invite_code` 누락 |
| 500 | 서버 내부 오류 |

---

#### [POST] /api/v1/trips/guardian-approval/:requestId/approve

**인증**: 불필요
**설명**: 보호자가 특정 여행자 참여 요청을 승인한다. `tb_guardian.invite_status`를 `accepted`로 변경하고 `accepted_at`을 기록한다.

> **검증 조건**: `guardian_id = requestId`, 초대 코드 일치(대소문자 무시), `invite_status = 'pending'`, 만료 미경과 조건을 모두 충족해야 한다.

**Path Parameters**

| 파라미터 | 타입 | 설명 |
|---------|------|------|
| `requestId` | string (UUID) | 승인할 `tb_guardian.guardian_id` |

**Request Body**
```json
{
  "invite_code": "string"
}
```

| 필드 | 타입 | 필수 | 설명 |
|------|------|:----:|------|
| `invite_code` | string | ✅ | 보호자 초대 코드 (`tb_guardian.guardian_invite_code`). 검증용 |

**Response 200**
```json
{
  "success": true,
  "data": {
    "message": "Traveler join request approved",
    "guardian_id": "string (UUID)"
  }
}
```

**Error Codes**

| Code | 설명 |
|------|------|
| 400 | `invite_code` 누락 |
| 404 | 요청 없음, 이미 처리됨, 코드 불일치, 또는 만료: `"Guardian request not found or already processed"` |
| 500 | 서버 내부 오류 |

---

#### [POST] /api/v1/trips/guardian-approval/:requestId/reject

**인증**: 불필요
**설명**: 보호자가 특정 여행자 참여 요청을 거부한다. `tb_guardian.invite_status`를 `rejected`로 변경한다.

> **검증 조건**: `guardian_id = requestId`, 초대 코드 일치(대소문자 무시), `invite_status = 'pending'`, 만료 미경과 조건을 모두 충족해야 한다.

**Path Parameters**

| 파라미터 | 타입 | 설명 |
|---------|------|------|
| `requestId` | string (UUID) | 거부할 `tb_guardian.guardian_id` |

**Request Body**
```json
{
  "invite_code": "string"
}
```

| 필드 | 타입 | 필수 | 설명 |
|------|------|:----:|------|
| `invite_code` | string | ✅ | 보호자 초대 코드. 검증용 |

**Response 200**
```json
{
  "success": true,
  "data": {
    "message": "Traveler join request rejected",
    "guardian_id": "string (UUID)"
  }
}
```

**Error Codes**

| Code | 설명 |
|------|------|
| 400 | `invite_code` 누락 |
| 404 | 요청 없음, 이미 처리됨, 코드 불일치, 또는 만료 |
| 500 | 서버 내부 오류 |

---

#### [POST] /api/v1/trips/guardian-approval/cancel

**인증**: 불필요 (단, `user_id`를 토큰 또는 Request Body로 전달해야 함)
**설명**: 여행자가 본인의 `pending` 상태 보호자 승인 요청을 취소한다. 해당 레코드를 `tb_guardian`에서 물리 삭제한다.

> **이미 취소된 경우**: `pending` 요청이 없으면 에러 없이 `"No pending request found"` 메시지로 200 반환.

**Request Body**
```json
{
  "user_id": "string"
}
```

| 필드 | 타입 | 필수 | 설명 |
|------|------|:----:|------|
| `user_id` | string | 조건부 | 인증 토큰이 없는 경우 필수. 취소할 요청의 여행자 Firebase UID |

**Response 200**
```json
{
  "success": true,
  "data": {
    "message": "Guardian approval request cancelled"
  }
}
```

또는 pending 요청이 없는 경우:
```json
{
  "success": true,
  "data": {
    "message": "No pending request found"
  }
}
```

**Error Codes**

| Code | 설명 |
|------|------|
| 401 | `user_id` 누락 (토큰도 없고 body도 없음): `"User authentication required"` |
| 500 | 서버 내부 오류 |

---

### §5.E 초대 코드 관리

---

#### [GET] /api/v1/trips/:tripId/invite-code

**인증**: 필요 (라우트에 `authenticate` 미들웨어 미적용이나, 컨트롤러 내부에서 `req.userId` 없으면 즉시 401. `Authorization: Bearer <token>` 헤더 필수.)
**설명**: 여행에 연결된 그룹의 초대 코드를 조회한다. `captain` 또는 `crew_chief` 역할만 허용.

> **권한 조건**: `tb_group_member.member_role IN ('captain', 'crew_chief')` 이어야 한다.

**Path Parameters**

| 파라미터 | 타입 | 설명 |
|---------|------|------|
| `tripId` | string (UUID) | 여행 UUID |

**Response 200**
```json
{
  "success": true,
  "data": {
    "trip_id": "string (UUID)",
    "group_id": "string (UUID)",
    "invite_code": "string"
  }
}
```

**Error Codes**

| Code | 설명 |
|------|------|
| 400 | `tripId` 누락 |
| 401 | `user_id`를 확인할 수 없음 |
| 403 | `captain` 또는 `crew_chief` 역할 아님: `"Admin permission required"` |
| 404 | 여행 없음 또는 그룹 없음 |
| 500 | 서버 내부 오류 |

---

#### [POST] /api/v1/trips/:tripId/regenerate-invite-code

**인증**: 필요 (라우트에 `authenticate` 미들웨어 미적용이나, 컨트롤러 내부에서 `req.userId` 없으면 즉시 401. `Authorization: Bearer <token>` 헤더 필수.)
**설명**: 여행 그룹의 초대 코드를 새로 생성하여 교체한다. `captain` 또는 `crew_chief` 역할만 허용. 기존 코드로 생성된 초대 링크는 모두 무효화된다.

> **신규 코드 형식**: 6~8자리 영숫자 대문자 (예: `"ABCD12"` ~ `"ABCDEFGH"`)

**Path Parameters**

| 파라미터 | 타입 | 설명 |
|---------|------|------|
| `tripId` | string (UUID) | 여행 UUID |

**Request Body**: 없음

**Response 200**
```json
{
  "success": true,
  "data": {
    "trip_id": "string (UUID)",
    "group_id": "string (UUID)",
    "invite_code": "string",
    "message": "Invite code regenerated successfully"
  }
}
```

**Error Codes**

| Code | 설명 |
|------|------|
| 400 | `tripId` 누락 |
| 401 | `user_id`를 확인할 수 없음 |
| 403 | `captain` 또는 `crew_chief` 역할 아님 |
| 404 | 여행 없음 |
| 500 | 서버 내부 오류 |

---

### §5.F 여행 설정

---

#### [GET] /api/v1/trips/:tripId/settings

**인증**: 필요
**설명**: 여행 설정을 조회한다. 설정 레코드가 없으면 기본값(`captain_receive_guardian_msg: true`)을 반환한다. 해당 여행의 멤버만 접근 가능.

**Path Parameters**

| 파라미터 | 타입 | 설명 |
|---------|------|------|
| `tripId` | string (UUID) | 여행 UUID |

**Response 200**
```json
{
  "success": true,
  "data": {
    "trip_id": "string (UUID)",
    "captain_receive_guardian_msg": "boolean"
  }
}
```

| 필드 | 타입 | 설명 |
|------|------|------|
| `trip_id` | string | 여행 UUID |
| `captain_receive_guardian_msg` | boolean | 캡틴이 가디언 메시지를 수신하는지 여부. 기본값 `true` |

**Error Codes**

| Code | 설명 |
|------|------|
| 401 | 인증 토큰 없음 또는 만료 |
| 403 | 해당 여행의 멤버가 아님: `"Access denied: not a member of this trip"` |
| 404 | 여행 없음 |
| 500 | 서버 내부 오류 |

---

#### [PATCH] /api/v1/trips/:tripId/settings

**인증**: 필요
**설명**: 여행 설정을 변경한다. `captain` 역할 전용. 현재 변경 가능한 설정은 `captain_receive_guardian_msg`(가디언 메시지 수신 ON/OFF)뿐이다. 설정이 없으면 UPSERT.

> **미들웨어**: `authenticate` + `requireTripCaptain` 이중 적용. `requireTripCaptain`은 해당 여행의 `captain` 역할 여부를 검증한다.

**Path Parameters**

| 파라미터 | 타입 | 설명 |
|---------|------|------|
| `tripId` | string (UUID) | 여행 UUID |

**Request Body**
```json
{
  "captain_receive_guardian_msg": "boolean"
}
```

| 필드 | 타입 | 필수 | 설명 |
|------|------|:----:|------|
| `captain_receive_guardian_msg` | boolean | ✅ | `true` = 가디언 메시지 수신 ON, `false` = OFF |

**Response 200**
```json
{
  "success": true,
  "data": {
    "trip_id": "string (UUID)",
    "captain_receive_guardian_msg": "boolean"
  },
  "message": "설정이 업데이트되었습니다"
}
```

**Error Codes**

| Code | 설명 |
|------|------|
| 400 | `captain_receive_guardian_msg`가 boolean 타입이 아님: `"captain_receive_guardian_msg must be a boolean"` |
| 401 | 인증 토큰 없음 또는 만료 |
| 403 | `captain` 역할 아님 (`requireTripCaptain` 미들웨어 거부) |
| 500 | 서버 내부 오류 |

---



---

## §5 Auth, Users (Generated)


### Path: /api/v1/auth/firebase-verify
#### [POST] /api/v1/auth/firebase-verify
**Summary**: Firebase Token verify & User UPSERT


### Path: /api/v1/auth/logout
#### [POST] /api/v1/auth/logout
**Summary**: 로그아웃 처리


### Path: /api/v1/auth/verify
#### [POST] /api/v1/auth/verify
**Summary**: 토큰 검증 + 사용자 정보 반환


### Path: /api/v1/auth/register
#### [POST] /api/v1/auth/register
**Summary**: 온보딩 완료 처리


### Path: /api/v1/auth/consent
#### [POST] /api/v1/auth/consent
**Summary**: 동의 기록


### Path: /api/v1/auth/account
#### [DELETE] /api/v1/auth/account
**Summary**: 계정 삭제 요청 (7일 유예)


### Path: /api/v1/auth/cancel-deletion
#### [POST] /api/v1/auth/cancel-deletion
**Summary**: 계정 삭제 취소


### Path: /api/v1/users/register
#### [POST] /api/v1/users/register
**Summary**: 테스트용 사용자 등록


### Path: /api/v1/users/by-phone
#### [GET] /api/v1/users/by-phone
**Summary**: 전화번호로 사용자 조회
**Parameters**:
- phone_number (query): string
- phone_country_code (query): string


### Path: /api/v1/users/search
#### [GET] /api/v1/users/search
**Summary**: 사용자 검색
**Parameters**:
- q (query): string


### Path: /api/v1/users/me
#### [GET] /api/v1/users/me
**Summary**: 내 프로필 조회

#### [PATCH] /api/v1/users/me
**Summary**: 내 프로필 수정


### Path: /api/v1/users/me/location-sharing
#### [PATCH] /api/v1/users/me/location-sharing
**Summary**: 위치 공유 모드 변경


### Path: /api/v1/users/me/device
#### [POST] /api/v1/users/me/device
**Summary**: 디바이스 등록/갱신


### Path: /api/v1/users/me/fcm-token
#### [PUT] /api/v1/users/me/fcm-token
**Summary**: FCM 토큰 등록/갱신 (본인)


### Path: /api/v1/users/me/fcm-token/{tokenId}
#### [DELETE] /api/v1/users/me/fcm-token/{tokenId}
**Summary**: FCM 토큰 비활성화 (본인)
**Parameters**:
- tokenId (path): string


### Path: /api/v1/users/{userId}
#### [GET] /api/v1/users/{userId}
**Summary**: 특정 사용자 조회 (userId)
**Parameters**:
- userId (path): string

#### [PUT] /api/v1/users/{userId}
**Summary**: 테스트용 특정 사용자 프로필 수정
**Parameters**:
- userId (path): string


### Path: /api/v1/users/{userId}/fcm-token
#### [PUT] /api/v1/users/{userId}/fcm-token
**Summary**: 테스트용 특정 사용자 FCM 토큰 등록/갱신
**Parameters**:
- userId (path): string


### Path: /api/v1/users/{id}/terms
#### [PATCH] /api/v1/users/{id}/terms
**Summary**: 약관 동의 기록
**Parameters**:
- id (path): string


### Path: /api/v1/groups/users/{userId}/recent-groups
#### [GET] /api/v1/groups/users/{userId}/recent-groups
**Summary**: 최근 그룹 조회
**Parameters**:
- userId (path): string


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


