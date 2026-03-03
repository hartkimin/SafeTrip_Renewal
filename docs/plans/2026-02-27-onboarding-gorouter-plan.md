# SafeTrip 온보딩 GoRouter 재설계 구현 계획

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** GoRouter 기반 선언적 라우팅으로 온보딩 흐름을 재설계하여, 진입 경로(newTrip/inviteCode/continueTrip)에 따른 스마트 분기, 기존 회원 약관·프로필 생략, 딥링크 지원을 구현한다.

**Architecture:** GoRouter의 `redirect` 함수 단일 진입점에서 인증 상태를 판단하여 자동 분기한다. `AuthNotifier(ChangeNotifier)`가 SharedPreferences 상태를 래핑하고 GoRouter가 구독하여 상태 변경 시 자동 리다이렉트한다. 화면 간 진입 경로는 GoRouter `extra` 파라미터로 전달한다.

**Tech Stack:** Flutter, go_router ^14.x, SharedPreferences, Firebase Auth

---

## 사전 지식

### 현재 화면 번호 매핑
| 파일 | 역할 |
|---|---|
| `screen_splash.dart` | 스플래시 + 토큰 검증 (InitialScreen) |
| `screen_1_onboarding.dart` | 가치 소개 캐러셀 (5장) |
| `screen_3_start.dart` | 온보딩 메인 (2갈래: 시작/초대코드) |
| `screen_4_role.dart` | 역할 선택 → **삭제 대상** |
| `screen_5_terms.dart` | 약관 동의 |
| `screen_6_phone.dart` | 전화번호 입력 |
| `screen_7_verify.dart` | SMS 인증 |
| `screen_8_profile.dart` | 프로필 설정 |

### GoRouter extra 패턴
GoRouter의 `extra`는 `Object?` 타입이다. Map<String, dynamic>으로 전달하고 수신 측에서 캐스팅한다.
```dart
context.push('/auth/phone', extra: {'entry': OnboardingEntry.newTrip});
// 수신
final extra = state.extra as Map<String, dynamic>;
final entry = extra['entry'] as OnboardingEntry;
```

### AuthNotifier → GoRouter 연결
```dart
GoRouter(
  refreshListenable: authNotifier,   // 상태 변경 시 redirect 재실행
  redirect: (context, state) { ... },
)
```

---

## Task 1: go_router 패키지 추가

**Files:**
- Modify: `safetrip-mobile/pubspec.yaml`

**Step 1: pubspec.yaml에 go_router 추가**

`dependencies:` 섹션 끝에 추가:
```yaml
  # 라우팅
  go_router: ^14.6.2
```

**Step 2: 패키지 설치**

```bash
cd /mnt/d/Project/15_SafeTrip_New/safetrip-mobile
flutter pub get
```

Expected: `go_router 14.x.x` 포함 출력. 오류 없음.

**Step 3: 커밋**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "feat: add go_router dependency"
```

---

## Task 2: OnboardingEntry enum 생성

**Files:**
- Create: `safetrip-mobile/lib/models/onboarding/onboarding_entry.dart`

**Step 1: 파일 생성**

```dart
// lib/models/onboarding/onboarding_entry.dart

enum OnboardingEntry {
  newTrip,      // 새 여행 만들기
  inviteCode,   // 초대 코드로 참여하기
  continueTrip, // 기존 여행으로 돌아가기
}
```

**Step 2: 커밋**

```bash
git add lib/models/onboarding/onboarding_entry.dart
git commit -m "feat: add OnboardingEntry enum"
```

---

## Task 3: RoutePaths 상수 생성

**Files:**
- Create: `safetrip-mobile/lib/router/route_paths.dart`

**Step 1: 파일 생성**

```dart
// lib/router/route_paths.dart

