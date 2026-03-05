import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../router/route_paths.dart';

/// A-02 Purpose Selection Screen
class ScreenPurposeSelect extends StatelessWidget {
  const ScreenPurposeSelect({super.key});

  void _onRoleSelected(BuildContext context, String role) {
    // New flow: purpose → phone (not terms)
    context.push(RoutePaths.authPhone, extra: {'role': role});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Column(
            children: [
              const Spacer(),
              Image.asset(
                'assets/images/logo-L.png',
                width: 80,
                height: 80,
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                '어떤 목적으로 SafeTrip을\n사용하시나요?',
                textAlign: TextAlign.center,
                style: AppTypography.headlineMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),

              // 1. 여행 만들기 (Captain)
              _buildRoleButton(
                context: context,
                icon: '✈️',
                label: '여행 만들기',
                onTap: () => _onRoleSelected(context, 'captain'),
              ),
              const SizedBox(height: AppSpacing.md),

              // 2. 초대코드 입력 (Crew) — goes directly to trip join screen
              _buildRoleButton(
                context: context,
                icon: '🔑',
                label: '초대코드 입력',
                isSecondary: true,
                onTap: () => context.push(RoutePaths.tripJoin),
              ),
              const SizedBox(height: AppSpacing.md),

              // 3. 먼저 둘러보기 (Demo)
              _buildRoleButton(
                context: context,
                icon: '👀',
                label: '먼저 둘러보기',
                isOutlined: true,
                onTap: () => context.go(RoutePaths.tripDemo),
              ),
              const SizedBox(height: AppSpacing.lg),

              // 4. 가디언 참여
              TextButton(
                onPressed: () => _onRoleSelected(context, 'guardian'),
                child: Text(
                  '가디언으로 참여 →',
                  style: AppTypography.labelLarge.copyWith(
                    color: AppColors.primaryTeal,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleButton({
    required BuildContext context,
    required String icon,
    required String label,
    bool isSecondary = false,
    bool isOutlined = false,
    required VoidCallback onTap,
  }) {
    final style = ElevatedButton.styleFrom(
      backgroundColor: isOutlined 
          ? Colors.transparent 
          : (isSecondary ? AppColors.textPrimary : AppColors.primaryTeal),
      foregroundColor: isOutlined ? AppColors.textPrimary : Colors.white,
      elevation: 0,
      side: isOutlined ? const BorderSide(color: AppColors.outline) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radius16),
      ),
    );

    return SizedBox(
      width: double.infinity,
      height: AppSpacing.buttonHeight + 4,
      child: isOutlined
          ? OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.outline),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radius16),
                ),
              ),
              child: _buildButtonContent(icon, label, AppColors.textPrimary),
            )
          : ElevatedButton(
              onPressed: onTap,
              style: style,
              child: _buildButtonContent(icon, label, Colors.white),
            ),
    );
  }

  Widget _buildButtonContent(String icon, String label, Color textColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(icon, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: AppSpacing.sm),
        Text(
          label,
          style: AppTypography.labelLarge.copyWith(
            color: textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
