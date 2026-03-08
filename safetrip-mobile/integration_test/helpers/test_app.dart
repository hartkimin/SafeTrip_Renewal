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
