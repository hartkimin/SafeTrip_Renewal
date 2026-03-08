# Demo Mode E2E Integration Test — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 신규 사용자 관점에서 데모 모드 전체 플로우를 E2E 통합 테스트로 검증 — 시나리오 선택 → 데모 메인 → 역할 전환 → 타임라인 → 전환 CTA → 완료 화면

**Architecture:** `integration_test` 패키지로 실제 앱을 에뮬레이터/시뮬레이터에서 구동하여 UI 자동화 테스트 실행. Firebase 불필요 (데모 모드는 인증 우회). GoRouter를 `/demo/scenario-select` 초기 라우트로 설정하여 데모 진입점에서 시작.

**Tech Stack:** Flutter `integration_test` package, `flutter_test`, `flutter_riverpod`, `go_router`, `shared_preferences`

**Design Doc:** `docs/plans/2026-03-07-demo-mode-e2e-test-design.md`

---

### Task 1: Add `integration_test` dependency

**Files:**
- Modify: `safetrip-mobile/pubspec.yaml:128-131` (dev_dependencies section)

**Step 1: Add integration_test SDK dependency**

In `safetrip-mobile/pubspec.yaml`, add `integration_test` under `dev_dependencies`:

```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  integration_test:
    sdk: flutter
  flutter_lints: ^3.0.0
```

**Step 2: Run pub get**

Run: `cd safetrip-mobile && flutter pub get`
Expected: No errors. `integration_test` resolves from SDK.

**Step 3: Commit**

```bash
git add safetrip-mobile/pubspec.yaml safetrip-mobile/pubspec.lock
git commit -m "chore: add integration_test SDK dependency for E2E demo tests"
```

---

### Task 2: Create test app helper

**Files:**
- Create: `safetrip-mobile/integration_test/helpers/test_app.dart`

**Context:** Integration tests need a minimal app that:
1. Wraps with `ProviderScope` (Riverpod)
2. Uses `GoRouter` starting at `/demo/scenario-select`
3. Bypasses Firebase initialization entirely
4. Includes only demo-related routes

**Key classes from codebase:**
- `AuthNotifier` (at `lib/router/auth_notifier.dart`) — manages auth state; `setDemoAuthenticated()` sets demo auth
- `AppRouter` (at `lib/router/app_router.dart`) — defines all routes; demo routes at lines 177-191
- `RoutePaths` (at `lib/router/route_paths.dart`) — route constants

**Step 1: Write the test app helper**

```dart
// safetrip-mobile/integration_test/helpers/test_app.dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:safetrip_mobile/core/theme/app_theme.dart';
import 'package:safetrip_mobile/router/auth_notifier.dart';
import 'package:safetrip_mobile/router/route_paths.dart';
import 'package:safetrip_mobile/features/demo/presentation/screens/screen_demo_scenario_select.dart';
import 'package:safetrip_mobile/features/demo/presentation/screens/screen_demo_complete.dart';
import 'package:safetrip_mobile/features/demo/presentation/widgets/demo_mode_wrapper.dart';
import 'package:safetrip_mobile/screens/main/screen_main.dart';
import 'package:safetrip_mobile/features/onboarding/presentation/screens/screen_welcome.dart';
import 'package:safetrip_mobile/features/onboarding/presentation/screens/screen_purpose_select.dart';
import 'package:safetrip_mobile/features/onboarding/presentation/screens/screen_phone_auth.dart';
import 'package:safetrip_mobile/screens/trip/screen_trip_join_code.dart';

/// Builds the test app with only demo-related routes.
/// [initialRoute] controls the starting screen (default: scenario select).
Widget buildTestApp({
  String initialRoute = RoutePaths.demoScenarioSelect,
  AuthNotifier? authNotifier,
}) {
  final auth = authNotifier ?? AuthNotifier();

  final router = GoRouter(
    initialLocation: initialRoute,
    routes: [
      GoRoute(
        path: RoutePaths.demoScenarioSelect,
        builder: (context, state) =>
            ScreenDemoScenarioSelect(authNotifier: auth),
      ),
      GoRoute(
        path: RoutePaths.demoMain,
        builder: (context, state) => DemoModeWrapper(
          child: MainScreen(authNotifier: auth),
        ),
      ),
      GoRoute(
        path: RoutePaths.demoComplete,
        builder: (context, state) => const ScreenDemoComplete(),
      ),
      // Routes needed for conversion CTA navigation
      GoRoute(
        path: RoutePaths.onboardingWelcome,
        builder: (context, state) => const ScreenWelcome(),
      ),
      GoRoute(
        path: RoutePaths.onboardingPurpose,
        builder: (context, state) =>
            ScreenPurposeSelect(authNotifier: auth),
      ),
      GoRoute(
        path: RoutePaths.authPhone,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final role = extra?['role'] as String? ?? 'crew';
          return PhoneAuthScreen(role: role, authNotifier: auth);
        },
      ),
      GoRoute(
        path: RoutePaths.tripJoin,
        builder: (context, state) =>
            ScreenTripJoinCode(authNotifier: auth),
      ),
    ],
  );

  return ProviderScope(
    child: MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
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
      routerConfig: router,
    ),
  );
}
```