class RoutePaths {
  static const splash       = '/';
  static const onboarding   = '/onboarding';
  static const onboardingMain = '/onboarding/main';
  static const authPhone    = '/auth/phone';
  static const authVerify   = '/auth/verify';
  static const authTerms    = '/auth/terms';
  static const authProfile  = '/auth/profile';
  static const main         = '/main';
  static const tripCreate   = '/trip/create';
  static const tripJoin     = '/trip/join';
  static const permission   = '/permission';
}
```

**Step 2: 커밋**

```bash
git add lib/router/route_paths.dart
git commit -m "feat: add RoutePaths constants"
```

---

## Task 4: AuthNotifier 생성

**Files:**
- Create: `safetrip-mobile/lib/router/auth_notifier.dart`

**Step 1: 파일 생성**

```dart
// lib/router/auth_notifier.dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthNotifier extends ChangeNotifier {
  bool _isAuthenticated = false;
  bool _hasActiveTrip = false;
  bool _isFirstLaunch = true;
  String? _pendingInviteCode;
  bool _isLoading = true;

  bool get isAuthenticated => _isAuthenticated;
  bool get hasActiveTrip => _hasActiveTrip;
  bool get isFirstLaunch => _isFirstLaunch;
  bool get isLoading => _isLoading;
  String? get pendingInviteCode => _pendingInviteCode;

  AuthNotifier() {
    _loadState();
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();

    final userId = prefs.getString('user_id');
    final authVerifiedAtStr = prefs.getString('auth_verified_at');
    final groupId = prefs.getString('group_id');
    final onboardingCompleted = prefs.getBool('onboarding_completed') ?? false;

    // 토큰 유효성: user_id 있고 30일 이내 인증
    bool tokenValid = false;
    if (userId != null && userId.isNotEmpty && authVerifiedAtStr != null) {
      final verifiedAt = DateTime.tryParse(authVerifiedAtStr);
      if (verifiedAt != null) {
        tokenValid = DateTime.now().toUtc().difference(verifiedAt).inDays < 30;
      }
    }

    _isAuthenticated = tokenValid;
    _hasActiveTrip = groupId != null && groupId.isNotEmpty;
    _isFirstLaunch = !onboardingCompleted;
    _isLoading = false;

    notifyListeners();
  }

  /// 온보딩 캐러셀 완료 시 호출 (최초 설치 플래그 저장)
  Future<void> completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);
    _isFirstLaunch = false;
    notifyListeners();
  }

  /// 인증 완료 시 호출
  Future<void> setAuthenticated({required bool hasTrip}) async {
    _isAuthenticated = true;
    _hasActiveTrip = hasTrip;
    notifyListeners();
  }

  /// 여행 참여/생성 완료 시 호출
  Future<void> setHasActiveTrip(bool value) async {
    _hasActiveTrip = value;
    notifyListeners();
  }

  /// 딥링크 초대코드 보존
  void setPendingInviteCode(String? code) {
    _pendingInviteCode = code;
    // notifyListeners 불필요 (redirect 재실행 불필요)
  }

  /// 로그아웃 시 호출
  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_id');
    await prefs.remove('auth_verified_at');
    await prefs.remove('group_id');
    await prefs.remove('user_role');
    _isAuthenticated = false;
    _hasActiveTrip = false;
    notifyListeners();
  }
}
```

**Step 2: 커밋**

```bash
git add lib/router/auth_notifier.dart
git commit -m "feat: add AuthNotifier ChangeNotifier"
```

---

## Task 5: AppRouter 생성

**Files:**
- Create: `safetrip-mobile/lib/router/app_router.dart`

**Step 1: 파일 생성**

아래 코드에서 각 화면 import는 실제 파일 경로에 맞게 조정한다.
`GoRoute`의 `builder`는 아직 존재하지 않는 화면은 `TODO` 주석으로 표시하고 임시로 `Placeholder()` 반환.

```dart
// lib/router/app_router.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/onboarding/onboarding_entry.dart';
import '../screens/auth/screen_3_start.dart';
import '../screens/auth/screen_5_terms.dart';
import '../screens/auth/screen_6_phone.dart';
import '../screens/auth/screen_7_verify.dart';
import '../screens/auth/screen_8_profile.dart';
import '../screens/main/screen_main.dart';
import '../screens/onboarding/screen_1_onboarding.dart';
import '../screens/screen_permission.dart';
import '../screens/screen_splash.dart';
import '../screens/trip/screen_trip_create.dart';
import '../screens/trip/screen_trip_join_code.dart';
import 'auth_notifier.dart';
import 'route_paths.dart';

class AppRouter {
  final AuthNotifier authNotifier;

  AppRouter(this.authNotifier);

  late final GoRouter router = GoRouter(
    initialLocation: RoutePaths.splash,
    refreshListenable: authNotifier,
    redirect: _redirect,
    routes: _routes,
  );

  String? _redirect(BuildContext context, GoRouterState state) {
    final path = state.uri.path;
    final isLoading = authNotifier.isLoading;
    final isAuth = authNotifier.isAuthenticated;
    final hasTrip = authNotifier.hasActiveTrip;
    final isFirst = authNotifier.isFirstLaunch;

    // 로딩 중에는 스플래시 유지
    if (isLoading) return path == RoutePaths.splash ? null : RoutePaths.splash;

    // 스플래시: 상태에 따라 자동 분기
    if (path == RoutePaths.splash) {
      if (!isAuth) {
        return isFirst ? RoutePaths.onboarding : RoutePaths.onboardingMain;
      }
      return hasTrip ? RoutePaths.main : RoutePaths.tripCreate;
    }

    // 인증된 유저가 온보딩/인증 화면 접근 시 차단
    if (isAuth && path.startsWith('/onboarding')) return RoutePaths.main;
    if (isAuth && path.startsWith('/auth')) return RoutePaths.main;

    // 딥링크 /trip/join 진입 시 비인증 상태면 온보딩 메인으로
    if (!isAuth && path == RoutePaths.tripJoin) {
      // 초대코드는 state.uri.queryParameters['code']에서 추출하여 보존
      final code = state.uri.queryParameters['code'];
      if (code != null) authNotifier.setPendingInviteCode(code);
      return RoutePaths.onboardingMain;
    }

    return null; // 통과
  }

