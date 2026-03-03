# SafeTrip 온보딩 전면 고도화 설계

**작성일**: 2026-02-27
**방향**: B+C 혼합 — 서사형 역할 선택 + Progressive 프로파일
**목표**: 11단계 → 5~6단계, UX/전환율 개선

---

## 1. 배경 및 문제 정의

### 현행 플로우 (11단계)
```
Splash → 인트로 캐러셀 → 시작화면 → 전화번호 → OTP → 약관동의
→ 프로필 설정 → 여행 생성 → 권한 요청 → 여행 확인 → 메인
```

### 주요 문제점
| 문제 | 영향 |
|------|------|
| 단계가 너무 많음 (11단계) | 이탈률 증가 |
| 여행 생성이 온보딩 중간에 배치 | 부자연스러운 UX, 크루/가디언에게 불필요 |
| 인트로 캐러셀이 실질적 가치 없음 | 대부분 스킵, 낭비 |
| 캡틴/크루 역할 안내 부족 | 혼선, 잘못된 진입 경로 선택 |

### 벤치마크 분석
- **Slack/Discord**: 초대 코드 → 역할 자동 감지 → 이름만 입력 → 완료
- **Airbnb**: 최소 정보 수집, 나머지는 컨텍스트 기반 단계적 요청
- **TripIt**: 인증 후 즉시 가치 접근, 여행 설정 나중에

---

## 2. 신규 플로우 설계

### 메인 플로우 (5~6단계)
```
1. Splash (유지)
2. 역할 선택 화면 (신규 — 인트로 캐러셀 + 시작화면 통합)
3. 전화 + OTP 통합 화면 (신규 — 2화면 → 1화면, 인라인 약관 포함)
4. 핵심 정보 입력 (역할별 분기)
   ├─ 캡틴: 이름 + 여행 기본정보 (1화면)
   └─ 크루/가디언: 이름만 (1화면)
5. 권한 요청 (Android만, 유지)
6. 메인 앱 (스마트 웰컴 배너)
```

### 초대 코드 딥링크 플로우 (4단계)
```
링크 클릭 → 여행 미리보기 (인증 없이)
→ 전화 + OTP → 이름 입력 → 합류 완료
```
- 역할은 초대 코드 prefix에서 자동 감지 (A/M/V)
- 역할 선택 화면 스킵

---

## 3. 화면별 상세 설계

### Step 2: 역할 선택 화면 (screen_role_select.dart) [신규]

**기존 대체**: `screen_1_onboarding.dart` + `screen_3_start.dart` 삭제

**UI 구성**:
- 배경: `bg.mp4` 루프 (기존 유지)
- 헤드카피: "이번 여행에서 나는?"
- 3개 서사형 역할 카드 (탭 → 즉시 다음 화면)
  - 🏔 **캡틴** — "여행을 만들고 팀을 이끄는 사람" / 일정 생성·멤버 초대·SOS 수신
  - 🎒 **크루** — "여행에 함께하는 사람" / 위치 공유·SOS 발신·일정 확인
  - 🛡 **가디언** — "집에서 안전을 지켜보는 사람" / 위치 모니터링·알림 수신
- 하단: "초대 코드가 있어요 →" 텍스트 링크 → 코드 입력 시트 팝업

**State**: `selectedRole` (captain / crew / guardian)
**Navigation**: 역할 선택 → `/auth/phone-auth`

---

### Step 3: 전화 + OTP 통합 화면 (screen_phone_auth.dart) [신규]

**기존 대체**: `screen_6_phone.dart` + `screen_7_verify.dart` + `screen_5_terms.dart` 삭제

**UI 상태 전환**:
1. **입력 상태**: 국가코드 + 전화번호 + "인증 코드 받기" 버튼
2. **인증 상태**: OTP 6자리 입력 + 카운트다운 + 재발송 버튼 (슬라이드 업 애니메이션)

**약관 처리**: 하단 인라인 텍스트 — "계속하면 이용약관 및 개인정보처리방침에 동의합니다 [자세히 보기 ↗]"
- "자세히 보기": ModalBottomSheet로 4개 약관 항목 표시 (별도 화면 불필요)
- DB 저장: OTP 인증 완료 시 `terms_agreed_at`, `terms_version` 자동 저장

**기존 로직 유지**:
- 테스트 전화번호 처리 (TestAuthConfig)
- 에뮬레이터 자동 OTP 입력
- `ApiService.syncUserWithFirebase()` 호출

---

### Step 4: 핵심 정보 입력 (역할별 분기)

#### 캡틴 (screen_captain_setup.dart) [신규]
```
내 이름: [                    ]
─── 첫 여행 설정 ───────────────
여행 이름: [                   ]
어디로?  [나라 검색...           ]
언제?   [출발] ~ [도착]
[여행 시작하기]
```
- 단일 스크롤 화면에 모든 필드
- API: `POST /api/v1/trips/create` (기존) + `PUT /api/v1/users/:id` (이름 저장)
- DOB, 아바타: 메인 앱 프로필 편집에서 선택적 입력

