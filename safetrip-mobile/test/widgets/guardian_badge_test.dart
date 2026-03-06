import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safetrip_mobile/widgets/guardian_badge.dart';

void main() {
  group('GuardianBadge', () {
    testWidgets('shows 가디언 for free guardian', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Center(child: GuardianBadge(isPaid: false))),
        ),
      );
      expect(find.text('가디언'), findsOneWidget);
      expect(find.text('가디언+'), findsNothing);
    });

    testWidgets('shows 가디언+ for paid guardian', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Center(child: GuardianBadge(isPaid: true))),
        ),
      );
      expect(find.text('가디언+'), findsOneWidget);
    });
  });

  group('GuardianBadge.icon', () {
    testWidgets('renders small circle badge for paid', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home:
              Scaffold(body: Center(child: GuardianBadge.icon(isPaid: true))),
        ),
      );
      // Should find a shield icon
      expect(find.byIcon(Icons.shield), findsOneWidget);
    });

    testWidgets('renders small circle badge for free', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home:
              Scaffold(body: Center(child: GuardianBadge.icon(isPaid: false))),
        ),
      );
      expect(find.byIcon(Icons.shield), findsOneWidget);
    });
  });
}
