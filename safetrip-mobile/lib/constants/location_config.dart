import 'package:flutter_background_geolocation/flutter_background_geolocation.dart'
    as bg;

/// BackgroundGeolocation 라이브러리 설정 상수
class LocationConfig {
  // ============================================================================
  // 위치 정확도 및 필터링
  // ============================================================================
  /// 위치 정확도 레벨 (HIGH: 고정밀도)
  static int get desiredAccuracy => bg.Config.DESIRED_ACCURACY_HIGH;

  /// 최소 이동 거리 필터 (10m 이상 이동 시 위치 수집)
  static const double distanceFilter = 5.0; // 미터 단위

  /// 위치 업데이트 간격 탄성 조정 비활성화 여부
  static const bool disableElasticity = false;

  // ============================================================================
  // 위치 업데이트 주기
  // ============================================================================
  /// 위치 업데이트 주기 (주석 처리됨,R 필요시 사용)
  static const int locationUpdateInterval = 10000; // 밀리초 단위

  /// 최소 위치 업데이트 주기
  static const int fastestLocationUpdateInterval = 10000; // 밀리초 단위

  // ============================================================================
  // 지오펜스 설정
  // ============================================================================
  /// 지오펜스 모드에서 고정밀도 사용 여부
  static const bool geofenceModeHighAccuracy = true;

  /// 지오펜스 재등록 시 초기 ENTRY 이벤트 방지 여부
  static const bool geofenceInitialTriggerEntry = false;

  /// 지오펜스 모니터링 반경 (1km 반경 내 지오펜스만 모니터링, 배터리 절약)
  static const int geofenceProximityRadius = 1000; // 미터 단위

  // ============================================================================
  // 활동 인식 설정
  // ============================================================================
  /// 모션 감지 활성화 여부
  static const bool disableMotionActivityUpdates = false;

  /// 활동 인식 샘플링 간격 (10초마다 활동 인식)
  static const int activityRecognitionInterval = 10000; // 밀리초 단위

  /// 활동 인식 최소 신뢰도 (100% 이상 신뢰도가 있어야 활동 상태 인식)
  static const int minimumActivityRecognitionConfidence = 50; // 0-100 범위

  // ============================================================================
  // 정지 감지 설정
  // ============================================================================
  /// 정지 시 위치 업데이트 자동 일시정지 여부
  static const bool pausesLocationUpdatesAutomatically = true;

  /// 라이브러리 정지 감지 시간
  static const int stopTimeout = 1; // 분 단위

  /// 실제 정지 감지 시간
  static const int stopRealTimeout = 6; // 분 단위

  /// 지오펜스 안에서의 정지 감지 시간
  static const int stopGeofenceTimeout = 3; // 분 단위

  /// 정지 감지 활성화 여부
  static const bool disableStopDetection = false;

  /// 정지 감지용 지오펜스 반경 (라이브러리용, 0으로 설정 시 정지 지오펜스 생성 안 함)
  static const double stationaryRadius = 100; // 미터 단위

  /// 실제 정지/이동 판단용 반경 (MovementDetector용)
  static const double stationaryRealRadius = 50.0; // 미터 단위

  /// 이동 감지 카운트 (기준점 밖으로 나간 연속 위치 개수)
  static const int movingDetectionCount = 2; // 개수

  // ============================================================================
  // 백그라운드 및 앱 생명주기
  // ============================================================================
  /// 앱 종료 시 위치 추적 중단 여부 (false: 계속 추적)
  static const bool stopOnTerminate = false;

  /// 부팅 시 자동 시작 여부
  static const bool startOnBoot = true;

  /// 헤드리스 모드 활성화 여부 (앱 종료 후에도 이벤트 처리)
  static const bool enableHeadless = true;

  // ============================================================================
  // 하트비트 설정
  // ============================================================================
  /// 하트비트 주기 (정지 상태에서 주기적 위치 확인)
  static const int heartbeatInterval = 600; // 초 단위

  // ============================================================================
  // updated_at 업데이트 설정
  // ============================================================================
  /// updated_at 업데이트 주기 (5분마다 Firebase updated_at만 업데이트)
  static const int updatedAtInterval = 5; // 분 단위

  /// 오프라인 판단 기준 시간 (20분 이상 업데이트 없으면 오프라인)
  static const int offlineThresholdMinutes = 20; // 분 단위

  // ============================================================================
  // RTDB 리스너 설정
  // ============================================================================
  /// RTDB 리스너 업데이트 최소 간격 (Throttling) - 화면 업데이트 제한
  static const int rtdbUpdateThrottleInterval = 10000; // 10초

  // ============================================================================
  // 데이터 저장 설정
  // ============================================================================
  /// 로컬 DB에 저장할 최대 위치 기록 수 (오프라인 대비)
  static const int maxRecordsToPersist = 100;

  // ============================================================================
  // 위치 필터링 설정
  // ============================================================================
  /// 위치 데이터 최대 허용 age
  static const int maxLocationAge = 20000; // 20초

  /// 위치 데이터 최대 허용 정확도 (50m, 미터 단위)
  static const double maxLocationAccuracy = 50.0; // 50미터

  /// 최소 heading 변화 (5도, heading이 6도 이상 변할 때만 저장)
  static const double minHeadingChange = 6.0; // 6도

  // ============================================================================
  // 로그 레벨 및 디버그 설정
  // ============================================================================
  /// 디버그 모드 활성화 여부
  static const bool debug = false;

  /// 설정 초기화 여부 (개발 중에만 true, 프로덕션에서는 false)
  /// true로 설정 시 이전 설정을 완전히 초기화하고 새로운 Config를 적용
  static const bool reset = true;

  /// 로그 레벨 (ERROR: 에러 로그만 출력)
  static int get logLevel => bg.Config.LOG_LEVEL_ERROR;

  // ============================================================================
  // 알림 설정
  // ============================================================================
  /// 포어그라운드 서비스 알림 제목
  static const String notificationTitle = 'SafeTrip';

  /// 포어그라운드 서비스 알림 내용
  static const String notificationText = '당신의 여행을 안전하게 보호하고 있습니다';

  /// 알림 채널 이름
  static const String notificationChannelName = 'Location Tracking';

  /// 알림 아이콘 리소스
  static const String notificationSmallIcon = 'drawable/ic_shield';

  /// 알림 우선순위 (HIGH: 높은 우선순위)
  static bg.NotificationPriority get notificationPriority =>
      bg.NotificationPriority.high;

  // ============================================================================
  // 권한 안내 설정
  // ============================================================================
  /// 위치 서비스 비활성화 시 안내 제목
  static const String locationAuthTitleWhenNotEnabled = '위치 서비스가 비활성화되어 있습니다';

  /// 위치 서비스 꺼짐 시 안내 제목
  static const String locationAuthTitleWhenOff = '위치 서비스가 꺼져 있습니다';

  /// 위치 권한 안내 메시지
  static const String locationAuthInstructions =
      'SafeTrip이 위치 추적을 위해 위치 서비스가 필요합니다. 설정에서 위치 서비스를 활성화해주세요.';

  /// 취소 버튼 텍스트
  static const String locationAuthCancelButton = '취소';

  /// 설정 버튼 텍스트
  static const String locationAuthSettingsButton = '설정';
}
