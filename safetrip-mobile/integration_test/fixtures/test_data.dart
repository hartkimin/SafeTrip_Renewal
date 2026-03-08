/// Test data constants for E2E flows.
class TestData {
  TestData._();

  // ── Onboarding ─────────────────────────────
  /// Firebase Emulator test phone number (auto-verified)
  static const testPhoneNumber = '01012345678';

  /// OTP code for Firebase Emulator (auto-verify returns any code)
  static const testOtpCode = '123456';

  /// Test user display name
  static const testUserName = '테스트유저';

  /// Test birth date (adult, 1995-06-15)
  static const testBirthYear = 1995;
  static const testBirthMonth = 6;
  static const testBirthDay = 15;

  // ── Trip ────────────────────────────────────
  /// Test trip name
  static const testTripName = '도쿄 자유여행';

  /// Test country selection
  static const testCountryName = '일본';
  static const testCountryCode = 'JP';

  /// Test destination city
  static const testDestinationCity = '도쿄';

  // ── Schedule ───────────────────────────────
  /// Test schedule title
  static const testScheduleTitle = '시부야 산책';

  /// Test schedule location
  static const testScheduleLocation = '시부야역';

  // ── Guardian ───────────────────────────────
  /// Guardian phone number
  static const guardianPhoneNumber = '01098765432';

  // ── Chat ────────────────────────────────────
  /// Test chat message
  static const testChatMessage = '안녕하세요, 테스트 메시지입니다';

  // ── Profile ─────────────────────────────────
  /// Updated display name
  static const updatedUserName = '수정된이름';
}
