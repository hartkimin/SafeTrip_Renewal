import 'package:flutter_test/flutter_test.dart';
import 'package:safetrip_mobile/features/main/providers/main_screen_provider.dart';
import 'package:safetrip_mobile/screens/main/navigation/bottom_navigation_bar.dart';

void main() {
  late MainScreenNotifier notifier;

  setUp(() {
    notifier = MainScreenNotifier();
  });

  // ----------------------------------------------------------------
  // Scenario 1: 5-level snap point traversal (ascending & descending)
  // ----------------------------------------------------------------
  test('Scenario 1: 5-level snap point ascending then descending', () {
    // Ascending
    notifier.setSheetLevel(BottomSheetLevel.collapsed);
    expect(notifier.state.sheetLevel, BottomSheetLevel.collapsed);

    notifier.setSheetLevel(BottomSheetLevel.peek);
    expect(notifier.state.sheetLevel, BottomSheetLevel.peek);

    notifier.setSheetLevel(BottomSheetLevel.half);
    expect(notifier.state.sheetLevel, BottomSheetLevel.half);

    notifier.setSheetLevel(BottomSheetLevel.expanded);
    expect(notifier.state.sheetLevel, BottomSheetLevel.expanded);

    notifier.setSheetLevel(BottomSheetLevel.full);
    expect(notifier.state.sheetLevel, BottomSheetLevel.full);

    // Descending
    notifier.setSheetLevel(BottomSheetLevel.expanded);
    expect(notifier.state.sheetLevel, BottomSheetLevel.expanded);

    notifier.setSheetLevel(BottomSheetLevel.half);
    expect(notifier.state.sheetLevel, BottomSheetLevel.half);

    notifier.setSheetLevel(BottomSheetLevel.peek);
    expect(notifier.state.sheetLevel, BottomSheetLevel.peek);

    notifier.setSheetLevel(BottomSheetLevel.collapsed);
    expect(notifier.state.sheetLevel, BottomSheetLevel.collapsed);
  });

  // ----------------------------------------------------------------
  // Scenario 2: Same-tab re-tap (S4.4)
  // ----------------------------------------------------------------
  test('Scenario 2: same-tab re-tap toggles height per S4.4', () {
    // collapsed -> half
    notifier.setSheetLevel(BottomSheetLevel.collapsed);
    final r1 = notifier.resolveHeightForSameTabTap();
    expect(r1, BottomSheetLevel.half);

    // half -> collapsed
    notifier.setSheetLevel(BottomSheetLevel.half);
    final r2 = notifier.resolveHeightForSameTabTap();
    expect(r2, BottomSheetLevel.collapsed);

    // full -> half
    notifier.setSheetLevel(BottomSheetLevel.full);
    final r3 = notifier.resolveHeightForSameTabTap();
    expect(r3, BottomSheetLevel.half);

    // expanded -> half
    notifier.setSheetLevel(BottomSheetLevel.expanded);
    final r4 = notifier.resolveHeightForSameTabTap();
    expect(r4, BottomSheetLevel.half);

    // peek -> collapsed
    notifier.setSheetLevel(BottomSheetLevel.peek);
    final r5 = notifier.resolveHeightForSameTabTap();
    expect(r5, BottomSheetLevel.collapsed);
  });

  // ----------------------------------------------------------------
  // Scenario 3: Tab switch height resolution (S5.1, S7.2)
  // ----------------------------------------------------------------
  test('Scenario 3: tab switch resolves height per S5.1 and S7.2', () {
    // collapsed -> trip tab: collapsed < trip min(peek) => default half
    notifier.setSheetLevel(BottomSheetLevel.collapsed);
    notifier.setCurrentTab(BottomTab.trip);
    final r1 = notifier.resolveHeightForTab(BottomTab.trip);
    expect(r1, BottomSheetLevel.half);

    // collapsed -> member tab: collapsed < member min(peek) => default peek
    notifier.setSheetLevel(BottomSheetLevel.collapsed);
    final r2 = notifier.resolveHeightForTab(BottomTab.member);
    expect(r2, BottomSheetLevel.peek);

    // collapsed -> chat tab: collapsed < chat min(expanded) => default expanded
    notifier.setSheetLevel(BottomSheetLevel.collapsed);
    final r3 = notifier.resolveHeightForTab(BottomTab.chat);
    expect(r3, BottomSheetLevel.expanded);

    // full -> member tab: full >= member min(peek) => keep full
    notifier.setSheetLevel(BottomSheetLevel.full);
    final r4 = notifier.resolveHeightForTab(BottomTab.member);
    expect(r4, BottomSheetLevel.full);

    // half -> chat tab: half < chat min(expanded) => default expanded
    notifier.setSheetLevel(BottomSheetLevel.half);
    final r5 = notifier.resolveHeightForTab(BottomTab.chat);
    expect(r5, BottomSheetLevel.expanded);

    // expanded -> guide tab: expanded >= guide min(peek) => keep expanded
    notifier.setSheetLevel(BottomSheetLevel.expanded);
    final r6 = notifier.resolveHeightForTab(BottomTab.guide);
    expect(r6, BottomSheetLevel.expanded);
  });

  // ----------------------------------------------------------------
  // Scenario 4: Keyboard show/hide (S6)
  // ----------------------------------------------------------------
  test('Scenario 4: keyboard show saves level, hide restores it', () {
    // Non-chat tab: half -> keyboard -> full -> hide -> half
    notifier.setCurrentTab(BottomTab.trip);
    notifier.setSheetLevel(BottomSheetLevel.half);

    final showResult = notifier.onKeyboardShow();
    expect(showResult, BottomSheetLevel.full);
    expect(notifier.state.sheetLevel, BottomSheetLevel.full);
    expect(notifier.state.preKeyboardLevel, BottomSheetLevel.half);

    final hideResult = notifier.onKeyboardHide();
    expect(hideResult, BottomSheetLevel.half);
    expect(notifier.state.sheetLevel, BottomSheetLevel.half);
    expect(notifier.state.preKeyboardLevel, isNull);

    // Chat tab: expanded -> keyboard -> full -> hide -> expanded (S6.2)
    notifier.setCurrentTab(BottomTab.chat);
    notifier.setSheetLevel(BottomSheetLevel.expanded);

    final showResult2 = notifier.onKeyboardShow();
    expect(showResult2, BottomSheetLevel.full);
    expect(notifier.state.sheetLevel, BottomSheetLevel.full);

    final hideResult2 = notifier.onKeyboardHide();
    expect(hideResult2, BottomSheetLevel.expanded);
    expect(notifier.state.sheetLevel, BottomSheetLevel.expanded);
  });

  // ----------------------------------------------------------------
  // Scenario 5: SOS activate/deactivate (S10)
  // ----------------------------------------------------------------
  test('Scenario 5: SOS locks to collapsed, deactivate restores peek', () {
    // half -> activateSos -> collapsed
    notifier.setSheetLevel(BottomSheetLevel.half);
    notifier.activateSos();
    expect(notifier.state.sheetLevel, BottomSheetLevel.collapsed);
    expect(notifier.state.isSosActive, isTrue);

    // Attempt setSheetLevel(full) while SOS active -> stays collapsed
    final result = notifier.setSheetLevel(BottomSheetLevel.full);
    expect(result, BottomSheetLevel.collapsed);
    expect(notifier.state.sheetLevel, BottomSheetLevel.collapsed);

    // deactivateSos -> peek
    notifier.deactivateSos();
    expect(notifier.state.sheetLevel, BottomSheetLevel.peek);
    expect(notifier.state.isSosActive, isFalse);

    // After SOS deactivation, setSheetLevel works normally
    notifier.setSheetLevel(BottomSheetLevel.half);
    expect(notifier.state.sheetLevel, BottomSheetLevel.half);
  });

  // ----------------------------------------------------------------
  // Scenario 6: No-trip state (S8.2)
  // ----------------------------------------------------------------
  test('Scenario 6: no-trip locks to collapsed, clearing unlocks', () {
    // setNoTrip(true) -> collapsed
    notifier.setNoTrip(true);
    expect(notifier.state.sheetLevel, BottomSheetLevel.collapsed);
    expect(notifier.state.isNoTrip, isTrue);

    // Attempt setSheetLevel(full) while no-trip -> stays collapsed
    final result = notifier.setSheetLevel(BottomSheetLevel.full);
    expect(result, BottomSheetLevel.collapsed);
    expect(notifier.state.sheetLevel, BottomSheetLevel.collapsed);

    // setNoTrip(false) -> unlock
    notifier.setNoTrip(false);
    expect(notifier.state.isNoTrip, isFalse);

    // Now setSheetLevel works
    notifier.setSheetLevel(BottomSheetLevel.half);
    expect(notifier.state.sheetLevel, BottomSheetLevel.half);
  });

  // ----------------------------------------------------------------
  // Scenario 7: Two-finger swipe -- programmatic collapsed->full
  // ----------------------------------------------------------------
  test('Scenario 7: programmatic collapsed to full (no block)', () {
    notifier.setSheetLevel(BottomSheetLevel.collapsed);
    expect(notifier.state.sheetLevel, BottomSheetLevel.collapsed);

    final result = notifier.setSheetLevel(BottomSheetLevel.full);
    expect(result, BottomSheetLevel.full);
    expect(notifier.state.sheetLevel, BottomSheetLevel.full);
  });

  // ----------------------------------------------------------------
  // Scenario 8: Fast flick -- provider allows full->collapsed
  // ----------------------------------------------------------------
  test('Scenario 8: fast flick full to collapsed (no block)', () {
    notifier.setSheetLevel(BottomSheetLevel.full);
    expect(notifier.state.sheetLevel, BottomSheetLevel.full);

    final result = notifier.setSheetLevel(BottomSheetLevel.collapsed);
    expect(result, BottomSheetLevel.collapsed);
    expect(notifier.state.sheetLevel, BottomSheetLevel.collapsed);
  });

  // ----------------------------------------------------------------
  // Scenario 9: Member detail view enter/exit (S7.4)
  // ----------------------------------------------------------------
  test('Scenario 9: detail view saves level, exit restores', () {
    // peek -> enterDetailView -> full (preDetailLevel=peek) -> exitDetailView -> peek
    notifier.setSheetLevel(BottomSheetLevel.peek);
    final enterResult = notifier.enterDetailView();
    expect(enterResult, BottomSheetLevel.full);
    expect(notifier.state.sheetLevel, BottomSheetLevel.full);
    expect(notifier.state.preDetailLevel, BottomSheetLevel.peek);

    final exitResult = notifier.exitDetailView();
    expect(exitResult, BottomSheetLevel.peek);
    expect(notifier.state.sheetLevel, BottomSheetLevel.peek);
    expect(notifier.state.preDetailLevel, isNull);

    // expanded -> enter -> full -> exit -> expanded
    notifier.setSheetLevel(BottomSheetLevel.expanded);
    final enterResult2 = notifier.enterDetailView();
    expect(enterResult2, BottomSheetLevel.full);
    expect(notifier.state.preDetailLevel, BottomSheetLevel.expanded);

    final exitResult2 = notifier.exitDetailView();
    expect(exitResult2, BottomSheetLevel.expanded);
    expect(notifier.state.sheetLevel, BottomSheetLevel.expanded);
  });

  // ----------------------------------------------------------------
  // Scenario 10: Back navigation (PopScope) -- isFullOrExpanded
  // ----------------------------------------------------------------
  test('Scenario 10: back navigation reduces or exits', () {
    // full: isFullOrExpanded -> setSheetLevel(half)
    notifier.setSheetLevel(BottomSheetLevel.full);
    final isFullOrExpanded1 = notifier.state.sheetLevel ==
            BottomSheetLevel.full ||
        notifier.state.sheetLevel == BottomSheetLevel.expanded;
    expect(isFullOrExpanded1, isTrue);
    notifier.setSheetLevel(BottomSheetLevel.half);
    expect(notifier.state.sheetLevel, BottomSheetLevel.half);

    // expanded: isFullOrExpanded -> setSheetLevel(half)
    notifier.setSheetLevel(BottomSheetLevel.expanded);
    final isFullOrExpanded2 = notifier.state.sheetLevel ==
            BottomSheetLevel.full ||
        notifier.state.sheetLevel == BottomSheetLevel.expanded;
    expect(isFullOrExpanded2, isTrue);
    notifier.setSheetLevel(BottomSheetLevel.half);
    expect(notifier.state.sheetLevel, BottomSheetLevel.half);

    // half: not full/expanded -> should exit
    notifier.setSheetLevel(BottomSheetLevel.half);
    final shouldExit = notifier.state.sheetLevel !=
            BottomSheetLevel.full &&
        notifier.state.sheetLevel != BottomSheetLevel.expanded;
    expect(shouldExit, isTrue);
  });
}
