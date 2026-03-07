import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safetrip_mobile/features/onboarding/presentation/widgets/welcome_dot_indicator.dart';
import 'package:safetrip_mobile/features/onboarding/l10n/welcome_strings.dart';

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

    testWidgets('active dot has localized semantics label', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: WelcomeDotIndicator(count: 4, current: 1),
          ),
        ),
      );

      // §3.5, §3.7: Verify semantics label uses WelcomeStrings.dotSemantics
      final expected = WelcomeStrings.dotSemantics(2, 4);
      expect(find.bySemanticsLabel(expected), findsOneWidget);
    });

    testWidgets('dot tap calls onDotTap with correct index', (tester) async {
      int? tappedIndex;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WelcomeDotIndicator(
              count: 4,
              current: 0,
              onDotTap: (i) => tappedIndex = i,
            ),
          ),
        ),
      );

      // §3.2: Tap the third dot (index 2)
      final dots = find.byType(GestureDetector);
      expect(dots, findsNWidgets(4));
      await tester.tap(dots.at(2));
      await tester.pump();

      expect(tappedIndex, equals(2));
    });

    testWidgets('dot tap does nothing when onDotTap is null', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: WelcomeDotIndicator(count: 4, current: 0),
          ),
        ),
      );

      // Should not throw when tapping without handler
      final dots = find.byType(GestureDetector);
      await tester.tap(dots.at(1));
      await tester.pump();
      // No assertion needed — just verifying no exception
    });
  });

  group('WelcomeStrings', () {
    test('dotSemantics formats correctly', () {
      final result = WelcomeStrings.dotSemantics(2, 4);
      // Default locale in test is system locale; verify number substitution
      expect(result, contains('2'));
      expect(result, contains('4'));
    });

    test('createTripForVariant returns default for "default"', () {
      final result = WelcomeStrings.createTripForVariant('default');
      // Should return the standard create trip label
      expect(result, isNotEmpty);
    });

    test('createTripForVariant returns safety variant for "safety"', () {
      final result = WelcomeStrings.createTripForVariant('safety');
      // Should return a different string than default
      final defaultResult = WelcomeStrings.createTripForVariant('default');
      expect(result, isNot(equals(defaultResult)));
    });
  });
}
