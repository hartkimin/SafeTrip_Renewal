import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../router/auth_notifier.dart';
import '../../../../router/route_paths.dart';
import '../../data/ab_test_service.dart';
import '../../data/welcome_analytics.dart';
import '../../l10n/welcome_strings.dart';

/// DOC-T3-WLC-029 §3.2 Phase 3 — Purpose Selection Screen
/// W4: Role-based purpose selection without exposing internal role terms
/// W5: Zero frustration — every choice leads to a valid path
class ScreenPurposeSelect extends StatefulWidget {
  const ScreenPurposeSelect({super.key, this.authNotifier});

  final AuthNotifier? authNotifier;

  @override
  State<ScreenPurposeSelect> createState() => _ScreenPurposeSelectState();
}

class _ScreenPurposeSelectState extends State<ScreenPurposeSelect> {
  WelcomeAbVariant _abVariant = WelcomeAbVariant.a;

  @override
  void initState() {
    super.initState();
    _initAbVariantAndAnalytics();
    _showDeeplinkFailureToast();
  }

  Future<void> _initAbVariantAndAnalytics() async {
    final variant = await WelcomeAbTestService.getVariant();
    if (!mounted) return;
    setState(() => _abVariant = variant);

    // §7.3: Fire welcome_view if not already fired (dedup covers deeplink path)
    WelcomeAnalytics.welcomeView(
      abVariant: variant.name,
      timeOfDay: AppColors.timeOfDayName(),
      deeplinkPresent: widget.authNotifier?.inviteDeeplinkFailed == true,
    );
  }

  /// §6.1: Show toast when invite deeplink parsing failed
  void _showDeeplinkFailureToast() {
    final authNotifier = widget.authNotifier;
    if (authNotifier == null || !authNotifier.inviteDeeplinkFailed) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(WelcomeStrings.inviteCodeManualHint),
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
        ),
      );
      authNotifier.clearInviteDeeplinkFailed();
    });
  }

  void _onRoleSelected(BuildContext context, String role) {
    WelcomeAnalytics.purposeSelected(purpose: role);
    context.push(RoutePaths.authPhone, extra: {'role': role});
  }

  @override
  Widget build(BuildContext context) {
    // §3.6: CTA text variant
    final ctaVariant = WelcomeAbTestService.ctaText(_abVariant);
    final createTripLabel = WelcomeStrings.createTripForVariant(ctaVariant);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Column(
            children: [
              const Spacer(),

              // Logo
              Semantics(
                label: 'SafeTrip 로고',
                child: Image.asset(
                  'assets/images/logo-L.png',
                  width: 80,
                  height: 80,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // Question (§3.2 Phase 3)
              Text(
                WelcomeStrings.purposeTitle,
                textAlign: TextAlign.center,
                style: AppTypography.headlineMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),

              // 1. 여행 만들기 (Captain) — Primary CTA with A/B variant
              _PurposeButton(
                icon: '✈️',
                label: createTripLabel,
                semanticLabel: '$createTripLabel 버튼',
                onTap: () => _onRoleSelected(context, 'captain'),
              ),
              const SizedBox(height: AppSpacing.md),

              // 2. 초대코드 입력 (Crew)
              _PurposeButton(
                icon: '🔑',
                label: WelcomeStrings.enterCode,
                semanticLabel: '${WelcomeStrings.enterCode} 버튼',
                isSecondary: true,
                onTap: () {
                  WelcomeAnalytics.purposeSelected(purpose: 'join_trip');
                  context.push(RoutePaths.tripJoin);
                },
              ),
              const SizedBox(height: AppSpacing.md),

              // 3. 먼저 둘러보기 (Demo)
              _PurposeButton(
                icon: '👀',
                label: WelcomeStrings.demoTour,
                semanticLabel: '${WelcomeStrings.demoTour} 버튼',
                isOutlined: true,
                onTap: () {
                  WelcomeAnalytics.purposeSelected(purpose: 'demo');
                  context.go(RoutePaths.tripDemo);
                },
              ),
              const SizedBox(height: AppSpacing.lg),

              // 4. 가디언으로 참여 (§3.2, §03.1 free guardian direct entry)
              Semantics(
                button: true,
                label: '${WelcomeStrings.guardianJoin} 링크',
                child: TextButton(
                  onPressed: () => _onRoleSelected(context, 'guardian'),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(
                      AppSpacing.minTouchTarget,
                      AppSpacing.minTouchTarget,
                    ),
                  ),
                  child: Text(
                    '${WelcomeStrings.guardianJoin} →',
                    style: AppTypography.labelLarge.copyWith(
                      color: AppColors.primaryTeal,
                      fontWeight: FontWeight.w600,
                    ),
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
}

/// Reusable purpose button with consistent styling
class _PurposeButton extends StatelessWidget {
  const _PurposeButton({
    required this.icon,
    required this.label,
    required this.semanticLabel,
    this.isSecondary = false,
    this.isOutlined = false,
    required this.onTap,
  });

  final String icon;
  final String label;
  final String semanticLabel;
  final bool isSecondary;
  final bool isOutlined;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: SizedBox(
        width: double.infinity,
        height: AppSpacing.buttonHeight + 4,
        child: isOutlined
            ? OutlinedButton(
                onPressed: onTap,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.outline),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radius16),
                  ),
                ),
                child: _content(AppColors.textPrimary),
              )
            : ElevatedButton(
                onPressed: onTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isSecondary
                      ? AppColors.textPrimary
                      : AppColors.primaryTeal,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radius16),
                  ),
                ),
                child: _content(Colors.white),
              ),
      ),
    );
  }

  Widget _content(Color textColor) {
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
