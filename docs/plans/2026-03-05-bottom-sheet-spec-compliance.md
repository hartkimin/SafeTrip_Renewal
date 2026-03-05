# Bottom Sheet Spec Compliance Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fix 4 discrepancies between the bottom sheet spec (`Master_docs/11_T2_바텀시트_동작_규칙.md` v2.0) and the current Flutter implementation so all P0+P1 rules are satisfied, plus §3.3 transition constraints and §7.4 detail-view transitions.

**Architecture:** Layered edits to the existing Riverpod state machine (`MainScreenNotifier`), the `SnappingBottomSheet` wrapper, and `screen_main.dart` UI. No new packages. No structural changes — we extend the existing patterns (state fields, copy-with, callbacks).

**Tech Stack:** Flutter, Riverpod (StateNotifier), DraggableScrollableSheet, go_router

---

### Task 1: Fix animation timing for tab tap (§3.1)

**Files:**
- Modify: `safetrip-mobile/lib/screens/main/screen_main.dart:226-247`

The spec says tab-tap from collapsed → half should animate in 250ms easeInOut.
Currently `_handleTabChanged` calls `_animateSheetTo(targetLevel)` which defaults to 200ms.
Fix: when same-tab re-tap resolves to collapsed→half, pass 250ms duration.

**Step 1: Edit `_handleTabChanged` to use spec-correct duration**

In `screen_main.dart`, replace lines 226-247 (`_handleTabChanged` method) with:

```dart
  /// 탭 전환 처리 (§4.4, §5.1, §7.2)
  void _handleTabChanged(BottomTab tab) {
    final mainState = ref.read(mainScreenProvider);
    final notifier = ref.read(mainScreenProvider.notifier);

    // SOS 활성 시 탭 전환 비활성화 (§10.2)
    if (mainState.isSosActive) return;

    // 여행 없음 상태에서 탭 전환 비활성화 (§8.2)
    final tripStatus = ref.read(tripProvider).currentTripStatus;
    if (tripStatus == 'none') return;

    if (tab == _currentTab) {
      // 동일 탭 재탭 (§4.4)
      final previousLevel = mainState.sheetLevel;
      final targetLevel = notifier.resolveHeightForSameTabTap();
      notifier.setSheetLevel(targetLevel);

      // §3.1: collapsed → half 전환은 250ms easeInOut
      final duration = (previousLevel == BottomSheetLevel.collapsed &&
              targetLevel == BottomSheetLevel.half)
          ? const Duration(milliseconds: 250)
          : const Duration(milliseconds: 200);
      _animateSheetTo(targetLevel, duration: duration);
    } else {
      // 다른 탭 전환 (§7.2)
      final targetLevel = notifier.resolveHeightForTab(tab);
      notifier.setCurrentTab(tab);
      notifier.setSheetLevel(targetLevel);
      setState(() => _currentTab = tab);
      _animateSheetTo(targetLevel);
    }
  }
```

**Step 2: Verify the app compiles**

Run: `cd safetrip-mobile && flutter analyze lib/screens/main/screen_main.dart`
Expected: No errors

**Step 3: Commit**

```bash
git add safetrip-mobile/lib/screens/main/screen_main.dart
git commit -m "fix(bottom-sheet): §3.1 tab tap animation 250ms for collapsed→half"
```

---

### Task 2: Add `preDetailLevel` and `isNoTrip` to state (§7.4, §8.2)

**Files:**
- Modify: `safetrip-mobile/lib/features/main/providers/main_screen_provider.dart`

Add the `preDetailLevel` field (for detail view save/restore) and `enterDetailView` / `exitDetailView` methods.
Also add `isNoTrip` logic to `setSheetLevel` to lock at collapsed during no-trip state.

**Step 1: Add field and methods to `MainScreenState` and `MainScreenNotifier`**

In `main_screen_provider.dart`, replace `MainScreenState` class (lines 76-116) with:

