# SafeTrip 온보딩 프로세스 설계

**작성일**: 2026-02-27
**기반**: SafeTrip 온보딩 프로세스 최종 설계안 v2.0
**구현 접근법**: GoRouter (Navigator 2.0)

---

## 1. 설계 원칙

| 원칙 | 설명 |
|---|---|
| **스마트 분기** | 토큰·회원·여행 상태에 따라 redirect에서 자동 판단 |
| **최소 마찰** | 기존 회원은 인증만으로 통과 (약관·프로필 생략) |
| **맥락적 권한 요청** | 위치 권한은 여행 생성/참여 완료 직후 요청 |
| **딥링크 지원** | 초대 링크 클릭 시 코드 자동 복원 |
| **진입 경로 보존** | OnboardingEntry enum을 GoRouter extra로 전달 |

---

## 2. 라우터 아키텍처

### 신규 파일

```
lib/
  router/
    app_router.dart        ← GoRouter 정의 + redirect 로직 (핵심)
    auth_notifier.dart     ← ChangeNotifier, GoRouter가 구독
    route_paths.dart       ← 경로 상수 모음
  models/
    onboarding/
      onboarding_entry.dart  ← enum OnboardingEntry
```

### 라우트 맵

| 경로 | 화면 | extra |
|---|---|---|
| `/` | InitialScreen | - |
| `/onboarding` | OnboardingScreen | - |
| `/onboarding/main` | StartScreen | - |
| `/auth/phone` | PhoneScreen | `OnboardingEntry` |
| `/auth/verify` | VerifyScreen | `VerifyExtra {entry, phone, countryCode, ...}` |
| `/auth/terms` | TermsScreen | `OnboardingEntry` |
| `/auth/profile` | ProfileScreen | `ProfileExtra {entry, phone, userId}` |
| `/main` | MainScreen | - |
| `/trip/create` | ScreenTripCreate | - |
| `/trip/join` | ScreenTripJoinCode | queryParam: `code` |
| `/permission` | PermissionScreen | `PermissionExtra {nextRoute}` |

---

## 3. AuthNotifier 상태

```dart
class AuthNotifier extends ChangeNotifier {
  bool isAuthenticated;      // SharedPreferences user_id + 30일 토큰
  bool hasActiveTrip;        // group_id 존재 여부
  bool isFirstLaunch;        // onboarding_completed SharedPreferences 키
  String? pendingInviteCode; // 딥링크로 진입한 초대코드 보존
}
```

---

## 4. redirect 로직

```dart
redirect: (context, state) {
  final path = state.uri.path;

  // 스플래시: 상태에 따라 자동 분기
  if (path == '/') {
    if (!isAuth) return isFirstLaunch ? '/onboarding' : '/onboarding/main';
    return hasTrip ? '/main' : '/trip/create';
  }

  // 인증된 유저가 온보딩/인증 화면 접근 시 차단
  if (isAuth && path.startsWith('/onboarding')) return '/main';
  if (isAuth && path.startsWith('/auth')) return '/main';

  // 딥링크 /trip/join 진입 시 비인증 상태면 온보딩 메인으로
  if (!isAuth && path == '/trip/join') return '/onboarding/main';

  return null; // 통과
}
```

---

## 5. 인증 완료 후 스마트 분기 (VerifyScreen)

```
전화번호 인증 완료
    │
    ▼
DB에서 사용자 조회 (phone_number 기준)
    │
┌───┴───┐
│       │
기존회원  신규회원
│       │
│       ├─ entry == continueTrip → 팝업: "가입 이력 없음" → /onboarding/main
│       └─ 아니면 → context.go('/auth/terms', extra: entry)
│
├─ entry == newTrip
│     → hasActiveTrip? → /main (토스트: "돌아오셨군요! 👋")
│                      → /trip/create
│
├─ entry == inviteCode
│     → context.go('/trip/join', extra: pendingCode)
│
└─ entry == continueTrip
      → context.go('/main')
```

---

## 6. 딥링크

커스텀 스킴: `safetrip://trip/join?code=T-ABCD-1234`

- Android: `AndroidManifest.xml` intent-filter 추가
- iOS: `Info.plist` URL Scheme 추가
- 비인증 상태 딥링크 진입 시: `AuthNotifier.pendingInviteCode`에 코드 보존 → 인증 완료 후 자동 복원

---

## 7. 온보딩 메인 화면 (StartScreen) 변경

기존 2갈래 → 3갈래:

