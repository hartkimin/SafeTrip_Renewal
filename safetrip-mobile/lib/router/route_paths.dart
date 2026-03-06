class RoutePaths {
  static const splash = '/';
  static const main = '/main';
  static const noTripHome = '/trip/no-trip-home';

  // Onboarding (document order: welcome → purpose → phone → terms → birthDate → profile)
  static const onboardingWelcome = '/onboarding/welcome';
  static const onboardingPurpose = '/onboarding/purpose';
  static const authPhone = '/auth/phone';
  static const authTerms = '/auth/terms';
  static const authBirthDate = '/auth/birth-date';
  static const authProfile = '/auth/profile';
  static const onboardingInviteConfirm = '/onboarding/invite-confirm';
  static const onboardingGuardianConfirm = '/onboarding/guardian-confirm';

  // Keep old names as aliases for backward compatibility during migration
  static const onboardingIntro = onboardingWelcome;
  static const roleSelect = onboardingPurpose;
  static const termsConsent = authTerms;
  static const profileSetup = authProfile;

  // Trip
  static const tripCreate = '/trip/create';
  static const tripJoin = '/trip/join';
  static const tripConfirm = '/trip/confirm';
  static const tripDemo = '/trip/demo';
  static const tripPreview = '/trip/preview';

  // Settings
  static const settingsMain = '/settings';
  static const privacySettings = '/settings/privacy';
  static const guardianManagement = '/settings/guardians';

  // Other
  static const permission = '/permission';
  static const notificationList = '/notifications';
  static const notifications = notificationList;
  static const aiBriefing = '/ai/briefing';
  static const mainGuardian = '/main/guardian';
  static const paymentPricingGuide = '/payment/pricing-guide';
  static const paymentSuccess = '/payment/success';

  // Demo
  static const demoScenarioSelect = '/demo/scenario-select';
  static const demoMain = '/demo/main';
  static const demoComplete = '/demo/complete';

  // Dynamic
  static const tripDetail = '/trip/:tripId';
  static const tripSchedule = '/trip/:tripId/schedule';
  static const tripMembers = '/trip/:tripId/members';
}
