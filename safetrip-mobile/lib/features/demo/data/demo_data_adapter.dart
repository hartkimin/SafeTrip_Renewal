import 'package:latlong2/latlong.dart';

import '../../../models/geofence.dart';
import '../../../models/location.dart' as location_model;
import '../../../models/schedule.dart';
import '../../../models/trip_member.dart';
import '../../../models/user.dart';
import '../models/demo_scenario.dart';
import 'demo_location_simulator.dart';

/// Demo JSON → Real model conversion utility.
///
/// Converts [DemoScenario] data into app-domain models
/// ([TripMember], [Schedule], [location_model.Location]) for provider seeding.
///
/// Applies simulation events to determine per-member state (SOS, offline,
/// battery drain) at the given simulation time, ensuring compliance with
/// DOC-T3-MBR-019 member tab principles.
class DemoDataAdapter {
  DemoDataAdapter._();

  // ---------------------------------------------------------------------------
  // Members (§4 멤버 카드, §7 정렬, §11 프라이버시)
  // ---------------------------------------------------------------------------

  /// Convert demo members → [TripMember] list with simulated positions
  /// and event-driven state (SOS, offline, battery, location text).
  static List<TripMember> toTripMembers({
    required DemoScenario scenario,
    required int currentSimMinutes,
    String privacyLevel = 'standard',
  }) {
    final positions = DemoLocationSimulator.getPositions(
      scenario: scenario,
      currentSimMinutes: currentSimMinutes,
    );

    // Pre-compute per-member event state at currentSimMinutes
    final memberStates = _computeMemberStates(
      scenario: scenario,
      currentSimMinutes: currentSimMinutes,
    );

    // Find the current day's schedule for location text generation
    final dayNumber = (currentSimMinutes ~/ (24 * 60)) + 1;
    final currentDaySchedule = scenario.schedules.firstWhere(
      (s) => s.day == dayNumber,
      orElse: () => DemoScheduleDay(day: dayNumber, title: '', items: []),
    );

    return scenario.members.where((m) => m.role != 'guardian').map((member) {
      final pos = positions[member.id];
      final lat = pos?.latitude ?? scenario.destination.lat;
      final lng = pos?.longitude ?? scenario.destination.lng;

      // Build guardian links for this member
      final links = scenario.guardianLinks
          .where((gl) => gl.memberId == member.id)
          .toList();
      final guardianSlots = links.asMap().entries.map((entry) {
        final gl = entry.value;
        final guardian = scenario.members.firstWhere(
          (m) => m.id == gl.guardianId,
          orElse: () => DemoMember(
            id: gl.guardianId,
            name: '가디언',
            role: 'guardian',
          ),
        );
        return GuardianSlot(
          linkId: 'demo_link_${member.id}_${entry.key}',
          guardianUserId: gl.guardianId,
          guardianName: guardian.name,
          isPaid: gl.isPaid,
          status: 'accepted',
        );
      }).toList();

      // Get event-driven state for this member
      final state = memberStates[member.id];
      final isSos = state?.isSosActive ?? false;
      final isOnline = state?.isOnline ?? member.isOnline;
      final battery = _computeBattery(member, currentSimMinutes);

      // Generate location text (§4.2, §11.1)
      final locationText = member.locationText ??
          _generateLocationText(
            member: member,
            scheduleItems: currentDaySchedule.items,
            currentSimMinutes: currentSimMinutes,
            destinationName: scenario.destination.name,
          );

      // Determine isScheduleOn based on time-of-day (§11.1)
      final isScheduleOn = _isScheduleTime(currentSimMinutes);

      return TripMember(
        userId: member.id,
        userName: member.name,
        memberRole: UserRoleExtension.fromMemberRole(member.role),
        b2bRoleName: member.b2bRoleName,
        isOnline: isOnline,
        isSosActive: isSos,
        latitude: lat,
        longitude: lng,
        batteryLevel: battery,
        privacyLevel: privacyLevel,
        isScheduleOn: isScheduleOn,
        isMinor: member.isMinor,
        lastLocationText: locationText,
        lastLocationUpdatedAt: DateTime.now().subtract(
          Duration(minutes: isSos ? 0 : (member.id.hashCode.abs() % 5)),
        ),
        guardianLinks: guardianSlots,
      );
    }).toList();
  }

