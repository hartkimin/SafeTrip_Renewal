# 여행정보카드 (Travel Info Card) Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement the complete 여행정보카드 feature (P0~P3, 21 features) per DOC-T3-TIC-024 v1.0, replacing the existing `TopTripInfoCard` with a Strategy-pattern based system that supports status-based card variants, guardian cards, trip switching, offline mode, and all edge cases.

**Architecture:** Strategy pattern — `TripInfoCardSection` container delegates rendering to status-specific content widgets (`PlanningCardContent`, `ActiveCardContent`, `CompletedCardContent`) and guardian-specific widgets. A dedicated `TripCardProvider` fetches data from a new `GET /trips/card-view` API backed by a `TB_TRIP_CARD_VIEW` SQL view.

**Tech Stack:** Flutter/Dart (Riverpod), NestJS/TypeScript (TypeORM), PostgreSQL, SharedPreferences (cache)

**Architecture Principle Reference:** `Master_docs/24_T3_여행정보카드_원칙.md` — C1(여행 컨텍스트 최우선), C2(최소 정보 노출), C3(상태 기반 UI), C4(빠른 접근성), C5(가디언 정보 분리)

---

## Task 1: DB Migration — TB_TRIP_CARD_VIEW SQL View

**Files:**
- Create: `safetrip-server-api/sql/17-view-trip-card.sql`

**Step 1: Write the migration SQL**

```sql
-- 17-view-trip-card.sql
-- TB_TRIP_CARD_VIEW: 여행정보카드 렌더링 전용 뷰 (DOC-T3-TIC-024 §11.3)

CREATE OR REPLACE VIEW tb_trip_card_view AS
SELECT
    t.trip_id,
    t.trip_name,
    t.status,
    t.start_date,
    t.end_date,
    t.end_date - t.start_date                          AS trip_days,
    t.privacy_level,
    t.sharing_mode,
    t.schedule_type,
    t.country_code,
    t.country_name,
    t.destination_city,
    t.has_minor_members,
    t.reactivated_at,
    t.reactivation_count,
    t.group_id,
    t.updated_at,
    -- D-day 계산 (§03.2)
    CASE
        WHEN t.status = 'active'    THEN 0
        WHEN t.status = 'planning'  THEN (t.start_date - CURRENT_DATE)
        ELSE NULL
    END                                                 AS d_day,
    -- 현재 진행 일차
    CASE
        WHEN t.status = 'active'
            THEN (CURRENT_DATE - t.start_date + 1)
        ELSE NULL
    END                                                 AS current_day,
    -- 활성 멤버 수 (가디언 제외)
    (
        SELECT COUNT(*)
        FROM tb_group_member gm
        WHERE gm.trip_id = t.trip_id
          AND gm.status = 'active'
          AND gm.member_role IN ('captain', 'crew_chief', 'crew')
    )                                                   AS member_count,
    -- 재활성화 가능 여부 (§04.5: 종료 후 24시간 이내 + 0회)
    CASE
        WHEN t.status = 'completed'
         AND t.reactivation_count = 0
         AND t.updated_at > NOW() - INTERVAL '24 hours'
            THEN TRUE
        ELSE FALSE
    END                                                 AS can_reactivate
FROM tb_trip t
WHERE t.deleted_at IS NULL;
```

**Step 2: Apply migration to dev DB**

Run: `cd safetrip-server-api && psql -U postgres -d safetrip -f sql/17-view-trip-card.sql`
Expected: `CREATE VIEW` success message

**Step 3: Verify the view works**

Run: `psql -U postgres -d safetrip -c "SELECT * FROM tb_trip_card_view LIMIT 3;"`
Expected: Rows from tb_trip with computed columns (d_day, current_day, member_count, can_reactivate)

**Step 4: Commit**

```
git add safetrip-server-api/sql/17-view-trip-card.sql
git commit -m "feat(db): add TB_TRIP_CARD_VIEW SQL view (§11.3 아키텍처 원칙 적용)"
```

---

## Task 2: Backend — Card View API Endpoint

**Files:**
- Modify: `safetrip-server-api/src/modules/trips/trips.controller.ts`
- Modify: `safetrip-server-api/src/modules/trips/trips.service.ts`

**Step 1: Add `getCardView()` method to TripsService**

Add before the `getUserTrips` method in `trips.service.ts`:

