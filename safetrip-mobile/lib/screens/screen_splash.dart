import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../core/theme/app_spacing.dart';

/// A-01 Splash Screen
///
/// - 앱 로고 애니메이션 (Fade-in)
/// - 인증 상태 체크 및 초기화 수행 (AppRouter에서 관리)
/// - 버전 정보 표시
class InitialScreen extends StatefulWidget {
  const InitialScreen({super.key});

  @override
  State<InitialScreen> createState() => _InitialScreenState();
}

class _InitialScreenState extends State<InitialScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late Animation<double> _logoFade;

  late AnimationController _sloganController;
  late Animation<double> _sloganFade;

  bool _showProgress = false;

  @override
  void initState() {
    super.initState();

    // 1. 로고 애니메이션 (0.5s)
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeIn),
    );

    // 2. 슬로건 애니메이션 (0.5s, 로고 시작 0.3s 후)
    _sloganController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _sloganFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _sloganController, curve: Curves.easeIn),
    );

    // 애니메이션 순차 실행
    _logoController.forward().then((_) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) _sloganController.forward();
      });
    });

    // 3. 로딩 바 표시 (1.0s 후)
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() => _showProgress = true);
      }
    });
  }

  @override
  void dispose() {
    _logoController.dispose();
    _sloganController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryTeal,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 중앙 로고 및 텍스트
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 앱 로고
                FadeTransition(
                  opacity: _logoFade,
                  child: Image.asset(
                    'assets/images/logo-L.png',
                    width: 120,
                    height: 120,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // 앱 명칭
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

                // 슬로건
                FadeTransition(
                  opacity: _sloganFade,
                  child: Text(
                    '함께 떠나고, 안전하게 돌아오다',
                    style: AppTypography.bodyMedium.copyWith(
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),

                // 로딩 인디케이터
                AnimatedOpacity(
                  opacity: _showProgress ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: const SizedBox(
                    width: 200,
                    child: LinearProgressIndicator(
                      color: Colors.white,
                      backgroundColor: Colors.white24,
                      minHeight: 2.0,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 하단 버전 정보
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + AppSpacing.lg,
            left: 0,
            right: 0,
            child: Text(
              'v1.1.0',
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall.copyWith(
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