  List<RouteBase> get _routes => [
    GoRoute(
      path: RoutePaths.splash,
      builder: (context, state) => const InitialScreen(),
    ),
    GoRoute(
      path: RoutePaths.onboarding,
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: RoutePaths.onboardingMain,
      builder: (context, state) => const StartScreen(),
    ),
    GoRoute(
      path: RoutePaths.authPhone,
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};
        final entry = extra['entry'] as OnboardingEntry? ?? OnboardingEntry.newTrip;
        return PhoneScreen(entry: entry);
      },
    ),
    GoRoute(
      path: RoutePaths.authVerify,
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        return VerifyScreen(
          entry: extra['entry'] as OnboardingEntry,
          phoneNumber: extra['phoneNumber'] as String,
          countryCode: extra['countryCode'] as String,
          verificationId: extra['verificationId'] as String?,
          resendToken: extra['resendToken'] as int?,
          autoVerified: extra['autoVerified'] as bool? ?? false,
          credential: extra['credential'],
          isTestAuth: extra['isTestAuth'] as bool? ?? false,
        );
      },
    ),
    GoRoute(
      path: RoutePaths.authTerms,
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};
        final entry = extra['entry'] as OnboardingEntry? ?? OnboardingEntry.newTrip;
        return TermsScreen(entry: entry);
      },
    ),
    GoRoute(
      path: RoutePaths.authProfile,
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        return ProfileScreen(
          entry: extra['entry'] as OnboardingEntry,
          phoneNumber: extra['phoneNumber'] as String,
          countryCode: extra['countryCode'] as String,
          userId: extra['userId'] as String,
          isNewUser: extra['isNewUser'] as bool? ?? true,
          displayName: extra['displayName'] as String?,
        );
      },
    ),
    GoRoute(
      path: RoutePaths.main,
      builder: (context, state) => const MainScreen(),
    ),
    GoRoute(
      path: RoutePaths.tripCreate,
      builder: (context, state) => const ScreenTripCreate(),
    ),
    GoRoute(
      path: RoutePaths.tripJoin,
      builder: (context, state) {
        final code = state.uri.queryParameters['code'];
        return ScreenTripJoinCode(
          joinType: JoinType.autoDetect,
          fromOnboarding: true,
          prefilledCode: code,
        );
      },
    ),
    GoRoute(
      path: RoutePaths.permission,
      builder: (context, state) => const PermissionScreen(),
    ),
  ];
}
```

**Step 2: 커밋 (컴파일 오류 있어도 구조 먼저 커밋)**

```bash
git add lib/router/app_router.dart
git commit -m "feat: add AppRouter with GoRouter redirect logic"
```

---

## Task 6: main.dart → MaterialApp.router 전환

**Files:**
- Modify: `safetrip-mobile/lib/main.dart`

**Step 1: MyApp 클래스를 StatefulWidget으로 변경하고 AppRouter/AuthNotifier 주입**

`MyApp` 클래스를 찾아 아래와 같이 교체한다. `main()` 함수와 headless task 코드는 건드리지 않는다.

교체 대상: `class MyApp extends StatelessWidget { ... }` (파일 끝)

```dart
// main.dart 상단 imports에 추가
import 'router/app_router.dart';
import 'router/auth_notifier.dart';

// MyApp 교체
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final AuthNotifier _authNotifier;
  late final AppRouter _appRouter;

  @override
  void initState() {
    super.initState();
    _authNotifier = AuthNotifier();
    _appRouter = AppRouter(_authNotifier);
  }

  @override
  void dispose() {
    _authNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'SafeTrip',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ko', 'KR'),
        Locale('en', 'US'),
      ],
      locale: const Locale('ko', 'KR'),
      builder: (context, child) {
        SystemChrome.setSystemUIOverlayStyle(
          const SystemUiOverlayStyle(
            systemNavigationBarColor: Colors.white,
            systemNavigationBarIconBrightness: Brightness.dark,
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
          ),
        );
        return child!;
      },
      routerConfig: _appRouter.router,
    );
  }
}
```

**Step 2: 컴파일 확인**

```bash
flutter build apk --debug 2>&1 | head -50
```

Expected: 여러 오류가 있을 수 있음 (아직 화면들이 새 시그니처를 지원하지 않으므로). 오류 목록을 파악하고 다음 Task에서 해결한다.

**Step 3: 커밋**

```bash
git add lib/main.dart
git commit -m "feat: migrate MyApp to MaterialApp.router with GoRouter"
```

---

## Task 7: InitialScreen (screen_splash.dart) 단순화

**Files:**
- Modify: `safetrip-mobile/lib/screens/screen_splash.dart`

**배경:** GoRouter의 redirect가 라우팅을 담당하므로, InitialScreen은 스플래시 UI만 표시하면 된다. AuthNotifier가 로딩 완료 시 `notifyListeners()`를 호출하면 GoRouter가 자동으로 redirect를 재실행한다.

**Step 1: InitialScreen을 로딩 UI만 표시하도록 교체**

`_checkFirstLaunch`, `_handleTokenExpired`, `_handleGroupIdCheck` 등 라우팅 로직을 모두 제거하고, AuthNotifier 초기화는 main.dart에서 담당한다.
서비스 초기화 (LocationService, FCM 토큰 등)는 MainScreen의 `initState`로 이동할 예정이므로 여기서는 스플래시 UI만 남긴다.

```dart
// lib/screens/screen_splash.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_tokens.dart';

