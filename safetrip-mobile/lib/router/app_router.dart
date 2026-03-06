import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'auth_notifier.dart';
import 'route_paths.dart';

import '../screens/screen_splash.dart';
import '../features/onboarding/presentation/screens/screen_welcome.dart';
import '../features/onboarding/presentation/screens/screen_purpose_select.dart';
import '../features/onboarding/presentation/screens/screen_terms_consent.dart';
import '../features/onboarding/presentation/screens/screen_birth_date.dart';
import '../features/onboarding/presentation/screens/screen_phone_auth.dart';
import '../features/onboarding/presentation/screens/screen_profile_setup.dart';
import '../screens/main/screen_main.dart';
import '../screens/main/screen_notification_list.dart';
import '../screens/settings/screen_settings_main.dart';
import '../screens/trip/screen_no_trip_home.dart';
import '../screens/trip/screen_trip_create.dart';
import '../screens/trip/screen_trip_join_code.dart';
import '../screens/trip/screen_trip_demo.dart';
import '../screens/trip/screen_trip_privacy.dart';
import '../features/demo/presentation/screens/screen_demo_scenario_select.dart';
import '../features/demo/presentation/screens/screen_demo_complete.dart';
import '../features/demo/presentation/widgets/demo_mode_wrapper.dart';
import '../screens/trip/screen_guardian_management.dart';
import '../screens/ai/screen_ai_briefing.dart';
import '../screens/main/screen_main_guardian.dart';
import '../features/onboarding/presentation/screens/screen_invite_confirm.dart';
import '../features/onboarding/presentation/screens/screen_guardian_confirm.dart';

class AppRouter {
  AppRouter(this.authNotifier);
  final AuthNotifier authNotifier;

