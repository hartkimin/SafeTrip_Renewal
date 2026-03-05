import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/trip_group.dart';
import '../../../models/trip.dart';
import '../../../services/api_service.dart';

class TripState {
  TripState({
    this.isLoading = false,
    this.error,
    this.myGroups = const [],
    this.currentGroup,
    this.currentTrip,
    this.userTrips = const [],
    this.currentTripName = '',
    this.currentTripStatus = 'active',
    this.currentUserRole = 'crew',
    this.tripImageUrl,
    this.tripStartDate,
    this.tripEndDate,
    this.destinationTimezone,
    this.destinationName,
    this.countryCode,
    this.countryName,
    this.userProfileImageUrl,
    this.totalMemberCount = 0,
    this.guardianCount = 0,
  });
  final bool isLoading;
  final String? error;
  final List<TripGroup> myGroups;
  final TripGroup? currentGroup;
  final Trip? currentTrip;

  // ==== Global Trip Data ====
  final List<Trip> userTrips;
  final String currentTripName;
  final String currentTripStatus;
  final String currentUserRole;
  final String? tripImageUrl;
  final DateTime? tripStartDate;
  final DateTime? tripEndDate;
  final String? destinationTimezone;
  final String? destinationName;
  final String? countryCode;
  final String? countryName;
  final String? userProfileImageUrl;
  final int totalMemberCount;
  final int guardianCount;

  TripState copyWith({
    bool? isLoading,
    String? error,
    List<TripGroup>? myGroups,
    TripGroup? currentGroup,
    Trip? currentTrip,
    List<Trip>? userTrips,
    String? currentTripName,
    String? currentTripStatus,
    String? currentUserRole,
    String? tripImageUrl,
    DateTime? tripStartDate,
    DateTime? tripEndDate,
    String? destinationTimezone,
    String? destinationName,
    String? countryCode,
    String? countryName,
    String? userProfileImageUrl,
    int? totalMemberCount,
    int? guardianCount,
    bool clearError = false,
  }) {
    return TripState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      myGroups: myGroups ?? this.myGroups,
      currentGroup: currentGroup ?? this.currentGroup,
      currentTrip: currentTrip ?? this.currentTrip,
      userTrips: userTrips ?? this.userTrips,
      currentTripName: currentTripName ?? this.currentTripName,
      currentTripStatus: currentTripStatus ?? this.currentTripStatus,
      currentUserRole: currentUserRole ?? this.currentUserRole,
      tripImageUrl: tripImageUrl ?? this.tripImageUrl,
      tripStartDate: tripStartDate ?? this.tripStartDate,
      tripEndDate: tripEndDate ?? this.tripEndDate,
      destinationTimezone: destinationTimezone ?? this.destinationTimezone,
      destinationName: destinationName ?? this.destinationName,
      countryCode: countryCode ?? this.countryCode,
      countryName: countryName ?? this.countryName,
      userProfileImageUrl: userProfileImageUrl ?? this.userProfileImageUrl,
      totalMemberCount: totalMemberCount ?? this.totalMemberCount,
      guardianCount: guardianCount ?? this.guardianCount,
    );
  }
}

class TripNotifier extends StateNotifier<TripState> {
  TripNotifier(this._apiService) : super(TripState());

  final ApiService _apiService;

  Future<void> fetchMyGroups() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final data = await _apiService.getGroups();
      final groups = data.map((e) => TripGroup.fromJson(e)).toList();
      state = state.copyWith(isLoading: false, myGroups: groups);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> createGroup(String name, String? description) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final res = await _apiService.createGroup({
        'name': name,
        'description': description,
        'country_code': 'KR', // 기본값 (기획에 따라 변경될 수 있음)
      });
      final newGroup = TripGroup.fromJson(res['data'] ?? res);
      state = state.copyWith(
        isLoading: false,
        myGroups: [...state.myGroups, newGroup],
        currentGroup: newGroup,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> fetchTripsForGroup(String groupId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final data = await _apiService.getTrips(groupId);
      final trips = data.map((e) => Trip.fromJson(e)).toList();

      // 현재 진행중인 여행이 있다면 currentTrip으로 설정
      final activeTrip = trips
          .where(
            (t) =>
                t.status == TripStatus.active ||
                t.status == TripStatus.planning,
          )
          .firstOrNull;

      state = state.copyWith(isLoading: false, currentTrip: activeTrip);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> createTrip({
    required String title,
    required String countryCode,
    required String tripType,
    required DateTime startDate,
    required DateTime endDate,
    String? countryName,
    String? privacyLevel,
    String? sharingMode,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _apiService.createTrip(
        title: title,
        countryCode: countryCode,
        tripType: tripType,
        startDate: startDate.toIso8601String(),
        endDate: endDate.toIso8601String(),
        countryName: countryName,
        privacyLevel: privacyLevel,
        sharingMode: sharingMode,
      );
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void selectGroup(TripGroup group) {
    state = state.copyWith(currentGroup: group, clearError: true);
    fetchTripsForGroup(group.groupId); // 그룹 선택 시 해당 그룹의 여행 데이터를 가져옴
  }

  void setUserTrips(List<Trip> trips) {
    state = state.copyWith(userTrips: trips);
  }

  void setCurrentTripDetails({
    required String tripName,
    String tripStatus = 'active',
    required String userRole,
    String? tripImageUrl,
    DateTime? tripStartDate,
    DateTime? tripEndDate,
    String? destinationTimezone,
    String? destinationName,
    String? countryCode,
    String? countryName,
    String? userProfileImageUrl,
    int totalMemberCount = 0,
    int guardianCount = 0,
  }) {
    state = state.copyWith(
      currentTripName: tripName,
      currentTripStatus: tripStatus,
      currentUserRole: userRole,
      tripImageUrl: tripImageUrl,
      tripStartDate: tripStartDate,
      tripEndDate: tripEndDate,
      destinationTimezone: destinationTimezone,
      destinationName: destinationName,
      countryCode: countryCode,
      countryName: countryName,
      userProfileImageUrl: userProfileImageUrl,
      totalMemberCount: totalMemberCount,
      guardianCount: guardianCount,
    );
  }
}

// Provider
final tripProvider = StateNotifierProvider<TripNotifier, TripState>((ref) {
  return TripNotifier(ApiService());
});
