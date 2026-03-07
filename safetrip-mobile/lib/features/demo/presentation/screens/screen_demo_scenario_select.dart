import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../features/trip/providers/trip_provider.dart';
import '../../../../router/auth_notifier.dart';
import '../../../../router/route_paths.dart';
import '../../data/demo_analytics.dart';
import '../../data/demo_scenario_loader.dart';
import '../../models/demo_scenario.dart';
import '../../providers/demo_state_provider.dart';

class ScreenDemoScenarioSelect extends ConsumerStatefulWidget {
  const ScreenDemoScenarioSelect({super.key, required this.authNotifier});
  final AuthNotifier authNotifier;

  @override
  ConsumerState<ScreenDemoScenarioSelect> createState() =>
      _ScreenDemoScenarioSelectState();
}

class _ScreenDemoScenarioSelectState
    extends ConsumerState<ScreenDemoScenarioSelect> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    DemoAnalytics.demoStarted();
  }

  Future<void> _selectScenario(DemoScenarioId scenarioId) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      // 1. Load scenario JSON
      final scenario = await DemoScenarioLoader.load(scenarioId);

      // 2. Seed demo state provider
      ref.read(demoStateProvider.notifier).startDemo(scenario);
      DemoAnalytics.scenarioSelected(scenarioId.name);

      // 3. Seed trip provider with demo data
      final currentUser = scenario.members.firstWhere(
        (m) => m.role == 'captain',
        orElse: () => scenario.members.first,
      );
      ref.read(tripProvider.notifier).setCurrentTripDetails(
            tripName: scenario.title,
            tripStatus: 'active',
            userRole: currentUser.role,
            destinationName: scenario.destination.name,
            destinationTimezone: scenario.destination.timezone,
            countryCode: scenario.destination.countryCode,
            countryName: scenario.destination.countryName,
            totalMemberCount: scenario.memberCount,
            guardianCount: scenario.guardianCount,
            tripStartDate: DateTime.now(),
            tripEndDate: DateTime.now().add(
              Duration(days: scenario.durationDays),
            ),
          );

      // 4. Set SharedPreferences for demo mode
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_demo_mode', true);
      await prefs.setString('user_id', currentUser.id);
      await prefs.setString('user_name', currentUser.name);
      await prefs.setString('group_id', 'demo_${scenarioId.name}');
      await prefs.setString('user_role', currentUser.role);

      // 5. Set auth state and navigate
      await widget.authNotifier.setDemoAuthenticated();

      if (mounted) {
        context.go(RoutePaths.demoMain);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('시나리오 로딩 실패: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('데모 체험'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(RoutePaths.onboardingWelcome),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '시나리오 선택',
                      textAlign: TextAlign.center,
                      style: AppTypography.headlineMedium
                          .copyWith(color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'SafeTrip의 주요 기능을 체험해 보세요',
                      textAlign: TextAlign.center,
                      style: AppTypography.bodyLarge
                          .copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    _ScenarioCard(
                      icon: Icons.school,
                      iconColor: AppColors.privacySafetyFirst,
                      title: '학생 단체 여행',
                      subtitle: '제주도 3일 수학여행',
                      memberCount: 33,
                      durationDays: 3,
                      gradeBadge: '안전최우선',
                      gradeColor: AppColors.privacySafetyFirst,
                      onTap: () => _selectScenario(DemoScenarioId.s1),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _ScenarioCard(
                      icon: Icons.people,
                      iconColor: AppColors.privacyStandard,
                      title: '친구들과 해외여행',
                      subtitle: '도쿄 7일 자유여행',
                      memberCount: 6,
                      durationDays: 7,
                      gradeBadge: '표준',
                      gradeColor: AppColors.privacyStandard,
                      onTap: () => _selectScenario(DemoScenarioId.s2),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _ScenarioCard(
                      icon: Icons.business_center,
                      iconColor: AppColors.privacyFirst,
                      title: '해외 출장/패키지 투어',
                      subtitle: '방콕 5일 패키지 투어',
                      memberCount: 18,
                      durationDays: 5,
                      gradeBadge: '프라이버시우선',
                      gradeColor: AppColors.privacyFirst,
                      onTap: () => _selectScenario(DemoScenarioId.s3),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _ScenarioCard extends StatelessWidget {
  const _ScenarioCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.memberCount,
    required this.durationDays,
    required this.gradeBadge,
    required this.gradeColor,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final int memberCount;
  final int durationDays;
  final String gradeBadge;
  final Color gradeColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radius16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radius16),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.cardPadding),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSpacing.radius12),
                ),
                child: Icon(icon, color: iconColor, size: 28),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.titleMedium
                          .copyWith(color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTypography.bodySmall
                          .copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        _InfoChip(
                          icon: Icons.person,
                          label: '$memberCount명',
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        _InfoChip(
                          icon: Icons.calendar_today,
                          label: '$durationDays일',
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: gradeColor.withValues(alpha: 0.12),
                            borderRadius:
                                BorderRadius.circular(AppSpacing.radiusFull),
                          ),
                          child: Text(
                            gradeBadge,
                            style: AppTypography.labelSmall.copyWith(
                              color: gradeColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: AppColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppColors.textTertiary),
        const SizedBox(width: 2),
        Text(
          label,
          style:
              AppTypography.labelSmall.copyWith(color: AppColors.textTertiary),
        ),
      ],
    );
  }
}