#### 크루 / 가디언 (screen_crew_setup.dart) [신규]
```
반가워요!
팀에서 어떻게 불릴까요?
이름: [                      ]
[시작하기]
```
- API: `PUT /api/v1/users/:id` (이름만)
- 여행 합류: 초대 코드로 이미 처리됨 (딥링크 플로우)

---

### Step 6: 메인 앱 — 스마트 웰컴 배너

**온보딩 완료 상태 추적** (`onboarding_step` 필드):
- `complete`: 모든 정보 완료
- `profile_pending`: 아바타/DOB 미입력 (배너 표시)
- `trip_pending`: 캡틴이지만 여행 미생성 (배너 표시)

**배너 동작**:
- 홈 화면 상단 고정 (닫기 가능)
- "프로필을 완성하면 멤버들이 나를 알아볼 수 있어요" → 프로필 편집 이동

---

## 4. 백엔드 변경 사항

### 신규 API 엔드포인트

#### GET /api/v1/trips/preview/:code
```typescript
// 인증 없이 초대 코드로 여행 미리보기
Response: {
  trip_id: string,
  trip_name: string,
  country_name: string,
  start_date: string,
  end_date: string,
  captain_name: string,
  member_count: number,
  role: 'crew_chief' | 'crew' | 'guardian',  // 코드 prefix 기반
}
```

#### PATCH /api/v1/users/:id/terms
```typescript
// 약관 동의 저장
Body: { terms_version: string }
Response: { terms_agreed_at: string }
```

### DB 스키마 변경

```sql
-- 약관 동의 이력 및 온보딩 상태 추가
ALTER TABLE tb_user
  ADD COLUMN terms_agreed_at TIMESTAMP,
  ADD COLUMN terms_version VARCHAR(10) DEFAULT '1.0',
  ADD COLUMN onboarding_step VARCHAR(20) DEFAULT 'complete';
-- onboarding_step: 'complete' | 'profile_pending' | 'trip_pending'
```

### 기존 API 재사용
- `POST /api/v1/trips/create` — 캡틴 여행 생성 (기존 유지)
- `PUT /api/v1/users/:id` — 프로필 업데이트 (기존 유지)
- `POST /api/v1/trips/join-by-code` — 초대 코드 합류 (기존 유지)
- `POST /api/v1/users/sync` — Firebase 인증 후 사용자 동기화 (기존 유지)

---

## 5. Flutter 파일 변경 목록

### 삭제
- `lib/screens/onboarding/screen_1_onboarding.dart`
- `lib/screens/auth/screen_3_start.dart`
- `lib/screens/auth/screen_5_terms.dart`

### 신규 생성
- `lib/screens/onboarding/screen_role_select.dart` — 역할 선택 + 서사 카드
- `lib/screens/auth/screen_phone_auth.dart` — 전화+OTP 통합 + 인라인 약관
- `lib/screens/auth/screen_captain_setup.dart` — 캡틴 이름+여행 입력
- `lib/screens/auth/screen_crew_setup.dart` — 크루/가디언 이름 입력

### 수정
- `lib/router/app_router.dart` — 라우트 재편성 (삭제된 경로 제거, 신규 경로 추가)
- `lib/router/route_paths.dart` — 경로 상수 업데이트
- `lib/router/auth_notifier.dart` — `onboarding_step` 상태 추가
- `lib/services/api_service.dart` — 신규 API 메서드 추가

---

## 6. Firebase / 딥링크

### App Links (Android) / Universal Links (iOS)
```
safetrip://join?code=AXXXXXX  →  여행 미리보기 화면 오픈
```
- `AndroidManifest.xml`, `ios/Runner/Info.plist`에 intent-filter / associated-domains 추가
- `auth_notifier.dart`의 `_pendingInviteCode` 기존 로직 재활용

---

## 7. 구현 우선순위

| 우선순위 | 항목 | 예상 영향 |
|---------|------|----------|
| P0 | 역할 선택 화면 (screen_role_select) | 핵심 UX 개선 |
| P0 | 전화+OTP 통합 (screen_phone_auth) | 2단계 → 1단계 |
| P1 | 캡틴/크루 셋업 화면 | 프로필+여행 분리 |
| P1 | 백엔드 DB 스키마 변경 | 약관 저장 |
| P2 | 여행 미리보기 API | 딥링크 UX |
| P2 | 웰컴 배너 (메인 앱) | deferred profile |
| P3 | App Links / Universal Links | 딥링크 완성 |

---

## 8. 미결 사항

- 초대 코드 딥링크: Firebase Dynamic Links vs 자체 URL Scheme 선택 필요
- 약관 버전 관리 전략 (향후 약관 변경 시 재동의 처리)
- 캡틴이 여행을 나중에 생성할 때의 UX (trip_pending 배너 → 여행 생성 플로우)
