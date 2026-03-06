import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../router/route_paths.dart';
import '../../providers/demo_state_provider.dart';

/// §3.8: 데모 → 실제 앱 전환 유도 모달
class DemoConversionModal extends ConsumerWidget {
  const DemoConversionModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const DemoConversionModal(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radius20),
        ),
      ),
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // Icon
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.primaryTeal.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.rocket_launch,
                size: 32,
                color: AppColors.primaryTeal,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Title
            Text(
              'SafeTrip 체험 완료!',
              style: AppTypography.headlineMedium
                  .copyWith(color: AppColors.textPrimary),
            ),
            const SizedBox(height: AppSpacing.sm),

            // Body
            Text(
              '지금 실제 SafeTrip을 시작하세요.\n회원가입 30초면 충분합니다.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyLarge
                  .copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.xl),

            // CTA: 여행 만들기
            SizedBox(
              width: double.infinity,
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
              width: double.infinity,
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
            TextButton(
              onPressed: () => _dismissAndGoWelcome(context, ref),
              child: Text(
                '나중에 할게요',
                style: AppTypography.bodyMedium
                    .copyWith(color: AppColors.textTertiary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exitAndNavigate(
      BuildContext context, WidgetRef ref, String route) async {
    await _clearDemoState(ref);
    if (context.mounted) {
      Navigator.of(context).pop(); // close modal
      context.go(route);
    }
  }

  Future<void> _dismissAndGoWelcome(
      BuildContext context, WidgetRef ref) async {
    await _clearDemoState(ref);
    if (context.mounted) {
      Navigator.of(context).pop(); // close modal
      context.go(RoutePaths.onboardingWelcome);
    }
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
