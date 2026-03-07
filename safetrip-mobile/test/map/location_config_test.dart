import 'package:flutter_test/flutter_test.dart';
import 'package:safetrip_mobile/constants/location_config.dart';

void main() {
  group('LocationConfig', () {
    test('offlineThresholdMinutes는 §7.1 기준 5분이어야 한다', () {
      expect(LocationConfig.offlineThresholdMinutes, equals(5));
    });
  });
}
