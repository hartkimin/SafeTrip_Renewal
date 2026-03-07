import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/movement_history_data.dart';
import '../models/timeline_event.dart';
import '../models/session_stats.dart';
import '../services/movement_history_service.dart';

class MovementHistoryState {
  final bool isLoading;
  final String? error;
  final String selectedDate;
  final MovementHistoryData? historyData;
  final List<TimelineEvent> timelineEvents;
  final SessionStats? sessionStats;
  final int? selectedEventIndex;
  final bool upgradeRequired;
  final String viewMode; // 'timeline' | 'map'

  const MovementHistoryState({
    this.isLoading = false,
    this.error,
    this.selectedDate = '',
    this.historyData,
    this.timelineEvents = const [],
    this.sessionStats,
    this.selectedEventIndex,
    this.upgradeRequired = false,
    this.viewMode = 'timeline',
  });

  MovementHistoryState copyWith({
    bool? isLoading,
    String? error,
    String? selectedDate,
    MovementHistoryData? historyData,
    List<TimelineEvent>? timelineEvents,
    SessionStats? sessionStats,
    int? selectedEventIndex,
    bool? upgradeRequired,
    String? viewMode,
  }) {
    return MovementHistoryState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      selectedDate: selectedDate ?? this.selectedDate,
      historyData: historyData ?? this.historyData,
      timelineEvents: timelineEvents ?? this.timelineEvents,
      sessionStats: sessionStats ?? this.sessionStats,
      selectedEventIndex: selectedEventIndex ?? this.selectedEventIndex,
      upgradeRequired: upgradeRequired ?? this.upgradeRequired,
      viewMode: viewMode ?? this.viewMode,
    );
  }
}

class MovementHistoryNotifier extends StateNotifier<MovementHistoryState> {
  final MovementHistoryService _service;
  final String tripId;
  final String targetUserId;

  MovementHistoryNotifier({
    required this.tripId,
    required this.targetUserId,
    MovementHistoryService? service,
  })  : _service = service ?? MovementHistoryService(),
        super(const MovementHistoryState());

  /// 특정 날짜의 이동기록 + 타임라인 로드
  Future<void> loadHistory(String date) async {
    state = state.copyWith(isLoading: true, error: null, selectedDate: date);
    try {
      final history = await _service.getMemberMovementHistory(
        tripId: tripId, targetUserId: targetUserId, date: date,
      );

      if (history.upgradeRequired) {
        state = state.copyWith(
          isLoading: false,
          historyData: history,
          upgradeRequired: true,
        );
        return;
      }

      final timeline = await _service.getMemberTimeline(
        tripId: tripId, targetUserId: targetUserId, date: date,
      );

      state = state.copyWith(
        isLoading: false,
        historyData: history,
        timelineEvents: timeline,
        upgradeRequired: false,
      );
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      String errorMsg = '이동기록을 불러올 수 없습니다.';

      if (statusCode == 403) {
        final code = e.response?.data?['code'];
        if (code == 'upgrade_required') {
          state = state.copyWith(isLoading: false, upgradeRequired: true);
          return;
        }
        errorMsg = e.response?.data?['message'] ?? '접근 권한이 없습니다.';
      } else if (statusCode == 404) {
        errorMsg = '이동기록 보존 기간이 만료되었습니다.';
      }
      state = state.copyWith(isLoading: false, error: errorMsg);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// 세션 통계 로드
  Future<void> loadSessionStats(String sessionId) async {
    try {
      final stats = await _service.getSessionStats(
        tripId: tripId, targetUserId: targetUserId, sessionId: sessionId,
      );
      state = state.copyWith(sessionStats: stats);
    } catch (_) {}
  }

  /// 타임라인 이벤트 선택 (양방향 연동)
  void selectEvent(int index) {
    state = state.copyWith(selectedEventIndex: index);
  }

  /// 뷰 모드 전환
  void toggleViewMode() {
    state = state.copyWith(
      viewMode: state.viewMode == 'timeline' ? 'map' : 'timeline',
    );
  }
}

final movementHistoryProvider = StateNotifierProvider.autoDispose
    .family<MovementHistoryNotifier, MovementHistoryState, ({String tripId, String targetUserId})>(
  (ref, params) {
    return MovementHistoryNotifier(
      tripId: params.tripId,
      targetUserId: params.targetUserId,
    );
  },
);
