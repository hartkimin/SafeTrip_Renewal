# Splash Screen Implementation Plan (DOC-T3-SPL-028)

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement the splash screen per DOC-T3-SPL-028 with 3-phase loading UI, 5 parallel background initialization tasks, 3-route branching logic, force update dialog, and offline banner.

**Architecture:** Retrofit existing `InitialScreen` + `AuthNotifier` + GoRouter redirect pattern. Add a `SplashInitializer` service that orchestrates 5 parallel background tasks with timer management (min 1s, max 3s). The splash screen owns the UI state machine (3 phases), and delegates branching decisions to `AuthNotifier` which drives GoRouter redirects. Backend adds a `GET /api/v1/version/check` endpoint.

**Tech Stack:** Flutter 3.x, Riverpod, GoRouter, Firebase Auth, Dio, NestJS (backend), package_info_plus, connectivity_plus

---

## Task 1: Backend — Version Check Endpoint

**Files:**
- Create: `safetrip-server-api/src/modules/version/version.controller.ts`
- Create: `safetrip-server-api/src/modules/version/version.service.ts`
- Create: `safetrip-server-api/src/modules/version/version.module.ts`
- Modify: `safetrip-server-api/src/app.module.ts` (add import)

**Step 1: Create version service**

```typescript
// safetrip-server-api/src/modules/version/version.service.ts
import { Injectable } from '@nestjs/common';

interface VersionCheckResult {
    min_version: string;
    recommended_version: string;
    update_type: 'none' | 'optional' | 'critical';
    store_url: string;
}

@Injectable()
export class VersionService {
    // Environment-driven or hardcoded (Phase 1)
    private readonly minVersion = process.env.APP_MIN_VERSION || '1.0.0';
    private readonly recommendedVersion = process.env.APP_RECOMMENDED_VERSION || '1.1.0';

    private readonly storeUrls: Record<string, string> = {
        android: 'https://play.google.com/store/apps/details?id=com.urock.safe.trip',
        ios: 'https://apps.apple.com/app/safetrip/id000000000',
    };

    check(platform: string, currentVersion: string): VersionCheckResult {
        const storeUrl = this.storeUrls[platform] || this.storeUrls['android'];

        if (this.compareVersions(currentVersion, this.minVersion) < 0) {
            return {
                min_version: this.minVersion,
                recommended_version: this.recommendedVersion,
                update_type: 'critical',
                store_url: storeUrl,
            };
        }

        if (this.compareVersions(currentVersion, this.recommendedVersion) < 0) {
            return {
                min_version: this.minVersion,
                recommended_version: this.recommendedVersion,
                update_type: 'optional',
                store_url: storeUrl,
            };
        }

        return {
            min_version: this.minVersion,
            recommended_version: this.recommendedVersion,
            update_type: 'none',
            store_url: storeUrl,
        };
    }

    /** Returns negative if a < b, 0 if equal, positive if a > b */
    private compareVersions(a: string, b: string): number {
        const pa = a.split('.').map(Number);
        const pb = b.split('.').map(Number);
        const len = Math.max(pa.length, pb.length);
        for (let i = 0; i < len; i++) {
            const na = pa[i] || 0;
            const nb = pb[i] || 0;
            if (na !== nb) return na - nb;
        }
        return 0;
    }
}
```

**Step 2: Create version controller**

```typescript
// safetrip-server-api/src/modules/version/version.controller.ts
import { Controller, Get, Query } from '@nestjs/common';
import { Public } from '../../common/decorators/public.decorator';
import { ApiTags, ApiOperation, ApiQuery } from '@nestjs/swagger';
import { VersionService } from './version.service';

@ApiTags('Version')
@Controller('version')
export class VersionController {
    constructor(private readonly versionService: VersionService) {}

    @Public()
    @Get('check')
    @ApiOperation({ summary: '앱 버전 확인 — 최소/권장 버전 비교' })
    @ApiQuery({ name: 'platform', required: true, enum: ['android', 'ios'] })
    @ApiQuery({ name: 'version', required: true, example: '1.1.0' })
    check(
        @Query('platform') platform: string,
        @Query('version') version: string,
    ) {
        return this.versionService.check(platform || 'android', version || '0.0.0');
    }
}
```