```dart
class MainScreenState {
  const MainScreenState({
    this.sheetLevel = BottomSheetLevel.half,
    this.currentTab = BottomTab.trip,
    this.isOnline = true,
    this.unreadCount = 0,
    this.isSosActive = false,
    this.isNoTrip = false,
    this.preKeyboardLevel,
    this.preDetailLevel,
  });

  final BottomSheetLevel sheetLevel;
  final BottomTab currentTab;
  final bool isOnline;
  final int unreadCount;

  /// SOS 발동 상태 (§10 — true이면 collapsed 잠금)
  final bool isSosActive;

  /// 여행 없음 상태 (§8.2 — true이면 collapsed 잠금 + 탭 비활성화)
  final bool isNoTrip;

  /// 키보드 출현 직전 상태 저장 (§6.1 — 키보드 닫힘 시 복원용)
  final BottomSheetLevel? preKeyboardLevel;

  /// 세부 화면 진입 직전 상태 저장 (§7.4 — 뒤로가기 시 복원용)
  final BottomSheetLevel? preDetailLevel;

  MainScreenState copyWith({
    BottomSheetLevel? sheetLevel,
    BottomTab? currentTab,
    bool? isOnline,
    int? unreadCount,
    bool? isSosActive,
    bool? isNoTrip,
    BottomSheetLevel? Function()? preKeyboardLevel,
    BottomSheetLevel? Function()? preDetailLevel,
  }) {
    return MainScreenState(
      sheetLevel: sheetLevel ?? this.sheetLevel,
      currentTab: currentTab ?? this.currentTab,
      isOnline: isOnline ?? this.isOnline,
      unreadCount: unreadCount ?? this.unreadCount,
      isSosActive: isSosActive ?? this.isSosActive,
      isNoTrip: isNoTrip ?? this.isNoTrip,
      preKeyboardLevel: preKeyboardLevel != null
          ? preKeyboardLevel()
          : this.preKeyboardLevel,
      preDetailLevel: preDetailLevel != null
          ? preDetailLevel()
          : this.preDetailLevel,
    );
  }
}
```

**Step 2: Add methods to `MainScreenNotifier`**

In `main_screen_provider.dart`, add these methods inside `MainScreenNotifier` (after the existing `onKeyboardHide` method, before the closing `}`):

```dart
  /// 여행 없음 상태 설정 (§8.2)
  void setNoTrip(bool noTrip) {
    state = state.copyWith(
      isNoTrip: noTrip,
      sheetLevel: noTrip ? BottomSheetLevel.collapsed : state.sheetLevel,
    );
  }

  /// 세부 화면 진입 (§7.4) — 현재 레벨 저장 후 full 전환
  BottomSheetLevel enterDetailView() {
    state = state.copyWith(
      preDetailLevel: () => state.sheetLevel,
      sheetLevel: BottomSheetLevel.full,
    );
    return BottomSheetLevel.full;
  }

  /// 세부 화면 종료 (§7.4) — 이전 레벨로 복원
  BottomSheetLevel exitDetailView() {
    final restored = state.preDetailLevel ?? BottomSheetLevel.half;
    state = state.copyWith(
      sheetLevel: restored,
      preDetailLevel: () => null,
    );
    return restored;
  }
```

**Step 3: Update `setSheetLevel` to respect `isNoTrip`**

Replace lines 123-130 (`setSheetLevel` method) with:

```dart
  BottomSheetLevel setSheetLevel(BottomSheetLevel level) {
    // SOS 활성 시 collapsed 이외 허용 안함 (§10.2)
    if (state.isSosActive && level != BottomSheetLevel.collapsed) {
      return BottomSheetLevel.collapsed;
    }
    // 여행 없음 시 collapsed 이외 허용 안함 (§8.2)
    if (state.isNoTrip && level != BottomSheetLevel.collapsed) {
      return BottomSheetLevel.collapsed;
    }
    state = state.copyWith(sheetLevel: level);
    return level;
  }
```

