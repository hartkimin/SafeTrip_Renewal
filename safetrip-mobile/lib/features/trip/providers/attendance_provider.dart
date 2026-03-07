import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/attendance.dart';
import '../../../services/api_service.dart';

class AttendanceState {
  AttendanceState({
    this.isLoading = false,
    this.error,
    this.currentCheck,
    this.history = const [],
    this.presentCount = 0,
    this.absentCount = 0,
    this.unknownCount = 0,
  });
  final bool isLoading;
  final String? error;
  final AttendanceCheck? currentCheck;
  final List<AttendanceCheck> history;
  final int presentCount;
  final int absentCount;
  final int unknownCount;

  AttendanceState copyWith({
    bool? isLoading,
    String? error,
    AttendanceCheck? currentCheck,
    List<AttendanceCheck>? history,
    int? presentCount,
    int? absentCount,
    int? unknownCount,
    bool clearError = false,
  }) {
    return AttendanceState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      currentCheck: currentCheck ?? this.currentCheck,
      history: history ?? this.history,
      presentCount: presentCount ?? this.presentCount,
      absentCount: absentCount ?? this.absentCount,
      unknownCount: unknownCount ?? this.unknownCount,
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

  Future<void> fetchResponses(String tripId, String checkId) async {
    try {
      final responses =
          await _apiService.getAttendanceResponses(tripId, checkId);
      int present = 0, absent = 0, unknown = 0;
      for (final r in responses) {
        switch (r['response_type']) {
          case 'present':
            present++;
            break;
          case 'absent':
            absent++;
            break;
          default:
            unknown++;
            break;
        }
      }
      state = state.copyWith(
        presentCount: present,
        absentCount: absent,
        unknownCount: unknown,
      );
    } catch (e) {
      debugPrint('[AttendanceNotifier] fetchResponses error: $e');
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
