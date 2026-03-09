import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../services/api_service.dart';
import '../../demo/providers/demo_state_provider.dart';

// ---------------------------------------------------------------------------
// DOC-T2-OFL-016 §2 — 3-State Network Detection with Healthcheck
// ---------------------------------------------------------------------------

/// §2.1 Network state classification.
enum NetworkState {
  /// Normal connectivity — all systems operational.
  online,

  /// Response > 3s or packet loss 5-20% — retry logic active, offline banner.
  degraded,

  /// No network or packet loss > 20% — full offline mode.
  offline,
}

/// Immutable snapshot of current network status.
class NetworkStatus {
  const NetworkStatus({
    required this.state,
    this.lastSyncTime,
  });

  final NetworkState state;

  /// Last time the device was confirmed online (successful healthcheck).
  final DateTime? lastSyncTime;

  bool get isOnline => state == NetworkState.online;
  bool get isDegraded => state == NetworkState.degraded;
  bool get isOffline => state == NetworkState.offline;

  NetworkStatus copyWith({
    NetworkState? state,
    DateTime? lastSyncTime,
  }) {
    return NetworkStatus(
      state: state ?? this.state,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NetworkStatus &&
          runtimeType == other.runtimeType &&
          state == other.state &&
          lastSyncTime == other.lastSyncTime;

  @override
  int get hashCode => Object.hash(state, lastSyncTime);

  @override
  String toString() =>
      'NetworkStatus(state: $state, lastSyncTime: $lastSyncTime)';
}

/// SharedPreferences key for persisting the last successful sync time.
const _kLastSyncTimeKey = 'offline_last_sync_time';

/// Healthcheck interval in seconds (§2.2).
const _kHealthcheckIntervalSeconds = 30;

// ---------------------------------------------------------------------------
// NetworkStateNotifier
// ---------------------------------------------------------------------------

/// Manages 3-state network detection per DOC-T2-OFL-016 §2.
///
/// Detection pipeline:
///   Stage 1 — OS-level connectivity via [connectivity_plus]
///   Stage 2 — HTTP healthcheck every 30 s (5 s timeout) to API `/health`
///   Stage 3 — 3 consecutive failures → offline
///
/// Transition rules (§2.3):
///   Online  → Offline  : 3 consecutive healthcheck failures
///   Offline → Online   : 1 healthcheck success (immediate)
///   Online  → Degraded : 2 consecutive failures
///   Degraded → Online  : 2 consecutive successes
class NetworkStateNotifier extends StateNotifier<NetworkStatus> {
  NetworkStateNotifier({
    ApiService? apiService,
    bool isDemoMode = false,
  })  : _apiService = apiService ?? ApiService(),
        _isDemoMode = isDemoMode,
        super(const NetworkStatus(state: NetworkState.online)) {
    // 데모 모드에서는 API 서버를 사용하지 않으므로
    // healthcheck를 건너뛰고 항상 online 상태를 유지한다.
    if (!_isDemoMode) {
      _init();
    }
  }

  final ApiService _apiService;
  final bool _isDemoMode;

  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  Timer? _healthcheckTimer;

  int _consecutiveFailures = 0;
  int _consecutiveSuccesses = 0;

  // ---------- lifecycle ----------

  void _init() {
    _loadLastSyncTime();

    // Stage 1: OS-level connectivity.
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen(_onConnectivityChanged);

    // Stage 2: periodic HTTP healthcheck.
    _healthcheckTimer = Timer.periodic(
      const Duration(seconds: _kHealthcheckIntervalSeconds),
      (_) => _runHealthcheck(),
    );

    // Run an initial healthcheck immediately.
    _runHealthcheck();
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _healthcheckTimer?.cancel();
    super.dispose();
  }

  // ---------- Stage 1: OS connectivity ----------

  void _onConnectivityChanged(ConnectivityResult result) {
    if (result == ConnectivityResult.none) {
      // No network at all — immediately go offline.
      _consecutiveFailures = 3;
      _consecutiveSuccesses = 0;
      _transitionTo(NetworkState.offline);
    } else if (state.isOffline) {
      // Network appeared — run healthcheck to confirm.
      _runHealthcheck();
    }
  }

  // ---------- Stage 2 & 3: HTTP healthcheck ----------

  Future<void> _runHealthcheck() async {
    final bool success;
    try {
      success = await _apiService.healthCheck();
    } catch (_) {
      _onHealthcheckFailure();
      return;
    }

    if (success) {
      _onHealthcheckSuccess();
    } else {
      _onHealthcheckFailure();
    }
  }

  void _onHealthcheckSuccess() {
    _consecutiveFailures = 0;
    _consecutiveSuccesses++;

    switch (state.state) {
      case NetworkState.offline:
        // §2.3: Offline → Online — 1 success (immediate).
        _consecutiveSuccesses = 0;
        _updateLastSyncTime();
        _transitionTo(NetworkState.online);
        break;
      case NetworkState.degraded:
        // §2.3: Degraded → Online — 2 consecutive successes.
        if (_consecutiveSuccesses >= 2) {
          _consecutiveSuccesses = 0;
          _updateLastSyncTime();
          _transitionTo(NetworkState.online);
        }
        break;
      case NetworkState.online:
        _updateLastSyncTime();
        break;
    }
  }

  void _onHealthcheckFailure() {
    _consecutiveSuccesses = 0;
    _consecutiveFailures++;

    switch (state.state) {
      case NetworkState.online:
        // §2.3: Online → Degraded — 2 consecutive failures.
        if (_consecutiveFailures >= 2) {
          _transitionTo(NetworkState.degraded);
        }
        break;
      case NetworkState.degraded:
        // §2.3: Online → Offline — 3 consecutive failures total.
        if (_consecutiveFailures >= 3) {
          _transitionTo(NetworkState.offline);
        }
        break;
      case NetworkState.offline:
        // Already offline — no transition needed.
        break;
    }
  }

  // ---------- State transitions ----------

  void _transitionTo(NetworkState newState) {
    if (state.state == newState) return;
    debugPrint('[NetworkState] ${state.state.name} → ${newState.name}');
    state = state.copyWith(state: newState);
  }

  // ---------- LastSyncTime persistence ----------

  Future<void> _loadLastSyncTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final millis = prefs.getInt(_kLastSyncTimeKey);
      if (millis != null) {
        state = state.copyWith(
          lastSyncTime: DateTime.fromMillisecondsSinceEpoch(millis),
        );
      }
    } catch (e) {
      debugPrint('[NetworkState] Failed to load lastSyncTime: $e');
    }
  }

  Future<void> _updateLastSyncTime() async {
    final now = DateTime.now();
    state = state.copyWith(lastSyncTime: now);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kLastSyncTimeKey, now.millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('[NetworkState] Failed to persist lastSyncTime: $e');
    }
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

/// Primary provider — exposes full [NetworkStatus] with 3-state detection.
/// 데모 모드 시 healthcheck를 비활성화하여 항상 online 상태를 반환한다.
final networkStateProvider =
    StateNotifierProvider<NetworkStateNotifier, NetworkStatus>(
  (ref) {
    final isDemoMode = ref.watch(isDemoModeProvider);
    return NetworkStateNotifier(isDemoMode: isDemoMode);
  },
);

/// OS-level connectivity stream (kept for backward compatibility).
final connectivityProvider = StreamProvider<ConnectivityResult>((ref) {
  return Connectivity().onConnectivityChanged;
});

/// Simple offline boolean — derives from [networkStateProvider].
/// Maintained for backward compatibility with existing consumers.
final isOfflineProvider = Provider<bool>((ref) {
  final status = ref.watch(networkStateProvider);
  return status.isOffline;
});