**Step 4: Verify the file compiles**

Run: `cd safetrip-mobile && flutter analyze lib/features/main/providers/main_screen_provider.dart`
Expected: No errors

**Step 5: Commit**

```bash
git add safetrip-mobile/lib/features/main/providers/main_screen_provider.dart
git commit -m "feat(bottom-sheet): add preDetailLevel, isNoTrip, enterDetailView/exitDetailView to state"
```

---

### Task 3: Implement no-trip state UI (§8.2)

**Files:**
- Modify: `safetrip-mobile/lib/screens/main/screen_main.dart`

When `tripStatus == 'none'`: disable tab bar, disable drag, show "+ 새 여행 만들기" CTA in the bottom sheet content area.

**Step 1: Update `_initializeServices` to set `isNoTrip` state**

In `screen_main.dart`, replace lines 149-157 (inside `_initializeServices`, the `if (mounted)` block) with:

```dart
      if (mounted) {
        // 여행 상태별 초기 높이 적용 (§5.2)
        final tripStatus =
            ref.read(tripProvider).currentTripStatus;
        final initialLevel = initialHeightForTripStatus(tripStatus);
        final notifier = ref.read(mainScreenProvider.notifier);
        notifier.setSheetLevel(initialLevel);

        // §8.2: 여행 없음 상태 설정
        notifier.setNoTrip(tripStatus == 'none');

        _animateSheetTo(initialLevel);

        setState(() => _isInitialLoading = false);
      }
```

**Step 2: Add `_buildNoTripContent` widget method**

Add this method to `_MainScreenState` (after `_buildTabContent`):

```dart
  /// §8.2: 여행 없는 상태에서 표시할 CTA
  Widget _buildNoTripContent() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.luggage_outlined,
              size: 48,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              '아직 여행이 없습니다',
              style: AppTypography.titleMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton.icon(
              onPressed: () => context.push(RoutePaths.tripCreate),
              icon: const Icon(Icons.add),
              label: const Text('새 여행 만들기'),
            ),
          ],
        ),
      ),
    );
  }
```

**Step 3: Update `build` method to handle no-trip state**

In the `build` method, add `isNoTrip` variable after `final showSos` line (line 261):

```dart
    final isNoTrip = tripStatus == 'none';
```

Update the SnappingBottomSheet `isDragEnabled` prop (around line 323) from:
```dart
              isDragEnabled: !mainState.isSosActive, // SOS 잠금 (§10.2)
```
to:
```dart
              isDragEnabled: !mainState.isSosActive && !isNoTrip, // SOS/NoTrip 잠금 (§10.2, §8.2)
```

Update the `builder` inside SnappingBottomSheet (around lines 333-341) from:
```dart
              builder: (context, scrollController) {
                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, animation) {
                    return FadeTransition(opacity: animation, child: child);
                  },
                  child: _buildTabContent(scrollController),
                );
              },
```
to:
```dart
              builder: (context, scrollController) {
                // §8.2: 여행 없음 → CTA만 표시
                if (isNoTrip) {
                  return _buildNoTripContent();
                }
                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, animation) {
                    return FadeTransition(opacity: animation, child: child);
                  },
                  child: _buildTabContent(scrollController),
                );
              },
```

Update the `AppBottomNavigationBar` `isDisabled` prop (around line 353) from:
```dart
                isDisabled: mainState.isSosActive, // SOS 시 탭 전환 비활성화 (§10.2)
```
to:
```dart
                isDisabled: mainState.isSosActive || isNoTrip, // SOS/NoTrip 시 탭 전환 비활성화 (§10.2, §8.2)
```

**Step 4: Add missing imports at top of `screen_main.dart`**

Add after the existing imports (if not already present):

```dart
import '../../core/theme/app_typography.dart';
import '../../router/route_paths.dart';
```

**Step 5: Verify the app compiles**

