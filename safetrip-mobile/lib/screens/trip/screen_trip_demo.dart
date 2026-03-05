import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../router/auth_notifier.dart';
import '../../router/route_paths.dart';

class ScreenTripDemo extends StatefulWidget {
  const ScreenTripDemo({super.key, required this.authNotifier});
  final AuthNotifier authNotifier;

  @override
  State<ScreenTripDemo> createState() => _ScreenTripDemoState();
}

class _ScreenTripDemoState extends State<ScreenTripDemo> {
  bool _isLoading = false;

  Future<void> _startDemo() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 가상 그룹 ID 설정
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('group_id', 'demo_group');
      await prefs.setString('user_id', 'demo_user');
      await prefs.setString('user_name', '데모 사용자');
      await prefs.setString('user_role', 'captain');
      
      // AuthNotifier 인증 상태 업데이트 (데모 모드)
      await widget.authNotifier.setDemoAuthenticated();
      
      if (mounted) {
        context.go(RoutePaths.main);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('오류가 발생했습니다: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          context.go(RoutePaths.noTripHome);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(
          title: const Text('데모 체험'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              context.go(RoutePaths.noTripHome);
            },
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                Text(
                  'SafeTrip 체험하기',
                  textAlign: TextAlign.center,
                  style: AppTypography.displayLarge.copyWith(color: AppColors.textPrimary),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '로그인 없이 주요 기능을 미리 볼 수 있어요.\n실제 위치 공유, SOS, 일정 관리 등을 체험해 보세요.',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyLarge.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 60),
                const Icon(
                  Icons.explore,
                  size: 80,
                  color: AppColors.primaryTeal,
                ),
                const SizedBox(height: 60),
                SizedBox(
                  height: AppSpacing.buttonHeight,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _startDemo,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryTeal,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppSpacing.radius12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(
                            '체험 시작하기',
                            style: AppTypography.labelLarge.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
