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
/// 상단 한 줄: 도구메뉴(좌) + 뱃지(중) + 역할패널(우)
/// 하단: 타임슬라이더 + 이벤트 시뮬레이터
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

    // Show first coachmark after demo loads (§3.7 — 체이닝 트리거)
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      _showNextUnviewedCoachmark(0);
    });
  }

  /// §3.7: 다음 미조회 코치마크를 자동 표시 (체이닝)
  void _showNextUnviewedCoachmark(int startIndex) {
    if (!mounted) return;
    final demoState = ref.read(demoStateProvider);

    for (int i = startIndex; i < kDemoCoachmarks.length; i++) {
      final cm = kDemoCoachmarks[i];
      if (!demoState.viewedCoachmarks.contains(cm.id)) {
        final targetRect = _getCoachmarkTargetRect(i);
        _showCoachmark(cm, targetRect, i);
        return;
      }
    }
  }

  /// 코치마크별 타겟 영역 계산 (3개: 지도, 역할, 슬라이더)
  Rect _getCoachmarkTargetRect(int index) {
    final screenSize = MediaQuery.of(context).size;
    final topPadding = MediaQuery.of(context).padding.top;

    switch (index) {
      case 0: // map_tab — 지도 중앙
        return Rect.fromCenter(
          center: Offset(screenSize.width / 2, screenSize.height * 0.35),
          width: screenSize.width - 32,
          height: 200,
        );
      case 1: // role_panel — 우측 상단 (뱃지와 같은 줄)
        return Rect.fromLTWH(
          screenSize.width - 120,
          topPadding + 4,
          100,
          30,
        );
      case 2: // time_slider — 하단
        return Rect.fromLTWH(
          16,
          screenSize.height - 290,
          screenSize.width - 32,
          80,
        );
      default:
        return Rect.fromCenter(
          center: Offset(screenSize.width / 2, screenSize.height / 2),
          width: 100,
          height: 100,
        );
    }
  }

  void _showCoachmark(CoachmarkDef coachmark, Rect targetRect, int index) {
    _coachmarkOverlay?.remove();
    _coachmarkOverlay = OverlayEntry(
      builder: (_) => DemoCoachmarkOverlay(
        coachmark: coachmark,
        targetRect: targetRect,
        onDismiss: () {
          _coachmarkOverlay?.remove();
          _coachmarkOverlay = null;
          // §3.7: 체이닝 — 다음 코치마크 자동 표시
          Future.delayed(const Duration(milliseconds: 500), () {
            _showNextUnviewedCoachmark(index + 1);
          });
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

    return Stack(
      children: [
        // Layer 0: 기존 MainScreen
        widget.child,

        // ── 상단 한 줄: 도구(좌) + 뱃지(중) + 역할(우) ──

        // 도구 메뉴 (좌측 — 가디언 비교, 등급 비교, 실제 앱 전환)
        Positioned(
          top: topPadding + 4,
          left: AppSpacing.md,
          child: const _DemoToolsMenu(),
        ),

        // 데모 뱃지 (중앙, §2 D3)
        Positioned(
          top: topPadding + 4,
          left: 0,
          right: 0,
          child: const Center(child: DemoBadge()),
        ),

        // 역할 전환 패널 (우측, §3.4)
        Positioned(
          top: topPadding + 4,
          right: AppSpacing.md,
          child: const DemoRolePanel(),
        ),

        // ── 하단: 타임 슬라이더 ──

        const Positioned(
          left: 0,
          right: 0,
          bottom: 200,
          child: DemoTimeSlider(),
        ),
      ],
    );
  }
}

// =============================================================================
// 도구 팝업 메뉴 (가디언 비교 + 등급 비교 + 실제 앱 전환)
// =============================================================================

class _DemoToolsMenu extends ConsumerWidget {
  const _DemoToolsMenu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final demoState = ref.watch(demoStateProvider);
    final canAccessGuardian = demoState.canAccess('guardian_billing');

    return Material(
      type: MaterialType.transparency,
      child: PopupMenuButton<String>(
      offset: const Offset(0, 36),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radius12),
      ),
      color: Colors.white,
      elevation: 4,
      onSelected: (value) {
        switch (value) {
          case 'guardian':
            if (canAccessGuardian) DemoGuardianCompare.show(context);
          case 'grade':
            DemoGradeCompare.show(context);
          case 'exit':
            DemoConversionModal.show(context);
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          value: 'guardian',
          enabled: canAccessGuardian,
          child: Row(
            children: [
              Icon(
                canAccessGuardian ? Icons.shield : Icons.lock,
                size: 16,
                color: canAccessGuardian
                    ? AppColors.guardian
                    : AppColors.textTertiary,
              ),
              const SizedBox(width: 8),
              Text(
                '가디언 비교',
                style: AppTypography.bodySmall.copyWith(
                  color: canAccessGuardian
                      ? AppColors.textPrimary
                      : AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'grade',
          child: Row(
            children: [
              const Icon(Icons.tune, size: 16, color: AppColors.primaryTeal),
              const SizedBox(width: 8),
              Text('등급 비교', style: AppTypography.bodySmall),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'exit',
          child: Row(
            children: [
              const Icon(Icons.login, size: 16, color: AppColors.primaryTeal),
              const SizedBox(width: 8),
              Text(
                '실제 앱으로 전환',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.primaryTeal,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
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
            const Icon(
              Icons.more_horiz,
              size: 16,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              '도구',
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }
}
