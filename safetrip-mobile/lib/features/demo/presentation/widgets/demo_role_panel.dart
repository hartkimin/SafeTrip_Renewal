import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../features/trip/providers/trip_provider.dart';
import '../../models/demo_scenario.dart';
import '../../providers/demo_state_provider.dart';

/// §3.4: 역할 전환 패널 — 4개 역할 칩 (캡틴/크루장/크루/가디언)
class DemoRolePanel extends ConsumerStatefulWidget {
  const DemoRolePanel({super.key});

  @override
  ConsumerState<DemoRolePanel> createState() => _DemoRolePanelState();
}

class _DemoRolePanelState extends ConsumerState<DemoRolePanel> {
  bool _isExpanded = false;

  Future<void> _switchRole(DemoRole role) async {
    final notifier = ref.read(demoStateProvider.notifier);
    final demoState = ref.read(demoStateProvider);
    final scenario = demoState.currentScenario;
    if (scenario == null) return;

    notifier.switchRole(role);

    // Sync role string
    final roleStr = role == DemoRole.captain
        ? 'captain'
        : role == DemoRole.crewChief
            ? 'crew_chief'
            : role == DemoRole.crew
                ? 'crew'
                : 'guardian';

    // Update SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_role', roleStr);

    // Find the first member with this role
    final member = scenario.members.firstWhere(
      (m) => m.role == roleStr,
      orElse: () => scenario.members.first,
    );
    await prefs.setString('user_id', member.id);
    await prefs.setString('user_name', member.name);

    // Update trip provider
    ref.read(tripProvider.notifier).setCurrentTripDetails(
          tripName: scenario.title,
          tripStatus: 'active',
          userRole: roleStr,
          destinationName: scenario.destination.name,
          destinationTimezone: scenario.destination.timezone,
          countryCode: scenario.destination.countryCode,
          countryName: scenario.destination.countryName,
          totalMemberCount: scenario.memberCount,
          guardianCount: scenario.guardianCount,
        );
  }

  @override
  Widget build(BuildContext context) {
    final demoState = ref.watch(demoStateProvider);
    final currentRole = demoState.currentRole;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Toggle button
        GestureDetector(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppSpacing.radius12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.swap_horiz,
                  size: 16,
                  color: AppColors.roleColor(_roleString(currentRole)),
                ),
                const SizedBox(width: 4),
                Text(
                  _roleLabel(currentRole),
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.roleColor(_roleString(currentRole)),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 2),
                Icon(
                  _isExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 14,
                  color: AppColors.textTertiary,
                ),
              ],
            ),
          ),
        ),

        // Expanded role chips
        if (_isExpanded) ...[
          const SizedBox(height: 6),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppSpacing.radius12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: DemoRole.values.map((role) {
                final isSelected = role == currentRole;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: GestureDetector(
                    onTap: () {
                      _switchRole(role);
                      setState(() => _isExpanded = false);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.roleColor(_roleString(role))
                                .withValues(alpha: 0.12)
                            : Colors.transparent,
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radius8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: AppColors.roleColor(_roleString(role)),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _roleLabel(role),
                            style: AppTypography.bodySmall.copyWith(
                              color: isSelected
                                  ? AppColors.roleColor(_roleString(role))
                                  : AppColors.textPrimary,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }

  String _roleLabel(DemoRole role) {
    switch (role) {
      case DemoRole.captain:
        return '캡틴';
      case DemoRole.crewChief:
        return '크루장';
      case DemoRole.crew:
        return '크루';
      case DemoRole.guardian:
        return '가디언';
    }
  }

  String _roleString(DemoRole role) {
    switch (role) {
      case DemoRole.captain:
        return 'captain';
      case DemoRole.crewChief:
        return 'crew_chief';
      case DemoRole.crew:
        return 'crew';
      case DemoRole.guardian:
        return 'guardian';
    }
  }
}
