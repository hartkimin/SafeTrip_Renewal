# SafeTrip Backend API 명세서 작성 구현 플랜

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task.

**Goal:** `Master_docs/35_T2_API_명세서.md`를 생성 — 백엔드 19개 컨트롤러의 모든 엔드포인트에 대한 Request Body / Response JSON / Error Codes 완전 명세

**Architecture:** Explore 에이전트로 컨트롤러 + 라우트 코드를 직접 읽어 실제 구현 기반 API 명세를 추출한다. 기존 `08_T2_아키텍처_구조_v3_0.md` §19의 엔드포인트 목록을 시작점으로 사용하며, 각 섹션을 순차적으로 Write 도구로 파일에 추가한다. TDD가 아닌 코드 분석 → 문서 생성 방식.

**Tech Stack:** Read/Grep 도구 (컨트롤러 분석), Write/Edit 도구 (마크다운 생성), Master_docs 경로: `/mnt/d/Project/15_SafeTrip_New/Master_docs/`

---

## 핵심 경로 참조

| 유형 | 경로 |
|------|------|
| 컨트롤러 | `/mnt/d/Project/15_SafeTrip_New/safetrip-server-api/src/controllers/` |
| 라우트 | `/mnt/d/Project/15_SafeTrip_New/safetrip-server-api/src/routes/` |
| 미들웨어 | `/mnt/d/Project/15_SafeTrip_New/safetrip-server-api/src/middleware/` |
| 출력 파일 | `/mnt/d/Project/15_SafeTrip_New/Master_docs/35_T2_API_명세서.md` |

## 엔드포인트 표기 형식 (모든 태스크 공통)

각 엔드포인트를 다음 형식으로 작성한다:

```markdown
#### [METHOD] /api/v1/[path]

**인증**: 필요 / 불필요 / 선택
**설명**: 한 줄 설명

**Path Parameters** (없으면 생략)
| 파라미터 | 타입 | 설명 |
|---------|------|------|
| userId | string(UUID) | 사용자 UUID |

**Query Parameters** (없으면 생략)
| 파라미터 | 타입 | 필수 | 기본값 | 설명 |
|---------|------|:----:|:------:|------|
| q | string | ✅ | — | 검색어 |

**Request Body** (GET/DELETE는 생략)
```json
{
  "fieldName": "string",
  "optionalField": "number (optional)"
}
```
| 필드 | 타입 | 필수 | 설명 |
|------|------|:----:|------|
| fieldName | string | ✅ | 설명 |

**Response 200**
```json
{
  "userId": "uuid",
  "name": "string"
}
```

**Error Codes**
| Code | 설명 |
|------|------|
| 400 | 요청 형식 오류 |
| 401 | 인증 토큰 없음/만료 |
| 403 | 권한 없음 |
| 404 | 리소스 없음 |
| 500 | 서버 오류 |
```

---

## ━━━━━━━━ Task 1: 문서 헤더 + §1 + §2 공통 규칙 ━━━━━━━━

**파일:**
- Read: `safetrip-server-api/src/middleware/auth.middleware.ts` (인증 헤더 형식 확인)
- Read: `safetrip-server-api/src/middleware/error.middleware.ts` (공통 에러 포맷 확인)
- Read: `safetrip-server-api/src/middleware/rate-limit.middleware.ts` (Rate limiting 규칙 확인)
- Create: `Master_docs/35_T2_API_명세서.md`

**Step 1: auth.middleware.ts 읽기**

`authenticate` 미들웨어에서 JWT 토큰 헤더 형식 확인:
- `Authorization: Bearer <token>` 사용 여부
- `req.user`에 어떤 필드가 주입되는지 (userId, role 등)

**Step 2: error.middleware.ts 읽기**

공통 에러 응답 포맷 확인:
```json
{
  "error": "에러 메시지",
  "code": "ERROR_CODE (있는 경우)"
}
```
또는 다른 포맷인지 확인.

**Step 3: 파일 생성 (§1 + §2)**

다음 내용으로 `35_T2_API_명세서.md` 파일을 생성한다:

```markdown
# SafeTrip Backend API 명세서

| 항목 | 내용 |
|------|------|
| **문서 ID** | `DOC-T2-API-035` |
| **문서 계층** | Tier 2 — 시스템 설계 |
| **버전** | v1.0 |
| **작성일** | 2026-03-02 |
| **기준 문서** | 아키텍처_구조_v3_0 (#08), DB_설계_v3_4 (#07) |
| **관련 문서** | 프로젝트_구조 (#34), 외부_API_연동 (#33) |

---

## §1. 목적 및 적용 범위

본 문서는 `safetrip-server-api` 백엔드의 모든 REST API 엔드포인트에 대해
Request Body, Response JSON, Error Codes를 정의한다. Flutter 클라이언트 개발 시
백엔드 코드를 직접 읽지 않아도 이 문서만으로 API 통합이 가능하도록 한다.

**기준**: 실제 컨트롤러 코드 기반 (코드 변경 시 이 문서도 함께 갱신).

---

## §2. 공통 규칙

### 2.1 기본 URL

| 환경 | URL |
|------|-----|
| 로컬 (Android 에뮬레이터) | `http://10.0.2.2:3001/api/v1` |
| 로컬 (ngrok) | `https://[ngrok-id].ngrok-free.app/api/v1` |
| 프로덕션 | TBD |

### 2.2 인증 헤더

모든 `/api/v1/*` 엔드포인트(로그인 제외)에 필수:

```
Authorization: Bearer <JWT_ACCESS_TOKEN>
```

JWT는 `POST /api/v1/auth/login` 응답의 `token` 필드에서 발급.

### 2.3 공통 에러 응답 포맷

```json
{
  "error": "에러 메시지 (human-readable)"
}
```

### 2.4 공통 에러 코드

| HTTP Code | 의미 |
|:---------:|------|
| 400 | Bad Request — 요청 형식 오류, 필수 필드 누락 |
| 401 | Unauthorized — 인증 토큰 없음 또는 만료 |
| 403 | Forbidden — 권한 부족 (인증은 됐지만 접근 불가) |
| 404 | Not Found — 리소스 없음 |
| 409 | Conflict — 중복 데이터 (이미 존재) |
| 429 | Too Many Requests — Rate limit 초과 |
| 500 | Internal Server Error — 서버 내부 오류 |

### 2.5 Rate Limiting