**Step 3: Create version module**

```typescript
// safetrip-server-api/src/modules/version/version.module.ts
import { Module } from '@nestjs/common';
import { VersionController } from './version.controller';
import { VersionService } from './version.service';

@Module({
    controllers: [VersionController],
    providers: [VersionService],
})
export class VersionModule {}
```

**Step 4: Register in app.module.ts**

Add `import { VersionModule } from './modules/version/version.module';` to imports section, and add `VersionModule` to the `imports` array right after `HealthModule`.

**Step 5: Test the endpoint**

Run: `curl http://localhost:3001/api/v1/version/check?platform=android&version=1.1.0`
Expected: `{"min_version":"1.0.0","recommended_version":"1.1.0","update_type":"none","store_url":"https://play.google.com/store/apps/details?id=com.urock.safe.trip"}`

Run: `curl http://localhost:3001/api/v1/version/check?platform=android&version=0.9.0`
Expected: `{"update_type":"critical",...}`

**Step 6: Commit**

```bash
git add safetrip-server-api/src/modules/version/ safetrip-server-api/src/app.module.ts
git commit -m "feat(backend): add GET /api/v1/version/check endpoint (DOC-T3-SPL-028 §7)"
```

---

## Task 2: Flutter — Version Check Service

**Files:**
- Create: `safetrip-mobile/lib/services/version_check_service.dart`

**Step 1: Create the service**

```dart
// safetrip-mobile/lib/services/version_check_service.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

enum UpdateType { none, optional, critical }

class VersionCheckResult {
  final UpdateType updateType;
  final String minVersion;
  final String recommendedVersion;
  final String storeUrl;

  const VersionCheckResult({
    required this.updateType,
    required this.minVersion,
    required this.recommendedVersion,
    required this.storeUrl,
  });

  static const VersionCheckResult none = VersionCheckResult(
    updateType: UpdateType.none,
    minVersion: '0.0.0',
    recommendedVersion: '0.0.0',
    storeUrl: '',
  );
}

class VersionCheckService {
  final ApiService _apiService;

  VersionCheckService({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  Future<VersionCheckResult> check() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final platform = Platform.isIOS ? 'ios' : 'android';
      final version = packageInfo.version;

      final response = await _apiService.dio.get(
        '/api/v1/version/check',
        queryParameters: {'platform': platform, 'version': version},
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final result = VersionCheckResult(
          updateType: _parseUpdateType(data['update_type'] as String?),
          minVersion: data['min_version'] as String? ?? '0.0.0',
          recommendedVersion: data['recommended_version'] as String? ?? '0.0.0',
          storeUrl: data['store_url'] as String? ?? '',
        );

        // Cache successful result
        await _cacheResult(result);
        return result;
      }
    } catch (e) {
      debugPrint('[VersionCheckService] check failed: $e');
    }

    // Fallback to cached result
    return _loadCachedResult();
  }

  UpdateType _parseUpdateType(String? type) {
    switch (type) {
      case 'critical':
        return UpdateType.critical;
      case 'optional':
        return UpdateType.optional;
      default:
        return UpdateType.none;
    }
  }

  Future<void> _cacheResult(VersionCheckResult result) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('version_check_update_type', result.updateType.name);
      await prefs.setString('version_check_store_url', result.storeUrl);
    } catch (_) {}
  }

  Future<VersionCheckResult> _loadCachedResult() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final type = prefs.getString('version_check_update_type');
      final url = prefs.getString('version_check_store_url') ?? '';
      if (type != null) {
        return VersionCheckResult(
          updateType: _parseUpdateType(type),
          minVersion: '',
          recommendedVersion: '',
          storeUrl: url,
        );
      }
    } catch (_) {}
    return VersionCheckResult.none;
  }
}
```

**Step 2: Commit**

```bash
git add safetrip-mobile/lib/services/version_check_service.dart
git commit -m "feat(splash): add VersionCheckService with cache fallback (DOC-T3-SPL-028 §7)"
```

---

## Task 3: Flutter — Splash Initializer Service

**Files:**
- Create: `safetrip-mobile/lib/services/splash_initializer.dart`

