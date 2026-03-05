import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'auth_notifier.dart';
import 'route_paths.dart';

import '../screens/screen_splash.dart';
import '../screens/onboarding/screen_intro.dart';
import '../screens/onboarding/screen_role_select.dart';
import '../screens/auth/screen_terms_consent.dart';
import '../screens/auth/screen_phone_auth.dart';
import '../screens/auth/screen_profile_setup.dart';
import '../screens/main/screen_main.dart';
import '../screens/main/screen_notification_list.dart';
import '../screens/settings/screen_settings_main.dart';
import '../screens/trip/screen_no_trip_home.dart';
import '../screens/trip/screen_trip_create.dart';
import '../screens/trip/screen_trip_join_code.dart';
import '../screens/trip/screen_trip_demo.dart';
import '../screens/trip/screen_trip_privacy.dart';
import '../screens/trip/screen_guardian_management.dart';
import '../screens/ai/screen_ai_briefing.dart';

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
        path: RoutePaths.onboardingIntro,
        builder: (context, state) => const ScreenIntro(),
      ),
      GoRoute(
        path: RoutePaths.roleSelect,
        builder: (context, state) => const RoleSelectScreen(),
      ),
      GoRoute(
        path: RoutePaths.termsConsent,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final role = extra?['role'] as String? ?? 'crew';
          return ScreenTermsConsent(selectedRole: role);
        },
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
        path: RoutePaths.profileSetup,
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
    ],
  );

  String? _redirect(BuildContext context, GoRouterState state) {
    final path = state.uri.path;
    final isLoading = authNotifier.isLoading;
    final isAuth = authNotifier.isAuthenticated;

    if (isLoading) return path == RoutePaths.splash ? null : RoutePaths.splash;

    if (path == RoutePaths.splash) {
      if (!isAuth) {
        if (authNotifier.pendingInviteCode != null) {
          return RoutePaths.tripJoin;
        }
        return authNotifier.isFirstLaunch
            ? RoutePaths.onboardingIntro
            : RoutePaths.roleSelect;
      }
      return authNotifier.hasActiveTrip ? RoutePaths.main : RoutePaths.noTripHome;
    }

    final authPaths = [
      RoutePaths.onboardingIntro,
      RoutePaths.roleSelect,
      RoutePaths.termsConsent,
      RoutePaths.authPhone,
    ];
    
    if (isAuth && authPaths.contains(path)) {
      return authNotifier.hasActiveTrip ? RoutePaths.main : RoutePaths.noTripHome;
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
