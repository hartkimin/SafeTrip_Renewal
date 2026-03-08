import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:safetrip_mobile/main.dart' as app;

import '../helpers/test_helpers.dart';
import '../helpers/test_config.dart';
import '../fixtures/test_data.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Flow 4: Guardian System', () {
    testWidgets('4-1: Create guardian invite link', (tester) async {
      app.main();
      await tester.pumpAndSettle();
      await tester.waitAndSettle(TestConfig.longWait);

      // Navigate to member tab or guardian section
      await tester.tapText('멤버');
      await tester.waitAndSettle(TestConfig.mediumWait);

      // Look for "가디언 초대" or similar
      final guardianInvite = find.textContaining('가디언');
      if (guardianInvite.evaluate().isNotEmpty) {
        await tester.tap(guardianInvite.first);
        await tester.pumpAndSettle();

        // Enter guardian phone number
        final phoneField = find.byType(TextField);
        if (phoneField.evaluate().isNotEmpty) {
          await tester.enterText(
              phoneField.first, TestData.guardianPhoneNumber);
          await tester.pumpAndSettle();

          // Submit
          final submitButton = find.text('초대');
          if (submitButton.evaluate().isNotEmpty) {
            await tester.tap(submitButton.first);
            await tester.waitAndSettle(TestConfig.mediumWait);
          }
        }
      }
    });

    testWidgets('4-2: Verify guardian pending status', (tester) async {
      app.main();
      await tester.pumpAndSettle();
      await tester.waitAndSettle(TestConfig.longWait);

      // Check guardian tab for pending status
      await tester.tapText('멤버');
      await tester.waitAndSettle(TestConfig.mediumWait);

      // Look for pending indicator
      expect(find.textContaining('대기'), findsWidgets,
          reason: 'Guardian invite should show pending state');
    });
  });
}
