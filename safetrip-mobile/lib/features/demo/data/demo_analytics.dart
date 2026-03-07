import 'package:flutter/foundation.dart';

/// DOC-T3-DMO-030 §3.8 — Demo mode analytics events
/// 7 events for measuring demo-to-signup conversion.
/// No PII — only session UUID as identifier (D1 principle).
class DemoAnalytics {
  DemoAnalytics._();

  /// Fires when user enters scenario selection screen
  static void demoStarted() {
    _log('demo_started', {});
  }

  /// Fires when user selects a scenario
  static void scenarioSelected(String scenarioId) {
    _log('demo_scenario_selected', {'scenario_id': scenarioId});
  }

  /// Fires when user switches role via role panel
  static void roleSwitched({
    required String fromRole,
    required String toRole,
  }) {
    _log('demo_role_switched', {
      'from_role': fromRole,
      'to_role': toRole,
    });
  }

  /// Fires when user switches privacy grade
  static void gradeSwitched(String grade) {
    _log('demo_grade_switched', {'grade': grade});
  }

  /// Fires when user views guardian upgrade comparison
  static void guardianUpgradeViewed() {
    _log('demo_guardian_upgrade_viewed', {});
  }

  /// Fires when demo completion screen is shown
  static void demoCompleted({
    required int durationSeconds,
    required String scenarioId,
  }) {
    _log('demo_completed', {
      'duration_seconds': durationSeconds.toString(),
      'scenario_id': scenarioId,
    });
  }

  /// Fires when user taps a conversion CTA
  static void demoConverted(String ctaType) {
    _log('demo_converted', {'cta_type': ctaType});
  }

  static void _log(String eventName, Map<String, String> params) {
    debugPrint('[DemoAnalytics] $eventName: $params');
    // TODO: Replace with FirebaseAnalytics.instance.logEvent() when integrated
  }
}
