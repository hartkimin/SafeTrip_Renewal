import 'dart:async';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
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
/// - Phase 1 (0–1s): Logo fade-in + slogan (branding only)
/// - Phase 2 (1–3s): Indeterminate progress bar appears
/// - Phase 3 (3s+): "연결 중..." text + "다시 시도" retry button
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

  // Phase tracking (§8)
  SplashPhase _phase = SplashPhase.branding;
  bool _initDone = false;
  int _retryCount = 0;
  int _initGeneration = 0; // Guards against stale _runInit completions

  // Timers (§3)
  Timer? _minTimer;
  Timer? _maxTimer;
  final Stopwatch _stopwatch = Stopwatch();

  // Version string cache
  String _versionString = '';

  @override
  void initState() {
    super.initState();

    // Logo animation: 0.3s fade-in (§8.1)
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeIn),
    );

    // Slogan animation: 0.2s delay after logo complete (§8.1)
    _sloganController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _sloganFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _sloganController, curve: Curves.easeIn),
    );

    // Sequential animation start
    _logoController.forward().then((_) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) _sloganController.forward();
      });
    });

    // Load version string
    _loadVersion();

    // Start initialization pipeline
    _stopwatch.start();
    _startInitialization();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) setState(() => _versionString = 'v${info.version}');
    } catch (_) {}
  }

  void _startInitialization() {
    // Min display time: 1.0s — transition to Phase 2 (§3, §8.2)
    _minTimer = Timer(const Duration(seconds: 1), () {
      if (mounted) {
        // Only show loading phase if init is still running
        // Prevents progress bar flash when init completes in <1s
        if (!_initDone) {
          setState(() {
            if (_phase == SplashPhase.branding) {
              _phase = SplashPhase.loading;
            }
          });
        }
        _tryTransition();
      }
    });

    // Max display time: 3.0s — transition to Phase 3 retry UI (§3, §8.3)
    _maxTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && !_initDone) {
        setState(() => _phase = SplashPhase.retry);
      }
    });

    // Run background initialization (§5)
    _runInit();
  }

  Future<void> _runInit() async {
    final gen = ++_initGeneration;
    final initializer = SplashInitializer();
    final result = await initializer.initialize();

    if (!mounted || gen != _initGeneration) return; // Discard stale completions
    _initDone = true;

    // Pass results to AuthNotifier (triggers GoRouter refresh)
    widget.authNotifier.setInitResult(
      firebaseSuccess: result.firebaseSuccess,
      requiresForceUpdate:
          result.versionResult.updateType == UpdateType.critical,
      forceUpdateStoreUrl:
          result.versionResult.updateType == UpdateType.critical
              ? result.versionResult.storeUrl
              : null,
      optionalUpdateAvailable:
          result.versionResult.updateType == UpdateType.optional,
      optionalUpdateStoreUrl:
          result.versionResult.updateType == UpdateType.optional
              ? result.versionResult.storeUrl
              : null,
    );

    _tryTransition();
  }

  void _tryTransition() {
    // Only transition after min time (1s) AND init complete (§3)
    if (!_initDone || _stopwatch.elapsedMilliseconds < 1000) return;

    _maxTimer?.cancel();

    // If critical update required, show blocking dialog (§7.1)
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

    // AuthNotifier.setInitResult() already called notifyListeners()
    // → GoRouter refresh → _redirect handles navigation
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
            // Center: logo + text content
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo (§2.1)
                  // TODO(P2): Add dark mode logo variant when asset is provided
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

                  // Phase-dependent content below app name
                  if (_phase == SplashPhase.retry) ...[
                    // Phase 3 (§8.3): "연결 중..." + retry button
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
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radius12),
                        ),
                      ),
                      child: const Text('다시 시도'),
                    ),
                    // 3회 연속 실패 시 추가 안내 (§11.3)
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
                    // Phase 1 & 2: slogan (§8.1, §8.2)
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

                  // Phase 2 only: indeterminate progress bar (§8.2)
                  // Height 2dp, 40dp horizontal margin, fade-in 0.2s
                  if (_phase == SplashPhase.loading)
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 200),
                      builder: (context, opacity, child) =>
                          Opacity(opacity: opacity, child: child!),
                      child: SizedBox(
                        width: MediaQuery.of(context).size.width - 80,
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

            // Bottom: dynamic version info
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + AppSpacing.lg,
              left: 0,
              right: 0,
              child: Text(
                _versionString,
                textAlign: TextAlign.center,
                style: AppTypography.bodySmall.copyWith(
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
