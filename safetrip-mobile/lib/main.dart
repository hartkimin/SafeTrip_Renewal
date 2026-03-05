import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'core/theme/app_theme.dart';
import 'router/app_router.dart';
import 'router/auth_notifier.dart';

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

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
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
    );
  }
}