| 대상 | 제한 |
|------|------|
| 전체 API | [미들웨어에서 확인하여 기입] |
| 인증 엔드포인트 | [미들웨어에서 확인하여 기입] |
```

> **주의**: §2.5 Rate Limiting 값은 `rate-limit.middleware.ts`를 읽어 실제 값으로 채운다.

**Step 4: 검증**

파일이 생성되었는지 확인:
```bash
ls -la /mnt/d/Project/15_SafeTrip_New/Master_docs/35_T2_API_명세서.md
```

---

## ━━━━━━━━ Task 2: §3 인증 (Auth) ━━━━━━━━

**파일:**
- Read: `safetrip-server-api/src/controllers/auth.controller.ts`
- Read: `safetrip-server-api/src/routes/auth.routes.ts`
- Modify: `Master_docs/35_T2_API_명세서.md` (§3 추가)

**Step 1: 코드 읽기**

`auth.controller.ts` 전체를 읽어 다음을 파악:
- 각 함수의 `req.body`에서 읽는 필드
- 각 함수의 `res.json()` 응답 구조
- 에러 조건 (if/throw 패턴)

`auth.routes.ts`를 읽어 라우트 경로와 미들웨어 확인.

**Step 2: §3 섹션 추가 (Edit 도구)**

파악된 내용을 바탕으로 §3을 작성하여 파일에 추가.
각 엔드포인트마다 공통 형식(Task 1 §2 마지막 부분의 템플릿) 사용.

예상 엔드포인트:
- `POST /auth/login` — Firebase ID Token → JWT
- `POST /auth/logout` — 로그아웃
- `PUT /auth/profile` — 최초 프로필 등록
- `POST /auth/refresh` — 토큰 갱신 (있는 경우)

**Step 3: 검증**

추가된 내용에 v5.0 같은 오류 표현이나 오타가 없는지 확인.

---

## ━━━━━━━━ Task 3: §4 사용자 (Users) ━━━━━━━━

**파일:**
- Read: `safetrip-server-api/src/controllers/users.controller.ts`
- Read: `safetrip-server-api/src/routes/users.routes.ts`
- Modify: `Master_docs/35_T2_API_명세서.md` (§4 추가)

**Step 1: 코드 읽기**

`users.controller.ts` 전체 읽기. 특히:
- `GET /users/search` — 쿼리 파라미터 `q` 처리 방식
- `GET /users/:userId` — 응답 필드 (name, profileImageUrl, role 등)
- `PUT /users/:userId` — 수정 가능한 필드
- `POST /users/:userId/profile-image` — multipart/form-data 처리 여부

**Step 2: §4 섹션 추가**

예상 엔드포인트:
- `GET /users/search?q=` — 사용자 검색
- `GET /users/:userId` — 프로필 조회
- `PUT /users/:userId` — 프로필 수정
- `POST /users/:userId/profile-image` — 프로필 이미지 업로드

**Step 3: travelers 컨트롤러 확인**

`travelers.controller.ts`, `travelers.routes.ts`를 읽어 Users와 중복/차이 파악 후 §4에 포함 또는 별도 섹션으로 처리.

---

## ━━━━━━━━ Task 4: §5 여행 (Trips) ━━━━━━━━

**파일:**
- Read: `safetrip-server-api/src/controllers/trips.controller.ts`
- Read: `safetrip-server-api/src/routes/trips.routes.ts`
- Modify: `Master_docs/35_T2_API_명세서.md` (§5 추가)

**Step 1: 코드 읽기**

`trips.controller.ts` 전체 읽기 (가장 큰 컨트롤러). 특히:
- `POST /trips` — 여행 생성 필드 (title, start_date, end_date, destination 등)
- `GET /trips/users/:userId/trips` — 내 여행 목록 응답 구조
- `GET /trips/:tripId` — 여행 상세 응답 필드
- `POST /trips/join` / `POST /trips/invite/:inviteCode` — 참가 필드
- `GET /trips/:tripId/settings` / `PUT /trips/:tripId/settings` — 설정 필드
- 멤버 추가/삭제/역할변경 관련 엔드포인트

`trips.routes.ts`로 라우트-컨트롤러 매핑 확인.

**Step 2: §5 섹션 추가**

예상 엔드포인트 (10개+):
- `POST /trips` — 여행 생성
- `GET /trips/users/:userId/trips` — 내 여행 목록
- `GET /trips/:tripId` — 여행 상세
- `POST /trips/join` — 참가 (직접)
- `POST /trips/invite/:inviteCode` — 초대코드 참가
- `POST /trips/guardian-join` — 가디언으로 참가
- `GET /trips/:tripId/settings` — 설정 조회
- `PUT /trips/:tripId/settings` — 설정 수정
- `DELETE /trips/:tripId` — 여행 삭제/종료 (있는 경우)
- Trip Preview/Terms 엔드포인트 (있는 경우)

---

## ━━━━━━━━ Task 5: §6 그룹 + §7 초대 코드 ━━━━━━━━

**파일:**
- Read: `safetrip-server-api/src/controllers/groups.controller.ts`
- Read: `safetrip-server-api/src/routes/groups.routes.ts`
- Read: `safetrip-server-api/src/controllers/invite-codes.controller.ts`
- Read: `safetrip-server-api/src/routes/invite-codes.routes.ts`
- Modify: `Master_docs/35_T2_API_명세서.md` (§6, §7 추가)

**Step 1: groups 코드 읽기**

- `POST /groups` — 그룹 생성 필드
- `GET /groups/:groupId` — 그룹 정보 응답
- `POST /groups/:groupId/members` — 멤버 추가
- `GET /groups/:groupId/members` — 멤버 목록 응답 구조

**Step 2: invite-codes 코드 읽기**

- 초대코드 생성 (POST): 어떤 필드가 필요한지
- 초대코드 조회 (GET): 코드 유효성 확인 응답 (trip 정보 포함 여부)
- `POST /groups/join-by-code/:guardianCode` — 가디언 그룹 가입 (groups 컨트롤러에 있는지 확인)

**Step 3: §6 + §7 추가**

---

## ━━━━━━━━ Task 6: §8 가디언 시스템 ━━━━━━━━

> 가디언은 `trip-guardian`, `guardians`, `guardian-messages`, `guardian-view` 4개 컨트롤러로 분리되어 있음.

**파일:**
- Read: `safetrip-server-api/src/controllers/trip-guardian.controller.ts`
- Read: `safetrip-server-api/src/routes/trip-guardian.routes.ts`
- Read: `safetrip-server-api/src/controllers/guardians.controller.ts`
- Read: `safetrip-server-api/src/routes/guardians.routes.ts`
- Read: `safetrip-server-api/src/controllers/guardian-messages.controller.ts`
- Read: `safetrip-server-api/src/routes/guardian-messages.routes.ts`
- Read: `safetrip-server-api/src/controllers/guardian-view.controller.ts`
- Read: `safetrip-server-api/src/routes/guardian-view.routes.ts`
- Modify: `Master_docs/35_T2_API_명세서.md` (§8 추가)

**Step 1: 4개 컨트롤러 모두 읽기**

특히 주의:
- `trip-guardian` vs `guardians` 차이 (여행별 가디언 링크 vs 가디언 그룹)
- `POST /trips/:tripId/guardians { guardian_phone }` — 링크 생성
- `PATCH /trips/:tripId/guardians/:linkId/respond { action: 'accepted'|'rejected' }` — 링크 응답
- `DELETE /trips/:tripId/guardians/:linkId` — 링크 해제
- `GET /trips/:tripId/guardian-view` — 가디언 전용 뷰 응답 구조
- `POST /trips/:tripId/guardian-messages/member { link_id, message }` — 멤버→가디언
- `POST /trips/:tripId/guardian-messages/guardian { link_id, message }` — 가디언→멤버
- `POST /groups/join-by-code/:guardianCode` — 가디언 코드로 그룹 가입 (위치 확인 필요)

**Step 2: §8 추가**

4개 컨트롤러를 하나의 §8 "가디언 시스템"으로 통합 작성.
서브섹션: 8.1 여행별 가디언 링크, 8.2 가디언 그룹, 8.3 가디언 메시지, 8.4 가디언 뷰

---

## ━━━━━━━━ Task 7: §9 위치 + §10 지오펜스 + §11 이동기록 ━━━━━━━━

**파일:**
- Read: `safetrip-server-api/src/controllers/locations.controller.ts`
- Read: `safetrip-server-api/src/routes/locations.routes.ts`
- Read: `safetrip-server-api/src/controllers/location-sharing.controller.ts`
- Read: `safetrip-server-api/src/routes/location-sharing.routes.ts`
- Read: `safetrip-server-api/src/controllers/geofences.controller.ts`
- Read: `safetrip-server-api/src/routes/geofences.routes.ts`
- Modify: `Master_docs/35_T2_API_명세서.md` (§9, §10, §11 추가)

**Step 1: 위치 관련 코드 읽기**

- `POST /locations` — 위치 저장 (lat, lng, accuracy, timestamp 등 필드)
- `GET /locations/groups/:groupId` — 멤버 현재 위치 목록 응답
- `location-sharing` — 실시간 위치 공유 설정 관련 엔드포인트

**Step 2: 지오펜스 코드 읽기**

- `POST /geofences` — 생성 (좌표, 반경, 이름 등)
- `GET /geofences/groups/:groupId` — 목록
- `DELETE /geofences/:geofenceId`

**Step 3: Movement 컨트롤러 확인**

`/mnt/d/Project/15_SafeTrip_New/safetrip-server-api/src/` 에서 movement 관련 컨트롤러 파일명 확인 (movement.controller.ts 또는 routes/trips.routes.ts 내 movement 경로).

이동기록 엔드포인트:
- `GET /movement/:userId/trips/:tripId` — 전체 이동기록
- `GET /movement/:userId/trips/:tripId/date/:date` — 일자별
- `GET /movement/:userId/trips/:tripId/sessions` — 세션 목록
- `GET /movement/:userId/trips/:tripId/export/gpx` — GPX 내보내기

**Step 4: §9, §10, §11 추가**

---

## ━━━━━━━━ Task 8: §12 FCM + §13 안전가이드 + §14 리더십 + §15 기타 ━━━━━━━━

**파일:**
- Read: `safetrip-server-api/src/controllers/fcm.controller.ts`
- Read: `safetrip-server-api/src/controllers/guides.controller.ts`
- Read: `safetrip-server-api/src/routes/guides.routes.ts`
- Read: `safetrip-server-api/src/controllers/leader-transfer.controller.ts`
- Read: `safetrip-server-api/src/routes/leader-transfer.routes.ts`
- Read: `safetrip-server-api/src/controllers/countries.controller.ts`
- Read: `safetrip-server-api/src/controllers/event-log.controller.ts`
- Modify: `Master_docs/35_T2_API_명세서.md` (§12~§15 추가)

**Step 1: 각 컨트롤러 읽기**

- FCM: 토큰 등록/삭제 엔드포인트
- guides: MOFA API 연동, 국가별 안전 가이드 응답 구조
- leader-transfer: 리더십 양도 (to_user_id 파라미터)
- countries: 국가 목록 조회
- event-log: 이벤트 로그 기록 (내부 사용 여부 확인)

**Step 2: §12~§15 추가**

```
§12. 알림 (FCM)
§13. 안전 가이드 (Guides / MOFA)
§14. 리더십 양도 (Leader Transfer)
§15. 국가 정보 (Countries)
```

event-log, travelers 컨트롤러가 내부 전용이면 §15.x 내부 엔드포인트로 별도 표시.

---

## ━━━━━━━━ Task 9: §16 공통 타입 정의 + 검토 ━━━━━━━━

**파일:**
- Read: `safetrip-server-api/src/constants/` (상수/Enum 확인)
- Read: `Master_docs/01_T1_SafeTrip_비즈니스_원칙_v5.1.md` §09.3 (역할명 확인)
- Modify: `Master_docs/35_T2_API_명세서.md` (§16 추가 + 최종 검토)

**Step 1: 상수 파일 읽기**

`src/constants/` 내 파일에서 Enum 값 확인:
- 역할 (role): captain, crew_leader, crew, guardian
- 여행 상태 (trip_status): planning, active, completed, cancelled
- 가디언 링크 상태: pending, accepted, rejected
- 프라이버시 등급: safety_first, standard, privacy_first
- 결제 타입, 구독 플랜 타입 등

**Step 2: §16 추가**

```markdown
## §16. 공통 타입 정의