class InitialScreen extends StatefulWidget {
  const InitialScreen({super.key});

  @override
  State<InitialScreen> createState() => _InitialScreenState();
}

class _InitialScreenState extends State<InitialScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        systemNavigationBarColor: AppTokens.primaryTeal,
        systemNavigationBarIconBrightness: Brightness.light,
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    return Scaffold(
      backgroundColor: AppTokens.primaryTeal,
      body: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedBuilder(
            animation: _fadeAnimation,
            builder: (context, child) => Opacity(
              opacity: _fadeAnimation.value,
              child: Image.asset('assets/images/sp.png', fit: BoxFit.cover),
            ),
          ),
          Center(
            child: Image.asset(
              'assets/images/logo-L.png',
              width: 200,
              height: 200,
            ),
          ),
        ],
      ),
    );
  }
}
```

**Step 2: 커밋**

```bash
git add lib/screens/screen_splash.dart
git commit -m "refactor: simplify InitialScreen to splash UI only (routing moved to GoRouter)"
```

---

## Task 8: OnboardingScreen — 최초 설치만 표시, 2장으로 축소

**Files:**
- Modify: `safetrip-mobile/lib/screens/onboarding/screen_1_onboarding.dart`

**Step 1: AuthNotifier 접근을 위해 GoRouter context 활용**

OnboardingScreen 완료 시 `AuthNotifier.completeOnboarding()`을 호출한 뒤 `/onboarding/main`으로 이동.

```dart
// lib/screens/onboarding/screen_1_onboarding.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart'; // go_router는 context extension만 필요