  late final GoRouter router = GoRouter(
    initialLocation: RoutePaths.splash,
    refreshListenable: authNotifier,
    redirect: _redirect,
    routes: [
      GoRoute(
        path: RoutePaths.splash,
        builder: (context, state) => const InitialScreen(),
      ),
      GoRoute(
        path: RoutePaths.onboardingWelcome,
        builder: (context, state) => const ScreenWelcome(),
      ),
      GoRoute(
        path: RoutePaths.onboardingPurpose,
        builder: (context, state) => const ScreenPurposeSelect(),
      ),
      GoRoute(
        path: RoutePaths.authPhone,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final role = extra?['role'] as String? ?? 'crew';
          return PhoneAuthScreen(role: role, authNotifier: authNotifier);
        },
      ),
      GoRoute(
        path: RoutePaths.authTerms,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final role = extra?['role'] as String? ?? 'crew';
          return ScreenTermsConsent(selectedRole: role);
        },
      ),
      GoRoute(
        path: RoutePaths.authBirthDate,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return ScreenBirthDate(role: extra['role'] as String? ?? 'crew');
        },
      ),
      GoRoute(
        path: RoutePaths.authProfile,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final userId = extra?['userId'] as String? ?? '';
          final role = extra?['role'] as String? ?? 'crew';
          return ScreenProfileSetup(
            userId: userId,
            role: role,
            authNotifier: authNotifier,
          );
        },
      ),
      GoRoute(
        path: RoutePaths.onboardingInviteConfirm,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return ScreenInviteConfirm(
            inviteCode: extra['inviteCode'] as String? ?? '',
          );
        },
      ),
      GoRoute(
        path: RoutePaths.onboardingGuardianConfirm,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return ScreenGuardianConfirm(
            guardianCode: extra['guardianCode'] as String? ?? '',
          );
        },
      ),
      GoRoute(
        path: RoutePaths.main,
        builder: (context, state) => MainScreen(authNotifier: authNotifier),
      ),
      GoRoute(
        path: RoutePaths.notificationList,
        builder: (context, state) => const NotificationListScreen(),
      ),
      GoRoute(
        path: RoutePaths.settingsMain,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: RoutePaths.privacySettings,
        builder: (context, state) => const ScreenTripPrivacy(),
      ),
      GoRoute(
        path: RoutePaths.guardianManagement,
        builder: (context, state) => const ScreenGuardianManagement(),
      ),
      GoRoute(
        path: RoutePaths.noTripHome,
        builder: (context, state) => const ScreenNoTripHome(),
      ),
      GoRoute(
        path: RoutePaths.tripCreate,
        builder: (context, state) => const ScreenTripCreate(),
      ),
      GoRoute(
        path: RoutePaths.tripJoin,
        builder: (context, state) => const ScreenTripJoinCode(),
      ),
      GoRoute(
        path: RoutePaths.tripDemo,
        builder: (context, state) => ScreenTripDemo(authNotifier: authNotifier),
      ),
      GoRoute(
        path: RoutePaths.aiBriefing,
        builder: (context, state) => const ScreenAiBriefing(),
      ),
      // 가디언 전용 메인 화면
      GoRoute(
        path: RoutePaths.mainGuardian,
        builder: (context, state) => const MainGuardianScreen(),
      ),
      // Demo routes
      GoRoute(
        path: RoutePaths.demoScenarioSelect,
        builder: (context, state) =>
            ScreenDemoScenarioSelect(authNotifier: authNotifier),
      ),
      GoRoute(
        path: RoutePaths.demoMain,
        builder: (context, state) => DemoModeWrapper(
          child: MainScreen(authNotifier: authNotifier),
        ),
      ),
      GoRoute(
        path: RoutePaths.demoComplete,
        builder: (context, state) => const ScreenDemoComplete(),
      ),
      // 딥링크 동적 라우트 (화면구성원칙 §9.2)
      GoRoute(
        path: RoutePaths.tripDetail,
        builder: (context, state) {
          // tripId 파라미터로 메인 화면 열기 (향후 확장)
          return MainScreen(authNotifier: authNotifier);
        },
      ),
      GoRoute(
        path: RoutePaths.tripSchedule,
        builder: (context, state) {
          return MainScreen(authNotifier: authNotifier);
        },
      ),
      GoRoute(
        path: RoutePaths.tripMembers,
        builder: (context, state) {
          return MainScreen(authNotifier: authNotifier);
        },
      ),
    ],
  );

  String? _redirect(BuildContext context, GoRouterState state) {
    final path = state.uri.path;
    final isLoading = authNotifier.isLoading;
    final isAuth = authNotifier.isAuthenticated;

    // Demo routes don't need auth
    if (path.startsWith('/demo/')) return null;

    // Still loading → stay on splash
    if (isLoading) return path == RoutePaths.splash ? null : RoutePaths.splash;

    // Splash: decide where to go
    if (path == RoutePaths.splash) {
      if (!isAuth) {
        // Check for deep link scenarios
        if (authNotifier.pendingInviteCode != null) {
          return RoutePaths.authPhone; // B: invite code → auth first
        }
        if (authNotifier.pendingGuardianCode != null) {
          return RoutePaths.authPhone; // C: guardian → auth first
        }
        // A or D: normal flow
        return authNotifier.isFirstLaunch
            ? RoutePaths.onboardingWelcome
            : RoutePaths.onboardingPurpose;
      }
      // Authenticated: go to main
      return authNotifier.hasActiveTrip
          ? RoutePaths.main
          : RoutePaths.noTripHome;
    }

    // Protect auth/onboarding routes from authenticated users
    // who have COMPLETED onboarding (consent + profile done).
    // Users mid-onboarding must stay on the flow.
    final onboardingPaths = [
      RoutePaths.onboardingWelcome,
      RoutePaths.onboardingPurpose,
      RoutePaths.authPhone,
      RoutePaths.authTerms,
      RoutePaths.authBirthDate,
      RoutePaths.authProfile,
    ];
    if (isAuth && onboardingPaths.contains(path)) {
      final onboardingDone =
          authNotifier.consentCompleted && authNotifier.profileCompleted;
      if (onboardingDone) {
        return authNotifier.hasActiveTrip
            ? RoutePaths.main
            : RoutePaths.noTripHome;
      }
      // Still onboarding → let them stay
    }

    return null;
  }
}

class PlaceholderScreen extends StatelessWidget {
  final String title;
  const PlaceholderScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(child: Text(title)),
    );
  }
}
