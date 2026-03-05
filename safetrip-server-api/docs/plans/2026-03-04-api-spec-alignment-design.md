# API 명세서-코드 정렬 설계 문서

| 항목 | 내용 |
|------|------|
| **문서 ID** | `DESIGN-API-ALIGN-001` |
| **작성일** | 2026-03-04 |
| **대상** | `safetrip-server-api` (NestJS) |
| **기준** | Master_docs API 명세서 v1.0 (35~38번 문서) |
| **범위** | Phase 1 (치명적 버그 수정) + Phase 2 (스키마 정렬) |

---

## 1. 배경 및 목적

Master_docs API 명세서(120+ 엔드포인트)와 safetrip-server-api(NestJS) 구현 간 갭 분석 결과:

- **27개** 엔드포인트 일치
- **39개** 엔드포인트 불일치 (경로, 인증, 스키마 등)
- **47개** 엔드포인트 미구현
- **27개** 코드에만 존재 (명세서 미기재)

이 문서는 **기존 코드의 치명적 버그 수정**과 **Request/Response 스키마 정렬**을 다룬다.
미구현 엔드포인트 신규 개발은 별도 Phase 3으로 분리한다.

---

## 2. Phase 1: 치명적 버그 수정

### 2.1 Double Prefix 버그 (12개 엔드포인트)

**문제**: `@Controller()` (빈 문자열) + 라우트 데코레이터에 `'api/v1/...'` 경로 포함 → NestJS 글로벌 프리픽스 `api/v1`과 중복되어 실제 경로가 `/api/v1/api/v1/...`

**영향 파일**:
- `src/modules/geofences/geofences.controller.ts` — 6개 엔드포인트
- `src/modules/locations/locations.controller.ts` — 6개 movement session 엔드포인트

**수정 방법**:

```typescript
// BEFORE (geofences.controller.ts)
@Controller()
export class GeofencesController {
  @Post('api/v1/groups/:group_id/geofences')
  @Get('api/v1/geofences')
  @Get('api/v1/geofences/:id')
  // ...
}

// AFTER
@Controller()
export class GeofencesController {
  @Post('groups/:group_id/geofences')
  @Get('geofences')
  @Get('geofences/:id')
  @Patch('geofences/:id')
  @Delete('geofences/:id')
  @Post('geofences/events')
}
```

```typescript
// BEFORE (locations.controller.ts, movement session routes)
@Get('api/v1/locations/users/:userId/movement-sessions/summary')

// AFTER
@Get('locations/users/:userId/movement-sessions/summary')
```

### 2.2 전역 Auth Guard 불일치 (20+ 엔드포인트)

**문제**: `FirebaseAuthGuard`가 `APP_GUARD`로 전역 적용. 명세서에서 인증 불필요로 표시된 엔드포인트에 `@Public()` 데코레이터 미적용.

**수정 대상 컨트롤러 및 메서드**:

| 컨트롤러 | 메서드 | `@Public()` 추가 |
|----------|--------|:-:|
| `trips.controller.ts` | `getPreview(:code)` | ✅ |
| `trips.controller.ts` | `getByInviteCode(:inviteCode)` | ✅ |
| `trips.controller.ts` | `verifyInviteCode(:code)` | ✅ |
| `trips.controller.ts` | `getTripDetail(:tripId)` | ✅ |
| `groups.controller.ts` | `getGroupById(:groupId)` | ✅ |
| `groups.controller.ts` | `getMembers(:tripId)` | ✅ |
| `groups.controller.ts` | `addMember(:groupId)` | ✅ (내부 권한 체크) |
| `countries.controller.ts` | `getAll()` | ✅ |
| `event-log.controller.ts` | `recordEvent()` | ✅ |
| `event-log.controller.ts` | `getEvents()` | ✅ |

### 2.3 리더십 양도 `owner_user_id` 미갱신

**문제**: `groups.service.ts`에서 리더십 양도 트랜잭션 중 `tb_group.owner_user_id` 업데이트가 주석 처리됨.

