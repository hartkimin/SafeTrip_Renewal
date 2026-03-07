import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'core/theme/app_theme.dart';
import 'features/onboarding/data/deeplink_service.dart';
import 'router/app_router.dart';
import 'router/auth_notifier.dart';
import 'widgets/offline_banner.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase 초기화
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
  }

  // 환경 변수 로드
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('.env load failed: $e');
  }

  // Firebase Emulator 연결 (개발 환경)
  final useEmulator = dotenv.env['USE_FIREBASE_EMULATOR']?.toLowerCase() == 'true';
  if (useEmulator) {
    final ngrokUrl = dotenv.env['FIREBASE_AUTH_EMULATOR_URL'] ?? '';

    if (ngrokUrl.isNotEmpty) {
      // ngrok 모드: 단일 프록시 URL (local-proxy.cjs가 경로 기반 라우팅)
      final uri = Uri.parse(ngrokUrl);
      final host = uri.host;
      final port = uri.port != 0 ? uri.port : 80;

      await FirebaseAuth.instance.useAuthEmulator(host, port);
      FirebaseDatabase.instance.useDatabaseEmulator(host, port);
      await FirebaseStorage.instance.useStorageEmulator(host, port);
      debugPrint('[Firebase] Emulator connected via ngrok: $host:$port');
    } else {
      // 로컬 WiFi/에뮬레이터 모드: 개별 포트
      final emulatorHost = dotenv.env['FIREBASE_EMULATOR_HOST'] ?? '10.0.2.2';

      await FirebaseAuth.instance.useAuthEmulator(emulatorHost, 9099);
      FirebaseDatabase.instance.useDatabaseEmulator(emulatorHost, 9000);
      await FirebaseStorage.instance.useStorageEmulator(emulatorHost, 9199);
      debugPrint('[Firebase] Emulator connected: $emulatorHost (local)');
    }
  }

  // Initialize deep link service
  await DeeplinkService.instance.init();

  debugPrint('[main] About to runApp...');
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
  debugPrint('[main] runApp called');
}

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
    debugPrint('[MyApp] initState start');
    _authNotifier = AuthNotifier();
    _appRouter = AppRouter(_authNotifier);

    // Forward deep link params to AuthNotifier (cold start + warm start)
    final deeplink = DeeplinkService.instance;
    if (deeplink.pendingInviteCode != null) {
      _authNotifier.setPendingInviteCode(deeplink.pendingInviteCode!);
    } else if (deeplink.inviteDeeplinkReceived) {
      // §6.1: invite URI received but code parse failed → mark for Phase 3 + toast
      _authNotifier.setInviteDeeplinkFailed();
    }
    if (deeplink.pendingGuardianCode != null) {
      _authNotifier.setPendingGuardianCode(deeplink.pendingGuardianCode!);
    }
    // Listen for warm-start deep links
    deeplink.onDeepLink = (type, value) {
      if (type == 'invite') {
        _authNotifier.setPendingInviteCode(value);
      } else if (type == 'guardian') {
        _authNotifier.setPendingGuardianCode(value);
      }
    };

    debugPrint('[MyApp] initState done');
  }

  @override
  void dispose() {
    _authNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('[MyApp] build called');
    return MaterialApp.router(
      title: 'SafeTrip',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
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
      routerConfig: _appRouter.router,
      builder: (context, child) {
        // Global offline banner (DOC-T3-SPL-028 §13.2)
        return ListenableBuilder(
          listenable: _authNotifier,
          builder: (context, _) {
            return Column(
              children: [
                if (_authNotifier.isOffline && _authNotifier.initCompleted)
                  const OfflineBanner(),
                Expanded(child: child ?? const SizedBox.shrink()),
              ],
            );
          },
        );
      },
    );
  }
}