**Step 1: Create the initializer**

This orchestrates 5 parallel tasks: Firebase token refresh, version check, FCM token refresh, cache integrity check, deep link parsing. It reports results through a callback.

```dart
// safetrip-mobile/lib/services/splash_initializer.dart
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'version_check_service.dart';

enum SplashPhase { branding, loading, retry }

class InitResult {
  final bool firebaseSuccess;
  final bool versionCheckSuccess;
  final VersionCheckResult versionResult;
  final bool isOffline;

  const InitResult({
    required this.firebaseSuccess,
    required this.versionCheckSuccess,
    required this.versionResult,
    required this.isOffline,
  });
}

class SplashInitializer {
  final VersionCheckService _versionService;

  SplashInitializer({VersionCheckService? versionService})
      : _versionService = versionService ?? VersionCheckService();

  /// Run all initialization tasks in parallel.
  /// Returns when REQUIRED tasks (Firebase + Version) complete or timeout.
  Future<InitResult> initialize() async {
    bool firebaseSuccess = false;
    bool versionCheckSuccess = false;
    VersionCheckResult versionResult = VersionCheckResult.none;
    bool isOffline = false;

    // Task 1: Firebase silent refresh (required)
    final firebaseTask = _refreshFirebaseToken().then((success) {
      firebaseSuccess = success;
    });

    // Task 2: FCM token refresh (optional — fire and forget)
    _refreshFcmToken();

    // Task 3: Version check (required)
    final versionTask = _versionService.check().then((result) {
      versionResult = result;
      versionCheckSuccess = true;
    }).catchError((_) {
      versionCheckSuccess = false;
    });

    // Task 4: Cache integrity check (optional — fire and forget)
    _checkCacheIntegrity();

    // Task 5: Deep link parsing — already handled by DeeplinkService in main.dart

    // Wait for required tasks (1 + 3) with 3s timeout
    try {
      await Future.wait([firebaseTask, versionTask])
          .timeout(const Duration(seconds: 3));
    } on TimeoutException {
      debugPrint('[SplashInitializer] Required tasks timed out');
      isOffline = true;
    }

    return InitResult(
      firebaseSuccess: firebaseSuccess,
      versionCheckSuccess: versionCheckSuccess,
      versionResult: versionResult,
      isOffline: isOffline,
    );
  }

  Future<bool> _refreshFirebaseToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.getIdToken(true); // force refresh
        debugPrint('[SplashInitializer] Firebase token refreshed');
        return true;
      }
      // No user = not logged in, still success
      return true;
    } catch (e) {
      debugPrint('[SplashInitializer] Firebase refresh failed: $e');
      return false;
    }
  }

  Future<void> _refreshFcmToken() async {
    try {
      await FirebaseMessaging.instance.getToken();
      debugPrint('[SplashInitializer] FCM token refreshed');
    } catch (e) {
      debugPrint('[SplashInitializer] FCM refresh failed (ignored): $e');
    }
  }

  Future<void> _checkCacheIntegrity() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Basic sanity: ensure user_id and auth_verified_at are consistent
      final userId = prefs.getString('user_id');
      final authAt = prefs.getString('auth_verified_at');
      if (userId != null && authAt == null) {
        // Inconsistent state — clear
        debugPrint('[SplashInitializer] Cache inconsistency detected, clearing');
        await prefs.remove('user_id');
      }
    } catch (e) {
      debugPrint('[SplashInitializer] Cache check failed (ignored): $e');
    }
  }
}
```

**Step 2: Commit**

```bash
git add safetrip-mobile/lib/services/splash_initializer.dart
git commit -m "feat(splash): add SplashInitializer — 5 parallel background tasks (DOC-T3-SPL-028 §5)"
```

---

## Task 4: Flutter — Force Update Dialog Widget

**Files:**
- Create: `safetrip-mobile/lib/widgets/force_update_dialog.dart`

**Step 1: Create the widget**

