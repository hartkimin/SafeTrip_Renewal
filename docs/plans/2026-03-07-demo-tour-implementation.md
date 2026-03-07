# Demo Tour Phase 1~3 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fill all gaps between existing demo feature code (~70% done) and DOC-T3-DMO-030 v2.1 architecture requirements across Phase 1~3.

**Architecture:** GAP-first sequential approach. Existing code uses Riverpod state management with `DemoStateProvider`, JSON-based scenario data in `assets/demo/`, and `DemoModeWrapper` overlay pattern. All new code follows the same patterns — no new libraries.

**Tech Stack:** Flutter/Dart, Riverpod, GoRouter, CustomPainter (coachmarks), Firebase Analytics pattern (debugPrint placeholder)

---

## Key Discovery: Phase 1 Already Complete

The welcome screen (`screen_welcome.dart:252-277`) already has the "먼저 둘러보기" CTA on the last slide, navigating to `RoutePaths.tripDemo`. **No Phase 1 work needed.**

---

### Task 1: Demo Event Toast Widget

**Files:**
- Create: `safetrip-mobile/lib/features/demo/presentation/widgets/demo_event_toast.dart`

**Step 1: Create the event toast widget**

This replaces the inline SnackBar in `demo_mode_wrapper.dart` with a richer, type-specific toast.

```dart
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

/// §3.6 step 4: Event-specific toast notification
/// Shows icon + color based on event type, auto-dismisses after 3 seconds.
class DemoEventToast {
  DemoEventToast._();

  static void show(BuildContext context, {
    required String type,
    required String message,
  }) {
    final config = _configFor(type);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(config.icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(message, style: AppTypography.bodySmall.copyWith(
                color: Colors.white,
              )),
            ),
          ],
        ),
        backgroundColor: config.color,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: config.isAlert ? 4 : 3),
        margin: const EdgeInsets.only(
          bottom: 120,
          left: AppSpacing.md,
          right: AppSpacing.md,
        ),
        dismissDirection: DismissDirection.horizontal,
      ),
    );
  }

  static _ToastConfig _configFor(String type) {
    switch (type) {
      case 'sos_drill':
      case 'sos_resolved':
        return _ToastConfig(Icons.sos, AppColors.semanticError, true);
      case 'geofence_out':
      case 'geofence_violation':
        return _ToastConfig(Icons.warning_amber, AppColors.semanticWarning, true);
      case 'member_left':
        return _ToastConfig(Icons.person_off, AppColors.secondaryAmber, true);
      case 'schedule_changed':
        return _ToastConfig(Icons.event_note, AppColors.semanticInfo, false);
      case 'geofence_in':
      case 'all_arrived':
        return _ToastConfig(Icons.location_on, AppColors.semanticSuccess, false);
      case 'chat_message':
        return _ToastConfig(Icons.chat_bubble, AppColors.primaryTeal, false);
      case 'trip_start':
      case 'trip_end':
        return _ToastConfig(Icons.flight, AppColors.primaryTeal, false);
      case 'notification':
        return _ToastConfig(Icons.notifications, AppColors.secondaryAmber, false);
      case 'daily_summary':
        return _ToastConfig(Icons.summarize, AppColors.primaryTeal, false);
      default:
        return _ToastConfig(Icons.info, AppColors.primaryTeal, false);
    }
  }
}

class _ToastConfig {
  const _ToastConfig(this.icon, this.color, this.isAlert);
  final IconData icon;
  final Color color;
  final bool isAlert;
}
```

**Step 2: Refactor DemoModeWrapper to use DemoEventToast**

In `demo_mode_wrapper.dart`, replace the inline `_handleSimEvent` and `_eventIcon` methods:

```dart
// Replace lines 48-107 in demo_mode_wrapper.dart with:
void _handleSimEvent(DemoSimEvent event) {
  if (!mounted) return;
  DemoEventToast.show(context, type: event.type, message: event.description);
  ref.read(demoStateProvider.notifier).advanceEvent();
}
```

Remove the `_eventIcon` method entirely (lines 84-107).

Add import: `import 'demo_event_toast.dart';`

**Step 3: Add new event types to scenario JSONs**

Add `member_left` and `schedule_changed` events to each scenario JSON file.

For `scenario_s1.json`, add after the `geofence_out` event (after line 100):
```json
{"time_offset_minutes": 135, "type": "member_left", "description": "장우진 학생이 그룹에서 일시적으로 이탈했습니다", "member_id": "m_crew05"},
```

