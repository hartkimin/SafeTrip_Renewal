import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../../../services/api_service.dart';
import '../models/trip_card_data.dart';
import '../services/trip_card_service.dart';

/// 여행정보카드 상태
class TripCardState {
  const TripCardState({
    this.data = const TripCardViewData(),
    this.isLoading = false,
    this.error,
    this.isOffline = false,
    this.lastSyncTime,
  });

  final TripCardViewData data;
  final bool isLoading;
  final String? error;
  final bool isOffline;
  final DateTime? lastSyncTime;

  TripCardState copyWith({
    TripCardViewData? data,
    bool? isLoading,
    String? error,
    bool? isOffline,
    DateTime? lastSyncTime,
    bool clearError = false,
  }) {
    return TripCardState(
      data: data ?? this.data,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      isOffline: isOffline ?? this.isOffline,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
    );
  }
}

/// 여행정보카드 StateNotifier (DOC-T3-TIC-024)
class TripCardNotifier extends StateNotifier<TripCardState> {
  TripCardNotifier(this._service) : super(const TripCardState());

  final TripCardService _service;
  static const _cacheKey = 'trip_card_cache';

  /// 카드 데이터 fetch (§12 오프라인 캐시 포함)
  Future<void> fetchCardView() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final data = await _service.fetchCardView();
      state = state.copyWith(
        data: data,
        isLoading: false,
        isOffline: false,
        lastSyncTime: DateTime.now(),
      );
      // 캐시 저장 (§12.2)
      await _saveCache(data);
    } catch (e) {
      debugPrint('[TripCardProvider] fetchCardView error: $e');
      // 오프라인 → 캐시에서 로드
      final cached = await _loadCache();
      state = state.copyWith(
        data: cached ?? state.data,
        isLoading: false,
        isOffline: true,
        error: e.toString(),
      );
    }
  }

  /// 여행 재활성화 (§04.5, P2-1)
  Future<bool> reactivateTrip(String tripId) async {
    try {
      await _service.reactivateTrip(tripId);
      await fetchCardView(); // 갱신
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// 오프라인 캐시 저장 (§12.2: SharedPreferences, 24시간)
  Future<void> _saveCache(TripCardViewData data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheData = {
        'memberTrips': data.memberTrips.map((t) {
          return {
            'trip_id': t.tripId,
            'trip_name': t.tripName,
            'status': t.status,
            'start_date': t.startDate.toIso8601String(),
            'end_date': t.endDate.toIso8601String(),
            'trip_days': t.tripDays,
            'privacy_level': t.privacyLevel,
            'sharing_mode': t.sharingMode,
            'country_code': t.countryCode,
            'country_name': t.countryName,
            'destination_city': t.destinationCity,
            'member_count': t.memberCount,
            'user_role': t.userRole,
            'd_day': t.dDay,
            'current_day': t.currentDay,
            'can_reactivate': t.canReactivate,
            'has_minor_members': t.hasMinorMembers,
            'reactivation_count': t.reactivationCount,
          };
        }).toList(),
        'guardianTrips': data.guardianTrips.map((t) {
          return {
            'trip_id': t.tripId,
            'trip_name': t.tripName,
            'status': t.status,
            'start_date': t.startDate.toIso8601String(),
            'end_date': t.endDate.toIso8601String(),
            'member_name': t.memberName,
            'guardian_type': t.guardianType,
            'is_paid': t.isPaid,
            'location_sharing_status': t.locationSharingStatus,
            'privacy_level': t.privacyLevel,
          };
        }).toList(),
        'cached_at': DateTime.now().toIso8601String(),
      };
      await prefs.setString(_cacheKey, jsonEncode(cacheData));
    } catch (e) {
      debugPrint('[TripCardProvider] cache save error: $e');
    }
  }

  /// 캐시 로드 (24시간 유효, §12.2)
  Future<TripCardViewData?> _loadCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null) return null;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final cachedAt = DateTime.parse(json['cached_at'] as String);
      if (DateTime.now().difference(cachedAt).inHours > 24) return null;
      return TripCardViewData.fromJson(json);
    } catch (e) {
      debugPrint('[TripCardProvider] cache load error: $e');
      return null;
    }
  }
}

/// Provider
final tripCardProvider =
    StateNotifierProvider<TripCardNotifier, TripCardState>((ref) {
  return TripCardNotifier(TripCardService(ApiService()));
});