```dart
// safetrip-mobile/lib/widgets/force_update_dialog.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../core/theme/app_spacing.dart';

class ForceUpdateDialog extends StatelessWidget {
  final String storeUrl;

  const ForceUpdateDialog({super.key, required this.storeUrl});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Block back button
      child: AlertDialog(
        title: Text(
          '업데이트가 필요합니다',
          style: AppTypography.titleLarge,
        ),
        content: Text(
          '안전한 여행을 위해 최신 버전으로 업데이트해 주세요.',
          style: AppTypography.bodyMedium,
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _openStore(),
              child: const Text('지금 업데이트'),
            ),
          ),
        ],
        actionsAlignment: MainAxisAlignment.center,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radius16),
        ),
      ),
    );
  }

  Future<void> _openStore() async {
    final uri = Uri.parse(storeUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// Show as a blocking, non-dismissible dialog
  static Future<void> show(BuildContext context, String storeUrl) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => ForceUpdateDialog(storeUrl: storeUrl),
    );
  }
}
```

**Step 2: Commit**

```bash
git add safetrip-mobile/lib/widgets/force_update_dialog.dart
git commit -m "feat(splash): add ForceUpdateDialog — critical update blocker (DOC-T3-SPL-028 §7.1)"
```

---

## Task 5: Flutter — AuthNotifier Updates

**Files:**
- Modify: `safetrip-mobile/lib/router/auth_notifier.dart`

**Step 1: Add initialization result fields**

Add the following fields and methods to `AuthNotifier`:

1. `_initCompleted` (bool) — splash initialization done
2. `_requiresForceUpdate` (bool) — critical update needed
3. `_forceUpdateStoreUrl` (String?) — store URL for update
4. `_isOffline` (bool) — offline state during init
5. `_optionalUpdateAvailable` (bool) — optional update available
6. `_optionalUpdateStoreUrl` (String?) — store URL for optional update

Add after existing field declarations (line ~22):

```dart
bool _initCompleted = false;
bool _requiresForceUpdate = false;
String? _forceUpdateStoreUrl;
bool _isOffline = false;
bool _optionalUpdateAvailable = false;
String? _optionalUpdateStoreUrl;
```

Add getters after existing getters (line ~33):

```dart
bool get initCompleted => _initCompleted;
bool get requiresForceUpdate => _requiresForceUpdate;
String? get forceUpdateStoreUrl => _forceUpdateStoreUrl;
bool get isOffline => _isOffline;
bool get optionalUpdateAvailable => _optionalUpdateAvailable;
String? get optionalUpdateStoreUrl => _optionalUpdateStoreUrl;
```

Add method at end of class:

```dart
void setInitResult({
  required bool firebaseSuccess,
  required bool requiresForceUpdate,
  String? forceUpdateStoreUrl,
  bool isOffline = false,
  bool optionalUpdateAvailable = false,
  String? optionalUpdateStoreUrl,
}) {
  if (!firebaseSuccess && _isAuthenticated) {
    // Firebase token refresh failed — force re-login
    _isAuthenticated = false;
    _isFirstLaunch = true;
  }
  _requiresForceUpdate = requiresForceUpdate;
  _forceUpdateStoreUrl = forceUpdateStoreUrl;
  _isOffline = isOffline;
  _optionalUpdateAvailable = optionalUpdateAvailable;
  _optionalUpdateStoreUrl = optionalUpdateStoreUrl;
  _initCompleted = true;
  notifyListeners();
}
```

**Step 2: Commit**

```bash
git add safetrip-mobile/lib/router/auth_notifier.dart
git commit -m "feat(splash): extend AuthNotifier with init result state (DOC-T3-SPL-028 §4)"
```

---

## Task 6: Flutter — Rewrite Splash Screen UI

**Files:**
- Modify: `safetrip-mobile/lib/screens/screen_splash.dart`

**Step 1: Rewrite with 3-phase UI + initialization orchestration**

Complete rewrite of `screen_splash.dart`:

```dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../core/theme/app_spacing.dart';
import '../services/splash_initializer.dart';
import '../services/version_check_service.dart';
import '../router/auth_notifier.dart';
import '../widgets/force_update_dialog.dart';

/// A-01 Splash Screen (DOC-T3-SPL-028)
///
/// 3-phase loading UI:
/// - Phase 1 (0-1s): Logo fade-in + slogan
/// - Phase 2 (1-3s): Indeterminate progress bar
/// - Phase 3 (3s+): "연결 중..." text + retry button
class InitialScreen extends StatefulWidget {
  final AuthNotifier authNotifier;

  const InitialScreen({super.key, required this.authNotifier});

  @override
  State<InitialScreen> createState() => _InitialScreenState();
}

class _InitialScreenState extends State<InitialScreen>
    with TickerProviderStateMixin {
  // Animation controllers
  late AnimationController _logoController;
  late Animation<double> _logoFade;
  late AnimationController _sloganController;
  late Animation<double> _sloganFade;

  // Phase tracking
  SplashPhase _phase = SplashPhase.branding;
  bool _initDone = false;
  int _retryCount = 0;

  // Timers
  Timer? _minTimer;
  Timer? _maxTimer;
  final Stopwatch _stopwatch = Stopwatch();

  @override
  void initState() {
    super.initState();

    // Logo animation (0.3s fade-in per spec §8.1)
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeIn),
    );

    // Slogan animation (0.2s delay after logo, per spec §8.1)
    _sloganController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _sloganFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _sloganController, curve: Curves.easeIn),
    );

    // Start animations sequentially
    _logoController.forward().then((_) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) _sloganController.forward();
      });
    });

    _stopwatch.start();
    _startInitialization();
  }

  void _startInitialization() {
    // Min display time: 1.0s (spec §3)
    _minTimer = Timer(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          if (_phase == SplashPhase.branding) {
            _phase = SplashPhase.loading;
          }
        });
        _tryTransition();
      }
    });

    // Max display time: 3.0s (spec §3)
    _maxTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && !_initDone) {
        setState(() => _phase = SplashPhase.retry);
      }
    });

    // Run background initialization
    _runInit();
  }

  Future<void> _runInit() async {
    final initializer = SplashInitializer();
    final result = await initializer.initialize();

    if (!mounted) return;
    _initDone = true;

    // Pass results to AuthNotifier
    widget.authNotifier.setInitResult(
      firebaseSuccess: result.firebaseSuccess,
      requiresForceUpdate: result.versionResult.updateType == UpdateType.critical,
      forceUpdateStoreUrl: result.versionResult.updateType == UpdateType.critical
          ? result.versionResult.storeUrl
          : null,
      isOffline: result.isOffline,
      optionalUpdateAvailable: result.versionResult.updateType == UpdateType.optional,
      optionalUpdateStoreUrl: result.versionResult.updateType == UpdateType.optional
          ? result.versionResult.storeUrl
          : null,
    );

    _tryTransition();
  }

  void _tryTransition() {
    // Only transition after min time (1s) AND init complete
    if (_initDone && _stopwatch.elapsedMilliseconds >= 1000) {
      _maxTimer?.cancel();

      // If critical update, show dialog instead of transitioning
      if (widget.authNotifier.requiresForceUpdate) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ForceUpdateDialog.show(
              context,
              widget.authNotifier.forceUpdateStoreUrl ?? '',
            );
          }
        });
        return;
      }

      // AuthNotifier.setInitResult() triggers notifyListeners()
      // which triggers GoRouter refresh → redirect handles navigation
    }
  }

  void _onRetry() {
    _retryCount++;
    setState(() {
      _phase = SplashPhase.branding;
      _initDone = false;
    });
    _stopwatch.reset();
    _stopwatch.start();
    _minTimer?.cancel();
    _maxTimer?.cancel();
    _startInitialization();
  }

  @override
  void dispose() {
    _logoController.dispose();
    _sloganController.dispose();
    _minTimer?.cancel();
    _maxTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1A1A2E) : AppColors.primaryTeal;

    return Scaffold(
      backgroundColor: bgColor,
      body: Semantics(
        label: 'SafeTrip, 로딩 중',
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Center: logo + slogan/status
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo
                  FadeTransition(
                    opacity: _logoFade,
                    child: Image.asset(
                      'assets/images/logo-L.png',
                      width: 120,
                      height: 120,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // App name
                  FadeTransition(
                    opacity: _logoFade,
                    child: Text(
                      'SafeTrip',
                      style: AppTypography.displayLarge.copyWith(
                        color: Colors.white,
                        fontSize: 40,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // Phase-dependent content
                  if (_phase == SplashPhase.retry) ...[
                    // Phase 3: "연결 중..." + retry button
                    Text(
                      '연결 중...',
                      style: AppTypography.bodyMedium.copyWith(
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    OutlinedButton(
                      onPressed: _onRetry,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppSpacing.radius12),
                        ),
                      ),
                      child: const Text('다시 시도'),
                    ),
                    if (_retryCount >= 3) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        '네트워크 연결을 확인해 주세요.',
                        style: AppTypography.bodySmall.copyWith(
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ] else ...[
                    // Phase 1 & 2: slogan
                    FadeTransition(
                      opacity: _sloganFade,
                      child: Text(
                        '함께 떠나고, 안전하게 돌아오다',
                        style: AppTypography.bodyMedium.copyWith(
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xxl),

                  // Phase 2: indeterminate progress bar
                  AnimatedOpacity(
                    opacity: _phase == SplashPhase.loading ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: SizedBox(
                      width: MediaQuery.of(context).size.width - 80, // 40dp margins
                      child: const LinearProgressIndicator(
                        color: Colors.white,
                        backgroundColor: Colors.white24,
                        minHeight: 2.0,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Bottom: version info (dynamic)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + AppSpacing.lg,
              left: 0,
              right: 0,
              child: FutureBuilder<String>(
                future: _getVersionString(),
                builder: (context, snapshot) {
                  return Text(
                    snapshot.data ?? '',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodySmall.copyWith(
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<String> _getVersionString() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return 'v${info.version}';
    } catch (_) {
      return '';
    }
  }
}
```

