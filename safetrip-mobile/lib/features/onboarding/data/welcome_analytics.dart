import 'package:flutter/foundation.dart';

/// DOC-T3-WLC-029 §7.3 — Welcome screen analytics events
/// Currently logs to debug console. Swap with Firebase Analytics when ready.
class WelcomeAnalytics {
  WelcomeAnalytics._();

  /// §7.3: Prevent double-firing welcome_view across ScreenWelcome → ScreenPurposeSelect
  static bool _welcomeViewFired = false;

  /// Reset for testing purposes
  static void resetForTesting() => _welcomeViewFired = false;

  static void welcomeView({
    required String abVariant,
    required String timeOfDay,
    required bool deeplinkPresent,
  }) {
    if (_welcomeViewFired) return; // §7.3: one per session
    _welcomeViewFired = true;
    _log('welcome_view', {
      'ab_variant': abVariant,
      'time_of_day': timeOfDay,
      'deeplink_present': deeplinkPresent.toString(),
    });
  }

  static void slideViewed({
    required int slideIndex,
    required bool autoAdvance,
  }) {
    _log('slide_viewed', {
      'slide_index': slideIndex.toString(),
      'auto_or_manual': autoAdvance ? 'auto' : 'manual',
    });
  }

  static void slideSkipped({required int skippedAtSlide}) {
    _log('slide_skipped', {
      'skipped_at_slide': skippedAtSlide.toString(),
    });
  }

  static void purposeSelected({required String purpose}) {
    _log('purpose_selected', {
      'purpose': purpose,
    });
  }

  static void _log(String eventName, Map<String, String> params) {
    debugPrint('[WelcomeAnalytics] $eventName: $params');
    // TODO: Replace with FirebaseAnalytics.instance.logEvent() when integrated
  }
}
