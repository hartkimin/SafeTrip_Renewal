/// 배터리 인식 GPS 주기 관리 (오프라인 원칙 DOC-T2-OFL-016 §7)
class BatteryGpsManager {
  /// GPS 수집 주기 계산 (초 단위 반환)
  ///
  /// [privacyLevel]: 'safety_first', 'standard', 'privacy_first'
  /// [isOffline]: 현재 오프라인 상태 여부
  /// [batteryLevel]: 0-100 배터리 잔량
  /// [isSosActive]: SOS 활성 상태 여부
  static int calculateInterval({
    required String privacyLevel,
    required bool isOffline,
    required int batteryLevel,
    required bool isSosActive,
  }) {
    // SOS active (§7.1)
    if (isSosActive) {
      return isOffline ? 30 : 10;
    }

    // Base interval by privacy level x network state (§7.1)
    int baseInterval;
    switch (privacyLevel) {
      case 'safety_first':
        baseInterval = isOffline ? 300 : 30;
        break;
      case 'standard':
        baseInterval = isOffline ? 300 : 60;
        break;
      case 'privacy_first':
        baseInterval = isOffline ? 600 : 300;
        break;
      default:
        baseInterval = isOffline ? 300 : 60;
    }

    // Battery thresholds (§7.3)
    if (batteryLevel < 5) {
      // SOS standby mode -- very infrequent
      return baseInterval * 4;
    } else if (batteryLevel < 10) {
      return baseInterval * 4;
    } else if (batteryLevel < 20) {
      return baseInterval * 2;
    }

    return baseInterval;
  }

  /// 배터리 경고 수준 반환
  /// null이면 경고 없음, 값이 있으면 해당 임계값 경고
  static int? getBatteryWarningLevel(int batteryLevel) {
    if (batteryLevel < 5) return 5;
    if (batteryLevel < 10) return 10;
    if (batteryLevel < 20) return 20;
    return null;
  }

  /// 현재 배터리 상태에서 비활성화할 항목 목록 (§7.2)
  static List<String> getDisabledFeatures({
    required bool isOffline,
    required int batteryLevel,
  }) {
    final disabled = <String>[];

    if (isOffline) {
      disabled.addAll([
        'realtime_location_upload',
        'ai_features',
        'mofa_api_refresh',
        'fcm_retry',
      ]);
    }

    if (batteryLevel < 10) {
      disabled.add('non_emergency_features');
    }

    return disabled;
  }
}