For `scenario_s2.json`, add a `schedule_changed` event:
```json
{"time_offset_minutes": 300, "type": "schedule_changed", "description": "크루장이 일정을 변경했습니다: 시부야 → 하라주쿠"},
```

For `scenario_s3.json`, add a `member_left` event:
```json
{"time_offset_minutes": 200, "type": "member_left", "description": "크루 1명이 업무 회의로 일시 이탈했습니다", "member_id": "m_crew01"},
```

**Step 4: Verify build compiles**

Run: `cd safetrip-mobile && flutter analyze lib/features/demo/`
Expected: No errors

**Step 5: Commit**

```bash
git add safetrip-mobile/lib/features/demo/presentation/widgets/demo_event_toast.dart \
  safetrip-mobile/lib/features/demo/presentation/widgets/demo_mode_wrapper.dart \
  safetrip-mobile/assets/demo/
git commit -m "feat(demo): add event-specific toast widget and enrich scenario events (DOC-T3-DMO-030 §3.6)"
```

---

### Task 2: Demo Analytics Service

**Files:**
- Create: `safetrip-mobile/lib/features/demo/data/demo_analytics.dart`
- Modify: `safetrip-mobile/lib/features/demo/presentation/screens/screen_demo_scenario_select.dart`
- Modify: `safetrip-mobile/lib/features/demo/presentation/screens/screen_demo_complete.dart`
- Modify: `safetrip-mobile/lib/features/demo/presentation/widgets/demo_role_panel.dart`
- Modify: `safetrip-mobile/lib/features/demo/presentation/widgets/demo_guardian_compare.dart`
- Modify: `safetrip-mobile/lib/features/demo/presentation/widgets/demo_conversion_modal.dart`

**Step 1: Create the analytics service**

Following the same pattern as `welcome_analytics.dart` (debugPrint with TODO for Firebase):

```dart
import 'package:flutter/foundation.dart';

/// DOC-T3-DMO-030 §3.8 — Demo mode analytics events
/// 7 events for measuring demo-to-signup conversion.
/// No PII — only session UUID as identifier (D1 principle).
class DemoAnalytics {
  DemoAnalytics._();

  /// Fires when user enters scenario selection screen
  static void demoStarted() {
    _log('demo_started', {});
  }

  /// Fires when user selects a scenario
  static void scenarioSelected(String scenarioId) {
    _log('demo_scenario_selected', {'scenario_id': scenarioId});
  }

  /// Fires when user switches role via role panel
  static void roleSwitched({
    required String fromRole,
    required String toRole,
  }) {
    _log('demo_role_switched', {
      'from_role': fromRole,
      'to_role': toRole,
    });
  }

  /// Fires when user switches privacy grade
  static void gradeSwitched(String grade) {
    _log('demo_grade_switched', {'grade': grade});
  }

  /// Fires when user views guardian upgrade comparison
  static void guardianUpgradeViewed() {
    _log('demo_guardian_upgrade_viewed', {});
  }

  /// Fires when demo completion screen is shown
  static void demoCompleted({
    required int durationSeconds,
    required String scenarioId,
  }) {
    _log('demo_completed', {
      'duration_seconds': durationSeconds.toString(),
      'scenario_id': scenarioId,
    });
  }

  /// Fires when user taps a conversion CTA
  static void demoConverted(String ctaType) {
    _log('demo_converted', {'cta_type': ctaType});
  }

  static void _log(String eventName, Map<String, String> params) {
    debugPrint('[DemoAnalytics] $eventName: $params');
    // TODO: Replace with FirebaseAnalytics.instance.logEvent() when integrated
  }
}
```

**Step 2: Wire analytics into screen_demo_scenario_select.dart**

Add import at top:
```dart
import '../../data/demo_analytics.dart';
```

In `_ScreenDemoScenarioSelectState`, add to `initState` override:
```dart
@override
void initState() {
  super.initState();
  DemoAnalytics.demoStarted();
}
```

In `_selectScenario`, after line 38 (`ref.read(demoStateProvider.notifier).startDemo(scenario);`):
```dart
DemoAnalytics.scenarioSelected(scenarioId.name);
```

**Step 3: Wire analytics into screen_demo_complete.dart**

Change from `ConsumerWidget` to `ConsumerStatefulWidget` to add `initState`.

Add import:
```dart
import '../../data/demo_analytics.dart';
```