**수정**:
```typescript
// BEFORE (groups.service.ts ~line 338)
/*ownerUserId: targetUserId*/

// AFTER
ownerUserId: targetUserId
```

### 2.4 FCM 토큰 등록 시 사용자 미존재 에러 코드

**문제**: `PUT /users/:userId/fcm-token`에서 사용자 미존재 시 500 대신 404 반환 필요.

**수정**: `InternalServerErrorException` → `NotFoundException`

### 2.5 Auth `firebase-verify`의 `user_role` 미구현

**문제**: 응답의 `user_role` 필드가 항상 `'crew'`로 하드코딩. 명세서는 가디언 링크 존재 시 `'guardian'` 반환 요구.

**수정**: `GuardianLink` 테이블에서 해당 사용자의 accepted 링크 존재 여부를 쿼리하여 role 결정.

---

## 3. Phase 2: 스키마 정렬

### 3.1 Response Envelope 일관성

**문제**: 명세서는 모든 응답을 `{ success: true, data: {...} }` envelope로 감싸지만, trips/groups/guardians 컨트롤러는 raw entity를 반환.

**수정 방법**:
- NestJS `TransformInterceptor`가 이미 존재하는지 확인
- 없으면 글로벌 인터셉터 추가하여 `{ success: true, data: <controller-return-value> }` 자동 래핑
- 에러 응답은 `{ success: false, error: message }` 형식의 글로벌 예외 필터

### 3.2 Field Naming Convention (camelCase → snake_case)

**문제**:
- 명세서: 모든 Request/Response 필드명이 `snake_case`
- NestJS: 일부 컨트롤러는 `camelCase` (trips, groups)
- 일부 컨트롤러는 수동 매핑으로 `snake_case` (auth, users)

**수정 방법**:
- 글로벌 직렬화 인터셉터에서 camelCase → snake_case 자동 변환
- 또는 각 컨트롤러의 응답 DTO에 `@Expose()` + `@Transform()` 적용
- Request body는 `class-transformer`의 `@Transform()` 또는 커스텀 파이프로 snake_case → camelCase 변환

### 3.3 Trips 컨트롤러 스키마 정렬

| 엔드포인트 | 수정 내용 |
|-----------|----------|
| `POST /trips` | Request: `title` → `tripName`, `country_code` → `destinationCountryCode` 매핑 추가. Response: `{ trip_id, group_id, invite_code }` 형식으로 정리 |
| `POST /trips/join` | Response: camelCase → snake_case (`groupId` → `group_id`) |
| `GET /trips` | 경로를 `GET /trips/users/:user_id/trips` 또는 `GET /trips`에 맞게 정리. Response에 `member_role`, `is_admin` 등 JOIN 필드 추가 |
| `GET /trips/preview/:code` | Response를 명세서 형식으로 변환 (`trip_id`, `trip_name`, `captain_name`, `member_count` 등) |
| `GET /trips/:tripId` | Response envelope 적용 |
| `GET /trips/verify-invite-code/:code` | `expired` 필드 추가 |

### 3.4 Trips 라우트 경로 정렬

| 현재 경로 | 명세서 경로 | 수정 |
|-----------|-----------|------|
| `POST /trips/guardian/request` | `POST /trips/guardian-approval/request` | 경로 변경 |
| `GET /trips/guardian/approval-status` | `GET /trips/guardian-approval/status` | 경로 변경 |

**라우트 충돌 해결**: `guardian-approval/*` 라우트를 `:tripId` 보다 먼저 선언하거나, 별도 컨트롤러로 분리.

### 3.5 Groups 컨트롤러 스키마 정렬