```typescript
/**
 * GET /trips/card-view — 여행정보카드 전용 데이터 조회
 * TB_TRIP_CARD_VIEW + 가디언 여행 + 오늘 일정 요약
 * (DOC-T3-TIC-024 §11.3)
 */
async getCardView(userId: string) {
    if (!userId) throw new BadRequestException('user_id is required');

    // 1) 자동 상태 전환: end_date 지난 active 여행 → completed (§04.5, P1-5)
    await this.dataSource.query(`
        UPDATE tb_trip
        SET status = 'completed', updated_at = NOW()
        WHERE status = 'active'
          AND end_date < CURRENT_DATE
          AND deleted_at IS NULL
    `);

    // 2) 멤버 여행 카드 데이터
    const memberTrips = await this.dataSource.query(`
        SELECT
            v.trip_id, v.trip_name, v.status, v.start_date, v.end_date,
            v.trip_days, v.privacy_level, v.sharing_mode, v.schedule_type,
            v.country_code, v.country_name, v.destination_city,
            v.has_minor_members, v.reactivation_count,
            v.d_day, v.current_day, v.member_count, v.can_reactivate,
            v.group_id, v.reactivated_at, v.updated_at,
            gm.member_role AS user_role,
            gm.is_admin
        FROM tb_trip_card_view v
        JOIN tb_group_member gm ON gm.trip_id = v.trip_id
        WHERE gm.user_id = $1
          AND gm.status = 'active'
          AND gm.member_role IN ('captain', 'crew_chief', 'crew')
        ORDER BY
            CASE v.status
                WHEN 'active' THEN 1
                WHEN 'planning' THEN 2
                WHEN 'completed' THEN 3
            END,
            v.start_date DESC
    `, [userId]);

    // 3) 가디언 여행 카드 데이터 (§05)
    const guardianTrips = await this.dataSource.query(`
        SELECT
            v.trip_id, v.trip_name, v.status, v.start_date, v.end_date,
            v.privacy_level, v.group_id,
            gl.guardian_type,
            gl.is_paid,
            u.display_name AS member_name,
            gm2.location_sharing_enabled AS location_sharing_status
        FROM tb_guardian_link gl
        JOIN tb_group_member gm ON gm.member_id = gl.member_id
        JOIN tb_trip_card_view v ON v.trip_id = gm.trip_id
        JOIN tb_user u ON u.user_id = gm.user_id
        LEFT JOIN tb_group_member gm2 ON gm2.trip_id = v.trip_id AND gm2.user_id = gm.user_id AND gm2.status = 'active'
        WHERE gl.guardian_user_id = $1
          AND gl.status = 'accepted'
          AND v.status IN ('active', 'planning')
        ORDER BY v.start_date DESC
    `, [userId]);

    // 4) 오늘 일정 요약 (active 여행만, P2-2)
    const todaySchedules = await this.dataSource.query(`
        SELECT
            ts.trip_id,
            STRING_AGG(si.title, ' → ' ORDER BY si.start_time) AS today_summary
        FROM tb_travel_schedule ts
        JOIN tb_schedule_item si ON si.schedule_id = ts.schedule_id
        WHERE ts.schedule_date = CURRENT_DATE
          AND ts.trip_id = ANY($1::uuid[])
        GROUP BY ts.trip_id
    `, [memberTrips.filter(t => t.status === 'active').map(t => t.trip_id)]);

    const scheduleMap = new Map(todaySchedules.map(s => [s.trip_id, s.today_summary]));

    // 5) completed 통계 (P3-1)
    const completedTripIds = memberTrips.filter(t => t.status === 'completed').map(t => t.trip_id);
    let statsMap = new Map();
    if (completedTripIds.length > 0) {
        const stats = await this.dataSource.query(`
            SELECT
                trip_id,
                COALESCE(SUM(distance_meters), 0) / 1000.0 AS total_distance_km,
                COUNT(DISTINCT place_name) AS visited_places
            FROM tb_movement_history
            WHERE trip_id = ANY($1::uuid[])
            GROUP BY trip_id
        `, [completedTripIds]);
        statsMap = new Map(stats.map(s => [s.trip_id, s]));
    }

    return {
        memberTrips: memberTrips.map(t => ({
            ...t,
            today_schedule_summary: scheduleMap.get(t.trip_id) || null,
            total_distance_km: statsMap.get(t.trip_id)?.total_distance_km || null,
            visited_places: statsMap.get(t.trip_id)?.visited_places || null,
        })),
        guardianTrips,
    };
}

/**
 * PATCH /trips/:tripId/reactivate — 여행 재활성화 (§04.5, P2-1)
 * 조건: completed + 24시간 이내 + reactivation_count == 0
 */
async reactivateTrip(tripId: string, userId: string) {
    const trip = await this.findById(tripId);

    // 캡틴만 가능
    const member = await this.memberRepo.findOne({
        where: { tripId, userId, status: 'active', memberRole: 'captain' },
    });
    if (!member) throw new ForbiddenException('캡틴만 재활성화할 수 있습니다.');

    if (trip.status !== 'completed') {
        throw new BadRequestException('완료된 여행만 재활성화할 수 있습니다.');
    }

    if (trip.reactivationCount >= 1) {
        throw new BadRequestException('재활성화는 1회만 가능합니다. (비즈니스 원칙 §02.6)');
    }

    const hoursSinceUpdate = (Date.now() - new Date(trip.updatedAt).getTime()) / (1000 * 60 * 60);
    if (hoursSinceUpdate > 24) {
        throw new BadRequestException('재활성화 가능 시간(24시간)이 지났습니다.');
    }

    await this.tripRepo.update(tripId, {
        status: 'active',
        reactivationCount: trip.reactivationCount + 1,
        reactivatedAt: new Date(),
    });

    return { success: true, message: '여행이 재활성화되었습니다.' };
}
```

**Step 2: Add controller routes**

Add before the parametric route `@Get(':tripId')` in `trips.controller.ts`:

```typescript
@Get('card-view')
@ApiOperation({ summary: '여행정보카드 전용 데이터 조회 (§11.3)' })
getCardView(@CurrentUser() userId: string) {
    return this.tripsService.getCardView(userId);
}

@Patch(':tripId/reactivate')
@ApiOperation({ summary: '여행 재활성화 (§04.5, §02.6)' })
reactivateTrip(
    @CurrentUser() userId: string,
    @Param('tripId') tripId: string,
) {
    return this.tripsService.reactivateTrip(tripId, userId);
}
```

**Step 3: Verify server compiles**

Run: `cd safetrip-server-api && npx tsc --noEmit`
Expected: No errors

**Step 4: Commit**

```
git add safetrip-server-api/src/modules/trips/trips.controller.ts safetrip-server-api/src/modules/trips/trips.service.ts
git commit -m "feat(api): add GET /trips/card-view + PATCH reactivate (§11.3, §04.5 아키텍처 원칙 적용)"
```

---

## Task 3: Flutter — TripCardData Model

**Files:**
- Create: `safetrip-mobile/lib/features/trip_card/models/trip_card_data.dart`

**Step 1: Create model mapping TB_TRIP_CARD_VIEW response**