Add initState that fires `demo_completed`:
```dart
@override
void initState() {
  super.initState();
  final demoState = ref.read(demoStateProvider);
  final duration = demoState.simStartTime != null
      ? DateTime.now().difference(demoState.simStartTime!).inSeconds
      : 0;
  final scenarioId = demoState.currentScenario?.id.name ?? 'unknown';
  DemoAnalytics.demoCompleted(
    durationSeconds: duration,
    scenarioId: scenarioId,
  );
}
```

**Step 4: Wire analytics into demo_role_panel.dart**

Add import:
```dart
import '../../data/demo_analytics.dart';
```

In `_switchRole`, at the beginning (after `if (scenario == null) return;`):
```dart
final fromRole = demoState.roleString;
```

After `notifier.switchRole(role);`:
```dart
DemoAnalytics.roleSwitched(
  fromRole: fromRole,
  toRole: roleStr,
);
```

**Step 5: Wire analytics into demo_guardian_compare.dart**

Add import:
```dart
import '../../data/demo_analytics.dart';
```

In the static `show` method, fire event before showing bottom sheet:
```dart
static Future<void> show(BuildContext context) {
  DemoAnalytics.guardianUpgradeViewed();
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const DemoGuardianCompare(),
  );
}
```

**Step 6: Wire analytics into demo_conversion_modal.dart**

Add import:
```dart
import '../../data/demo_analytics.dart';
```

In `_exitAndNavigate`, before clearing state, fire conversion event:
```dart
Future<void> _exitAndNavigate(
    BuildContext context, WidgetRef ref, String route) async {
  final ctaType = route == RoutePaths.authPhone ? 'create_trip' : 'join_code';
  DemoAnalytics.demoConverted(ctaType);
  await _clearDemoState(ref);
  if (context.mounted) {
    Navigator.of(context).pop();
    context.go(route);
  }
}
```

**Step 7: Verify build compiles**

Run: `cd safetrip-mobile && flutter analyze lib/features/demo/`
Expected: No errors

**Step 8: Commit**

```bash
git add safetrip-mobile/lib/features/demo/data/demo_analytics.dart \
  safetrip-mobile/lib/features/demo/presentation/screens/screen_demo_scenario_select.dart \
  safetrip-mobile/lib/features/demo/presentation/screens/screen_demo_complete.dart \
  safetrip-mobile/lib/features/demo/presentation/widgets/demo_role_panel.dart \
  safetrip-mobile/lib/features/demo/presentation/widgets/demo_guardian_compare.dart \
  safetrip-mobile/lib/features/demo/presentation/widgets/demo_conversion_modal.dart
git commit -m "feat(demo): add analytics service with 7 conversion events (DOC-T3-DMO-030 §3.8)"
```

---

### Task 3: Privacy Grade Compare Panel

**Files:**
- Create: `safetrip-mobile/lib/features/demo/presentation/widgets/demo_grade_compare.dart`
- Modify: `safetrip-mobile/lib/features/demo/presentation/widgets/demo_mode_wrapper.dart`

**Step 1: Create the grade comparison panel widget**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/demo_analytics.dart';
import '../../models/demo_scenario.dart';
import '../../providers/demo_state_provider.dart';

