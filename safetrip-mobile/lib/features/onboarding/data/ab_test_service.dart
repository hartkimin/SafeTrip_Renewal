import 'package:shared_preferences/shared_preferences.dart';

/// DOC-T3-WLC-029 §3.6 — Device ID hash-based A/B test variant assignment
/// Same device always gets same variant (deterministic).
enum WelcomeAbVariant { a, b }

class WelcomeAbTestService {
  WelcomeAbTestService._();

  static WelcomeAbVariant? _cached;

  /// Get the A/B variant for this device.
  /// Uses stored device_id hash for deterministic assignment.
  static Future<WelcomeAbVariant> getVariant() async {
    if (_cached != null) return _cached!;

    final prefs = await SharedPreferences.getInstance();
    final deviceId = prefs.getString('user_id') ??
        prefs.getString('device_id') ??
        DateTime.now().millisecondsSinceEpoch.toString();

    // Deterministic hash → variant
    final hash = deviceId.hashCode.abs();
    _cached = hash % 2 == 0 ? WelcomeAbVariant.a : WelcomeAbVariant.b;
    return _cached!;
  }

  /// A/B test variables (§3.6 table)
  static int slideCount(WelcomeAbVariant v) => v == WelcomeAbVariant.a ? 4 : 3;
  static String ctaText(WelcomeAbVariant v) => v == WelcomeAbVariant.a ? 'default' : 'safety';
}
