# SafeTrip 온보딩 프로세스 통합 테스트 설계

**Date:** 2026-02-27
**Scope:** 백엔드 API 계층 + Firebase 에뮬레이터 연동
**Output:** `scripts/test-onboarding.ts`

---

## 1. 온보딩 플로우 요약

```
Splash
  └─ [첫 실행] Onboarding 슬라이드 → onboarding_completed = true
  └─ [이후] Start Screen (screen_3_start.dart)
               ├─ 새 여행 만들기     → OnboardingEntry.newTrip
               ├─ 초대 코드로 참여   → OnboardingEntry.inviteCode
               └─ 기존 여행 돌아가기 → OnboardingEntry.continueTrip
                         ↓
               Phone (screen_6_phone.dart)
                 - TestAuthConfig: 01099990001~9 → Anonymous Auth
                 - 일반 번호: Firebase SMS OTP
                         ↓
               Verify (screen_7_verify.dart)
                 → POST /api/v1/auth/firebase-verify
                 → is_new_user 판단 (전화번호로 기존 유저 검색)
                         ↓
         ┌─ [신규] Terms → Profile → entry별 분기
         └─ [기존] entry + hasTrip(group_id in SharedPreferences) 기반 직행
```

### 백엔드 핵심 로직 (`user.service.ts`)

- `getOrCreateUserFromFirebase(uid, phoneNumber, countryCode)`:
  - 전화번호로 기존 유저 검색 → 없으면 INSERT (is_new_user: true)
  - UID가 같으면 metadata 업데이트
  - UID가 다르면 (기기 변경/에뮬레이터 리셋) CASCADE UPDATE (트리거 disable 후 PK 변경)

### 클라이언트 분기 로직 (`screen_7_verify.dart` `_navigateAfterAuth`)

| is_new_user | entry | hasTrip | 결과 |
|---|---|---|---|
| true | any (continueTrip) | - | 오류 다이얼로그 → Start Screen |
| true | newTrip / inviteCode | - | Terms → Profile |
| false | newTrip | true | Main |
| false | newTrip | false | TripCreate |
| false | inviteCode | - | TripJoin |
| false | continueTrip | - | Main |

---

## 2. 테스트 시나리오 (8개)

### SC-01: 신규 유저 + 새 여행 만들기
- **입력**: 미등록 전화번호 (`+821099901001`), entry=newTrip
- **기대 응답**: `is_new_user: true`, `display_name: ""`
- **DB 검증**: `tb_user` INSERT 완료, `display_name = ''`

### SC-02: 신규 유저 + 초대 코드 참여
- **입력**: 미등록 전화번호 (`+821099901002`), entry=inviteCode
- **기대 응답**: `is_new_user: true`
- **DB 검증**: `tb_user` INSERT 완료

### SC-03: 신규 유저 + 기존 여행 돌아가기 (에러 케이스)
- **입력**: 미등록 전화번호 (`+821099901003`), entry=continueTrip
- **기대 응답**: `is_new_user: true`
- **검증**: 클라이언트 레벨 오류 (서버는 정상 응답, 클라이언트가 다이얼로그 표시)
- **DB 검증**: `tb_user` 생성되지만 group_member 없음

### SC-04: 기존 유저 + 새 여행 만들기 + 여행 있음
- **입력**: 기존 등록 유저 + group_member 있음
- **기대 응답**: `is_new_user: false`, `user_role: captain 또는 crew_chief`
- **DB 검증**: `last_verification_at` 업데이트됨

### SC-05: 기존 유저 + 새 여행 만들기 + 여행 없음
- **입력**: 기존 등록 유저 + group_member 없음
- **기대 응답**: `is_new_user: false`, `user_role: traveler`
- **DB 검증**: `tb_user` 업데이트만 (INSERT 없음)

### SC-06: 기존 유저 + 초대 코드 참여
- **입력**: 기존 등록 유저 + group_member 없음, entry=inviteCode
- **기대 응답**: `is_new_user: false`
- **DB 검증**: `last_verification_at` 업데이트됨

### SC-07: 기존 유저 + 기존 여행 돌아가기
- **입력**: 기존 등록 유저 + group_member 있음, entry=continueTrip
- **기대 응답**: `is_new_user: false`, `user_role: traveler 또는 guardian`
- **DB 검증**: 기존 레코드 보존

### SC-08: 테스트 번호 Anonymous Auth
- **입력**: 테스트 번호 (`+821099990001`), Firebase Anonymous Auth
- **기대 응답**: `is_new_user: true` (첫 실행)
- **DB 검증**: `install_id` 기반으로 INSERT

---

## 3. 아키텍처

```
scripts/test-onboarding.ts
  ├─ Config          → 포트, 에뮬레이터 주소
  ├─ FirebaseHelper  → 에뮬레이터 REST API로 유저 생성 + ID Token 발급
  ├─ ApiHelper       → POST /api/v1/auth/firebase-verify 호출
  ├─ DbHelper        → pg로 직접 DB 조회 (검증용)
  ├─ ScenarioRunner  → 각 시나리오 독립 실행 (setup → execute → verify → cleanup)
  └─ Reporter        → PASS/FAIL 결과 테이블 출력
```

### Firebase 에뮬레이터 REST 플로우 (테스트용)

```
1. POST http://localhost:9099/identitytoolkit.googleapis.com/v1/accounts:signInWithPhoneNumber
   body: { phoneNumber, code: "123456" }  ← 에뮬레이터는 사전 등록된 번호만 허용
   → idToken

2. POST http://localhost:3001/api/v1/auth/firebase-verify
   body: { id_token: idToken, phone_country_code: "+82" }
   → { is_new_user, user_id, display_name, user_role, ... }
```

---

## 4. 더미 데이터

| 변수 | 전화번호 (E.164) | 용도 |
|---|---|---|
| `TEST_PHONE_NEW_TRIP` | +821099901001 | SC-01: 신규+newTrip |
| `TEST_PHONE_NEW_INVITE` | +821099901002 | SC-02: 신규+inviteCode |
| `TEST_PHONE_NEW_CONTINUE` | +821099901003 | SC-03: 신규+continueTrip |
| `TEST_PHONE_EXISTING_WITH_TRIP` | +821099901004 | SC-04,07: 기존+여행있음 |
| `TEST_PHONE_EXISTING_NO_TRIP` | +821099901005 | SC-05,06: 기존+여행없음 |
| `TEST_PHONE_ANONYMOUS` | +821099990001 | SC-08: Anonymous Auth |

---

## 5. 파일 목록

| 파일 | 설명 |
|---|---|
| `scripts/test-onboarding.ts` | 메인 테스트 스크립트 |
| `scripts/test-onboarding-setup.sql` | 기존 유저 + trip 데이터 사전 삽입 SQL |
| `scripts/test-onboarding-cleanup.sql` | 테스트 데이터 정리 SQL |
