/// Onboarding scenario types per DOC-T3-ONB-014 v3.1 §2
enum OnboardingType {
  /// Scenario A: Captain creates new trip
  captain,
  /// Scenario B: Join via invite code (crew/crew chief)
  inviteCode,
  /// Scenario C: Guardian invited via SMS link
  guardian,
  /// Scenario D: Returning user (token refresh)
  returning,
}