import '../../constants/app_tokens.dart';
import '../../router/auth_notifier.dart';
import '../../router/route_paths.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // 2장으로 축소
  final List<OnboardingPageData> _pages = [
    OnboardingPageData(
      title: '실시간 위치 공유',
      description: '여행 중 소중한 사람의 안전을\n실시간으로 확인하세요.',
      imagePath: 'assets/images/image-onboarding_01.png',
    ),
    OnboardingPageData(
      title: '긴급 SOS & 안전 알림',
      description: '위급 상황에서 즉시 위치를 확인하고\n가디언에게 알림을 보내세요.',
      imagePath: 'assets/images/image-onboarding_05.png',
    ),
  ];

  Future<void> _complete() async {
    // AuthNotifier에 최초 설치 완료 기록
    // GoRouter context extension으로 router 접근
    final router = GoRouter.of(context);
    // AuthNotifier는 GoRouter refreshListenable으로 등록됨
    // main.dart의 _MyAppState에서 생성되어 있으므로 InheritedWidget 없이
    // GoRouterState에서 접근하거나 별도 방법 필요.
    // 가장 단순한 방법: SharedPreferences 직접 저장
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);
    if (mounted) context.go(RoutePaths.onboardingMain);
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _complete();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTokens.bgBasic01,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 20, right: 16),
              child: Align(
                alignment: Alignment.topRight,
                child: TextButton(
                  onPressed: _complete,
                  child: Text(
                    '건너뛰기',
                    style: TextStyle(
                      color: AppTokens.text05,
                      fontSize: 18,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w500,
                      height: 1.40,
                      letterSpacing: -1.50,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemCount: _pages.length,
                itemBuilder: (context, index) =>
                    _buildPage(_pages[index]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _pages.length,
                      (i) => _buildDot(i == _currentPage),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _nextPage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTokens.primaryTeal,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        _currentPage == _pages.length - 1 ? '시작하기' : '다음',
                        style: TextStyle(
                          color: AppTokens.bgBasic01,
                          fontSize: 16,
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(OnboardingPageData data) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: double.infinity,
            height: 300,
            margin: const EdgeInsets.only(bottom: 60),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: AppTokens.bgBasic01,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(data.imagePath, fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Container(
                  color: AppTokens.basic04,
                  child: const Icon(Icons.image, size: 80, color: Color(0xFFBDBDBD)),
                ),
              ),
            ),
          ),
          Text(data.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTokens.text05, fontSize: 28,
              fontFamily: 'Pretendard', fontWeight: FontWeight.w600,
              letterSpacing: -3,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 280,
            child: Text(data.description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFA5A5A5), fontSize: 16,
                fontFamily: 'Poppins', fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(bool isActive) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 3),
      width: isActive ? 14 : 6,
      height: 6,
      decoration: BoxDecoration(
        color: isActive ? AppTokens.primaryTeal : const Color(0xFFDAEFF3),
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

class OnboardingPageData {
  final String title;
  final String description;
  final String imagePath;
  OnboardingPageData({required this.title, required this.description, required this.imagePath});
}
```

> **주의:** `shared_preferences` import 추가 필요: `import 'package:shared_preferences/shared_preferences.dart';`

**Step 2: 커밋**

```bash
git add lib/screens/onboarding/screen_1_onboarding.dart
git commit -m "feat: reduce onboarding carousel to 2 pages, add first-launch completion"
```

---

## Task 9: StartScreen — 3갈래 버튼으로 개선

**Files:**
- Modify: `safetrip-mobile/lib/screens/auth/screen_3_start.dart`

**Step 1: 3갈래 버튼으로 교체**

기존 `_onStartPressed` → `_onLoginPressed` 로직을 GoRouter로 전환.

```dart
// lib/screens/auth/screen_3_start.dart
// 핵심 변경 부분만 표시

// 기존 _onStartPressed, _onInviteCodePressed, _onLoginPressed 교체:
void _navigateTo(OnboardingEntry entry) {
  _videoController?.pause();
  _videoController?.dispose();
  _videoController = null;
  if (!mounted) return;
  context.push(RoutePaths.authPhone, extra: {'entry': entry});
}

// build()의 버튼 영역:
// 1. 새 여행 만들기 (Primary)
PrimaryButton(
  text: '새 여행 만들기',
  onTap: () => _navigateTo(OnboardingEntry.newTrip),
),
const SizedBox(height: 12),
// 2. 초대 코드로 참여하기 (Secondary)
SecondaryButton(
  text: '초대 코드로 참여하기',
  onTap: () => _navigateTo(OnboardingEntry.inviteCode),
),
const SizedBox(height: 12),
// 3. 기존 여행으로 돌아가기 (Outlined)
OutlinedButton(
  onPressed: () => _navigateTo(OnboardingEntry.continueTrip),
  style: OutlinedButton.styleFrom(
    minimumSize: const Size.fromHeight(54),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    side: BorderSide(color: AppTokens.primaryTeal),
  ),
  child: Text('기존 여행으로 돌아가기',
    style: TextStyle(color: AppTokens.primaryTeal, fontSize: 16,
      fontFamily: 'Poppins', fontWeight: FontWeight.w600),
  ),
),
```

필요한 imports 추가:
```dart
import 'package:go_router/go_router.dart';
import '../../models/onboarding/onboarding_entry.dart';
import '../../router/route_paths.dart';
```

**Step 2: 커밋**

```bash
git add lib/screens/auth/screen_3_start.dart
git commit -m "feat: add 3rd button (continue trip) to StartScreen, migrate to GoRouter"
```

---

## Task 10: PhoneScreen — OnboardingEntry 파라미터 추가

**Files:**
- Modify: `safetrip-mobile/lib/screens/auth/screen_6_phone.dart`

**Step 1: 생성자에 entry 파라미터 추가**

```dart
class PhoneScreen extends StatefulWidget {
  final OnboardingEntry entry;    // ← 추가
  const PhoneScreen({super.key, required this.entry});
  ...
}
```

**Step 2: VerifyScreen으로 이동 시 entry 포함**

기존 `Navigator.push(... VerifyScreen(...))` 3곳 모두를 아래로 교체:

```dart
// codeSent 콜백 내부
context.push(RoutePaths.authVerify, extra: {
  'entry': widget.entry,
  'phoneNumber': phoneInput,
  'countryCode': _countryCode,
  'verificationId': verificationId,
  'resendToken': resendToken,
  'autoVerified': false,
  'isTestAuth': false,
});

// autoVerified 콜백 내부
context.push(RoutePaths.authVerify, extra: {
  'entry': widget.entry,
  'phoneNumber': phoneInput,
  'countryCode': _countryCode,
  'autoVerified': true,
  'credential': credential,
  'isTestAuth': false,
});

// isTestPhoneNumber 분기
context.push(RoutePaths.authVerify, extra: {
  'entry': widget.entry,
  'phoneNumber': phoneInput,
  'countryCode': _countryCode,
  'isTestAuth': true,
});
```

필요한 imports:
```dart
import 'package:go_router/go_router.dart';
import '../../models/onboarding/onboarding_entry.dart';
import '../../router/route_paths.dart';
```

**Step 3: 커밋**

```bash
git add lib/screens/auth/screen_6_phone.dart
git commit -m "feat: add OnboardingEntry param to PhoneScreen, migrate navigation to GoRouter"
```

---

## Task 11: VerifyScreen — 기존 회원 판별 + 스마트 분기

**Files:**
- Modify: `safetrip-mobile/lib/screens/auth/screen_7_verify.dart`

**Step 1: 생성자에 entry 파라미터 추가**

```dart
class VerifyScreen extends StatefulWidget {
  final OnboardingEntry entry;    // ← 추가
  final String phoneNumber;
  final String countryCode;
  final String? verificationId;
  final int? resendToken;
  final bool autoVerified;
  final PhoneAuthCredential? credential;
  final bool isTestAuth;

  const VerifyScreen({
    super.key,
    required this.entry,          // ← 추가
    required this.phoneNumber,
    required this.countryCode,
    this.verificationId,
    this.resendToken,
    this.autoVerified = false,
    this.credential,
    this.isTestAuth = false,
  });
}
```

**Step 2: `_syncUserWithFirebase` 완료 후 라우팅 로직 교체**

`_syncUserWithFirebase` 메서드 내 인증 완료 후 기존 `Navigator.push(... ProfileScreen(...))` 부분을 찾아 다음으로 교체:

```dart
// _syncUserWithFirebase 메서드 내, auth_verified_at 저장 이후
final prefs = await SharedPreferences.getInstance();
await prefs.setString('auth_verified_at', DateTime.now().toUtc().toIso8601String());

// 사용자 정보 저장
final userId = userData['user_id'] as String;
final displayName = userData['display_name'] as String? ?? userData['user_name'] as String?;
final isNewUser = userData['is_new_user'] as bool? ?? true;
await prefs.setString('user_id', userId);
if (displayName != null) await prefs.setString('user_name', displayName);

if (!mounted) return;

// 스마트 분기
await _navigateAfterAuth(
  userId: userId,
  displayName: displayName,
  isNewUser: isNewUser,
);
```

**Step 3: `_navigateAfterAuth` 메서드 추가**

```dart
Future<void> _navigateAfterAuth({
  required String userId,
  String? displayName,
  required bool isNewUser,
}) async {
  if (!mounted) return;

  // 신규 회원
  if (isNewUser) {
    if (widget.entry == OnboardingEntry.continueTrip) {
      // 가입 이력 없음 안내
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('가입 이력이 없습니다'),
          content: const Text('새 여행 만들기로 진행해주세요.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                context.go(RoutePaths.onboardingMain);
              },
              child: const Text('확인'),
            ),
          ],
        ),
      );
      return;
    }
    // 약관 → 프로필 → 최종 목적지
    context.push(RoutePaths.authTerms, extra: {
      'entry': widget.entry,
      'phoneNumber': widget.phoneNumber,
      'countryCode': widget.countryCode,
      'userId': userId,
    });
    return;
  }

  // 기존 회원 분기
  final prefs = await SharedPreferences.getInstance();
  final groupId = prefs.getString('group_id') ?? '';
  final hasTrip = groupId.isNotEmpty;

  switch (widget.entry) {
    case OnboardingEntry.newTrip:
      if (hasTrip) {
        context.go(RoutePaths.main);
        // 토스트 표시
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('돌아오셨군요! 👋')),
            );
          }
        });
      } else {
        context.go(RoutePaths.tripCreate);
      }
    case OnboardingEntry.inviteCode:
      // pendingInviteCode 가 있으면 query param으로 전달
      context.go(RoutePaths.tripJoin);
    case OnboardingEntry.continueTrip:
      context.go(RoutePaths.main);
  }
}
```

필요한 imports 추가:
```dart
import 'package:go_router/go_router.dart';
import '../../models/onboarding/onboarding_entry.dart';
import '../../router/route_paths.dart';
```

**Step 4: 커밋**

```bash
git add lib/screens/auth/screen_7_verify.dart
git commit -m "feat: add smart routing after auth verification based on OnboardingEntry"
```

---

## Task 12: TermsScreen — entry 파라미터 + GoRouter 전환

**Files:**
- Modify: `safetrip-mobile/lib/screens/auth/screen_5_terms.dart`

**Step 1: 생성자에 파라미터 추가**

```dart
class TermsScreen extends StatefulWidget {
  final OnboardingEntry entry;
  final String? phoneNumber;
  final String? countryCode;
  final String? userId;

