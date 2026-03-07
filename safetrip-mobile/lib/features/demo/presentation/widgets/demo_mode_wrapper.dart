import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/demo_event_simulator.dart';
import '../../models/demo_scenario.dart';
import '../../providers/demo_state_provider.dart';
import 'demo_badge.dart';
import 'demo_coachmark.dart';
import 'demo_coachmark_data.dart';
import 'demo_event_toast.dart';
import 'demo_conversion_modal.dart';
import 'demo_grade_compare.dart';
import 'demo_guardian_compare.dart';
import 'demo_role_panel.dart';
import 'demo_time_slider.dart';

/// 데모 모드에서 MainScreen을 감싸는 래퍼
/// DemoBadge + DemoRolePanel + TimeSlider + 전환 FAB + 이벤트 시뮬레이터
class DemoModeWrapper extends ConsumerStatefulWidget {
  const DemoModeWrapper({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<DemoModeWrapper> createState() => _DemoModeWrapperState();
}

class _DemoModeWrapperState extends ConsumerState<DemoModeWrapper> {
  DemoEventSimulator? _eventSimulator;
  OverlayEntry? _coachmarkOverlay;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startEventSimulator();
    });
  }

  void _startEventSimulator() {
    final demoState = ref.read(demoStateProvider);
    final scenario = demoState.currentScenario;
    if (scenario == null) return;

    _eventSimulator = DemoEventSimulator(
      onEvent: _handleSimEvent,
    );
    _eventSimulator!.start(scenario.simulationEvents);

    // Show first coachmark after demo loads (§3.7)
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      final demoState = ref.read(demoStateProvider);
      if (!demoState.viewedCoachmarks.contains('map_tab')) {
        final screenSize = MediaQuery.of(context).size;
        final mapRect = Rect.fromCenter(
          center: Offset(screenSize.width / 2, screenSize.height * 0.35),
          width: screenSize.width - 32,
          height: 200,
        );
        _showCoachmark(kDemoCoachmarks[0], mapRect);
      }
    });
  }

  void _showCoachmark(CoachmarkDef coachmark, Rect targetRect) {
    _coachmarkOverlay?.remove();
    _coachmarkOverlay = OverlayEntry(
      builder: (_) => DemoCoachmarkOverlay(
        coachmark: coachmark,
        targetRect: targetRect,
        onDismiss: () {
          _coachmarkOverlay?.remove();
          _coachmarkOverlay = null;
        },
        onSkipAll: () {
          _coachmarkOverlay?.remove();
          _coachmarkOverlay = null;
        },
      ),
    );
    Overlay.of(context).insert(_coachmarkOverlay!);
  }

  void _handleSimEvent(DemoSimEvent event) {
    if (!mounted) return;
    DemoEventToast.show(context, type: event.type, message: event.description);
    ref.read(demoStateProvider.notifier).advanceEvent();
  }

  @override
  void dispose() {
    _coachmarkOverlay?.remove();
    _eventSimulator?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final demoState = ref.watch(demoStateProvider);

    // 데모 모드가 아니면 child만 반환
    if (!demoState.isActive) return widget.child;

    // Role change → pause/resume simulator
    ref.listen<DemoState>(demoStateProvider, (prev, next) {
      if (prev?.currentRole != next.currentRole) {
        _eventSimulator?.pause();
        Future.delayed(const Duration(milliseconds: 250), () {
          if (mounted) _eventSimulator?.resume();
        });
      }
    });

    final topPadding = MediaQuery.of(context).padding.top;
    final isCaptain = demoState.currentRole == DemoRole.captain;

    return Stack(
      children: [
        // Layer 0: 기존 MainScreen
        widget.child,

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

        // Layer 3: 타임 슬라이더 (§3.2, 바텀시트 위)
        const Positioned(
          left: 0,
          right: 0,
          bottom: 220, // above bottom sheet
          child: DemoTimeSlider(),
        ),

        // Layer 4: 가디언 비교 버튼 (캡틴 전용, §3.3)
        if (isCaptain)
          Positioned(
            top: topPadding + 30,
            left: AppSpacing.md,
            child: _GuardianCompareButton(
              onTap: () => DemoGuardianCompare.show(context),
            ),
          ),

        // Layer 4b: 등급 비교 버튼 (전체 역할, §3.5 + §4)
        Positioned(
          top: topPadding + (isCaptain ? 66 : 30),
          left: AppSpacing.md,
          child: _GradeCompareButton(
            onTap: () => DemoGradeCompare.show(context),
          ),
        ),

        // Layer 5: "실제 앱으로 전환" FAB (D5, 항상 표시)
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

class _GuardianCompareButton extends StatelessWidget {
  const _GuardianCompareButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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
            const Icon(Icons.shield, size: 14, color: AppColors.guardian),
            const SizedBox(width: 4),
            Text(
              '가디언 비교',
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.guardian,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GradeCompareButton extends StatelessWidget {
  const _GradeCompareButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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
            const Icon(Icons.tune, size: 14, color: AppColors.primaryTeal),
            const SizedBox(width: 4),
            Text(
              '등급 비교',
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.primaryTeal,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