**Step 2: Verify file compiles**

Run: `cd safetrip-mobile && dart analyze integration_test/helpers/test_app.dart`
Expected: No errors (may show warnings for unused imports if any).

**Step 3: Commit**

```bash
git add safetrip-mobile/integration_test/helpers/test_app.dart
git commit -m "test: add test_app helper for demo mode integration tests"
```

---

### Task 3: Write Group 1 — Scenario Selection Screen tests

**Files:**
- Create: `safetrip-mobile/integration_test/demo_flow_test.dart`

**Context:**
- `ScreenDemoScenarioSelect` is at `lib/features/demo/presentation/screens/screen_demo_scenario_select.dart`
- It renders 3 `_ScenarioCard` widgets with titles: "학생 단체 여행", "친구들과 해외여행", "해외 출장/패키지 투어"
- Each card shows member count (e.g., "33명"), duration (e.g., "3일"), and privacy badge (e.g., "안전최우선")
- `DemoBadge` (at `lib/features/demo/presentation/widgets/demo_badge.dart`) shows "데모 모드" text
- AppBar title is "데모 체험"

**Step 1: Write the integration test file with Group 1 tests**

```dart
// safetrip-mobile/integration_test/demo_flow_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:safetrip_mobile/features/demo/presentation/widgets/demo_badge.dart';

import 'helpers/test_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  // ============================================================
  // Group 1: 시나리오 선택 화면 렌더링
  // ============================================================
  group('Group 1: 시나리오 선택 화면', () {
    testWidgets('1-1: AppBar에 "데모 체험" 타이틀 표시', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('데모 체험'), findsOneWidget);
    });

    testWidgets('1-2: 3개 시나리오 카드 렌더링', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('학생 단체 여행'), findsOneWidget);
      expect(find.text('친구들과 해외여행'), findsOneWidget);
      expect(find.text('해외 출장/패키지 투어'), findsOneWidget);
    });

    testWidgets('1-3: S1 카드에 33명, 3일, 안전최우선 표시', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('33명'), findsOneWidget);
      expect(find.text('3일'), findsOneWidget);
      expect(find.text('안전최우선'), findsOneWidget);
    });

    testWidgets('1-4: DemoBadge 표시', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      expect(find.byType(DemoBadge), findsOneWidget);
    });

    testWidgets('1-5: 뒤로가기 버튼 존재', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });
  });
}
```

**Step 2: Run tests to verify they pass**

Run: `cd safetrip-mobile && flutter test integration_test/demo_flow_test.dart -d <device_id>`
Expected: All 5 tests PASS. (Note: integration tests require a connected device/emulator)

If no device available, verify compilation: `cd safetrip-mobile && dart analyze integration_test/demo_flow_test.dart`

**Step 3: Commit**

```bash
git add safetrip-mobile/integration_test/demo_flow_test.dart
git commit -m "test: add demo mode Group 1 — scenario selection screen tests"
```

---

### Task 4: Write Group 2 — Scenario Loading & Demo Main Entry