**Important:** Add `import 'package:package_info_plus/package_info_plus.dart';` at the top.

**Step 2: Commit**

```bash
git add safetrip-mobile/lib/screens/screen_splash.dart
git commit -m "feat(splash): rewrite with 3-phase UI + init orchestration (DOC-T3-SPL-028 §8)"
```

---

## Task 7: Flutter — Update Router for Splash Integration

**Files:**
- Modify: `safetrip-mobile/lib/router/app_router.dart`
- Modify: `safetrip-mobile/lib/main.dart`

**Step 1: Update AppRouter — pass authNotifier to splash screen**

In `app_router.dart`, change the splash route builder (line ~46):

From:
```dart
builder: (context, state) => const InitialScreen(),
```
To:
```dart
builder: (context, state) => InitialScreen(authNotifier: authNotifier),
```

**Step 2: Update redirect logic for force update and init completion**

In `app_router.dart`, update the `_redirect` method. Replace the existing splash redirect block (lines ~222-244) with:

```dart
if (path == RoutePaths.splash) {
  // Wait for both loading AND initialization to complete
  if (!isAuth && !authNotifier.initCompleted) return null; // stay on splash
  if (isAuth && !authNotifier.initCompleted) return null; // stay on splash

  // Force update blocks all navigation
  if (authNotifier.requiresForceUpdate) return null; // dialog shown on splash

  if (!isAuth) {
    // Check for deep link scenarios
    if (authNotifier.pendingInviteCode != null) {
      return RoutePaths.authPhone;
    }
    if (authNotifier.pendingGuardianCode != null) {
      return RoutePaths.authPhone;
    }
    return authNotifier.isFirstLaunch
        ? RoutePaths.onboardingWelcome
        : RoutePaths.onboardingPurpose;
  }
  // Authenticated
  return authNotifier.hasActiveTrip
      ? RoutePaths.main
      : RoutePaths.noTripHome;
}
```

**Step 3: Commit**

```bash
git add safetrip-mobile/lib/router/app_router.dart safetrip-mobile/lib/main.dart
git commit -m "feat(splash): integrate init state into GoRouter redirect (DOC-T3-SPL-028 §4)"
```

---

## Task 8: Flutter — Offline Banner Widget

**Files:**
- Create: `safetrip-mobile/lib/widgets/offline_banner.dart`

**Step 1: Create the widget**

```dart
// safetrip-mobile/lib/widgets/offline_banner.dart
import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: AppColors.secondaryAmber,
      child: Row(
        children: [
          const Icon(Icons.cloud_off, size: 16, color: Colors.black87),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '오프라인 상태입니다. 일부 기능이 제한됩니다.',
              style: AppTypography.bodySmall.copyWith(color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}
```

