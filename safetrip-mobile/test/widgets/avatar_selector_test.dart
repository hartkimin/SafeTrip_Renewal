import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safetrip_mobile/core/constants/avatar_constants.dart';
import 'package:safetrip_mobile/widgets/avatar_selector.dart';

void main() {
  testWidgets('AvatarSelector renders 10 avatar options', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AvatarSelector(
              selectedAvatarId: null,
              onSelected: (_) {},
            ),
          ),
        ),
      ),
    );

    // Check some avatar names are rendered
    expect(find.text('비행기'), findsOneWidget);
    expect(find.text('캠핑'), findsOneWidget);
    expect(find.text('탐험'), findsOneWidget);
  });

  test('AvatarConstants has exactly 10 themes', () {
    expect(AvatarConstants.themes.length, 10);
  });

  test('AvatarConstants.getById returns correct theme', () {
    final theme = AvatarConstants.getById('avatar_camping');
    expect(theme?.name, '캠핑');
    expect(theme?.icon, '⛺');
  });

  test('AvatarConstants.getById returns null for unknown id', () {
    expect(AvatarConstants.getById('unknown'), isNull);
  });

  test('AvatarConstants.getById returns null for null', () {
    expect(AvatarConstants.getById(null), isNull);
  });
}