| 엔드포인트 | 수정 내용 |
|-----------|----------|
| `GET /:group_id/members` | 경로 파라미터를 `tripId` → `group_id`로 변경. Response에 `location_sharing_enabled`, `joined_at` 추가 |
| `POST /:group_id/members` | Request에 `phone_number` 기반 사용자 조회 로직 추가 (현재 `userId` 직접 전달) |
| `PATCH /:group_id/members/:user_id` | 경로에서 `/role` 접미사 제거. Request body에 6개 권한 필드 추가 |
| `POST /join/:invite_code` | `tb_invite_code` 우선 조회 → `tb_group.invite_code` 폴백 이중 조회 로직 추가 |
| `GET /:groupId/invite-codes` | 비활성 코드도 포함하여 반환 |

### 3.6 Guardians 컨트롤러 스키마 정렬

| 엔드포인트 | 수정 내용 |
|-----------|----------|
| `GET /pending` | raw entity 대신 trip/member 프로필 정보 JOIN하여 반환 |
| `GET /linked-members` | raw entity 대신 사용자 프로필 + 멤버 역할 JOIN하여 반환 |

### 3.7 Guides 서비스 스텁 해제

3개 엔드포인트(`/:countryCode`, `/search`, `/:countryCode/emergency`)의 스텁 구현을 실제 DB 쿼리로 교체:
- `TB_COUNTRY` 테이블의 `travel_guide_data` JSONB 컬럼 직접 조회
- `TB_MOFA_RISK` 테이블에서 `is_current = TRUE` 위험 정보 JOIN

### 3.8 MOFA 캐싱 미적용

명세서는 30분/7일/6-24시간 TTL 캐싱을 요구하나, 현재 매 요청마다 외교부 API 직접 호출.
- NestJS `CacheModule` 또는 인메모리 캐시(`Map` + TTL) 적용 검토
- `GET /mofa/country/:countryCode/all` 통합 엔드포인트 추가
- `DELETE /mofa/cache` 캐시 클리어 엔드포인트 추가

---

## 4. 범위 외 (Phase 3: 미구현 엔드포인트)

다음은 이번 작업 범위에서 제외하며, 별도 Phase 3 설계가 필요:

| 섹션 | 미구현 엔드포인트 수 | 주요 항목 |
|------|:---:|------|
| §4B Travelers | 2 | register, last-location |
| §5 Trips | 14 | guardian-invite, guardian-join, guardian-approval (5개), invite-code 관리(2개), trip settings(2개), 국가/타임존 조회(3개) |
| §6 Groups | 8 | 일정(4개), 출석(1개), 위치공유(3개) |
| §8 Guardians | 11 | 메시지(4개), 뷰(3개), 레거시(4개) |
| §10 Geofences | 6 | 전체 재구현 (현재 스텁) |
| §12 FCM | 1 | travelers/:travelerId/notify |
| §13 MOFA | 2 | /all, /cache |
| **합계** | **44** | |

---

## 5. 수정 순서 (권장)

### Phase 1 (즉시)
1. Double prefix 버그 수정 (geofences + locations)
2. `@Public()` 데코레이터 추가 (auth 불일치 해소)
3. 리더십 양도 `owner_user_id` 주석 해제
4. FCM 에러 코드 수정 (500 → 404)
5. Auth `user_role` 구현

### Phase 2 (스키마 정렬)
1. 글로벌 Response envelope 인터셉터
2. 글로벌 snake_case 직렬화
3. Trips 컨트롤러 스키마 정렬
4. Groups 컨트롤러 스키마 정렬
5. Guardians 스키마 정렬 (pending, linked-members)
6. Guides 스텁 해제
7. MOFA 캐싱 + 추가 엔드포인트
8. Trips 라우트 경로 정렬

---

## 6. 테스트 계획

- 각 수정 후 해당 엔드포인트 curl/Postman 테스트
- Double prefix 수정 후 기존 클라이언트(Flutter) 호출 경로 확인
- Auth Guard 변경 후 토큰 없이 public 엔드포인트 접근 가능한지 검증
- Response envelope 인터셉터 적용 후 모든 기존 엔드포인트의 응답 형식 검증
