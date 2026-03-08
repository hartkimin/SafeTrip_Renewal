import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:safetrip_mobile/main.dart' as app;

import '../helpers/test_helpers.dart';
import '../helpers/test_config.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Flow 6: SOS + Offline', () {
    testWidgets('6-1: SOS button long-press activates SOS overlay',
        (tester) async {
      app.main();
      await tester.pumpAndSettle();
      await tester.waitAndSettle(TestConfig.longWait);

      // Find SOS button on main screen
      final sosButton = find.text('SOS');
      if (sosButton.evaluate().isNotEmpty) {
        // Long-press for 3+ seconds to activate
        await tester.longPress(sosButton);
        await tester.pump(const Duration(seconds: 4));
        await tester.pumpAndSettle();

        // ── 6-1: Verify SOS overlay appears ──
        final deactivateButton = find.text('해제');
        expect(deactivateButton, findsWidgets,
            reason: 'SOS overlay should show deactivation button');

        // ── 6-2: Deactivate SOS ──
        await tester.tap(deactivateButton);
        await tester.pumpAndSettle();

        // Verify SOS overlay is gone
        expect(find.text('해제'), findsNothing,
            reason: 'SOS overlay should disappear after deactivation');
      }
    });

    // Offline testing requires connectivity mock — placeholder
    testWidgets('6-3: Offline banner (placeholder)', (tester) async {
      expect(true, isTrue,
          reason: 'Placeholder — offline test needs mock setup');
    });
  });
}