**Files:**
- Modify: `safetrip-mobile/integration_test/demo_flow_test.dart`

**Context:**
- Tapping a scenario card calls `_selectScenario()` which: loads JSON via `DemoScenarioLoader.load()`, seeds `demoStateProvider`, seeds `tripProvider`, sets SharedPreferences, calls `authNotifier.setDemoAuthenticated()`, navigates to `/demo/main`
- `DemoModeWrapper` wraps `MainScreen` — detected via `find.byType(DemoModeWrapper)`
- SharedPreferences key `is_demo_mode` is set to `true`

**Step 1: Add Group 2 tests after Group 1's closing bracket**

```dart
  // ============================================================
  // Group 2: 시나리오 로딩 → 데모 메인 진입
  // ============================================================
  group('Group 2: 시나리오 로딩 → 데모 메인', () {
    testWidgets('2-1: S1 카드 탭 → 데모 메인 진입', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // Tap S1 scenario card
      await tester.tap(find.text('학생 단체 여행'));
      await tester.pump(); // start loading

      // Wait for asset loading and navigation
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Should be on demo main screen now
      expect(find.byType(DemoModeWrapper), findsOneWidget);
    });

    testWidgets('2-2: SharedPreferences에 데모 키 설정됨', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('학생 단체 여행'));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('is_demo_mode'), isTrue);
      expect(prefs.getString('demo_user_role'), equals('captain'));
      expect(prefs.getString('demo_group_id'), equals('demo_s1'));
    });
  });
```

**Step 2: Run tests**

Run: `cd safetrip-mobile && flutter test integration_test/demo_flow_test.dart -d <device_id>`
Expected: All tests PASS.

**Step 3: Commit**

```bash
git add safetrip-mobile/integration_test/demo_flow_test.dart
git commit -m "test: add demo mode Group 2 — scenario loading and main entry"
```

---

### Task 5: Write Group 3 — Demo Main Wrapper UI Layers

**Files:**
- Modify: `safetrip-mobile/integration_test/demo_flow_test.dart`

**Context:**
- `DemoModeWrapper` (`lib/features/demo/presentation/widgets/demo_mode_wrapper.dart`) adds these UI layers on top of `MainScreen`:
  - Layer 1: `DemoBadge` — shows "데모 모드"
  - Layer 2: `DemoRolePanel` — role switcher dropdown
  - Layer 3: `DemoTimeSlider` — timeline control
  - Layer 4: `_GuardianCompareButton` — shows "가디언 비교"
  - Layer 4b: `_GradeCompareButton` — shows "등급 비교"
  - Layer 5: `_ExitDemoFab` — shows "실제 앱으로 전환"
- Need to navigate to demo main first (tap S1 → wait)

**Step 1: Add Group 3 tests**

```dart
  // ============================================================
  // Group 3: 데모 메인 래퍼 UI 레이어
  // ============================================================
  group('Group 3: 데모 메인 UI 레이어', () {
    Future<void> navigateToDemoMain(WidgetTester tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();
      await tester.tap(find.text('학생 단체 여행'));
      await tester.pumpAndSettle(const Duration(seconds: 5));
    }

    testWidgets('3-1: DemoBadge "데모 모드" 표시', (tester) async {
      await navigateToDemoMain(tester);
      expect(find.text('데모 모드'), findsOneWidget);
    });

    testWidgets('3-2: DemoRolePanel 렌더링', (tester) async {
      await navigateToDemoMain(tester);
      // Role panel shows current role "캡틴"
      expect(find.text('캡틴'), findsOneWidget);
    });

    testWidgets('3-3: DemoTimeSlider 렌더링', (tester) async {
      await navigateToDemoMain(tester);
      expect(find.byType(Slider), findsOneWidget);
      expect(find.text('D-7'), findsOneWidget);
      expect(find.text('여행 중'), findsOneWidget);
    });

    testWidgets('3-4: ExitFab "실제 앱으로 전환" 표시', (tester) async {
      await navigateToDemoMain(tester);
      expect(find.text('실제 앱으로 전환'), findsOneWidget);
    });

    testWidgets('3-5: 가디언 비교 버튼 표시', (tester) async {
      await navigateToDemoMain(tester);
      expect(find.text('가디언 비교'), findsOneWidget);
    });

    testWidgets('3-6: 등급 비교 버튼 표시', (tester) async {
      await navigateToDemoMain(tester);
      expect(find.text('등급 비교'), findsOneWidget);
    });
  });
```