**Step 2: Commit**

```bash
git add safetrip-mobile/lib/widgets/offline_banner.dart
git commit -m "feat(splash): add OfflineBanner widget (DOC-T3-SPL-028 §13.2)"
```

---

## Task 9: Integration Testing — Manual Verification

**Step 1: Start backend**

```bash
cd safetrip-server-api && npm run dev
```

**Step 2: Verify version check endpoint**

```bash
curl http://localhost:3001/api/v1/version/check?platform=android&version=1.1.0
curl http://localhost:3001/api/v1/version/check?platform=android&version=0.5.0
```

**Step 3: Run Flutter app**

```bash
cd safetrip-mobile && flutter run
```

**Step 4: Verification against spec checklist (DOC-T3-SPL-028 §15)**

| # | Item | How to verify |
|---|------|--------------|
| 1 | Logo + slogan displayed center | Visual check on app launch |
| 2 | Min display 1.0s | Observe splash doesn't flash away |
| 3 | Max display 3.0s → retry UI | Kill network, observe retry button after 3s |
| 4 | New user → welcome | Clear SharedPreferences, launch app |
| 5 | Returning user → main | Have valid token, launch app |
| 6 | Deep link invite | Launch with `safetrip://invite/TEST123` |
| 7 | Force update (critical) | Set APP_MIN_VERSION=99.0.0 on server |
| 8 | Optional update | Set APP_RECOMMENDED_VERSION=99.0.0 |
| 9 | Offline banner | Disable network, launch app |
| 10 | Firebase expired → re-login | Delete cached token, have expired Firebase |
| 11 | Dark mode logo | Enable dark mode on device |
| 12 | Screen reader | Enable TalkBack, verify "SafeTrip, 로딩 중" |

**Step 5: Commit verification results**

```bash
git add -A
git commit -m "test(splash): verified DOC-T3-SPL-028 §15 checklist — all 12 items pass"
```

---

## Task 10: Round 2 — Bug Fixes and Refinements

After initial implementation, run a second verification pass:

**Step 1: Re-run all 12 checklist items**

Focus on edge cases:
- What happens if Firebase init fails AND version check fails simultaneously?
- Does retry button reset the 3-second timer?
- Does the progress bar width match spec (40dp margins)?
- Does slogan disappear in Phase 3?
- Does version text show dynamic version from package_info_plus?

**Step 2: Fix any issues found**

**Step 3: Commit fixes**

```bash
git commit -m "fix(splash): round 2 — [describe specific fixes]"
```

---

## Task 11: Round 3 — Final Verification and Polish

**Step 1: Final checklist pass**

Run through all 12 items one last time. Additionally verify:
- Performance: splash → next screen ≤ 3.0s on normal network
- Retry button responds within 100ms
- Animations are smooth (no janks)
- Dark mode background color matches spec (`Color(0xFF1A1A2E)`)

**Step 2: Fix any remaining issues**

**Step 3: Final commit**

```bash
git commit -m "feat(splash): final polish — DOC-T3-SPL-028 implementation complete"
```

---

## Summary of All Files

| File | Action |
|------|--------|
| `safetrip-server-api/src/modules/version/version.service.ts` | Create |
| `safetrip-server-api/src/modules/version/version.controller.ts` | Create |
| `safetrip-server-api/src/modules/version/version.module.ts` | Create |
| `safetrip-server-api/src/app.module.ts` | Modify (add VersionModule import) |
| `safetrip-mobile/lib/services/version_check_service.dart` | Create |
| `safetrip-mobile/lib/services/splash_initializer.dart` | Create |
| `safetrip-mobile/lib/widgets/force_update_dialog.dart` | Create |
| `safetrip-mobile/lib/widgets/offline_banner.dart` | Create |
| `safetrip-mobile/lib/router/auth_notifier.dart` | Modify (add init state) |
| `safetrip-mobile/lib/screens/screen_splash.dart` | Modify (rewrite) |
| `safetrip-mobile/lib/router/app_router.dart` | Modify (redirect logic) |
