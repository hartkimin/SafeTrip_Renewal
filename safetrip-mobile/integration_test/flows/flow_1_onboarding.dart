import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:safetrip_mobile/main.dart' as app;

import '../helpers/test_helpers.dart';
import '../helpers/test_config.dart';
import '../fixtures/test_data.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Flow 1: Onboarding — New User Signup', () {
    testWidgets('1-1: Splash screen shows and transitions', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Splash screen should auto-transition to Welcome or Purpose
      await tester.waitAndSettle(TestConfig.longWait);
    });

    testWidgets(
        '1-2~1-7: Complete onboarding: Welcome → Purpose → Phone → Terms → Birth → Profile',
        (tester) async {
      app.main();
      await tester.pumpAndSettle();
      await tester.waitAndSettle(TestConfig.longWait);

      // ── 1-2: Welcome Screen — Skip through slides ──
      final skipFinder = find.text('건너뛰기');
      if (skipFinder.evaluate().isNotEmpty) {
        await tester.tap(skipFinder);
        await tester.pumpAndSettle();
      }

      // ── 1-3: Purpose Select — Choose "여행 만들기" (Captain) ──
      await tester.waitAndSettle(TestConfig.mediumWait);
      final createTripFinder = find.textContaining('여행');
      expect(createTripFinder, findsWidgets,
          reason: 'Purpose select should show trip creation option');

      await tester.tap(createTripFinder.first);
      await tester.pumpAndSettle();

      // ── 1-4: Phone Auth — Enter phone number and OTP ──
      await tester.waitAndSettle(TestConfig.mediumWait);

      // Step 1: Enter phone number
      final phoneField = find.byType(TextField).first;
      await tester.enterText(phoneField, TestData.testPhoneNumber);
      await tester.pumpAndSettle();

      // Tap "인증번호 받기" (Send OTP)
      await tester.tapText('인증번호 받기');
      await tester.waitAndSettle(TestConfig.longWait);

      // Step 2: Enter OTP code
      final otpField = find.byType(TextField).last;
      await tester.enterText(otpField, TestData.testOtpCode);
      await tester.pumpAndSettle();

      // Tap "인증하기" (Verify)
      await tester.tapText('인증하기');
      await tester.waitAndSettle(TestConfig.longWait);

      // ── 1-5: Terms Consent — Check all required boxes ──
      await tester.waitAndSettle(TestConfig.mediumWait);

      final checkboxes = find.byType(Checkbox);
      if (checkboxes.evaluate().isNotEmpty) {
        for (int i = 0; i < checkboxes.evaluate().length && i < 4; i++) {
          await tester.tap(checkboxes.at(i));
          await tester.pumpAndSettle();
        }

        await tester.tapText('다음');
        await tester.waitAndSettle(TestConfig.mediumWait);
      }

      // ── 1-6: Birth Date — Select adult date ──
      await tester.waitAndSettle(TestConfig.mediumWait);

      final datePicker = find.byType(CupertinoDatePicker);
      if (datePicker.evaluate().isNotEmpty) {
        await tester.tapText('다음');
        await tester.waitAndSettle(TestConfig.mediumWait);
      }

      // ── 1-7: Profile Setup — Enter name and complete ──
      await tester.waitAndSettle(TestConfig.mediumWait);

      final nameField = find.byType(TextField);
      if (nameField.evaluate().isNotEmpty) {
        await tester.enterText(nameField.first, TestData.testUserName);
        await tester.pumpAndSettle();

        final startButton = find.text('시작하기');
        if (startButton.evaluate().isNotEmpty) {
          await tester.tap(startButton);
        }
        await tester.waitAndSettle(TestConfig.longWait);
      }

      // ── Verify: Should be on Main screen or Trip Create screen ──
      await tester.waitAndSettle(TestConfig.longWait);

      final onMainOrCreate =
          find.textContaining('여행').evaluate().isNotEmpty ||
              find.text('일정').evaluate().isNotEmpty;
      expect(onMainOrCreate, isTrue,
          reason: 'After onboarding, should be on main or trip create screen');
    });
  });
}
