import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/schedule.dart';
import '../../../services/api_service.dart';
import '../../../widgets/schedule/share_timeline_bar.dart';

class ScheduleState {
  const ScheduleState({
    this.isLoading = false,
    this.error,
    this.schedules = const [],
    this.selectedDate,
    this.scheduleDates = const [],
    this.tripStartDate,
    this.tripEndDate,
    this.privacyLevel = 'standard',
    this.userRole = 'crew',
    this.tripStatus = 'active',
    this.tripId,
    this.shareTimelineSegments = const [],
  });

  final bool isLoading;
  final String? error;
  final List<Schedule> schedules;
  final DateTime? selectedDate;
  final List<String> scheduleDates;
  final DateTime? tripStartDate;
  final DateTime? tripEndDate;
  final String privacyLevel;
  final String userRole;
  final String tripStatus;
  final String? tripId;
  final List<TimelineSegment> shareTimelineSegments;

  bool get canEdit =>
      (userRole == 'captain' || userRole == 'crew_chief') &&
      tripStatus != 'completed';

  bool get showPrivacyBanner => privacyLevel == 'privacy_first';
  bool get showShareTimeline => privacyLevel == 'privacy_first';

  List<DateTime> get tripDates {
    if (tripStartDate == null || tripEndDate == null) return [];
    final dates = <DateTime>[];
    var current = tripStartDate!;
    while (!current.isAfter(tripEndDate!) && dates.length < 15) {
      dates.add(current);
      current = current.add(const Duration(days: 1));
    }
    return dates;
  }

  ScheduleState copyWith({
    bool? isLoading,
    String? error,
    List<Schedule>? schedules,
    DateTime? selectedDate,
    List<String>? scheduleDates,
    DateTime? tripStartDate,
    DateTime? tripEndDate,
    String? privacyLevel,
    String? userRole,
    String? tripStatus,
    String? tripId,
    List<TimelineSegment>? shareTimelineSegments,
  }) {
    return ScheduleState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      schedules: schedules ?? this.schedules,
      selectedDate: selectedDate ?? this.selectedDate,
      scheduleDates: scheduleDates ?? this.scheduleDates,
      tripStartDate: tripStartDate ?? this.tripStartDate,
      tripEndDate: tripEndDate ?? this.tripEndDate,
      privacyLevel: privacyLevel ?? this.privacyLevel,
      userRole: userRole ?? this.userRole,
      tripStatus: tripStatus ?? this.tripStatus,
      tripId: tripId ?? this.tripId,
      shareTimelineSegments:
          shareTimelineSegments ?? this.shareTimelineSegments,
    );
  }
}

class ScheduleNotifier extends StateNotifier<ScheduleState> {
  ScheduleNotifier(this._apiService) : super(const ScheduleState());
  final ApiService _apiService;

  void setTripContext({
    required String tripId,
    required DateTime startDate,
    required DateTime endDate,
    required String privacyLevel,
    required String userRole,
    required String tripStatus,
  }) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);

    state = state.copyWith(
      tripId: tripId,
      tripStartDate: start,
      tripEndDate: end,
      privacyLevel: privacyLevel,
      userRole: userRole,
      tripStatus: tripStatus,
      selectedDate: today.isAfter(start) &&
              today.isBefore(end.add(const Duration(days: 1)))
          ? today
          : start,
    );
    fetchScheduleDates();
    fetchSchedules();
    fetchShareTimeline();
  }

  void selectDate(DateTime date) {
    state = state.copyWith(
        selectedDate: DateTime(date.year, date.month, date.day));
    fetchSchedules();
    fetchShareTimeline();
  }

  /// privacy_first 모드일 때 공유 타임라인 세그먼트를 서버에서 가져온다.
  Future<void> fetchShareTimeline() async {
    if (state.tripId == null || state.selectedDate == null) return;
    if (state.privacyLevel != 'privacy_first') return;
    try {
      final d = state.selectedDate!;
      final dateStr =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      final result = await _apiService.dio.get(
        '/api/v1/trips/${state.tripId}/schedules/share-timeline',
        queryParameters: {'date': dateStr},
      );
      if (result.data?['success'] == true) {
        final data = result.data['data'];
        final segmentsList =
            data is Map ? (data['segments'] ?? []) : [];
        final segments = (segmentsList as List)
            .map((e) =>
                TimelineSegment.fromJson(e as Map<String, dynamic>))
            .toList();
        state = state.copyWith(shareTimelineSegments: segments);
      }
    } catch (_) {
      // 타임라인 로드 실패 시 빈 목록 유지
    }
  }

  Future<void> fetchScheduleDates() async {
    if (state.tripId == null) return;
    try {
      final result = await _apiService.dio.get(
        '/api/v1/trips/${state.tripId}/schedules/dates',
      );
      if (result.data?['success'] == true) {
        final data = result.data['data'];
        // Server returns { data: { dates: [...] } }
        final datesList = data is Map ? (data['dates'] ?? []) : (data ?? []);
        final dates = List<String>.from(datesList);
        state = state.copyWith(scheduleDates: dates);
      }
    } catch (_) {}
  }

  Future<void> fetchSchedules() async {
    if (state.tripId == null || state.selectedDate == null) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final d = state.selectedDate!;
      final dateStr =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      final result = await _apiService.dio.get(
        '/api/v1/trips/${state.tripId}/schedules',
        queryParameters: {'date': dateStr},
      );
      if (result.data?['success'] == true) {
        final data = result.data['data'];
        // Server returns { data: { schedules: [...], total: N } }
        final schedulesList = data is Map ? (data['schedules'] ?? []) : (data ?? []);
        final list = (schedulesList as List)
                .map((e) => Schedule.fromJson(e as Map<String, dynamic>))
                .toList();
        list.sort((a, b) => a.startTime.compareTo(b.startTime));
        state = state.copyWith(schedules: list, isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: '일정을 불러올 수 없습니다. 다시 시도해 주세요',
      );
    }
  }

  Future<bool> deleteSchedule(String scheduleId) async {
    if (state.tripId == null) return false;
    try {
      final result = await _apiService.dio.delete(
        '/api/v1/trips/${state.tripId}/schedules/$scheduleId',
      );
      if (result.data?['success'] == true) {
        await fetchSchedules();
        await fetchScheduleDates();
        return true;
      }
    } catch (_) {}
    return false;
  }
}

final scheduleProvider =
    StateNotifierProvider<ScheduleNotifier, ScheduleState>((ref) {
  return ScheduleNotifier(ApiService());
});