```dart
/// TB_TRIP_CARD_VIEW 매핑 모델 (DOC-T3-TIC-024 §11.3)
///
/// 서버 GET /trips/card-view 응답의 memberTrips / guardianTrips 각 항목을
/// Dart 객체로 변환한다.
class MemberTripCard {
  const MemberTripCard({
    required this.tripId,
    required this.tripName,
    required this.status,
    required this.startDate,
    required this.endDate,
    required this.tripDays,
    required this.privacyLevel,
    required this.sharingMode,
    this.scheduleType,
    this.countryCode,
    this.countryName,
    this.destinationCity,
    this.hasMinorMembers = false,
    this.reactivationCount = 0,
    this.dDay,
    this.currentDay,
    this.memberCount = 0,
    this.canReactivate = false,
    required this.userRole,
    this.isAdmin = false,
    this.todayScheduleSummary,
    this.totalDistanceKm,
    this.visitedPlaces,
    this.groupId,
  });

  factory MemberTripCard.fromJson(Map<String, dynamic> json) {
    return MemberTripCard(
      tripId: json['trip_id'] as String? ?? '',
      tripName: json['trip_name'] as String? ?? '',
      status: json['status'] as String? ?? 'planning',
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: DateTime.parse(json['end_date'] as String),
      tripDays: json['trip_days'] as int? ?? 0,
      privacyLevel: json['privacy_level'] as String? ?? 'standard',
      sharingMode: json['sharing_mode'] as String? ?? 'voluntary',
      scheduleType: json['schedule_type'] as String?,
      countryCode: json['country_code'] as String?,
      countryName: json['country_name'] as String?,
      destinationCity: json['destination_city'] as String?,
      hasMinorMembers: json['has_minor_members'] as bool? ?? false,
      reactivationCount: json['reactivation_count'] as int? ?? 0,
      dDay: json['d_day'] as int?,
      currentDay: json['current_day'] as int?,
      memberCount: json['member_count'] as int? ?? 0,
      canReactivate: json['can_reactivate'] as bool? ?? false,
      userRole: json['user_role'] as String? ?? 'crew',
      isAdmin: json['is_admin'] as bool? ?? false,
      todayScheduleSummary: json['today_schedule_summary'] as String?,
      totalDistanceKm: (json['total_distance_km'] as num?)?.toDouble(),
      visitedPlaces: json['visited_places'] as int?,
      groupId: json['group_id'] as String?,
    );
  }

  final String tripId;
  final String tripName;
  final String status; // planning | active | completed
  final DateTime startDate;
  final DateTime endDate;
  final int tripDays;
  final String privacyLevel; // safety_first | standard | privacy_first
  final String sharingMode;
  final String? scheduleType;
  final String? countryCode;
  final String? countryName;
  final String? destinationCity;
  final bool hasMinorMembers;
  final int reactivationCount;
  final int? dDay;
  final int? currentDay;
  final int memberCount;
  final bool canReactivate;
  final String userRole; // captain | crew_chief | crew
  final bool isAdmin;
  final String? todayScheduleSummary;
  final double? totalDistanceKm;
  final int? visitedPlaces;
  final String? groupId;

  /// D-day 표시 문자열 (§03.2)
  /// D-15~D-1, "여행 중", "완료"
  String get dDayDisplay {
    if (status == 'completed') return '완료';
    if (status == 'active') return '여행 중';
    if (dDay == null) return '';
    if (dDay! > 15) return ''; // D-16 이상은 비표시
    if (dDay! == 0) return '여행 중';
    return 'D-$dDay';
  }
}

class GuardianTripCard {
  const GuardianTripCard({
    required this.tripId,
    required this.tripName,
    required this.status,
    required this.startDate,
    required this.endDate,
    this.memberName,
    this.guardianType,
    this.isPaid = false,
    this.locationSharingStatus = false,
    this.privacyLevel,
    this.todayScheduleSummary,
  });

  factory GuardianTripCard.fromJson(Map<String, dynamic> json) {
    return GuardianTripCard(
      tripId: json['trip_id'] as String? ?? '',
      tripName: json['trip_name'] as String? ?? '',
      status: json['status'] as String? ?? 'planning',
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: DateTime.parse(json['end_date'] as String),
      memberName: json['member_name'] as String?,
      guardianType: json['guardian_type'] as String?,
      isPaid: json['is_paid'] as bool? ?? false,
      locationSharingStatus: json['location_sharing_status'] as bool? ?? false,
      privacyLevel: json['privacy_level'] as String?,
      todayScheduleSummary: json['today_schedule_summary'] as String?,
    );
  }

  final String tripId;
  final String tripName;
  final String status;
  final DateTime startDate;
  final DateTime endDate;
  final String? memberName;
  final String? guardianType; // personal | full
  final bool isPaid;
  final bool locationSharingStatus;
  final String? privacyLevel;
  final String? todayScheduleSummary;

  /// 무료 가디언인지 (§05.2)
  bool get isFreeGuardian => !isPaid;

  /// 전체 가디언인지 (§05.4)
  bool get isFullGuardian => guardianType == 'full';
}

/// 카드뷰 API 전체 응답
class TripCardViewData {
  const TripCardViewData({
    this.memberTrips = const [],
    this.guardianTrips = const [],
  });

  factory TripCardViewData.fromJson(Map<String, dynamic> json) {
    return TripCardViewData(
      memberTrips: (json['memberTrips'] as List<dynamic>?)
              ?.map((e) => MemberTripCard.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      guardianTrips: (json['guardianTrips'] as List<dynamic>?)
              ?.map((e) => GuardianTripCard.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  final List<MemberTripCard> memberTrips;
  final List<GuardianTripCard> guardianTrips;

  /// active 여행 수 (P2-4 복수 active 경고용)
  int get activeCount => memberTrips.where((t) => t.status == 'active').length;

  /// 현재 표시할 메인 카드 (C1: 가장 최근 active 여행 우선, §09.2)
  MemberTripCard? get primaryTrip {
    final active = memberTrips.where((t) => t.status == 'active').toList();
    if (active.isNotEmpty) return active.first; // 이미 start_date DESC 정렬
    final planning = memberTrips.where((t) => t.status == 'planning').toList();
    if (planning.isNotEmpty) return planning.first;
    return memberTrips.isNotEmpty ? memberTrips.first : null;
  }

  /// 여행이 하나도 없는 경우 (§04.4 탐색 모드)
  bool get isEmpty => memberTrips.isEmpty && guardianTrips.isEmpty;
}
```

**Step 2: Commit**

```
git add safetrip-mobile/lib/features/trip_card/models/trip_card_data.dart
git commit -m "feat(flutter): add TripCardData model for TB_TRIP_CARD_VIEW (§11.3 아키텍처 원칙 적용)"
```

---

## Task 4: Flutter — TripCardService + TripCardProvider

**Files:**
- Create: `safetrip-mobile/lib/features/trip_card/services/trip_card_service.dart`
- Create: `safetrip-mobile/lib/features/trip_card/providers/trip_card_provider.dart`

**Step 1: Create TripCardService**

```dart
import '../../../services/api_service.dart';
import '../models/trip_card_data.dart';

/// 여행정보카드 API 서비스 (DOC-T3-TIC-024)
class TripCardService {
  TripCardService(this._apiService);

  final ApiService _apiService;

  /// GET /trips/card-view
  Future<TripCardViewData> fetchCardView() async {
    final response = await _apiService.dio.get('/api/v1/trips/card-view');
    if (response.data is Map<String, dynamic>) {
      return TripCardViewData.fromJson(response.data as Map<String, dynamic>);
    }
    return const TripCardViewData();
  }

  /// PATCH /trips/:tripId/reactivate (§04.5)
  Future<void> reactivateTrip(String tripId) async {
    await _apiService.dio.patch('/api/v1/trips/$tripId/reactivate');
  }
}
```

**Step 2: Create TripCardProvider**

```dart
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
        'memberTrips': data.memberTrips.map((t) => {
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
        'guardianTrips': data.guardianTrips.map((t) => {
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
```

**Step 3: Commit**

```
git add safetrip-mobile/lib/features/trip_card/services/trip_card_service.dart safetrip-mobile/lib/features/trip_card/providers/trip_card_provider.dart
git commit -m "feat(flutter): add TripCardService + TripCardProvider with offline cache (§11.3, §12 아키텍처 원칙 적용)"
```

---

## Task 5: Flutter — Shared Sub-Widgets (PrivacyBadge, DDayBadge, OfflineBanner)

**Files:**
- Create: `safetrip-mobile/lib/features/trip_card/widgets/privacy_badge.dart`
- Create: `safetrip-mobile/lib/features/trip_card/widgets/d_day_badge.dart`
- Create: `safetrip-mobile/lib/features/trip_card/widgets/offline_banner.dart`

**Step 1: Create PrivacyBadge (§03.3, P0-8)**