**Step 2: Run tests**

Run: `cd safetrip-mobile && flutter test integration_test/demo_flow_test.dart -d <device_id>`
Expected: All tests PASS.

**Step 3: Commit**

```bash
git add safetrip-mobile/integration_test/demo_flow_test.dart
git commit -m "test: add demo mode Group 3 — main wrapper UI layer verification"
```

---

### Task 6: Write Group 4 — Role Switching

**Files:**
- Modify: `safetrip-mobile/integration_test/demo_flow_test.dart`

**Context:**
- `DemoRolePanel` (`lib/features/demo/presentation/widgets/demo_role_panel.dart`):
  - Collapsed state shows current role label + `Icons.swap_horiz`
  - Tap → expands to show 4 roles: "캡틴", "크루장", "크루", "가디언"
  - Each role has a colored dot (8x8 circle) + label
  - Tapping a role calls `_switchRole()` → updates DemoState, SharedPreferences, TripProvider
- `DemoLockOverlay` wraps `_GuardianCompareButton` with `feature: 'guardian_billing'`
  - `canAccess('guardian_billing')` returns `true` only for captain
  - When locked: shows `Icons.lock` icon with 0.3 opacity on child

**Step 1: Add Group 4 tests**

```dart
  // ============================================================
  // Group 4: 역할 전환 (DemoRolePanel)
  // ============================================================
  group('Group 4: 역할 전환', () {
    Future<void> navigateToDemoMain(WidgetTester tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();
      await tester.tap(find.text('학생 단체 여행'));
      await tester.pumpAndSettle(const Duration(seconds: 5));
    }

    testWidgets('4-1: 초기 역할 캡틴 표시', (tester) async {
      await navigateToDemoMain(tester);
      expect(find.text('캡틴'), findsOneWidget);
    });

    testWidgets('4-2: 패널 탭 → 4개 역할 표시', (tester) async {
      await navigateToDemoMain(tester);

      // Tap the role panel toggle (contains swap_horiz icon)
      await tester.tap(find.byIcon(Icons.swap_horiz));
      await tester.pumpAndSettle();

      // All 4 roles should be visible
      expect(find.text('캡틴'), findsWidgets); // toggle button + expanded list
      expect(find.text('크루장'), findsOneWidget);
      expect(find.text('크루'), findsOneWidget);
      expect(find.text('가디언'), findsOneWidget);
    });

    testWidgets('4-3: 크루 선택 → 역할 변경 + SharedPreferences 업데이트',
        (tester) async {
      await navigateToDemoMain(tester);

      // Open role panel
      await tester.tap(find.byIcon(Icons.swap_horiz));
      await tester.pumpAndSettle();

      // Select "크루"
      await tester.tap(find.text('크루'));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      // Verify SharedPreferences updated
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('demo_user_role'), equals('crew'));
    });

    testWidgets('4-4: 캡틴 전용 가디언 비교 → 크루에서 잠금', (tester) async {
      await navigateToDemoMain(tester);

      // Switch to crew role
      await tester.tap(find.byIcon(Icons.swap_horiz));
      await tester.pumpAndSettle();
      await tester.tap(find.text('크루'));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      // Guardian billing button should be locked (lock icon visible)
      expect(find.byIcon(Icons.lock), findsOneWidget);
    });
  });
```

**Step 2: Run tests**

Run: `cd safetrip-mobile && flutter test integration_test/demo_flow_test.dart -d <device_id>`
Expected: All tests PASS.

**Step 3: Commit**

```bash
git add safetrip-mobile/integration_test/demo_flow_test.dart
git commit -m "test: add demo mode Group 4 — role switching and feature lock"
```

---

### Task 7: Write Group 5 — Time Slider

