import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/trip_member.dart';
import '../../../models/user.dart';
import '../../../services/api_service.dart';

// =============================================================================
// MemberTabState
// =============================================================================

class MemberTabState {
  const MemberTabState({
    this.isLoading = false,
    this.error,
    this.allMembers = const [],
    this.guardianSlots = const [],
    this.currentUserId,
    this.currentUserRole,
    this.isB2bTrip = false,
    this.tripId,
    this.groupId,
    this.totalMemberCount = 0,
    this.isPaidTrip = false,
    this.isOfflineMode = false,
    this.lastSyncAt,
  });

  final bool isLoading;
  final String? error;
  final List<TripMember> allMembers;
  final List<GuardianSlot> guardianSlots;
  final String? currentUserId;
  final UserRole? currentUserRole;
  final bool isB2bTrip;
  final String? tripId;
  final String? groupId;
  final int totalMemberCount;
  final bool isPaidTrip;
  final bool isOfflineMode;
  final DateTime? lastSyncAt;

  // ---------------------------------------------------------------------------
  // Computed Getters
  // ---------------------------------------------------------------------------

  /// 관리자 목록 (captain + crew_chief), 정렬 적용
  List<TripMember> get adminMembers {
    final admins = allMembers
        .where((m) =>
            m.memberRole == UserRole.captain ||
            m.memberRole == UserRole.crewChief)
        .toList();
    _sortMembers(admins);
    return admins;
  }

  /// 크루 목록 (crew만), 정렬 적용
  List<TripMember> get crewMembers {
    final crews =
        allMembers.where((m) => m.memberRole == UserRole.crew).toList();
    _sortMembers(crews);
    return crews;
  }

  /// SOS 활성 멤버 목록
  List<TripMember> get sosMembersList =>
      allMembers.where((m) => m.isSosActive).toList();

  /// 오프라인 멤버 목록 (SOS 활성이 아닌 오프라인 멤버)
  List<TripMember> get offlineMembers =>
      allMembers.where((m) => !m.isOnline && !m.isSosActive).toList();

  /// SOS 알림 존재 여부
  bool get hasSosAlert => allMembers.any((m) => m.isSosActive);

  /// 오프라인 알림 존재 여부
  bool get hasOfflineAlert =>
      allMembers.any((m) => !m.isOnline && !m.isSosActive);

  /// 출석 시작 가능 여부 (유료 여행 + 6명 이상)
  bool get canStartAttendance => isPaidTrip && totalMemberCount >= 6;

  /// 현재 사용자가 캡틴인지
  bool get isCaptain => currentUserRole == UserRole.captain;

  /// 현재 사용자가 관리자(captain 또는 crewChief)인지
  bool get isAdmin => currentUserRole?.isAdmin ?? false;

  // ---------------------------------------------------------------------------
  // Sorting (SS7.1)
  // ---------------------------------------------------------------------------

  /// 멤버 정렬: SOS > 역할 순서 > 온라인 > 이름 가나다순
  static void _sortMembers(List<TripMember> members) {
    members.sort((a, b) {
      // 1. SOS 활성 우선
      if (a.isSosActive != b.isSosActive) {
        return a.isSosActive ? -1 : 1;
      }

      // 2. 역할 순서: captain(0) > crew_chief(1) > crew(2) > guardian(3)
      final roleOrder = _roleOrder(a.memberRole) - _roleOrder(b.memberRole);
      if (roleOrder != 0) return roleOrder;

      // 3. 온라인 우선
      if (a.isOnline != b.isOnline) {
        return a.isOnline ? -1 : 1;
      }

      // 4. 이름 가나다순
      return a.userName.compareTo(b.userName);
    });
  }

  static int _roleOrder(UserRole role) {
    switch (role) {
      case UserRole.captain:
        return 0;
      case UserRole.crewChief:
        return 1;
      case UserRole.crew:
        return 2;
      case UserRole.guardian:
        return 3;
    }
  }

  // ---------------------------------------------------------------------------
  // copyWith
  // ---------------------------------------------------------------------------

