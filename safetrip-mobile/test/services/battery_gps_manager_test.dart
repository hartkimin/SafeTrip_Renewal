import 'package:flutter_test/flutter_test.dart';
import 'package:safetrip_mobile/services/battery_gps_manager.dart';

void main() {
  group('BatteryGpsManager.calculateInterval', () {
    // §7.1 — SOS active overrides everything
    test('SOS active online returns 10s', () {
      expect(
        BatteryGpsManager.calculateInterval(
          privacyLevel: 'standard',
          isOffline: false,
          batteryLevel: 80,
          isSosActive: true,
        ),
        10,
      );
    });

    test('SOS active offline returns 30s', () {
      expect(
        BatteryGpsManager.calculateInterval(
          privacyLevel: 'standard',
          isOffline: true,
          batteryLevel: 80,
          isSosActive: true,
        ),
        30,
      );
    });

    // §7.1 — Privacy × Network matrix
    test('safety_first online returns 30s', () {
      expect(
        BatteryGpsManager.calculateInterval(
          privacyLevel: 'safety_first',
          isOffline: false,
          batteryLevel: 80,
          isSosActive: false,
        ),
        30,
      );
    });

    test('safety_first offline returns 300s (5min)', () {
      expect(
        BatteryGpsManager.calculateInterval(
          privacyLevel: 'safety_first',
          isOffline: true,
          batteryLevel: 80,
          isSosActive: false,
        ),
        300,
      );
    });

    test('standard online returns 60s', () {
      expect(
        BatteryGpsManager.calculateInterval(
          privacyLevel: 'standard',
          isOffline: false,
          batteryLevel: 80,
          isSosActive: false,
        ),
        60,
      );
    });

    test('standard offline returns 300s (5min)', () {
      expect(
        BatteryGpsManager.calculateInterval(
          privacyLevel: 'standard',
          isOffline: true,
          batteryLevel: 80,
          isSosActive: false,
        ),
        300,
      );
    });

    test('privacy_first online returns 300s (5min)', () {
      expect(
        BatteryGpsManager.calculateInterval(
          privacyLevel: 'privacy_first',
          isOffline: false,
          batteryLevel: 80,
          isSosActive: false,
        ),
        300,
      );
    });

    test('privacy_first offline returns 600s (10min)', () {
      expect(
        BatteryGpsManager.calculateInterval(
          privacyLevel: 'privacy_first',
          isOffline: true,
          batteryLevel: 80,
          isSosActive: false,
        ),
        600,
      );
    });

    // §7.3 — Battery thresholds
    test('battery <20% doubles interval', () {
      // standard online base = 60s, ×2 = 120s
      expect(
        BatteryGpsManager.calculateInterval(
          privacyLevel: 'standard',
          isOffline: false,
          batteryLevel: 15,
          isSosActive: false,
        ),
        120,
      );
    });

    test('battery <10% quadruples interval', () {
      // standard online base = 60s, ×4 = 240s
      expect(
        BatteryGpsManager.calculateInterval(
          privacyLevel: 'standard',
          isOffline: false,
          batteryLevel: 8,
          isSosActive: false,
        ),
        240,
      );
    });

    test('battery <5% also quadruples (SOS standby)', () {
      // standard online base = 60s, ×4 = 240s
      expect(
        BatteryGpsManager.calculateInterval(
          privacyLevel: 'standard',
          isOffline: false,
          batteryLevel: 3,
          isSosActive: false,
        ),
        240,
      );
    });

    test('battery exactly 20% uses normal interval (no multiplier)', () {
      expect(
        BatteryGpsManager.calculateInterval(
          privacyLevel: 'standard',
          isOffline: false,
          batteryLevel: 20,
          isSosActive: false,
        ),
        60,
      );
    });

    test('unknown privacy level defaults to standard', () {
      expect(
        BatteryGpsManager.calculateInterval(
          privacyLevel: 'unknown',
          isOffline: false,
          batteryLevel: 80,
          isSosActive: false,
        ),
        60,
      );
    });
  });

  group('BatteryGpsManager.getBatteryWarningLevel', () {
    test('returns null for battery >= 20%', () {
      expect(BatteryGpsManager.getBatteryWarningLevel(100), isNull);
      expect(BatteryGpsManager.getBatteryWarningLevel(50), isNull);
      expect(BatteryGpsManager.getBatteryWarningLevel(20), isNull);
    });

    test('returns 20 for battery 10-19%', () {
      expect(BatteryGpsManager.getBatteryWarningLevel(19), 20);
      expect(BatteryGpsManager.getBatteryWarningLevel(15), 20);
      expect(BatteryGpsManager.getBatteryWarningLevel(10), 20);
    });

    test('returns 10 for battery 5-9%', () {
      expect(BatteryGpsManager.getBatteryWarningLevel(9), 10);
      expect(BatteryGpsManager.getBatteryWarningLevel(5), 10);
    });

    test('returns 5 for battery <5%', () {
      expect(BatteryGpsManager.getBatteryWarningLevel(4), 5);
      expect(BatteryGpsManager.getBatteryWarningLevel(1), 5);
      expect(BatteryGpsManager.getBatteryWarningLevel(0), 5);
    });
  });

  group('BatteryGpsManager.getDisabledFeatures', () {
    test('online high battery disables nothing', () {
      final features = BatteryGpsManager.getDisabledFeatures(
        isOffline: false,
        batteryLevel: 80,
      );
      expect(features, isEmpty);
    });

    test('offline disables 4 features', () {
      final features = BatteryGpsManager.getDisabledFeatures(
        isOffline: true,
        batteryLevel: 80,
      );
      expect(features, containsAll([
        'realtime_location_upload',
        'ai_features',
        'mofa_api_refresh',
        'fcm_retry',
      ]));
    });

    test('low battery (<10%) adds non_emergency_features', () {
      final features = BatteryGpsManager.getDisabledFeatures(
        isOffline: false,
        batteryLevel: 8,
      );
      expect(features, contains('non_emergency_features'));
    });

    test('offline + low battery combines both lists', () {
      final features = BatteryGpsManager.getDisabledFeatures(
        isOffline: true,
        batteryLevel: 5,
      );
      expect(features, containsAll([
        'realtime_location_upload',
        'ai_features',
        'non_emergency_features',
      ]));
    });
  });
}
