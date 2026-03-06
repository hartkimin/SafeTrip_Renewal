import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../router/route_paths.dart';
import '../../providers/demo_state_provider.dart';

/// §3.6 step 6: 데모 체험 완료 화면
class ScreenDemoComplete extends ConsumerWidget {
  const ScreenDemoComplete({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 2),

              // Completion icon
              Container(
                width: 80,
                height: 80,
                margin: const EdgeInsets.only(bottom: AppSpacing.xl),
                decoration: BoxDecoration(
                  color: AppColors.primaryTeal.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_outline,
                  size: 48,
                  color: AppColors.primaryTeal,
                ),
              ),

              Text(
                '데모 체험을 완료했습니다!',
                textAlign: TextAlign.center,
                style: AppTypography.headlineMedium
                    .copyWith(color: AppColors.textPrimary),
              ),
              const SizedBox(height: AppSpacing.md),

              Text(
                '실제 SafeTrip으로 안전한 여행을 시작해 보세요.\n회원가입은 30초면 충분합니다.',
                textAlign: TextAlign.center,
                style: AppTypography.bodyLarge
                    .copyWith(color: AppColors.textSecondary),
              ),

              const Spacer(flex: 2),

              // CTA: 여행 만들기
              SizedBox(
                height: AppSpacing.buttonHeight,
                child: ElevatedButton(
                  onPressed: () => _exitAndNavigate(context, ref, RoutePaths.authPhone),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryTeal,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radius12),
                    ),
                  ),
                  child: Text(
                    '여행 만들기',
                    style: AppTypography.labelLarge.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              // CTA: 초대코드로 참여
              SizedBox(
                height: AppSpacing.buttonHeight,
                child: OutlinedButton(
                  onPressed: () => _exitAndNavigate(context, ref, RoutePaths.tripJoin),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.primaryTeal),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radius12),
                    ),
                  ),
                  child: Text(
                    '초대코드로 참여',
                    style: AppTypography.labelLarge.copyWith(
                      color: AppColors.primaryTeal,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              // Dismiss
              Center(
                child: TextButton(
                  onPressed: () => _dismissAndGoWelcome(context, ref),
                  child: Text(
                    '나중에 할게요',
                    style: AppTypography.bodyMedium
                        .copyWith(color: AppColors.textTertiary),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _exitAndNavigate(
      BuildContext context, WidgetRef ref, String route) async {
    await _clearDemoState(ref);
    if (context.mounted) context.go(route);
  }

  Future<void> _dismissAndGoWelcome(
      BuildContext context, WidgetRef ref) async {
    await _clearDemoState(ref);
    if (context.mounted) context.go(RoutePaths.onboardingWelcome);
  }

  Future<void> _clearDemoState(WidgetRef ref) async {
    ref.read(demoStateProvider.notifier).endDemo();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('is_demo_mode');
    await prefs.remove('user_id');
    await prefs.remove('user_name');
    await prefs.remove('group_id');
    await prefs.remove('user_role');
  }
}
