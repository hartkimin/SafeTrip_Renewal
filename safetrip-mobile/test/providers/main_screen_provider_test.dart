import 'package:flutter_test/flutter_test.dart';
import 'package:safetrip_mobile/features/main/providers/main_screen_provider.dart';
import 'package:safetrip_mobile/screens/main/navigation/bottom_navigation_bar.dart';

void main() {
  late MainScreenNotifier notifier;

  setUp(() {
    notifier = MainScreenNotifier();
  });

  // ---------------------------------------------------------------------------
  // 1. S2 5-level state machine
  // ---------------------------------------------------------------------------
  group('S2 5-level state machine', () {
    test('initial state is half', () {
      expect(notifier.state.sheetLevel, BottomSheetLevel.half);
    });

    test('all levels can be set', () {
      for (final level in BottomSheetLevel.values) {
        final result = notifier.setSheetLevel(level);
        expect(result, level);
        expect(notifier.state.sheetLevel, level);
      }
    });
  });

  // ---------------------------------------------------------------------------
  // 2. S4.4 same-tab re-tap
  // ---------------------------------------------------------------------------
  group('S4.4 same-tab re-tap', () {
    test('collapsed -> half', () {
      notifier.setSheetLevel(BottomSheetLevel.collapsed);
      expect(notifier.resolveHeightForSameTabTap(), BottomSheetLevel.half);
    });

    test('peek -> collapsed', () {
      notifier.setSheetLevel(BottomSheetLevel.peek);
      expect(notifier.resolveHeightForSameTabTap(), BottomSheetLevel.collapsed);
    });

    test('half -> collapsed', () {
      // initial is half already
      expect(notifier.resolveHeightForSameTabTap(), BottomSheetLevel.collapsed);
    });

    test('expanded -> half', () {
      notifier.setSheetLevel(BottomSheetLevel.expanded);
      expect(notifier.resolveHeightForSameTabTap(), BottomSheetLevel.half);
    });

    test('full -> half', () {
      notifier.setSheetLevel(BottomSheetLevel.full);
      expect(notifier.resolveHeightForSameTabTap(), BottomSheetLevel.half);
    });
  });

  // ---------------------------------------------------------------------------
  // 3. S5.1 tab default heights
  // ---------------------------------------------------------------------------
  group('S5.1 tab default heights', () {
    test('trip tab default is half', () {
      expect(tabDefaultHeight[BottomTab.trip], BottomSheetLevel.half);
    });

    test('member tab default is peek', () {
      expect(tabDefaultHeight[BottomTab.member], BottomSheetLevel.peek);
    });

    test('chat tab default is expanded', () {
      expect(tabDefaultHeight[BottomTab.chat], BottomSheetLevel.expanded);
    });

    test('guide tab default is half', () {
      expect(tabDefaultHeight[BottomTab.guide], BottomSheetLevel.half);
    });
  });

  // ---------------------------------------------------------------------------
  // 4. S7.2 tab switch height preservation
  // ---------------------------------------------------------------------------
  group('S7.2 tab switch height preservation', () {
    test('current >= min required -> keep current height', () {
      // Set to expanded (index 3), switch to trip (min: peek, index 1)
      notifier.setSheetLevel(BottomSheetLevel.expanded);
      final result = notifier.resolveHeightForTab(BottomTab.trip);
      expect(result, BottomSheetLevel.expanded);
    });

    test('current < min required -> use tab default', () {
      // Set to collapsed (index 0), switch to chat (min: expanded, index 3)
      notifier.setSheetLevel(BottomSheetLevel.collapsed);
      final result = notifier.resolveHeightForTab(BottomTab.chat);
      // collapsed < expanded, so fallback to chat default (expanded)
      expect(result, BottomSheetLevel.expanded);
    });
  });

  // ---------------------------------------------------------------------------
  // 5. S5.2 trip status initial heights
  // ---------------------------------------------------------------------------
  group('S5.2 trip status initial heights', () {
    test('none -> collapsed', () {
      expect(initialHeightForTripStatus('none'), BottomSheetLevel.collapsed);
    });

    test('planning -> collapsed', () {
      expect(
          initialHeightForTripStatus('planning'), BottomSheetLevel.collapsed);
    });

    test('active -> collapsed', () {
      expect(initialHeightForTripStatus('active'), BottomSheetLevel.collapsed);
    });

    test('completed -> half', () {
      expect(initialHeightForTripStatus('completed'), BottomSheetLevel.half);
    });
  });

  // ---------------------------------------------------------------------------
  // 6. S6 keyboard handling
  // ---------------------------------------------------------------------------
  group('S6 keyboard handling', () {
    test('show -> full + save previous level', () {
      notifier.setSheetLevel(BottomSheetLevel.half);
      final result = notifier.onKeyboardShow();
      expect(result, BottomSheetLevel.full);
      expect(notifier.state.sheetLevel, BottomSheetLevel.full);
      expect(notifier.state.preKeyboardLevel, BottomSheetLevel.half);
    });

    test('hide -> restore previous level', () {
      notifier.setSheetLevel(BottomSheetLevel.expanded);
      notifier.onKeyboardShow();
      final result = notifier.onKeyboardHide();
      expect(result, BottomSheetLevel.expanded);
      expect(notifier.state.sheetLevel, BottomSheetLevel.expanded);
      expect(notifier.state.preKeyboardLevel, isNull);
    });

    test('chat tab hide -> expanded (S6.2)', () {
      notifier.setCurrentTab(BottomTab.chat);
      notifier.setSheetLevel(BottomSheetLevel.half);
      notifier.onKeyboardShow();
      final result = notifier.onKeyboardHide();
      expect(result, BottomSheetLevel.expanded);
      expect(notifier.state.sheetLevel, BottomSheetLevel.expanded);
    });

    test('SOS active + keyboard show -> collapsed', () {
      notifier.activateSos();
      final result = notifier.onKeyboardShow();
      expect(result, BottomSheetLevel.collapsed);
      expect(notifier.state.sheetLevel, BottomSheetLevel.collapsed);
    });
  });

  // ---------------------------------------------------------------------------
  // 7. S10 SOS
  // ---------------------------------------------------------------------------
  group('S10 SOS', () {
    test('activate -> collapsed + locked (isSosActive)', () {
      notifier.activateSos();
      expect(notifier.state.isSosActive, isTrue);
      expect(notifier.state.sheetLevel, BottomSheetLevel.collapsed);
    });

    test('locked -> setSheetLevel returns collapsed regardless of input', () {
      notifier.activateSos();
      final result = notifier.setSheetLevel(BottomSheetLevel.expanded);
      expect(result, BottomSheetLevel.collapsed);
      // state should remain collapsed
      expect(notifier.state.sheetLevel, BottomSheetLevel.collapsed);
    });

    test('deactivate -> peek + unlocked', () {
      notifier.activateSos();
      notifier.deactivateSos();
      expect(notifier.state.isSosActive, isFalse);
      expect(notifier.state.sheetLevel, BottomSheetLevel.peek);
    });
  });

  // ---------------------------------------------------------------------------
  // 8. S7.4 detail view
  // ---------------------------------------------------------------------------
  group('S7.4 detail view', () {
    test('enter -> full + save previous level', () {
      notifier.setSheetLevel(BottomSheetLevel.half);
      final result = notifier.enterDetailView();
      expect(result, BottomSheetLevel.full);
      expect(notifier.state.sheetLevel, BottomSheetLevel.full);
      expect(notifier.state.preDetailLevel, BottomSheetLevel.half);
    });

    test('exit -> restore previous level', () {
      notifier.setSheetLevel(BottomSheetLevel.expanded);
      notifier.enterDetailView();
      final result = notifier.exitDetailView();
      expect(result, BottomSheetLevel.expanded);
      expect(notifier.state.sheetLevel, BottomSheetLevel.expanded);
      expect(notifier.state.preDetailLevel, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // 9. S8.2 No-trip
  // ---------------------------------------------------------------------------
  group('S8.2 No-trip', () {
    test('setNoTrip(true) -> collapsed + locked', () {
      notifier.setNoTrip(true);
      expect(notifier.state.isNoTrip, isTrue);
      expect(notifier.state.sheetLevel, BottomSheetLevel.collapsed);
    });

    test('locked -> setSheetLevel returns collapsed regardless of input', () {
      notifier.setNoTrip(true);
      final result = notifier.setSheetLevel(BottomSheetLevel.half);
      expect(result, BottomSheetLevel.collapsed);
      expect(notifier.state.sheetLevel, BottomSheetLevel.collapsed);
    });

    test('setNoTrip(false) -> unlocked (can set levels freely)', () {
      notifier.setNoTrip(true);
      notifier.setNoTrip(false);
      expect(notifier.state.isNoTrip, isFalse);
      // Now should be able to set a level
      final result = notifier.setSheetLevel(BottomSheetLevel.expanded);
      expect(result, BottomSheetLevel.expanded);
      expect(notifier.state.sheetLevel, BottomSheetLevel.expanded);
    });
  });

  // ---------------------------------------------------------------------------
  // 10. BottomSheetLevel fraction
  // ---------------------------------------------------------------------------
  group('BottomSheetLevel fraction', () {
    test('all fractions are correct', () {
      expect(BottomSheetLevel.collapsed.fraction, 0.10);
      expect(BottomSheetLevel.peek.fraction, 0.25);
      expect(BottomSheetLevel.half.fraction, 0.50);
      expect(BottomSheetLevel.expanded.fraction, 0.75);
      expect(BottomSheetLevel.full.fraction, 1.00);
    });

    test('fromFraction returns nearest level', () {
      expect(BottomSheetLevelExt.fromFraction(0.0), BottomSheetLevel.collapsed);
      expect(BottomSheetLevelExt.fromFraction(0.10), BottomSheetLevel.collapsed);
      expect(BottomSheetLevelExt.fromFraction(0.15), BottomSheetLevel.collapsed);
      expect(BottomSheetLevelExt.fromFraction(0.20), BottomSheetLevel.peek);
      expect(BottomSheetLevelExt.fromFraction(0.25), BottomSheetLevel.peek);
      expect(BottomSheetLevelExt.fromFraction(0.40), BottomSheetLevel.half);
      expect(BottomSheetLevelExt.fromFraction(0.50), BottomSheetLevel.half);
      expect(BottomSheetLevelExt.fromFraction(0.60), BottomSheetLevel.half);
      expect(BottomSheetLevelExt.fromFraction(0.70), BottomSheetLevel.expanded);
      expect(BottomSheetLevelExt.fromFraction(0.75), BottomSheetLevel.expanded);
      expect(BottomSheetLevelExt.fromFraction(0.90), BottomSheetLevel.full);
      expect(BottomSheetLevelExt.fromFraction(1.00), BottomSheetLevel.full);
    });
  });
}