  MemberTabState copyWith({
    bool? isLoading,
    String? error,
    List<TripMember>? allMembers,
    List<GuardianSlot>? guardianSlots,
    String? currentUserId,
    UserRole? currentUserRole,
    bool? isB2bTrip,
    String? tripId,
    String? groupId,
    int? totalMemberCount,
    bool? isPaidTrip,
    bool? isOfflineMode,
    DateTime? lastSyncAt,
    bool clearError = false,
  }) {
    return MemberTabState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      allMembers: allMembers ?? this.allMembers,
      guardianSlots: guardianSlots ?? this.guardianSlots,
      currentUserId: currentUserId ?? this.currentUserId,
      currentUserRole: currentUserRole ?? this.currentUserRole,
      isB2bTrip: isB2bTrip ?? this.isB2bTrip,
      tripId: tripId ?? this.tripId,
      groupId: groupId ?? this.groupId,
      totalMemberCount: totalMemberCount ?? this.totalMemberCount,
      isPaidTrip: isPaidTrip ?? this.isPaidTrip,
      isOfflineMode: isOfflineMode ?? this.isOfflineMode,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
    );
  }
}

// =============================================================================
// MemberTabNotifier
// =============================================================================

class MemberTabNotifier extends StateNotifier<MemberTabState> {
  MemberTabNotifier(this._apiService) : super(const MemberTabState());

  final ApiService _apiService;

  // ---------------------------------------------------------------------------
  // Initialize
  // ---------------------------------------------------------------------------

  /// 멤버 탭 초기화: 기본 상태 설정 후 멤버 목록 조회
  Future<void> initialize({
    required String groupId,
    required String tripId,
    required String currentUserId,
    required UserRole currentUserRole,
    bool isB2bTrip = false,
    bool isPaidTrip = false,
  }) async {
    state = state.copyWith(
      groupId: groupId,
      tripId: tripId,
      currentUserId: currentUserId,
      currentUserRole: currentUserRole,
      isB2bTrip: isB2bTrip,
      isPaidTrip: isPaidTrip,
      clearError: true,
    );
    await fetchMembers();
  }

  // ---------------------------------------------------------------------------
  // Fetch Members
  // ---------------------------------------------------------------------------

  /// 서버에서 그룹 멤버 목록을 조회하여 상태 갱신
  Future<void> fetchMembers() async {
    final groupId = state.groupId;
    if (groupId == null || groupId.isEmpty) {
      state = state.copyWith(error: 'groupId가 설정되지 않았습니다.');
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final data = await _apiService.getGroupMembers(groupId);
      final members = data.map((e) => TripMember.fromJson(e)).toList();

      // 가디언 슬롯 집계: 전체 멤버의 guardianLinks를 평탄화
      final allGuardianSlots =
          members.expand((m) => m.guardianLinks).toList();

      state = state.copyWith(
        isLoading: false,
        allMembers: members,
        guardianSlots: allGuardianSlots,
        totalMemberCount: members.length,
        lastSyncAt: DateTime.now(),
      );
    } catch (e) {
      debugPrint('[MemberTabNotifier] fetchMembers Error: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  // ---------------------------------------------------------------------------
  // Real-time Presence Update
  // ---------------------------------------------------------------------------

  /// 개별 멤버의 실시간 상태를 갱신 (RTDB 리스너에서 호출)
  void updateMemberPresence(
    String userId, {
    bool? isOnline,
    int? battery,
    bool? isSos,
    String? locationText,
    DateTime? locationUpdatedAt,
  }) {
    final updatedMembers = state.allMembers.map((member) {
      if (member.userId != userId) return member;
      return member.copyWith(
        isOnline: isOnline,
        batteryLevel: battery,
        isSosActive: isSos,
        lastLocationText: locationText,
        lastLocationUpdatedAt: locationUpdatedAt,
      );
    }).toList();

    state = state.copyWith(allMembers: updatedMembers);
  }

  // ---------------------------------------------------------------------------
  // Offline Mode
  // ---------------------------------------------------------------------------

  /// 오프라인 모드 전환
  void setOfflineMode(bool offline) {
    state = state.copyWith(isOfflineMode: offline);
  }
}

// =============================================================================
// Provider
// =============================================================================

final memberTabProvider =
    StateNotifierProvider<MemberTabNotifier, MemberTabState>((ref) {
  return MemberTabNotifier(ApiService());
});
