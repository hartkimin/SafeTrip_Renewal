# 온보딩 UX 구현 설계

| 항목 | 내용 |
|------|------|
| 날짜 | 2026-03-05 |
| 기준 문서 | `14_T3_온보딩_UX_시나리오.md` v3.1 |
| 구현 범위 | Phase 1 (P0 + P1) |
| 아키텍처 | Feature 모듈 분리 (Clean Architecture) |

---

## 1. 구현 범위

### Phase 1 포함 항목
- **P0**: 전화번호 OTP 인증 개선, 약관 동의 화면 §06.5 정합, 초대코드 참여(시나리오 B), 복귀 사용자 토큰 복원(시나리오 D)
- **P1**: 가디언 초대 참여(시나리오 C), 여행 기간 15일 제한, 프라이버시 등급 선택
- 딥링크 + 수동 입력 모두 지원

### Phase 1 제외 (Phase 2+)
- 미성년자 동의 분기 실행 (나이 계산 + is_minor 플래그만 Phase 1)
- B2B CSV 일괄 등록 (시나리오 E)
- GDPR/Firebase 국외이전 동의 (EU 화면 구조만, 실동작은 Phase 2)
- 데모 모드 완전 구현

---

## 2. 디렉토리 구조

```
lib/features/onboarding/
├── data/
│   ├── onboarding_repository.dart       # API 호출 (약관 저장, 사용자 동기화)
│   └── deeplink_service.dart            # 딥링크 파싱 & 파라미터 캐싱
├── domain/
│   ├── onboarding_type.dart             # enum: captain, inviteCode, guardian, returning
│   ├── onboarding_step.dart             # enum: 각 온보딩 단계
│   └── consent_model.dart               # 약관 동의 데이터 모델
├── presentation/
│   ├── screens/
│   │   ├── screen_welcome.dart          # 기존 screen_intro.dart 이동
│   │   ├── screen_purpose_select.dart   # 기존 screen_role_select.dart 이동
│   │   ├── screen_phone_auth.dart       # 기존 이동
│   │   ├── screen_terms_consent.dart    # 기존 이동 + §8 정합
│   │   ├── screen_birth_date.dart       # 신규
│   │   ├── screen_profile_setup.dart    # 기존 이동
│   │   ├── screen_invite_confirm.dart   # 신규
│   │   └── screen_guardian_confirm.dart # 신규
│   └── widgets/
│       ├── onboarding_progress_bar.dart
│       ├── consent_item_tile.dart
│       └── otp_input_field.dart
└── providers/
    └── onboarding_provider.dart         # Riverpod 온보딩 상태
```

기존 파일 이동:
- `screens/onboarding/screen_intro.dart` → `features/onboarding/presentation/screens/screen_welcome.dart`
- `screens/onboarding/screen_role_select.dart` → `features/onboarding/presentation/screens/screen_purpose_select.dart`
- `screens/auth/screen_phone_auth.dart` → `features/onboarding/presentation/screens/screen_phone_auth.dart`
- `screens/auth/screen_terms_consent.dart` → `features/onboarding/presentation/screens/screen_terms_consent.dart`
- `screens/auth/screen_profile_setup.dart` → `features/onboarding/presentation/screens/screen_profile_setup.dart`

---

## 3. 시나리오별 플로우

### 시나리오 A — 여행장 주도 신규 가입
```
Splash → Welcome(4슬라이드) → PurposeSelect["여행 만들기"]
  → PhoneAuth → OTP → TermsConsent → BirthDate → Profile
  → TripCreate(선택) → Main(캡틴)
```

### 시나리오 B — 초대코드 참여
```
딥링크 or 수동입력 → Splash(파라미터 보존)
  → PhoneAuth → OTP → TermsConsent → BirthDate → Profile
  → InviteConfirm(여행명, 캡틴, 역할) → Main(크루/크루장)
```

### 시나리오 C — 가디언 초대
```
SMS 링크 → Splash(guardian_invite 딥링크)
  → PhoneAuth → OTP → TermsConsent
  → GuardianConfirm(멤버명, 여행정보) → Main(가디언UI)
```

### 시나리오 D — 복귀 사용자
```
Splash → 토큰 유효?
  ├── Yes → Main(자동 여행 배정: active > planning > 시작일순)
  └── No → PhoneAuth → OTP → Main(약관/프로필 생략)
```

---

## 4. 라우팅 설계

### AuthNotifier 확장
```dart
enum OnboardingType { captain, inviteCode, guardian, returning }

// 추가 필드
OnboardingType? onboardingType;
String? pendingInviteCode;      // 시나리오 B
String? pendingGuardianLinkId;  // 시나리오 C
```

### 온보딩 라우트 순서 (문서 v3.1 기준)
```
'/' → splash
'/onboarding/welcome' → 웰컴 슬라이드 (기존 /onboarding/intro)
'/onboarding/purpose' → 목적 선택 (기존 /onboarding/role)
'/auth/phone' → 전화번호 입력 + OTP (기존 /auth/phone-auth)
'/auth/terms' → 약관 동의 (순서 변경: 인증 후로)
'/auth/birth-date' → 생년월일 (신규)
'/auth/profile' → 프로필 설정 (기존 /auth/profile-setup)
'/onboarding/invite-confirm' → 초대코드 확인 (신규)
'/onboarding/guardian-confirm' → 가디언 확인 (신규)
'/main' → 메인
```