Run: `cd safetrip-mobile && flutter analyze lib/screens/main/screen_main.dart`
Expected: No errors

**Step 6: Commit**

```bash
git add safetrip-mobile/lib/screens/main/screen_main.dart
git commit -m "feat(bottom-sheet): §8.2 no-trip state with disabled tabs and CTA"
```

---

### Task 4: Add transition constraint — block full↔collapsed direct jumps (§3.3)

**Files:**
- Modify: `safetrip-mobile/lib/screens/main/bottom_sheets/snapping_bottom_sheet.dart`

Track previous level in `_onSizeChanged`. If the user-initiated gesture produces a full↔collapsed direct jump (index distance >= 3), redirect to an intermediate snap point instead.

**Step 1: Add previous level tracking and jump guard**

Replace `_SnappingBottomSheetState` (lines 44-147) with:

```dart
class _SnappingBottomSheetState extends State<SnappingBottomSheet> {
  late final DraggableScrollableController _controller;
  bool _ownsController = false;

  // DraggableScrollableSheet의 snapSizes는 minChildSize/maxChildSize를 제외한 중간값만 받음
  static const _minSize = AppTokens.bottomSheetHeightCollapsed; // 0.10
  static const _maxSize = AppTokens.bottomSheetHeightExpanded; // 1.00
  static const _snapSizes = [
    AppTokens.bottomSheetHeightPeek, // 0.25
    AppTokens.bottomSheetHeightHalf, // 0.50
    AppTokens.bottomSheetHeightTall, // 0.75
  ];

  /// §3.3: 직전 안정 레벨 (전환 제약 검증용)
  BottomSheetLevel _previousStableLevel = BottomSheetLevel.half;

  /// 프로그래밍적 애니메이션 중인지 여부 (코드에서 animateTo 호출 시 true)
  /// true이면 점프 가드를 건너뛴다 (SOS, 탭 전환 등 의도적 점프).
  bool _isProgrammaticMove = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
    } else {
      _controller = DraggableScrollableController();
      _ownsController = true;
    }
    _controller.addListener(_onSizeChanged);
    _previousStableLevel = widget.initialLevel;
  }

  @override
  void dispose() {
    _controller.removeListener(_onSizeChanged);
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _onSizeChanged() {
    if (!_controller.isAttached) return;
    final size = _controller.size;
    final level = BottomSheetLevelExt.fromFraction(size);

    // §3.3: 프로그래밍적 이동이 아닌 사용자 제스처에 의한 직접 점프 검증
    if (!_isProgrammaticMove && widget.isDragEnabled) {
      final distance = (level.index - _previousStableLevel.index).abs();
      if (distance >= 3) {
        // full→collapsed or collapsed→full 직접 점프 감지 — 중간 레벨로 리다이렉트
        final redirectLevel = level.index > _previousStableLevel.index
            ? BottomSheetLevel.peek // collapsed→full 시도 → peek로 제한
            : BottomSheetLevel.expanded; // full→collapsed 시도 → expanded로 제한

        // 비동기로 리다이렉트 (현재 리스너 콜백 내에서 animateTo 직접 호출 방지)
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_controller.isAttached) {
            _isProgrammaticMove = true;
            _controller.animateTo(
              redirectLevel.fraction,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
            Future.delayed(const Duration(milliseconds: 350), () {
              _isProgrammaticMove = false;
            });
          }
        });

        widget.onLevelChanged?.call(redirectLevel);
        _previousStableLevel = redirectLevel;
        return;
      }
    }

    _previousStableLevel = level;
    widget.onLevelChanged?.call(level);
  }

  /// 외부에서 animateTo 호출 시 점프 가드 우회를 위해
  /// controller를 직접 사용하는 대신 이 플래그를 설정하는 방법이 필요.
  /// screen_main.dart에서 _sheetController.animateTo를 호출하기 직전에
  /// 이 위젯의 markProgrammaticMove()를 호출해야 한다.
  /// → 대안: onLevelChanged 콜백 반환값 기반으로 처리하므로 현재 구현에서는
  ///   controller.animateTo() 호출 시 _isProgrammaticMove = true가 자동 설정되지 않는다.
  ///   이를 해결하기 위해 screen_main.dart의 _animateSheetTo에서 콜백을 추가한다.

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      controller: _controller,
      initialChildSize: widget.initialLevel.fraction,
      minChildSize: _minSize,
      maxChildSize: _maxSize,
      snap: true,
      snapSizes: _snapSizes,
      snapAnimationDuration: const Duration(milliseconds: 300),
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppSpacing.radius24),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 10,
                offset: Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            children: [
              // 드래그 핸들 — isDragEnabled=false일 때도 시각적 핸들은 유지 (§10.2)
              GestureDetector(
                // SOS 잠금 시 드래그를 흡수하여 무효화
                onVerticalDragUpdate:
                    widget.isDragEnabled ? null : (_) {},
                child: Container(
                  height: 32,
                  width: double.infinity,
                  alignment: Alignment.center,
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.outline,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              // 콘텐츠
              Expanded(
                child: widget.isDragEnabled
                    ? widget.builder(context, scrollController)
                    : IgnorePointer(
                        // SOS 잠금 시 내부 스크롤도 비활성화
                        ignoring: true,
                        child: widget.builder(context, scrollController),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
```