```dart
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

/// 프라이버시 등급 배지 (§03.3, §07)
/// 3행 레이아웃의 3행에 표시된다.
class PrivacyBadge extends StatelessWidget {
  const PrivacyBadge({super.key, required this.level});

  final String level;

  @override
  Widget build(BuildContext context) {
    final config = _getConfig(level);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: config.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(config.icon, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          Text(
            config.label,
            style: AppTypography.labelSmall.copyWith(
              color: config.color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  static _PrivacyConfig _getConfig(String level) {
    switch (level) {
      case 'safety_first':
        return _PrivacyConfig(
          icon: '\u{1F6E1}\u{FE0F}',
          label: '안전 최우선 · 강제 공유 · 24시간',
          color: AppColors.privacySafetyFirst,
        );
      case 'privacy_first':
        return _PrivacyConfig(
          icon: '\u{1F512}',
          label: '프라이버시 우선 · 일정 연동',
          color: AppColors.privacyFirst,
        );
      case 'standard':
      default:
        return _PrivacyConfig(
          icon: '\u{1F4CD}',
          label: '표준 · 24시간 공유',
          color: AppColors.privacyStandard,
        );
    }
  }
}

class _PrivacyConfig {
  const _PrivacyConfig({
    required this.icon,
    required this.label,
    required this.color,
  });
  final String icon;
  final String label;
  final Color color;
}
```

**Step 2: Create DDayBadge (§03.2, P0-3)**

```dart
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

/// D-day 배지 (§03.2)
/// planning: D-15~D-1, active: "여행 중", completed: "완료"
class DDayBadge extends StatelessWidget {
  const DDayBadge({super.key, required this.status, this.dDay, this.currentDay});

  final String status;
  final int? dDay;
  final int? currentDay;

  @override
  Widget build(BuildContext context) {
    final display = _getDisplay();
    if (display.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _getColor().withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        display,
        style: AppTypography.labelSmall.copyWith(
          color: _getColor(),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _getDisplay() {
    switch (status) {
      case 'active':
        return '여행 중';
      case 'completed':
        return '완료';
      case 'planning':
        if (dDay == null) return '';
        if (dDay! > 15) return ''; // §03.2: D-16 이상 비표시
        if (dDay! == 0) return '여행 중';
        return 'D-$dDay';
      default:
        return '';
    }
  }

  Color _getColor() {
    switch (status) {
      case 'active':
        return AppColors.tripActive;
      case 'completed':
        return AppColors.tripCompleted;
      case 'planning':
      default:
        return AppColors.tripPlanning;
    }
  }
}
```

**Step 3: Create OfflineBanner (§12.1, P1-4)**

```dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_spacing.dart';

/// 오프라인 배지 (§12.1)
/// 네트워크 연결 끊김 시 카드 상단에 표시
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key, this.lastSyncTime});

  final DateTime? lastSyncTime;

  @override
  Widget build(BuildContext context) {
    final syncText = lastSyncTime != null
        ? '마지막 동기화: ${DateFormat('HH:mm').format(lastSyncTime!)}'
        : '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.textTertiary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppSpacing.radius4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off, size: 14, color: AppColors.textTertiary),
          const SizedBox(width: 4),
          Text(
            '오프라인 $syncText',
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}
```

**Step 4: Commit**

```
git add safetrip-mobile/lib/features/trip_card/widgets/privacy_badge.dart safetrip-mobile/lib/features/trip_card/widgets/d_day_badge.dart safetrip-mobile/lib/features/trip_card/widgets/offline_banner.dart
git commit -m "feat(flutter): add PrivacyBadge, DDayBadge, OfflineBanner widgets (§03.2, §03.3, §12.1 아키텍처 원칙 적용)"
```

---

## Task 6: Flutter — Status-Specific Content Widgets (P0-1, P0-2)

**Files:**
- Create: `safetrip-mobile/lib/features/trip_card/widgets/planning_card_content.dart`
- Create: `safetrip-mobile/lib/features/trip_card/widgets/active_card_content.dart`
- Create: `safetrip-mobile/lib/features/trip_card/widgets/completed_card_content.dart`

**Step 1: Create PlanningCardContent (§04.1)**

```dart
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../models/trip_card_data.dart';
import 'privacy_badge.dart';
import 'd_day_badge.dart';

/// planning 상태 카드 콘텐츠 (§04.1)
class PlanningCardContent extends StatelessWidget {
  const PlanningCardContent({super.key, required this.card});

  final MemberTripCard card;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1행: [예정] + 국기+여행명 + D-N + 멤버수
        Row(
          children: [
            _statusBadge(),
            const SizedBox(width: 6),
            if (card.countryCode != null) ...[
              Text(
                _countryFlag(card.countryCode!),
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(width: 4),
            ],
            Expanded(
              child: Text(
                card.tripName,
                style: AppTypography.titleMedium.copyWith(fontSize: 15),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            DDayBadge(status: card.status, dDay: card.dDay),
            const SizedBox(width: 8),
            Icon(Icons.people_outline, size: 14, color: AppColors.textTertiary),
            const SizedBox(width: 2),
            Text(
              '${card.memberCount}명',
              style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary),
            ),
          ],
        ),
        const SizedBox(height: 4),
        // 2행: 날짜
        Text(
          '\u{1F4C5} ${_formatDate(card.startDate)} ~ ${_formatDate(card.endDate)} (${card.tripDays}일)',
          style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 4),
        // 3행: 프라이버시 배지
        PrivacyBadge(level: card.privacyLevel),
      ],
    );
  }

  Widget _statusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.tripPlanning.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '예정',
        style: TextStyle(
          color: AppColors.tripPlanning,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _formatDate(DateTime d) => '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';

  String _countryFlag(String countryCode) {
    if (countryCode.length != 2) return '\u{1F30F}';
    final first = countryCode.codeUnitAt(0) - 0x41 + 0x1F1E6;
    final second = countryCode.codeUnitAt(1) - 0x41 + 0x1F1E6;
    return String.fromCharCode(first) + String.fromCharCode(second);
  }
}
```

**Step 2: Create ActiveCardContent (§04.2)**

```dart
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../models/trip_card_data.dart';
import 'd_day_badge.dart';

/// active 상태 카드 콘텐츠 (§04.2)
class ActiveCardContent extends StatelessWidget {
  const ActiveCardContent({super.key, required this.card});

  final MemberTripCard card;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1행: [진행 중] + 국기+여행명 + 여행 중 + 멤버수
        Row(
          children: [
            _statusBadge(),
            const SizedBox(width: 6),
            if (card.countryCode != null) ...[
              Text(
                _countryFlag(card.countryCode!),
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(width: 4),
            ],
            Expanded(
              child: Text(
                card.tripName,
                style: AppTypography.titleMedium.copyWith(fontSize: 15),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            DDayBadge(status: card.status),
            const SizedBox(width: 8),
            Icon(Icons.people_outline, size: 14, color: AppColors.textTertiary),
            const SizedBox(width: 2),
            Text(
              '${card.memberCount}명',
              style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary),
            ),
          ],
        ),
        const SizedBox(height: 4),
        // 2행: 날짜 + N일째 진행 중
        Text(
          '\u{1F4C5} ${_formatDate(card.startDate)} ~ ${_formatDate(card.endDate)} | ${card.currentDay ?? 1}일째 진행 중',
          style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 4),
        // 3행: 오늘 일정 요약 (P2-2)
        if (card.todayScheduleSummary != null && card.todayScheduleSummary!.isNotEmpty)
          Row(
            children: [
              Text(
                '오늘 일정: ',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.textTertiary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Expanded(
                child: Text(
                  card.todayScheduleSummary!,
                  style: AppTypography.labelSmall.copyWith(color: AppColors.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _statusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.tripActive.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '진행 중',
        style: TextStyle(
          color: AppColors.tripActive,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _formatDate(DateTime d) => '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';

  String _countryFlag(String countryCode) {
    if (countryCode.length != 2) return '\u{1F30F}';
    final first = countryCode.codeUnitAt(0) - 0x41 + 0x1F1E6;
    final second = countryCode.codeUnitAt(1) - 0x41 + 0x1F1E6;
    return String.fromCharCode(first) + String.fromCharCode(second);
  }
}
```