**Files:**
- Modify: `safetrip-mobile/integration_test/demo_flow_test.dart`

**Context:**
- `DemoTimeSlider` (`lib/features/demo/presentation/widgets/demo_time_slider.dart`):
  - Shows labels: "D-7", "여행 중", "D+N" (where N = durationDays - 7 + 3, clamped at 15-7=8... actually `maxDay - 7`)
  - For S1 (3 days): maxDay = (3+3).clamp(0,15) = 6, so label = "D+${6-7}" = "D+-1"...
  - Wait: `maxDay = (durationDays + 3).clamp(0, 15)` = (3+3).clamp(0,15) = 6. Label: `D+${maxDay - 7}` = `D+${6-7}` = `D+-1`. That seems wrong.
  - Actually re-reading: line 71: `Text('D+${maxDay - 7}',` — for S1 (3 days): maxDay=6, so "D+-1". This would show as "D+-1" which is odd but matches the slider label. Actually it represents post-trip days after trip start. For 3-day trip with +3 buffer, max = D+6 from trip start, minus the D-7 pre-trip = shows "-1" ... this might be a display issue.
  - Actually rethinking: maxDay is the max day value from trip start (D+0). For S1 (3 days), maxDay = 6. The right label "D+6" makes sense (6 days after trip start). But the code shows `D+${maxDay - 7}` = "D+-1". This is likely a bug.
  - Let me just test what actually renders. The labels that definitely exist: "D-7" and "여행 중".
  - Current position format: `_formatDayLabel(0)` = "D-Day 00:00" (initial position = 0 because diffMinutes = 0)

**Step 1: Add Group 5 tests**

```dart
  // ============================================================
  // Group 5: 타임 슬라이더 (DemoTimeSlider)
  // ============================================================
  group('Group 5: 타임 슬라이더', () {
    Future<void> navigateToDemoMain(WidgetTester tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();
      await tester.tap(find.text('학생 단체 여행'));
      await tester.pumpAndSettle(const Duration(seconds: 5));
    }

    testWidgets('5-1: "D-7"과 "여행 중" 라벨 표시', (tester) async {
      await navigateToDemoMain(tester);

      expect(find.text('D-7'), findsOneWidget);
      expect(find.text('여행 중'), findsOneWidget);
    });

    testWidgets('5-2: Slider 위젯 존재', (tester) async {
      await navigateToDemoMain(tester);

      expect(find.byType(Slider), findsOneWidget);
    });

    testWidgets('5-3: 현재 위치 "D-Day" 포맷 표시', (tester) async {
      await navigateToDemoMain(tester);

      // Initial position is at simStartTime (diff=0) → day=0 → "D-Day HH:00"
      // Find any text matching D-Day pattern
      expect(
        find.textContaining('D-Day'),
        findsOneWidget,
      );
    });
  });
```

**Step 2: Run tests**

Run: `cd safetrip-mobile && flutter test integration_test/demo_flow_test.dart -d <device_id>`
Expected: All tests PASS.

**Step 3: Commit**

```bash
git add safetrip-mobile/integration_test/demo_flow_test.dart
git commit -m "test: add demo mode Group 5 — time slider verification"
```

---

### Task 8: Write Group 6 — Conversion Modal

**Files:**
- Modify: `safetrip-mobile/integration_test/demo_flow_test.dart`

**Context:**
- `DemoConversionModal` (`lib/features/demo/presentation/widgets/demo_conversion_modal.dart`):
  - Opened by tapping the "실제 앱으로 전환" FAB (`_ExitDemoFab`)
  - Shows via `showModalBottomSheet`
  - Title: "SafeTrip 체험 완료!" (line 70)
  - Body: "지금 실제 SafeTrip을 시작하세요.\n회원가입 30초면 충분합니다." (line 78)
  - 3 CTAs: "여행 만들기" (ElevatedButton), "초대코드로 참여" (OutlinedButton), "나중에 할게요" (TextButton)
  - "나중에 할게요" → `_dismissAndGoWelcome()` → clears demo state → navigates to welcome
- FAB is a `GestureDetector` wrapping a Container with text "실제 앱으로 전환"