**Step 2: Add programmatic-move flag callback to SnappingBottomSheet**

Add a new callback parameter to `SnappingBottomSheet` widget. Replace the constructor and fields (lines 14-22) with:

```dart
class SnappingBottomSheet extends StatefulWidget {
  const SnappingBottomSheet({
    super.key,
    required this.builder,
    this.controller,
    this.initialLevel = BottomSheetLevel.half,
    this.onLevelChanged,
    this.isDragEnabled = true,
    this.onCreated,
  });

  /// 시트 내부 콘텐츠 빌더. [ScrollController]를 반드시 ListView 등에 연결해야 한다.
  final Widget Function(BuildContext context, ScrollController controller)
      builder;

  /// 외부에서 주입 가능한 DraggableScrollableController (§3, §10 제어용)
  final DraggableScrollableController? controller;

  /// 초기 시트 레벨
  final BottomSheetLevel initialLevel;

  /// 레벨 변경 콜백
  final ValueChanged<BottomSheetLevel>? onLevelChanged;

  /// 드래그 활성화 여부 (SOS 발동 시 false — §10.2)
  final bool isDragEnabled;

  /// 시트 상태 생성 후 콜백 — 외부에서 programmatic move 표시 기능 접근용
  final void Function(void Function() markProgrammatic)? onCreated;
```

Then add `markProgrammaticMove` method and call `onCreated` from `initState`:

Add to `_SnappingBottomSheetState.initState`, after `_previousStableLevel = widget.initialLevel;`:

```dart
    widget.onCreated?.call(_markProgrammaticMove);
```

Add the method to `_SnappingBottomSheetState`:

```dart
  void _markProgrammaticMove() {
    _isProgrammaticMove = true;
    Future.delayed(const Duration(milliseconds: 350), () {
      _isProgrammaticMove = false;
    });
  }
```

**Step 3: Update `screen_main.dart` to use the programmatic-move flag**

Add a field to `_MainScreenState`:

```dart
  /// §3.3: 프로그래밍적 시트 이동 시 점프 가드 우회 콜백
  void Function()? _markSheetProgrammatic;
```

Update the `SnappingBottomSheet` widget in `build()` to pass `onCreated`:

```dart
            SnappingBottomSheet(
              controller: _sheetController,
              initialLevel: BottomSheetLevel.half,
              isDragEnabled: !mainState.isSosActive && !isNoTrip,
              onCreated: (markFn) => _markSheetProgrammatic = markFn,
```

