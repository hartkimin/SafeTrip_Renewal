import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:safetrip_mobile/main.dart' as app;

import '../helpers/test_helpers.dart';
import '../helpers/test_config.dart';
import '../fixtures/test_data.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Flow 7: Settings & Profile', () {
    testWidgets('7-1: Navigate to profile screen', (tester) async {
      app.main();
      await tester.pumpAndSettle();
      await tester.waitAndSettle(TestConfig.longWait);

      // Find settings/profile icon
      final settingsIcon = find.byIcon(Icons.settings);
      final personIcon = find.byIcon(Icons.person);

      if (settingsIcon.evaluate().isNotEmpty) {
        await tester.tap(settingsIcon.first);
      } else if (personIcon.evaluate().isNotEmpty) {
        await tester.tap(personIcon.first);
      }
      await tester.pumpAndSettle();

      await tester.waitAndSettle(TestConfig.mediumWait);

      final profileText = find.textContaining('프로필');
      expect(profileText, findsWidgets,
          reason: 'Profile/settings screen should show profile section');
    });

    testWidgets('7-2: Edit display name', (tester) async {
      app.main();
      await tester.pumpAndSettle();
      await tester.waitAndSettle(TestConfig.longWait);

      // Navigate to settings
      final settingsIcon = find.byIcon(Icons.settings);
      if (settingsIcon.evaluate().isNotEmpty) {
        await tester.tap(settingsIcon.first);
        await tester.pumpAndSettle();
      }

      // Navigate to profile edit
      final profileEdit = find.textContaining('프로필 편집');
      if (profileEdit.evaluate().isNotEmpty) {
        await tester.tap(profileEdit.first);
        await tester.pumpAndSettle();
      }

      // Find name TextField and update
      final nameField = find.byType(TextField);
      if (nameField.evaluate().isNotEmpty) {
        await tester.enterText(nameField.first, TestData.updatedUserName);
        await tester.pumpAndSettle();

        final saveButton = find.text('저장');
        if (saveButton.evaluate().isNotEmpty) {
          await tester.tap(saveButton);
          await tester.waitAndSettle(TestConfig.mediumWait);
        }
      }

      await tester.waitAndSettle(TestConfig.mediumWait);
    });

    testWidgets('7-3: Logout returns to Welcome screen', (tester) async {
      app.main();
      await tester.pumpAndSettle();
      await tester.waitAndSettle(TestConfig.longWait);

      // Navigate to settings
      final settingsIcon = find.byIcon(Icons.settings);
      if (settingsIcon.evaluate().isNotEmpty) {
        await tester.tap(settingsIcon.first);
        await tester.pumpAndSettle();
      }

      // Find and tap logout
      final logoutButton = find.textContaining('로그아웃');
      if (logoutButton.evaluate().isNotEmpty) {
        await tester.tap(logoutButton.first);
        await tester.pumpAndSettle();

        final confirmButton = find.text('확인');
        if (confirmButton.evaluate().isNotEmpty) {
          await tester.tap(confirmButton);
          await tester.waitAndSettle(TestConfig.longWait);
        }
      }

      // Verify: should be back on Welcome or Purpose screen
      await tester.waitAndSettle(TestConfig.longWait);

      final welcomeOrPurpose =
          find.text('건너뛰기').evaluate().isNotEmpty ||
              find.textContaining('SafeTrip').evaluate().isNotEmpty;
      expect(welcomeOrPurpose, isTrue,
          reason: 'After logout, should return to welcome/purpose screen');
    });
  });
}