  const TermsScreen({
    super.key,
    required this.entry,
    this.phoneNumber,
    this.countryCode,
    this.userId,
  });
}
```

**Step 2: `_onNextPressed` 내 Navigator.push → context.push 교체**

```dart
void _onNextPressed() {
  if (!_allRequiredAgreed) { /* 기존 SnackBar 유지 */ return; }
  context.push(RoutePaths.authProfile, extra: {
    'entry': widget.entry,
    'phoneNumber': widget.phoneNumber ?? '',
    'countryCode': widget.countryCode ?? '+82',
    'userId': widget.userId ?? '',
    'isNewUser': true,
  });
}
```

**Step 3: 커밋**

```bash
git add lib/screens/auth/screen_5_terms.dart
git commit -m "feat: add entry param to TermsScreen, migrate to GoRouter"
```

---

## Task 13: ProfileScreen — entry 기반 최종 목적지 분기

**Files:**
- Modify: `safetrip-mobile/lib/screens/auth/screen_8_profile.dart`

**Step 1: 생성자에 entry 파라미터 추가**

```dart
class ProfileScreen extends StatefulWidget {
  final OnboardingEntry entry;    // ← 추가
  final String phoneNumber;
  final String countryCode;
  final String userId;
  final bool isNewUser;
  final String? displayName;
  ...
}
```

**Step 2: 프로필 저장 완료 후 라우팅 교체**

기존 `Navigator.push(... ScreenTripSelection(...))` 또는 `ScreenTripConfirm` 부분을 찾아 교체:

```dart
void _onProfileComplete() {
  switch (widget.entry) {
    case OnboardingEntry.newTrip:
      context.go(RoutePaths.tripCreate);
    case OnboardingEntry.inviteCode:
      context.go(RoutePaths.tripJoin);
    case OnboardingEntry.continueTrip:
      // 신규 회원이 continueTrip으로 진입할 수 없지만 방어 처리
      context.go(RoutePaths.main);
  }
}
```

**Step 3: 커밋**

```bash
git add lib/screens/auth/screen_8_profile.dart
git commit -m "feat: add entry-based final routing to ProfileScreen"
```

---

## Task 14: PermissionScreen — 완료 후 /main으로 이동

**Files:**
- Modify: `safetrip-mobile/lib/screens/screen_permission.dart`

**Step 1: `_navigateToNext` 교체**

기존:
```dart
void _navigateToNext() {
  Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const StartScreen()));
}
```

교체:
```dart
void _navigateToNext() {
  context.go(RoutePaths.main);
}
```

필요한 imports:
```dart
import 'package:go_router/go_router.dart';
import '../router/route_paths.dart';
```

**Step 2: 커밋**

```bash
git add lib/screens/screen_permission.dart
git commit -m "feat: migrate PermissionScreen to GoRouter, navigate to /main on complete"
```

---

## Task 15: TripCreate — 완료 후 /permission으로 이동

**Files:**
- Modify: `safetrip-mobile/lib/screens/trip/screen_trip_create.dart`

**Step 1: 여행 생성 완료 후 Navigator → GoRouter 전환**

`ScreenTripCreate`에서 여행 생성 성공 후 `ScreenTripConfirm`이나 `MainScreen`으로 이동하는 부분을 찾아:

```dart
// 여행 생성 성공 후
context.go(RoutePaths.permission);
```

**Step 2: 커밋**

```bash
git add lib/screens/trip/screen_trip_create.dart
git commit -m "feat: navigate to /permission after trip creation"
```

---

## Task 16: TripJoinCode — 완료 후 /permission으로 이동

**Files:**
- Modify: `safetrip-mobile/lib/screens/trip/screen_trip_join_code.dart`

**Step 1: prefilledCode 파라미터 추가 (딥링크 코드 자동 입력)**

```dart
class ScreenTripJoinCode extends StatefulWidget {
  final JoinType joinType;
  final bool fromOnboarding;
  final String? prefilledCode;    // ← 추가

