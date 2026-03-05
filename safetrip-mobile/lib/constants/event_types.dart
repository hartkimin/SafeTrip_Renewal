/// 이벤트 타입 상수
/// 서버는 event_type과 event_subtype 검증을 하지 않으므로,
/// 새로운 이벤트 추가 시 서버 수정이 필요 없습니다.
class EventTypes {
  static const String geofence = 'geofence';
  static const String session = 'session';
  static const String sessionEvent = 'session_event';
  static const String deviceStatus = 'device_status';
  static const String sos = 'sos';
}

/// 지오펜스 이벤트 서브타입
class GeofenceEventSubtypes {
  static const String enter = 'enter';
  static const String exit = 'exit';
  static const String dwell = 'dwell';
}

/// 세션 이벤트 서브타입
class SessionEventSubtypes {
  static const String start = 'start';
  static const String end = 'end';
  static const String kill = 'kill';
  static const String prematureEnd = 'premature_end';
  static const String lastLocationSaved = 'last_location_saved';
  static const String lastLocationCleared = 'last_location_cleared';
}

/// 세션 이벤트 서브타입
class SessionEventEventSubtypes {
  static const String rapidAcceleration = 'rapid_acceleration';
  static const String rapidDeceleration = 'rapid_deceleration';
  static const String speeding = 'speeding';
}

/// 디바이스 상태 이벤트 서브타입
class DeviceStatusEventSubtypes {
  static const String batteryWarning = 'battery_warning';
  static const String batteryCharging = 'battery_charging';
  static const String mockLocation = 'mock_location';
  static const String locationPermissionDenied = 'location_permission_denied';
  static const String networkChange = 'network_change';
  static const String appLifecycle = 'app_lifecycle';
  static const String locationSharingEnabled = 'location_sharing_enabled';
  static const String locationSharingDisabled = 'location_sharing_disabled';
  static const String online = 'online';
  static const String offline = 'offline';
}

/// SOS 이벤트 서브타입
class SosEventSubtypes {
  static const String emergency = 'emergency';
  static const String crime = 'crime';
  static const String medical = 'medical';
}
