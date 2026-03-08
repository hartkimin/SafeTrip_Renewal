import 'package:latlong2/latlong.dart';

enum DemoScenarioId { s1, s2, s3, s4, s5 }

enum DemoRole { captain, crewChief, crew, guardian }

enum DemoPrivacyGrade { safetyFirst, standard, privacyFirst }

class DemoScenario {
  const DemoScenario({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.privacyGrade,
    required this.durationDays,
    required this.destination,
    required this.members,
    required this.guardianLinks,
    required this.schedules,
    required this.simulationEvents,
    required this.locationTracks,
    this.geofences = const [],
  });

  final DemoScenarioId id;
  final String title;
  final String subtitle;
  final DemoPrivacyGrade privacyGrade;
  final int durationDays;
  final DemoDestination destination;
  final List<DemoMember> members;
  final List<DemoGuardianLink> guardianLinks;
  final List<DemoScheduleDay> schedules;
  final List<DemoSimEvent> simulationEvents;
  final Map<String, List<DemoLocationPoint>> locationTracks;
  final List<DemoGeofence> geofences;

  factory DemoScenario.fromJson(Map<String, dynamic> json) {
    return DemoScenario(
      id: DemoScenarioId.values.firstWhere(
        (e) => e.name == json['scenario_id'],
      ),
      title: json['title'] as String,
      subtitle: json['subtitle'] as String? ?? '',
      privacyGrade: _parseGrade(json['privacy_grade'] as String),
      durationDays: json['duration_days'] as int,
      destination: DemoDestination.fromJson(json['destination']),
      members:
          (json['members'] as List).map((e) => DemoMember.fromJson(e)).toList(),
      guardianLinks: (json['guardian_links'] as List? ?? [])
          .map((e) => DemoGuardianLink.fromJson(e))
          .toList(),
      schedules: (json['schedules'] as List)
          .map((e) => DemoScheduleDay.fromJson(e))
          .toList(),
      simulationEvents: (json['simulation_events'] as List)
          .map((e) => DemoSimEvent.fromJson(e))
          .toList(),
      locationTracks:
          (json['location_tracks'] as Map<String, dynamic>? ?? {}).map(
        (k, v) => MapEntry(
          k,
          (v as List).map((e) => DemoLocationPoint.fromJson(e)).toList(),
        ),
      ),
      geofences: (json['geofences'] as List? ?? [])
          .map((e) => DemoGeofence.fromJson(e))
          .toList(),
    );
  }

  static DemoPrivacyGrade _parseGrade(String g) {
    switch (g) {
      case 'safety_first':
        return DemoPrivacyGrade.safetyFirst;
      case 'privacy_first':
        return DemoPrivacyGrade.privacyFirst;
      default:
        return DemoPrivacyGrade.standard;
    }
  }

  String get privacyGradeString {
    switch (privacyGrade) {
      case DemoPrivacyGrade.safetyFirst:
        return 'safety_first';
      case DemoPrivacyGrade.standard:
        return 'standard';
      case DemoPrivacyGrade.privacyFirst:
        return 'privacy_first';
    }
  }

  int get memberCount => members.where((m) => m.role != 'guardian').length;
  int get guardianCount => members.where((m) => m.role == 'guardian').length;
}

class DemoDestination {
  const DemoDestination({
    required this.name,
    required this.countryCode,
    required this.countryName,
    required this.lat,
    required this.lng,
    required this.timezone,
  });

  final String name;
  final String countryCode;
  final String countryName;
  final double lat;
  final double lng;
  final String timezone;

  LatLng get latLng => LatLng(lat, lng);

  factory DemoDestination.fromJson(Map<String, dynamic> json) {
    return DemoDestination(
      name: json['name'] as String,
      countryCode: json['country_code'] as String,
      countryName: json['country_name'] as String? ?? '',
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      timezone: json['timezone'] as String,
    );
  }
}

class DemoMember {
  const DemoMember({
    required this.id,
    required this.name,
    required this.role,
    this.avatar,
    this.isMinor = false,
    this.b2bRoleName,
    this.battery,
    this.isOnline = true,
    this.locationText,
    this.groupRef,
  });

  final String id;
  final String name;
  final String role; // captain, crew_chief, crew, guardian
  final String? avatar;

  /// 그룹 참조 ID (멀티그룹 시나리오에서 소속 그룹 식별)
  final String? groupRef;

  /// 미성년자 여부 (§10.2 — safety_first 강제, 가디언 해제 캡틴 승인)
  final bool isMinor;