  const ScreenTripJoinCode({
    super.key,
    required this.joinType,
    this.fromOnboarding = false,
    this.prefilledCode,           // ← 추가
  });
}
```

`initState`에서 prefilledCode가 있으면 자동 입력:
```dart
@override
void initState() {
  super.initState();
  if (widget.prefilledCode != null) {
    _codeController.text = widget.prefilledCode!;
    // 자동 코드 검증 호출
    WidgetsBinding.instance.addPostFrameCallback((_) => _validateCode());
  }
}
```

**Step 2: 참여 완료 후 /permission으로 이동**

기존 `Navigator.pushReplacement(... MainScreen())` 부분을 찾아:
```dart
context.go(RoutePaths.permission);
```

**Step 3: 커밋**

```bash
git add lib/screens/trip/screen_trip_join_code.dart
git commit -m "feat: add prefilledCode param, navigate to /permission after join"
```

---

## Task 17: screen_4_role.dart 삭제

**Files:**
- Delete: `safetrip-mobile/lib/screens/auth/screen_4_role.dart`

**Step 1: 참조 검색**

```bash
grep -r "screen_4_role\|RoleScreen\|RoleCard" /mnt/d/Project/15_SafeTrip_New/safetrip-mobile/lib/ --include="*.dart" -l
```

모든 참조 파일에서 해당 import와 사용 코드 제거.

**Step 2: 파일 삭제**

```bash
rm /mnt/d/Project/15_SafeTrip_New/safetrip-mobile/lib/screens/auth/screen_4_role.dart
```

**Step 3: 커밋**

```bash
git add -A
git commit -m "chore: remove screen_4_role.dart (role selection replaced by entry-path routing)"
```

---

## Task 18: 딥링크 설정 — Android

**Files:**
- Modify: `safetrip-mobile/android/app/src/main/AndroidManifest.xml`

**Step 1: MainActivity의 intent-filter에 딥링크 추가**

```xml
<!-- 기존 intent-filter 다음에 추가 -->
<intent-filter android:autoVerify="true">
  <action android:name="android.intent.action.VIEW" />
  <category android:name="android.intent.category.DEFAULT" />
  <category android:name="android.intent.category.BROWSABLE" />
  <!-- 커스텀 URL 스킴 -->
  <data android:scheme="safetrip" />
