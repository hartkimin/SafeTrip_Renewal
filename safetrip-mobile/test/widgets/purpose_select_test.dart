import 'package:flutter_test/flutter_test.dart';
import 'package:safetrip_mobile/features/onboarding/l10n/welcome_strings.dart';

void main() {
  group('WelcomeStrings', () {
    test('slide titles have 4 entries', () {
      final titles = WelcomeStrings.slideTitles;
      expect(titles.length, 4);
    });

    test('all string lists have matching lengths', () {
      final titles = WelcomeStrings.slideTitles;
      final subtitles = WelcomeStrings.slideSubtitles;
      final semantics = WelcomeStrings.slideSemantics;
      expect(titles.length, subtitles.length);
      expect(titles.length, semantics.length);
    });

    test('button strings are not empty', () {
      expect(WelcomeStrings.skip.isNotEmpty, true);
      expect(WelcomeStrings.next.isNotEmpty, true);
      expect(WelcomeStrings.getStarted.isNotEmpty, true);
      expect(WelcomeStrings.createTrip.isNotEmpty, true);
      expect(WelcomeStrings.enterCode.isNotEmpty, true);
      expect(WelcomeStrings.demoTour.isNotEmpty, true);
      expect(WelcomeStrings.guardianJoin.isNotEmpty, true);
    });
  });
}
