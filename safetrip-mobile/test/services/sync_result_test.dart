import 'package:flutter_test/flutter_test.dart';
import 'package:safetrip_mobile/services/offline_sync_service.dart';

void main() {
  group('SyncResult', () {
    test('empty() returns zero counts', () {
      final result = SyncResult.empty();
      expect(result.synced, 0);
      expect(result.failed, 0);
      expect(result.total, 0);
      expect(result.hasFailures, false);
    });

    test('all synced has no failures', () {
      const result = SyncResult(synced: 10, failed: 0);
      expect(result.total, 10);
      expect(result.hasFailures, false);
    });

    test('partial failure reports hasFailures', () {
      const result = SyncResult(synced: 5, failed: 3);
      expect(result.total, 8);
      expect(result.hasFailures, true);
    });

    test('all failed reports hasFailures', () {
      const result = SyncResult(synced: 0, failed: 5);
      expect(result.total, 5);
      expect(result.hasFailures, true);
    });
  });
}