### 딥링크 URI
```
safetrip://invite?code=ABC123         → 시나리오 B
safetrip://guardian?link_id=456       → 시나리오 C
https://safetrip.app/invite/ABC123    → Universal Link (B)
https://safetrip.app/guardian/456     → Universal Link (C)
```

---

## 5. 화면 상세

### 5.1 약관 동의 (§8 정합)

항목 구성 (기존 5개 → 4+2):
```
[전체 동의]
─────────────
[필수] 서비스 이용약관           → [전문 보기]
[필수] 개인정보처리방침          → [전문 보기]
[필수] 위치기반서비스 이용약관    → [전문 보기]
[선택] 마케팅 정보 수신 동의
─────────────
[EU 사용자만 — locale 기반 판별]
[필수] GDPR 개인정보 처리 동의
[필수] Firebase 국외 이전 동의
```

- 기존 "14세 이상" 체크박스 제거 → 생년월일 화면에서 자동 판단
- 필수 미체크 시: 미체크 항목 하이라이트 + 안내 메시지
- 동의 기록: `tb_user_consent` INSERT (consent_type, is_agreed, agreed_at, version)

### 5.2 생년월일 입력 (신규)

- CupertinoDatePicker 또는 드롭다운(연/월/일)
- 나이 계산:
  - 18세 이상 → 정상 진행
  - 14~17세 → Phase 1: 경고 + `is_minor=true` 저장, Phase 2: 보호자 동의
  - 14세 미만 → Phase 1: 경고 + `is_minor=true`, Phase 2: 법정대리인 OTP

### 5.3 초대코드 확인 (신규)

- API: `GET /api/v1/invite-codes/:code` → 여행명, 캡틴명, 역할 조회
- [참여 확인]: `POST /api/v1/groups/join-by-code/:code` 호출
- [거절]: PurposeSelect 화면으로 복귀

### 5.4 가디언 초대 확인 (신규)

- API: `GET /api/v1/trips/:tripId/guardians/:linkId` → 멤버명, 여행정보
- [수락]: `PATCH /api/v1/trips/:tripId/guardians/:linkId/respond { action: 'accepted' }`
- [거절]: `PATCH ... { action: 'rejected' }` → 앱 종료 또는 PurposeSelect

### 5.5 여행 기간 15일 제한 (기존 수정)

- `screen_trip_create.dart`에서 날짜 선택 시 기간 계산 로직 추가
- 15일 초과 → 모달 표시 (1차 여행 생성 / 취소)
- 15일 도달 → 인라인 안내 메시지

---

## 6. 데이터 모델

### consent_model.dart
```dart
class ConsentModel {
  final bool termsOfService;     // 필수
  final bool privacyPolicy;      // 필수
  final bool lbsTerms;           // 필수
  final bool marketing;          // 선택
  final bool? gdpr;              // EU만
  final bool? firebaseTransfer;  // EU만
  final String version;          // '2026-03-01'
}
```

### onboarding_type.dart
```dart
enum OnboardingType { captain, inviteCode, guardian, returning }
```

### onboarding_step.dart
```dart
enum OnboardingStep {
  splash, welcome, purpose, phone, otp, terms,
  birthDate, profile, tripCreate, inviteConfirm,
  guardianConfirm, main
}
```

---

## 7. 에러 & 엣지케이스 (Phase 1)

| 케이스 | 처리 |
|--------|------|
| OTP 만료 (3분) | 재발송 버튼, 1분 후 재활성화 |
| OTP 3회 오입력 | 1분 대기 후 재시도 |
| 딥링크 만료 | "초대코드가 만료되었습니다" 안내 |
| 이미 가입된 번호 | 시나리오 D 자동 전환 |
| 약관 동의 중단 | 재진입 시 동의 화면부터 |
| 여행 기간 15일 초과 | 모달 + 차단 |
| 오프라인 OTP/약관/여행생성 | "인터넷 연결 필요" 안내 |

---

## 8. 변경 영향 범위

### 수정 파일
- `lib/router/app_router.dart` — 라우트 순서 변경, 새 라우트 추가
- `lib/router/route_paths.dart` — 경로 상수 추가/변경
- `lib/router/auth_notifier.dart` — onboardingType, 딥링크 파라미터 필드 추가
- `lib/main.dart` — 딥링크 초기화
- `lib/screens/screen_splash.dart` — 딥링크 파라미터 캡처
- `lib/screens/trip/screen_trip_create.dart` — 15일 제한 로직

### 이동 파일 (5개)
- screen_intro → screen_welcome
- screen_role_select → screen_purpose_select
- screen_phone_auth → 이동
- screen_terms_consent → 이동 + 수정
- screen_profile_setup → 이동

### 신규 파일 (약 10개)
- domain: 3 (onboarding_type, onboarding_step, consent_model)
- data: 2 (onboarding_repository, deeplink_service)
- screens: 3 (birth_date, invite_confirm, guardian_confirm)
- widgets: 3 (progress_bar, consent_tile, otp_field)
- providers: 1 (onboarding_provider)
