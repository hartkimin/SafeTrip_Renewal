import 'package:flutter/foundation.dart';

/// 테스트 기기(와이파이폰 등) 인증 우회 설정
///
/// 전화번호가 없는 와이파이폰에서 테스트할 수 있도록
/// 예약된 전화번호 범위와 고정 OTP 코드를 정의합니다.
/// 이 범위의 번호로 인증 시 Firebase Anonymous Auth를 사용하며,
/// 백엔드 DB에서 is_test_device 플래그로 구분됩니다.
class TestAuthConfig {
  TestAuthConfig._();

  /// 테스트 전화번호 범위 (기본: 01099990001 ~ 01099990009)
  static const String testNumberPrefix = '0109999000';
  
  /// 추가 테스트 전화번호 접두어 (01012340001 ~ 01012340009)
  static const String testNumberPrefix2 = '0101234000';

  /// 테스트 인증에 사용되는 고정 OTP 코드
  static const String testOtpCode = '000000';

  /// 주어진 전화번호가 테스트 번호인지 확인
  static bool isTestPhoneNumber(String phoneNumber) {
    final cleaned = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    
    // 기본 테스트 번호 범위
    if (cleaned.startsWith(testNumberPrefix) && cleaned.length == 11) {
      final lastDigit = int.tryParse(cleaned.substring(10));
      if (lastDigit != null && lastDigit >= 1 && lastDigit <= 9) return true;
    }

    // 추가 테스트 번호 범위 (01012340001~9)
    if (cleaned.startsWith(testNumberPrefix2) && cleaned.length == 11) {
      final lastDigit = int.tryParse(cleaned.substring(10));
      if (lastDigit != null && lastDigit >= 1 && lastDigit <= 9) return true;
    }

    // 디버그 모드에서는 끝자리가 0, 1, 3으로 끝나는 모든 번호를 테스트 번호로 허용
    // 사용자가 입력한 01012340003 같은 번호도 여기서 통과됨
    if (kDebugMode && cleaned.length >= 10) {
      if (cleaned.endsWith('0') || cleaned.endsWith('1') || cleaned.endsWith('3')) {
        return true;
      }
    }

    return false;
  }

  /// 테스트 OTP 코드 검증
  static bool isValidTestOtp(String code) {
    return code == testOtpCode;
  }
}
