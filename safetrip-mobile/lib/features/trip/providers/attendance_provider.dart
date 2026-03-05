import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/attendance.dart';
import '../../../services/api_service.dart';

class AttendanceState {
  AttendanceState({
    this.isLoading = false,
    this.error,
    this.currentCheck,
    this.history = const [],
  });
  final bool isLoading;
  final String? error;
  final AttendanceCheck? currentCheck;
  final List<AttendanceCheck> history;

  AttendanceState copyWith({
    bool? isLoading,
    String? error,
    AttendanceCheck? currentCheck,
    List<AttendanceCheck>? history,
    bool clearError = false,
  }) {
    return AttendanceState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      currentCheck: currentCheck ?? this.currentCheck,
      history: history ?? this.history,
    );
  }
}

class AttendanceNotifier extends StateNotifier<AttendanceState> {
  AttendanceNotifier(this._apiService) : super(AttendanceState());

  final ApiService _apiService;

  Future<void> fetchAttendances(String tripId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final res = await _apiService.getAttendances(tripId);
      final list = res.map((e) => AttendanceCheck.fromJson(e)).toList();

      // Find active check (status == 'active')
      final active = list
          .where((a) => a.status == AttendanceStatus.ongoing)
          .firstOrNull;

      state = state.copyWith(
        isLoading: false,
        history: list,
        currentCheck: active,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> startAttendance(String tripId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final res = await _apiService.startAttendance(tripId);
      final newCheck = AttendanceCheck.fromJson(res['data'] ?? res);
      state = state.copyWith(
        isLoading: false,
        currentCheck: newCheck,
        history: [newCheck, ...state.history],
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> respondAttendance(
    String tripId,
    String checkId,
    String responseType,
  ) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _apiService.respondAttendance(tripId, checkId, responseType);
      // Reload attendances to get updated list of responses
      await fetchAttendances(tripId);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> closeAttendance(String tripId, String checkId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _apiService.closeAttendance(tripId, checkId);
      await fetchAttendances(tripId); // update UI
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final attendanceProvider =
    StateNotifierProvider<AttendanceNotifier, AttendanceState>((ref) {
      return AttendanceNotifier(ApiService());
    });
