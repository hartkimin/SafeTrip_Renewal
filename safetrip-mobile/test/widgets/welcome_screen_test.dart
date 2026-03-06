import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safetrip_mobile/features/onboarding/presentation/widgets/welcome_dot_indicator.dart';

void main() {
  group('WelcomeDotIndicator', () {
    testWidgets('renders correct number of dots', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: WelcomeDotIndicator(count: 4, current: 0),
          ),
        ),
      );

      // 4 AnimatedContainers for 4 dots
      final containers = find.byType(AnimatedContainer);
      expect(containers, findsNWidgets(4));
    });

    testWidgets('active dot has semantics label', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: WelcomeDotIndicator(count: 4, current: 1),
          ),
        ),
      );

      // Verify semantics label
      expect(find.bySemanticsLabel('슬라이드 2 / 4'), findsOneWidget);
    });
  });
}