| 버튼 | 레이블 | entryPath | 다음 화면 |
|---|---|---|---|
| Primary | 새 여행 만들기 | `newTrip` | `/auth/phone` |
| Secondary | 초대 코드로 참여하기 | `inviteCode` | `/auth/phone` |
| Outlined | 기존 여행으로 돌아가기 | `continueTrip` | `/auth/phone` |

---

## 8. 권한 요청 위치 변경

**기존**: 온보딩 초기 (OnboardingScreen → PermissionScreen → StartScreen)
**변경**: 여행 생성 완료(`/trip/create`) 또는 초대코드 참여 완료(`/trip/join`) 직후 → `/permission` → `/main`

---

## 9. 삭제 대상

- `lib/screens/auth/screen_4_role.dart` — 역할 선택 화면 제거
  역할은 초대코드 분석(`T-` = crew, `G-` = guardian)으로 자동 결정

---

## 10. 변경 파일 목록

### 신규 생성
```
lib/router/app_router.dart
lib/router/auth_notifier.dart
lib/router/route_paths.dart
lib/models/onboarding/onboarding_entry.dart
docs/plans/2026-02-27-onboarding-design.md
```

### 수정
```
pubspec.yaml                                     ← go_router 추가
lib/main.dart                                    ← MaterialApp.router 전환
lib/screens/screen_splash.dart                   ← 로딩 UI만 유지
lib/screens/onboarding/screen_1_onboarding.dart  ← 5장→2장, 최초설치만 표시
lib/screens/auth/screen_3_start.dart             ← 3갈래 버튼
lib/screens/auth/screen_7_verify.dart            ← 기존회원 판별 + 분기
lib/screens/auth/screen_8_profile.dart           ← context.go(최종목적지)
lib/screens/auth/screen_5_terms.dart             ← context.go('/auth/profile')
lib/screens/trip/screen_trip_join_code.dart      ← 완료 후 /permission
lib/screens/trip/screen_trip_create.dart         ← 완료 후 /permission
lib/screens/screen_permission.dart               ← 완료 후 /main
```

### 삭제
```
lib/screens/auth/screen_4_role.dart
```

---

## 11. 구현 우선순위 (v1 MVP)

1. GoRouter 기반 인프라 (app_router, auth_notifier, route_paths)
2. OnboardingEntry enum + main.dart 전환
3. StartScreen 3갈래 + 최초설치 체크
4. VerifyScreen 기존회원 판별 분기
5. Terms/Profile/Permission → context.go 전환
6. screen_4_role.dart 삭제
7. 딥링크 Android/iOS 설정

---

## 12. 전체 진입 경로별 화면 경유 요약

| 진입 경로 | 토큰 | 회원 | 기존 여행 | 화면 경유 |
|---|---|---|---|---|
| 새 여행 만들기 | 유효 | - | 있음 | 스플래시 → **메인** (토스트) |
| 새 여행 만들기 | 유효 | - | 없음 | 스플래시 → **여행생성** → 권한 |
| 새 여행 만들기 | 없음 | 기존 | 있음 | 온보딩메인 → 인증 → **메인** |
| 새 여행 만들기 | 없음 | 기존 | 없음 | 온보딩메인 → 인증 → **여행생성** → 권한 |
| 새 여행 만들기 | 없음 | 신규 | - | 온보딩메인 → 인증 → 약관 → 프로필 → **여행생성** → 권한 |
| 초대 코드 | 유효 | - | - | 온보딩메인 → **초대코드** → 권한 |
| 초대 코드 | 없음 | 기존 | - | 온보딩메인 → 인증 → **초대코드** → 권한 |
| 초대 코드 | 없음 | 신규 | - | 온보딩메인 → 인증 → 약관 → 프로필 → **초대코드** → 권한 |
| 돌아가기 | 유효 | - | - | 스플래시 → **메인** |
| 돌아가기 | 없음 | 기존 | - | 온보딩메인 → 인증 → **메인** |
| 돌아가기 | 없음 | 비회원 | - | 온보딩메인 → 인증 → 팝업 → **온보딩메인** |
| 딥링크 초대 | 유효 | - | - | 딥링크 → **초대코드(자동)** → 권한 |
| 딥링크 초대 | 없음 | 기존 | - | 딥링크 → 온보딩메인 → 인증 → **초대코드(자동)** |
| 딥링크 초대 | 없음 | 신규 | - | 딥링크 → 온보딩메인 → 인증 → 약관 → 프로필 → **초대코드(자동)** |