**Step 3: Create CompletedCardContent (§04.3)**

```dart
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_spacing.dart';
import '../models/trip_card_data.dart';

/// completed 상태 카드 콘텐츠 (§04.3, P2-1 재활성화, P3-1 통계)
class CompletedCardContent extends StatelessWidget {
  const CompletedCardContent({
    super.key,
    required this.card,
    this.onReactivate,
  });

  final MemberTripCard card;
  final VoidCallback? onReactivate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1행: [완료] + 국기+여행명 + 완료 + 멤버수
        Row(
          children: [
            _statusBadge(),
            const SizedBox(width: 6),
            if (card.countryCode != null) ...[
              Text(
                _countryFlag(card.countryCode!),
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(width: 4),
            ],
            Expanded(
              child: Text(
                card.tripName,
                style: AppTypography.titleMedium.copyWith(fontSize: 15),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.tripCompleted.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '완료',
                style: TextStyle(
                  color: AppColors.tripCompleted,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.people_outline, size: 14, color: AppColors.textTertiary),
            const SizedBox(width: 2),
            Text(
              '${card.memberCount}명',
              style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary),
            ),
          ],
        ),
        const SizedBox(height: 4),
        // 2행: 날짜
        Text(
          '\u{1F4C5} ${_formatDate(card.startDate)} ~ ${_formatDate(card.endDate)} (${card.tripDays}일)',
          style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 4),
        // 3행: 통계 (P3-1) + 재활성화 (P2-1)
        Row(
          children: [
            if (card.totalDistanceKm != null)
              _statChip('이동 거리: ${card.totalDistanceKm!.toStringAsFixed(1)}km'),
            if (card.visitedPlaces != null) ...[
              const SizedBox(width: 6),
              _statChip('방문지: ${card.visitedPlaces}곳'),
            ],
            const Spacer(),
            // 재활성화 버튼 (P2-1: 캡틴만, §04.5)
            if (card.canReactivate && card.userRole == 'captain')
              TextButton.icon(
                onPressed: onReactivate,
                icon: const Icon(Icons.refresh, size: 14),
                label: const Text('재활성화'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  textStyle: AppTypography.labelSmall,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _statusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.tripCompleted.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '완료',
        style: TextStyle(
          color: AppColors.tripCompleted,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _statChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary),
      ),
    );
  }

  String _formatDate(DateTime d) => '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';

  String _countryFlag(String countryCode) {
    if (countryCode.length != 2) return '\u{1F30F}';
    final first = countryCode.codeUnitAt(0) - 0x41 + 0x1F1E6;
    final second = countryCode.codeUnitAt(1) - 0x41 + 0x1F1E6;
    return String.fromCharCode(first) + String.fromCharCode(second);
  }
}
```

**Step 4: Commit**

```
git add safetrip-mobile/lib/features/trip_card/widgets/planning_card_content.dart safetrip-mobile/lib/features/trip_card/widgets/active_card_content.dart safetrip-mobile/lib/features/trip_card/widgets/completed_card_content.dart
git commit -m "feat(flutter): add status-specific card content widgets (§04.1-04.3, P0-1/P0-2 아키텍처 원칙 적용)"
```

---

## Task 7: Flutter — MemberTripCard + GuardianCard + NoTripCta

**Files:**
- Create: `safetrip-mobile/lib/features/trip_card/widgets/member_trip_card.dart`
- Create: `safetrip-mobile/lib/features/trip_card/widgets/guardian_card.dart`
- Create: `safetrip-mobile/lib/features/trip_card/widgets/no_trip_cta.dart`

**Step 1: Create MemberTripCard (strategy container)**

```dart
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../models/trip_card_data.dart';
import 'planning_card_content.dart';
import 'active_card_content.dart';
import 'completed_card_content.dart';

/// 멤버 여행 카드 — 상태별 strategy 분기 (§04, C3)
class MemberTripCard extends StatelessWidget {
  const MemberTripCard({
    super.key,
    required this.card,
    this.onTap,
    this.onReactivate,
    this.showSwitchButton = false,
    this.onSwitch,
  });

  final MemberTripCard card; // naming conflict — see fix below
  final VoidCallback? onTap;
  final VoidCallback? onReactivate;
  final bool showSwitchButton;
  final VoidCallback? onSwitch;

  @override
  Widget build(BuildContext context) {
    // ... implementation
  }
}
```

> **Note for implementer:** The field name `card` conflicts with the class name `MemberTripCard`. Rename the field to `data` of type `MemberTripCardData` or rename the class. In the actual implementation, use `data` as the field name:

```dart
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../models/trip_card_data.dart';
import 'planning_card_content.dart';
import 'active_card_content.dart';
import 'completed_card_content.dart';

/// 멤버 여행 카드 — 상태별 strategy 분기 (§04, C3)
class MemberTripCardWidget extends StatelessWidget {
  const MemberTripCardWidget({
    super.key,
    required this.data,
    this.onTap,
    this.onReactivate,
    this.showSwitchButton = false,
    this.onSwitch,
  });

  final MemberTripCard data;
  final VoidCallback? onTap;
  final VoidCallback? onReactivate;
  final bool showSwitchButton;
  final VoidCallback? onSwitch;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(AppSpacing.radius12),
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 4),
          ],
        ),
        child: Stack(
          children: [
            _buildContent(),
            // [전환▼] 버튼 (§09.1, P0-6)
            if (showSwitchButton)
              Positioned(
                top: 0,
                right: 0,
                child: GestureDetector(
                  onTap: onSwitch,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          data.status == 'completed' ? '열람' : '전환',
                          style: const TextStyle(fontSize: 10, color: AppColors.textTertiary),
                        ),
                        const Icon(Icons.arrow_drop_down, size: 14, color: AppColors.textTertiary),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (data.status) {
      case 'active':
        return ActiveCardContent(card: data);
      case 'completed':
        return CompletedCardContent(card: data, onReactivate: onReactivate);
      case 'planning':
      default:
        return PlanningCardContent(card: data);
    }
  }
}
```