Update `_animateSheetTo` to call the flag before animating:

```dart
  void _animateSheetTo(
    BottomSheetLevel level, {
    Duration duration = const Duration(milliseconds: 200),
    Curve curve = Curves.easeInOut,
  }) {
    if (!_sheetController.isAttached) return;
    _markSheetProgrammatic?.call(); // §3.3: 점프 가드 우회
    _sheetController.animateTo(
      level.fraction,
      duration: duration,
      curve: curve,
    );
  }
```

**Step 4: Verify the app compiles**

Run: `cd safetrip-mobile && flutter analyze lib/screens/main/bottom_sheets/snapping_bottom_sheet.dart lib/screens/main/screen_main.dart`
Expected: No errors

**Step 5: Commit**

```bash
git add safetrip-mobile/lib/screens/main/bottom_sheets/snapping_bottom_sheet.dart safetrip-mobile/lib/screens/main/screen_main.dart
git commit -m "feat(bottom-sheet): §3.3 block full↔collapsed direct jumps with post-hoc guard"
```

---

### Task 5: Add two-finger swipe gesture for collapsed→full (§3.3)

**Files:**
- Modify: `safetrip-mobile/lib/screens/main/screen_main.dart`

Wrap the sheet area with a listener that detects two-finger vertical swipes. When the sheet is at collapsed and a two-finger up swipe is detected, animate directly to full.

**Step 1: Add two-finger gesture state variables**

Add to `_MainScreenState` fields (after `_sosUserName`):

```dart
  /// §3.3: 두 손가락 제스처 감지용
  int _pointerCount = 0;
  double? _twoFingerStartY;
```

**Step 2: Add gesture detection methods**

Add to `_MainScreenState`:

```dart
  /// §3.3: 포인터 다운 — 동시 터치 수 추적
  void _onPointerDown(PointerDownEvent event) {
    _pointerCount++;
    if (_pointerCount == 2) {
      _twoFingerStartY = event.position.dy;
    }
  }

  /// §3.3: 포인터 업 — 두 손가락 위 스와이프 판정
  void _onPointerUp(PointerUpEvent event) {
    if (_pointerCount == 2 && _twoFingerStartY != null) {
      final deltaY = event.position.dy - _twoFingerStartY!;
      final mainState = ref.read(mainScreenProvider);

      // 위로 스와이프 (deltaY < -100) + collapsed 상태 → full로 직접 전환
      if (deltaY < -100 &&
          mainState.sheetLevel == BottomSheetLevel.collapsed &&
          !mainState.isSosActive &&
          !mainState.isNoTrip) {
        final notifier = ref.read(mainScreenProvider.notifier);
        notifier.setSheetLevel(BottomSheetLevel.full);
        _animateSheetTo(BottomSheetLevel.full,
            duration: const Duration(milliseconds: 300));
      }
    }
    _pointerCount--;
    if (_pointerCount <= 0) {
      _pointerCount = 0;
      _twoFingerStartY = null;
    }
  }
```

**Step 3: Wrap the Stack in Listener for pointer events**

In the `build` method, wrap the `Stack` with a `Listener` widget. Change:

```dart
      child: Scaffold(
        body: Stack(
```

to:

```dart
      child: Scaffold(
        body: Listener(
          onPointerDown: _onPointerDown,
          onPointerUp: _onPointerUp,
          child: Stack(
```

And add the corresponding closing parenthesis. After the Stack's closing `],` `)` on what is currently around line 440, add another `)` to close the `Listener`:

Change:
```dart
          ],
        ),
      ),
    );
```
to:
```dart
            ],
          ),
        ),
      ),
    );
```

**Step 4: Verify the app compiles**

Run: `cd safetrip-mobile && flutter analyze lib/screens/main/screen_main.dart`
Expected: No errors

**Step 5: Commit**

```bash
git add safetrip-mobile/lib/screens/main/screen_main.dart
git commit -m "feat(bottom-sheet): §3.3 two-finger swipe collapsed→full gesture"
```