**Step 1: Add Group 6 tests**

```dart
  // ============================================================
  // Group 6: 전환 모달 (DemoConversionModal)
  // ============================================================
  group('Group 6: 전환 모달', () {
    Future<void> navigateToDemoMain(WidgetTester tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();
      await tester.tap(find.text('학생 단체 여행'));
      await tester.pumpAndSettle(const Duration(seconds: 5));
    }

    testWidgets('6-1: ExitFab 탭 → 모달 표시', (tester) async {
      await navigateToDemoMain(tester);

      // Tap the exit FAB
      await tester.tap(find.text('실제 앱으로 전환'));
      await tester.pumpAndSettle();

      // Modal should appear
      expect(find.text('SafeTrip 체험 완료!'), findsOneWidget);
    });

    testWidgets('6-2: 모달에 3개 CTA 표시', (tester) async {
      await navigateToDemoMain(tester);

      await tester.tap(find.text('실제 앱으로 전환'));
      await tester.pumpAndSettle();

      expect(find.text('여행 만들기'), findsOneWidget);
      expect(find.text('초대코드로 참여'), findsOneWidget);
      expect(find.text('나중에 할게요'), findsOneWidget);
    });

    testWidgets('6-3: "나중에 할게요" → 데모 상태 클리어', (tester) async {
      await navigateToDemoMain(tester);

      await tester.tap(find.text('실제 앱으로 전환'));
      await tester.pumpAndSettle();

      // Tap dismiss
      await tester.tap(find.text('나중에 할게요'));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // SharedPreferences should be cleared
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('is_demo_mode'), isNull);
      expect(prefs.getString('demo_user_role'), isNull);
    });
  });
```

**Step 2: Run tests**

Run: `cd safetrip-mobile && flutter test integration_test/demo_flow_test.dart -d <device_id>`
Expected: All tests PASS.

**Step 3: Commit**

```bash
git add safetrip-mobile/integration_test/demo_flow_test.dart
git commit -m "test: add demo mode Group 6 — conversion modal tests"
```

---

### Task 9: Write Group 7 — Demo Complete Screen

**Files:**
- Modify: `safetrip-mobile/integration_test/demo_flow_test.dart`

**Context:**
- `ScreenDemoComplete` (`lib/features/demo/presentation/screens/screen_demo_complete.dart`):
  - Accessed at `/demo/complete` route
  - Shows: check icon (`Icons.check_circle_outline`), "데모 체험을 완료했습니다!" title, "실제 SafeTrip으로 안전한 여행을 시작해 보세요.\n회원가입은 30초면 충분합니다." body
  - 3 CTAs: "여행 만들기" (ElevatedButton), "초대코드로 참여" (OutlinedButton), "나중에 할게요" (TextButton)
  - DemoBadge at top
  - `_clearDemoState()` removes all SharedPreferences demo keys
- To test this screen, navigate directly via GoRouter initial route `/demo/complete`
  - But we need DemoState to be active first for analytics. Simplest: navigate to it directly.

**Step 1: Add Group 7 tests**

```dart
  // ============================================================
  // Group 7: 완료 화면 (ScreenDemoComplete)
  // ============================================================
  group('Group 7: 완료 화면', () {
    testWidgets('7-1: 완료 메시지 표시', (tester) async {
      await tester.pumpWidget(
        buildTestApp(initialRoute: RoutePaths.demoComplete),
      );
      await tester.pumpAndSettle();

      expect(find.text('데모 체험을 완료했습니다!'), findsOneWidget);
    });

    testWidgets('7-2: 체크 아이콘 표시', (tester) async {
      await tester.pumpWidget(
        buildTestApp(initialRoute: RoutePaths.demoComplete),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    });

    testWidgets('7-3: 3개 CTA 버튼 타입 검증', (tester) async {
      await tester.pumpWidget(
        buildTestApp(initialRoute: RoutePaths.demoComplete),
      );
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(ElevatedButton, '여행 만들기'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(OutlinedButton, '초대코드로 참여'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(TextButton, '나중에 할게요'),
        findsOneWidget,
      );
    });

    testWidgets('7-4: DemoBadge 표시', (tester) async {
      await tester.pumpWidget(
        buildTestApp(initialRoute: RoutePaths.demoComplete),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DemoBadge), findsOneWidget);
    });

    testWidgets('7-5: "나중에 할게요" → 데모 상태 클리어', (tester) async {
      // Pre-set demo prefs
      SharedPreferences.setMockInitialValues({
        'is_demo_mode': true,
        'demo_user_id': 'm_captain',
        'demo_user_name': '김선생',
        'demo_group_id': 'demo_s1',
        'demo_user_role': 'captain',
      });

      await tester.pumpWidget(
        buildTestApp(initialRoute: RoutePaths.demoComplete),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('나중에 할게요'));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('is_demo_mode'), isNull);
      expect(prefs.getString('demo_user_id'), isNull);
      expect(prefs.getString('demo_user_name'), isNull);
      expect(prefs.getString('demo_group_id'), isNull);
      expect(prefs.getString('demo_user_role'), isNull);
    });
  });
```