  // ---------------------------------------------------------------------------
  // Schedules
  // ---------------------------------------------------------------------------

  /// Convert demo schedules for a specific day → [Schedule] list.
  static List<Schedule> toSchedules({
    required DemoScenario scenario,
    required int dayNumber,
    required DateTime tripStartDate,
  }) {
    final scheduleDay = scenario.schedules.firstWhere(
      (s) => s.day == dayNumber,
      orElse: () => DemoScheduleDay(day: dayNumber, title: '', items: []),
    );

    final baseDate = tripStartDate.add(Duration(days: dayNumber - 1));
    final now = DateTime.now();

    return scheduleDay.items.asMap().entries.map((entry) {
      final idx = entry.key;
      final item = entry.value;
      final parts = item.time.split(':');
      final hour = int.tryParse(parts[0]) ?? 9;
      final minute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;

      final startTime = DateTime(
        baseDate.year,
        baseDate.month,
        baseDate.day,
        hour,
        minute,
      );
      final endTime = startTime.add(const Duration(hours: 1));

      Map<String, double>? locationCoords;
      if (item.lat != null && item.lng != null) {
        locationCoords = {
          'latitude': item.lat!,
          'longitude': item.lng!,
        };
      }

      return Schedule(
        scheduleId: 'demo_s${dayNumber}_$idx',
        title: item.title,
        scheduleType: 'activity',
        createdBy: 'demo',
        startTime: startTime,
        endTime: endTime,
        scheduleDate:
            '${baseDate.year}-${baseDate.month.toString().padLeft(2, '0')}-${baseDate.day.toString().padLeft(2, '0')}',
        locationName: item.title,
        locationCoords: locationCoords,
        createdAt: now,
        updatedAt: now,
      );
    }).toList();
  }

  /// Get all available schedule dates as 'YYYY-MM-DD' strings.
  static List<String> toScheduleDates({
    required DemoScenario scenario,
    required DateTime tripStartDate,
  }) {
    return scenario.schedules.map((day) {
      final date = tripStartDate.add(Duration(days: day.day - 1));
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    }).toList();
  }

  // ---------------------------------------------------------------------------
  // Geofences (데모 지오펜스 필터링)
  // ---------------------------------------------------------------------------

  /// 현재 시뮬레이션 시간에 활성화된 지오펜스 목록 반환.
  /// schedule_day와 active_from/to를 기반으로 필터링.
  static List<DemoGeofence> getActiveGeofences({
    required DemoScenario scenario,
    required int currentSimMinutes,
  }) {
    if (scenario.geofences.isEmpty) return [];

    final dayNumber = (currentSimMinutes ~/ (24 * 60)) + 1;
    final minuteInDay = currentSimMinutes % (24 * 60);

    return scenario.geofences.where((gf) {
      // Day 필터
      if (!gf.scheduleDays.contains(dayNumber)) return false;

      // 시간 필터 (activeFrom/To 없으면 종일 활성)
      if (gf.activeFrom != null && gf.activeTo != null) {
        final fromParts = gf.activeFrom!.split(':');
        final toParts = gf.activeTo!.split(':');
        final fromMinutes = (int.tryParse(fromParts[0]) ?? 0) * 60 +
            (fromParts.length > 1 ? (int.tryParse(fromParts[1]) ?? 0) : 0);
        final toMinutes = (int.tryParse(toParts[0]) ?? 0) * 60 +
            (toParts.length > 1 ? (int.tryParse(toParts[1]) ?? 0) : 0);

        // 야간 지오펜스 (예: 18:00~08:00) 지원
        if (fromMinutes > toMinutes) {
          // 야간: 18:00~08:00 → fromMinutes(1080) > toMinutes(480)
          // 활성 구간: minuteInDay >= 1080 OR minuteInDay <= 480
          if (minuteInDay < fromMinutes && minuteInDay > toMinutes) return false;
        } else {
          // 주간: 09:00~12:00
          if (minuteInDay < fromMinutes || minuteInDay > toMinutes) return false;
        }
      }

      return true;
    }).toList();
  }