---

### Task 6: Implement detail view transitions for Member tab (§7.4)

**Files:**
- Modify: `safetrip-mobile/lib/screens/main/bottom_sheets/bottom_sheet_2_member.dart`
- Modify: `safetrip-mobile/lib/screens/main/screen_main.dart`

When a member card is tapped (detail view entry), animate bottom sheet to full.
When the back button is tapped (exit detail), restore previous level.

**Step 1: Add callbacks to BottomSheetMember**

Replace the `BottomSheetMember` class definition (lines 10-14) with:

```dart
class BottomSheetMember extends StatefulWidget {
  const BottomSheetMember({
    super.key,
    required this.scrollController,
    this.onEnterDetail,
    this.onExitDetail,
  });

  final ScrollController scrollController;

  /// §7.4: 세부 화면 진입 시 호출 (바텀시트 → full)
  final VoidCallback? onEnterDetail;

  /// §7.4: 세부 화면 종료 시 호출 (바텀시트 → 이전 레벨 복원)
  final VoidCallback? onExitDetail;
```

**Step 2: Call the callbacks on member card tap and back button**

Replace the `onTap` in member list tile (line 50) from:
```dart
          onTap: () => setState(() => _selectedUserId = 'user_$index'),
```
to:
```dart
          onTap: () {
            setState(() => _selectedUserId = 'user_$index');
            widget.onEnterDetail?.call(); // §7.4
          },
```

Replace the back button `onPressed` in user timeline (line 65) from:
```dart
                onPressed: () => setState(() => _selectedUserId = null),
```
to:
```dart
                onPressed: () {
                  setState(() => _selectedUserId = null);
                  widget.onExitDetail?.call(); // §7.4
                },
```

**Step 3: Wire callbacks in `screen_main.dart`**

In `_buildTabContent`, update the `BottomTab.member` case from:

```dart
      case BottomTab.member:
        return BottomSheetMember(
          key: const ValueKey('tab_member'),
          scrollController: scrollController,
        );
```

to:

```dart
      case BottomTab.member:
        return BottomSheetMember(
          key: const ValueKey('tab_member'),
          scrollController: scrollController,
          onEnterDetail: () {
            // §7.4: 세부 화면 진입 → full
            final target =
                ref.read(mainScreenProvider.notifier).enterDetailView();
            _animateSheetTo(target, duration: const Duration(milliseconds: 250));
          },
          onExitDetail: () {
            // §7.4: 세부 화면 종료 → 이전 레벨 복원
            final target =
                ref.read(mainScreenProvider.notifier).exitDetailView();
            _animateSheetTo(target, duration: const Duration(milliseconds: 250));
          },
        );
```

**Step 4: Verify the app compiles**

Run: `cd safetrip-mobile && flutter analyze lib/screens/main/bottom_sheets/bottom_sheet_2_member.dart lib/screens/main/screen_main.dart`
Expected: No errors

**Step 5: Commit**

```bash
git add safetrip-mobile/lib/screens/main/bottom_sheets/bottom_sheet_2_member.dart safetrip-mobile/lib/screens/main/screen_main.dart
git commit -m "feat(bottom-sheet): §7.4 detail view transitions for Member tab"
```

---

### Task 7: Final integration verification

**Files:** All modified files

**Step 1: Run full analysis**

Run: `cd safetrip-mobile && flutter analyze`
Expected: No errors in modified files

**Step 2: Verify build succeeds**

Run: `cd safetrip-mobile && flutter build apk --debug 2>&1 | tail -5`
Expected: Build succeeds

**Step 3: Commit design document**

```bash
git add docs/plans/2026-03-05-bottom-sheet-spec-compliance-design.md docs/plans/2026-03-05-bottom-sheet-spec-compliance.md
git commit -m "docs: add bottom sheet spec compliance design and plan"
```
