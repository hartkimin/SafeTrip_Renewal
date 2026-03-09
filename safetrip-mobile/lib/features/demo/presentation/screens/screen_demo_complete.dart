import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../router/route_paths.dart';
import '../../data/demo_analytics.dart';
import '../../providers/demo_state_provider.dart';
import '../widgets/demo_badge.dart';

/// §3.6 step 6: 데모 체험 완료 화면
class ScreenDemoComplete extends ConsumerStatefulWidget {
  const ScreenDemoComplete({super.key});

  @override
  ConsumerState<ScreenDemoComplete> createState() =>
      _ScreenDemoCompleteState();
}

class _ScreenDemoCompleteState extends ConsumerState<ScreenDemoComplete> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final demoState = ref.read(demoStateProvider);
      final duration = demoState.simStartTime != null
          ? DateTime.now().difference(demoState.simStartTime!).inSeconds
          : 0;
      final scenarioId = demoState.currentScenario?.id.name ?? 'unknown';
      DemoAnalytics.demoCompleted(
        durationSeconds: duration,
        scenarioId: scenarioId,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
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

                  // §8: 오프라인 가드 적용 CTA
                  FutureBuilder<ConnectivityResult>(
                    future: Connectivity().checkConnectivity(),
                    builder: (context, snapshot) {
                      final isOffline = snapshot.hasData &&
                          snapshot.data == ConnectivityResult.none;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // CTA: 여행 만들기
                          SizedBox(
                            height: AppSpacing.buttonHeight,
                            child: ElevatedButton(
                              onPressed: isOffline
                                  ? null
                                  : () => _exitAndNavigate(
                                      context, RoutePaths.authPhone),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryTeal,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                      AppSpacing.radius12),
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
                              onPressed: isOffline
                                  ? null
                                  : () => _exitAndNavigate(
                                      context, RoutePaths.tripJoin),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                    color: AppColors.primaryTeal),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                      AppSpacing.radius12),
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

                          // §8: 오프라인 안내
                          if (isOffline) ...[
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              '온라인 연결 후 이용 가능합니다',
                              textAlign: TextAlign.center,
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.textWarning,
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // Dismiss
                  Center(
                    child: TextButton(
                      onPressed: () => _dismissAndGoWelcome(context),
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
            // §2 D3: 데모 배지
            const Positioned(
              top: 8,
              left: 0,
              right: 0,
              child: Center(child: DemoBadge()),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exitAndNavigate(
      BuildContext context, String route) async {
    final ctaType = route == RoutePaths.authPhone ? 'create_trip' : 'join_code';
    DemoAnalytics.demoConverted(ctaType);
    await _clearDemoState();
    if (context.mounted) context.go(route);
  }

  Future<void> _dismissAndGoWelcome(BuildContext context) async {
    await _clearDemoState();
    if (context.mounted) context.go(RoutePaths.onboardingWelcome);
  }

  Future<void> _clearDemoState() async {
    ref.read(demoStateProvider.notifier).endDemo();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('is_demo_mode');
    await prefs.remove('demo_user_id');
    await prefs.remove('demo_user_name');
    await prefs.remove('demo_group_id');
    await prefs.remove('demo_user_role');
  }
}
