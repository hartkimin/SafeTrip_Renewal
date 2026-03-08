/// E2E test environment configuration.
/// Assumes Firebase Emulator + local NestJS server running.
class TestConfig {
  TestConfig._();

  /// Default timeout for pumpAndSettle
  static const Duration settleTimeout = Duration(seconds: 15);

  /// Short wait for animations / transitions
  static const Duration shortWait = Duration(milliseconds: 500);

  /// Medium wait for API calls
  static const Duration mediumWait = Duration(seconds: 2);

  /// Long wait for Firebase auth flows
  static const Duration longWait = Duration(seconds: 5);
}