**Step 2: Create GuardianCard (§05, P1-1~P1-3)**

```dart
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../models/trip_card_data.dart';
import 'privacy_badge.dart';

/// 가디언 카드 (§05, C5)
/// 무료/유료/전체 가디언에 따라 표시 정보가 다르다.
class GuardianCardWidget extends StatelessWidget {
  const GuardianCardWidget({super.key, required this.data, this.onTap});

  final GuardianTripCard data;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(AppSpacing.radius12),
          border: Border.all(color: AppColors.guardian.withValues(alpha: 0.3)),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1행: [가디언] + 멤버 이름/여행명 + 상태 + [상세보기]
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.guardian.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    data.isFullGuardian ? '전체 가디언' : (data.isPaid ? '유료 가디언' : '가디언'),
                    style: TextStyle(
                      color: AppColors.guardian,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    data.isFullGuardian
                        ? data.tripName
                        : '${data.memberName ?? ''}의 여행',
                    style: AppTypography.titleMedium.copyWith(fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  data.status == 'active' ? '여행 중' : '예정',
                  style: AppTypography.labelSmall.copyWith(
                    color: data.status == 'active' ? AppColors.tripActive : AppColors.tripPlanning,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                // 유료 가디언: 프라이버시 배지 (§05.3)
                if (data.isPaid && data.privacyLevel != null) ...[
                  const SizedBox(width: 6),
                  PrivacyBadge(level: data.privacyLevel!),
                ],
              ],
            ),
            const SizedBox(height: 4),
            // 2행: 날짜
            Text(
              '\u{1F4C5} ${_formatDate(data.startDate)} ~ ${_formatDate(data.endDate)}',
              style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 4),
            // 3행: 상태 정보
            Text(
              _statusLine(),
              style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary),
            ),
            // 유료 가디언: 오늘 일정 (§05.3)
            if (data.isPaid && data.todayScheduleSummary != null) ...[
              const SizedBox(height: 4),
              Text(
                '오늘: ${data.todayScheduleSummary}',
                style: AppTypography.labelSmall.copyWith(color: AppColors.textSecondary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            // 무료 가디언: 유료 전환 유도 (§05.2, P1-3)
            if (data.isFreeGuardian && !data.isFullGuardian) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.secondaryAmber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSpacing.radius8),
                ),
                child: Column(
                  children: [
                    Text(
                      '유료 가디언으로 전환하면 일정 요약, 프라이버시 등급 정보를 추가로 확인할 수 있습니다.',
                      style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 4),
                    TextButton(
                      onPressed: () {
                        // TODO: 유료 전환 플로우
                      },
                      child: const Text('유료로 전환 (1,900원/여행)'),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _statusLine() {
    if (data.isFullGuardian) {
      return '전체 멤버 위치 공유 현황 확인';
    }
    return '현재 상태: ${data.locationSharingStatus ? '위치 공유 중' : '위치 비공유'}';
  }

  String _formatDate(DateTime d) => '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';
}
```

**Step 3: Create NoTripCta (§04.4, P0-7)**

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../router/route_paths.dart';

