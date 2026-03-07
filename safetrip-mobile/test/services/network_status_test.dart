import 'package:flutter_test/flutter_test.dart';
import 'package:safetrip_mobile/features/main/providers/connectivity_provider.dart';

void main() {
  group('NetworkStatus', () {
    test('isOnline returns true for online state', () {
      const status = NetworkStatus(state: NetworkState.online);
      expect(status.isOnline, true);
      expect(status.isDegraded, false);
      expect(status.isOffline, false);
    });

    test('isDegraded returns true for degraded state', () {
      const status = NetworkStatus(state: NetworkState.degraded);
      expect(status.isOnline, false);
      expect(status.isDegraded, true);
      expect(status.isOffline, false);
    });

    test('isOffline returns true for offline state', () {
      const status = NetworkStatus(state: NetworkState.offline);
      expect(status.isOnline, false);
      expect(status.isDegraded, false);
      expect(status.isOffline, true);
    });

    test('copyWith preserves unchanged fields', () {
      final now = DateTime.now();
      final status = NetworkStatus(
        state: NetworkState.online,
        lastSyncTime: now,
      );
      final updated = status.copyWith(state: NetworkState.degraded);
      expect(updated.state, NetworkState.degraded);
      expect(updated.lastSyncTime, now);
    });

    test('copyWith updates lastSyncTime', () {
      const status = NetworkStatus(state: NetworkState.online);
      final now = DateTime.now();
      final updated = status.copyWith(lastSyncTime: now);
      expect(updated.state, NetworkState.online);
      expect(updated.lastSyncTime, now);
    });

    test('equality works for same state', () {
      const a = NetworkStatus(state: NetworkState.online);
      const b = NetworkStatus(state: NetworkState.online);
      expect(a, equals(b));
    });

    test('equality fails for different states', () {
      const a = NetworkStatus(state: NetworkState.online);
      const b = NetworkStatus(state: NetworkState.offline);
      expect(a, isNot(equals(b)));
    });

    test('hashCode is consistent with equality', () {
      const a = NetworkStatus(state: NetworkState.online);
      const b = NetworkStatus(state: NetworkState.online);
      expect(a.hashCode, equals(b.hashCode));
    });

    test('toString includes state', () {
      const status = NetworkStatus(state: NetworkState.degraded);
      expect(status.toString(), contains('degraded'));
    });
  });

  group('NetworkState enum', () {
    test('has 3 values', () {
      expect(NetworkState.values.length, 3);
    });

    test('contains expected values', () {
      expect(NetworkState.values, containsAll([
        NetworkState.online,
        NetworkState.degraded,
        NetworkState.offline,
      ]));
    });
  });
}
