import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'test_config.dart';

/// Common helper extensions for integration tests.
extension IntegrationTestHelpers on WidgetTester {
  /// Wait for widget to appear, then settle.
  Future<void> waitForWidget(Finder finder, {Duration? timeout}) async {
    final deadline = timeout ?? TestConfig.settleTimeout;
    final end = DateTime.now().add(deadline);
    while (DateTime.now().isBefore(end)) {
      await pump(const Duration(milliseconds: 100));
      if (finder.evaluate().isNotEmpty) {
        await pumpAndSettle();
        return;
      }
    }
    // Final attempt — let it throw if still not found
    await pumpAndSettle();
    expect(finder, findsWidgets);
  }

  /// Tap a widget found by text, then settle.
  Future<void> tapText(String text) async {
    await waitForWidget(find.text(text));
    await tap(find.text(text).first);
    await pumpAndSettle();
  }

  /// Tap a widget found by key, then settle.
  Future<void> tapByKey(String key) async {
    final finder = find.byKey(ValueKey(key));
    await waitForWidget(finder);
    await tap(finder.first);
    await pumpAndSettle();
  }

  /// Enter text into a TextField found by index.
  Future<void> enterTextAtIndex(int index, String text) async {
    final finder = find.byType(TextField).at(index);
    await waitForWidget(finder);
    await enterText(finder, text);
    await pumpAndSettle();
  }

  /// Enter text into the first TextField visible.
  Future<void> enterFirstTextField(String text) async {
    final finder = find.byType(TextField).first;
    await waitForWidget(finder);
    await enterText(finder, text);
    await pumpAndSettle();
  }

  /// Wait a fixed duration, then settle.
  Future<void> waitAndSettle(Duration duration) async {
    await pump(duration);
    await pumpAndSettle();
  }

  /// Swipe left on a PageView (next page).
  Future<void> swipePageLeft() async {
    final pageView = find.byType(PageView);
    await drag(pageView, const Offset(-300, 0));
    await pumpAndSettle();
  }

  /// Verify a screen is visible by checking for specific text.
  void expectScreen(String text) {
    expect(find.text(text), findsWidgets,
        reason: 'Expected screen with "$text" to be visible');
  }

  /// Verify text is NOT visible.
  void expectNoText(String text) {
    expect(find.text(text), findsNothing,
        reason: 'Expected "$text" to NOT be visible');
  }
}