  /// B2B 커스텀 역할명 (§01.4 — 학교/여행사/기업)
  final String? b2bRoleName;

  /// 초기 배터리 레벨 (null이면 어댑터가 자동 생성)
  final int? battery;

  /// 초기 온라인 상태
  final bool isOnline;

  /// 초기 위치 텍스트 (null이면 어댑터가 스케줄 기반 생성)
  final String? locationText;

  factory DemoMember.fromJson(Map<String, dynamic> json) {
    return DemoMember(
      id: json['id'] as String,
      name: json['name'] as String,
      role: json['role'] as String,
      avatar: json['avatar'] as String?,
      isMinor: json['is_minor'] as bool? ?? false,
      b2bRoleName: json['b2b_role_name'] as String?,
      battery: json['battery'] as int?,
      isOnline: json['is_online'] as bool? ?? true,
      locationText: json['location_text'] as String?,
      groupRef: json['group_ref'] as String?,
    );
  }
}

class DemoGuardianLink {
  const DemoGuardianLink({
    required this.memberId,
    required this.guardianId,
    this.isPaid = false,
  });

  final String memberId;
  final String guardianId;
  final bool isPaid;

  factory DemoGuardianLink.fromJson(Map<String, dynamic> json) {
    return DemoGuardianLink(
      memberId: json['member_id'] as String,
      guardianId: json['guardian_id'] as String,
      isPaid: json['is_paid'] as bool? ?? false,
    );
  }
}

class DemoScheduleDay {
  const DemoScheduleDay({
    required this.day,
    required this.title,
    required this.items,
  });

  final int day;
  final String title;
  final List<DemoScheduleItem> items;

  factory DemoScheduleDay.fromJson(Map<String, dynamic> json) {
    return DemoScheduleDay(
      day: json['day'] as int,
      title: json['title'] as String,
      items: (json['items'] as List)
          .map((e) => DemoScheduleItem.fromJson(e))
          .toList(),
    );
  }
}

class DemoScheduleItem {
  const DemoScheduleItem({
    required this.time,
    required this.title,
    this.lat,
    this.lng,
  });

  final String time;
  final String title;
  final double? lat;
  final double? lng;

  factory DemoScheduleItem.fromJson(Map<String, dynamic> json) {
    return DemoScheduleItem(
      time: json['time'] as String,
      title: json['title'] as String,
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
    );
  }
}

class DemoSimEvent {
  const DemoSimEvent({
    required this.timeOffsetMinutes,
    required this.type,
    required this.description,
    this.memberId,
    this.data,
  });

  final int timeOffsetMinutes;
  final String type;
  final String description;
  final String? memberId;
  final Map<String, dynamic>? data;

  factory DemoSimEvent.fromJson(Map<String, dynamic> json) {
    return DemoSimEvent(
      timeOffsetMinutes: json['time_offset_minutes'] as int,
      type: json['type'] as String,
      description: json['description'] as String,
      memberId: json['member_id'] as String?,
      data: json['data'] as Map<String, dynamic>?,
    );
  }
}

class DemoGeofence {
  const DemoGeofence({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.radiusM,
    required this.scheduleDays,
    this.activeFrom,
    this.activeTo,
    this.color,
  });

  final String id;
  final String name;
  final double lat;
  final double lng;
  final int radiusM;
  final List<int> scheduleDays;
  final String? activeFrom;
  final String? activeTo;
  final String? color;

  LatLng get latLng => LatLng(lat, lng);

  factory DemoGeofence.fromJson(Map<String, dynamic> json) {
    final rawDay = json['schedule_day'];
    final List<int> days;
    if (rawDay is List) {
      days = rawDay.cast<int>();
    } else if (rawDay is int) {
      days = [rawDay];
    } else {
      days = [1];
    }

    return DemoGeofence(
      id: json['id'] as String,
      name: json['name'] as String,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      radiusM: json['radius_m'] as int,
      scheduleDays: days,
      activeFrom: json['active_from'] as String?,
      activeTo: json['active_to'] as String?,
      color: json['color'] as String?,
    );
  }
}

class DemoLocationPoint {
  const DemoLocationPoint({
    required this.t,
    required this.lat,
    required this.lng,
  });

  final int t; // time offset in minutes
  final double lat;
  final double lng;

  LatLng get latLng => LatLng(lat, lng);

  factory DemoLocationPoint.fromJson(Map<String, dynamic> json) {
    return DemoLocationPoint(
      t: json['t'] as int,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
    );
  }
}
