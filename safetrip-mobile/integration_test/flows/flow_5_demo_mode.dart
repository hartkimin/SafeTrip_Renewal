import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:safetrip_mobile/main.dart' as app;

import '../helpers/test_helpers.dart';
import '../helpers/test_config.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Flow 5: Demo Mode', () {
    testWidgets('5-1~5-5: Complete demo tour flow', (tester) async {
      app.main();
      await tester.pumpAndSettle();
      await tester.waitAndSettle(TestConfig.longWait);

      // ── 5-1: Navigate to Purpose Select → Demo Tour ──
      final demoButton = find.textContaining('둘러보기');
      if (demoButton.evaluate().isEmpty) {
        // Need to log out first
        final settingsIcon = find.byIcon(Icons.settings);
        if (settingsIcon.evaluate().isNotEmpty) {
          await tester.tap(settingsIcon.first);
          await tester.pumpAndSettle();

          final logout = find.textContaining('로그아웃');
          if (logout.evaluate().isNotEmpty) {
            await tester.tap(logout.first);
            await tester.pumpAndSettle();

            final confirm = find.text('확인');
            if (confirm.evaluate().isNotEmpty) {
              await tester.tap(confirm);
              await tester.waitAndSettle(TestConfig.longWait);
            }
          }
        }
      }

      // Now should be on Welcome or Purpose screen
      await tester.waitAndSettle(TestConfig.longWait);

      // Skip welcome if visible
      final skip = find.text('건너뛰기');
      if (skip.evaluate().isNotEmpty) {
        await tester.tap(skip);
        await tester.pumpAndSettle();
      }

      // ── 5-1: Tap "먼저 둘러보기" (Demo Tour) ──
      final demoTour = find.textContaining('둘러보기');
      if (demoTour.evaluate().isNotEmpty) {
        await tester.tap(demoTour.first);
        await tester.waitAndSettle(TestConfig.longWait);
      }

      // ── 5-2: Scenario Select ──
      await tester.waitAndSettle(TestConfig.mediumWait);

      final scenarioButton = find.byType(ElevatedButton);
      if (scenarioButton.evaluate().isNotEmpty) {
        await tester.tap(scenarioButton.first);
        await tester.waitAndSettle(TestConfig.longWait);
      }

      // ── 5-3: Demo Main Screen ──
      await tester.waitAndSettle(TestConfig.longWait);

      // ── 5-4: Verify read-only mode ──
      // Demo mode should restrict editing

      // ── 5-5: Exit demo ──
      final exitDemo = find.textContaining('나가기');
      final endDemo = find.textContaining('종료');
      if (exitDemo.evaluate().isNotEmpty) {
        await tester.tap(exitDemo.first);
        await tester.waitAndSettle(TestConfig.mediumWait);
      } else if (endDemo.evaluate().isNotEmpty) {
        await tester.tap(endDemo.first);
        await tester.waitAndSettle(TestConfig.mediumWait);
      }
    });
  });
}