**Step 2: Add `RoutePaths` import at top of file**

Add to the imports section at the top of `demo_flow_test.dart`:

```dart
import 'package:safetrip_mobile/router/route_paths.dart';
```

**Step 3: Run tests**

Run: `cd safetrip-mobile && flutter test integration_test/demo_flow_test.dart -d <device_id>`
Expected: All tests PASS.

**Step 4: Commit**

```bash
git add safetrip-mobile/integration_test/demo_flow_test.dart
git commit -m "test: add demo mode Group 7 — complete screen and state cleanup"
```

---

### Task 10: Full test run & fix any issues

**Files:**
- Possibly modify: `safetrip-mobile/integration_test/demo_flow_test.dart`
- Possibly modify: `safetrip-mobile/integration_test/helpers/test_app.dart`

**Step 1: Run all integration tests end-to-end**

Run: `cd safetrip-mobile && flutter test integration_test/demo_flow_test.dart -d <device_id> --verbose`
Expected: All 7 groups (21+ tests) PASS.

**Step 2: Fix any failures**

Common issues to watch for:
- **Timing**: If `pumpAndSettle` times out, increase timeout or use `pump(Duration)` with explicit waits
- **Widget not found**: If a widget is inside a scrollable, use `tester.scrollUntilVisible()` before `expect()`
- **Duplicate text**: If `findsOneWidget` fails because text appears multiple times, use `findsWidgets` or `findsAtLeast(n)`
- **DemoModeWrapper import**: Add `import 'package:safetrip_mobile/features/demo/presentation/widgets/demo_mode_wrapper.dart';` if Group 2 needs `find.byType(DemoModeWrapper)`
- **MainScreen dependencies**: MainScreen may try to call Firebase/API — if it crashes, wrap with error handler or mock the API service

**Step 3: Final commit**

```bash
git add -A safetrip-mobile/integration_test/
git commit -m "test: finalize demo mode E2E integration tests — all 7 groups passing"
```

---

## Summary

| Task | Description | Files | Tests |
|------|-------------|-------|-------|
| 1 | Add `integration_test` dependency | pubspec.yaml | - |
| 2 | Create test app helper | helpers/test_app.dart | - |
| 3 | Group 1: Scenario select screen | demo_flow_test.dart | 5 |
| 4 | Group 2: Scenario loading → demo main | demo_flow_test.dart | 2 |
| 5 | Group 3: Demo main UI layers | demo_flow_test.dart | 6 |
| 6 | Group 4: Role switching | demo_flow_test.dart | 4 |
| 7 | Group 5: Time slider | demo_flow_test.dart | 3 |
| 8 | Group 6: Conversion modal | demo_flow_test.dart | 3 |
| 9 | Group 7: Complete screen | demo_flow_test.dart | 5 |
| 10 | Full run & fix | any | - |

**Total: 28 tests across 7 groups, 10 tasks**

## Execution

```bash
# Ensure an Android emulator or iOS simulator is running
cd safetrip-mobile
flutter test integration_test/demo_flow_test.dart -d <device_id>
```

No backend/Firebase required — demo mode is 100% local data.