  /// 데모 지오펜스 → GeofenceData 변환 (GeofenceMapRenderer 호환).
  static List<GeofenceData> toGeofenceData({
    required DemoScenario scenario,
    required int currentSimMinutes,
  }) {
    final active = getActiveGeofences(
      scenario: scenario,
      currentSimMinutes: currentSimMinutes,
    );

    return active.map((gf) => GeofenceData(
      geofenceId: gf.id,
      name: gf.name,
      type: 'safe',
      shapeType: 'circle',
      centerLatitude: gf.lat,
      centerLongitude: gf.lng,
      radiusMeters: gf.radiusM,
      isActive: true,
    )).toList();
  }

  // ---------------------------------------------------------------------------
  // Location data for MarkerManager
  // ---------------------------------------------------------------------------

  /// Convert demo positions → [location_model.Location] map for MarkerManager.
  static Map<String, location_model.Location> toLocationMap({
    required DemoScenario scenario,
    required int currentSimMinutes,
  }) {
    final positions = DemoLocationSimulator.getPositions(
      scenario: scenario,
      currentSimMinutes: currentSimMinutes,
    );

    final result = <String, location_model.Location>{};
    for (final member in scenario.members) {
      if (member.role == 'guardian') continue;
      final pos = positions[member.id];
      final lat = pos?.latitude ?? scenario.destination.lat;
      final lng = pos?.longitude ?? scenario.destination.lng;

      result[member.id] = location_model.Location(
        userId: member.id,
        userName: member.name,
        latitude: lat,
        longitude: lng,
        timestamp: DateTime.now(),
        battery: _computeBattery(member, currentSimMinutes),
        isMoving: true,
        activityType: 'walking',
      );
    }
    return result;
  }

  /// Generate user data maps compatible with MarkerManager's getUsers() callback.
  static List<Map<String, dynamic>> toUserMaps({
    required DemoScenario scenario,
    required int currentSimMinutes,
  }) {
    return DemoLocationSimulator.getMemberData(
      scenario: scenario,
      currentSimMinutes: currentSimMinutes,
    );
  }

