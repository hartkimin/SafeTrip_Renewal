import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../providers/demo_state_provider.dart';
import 'demo_badge.dart';
import 'demo_conversion_modal.dart';
import 'demo_role_panel.dart';

/// 데모 모드에서 MainScreen을 감싸는 래퍼
/// DemoBadge + DemoRolePanel + 전환 FAB을 오버레이한다.
class DemoModeWrapper extends ConsumerWidget {
  const DemoModeWrapper({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final demoState = ref.watch(demoStateProvider);

    // 데모 모드가 아니면 child만 반환
    if (!demoState.isActive) return child;

    final topPadding = MediaQuery.of(context).padding.top;

    return Stack(
      children: [
        // Layer 0: 기존 MainScreen
        child,

        // Layer 1: 데모 뱃지 (top center, §2 D3)
        Positioned(
          top: topPadding + 4,
          left: 0,
          right: 0,
          child: const Center(child: DemoBadge()),
        ),

        // Layer 2: 역할 전환 패널 (우측, §3.4)
        Positioned(
          top: topPadding + 30,
          right: AppSpacing.md,
          child: const DemoRolePanel(),
        ),

        // Layer 3: "실제 앱으로 전환" FAB (D5, 항상 표시)
        Positioned(
          left: AppSpacing.md,
          bottom: AppSpacing.navigationBarHeight + 28,
          child: _ExitDemoFab(
            onTap: () => DemoConversionModal.show(context),
          ),
        ),
      ],
    );
  }
}

class _ExitDemoFab extends StatelessWidget {
  const _ExitDemoFab({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primaryTeal,
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryTeal.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.login, size: 16, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              '실제 앱으로 전환',
              style: AppTypography.labelSmall.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
