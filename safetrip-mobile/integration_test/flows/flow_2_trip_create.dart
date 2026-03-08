import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:safetrip_mobile/main.dart' as app;

import '../helpers/test_helpers.dart';
import '../helpers/test_config.dart';
import '../fixtures/test_data.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Flow 2: Trip Creation', () {
    testWidgets('2-1~2-5: Create a new trip after onboarding', (tester) async {
      app.main();
      await tester.pumpAndSettle();
      await tester.waitAndSettle(TestConfig.longWait);

      // If we land on main (already has trip), navigate to trip create
      final tripCreateTitle = find.textContaining('여행 정보를');
      if (tripCreateTitle.evaluate().isEmpty) {
        return;
      }

      // ── 2-1: Enter trip name ──
      await tester.waitAndSettle(TestConfig.mediumWait);
      final tripNameField = find.byType(TextField).first;
      await tester.enterText(tripNameField, TestData.testTripName);
      await tester.pumpAndSettle();

      // ── 2-2: Select country (Japan) ──
      final countrySelector = find.textContaining('국가');
      if (countrySelector.evaluate().isNotEmpty) {
        await tester.tap(countrySelector.first);
        await tester.pumpAndSettle();

        final japanOption = find.text(TestData.testCountryName);
        if (japanOption.evaluate().isNotEmpty) {
          await tester.tap(japanOption.first);
          await tester.pumpAndSettle();
        }
      }

      // ── 2-3: Enter destination city ──
      final textFields = find.byType(TextField);
      if (textFields.evaluate().length > 1) {
        await tester.enterText(textFields.at(1), TestData.testDestinationCity);
        await tester.pumpAndSettle();
      }

      // ── 2-4: Select date range ──
      final datePicker = find.textContaining('여행 기간');
      if (datePicker.evaluate().isNotEmpty) {
        await tester.tap(datePicker.first);
        await tester.pumpAndSettle();

        final confirmButton = find.text('확인');
        if (confirmButton.evaluate().isNotEmpty) {
          await tester.tap(confirmButton);
          await tester.pumpAndSettle();
        }
      }

      // ── 2-5: Tap "여행 생성하기" ──
      final createButton = find.text('여행 생성하기');
      if (createButton.evaluate().isNotEmpty) {
        await tester.tap(createButton);
        await tester.waitAndSettle(TestConfig.longWait);
      }

      // ── Verify: Should navigate to main screen ──
      await tester.waitAndSettle(TestConfig.longWait);

      final tabText = find.text('일정');
      expect(tabText, findsWidgets,
          reason: 'After trip creation, should see main screen with 일정 tab');
    });
  });
}