</intent-filter>
```

**Step 2: GoRouter에 딥링크 스킴 등록**

`app_router.dart`의 GoRouter 생성자에 추가:
```dart
GoRouter(
  initialLocation: RoutePaths.splash,
  refreshListenable: authNotifier,
  redirect: _redirect,
  routes: _routes,
  // 딥링크 지원
  // safetrip://trip/join?code=T-ABCD-1234
)
```

GoRouter는 Android intent-filter와 iOS URL Scheme 설정만으로 자동으로 딥링크를 처리한다. 별도 설정 불필요.

**Step 3: 커밋**

```bash
git add android/app/src/main/AndroidManifest.xml
git commit -m "feat: add Android deep link intent-filter for safetrip:// scheme"
```

---

## Task 19: 딥링크 설정 — iOS

**Files:**
- Modify: `safetrip-mobile/ios/Runner/Info.plist`

**Step 1: URL Scheme 추가**

`Info.plist`에 아래 추가:
```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleTypeRole</key>
    <string>Editor</string>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>safetrip</string>
    </array>
  </dict>
</array>
```

**Step 2: 커밋**

```bash
git add ios/Runner/Info.plist
git commit -m "feat: add iOS URL scheme for safetrip:// deep link"
```

---

## Task 20: 빌드 검증 및 수동 테스트

**Step 1: 컴파일 오류 확인**

```bash
cd /mnt/d/Project/15_SafeTrip_New/safetrip-mobile
flutter analyze 2>&1 | grep -E "error|warning" | head -30
```

Expected: 0 errors. warnings는 무시 가능.

**Step 2: 에뮬레이터에서 수동 테스트 체크리스트**

```
[ ] 최초 설치: 스플래시 → 가치소개(2장) → 온보딩 메인(3갈래)
[ ] 재실행 (onboarding_completed=true, user_id=없음): 스플래시 → 온보딩 메인
[ ] 재실행 (user_id=있음, group_id=있음): 스플래시 → 메인
[ ] 재실행 (user_id=있음, group_id=없음): 스플래시 → 여행 생성
[ ] 새 여행 만들기 → 신규: 약관 → 프로필 → 여행생성 → 권한 → 메인
[ ] 새 여행 만들기 → 기존 (여행 있음): 인증 → 메인 + 토스트
[ ] 새 여행 만들기 → 기존 (여행 없음): 인증 → 여행생성 → 권한 → 메인
[ ] 초대코드로 참여 → 기존: 인증 → 초대코드 → 권한 → 메인
[ ] 기존 여행으로 돌아가기 → 기존: 인증 → 메인
[ ] 기존 여행으로 돌아가기 → 신규: 인증 → 팝업 → 온보딩 메인
[ ] 딥링크: adb shell am start -W -a android.intent.action.VIEW -d "safetrip://trip/join?code=TEST123" com.safetrip
```

**Step 3: 딥링크 수동 테스트 명령**

```bash
adb shell am start -W -a android.intent.action.VIEW \
  -d "safetrip://trip/join?code=T-TEST-1234" \
  com.safetrip
```

Expected: 앱이 열리고 `/onboarding/main` 또는 `/trip/join?code=T-TEST-1234`(인증 시)으로 이동.

**Step 4: 최종 커밋**

```bash
git add -A
git commit -m "feat: complete GoRouter-based onboarding redesign

- Add GoRouter with redirect-based auth state routing
- Add OnboardingEntry enum for entry-path tracking
- 3-way onboarding main (new trip / invite code / continue trip)
- Skip terms/profile for existing users
- Contextual location permission request after trip join/create
- Deep link support via safetrip:// scheme
- Remove role selection screen"
```

---

## 엣지 케이스 참고

| 상황 | 처리 |
|---|---|
| 토큰 유효하지만 서버에서 계정 삭제 | `AuthNotifier._loadState`에서 서버 검증 실패 시 `signOut()` 호출 |
| 인증 도중 앱 종료 후 재시작 | `onboarding_completed=true`, `user_id=없음` → 온보딩 메인 재시작 |
| 딥링크 코드 복원 실패 | `/trip/join`으로 이동하여 수동 입력 유도 |
| 기존 여행으로 돌아가기 → 인증 후 여행 없음 | 메인 화면 진입 후 여행 목록 비어있음 (기존 빈 상태 UI 유지) |