/// 탐색 모드 CTA (§04.4, P0-7)
/// 참여 중인 여행이 없을 때 표시
class NoTripCta extends StatelessWidget {
  const NoTripCta({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(AppSpacing.radius12),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '여행이 없습니다',
            style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => context.push(RoutePaths.tripCreate),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('새 여행 만들기'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(40),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => context.push(RoutePaths.tripJoin),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(40),
                    side: const BorderSide(color: AppColors.primaryTeal),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radius12),
                    ),
                  ),
                  child: const Text('초대코드 입력', style: TextStyle(color: AppColors.primaryTeal)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
```

**Step 4: Commit**

```
git add safetrip-mobile/lib/features/trip_card/widgets/member_trip_card.dart safetrip-mobile/lib/features/trip_card/widgets/guardian_card.dart safetrip-mobile/lib/features/trip_card/widgets/no_trip_cta.dart
git commit -m "feat(flutter): add MemberTripCard, GuardianCard, NoTripCta widgets (§04, §05, C3/C5 아키텍처 원칙 적용)"
```

---

## Task 8: Flutter — TripSwitchBottomSheet (P0-6, §09)

**Files:**
- Create: `safetrip-mobile/lib/features/trip_card/widgets/trip_switch_bottom_sheet.dart`

**Step 1: Create the trip switching bottom sheet**

```dart
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../models/trip_card_data.dart';

/// 여행 전환 바텀시트 (§09, P0-6)
/// 복수 여행 참여 시 전환 목록 표시
class TripSwitchBottomSheet extends StatelessWidget {
  const TripSwitchBottomSheet({
    super.key,
    required this.cardData,
    required this.onSelect,
  });

  final TripCardViewData cardData;
  final void Function(String tripId) onSelect;

  @override
  Widget build(BuildContext context) {
    final active = cardData.memberTrips.where((t) => t.status == 'active').toList();
    final planning = cardData.memberTrips.where((t) => t.status == 'planning').toList();
    final completed = cardData.memberTrips.where((t) => t.status == 'completed').take(5).toList();
    final guardian = cardData.guardianTrips;

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppSpacing.radius20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 핸들
          Center(
            child: Container(
              width: AppSpacing.bottomSheetHandleWidth,
              height: AppSpacing.bottomSheetHandleHeight,
              decoration: BoxDecoration(
                color: AppColors.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text('여행 전환', style: AppTypography.titleMedium),
          const SizedBox(height: AppSpacing.md),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                if (active.isNotEmpty) ...[
                  _sectionHeader('진행 중인 여행'),
                  ...active.map((t) => _tripItem(t.tripId, t.tripName, '${t.currentDay ?? 1}일째', AppColors.tripActive)),
                ],
                if (planning.isNotEmpty) ...[
                  _sectionHeader('예정된 여행'),
                  ...planning.map((t) => _tripItem(t.tripId, t.tripName, t.dDayDisplay, AppColors.tripPlanning)),
                ],
                if (guardian.isNotEmpty) ...[
                  _sectionHeader('가디언으로 참여 중'),
                  ...guardian.map((t) => _tripItem(
                    t.tripId,
                    t.isFullGuardian ? t.tripName : '${t.memberName ?? ''}의 여행',
                    t.status == 'active' ? '여행 중' : '예정',
                    AppColors.guardian,
                  )),
                ],
                if (completed.isNotEmpty) ...[
                  _sectionHeader('완료된 여행 (최근 5개)'),
                  ...completed.map((t) => _tripItem(t.tripId, t.tripName, '완료', AppColors.tripCompleted)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.xs),
      child: Text(
        title,
        style: AppTypography.labelSmall.copyWith(
          color: AppColors.textTertiary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _tripItem(String tripId, String name, String badge, Color color) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      title: Text(name, style: AppTypography.bodyMedium),
      trailing: Text(
        badge,
        style: AppTypography.labelSmall.copyWith(color: color, fontWeight: FontWeight.w600),
      ),
      onTap: () => onSelect(tripId),
    );
  }
}

/// 바텀시트 표시 헬퍼
void showTripSwitchSheet(
  BuildContext context, {
  required TripCardViewData cardData,
  required void Function(String tripId) onSelect,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => TripSwitchBottomSheet(
      cardData: cardData,
      onSelect: (tripId) {
        Navigator.pop(context);
        onSelect(tripId);
      },
    ),
  );
}
```

**Step 2: Commit**

```
git add safetrip-mobile/lib/features/trip_card/widgets/trip_switch_bottom_sheet.dart
git commit -m "feat(flutter): add TripSwitchBottomSheet for trip switching (§09, P0-6 아키텍처 원칙 적용)"
```

---

## Task 9: Flutter — TripInfoCardSection (Top-Level Container) + Wire Into MainScreen

**Files:**
- Create: `safetrip-mobile/lib/features/trip_card/widgets/trip_info_card_section.dart`
- Modify: `safetrip-mobile/lib/screens/main/screen_main.dart:596-601` — replace `TopTripInfoCard` reference
- Modify: `safetrip-mobile/lib/screens/main/widgets/top_trip_info_card.dart` — redirect import (backward compat)

**Step 1: Create TripInfoCardSection**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../models/trip_card_data.dart';
import '../providers/trip_card_provider.dart';
import 'member_trip_card.dart';
import 'guardian_card.dart';
import 'no_trip_cta.dart';
import 'offline_banner.dart';
import 'trip_switch_bottom_sheet.dart';

/// 여행정보카드 최상위 컨테이너 (DOC-T3-TIC-024)
///
/// TripCardProvider의 상태를 watch하여:
/// - 멤버 여행 카드 (상태별 strategy)
/// - 가디언 여행 카드 (분리 섹션, C5)
/// - 탐색 모드 CTA (여행 없음)
/// - 오프라인 배지 (§12)
/// - 복수 active 경고 (P2-4)
/// 를 렌더링한다.
class TripInfoCardSection extends ConsumerStatefulWidget {
  const TripInfoCardSection({super.key});

  @override
  ConsumerState<TripInfoCardSection> createState() => _TripInfoCardSectionState();
}

class _TripInfoCardSectionState extends ConsumerState<TripInfoCardSection> {
  @override
  void initState() {
    super.initState();
    // 최초 로드
    Future.microtask(() => ref.read(tripCardProvider.notifier).fetchCardView());
  }

  @override
  Widget build(BuildContext context) {
    final cardState = ref.watch(tripCardProvider);
    final data = cardState.data;

    // 로딩 중: 스켈레톤 (§10.1)
    if (cardState.isLoading && data.isEmpty) {
      return _buildSkeleton();
    }

    // 여행 없음: 탐색 모드 CTA (§04.4)
    if (data.isEmpty) {
      return const NoTripCta();
    }

    final primary = data.primaryTrip;
    final hasMultipleTrips = data.memberTrips.length + data.guardianTrips.length > 1;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 오프라인 배지 (§12, P1-4)
        if (cardState.isOffline)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: OfflineBanner(lastSyncTime: cardState.lastSyncTime),
          ),

        // 복수 active 경고 (P2-4)
        if (data.activeCount >= 2)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.semanticWarning.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.warning_amber, size: 14, color: AppColors.semanticWarning),
                  const SizedBox(width: 4),
                  Text(
                    '진행 중인 여행 ${data.activeCount}개',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.semanticWarning,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // 메인 카드 (C1: 여행 컨텍스트 최우선)
        if (primary != null)
          MemberTripCardWidget(
            data: primary,
            showSwitchButton: hasMultipleTrips,
            onSwitch: () => _showSwitchSheet(data),
            onReactivate: primary.canReactivate
                ? () => _handleReactivate(primary.tripId)
                : null,
            onTap: () {
              // C4: 1터치 진입 — 이미 메인 화면에 있으므로 tripProvider 갱신
              // TODO: tripProvider와 연동하여 선택된 여행 컨텍스트 전환
            },
          ),

        // 가디언 여행 섹션 (C5: 분리 표시, P1-1)
        if (data.guardianTrips.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '가디언으로 참여 중인 여행',
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.textTertiary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          ...data.guardianTrips.map((g) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: GuardianCardWidget(data: g),
          )),
        ],
      ],
    );
  }

  Widget _buildSkeleton() {
    return Container(
      height: 80,
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(AppSpacing.radius12),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: 12, width: 120, color: AppColors.surfaceVariant),
          const SizedBox(height: 8),
          Container(height: 10, width: 200, color: AppColors.surfaceVariant),
          const SizedBox(height: 8),
          Container(height: 10, width: 150, color: AppColors.surfaceVariant),
        ],
      ),
    );
  }

  void _showSwitchSheet(TripCardViewData data) {
    showTripSwitchSheet(
      context,
      cardData: data,
      onSelect: (tripId) {
        // TODO: tripProvider와 연동하여 선택된 여행으로 컨텍스트 전환
        ref.read(tripCardProvider.notifier).fetchCardView();
      },
    );
  }

  Future<void> _handleReactivate(String tripId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('여행 재활성화'),
        content: const Text('이 여행을 다시 활성화하시겠습니까?\n재활성화는 1회만 가능합니다.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('재활성화')),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      final success = await ref.read(tripCardProvider.notifier).reactivateTrip(tripId);
      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ref.read(tripCardProvider).error ?? '재활성화에 실패했습니다.')),
        );
      }
    }
  }
}
```

**Step 2: Update MainScreen to use TripInfoCardSection**

In `safetrip-mobile/lib/screens/main/screen_main.dart`, replace line 601:

```dart
// OLD:
child: const TopTripInfoCard(),

// NEW:
child: const TripInfoCardSection(),
```

And update the import at top of file:

```dart
// OLD:
import 'widgets/top_trip_info_card.dart';

// NEW:
import '../../features/trip_card/widgets/trip_info_card_section.dart';
```

**Step 3: Verify Flutter compiles**

Run: `cd safetrip-mobile && flutter analyze --no-pub`
Expected: No errors related to trip card widgets

**Step 4: Commit**

```
git add safetrip-mobile/lib/features/trip_card/widgets/trip_info_card_section.dart safetrip-mobile/lib/screens/main/screen_main.dart
git commit -m "feat(flutter): add TripInfoCardSection + wire into MainScreen (C1-C5, P0~P3 아키텍처 원칙 적용)"
```

---

## Task 10: Backend — 15-Day Validation Enhancement (P0-5)

**Files:**
- Modify: `safetrip-server-api/src/modules/trips/trips.service.ts` — enhance `updateTrip()` validation

**Step 1: Add explicit 15-day error codes to updateTrip**

In `trips.service.ts`, find the `updateTrip` method and add after the permission check:

```typescript
// §08.2: 기간 변경 시 15일 검증
if (data.endDate || data.startDate) {
    const newStart = data.startDate ? new Date(data.startDate) : trip.startDate;
    const newEnd = data.endDate ? new Date(data.endDate) : trip.endDate;
    const diffDays = Math.ceil((newEnd.getTime() - newStart.getTime()) / (1000 * 60 * 60 * 24));
    if (diffDays > 15) {
        throw new BadRequestException({
            errorCode: 'TRIP_DURATION_EXCEEDED',
            message: '여행 기간은 최대 15일까지 설정할 수 있습니다.',
        });
    }
    if (diffDays < 0) {
        throw new BadRequestException({
            errorCode: 'TRIP_DATE_CONFLICT',
            message: '종료일이 시작일보다 앞설 수 없습니다.',
        });
    }
}
```

**Step 2: Verify server compiles**

Run: `cd safetrip-server-api && npx tsc --noEmit`
Expected: No errors

**Step 3: Commit**

```
git add safetrip-server-api/src/modules/trips/trips.service.ts
git commit -m "feat(api): enhance 15-day validation with error codes (§08.2, P0-5 아키텍처 원칙 적용)"
```

---

## Task 11: Flutter — 15-Day Calendar Picker Enhancement (P0-4)

**Files:**
- Modify: `safetrip-mobile/lib/screens/trip/screen_trip_create.dart` — enhance DateRangePicker with 15-day limit

**Step 1: Locate and enhance the date picker**

Find the end date picker in `screen_trip_create.dart` and update it to enforce the 15-day limit:

```dart
// §08.1: 16일째 이후 날짜는 자동 비활성화
lastDate: _startDate?.add(const Duration(days: 15)) ?? DateTime.now().add(const Duration(days: 365)),
```

Also add a validation check before API call:

```dart
// §08.2: 클라이언트 사전 검증
final duration = _endDate!.difference(_startDate!).inDays;
if (duration > 15) {
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('여행 기간은 최대 15일을 초과할 수 없습니다. 15일을 초과하는 여행은 분할하여 각각 별도 여행으로 생성하세요.')),
    );
    return;
}
```

**Step 2: Commit**

```
git add safetrip-mobile/lib/screens/trip/screen_trip_create.dart
git commit -m "feat(flutter): enforce 15-day calendar picker limit (§08.1, P0-4 아키텍처 원칙 적용)"
```

---

## Task 12: Flutter — Minor Member Icon (P3-2) + Guardian Color Constant

**Files:**
- Modify: `safetrip-mobile/lib/core/theme/app_colors.dart` — add guardian card color if needed

**Step 1: Verify guardian color exists**

Check `app_colors.dart:45` — `static const Color guardian = AppTokens.semanticSuccess;` already exists.

No new constant needed. The `guardian` color and `mapMarkerGuardian` (purple) are already defined.

**Step 2: Commit (skip if no change)**

Only commit if a new constant was added.

---

## Task 13: Verification — Run Flutter Analyze + Build Check

**Step 1: Run flutter analyze**

Run: `cd safetrip-mobile && flutter analyze --no-pub`
Expected: No analysis errors in trip_card/ files

**Step 2: Run flutter build (dry run)**

Run: `cd safetrip-mobile && flutter build apk --debug 2>&1 | tail -20`
Expected: BUILD SUCCESSFUL

**Step 3: Run backend compile check**

Run: `cd safetrip-server-api && npx tsc --noEmit`
Expected: No errors

---

## Task 14: Final Commit + Cleanup

**Step 1: Review all changes**

Run: `git diff --stat HEAD~10..HEAD`

**Step 2: Verify file structure**

Run: `find safetrip-mobile/lib/features/trip_card -type f | sort`
Expected:
```
safetrip-mobile/lib/features/trip_card/models/trip_card_data.dart
safetrip-mobile/lib/features/trip_card/providers/trip_card_provider.dart
safetrip-mobile/lib/features/trip_card/services/trip_card_service.dart
safetrip-mobile/lib/features/trip_card/widgets/active_card_content.dart
safetrip-mobile/lib/features/trip_card/widgets/completed_card_content.dart
safetrip-mobile/lib/features/trip_card/widgets/d_day_badge.dart
safetrip-mobile/lib/features/trip_card/widgets/guardian_card.dart
safetrip-mobile/lib/features/trip_card/widgets/member_trip_card.dart
safetrip-mobile/lib/features/trip_card/widgets/no_trip_cta.dart
safetrip-mobile/lib/features/trip_card/widgets/offline_banner.dart
safetrip-mobile/lib/features/trip_card/widgets/planning_card_content.dart
safetrip-mobile/lib/features/trip_card/widgets/privacy_badge.dart
safetrip-mobile/lib/features/trip_card/widgets/trip_info_card_section.dart
safetrip-mobile/lib/features/trip_card/widgets/trip_switch_bottom_sheet.dart
```

**Step 3: Verify P0~P3 mapping completeness**

| # | Feature | Task | Status |
|---|---------|------|--------|
| P0-1 | 카드 기본 렌더링 | Task 6, 7 | member_trip_card + content widgets |
| P0-2 | 상태별 카드 변형 | Task 6 | planning/active/completed content |
| P0-3 | D-day 계산 및 표시 | Task 5 | d_day_badge.dart |
| P0-4 | 15일 제한 달력 피커 | Task 11 | screen_trip_create.dart |
| P0-5 | 서버 15일 검증 | Task 10 | trips.service.ts |
| P0-6 | 여행 전환 바텀시트 | Task 8 | trip_switch_bottom_sheet.dart |
| P0-7 | 탐색 모드 CTA | Task 7 | no_trip_cta.dart |
| P0-8 | 프라이버시 등급 배지 | Task 5 | privacy_badge.dart |
| P1-1 | 가디언 카드 분리 | Task 7, 9 | guardian_card + section |
| P1-2 | 무료/유료 차이 | Task 7 | guardian_card.dart |
| P1-3 | 유료 전환 유도 | Task 7 | guardian_card.dart |
| P1-4 | 오프라인 배지+캐시 | Task 4, 5 | provider + offline_banner |
| P1-5 | 여행 상태 자동 전환 | Task 2 | getCardView() auto-transition |
| P2-1 | 재활성화 버튼 | Task 2, 6 | reactivateTrip + CompletedCard |
| P2-2 | 오늘 일정 요약 | Task 2, 6 | getCardView + ActiveCard |
| P2-3 | D-1/D-0 알림 연동 | Task 2 | getCardView auto-transition |
| P2-4 | 복수 active 경고 | Task 9 | TripInfoCardSection |
| P3-1 | completed 통계 | Task 2, 6 | getCardView + CompletedCard |
| P3-2 | 미성년자 아이콘 | Task 12 | hasMinorMembers field |
| P3-3 | 여행 히스토리 열람 | Task 8 | completed in switch sheet |
| P3-4 | 뷰 캐싱 | Task 1, 4 | SQL view + provider cache |