/// §3.5: 등급 비교 체험 패널
/// 3개 프라이버시 등급 전환 + 차이 시각화 (5행)
class DemoGradeCompare extends ConsumerWidget {
  const DemoGradeCompare({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const DemoGradeCompare(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final demoState = ref.watch(demoStateProvider);
    final currentGrade = demoState.currentGrade;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radius20),
        ),
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: SafeArea(
        child: SingleChildScrollView(
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
              const SizedBox(height: AppSpacing.lg),

              Text(
                '프라이버시 등급 비교',
                style: AppTypography.titleLarge
                    .copyWith(color: AppColors.textPrimary),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '등급을 바꾸면 위치 공유와 가디언 공유 방식이 달라집니다',
                style: AppTypography.bodyMedium
                    .copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),

              // 3-tab toggle
              Row(
                children: DemoPrivacyGrade.values.map((grade) {
                  final isSelected = grade == currentGrade;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        ref.read(demoStateProvider.notifier).switchGrade(grade);
                        DemoAnalytics.gradeSwitched(_gradeName(grade));
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? _gradeColor(grade).withValues(alpha: 0.12)
                              : AppColors.surfaceVariant,
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radius8),
                          border: isSelected
                              ? Border.all(color: _gradeColor(grade), width: 1.5)
                              : null,
                        ),
                        child: Column(
                          children: [
                            Text(
                              _gradeLabel(grade),
                              style: AppTypography.labelSmall.copyWith(
                                color: isSelected
                                    ? _gradeColor(grade)
                                    : AppColors.textSecondary,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Comparison rows (5 items from §3.5)
              _ComparisonRow(
                label: '위치 공유 범위',
                values: const ['24시간 실시간', '24시간\n(OFF시 저빈도)', '일정 연동\n시간대만'],
                currentGrade: currentGrade,
              ),
              _ComparisonRow(
                label: '가디언 공유',
                values: const ['항상 공유', '항상\n(OFF시 30분 스냅샷)', '스케줄 OFF\n비공유'],
                currentGrade: currentGrade,
              ),
              _ComparisonRow(
                label: '마커 표시',
                values: const ['실시간 갱신', '실시간 갱신', '체크포인트만\n핀 표시'],
                currentGrade: currentGrade,
              ),
              _ComparisonRow(
                label: '가디언 일시 중지',
                values: const ['불가', '최대 12시간', '최대 24시간'],
                currentGrade: currentGrade,
              ),
              _ComparisonRow(
                label: '지오펜스→가디언',
                values: const ['항상 전달', '스케줄 ON\n시만', '전달 안 함'],
                currentGrade: currentGrade,
              ),

              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }

  static String _gradeLabel(DemoPrivacyGrade grade) {
    switch (grade) {
      case DemoPrivacyGrade.safetyFirst:
        return '안전 최우선';
      case DemoPrivacyGrade.standard:
        return '표준';
      case DemoPrivacyGrade.privacyFirst:
        return '프라이버시\n우선';
    }
  }

  static String _gradeName(DemoPrivacyGrade grade) {
    switch (grade) {
      case DemoPrivacyGrade.safetyFirst:
        return 'safety_first';
      case DemoPrivacyGrade.standard:
        return 'standard';
      case DemoPrivacyGrade.privacyFirst:
        return 'privacy_first';
    }
  }

  static Color _gradeColor(DemoPrivacyGrade grade) {
    switch (grade) {
      case DemoPrivacyGrade.safetyFirst:
        return AppColors.privacySafetyFirst;
      case DemoPrivacyGrade.standard:
        return AppColors.privacyStandard;
      case DemoPrivacyGrade.privacyFirst:
        return AppColors.privacyFirst;
    }
  }
}

class _ComparisonRow extends StatelessWidget {
  const _ComparisonRow({
    required this.label,
    required this.values,
    required this.currentGrade,
  });

  final String label;
  final List<String> values; // [safetyFirst, standard, privacyFirst]
  final DemoPrivacyGrade currentGrade;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(AppSpacing.radius8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.textTertiary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              values[currentGrade.index],
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

**Step 2: Add grade compare button to DemoModeWrapper**

In `demo_mode_wrapper.dart`, add import:
```dart
import 'demo_grade_compare.dart';
```

Add a new Layer (after the guardian compare button, before the exit FAB) for grade compare access — this is available to all roles per §4:

```dart
// Layer 4b: 등급 비교 버튼 (전체 역할, §3.5 + §4)
Positioned(
  top: topPadding + (isCaptain ? 66 : 30),
  left: AppSpacing.md,
  child: _GradeCompareButton(
    onTap: () => DemoGradeCompare.show(context),
  ),
),
```

Add the `_GradeCompareButton` widget class at the end of the file:
```dart
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
```

**Step 3: Verify build compiles**

Run: `cd safetrip-mobile && flutter analyze lib/features/demo/`
Expected: No errors

**Step 4: Commit**

```bash
git add safetrip-mobile/lib/features/demo/presentation/widgets/demo_grade_compare.dart \
  safetrip-mobile/lib/features/demo/presentation/widgets/demo_mode_wrapper.dart
git commit -m "feat(demo): add privacy grade comparison panel (DOC-T3-DMO-030 §3.5)"
```

---

### Task 4: Coachmark System

**Files:**
- Create: `safetrip-mobile/lib/features/demo/presentation/widgets/demo_coachmark_data.dart`
- Create: `safetrip-mobile/lib/features/demo/presentation/widgets/demo_coachmark.dart`
- Modify: `safetrip-mobile/lib/features/demo/presentation/widgets/demo_mode_wrapper.dart`

**Step 1: Create coachmark data definitions**

```dart
/// §3.7: Coachmark definitions — text from DOC-T3-DMO-030 table
class CoachmarkDef {
  const CoachmarkDef({
    required this.id,
    required this.text,
    this.arrowDirection = ArrowDirection.up,
  });

  final String id;
  final String text;
  final ArrowDirection arrowDirection;
}

enum ArrowDirection { up, down, left, right }

/// §3.7 texts: Korean P0, English/Japanese P3
const kDemoCoachmarks = [
  CoachmarkDef(
    id: 'map_tab',
    text: '멤버들의 실시간 위치가 지도에 표시됩니다.\n마커를 탭하면 멤버 정보를 확인할 수 있어요.',
    arrowDirection: ArrowDirection.down,
  ),
  CoachmarkDef(
    id: 'role_panel',
    text: '역할을 바꿔가며 각 역할의 기능 차이를 체험해 보세요.',
    arrowDirection: ArrowDirection.right,
  ),
  CoachmarkDef(
    id: 'guardian_compare',
    text: '무료·유료 가디언의 차이를 직접 비교해 보세요.\n실제 앱에서는 1,900원/여행으로 추가 연결 가능합니다.',
    arrowDirection: ArrowDirection.left,
  ),
  CoachmarkDef(
    id: 'time_slider',
    text: '슬라이더를 움직여 여행 전·중·후 시점을 체험해 보세요.\n여행은 최대 15일까지 설정 가능합니다.',
    arrowDirection: ArrowDirection.down,
  ),
  CoachmarkDef(
    id: 'sos_button',
    text: 'SOS 버튼은 긴급 상황 시 전체 멤버와 가디언에게 즉시 알림을 보냅니다.',
    arrowDirection: ArrowDirection.down,
  ),
  CoachmarkDef(
    id: 'grade_compare',
    text: '프라이버시 등급을 바꾸면 위치 공유 범위와 가디언 공유 방식이 달라집니다.',
    arrowDirection: ArrowDirection.left,
  ),
];
```

**Step 2: Create the coachmark overlay widget**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../providers/demo_state_provider.dart';
import 'demo_coachmark_data.dart';

/// §3.7: Coachmark overlay with tooltip, arrow, and semi-transparent backdrop.
/// Shows once per coachmark per demo session. "Skip All" dismisses all.
class DemoCoachmarkOverlay extends ConsumerWidget {
  const DemoCoachmarkOverlay({
    super.key,
    required this.coachmark,
    required this.targetRect,
    required this.onDismiss,
    required this.onSkipAll,
  });

  final CoachmarkDef coachmark;
  final Rect targetRect;
  final VoidCallback onDismiss;
  final VoidCallback onSkipAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenSize = MediaQuery.of(context).size;

    // Position tooltip relative to target
    final tooltipTop = coachmark.arrowDirection == ArrowDirection.down
        ? targetRect.top - 100
        : targetRect.bottom + 12;

    final tooltipLeft = (targetRect.center.dx - 140).clamp(16.0, screenSize.width - 296);

    return GestureDetector(
      onTap: () {
        ref.read(demoStateProvider.notifier).markCoachmarkViewed(coachmark.id);
        onDismiss();
      },
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            // Semi-transparent backdrop with cutout
            CustomPaint(
              size: screenSize,
              painter: _BackdropPainter(targetRect: targetRect),
            ),

            // Tooltip bubble
            Positioned(
              top: tooltipTop,
              left: tooltipLeft,
              child: Container(
                width: 280,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppSpacing.radius12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      coachmark.text,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textPrimary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          onTap: () {
                            // Mark all as viewed
                            final notifier = ref.read(demoStateProvider.notifier);
                            for (final cm in kDemoCoachmarks) {
                              notifier.markCoachmarkViewed(cm.id);
                            }
                            onSkipAll();
                          },
                          child: Text(
                            '모두 건너뛰기',
                            style: AppTypography.labelSmall.copyWith(
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryTeal,
                            borderRadius:
                                BorderRadius.circular(AppSpacing.radiusFull),
                          ),
                          child: Text(
                            '확인',
                            style: AppTypography.labelSmall.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Paints a semi-transparent overlay with a rounded-rect cutout around the target
class _BackdropPainter extends CustomPainter {
  _BackdropPainter({required this.targetRect});
  final Rect targetRect;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withValues(alpha: 0.5);
    final fullRect = Rect.fromLTWH(0, 0, size.width, size.height);

    // Draw full overlay
    canvas.drawRect(fullRect, paint);

    // Cut out the target area
    final clearPaint = Paint()..blendMode = BlendMode.clear;
    final rrect = RRect.fromRectAndRadius(
      targetRect.inflate(4),
      const Radius.circular(8),
    );
    canvas.drawRRect(rrect, clearPaint);
  }

  @override
  bool shouldRepaint(covariant _BackdropPainter old) =>
      old.targetRect != targetRect;
}
```

**Step 3: Add coachmark trigger to DemoModeWrapper**

In `demo_mode_wrapper.dart`, add coachmark state and trigger logic.

Add field to `_DemoModeWrapperState`:
```dart
OverlayEntry? _coachmarkOverlay;
final GlobalKey _mapAreaKey = GlobalKey();
```

Add a method to show a coachmark:
```dart
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
```

In `_startEventSimulator`, after starting the simulator, trigger the first coachmark (map_tab) with a delay:
```dart
// Show first coachmark after demo loads
Future.delayed(const Duration(seconds: 1), () {
  if (!mounted) return;
  final demoState = ref.read(demoStateProvider);
  if (!demoState.viewedCoachmarks.contains('map_tab')) {
    final screenSize = MediaQuery.of(context).size;
    // Target the map area (center of screen)
    final mapRect = Rect.fromCenter(
      center: Offset(screenSize.width / 2, screenSize.height * 0.35),
      width: screenSize.width - 32,
      height: 200,
    );
    _showCoachmark(kDemoCoachmarks[0], mapRect);
  }
});
```

Add cleanup in dispose:
```dart
@override
void dispose() {
  _coachmarkOverlay?.remove();
  _eventSimulator?.dispose();
  super.dispose();
}
```

Add imports:
```dart
import 'demo_coachmark.dart';
import 'demo_coachmark_data.dart';
```

**Step 4: Verify build compiles**

Run: `cd safetrip-mobile && flutter analyze lib/features/demo/`
Expected: No errors

**Step 5: Commit**

```bash
git add safetrip-mobile/lib/features/demo/presentation/widgets/demo_coachmark_data.dart \
  safetrip-mobile/lib/features/demo/presentation/widgets/demo_coachmark.dart \
  safetrip-mobile/lib/features/demo/presentation/widgets/demo_mode_wrapper.dart
git commit -m "feat(demo): add coachmark overlay system with 6 tooltips (DOC-T3-DMO-030 §3.7)"
```

---

### Task 5: Memory Optimization Verification

**Files:**
- No new files; verification only

**Step 1: Check JSON file sizes**

Run: `ls -la safetrip-mobile/assets/demo/scenario_s*.json`
Expected: Each file < 200KB (per §3.9 requirement)

**Step 2: Verify demo wrapper dispose cleanup**

Read `demo_mode_wrapper.dart` dispose method and confirm:
- `_eventSimulator?.dispose()` is called
- `_coachmarkOverlay?.remove()` is called
- No image cache references to clean (current implementation uses icons, not images)

**Step 3: Verify no profile images in assets**

Run: `ls safetrip-mobile/assets/demo/demo_profiles/ 2>/dev/null || echo "No profile images directory — OK"`
Expected: "No profile images directory — OK" (current impl uses Material Icons for avatars)

**Step 4: Commit (no changes expected, skip if nothing changed)**

---

### Task 6: Full Static Analysis & §10 Checklist Verification

**Step 1: Run flutter analyze on entire demo feature**

Run: `cd safetrip-mobile && flutter analyze lib/features/demo/`
Expected: No errors, no warnings

**Step 2: Verify §10 checklist (12 items)**

Manually verify each item from DOC-T3-DMO-030 §10:
1. Demo badge on all screens → `demo_badge.dart` + `demo_mode_wrapper.dart` Layer 1
2. No server API (Analytics exception) → All code is local JSON + debugPrint analytics
3. 3 scenarios work → `screen_demo_scenario_select.dart` with s1/s2/s3
4. 4 roles → `demo_role_panel.dart` with captain/crewChief/crew/guardian
5. 15-day limit → `demo_time_slider.dart` with haptic at D+15
6. Guardian free/paid → `demo_guardian_compare.dart` with ₩1,900
7. 3-grade compare → NEW `demo_grade_compare.dart`
8. Conversion modal → `demo_conversion_modal.dart` with 3 CTAs
9. Data isolation → SharedPreferences only, cleared on exit
10. Offline capable → `assets/demo/` bundled
11. Business principle refs → Document references §02.3, §04, §09.3
12. Coachmarks 1st-visit → NEW `demo_coachmark.dart` with viewedCoachmarks set

**Step 3: Final commit with all verified changes**

```bash
git add -A
git commit -m "feat(demo): complete Phase 1~3 demo tour implementation (DOC-T3-DMO-030 v2.1)"
```