  /// Convert schedules to marker data for ScheduleMarkerManager.
  static List<Map<String, dynamic>> toScheduleMarkerData(
      List<Schedule> schedules) {
    return schedules
        .where((s) => s.locationCoords != null)
        .map((s) => {
              'schedule_id': s.scheduleId,
              'latitude': s.locationCoords!['latitude'],
              'longitude': s.locationCoords!['longitude'],
              'place_name': s.locationName ?? s.title,
            })
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Track data
  // ---------------------------------------------------------------------------

  /// Get interpolated track up to the current simulation time.
  static List<LatLng> getTrackUpTo({
    required DemoScenario scenario,
    required String memberId,
    required int currentSimMinutes,
  }) {
    final points = scenario.locationTracks[memberId];
    if (points == null || points.isEmpty) return [];

    final track = <LatLng>[];
    for (final point in points) {
      if (point.t > currentSimMinutes) break;
      track.add(point.latLng);
    }

    // Add interpolated current position
    final currentPos = DemoLocationSimulator.getPositions(
      scenario: scenario,
      currentSimMinutes: currentSimMinutes,
    )[memberId];
    if (currentPos != null) {
      track.add(currentPos);
    }

    return track;
  }

  /// Convert demo positions to LatLng map for MarkerManager.updateOriginalPositions().
  static Map<String, LatLng> toOriginalPositions({
    required DemoScenario scenario,
    required int currentSimMinutes,
  }) {
    final positions = DemoLocationSimulator.getPositions(
      scenario: scenario,
      currentSimMinutes: currentSimMinutes,
    );

    final result = <String, LatLng>{};
    for (final member in scenario.members) {
      if (member.role == 'guardian') continue;
      final pos = positions[member.id];
      if (pos != null) {
        result[member.id] = pos;
      } else {
        result[member.id] = scenario.destination.latLng;
      }
    }
    return result;
  }

  // ---------------------------------------------------------------------------
  // Simulation Event Processing (§4.3 SOS, §3.3 경고 배너)
  // ---------------------------------------------------------------------------

  /// Compute per-member state (SOS, online) by replaying simulation events
  /// up to [currentSimMinutes].
  static Map<String, _MemberEventState> _computeMemberStates({
    required DemoScenario scenario,
    required int currentSimMinutes,
  }) {
    final states = <String, _MemberEventState>{};

    // Initialize all members as online, no SOS
    for (final member in scenario.members) {
      if (member.role == 'guardian') continue;
      states[member.id] = _MemberEventState(
        isOnline: member.isOnline,
        isSosActive: false,
      );
    }

    // Replay events chronologically up to current time
    for (final event in scenario.simulationEvents) {
      if (event.timeOffsetMinutes > currentSimMinutes) break;

      final memberId = event.memberId;

      switch (event.type) {
        case 'sos_drill':
        case 'sos_start':
          if (memberId != null) {
            states[memberId]?.isSosActive = true;
          }
          break;
        case 'sos_resolved':
        case 'sos_end':
          if (memberId != null) {
            states[memberId]?.isSosActive = false;
          } else {
            // No member_id → resolve all active SOS
            for (final s in states.values) {
              s.isSosActive = false;
            }
          }
          break;
        case 'member_left':
        case 'member_offline':
          if (memberId != null) {
            states[memberId]?.isOnline = false;
          }
          break;
        case 'member_returned':
        case 'member_online':
          if (memberId != null) {
            states[memberId]?.isOnline = true;
          }
          break;
      }
    }

    return states;
  }

  // ---------------------------------------------------------------------------
  // Battery Simulation (§4.2 — 20% 이하 빨간색)
  // ---------------------------------------------------------------------------

  /// Compute battery level for a member at the given simulation time.
  /// Uses member.battery as initial value, then drains ~5%/hour.
  /// Ensures some members hit the 20% threshold for demo purposes.
  static int _computeBattery(DemoMember member, int currentSimMinutes) {
    final initial = member.battery ?? _defaultBattery(member);
    // Drain rate varies per member for diversity
    final drainPerHour = 3 + (member.id.hashCode.abs() % 4); // 3~6%/hour
    final hoursElapsed = currentSimMinutes / 60.0;
    final drained = (hoursElapsed * drainPerHour).round();
    return (initial - drained).clamp(5, 100);
  }

  /// Default battery levels with intentional variety including low values.
  static int _defaultBattery(DemoMember member) {
    final hash = member.id.hashCode.abs();
    // Assign diverse initial batteries: most 60-95%, some 15-25%
    final values = [92, 85, 78, 65, 88, 23, 71, 95, 18, 82, 60, 73, 90, 15,
                    87, 68, 93, 45, 77, 83, 91, 55, 70, 16, 80, 62, 89, 72];
    return values[hash % values.length];
  }

  // ---------------------------------------------------------------------------
  // Location Text Generation (§4.2, §11.1)
  // ---------------------------------------------------------------------------

  /// Generate location text based on nearest schedule item.
  /// Format: "[장소명] · N분 전" (§4.2)
  static String _generateLocationText({
    required DemoMember member,
    required List<DemoScheduleItem> scheduleItems,
    required int currentSimMinutes,
    required String destinationName,
  }) {
    if (scheduleItems.isEmpty) return '$destinationName 근처';

    // Find the most recent schedule item before current time
    final minuteInDay = currentSimMinutes % (24 * 60);
    DemoScheduleItem? nearest;
    int nearestMinuteDiff = 999999;

    for (final item in scheduleItems) {
      final parts = item.time.split(':');
      final itemMinutes =
          (int.tryParse(parts[0]) ?? 0) * 60 +
          (parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0);
      final diff = minuteInDay - itemMinutes;
      if (diff >= 0 && diff < nearestMinuteDiff) {
        nearestMinuteDiff = diff;
        nearest = item;
      }
    }

    if (nearest != null) {
      final ago = nearestMinuteDiff;
      final agoText = ago < 1
          ? '방금'
          : ago < 60
              ? '$ago분 전'
              : '${ago ~/ 60}시간 전';
      return '${nearest.title} · $agoText';
    }

    // Before first schedule → use first item
    return '${scheduleItems.first.title} 근처';
  }

  // ---------------------------------------------------------------------------
  // Schedule Time Detection (§11.1)
  // ---------------------------------------------------------------------------

  /// Determine if current sim time falls within "schedule ON" hours (07:00~22:00).
  static bool _isScheduleTime(int currentSimMinutes) {
    final minuteInDay = currentSimMinutes % (24 * 60);
    return minuteInDay >= 7 * 60 && minuteInDay < 22 * 60;
  }
}

/// Mutable holder for per-member event-driven state.
class _MemberEventState {
  _MemberEventState({required this.isOnline, required this.isSosActive});
  bool isOnline;
  bool isSosActive;
}