### 역할 (role)
| 값 | 설명 |
|---|------|
| captain | 캡틴 |
| crew_leader | 크루장 |
| crew | 크루 |
| guardian | 가디언 |

### 여행 상태 (trip_status)
...
```

**Step 3: 전체 문서 검토**

파일 전체를 읽어 다음 확인:
1. 모든 엔드포인트가 누락 없이 포함되었는지
2. 아키텍처 §19의 엔드포인트 목록과 비교 검증
3. JSON 예시 코드 블록 문법 오류 없는지
4. 버전 표기 일관성 (v5.1 참조 등)

검증용 Grep:
```bash
# 아키텍처 §19에 있는 주요 엔드포인트가 명세서에도 있는지 확인
grep -c "####" /mnt/d/Project/15_SafeTrip_New/Master_docs/35_T2_API_명세서.md
# 30개 이상이어야 함
```

---

## ━━━━━━━━ Task 10: 변경 이력 + Notion 기록 ━━━━━━━━

**Step 1: 변경 이력 섹션 추가**

파일 끝에 추가:

```markdown
---

## §17. 변경 이력

| 버전 | 날짜 | 내용 |
|------|------|------|
| v1.0 | 2026-03-02 | 초기 작성 — 백엔드 19개 컨트롤러 기반 전체 API 명세 |
```

**Step 2: Notion 기록**

`mcp__claude_ai_Notion__notion-update-page` 사용:
- 페이지 ID: `316a19580398815cb74bc9d09481cb4b` (2026-03-02 개발사항)
- 삽입 위치: `insert_content_after` + anchor
- 블록 형식: 토글
- 제목: `HH:MM — 35_T2_API_명세서.md 신규 생성 완료 (Backend 전체 API Request/Response 명세)`
- 내용: 문서 경로, 엔드포인트 수, 섹션 목록

---

## 처리 흐름 요약

```
Task 1: 파일 생성 + §1 + §2 공통 규칙
Task 2: §3 Auth
Task 3: §4 Users
Task 4: §5 Trips (가장 복잡)
Task 5: §6 Groups + §7 Invite Codes
Task 6: §8 Guardian System (4개 컨트롤러)
Task 7: §9 Locations + §10 Geofences + §11 Movement
Task 8: §12 FCM + §13 Guides + §14 Leader Transfer + §15 Countries
Task 9: §16 Types + 전체 검토
Task 10: 변경 이력 + Notion 기록
```

---

## 주의사항

1. **코드베이스 기반 작성**: 추측하지 말고 실제 컨트롤러 코드에서 읽은 내용만 기재
2. **불확실한 필드**: 컨트롤러 코드에서 명확하지 않으면 `(확인 필요)` 표시
3. **내부 엔드포인트**: `/event-log`, `/firebase-test`, `/health` 등 내부용은 간략히만 기재
4. **기존 아키텍처 문서 존중**: §19 목록과 충돌 시 실제 코드를 우선
