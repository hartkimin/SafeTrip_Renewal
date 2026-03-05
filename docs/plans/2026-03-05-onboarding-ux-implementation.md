# Onboarding UX Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement the full Phase 1 (P0+P1) onboarding UX per document DOC-T3-ONB-014 v3.1, restructuring the codebase into a feature module with correct flow ordering and new screens.

**Architecture:** Feature module at `lib/features/onboarding/` with Clean Architecture layers. Existing screens are moved and refactored. GoRouter redirect logic updated for scenario-based branching (A: captain, B: invite code, C: guardian, D: returning user). Deep links handled via `app_links` package.

**Tech Stack:** Flutter 3.x, GoRouter, Riverpod, Firebase Auth, Dio, SharedPreferences, app_links

---

## Task 1: Create domain layer (enums and models)

**Files:**
- Create: `safetrip-mobile/lib/features/onboarding/domain/onboarding_type.dart`
- Create: `safetrip-mobile/lib/features/onboarding/domain/onboarding_step.dart`
- Create: `safetrip-mobile/lib/features/onboarding/domain/consent_model.dart`

**Step 1: Create directory structure**

```bash
mkdir -p safetrip-mobile/lib/features/onboarding/{domain,data,presentation/{screens,widgets},providers}
```

**Step 2: Create onboarding_type.dart**

```dart
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
```

**Step 3: Create onboarding_step.dart**

```dart
/// Tracks progress through the onboarding flow.
/// Order matches document v3.1 Scenario A flow.
enum OnboardingStep {
  splash,
  welcome,
  purpose,
  phone,
  otp,
  terms,
  birthDate,
  profile,
  tripCreate,
  inviteConfirm,
  guardianConfirm,
  complete,
}
```

**Step 4: Create consent_model.dart**

```dart
/// §8 consent items — 4 standard + 2 EU-only
class ConsentModel {
  final bool termsOfService;
  final bool privacyPolicy;
  final bool lbsTerms;
  final bool marketing;
  final bool? gdpr;
  final bool? firebaseTransfer;

  const ConsentModel({
    this.termsOfService = false,
    this.privacyPolicy = false,
    this.lbsTerms = false,
    this.marketing = false,
    this.gdpr,
    this.firebaseTransfer,
  });

  bool get allRequiredChecked {
    final base = termsOfService && privacyPolicy && lbsTerms;
    if (gdpr != null) return base && gdpr! && (firebaseTransfer ?? false);
    return base;
  }

  bool get allChecked => allRequiredChecked && marketing;

  ConsentModel copyWith({
    bool? termsOfService,
    bool? privacyPolicy,
    bool? lbsTerms,
    bool? marketing,
    bool? gdpr,
    bool? firebaseTransfer,
  }) {
    return ConsentModel(
      termsOfService: termsOfService ?? this.termsOfService,
      privacyPolicy: privacyPolicy ?? this.privacyPolicy,
      lbsTerms: lbsTerms ?? this.lbsTerms,
      marketing: marketing ?? this.marketing,
      gdpr: gdpr ?? this.gdpr,
      firebaseTransfer: firebaseTransfer ?? this.firebaseTransfer,
    );
  }
}
```

**Step 5: Commit**

```bash
git add safetrip-mobile/lib/features/onboarding/domain/
git commit -m "feat(onboarding): add domain layer — enums and consent model"
```

---

## Task 2: Create onboarding provider (Riverpod state management)

**Files:**
- Create: `safetrip-mobile/lib/features/onboarding/providers/onboarding_provider.dart`

**Step 1: Create the provider**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/onboarding_type.dart';
import '../domain/onboarding_step.dart';
import '../domain/consent_model.dart';

class OnboardingState {
  final OnboardingType type;
  final OnboardingStep step;
  final ConsentModel consent;
  final String? pendingInviteCode;
  final String? pendingGuardianLinkId;
  final String? userId;
  final String? role;
  final bool isEuUser;

  const OnboardingState({
    this.type = OnboardingType.captain,
    this.step = OnboardingStep.splash,
    this.consent = const ConsentModel(),
    this.pendingInviteCode,
    this.pendingGuardianLinkId,
    this.userId,
    this.role,
    this.isEuUser = false,
  });

  OnboardingState copyWith({
    OnboardingType? type,
    OnboardingStep? step,
    ConsentModel? consent,
    String? pendingInviteCode,
    String? pendingGuardianLinkId,
    String? userId,
    String? role,
    bool? isEuUser,
  }) {
    return OnboardingState(
      type: type ?? this.type,
      step: step ?? this.step,
      consent: consent ?? this.consent,
      pendingInviteCode: pendingInviteCode ?? this.pendingInviteCode,
      pendingGuardianLinkId: pendingGuardianLinkId ?? this.pendingGuardianLinkId,
      userId: userId ?? this.userId,
      role: role ?? this.role,
      isEuUser: isEuUser ?? this.isEuUser,
    );
  }
}

class OnboardingNotifier extends StateNotifier<OnboardingState> {
  OnboardingNotifier() : super(const OnboardingState());

  void setType(OnboardingType type) =>
      state = state.copyWith(type: type);

  void setStep(OnboardingStep step) =>
      state = state.copyWith(step: step);

  void setInviteCode(String code) =>
      state = state.copyWith(
        pendingInviteCode: code,
        type: OnboardingType.inviteCode,
      );

  void setGuardianLink(String linkId) =>
      state = state.copyWith(
        pendingGuardianLinkId: linkId,
        type: OnboardingType.guardian,
      );

  void setUserId(String userId) =>
      state = state.copyWith(userId: userId);

  void setRole(String role) =>
      state = state.copyWith(role: role);

  void updateConsent(ConsentModel consent) =>
      state = state.copyWith(consent: consent);

  void setEuUser(bool isEu) =>
      state = state.copyWith(isEuUser: isEu);

  void reset() => state = const OnboardingState();
}

final onboardingProvider =
    StateNotifierProvider<OnboardingNotifier, OnboardingState>(
  (ref) => OnboardingNotifier(),
);
```

**Step 2: Commit**

```bash
git add safetrip-mobile/lib/features/onboarding/providers/
git commit -m "feat(onboarding): add Riverpod onboarding state provider"
```

---

## Task 3: Create data layer (repository and deeplink service)

**Files:**
- Create: `safetrip-mobile/lib/features/onboarding/data/onboarding_repository.dart`
- Create: `safetrip-mobile/lib/features/onboarding/data/deeplink_service.dart`

**Step 1: Create onboarding_repository.dart**

This wraps API calls specific to onboarding. The backend endpoints are:
- `POST /api/v1/auth/consent` — save individual consent record
- `GET /api/v1/trips/invite/:inviteCode` — preview invite
- `POST /api/v1/trips/invite/accept` — accept invite
- `GET /api/v1/trips/guardian-invite/:inviteCode` — preview guardian invite

```dart
import '../../services/api_service.dart';

class OnboardingRepository {
  final ApiService _api;

  OnboardingRepository({ApiService? api}) : _api = api ?? ApiService();

  /// Save individual consent record per §8
  /// Backend: POST /api/v1/auth/consent
  Future<bool> saveConsent({
    required String consentType,
    required bool isGranted,
    String consentVersion = '2026-03-01',
  }) async {
    return _api.saveConsentRecord(
      consentType: consentType,
      consentVersion: consentVersion,
      isGranted: isGranted,
    );
  }

  /// Save all consent items at once
  Future<void> saveAllConsents({
    required bool termsOfService,
    required bool privacyPolicy,
    required bool lbsTerms,
    required bool marketing,
    bool? gdpr,
    bool? firebaseTransfer,
  }) async {
    final items = <MapEntry<String, bool>>[
      MapEntry('terms_of_service', termsOfService),
      MapEntry('privacy_policy', privacyPolicy),
      MapEntry('lbs_terms', lbsTerms),
      MapEntry('marketing', marketing),
    ];
    if (gdpr != null) items.add(MapEntry('gdpr', gdpr));
    if (firebaseTransfer != null) {
      items.add(MapEntry('firebase_international', firebaseTransfer));
    }
    for (final entry in items) {
      await saveConsent(consentType: entry.key, isGranted: entry.value);
    }
  }

  /// Preview invite code info — Scenario B (B-8)
  /// Backend: GET /api/v1/trips/invite/:inviteCode
  Future<Map<String, dynamic>?> previewInviteCode(String code) async {
    return _api.previewInviteCode(code);
  }

  /// Accept invite code — Scenario B (B-9)
  /// Backend: POST /api/v1/trips/invite/accept
  Future<Map<String, dynamic>?> acceptInvite(String code) async {
    return _api.acceptInvite(code);
  }

  /// Preview guardian invite — Scenario C (C-6)
  /// Backend: GET /api/v1/trips/guardian-invite/:inviteCode
  Future<Map<String, dynamic>?> previewGuardianInvite(String code) async {
    return _api.previewGuardianInvite(code);
  }

  /// Respond to guardian invite — Scenario C (C-7)
  /// Backend: PATCH /api/v1/trips/:tripId/guardians/:linkId/respond
  Future<Map<String, dynamic>?> respondGuardianInvite({
    required String tripId,
    required String linkId,
    required String action, // 'accepted' or 'rejected'
  }) async {
    return _api.respondGuardianInvite(
      tripId: tripId,
      linkId: linkId,
      action: action,
    );
  }
}
```

**Step 2: Add missing API methods to ApiService**

In `safetrip-mobile/lib/services/api_service.dart`, add these methods (they map to existing backend endpoints):

```dart
/// POST /api/v1/auth/consent — individual consent record
Future<bool> saveConsentRecord({
  required String consentType,
  required String consentVersion,
  required bool isGranted,
}) async {
  try {
    final response = await _dio.post('/api/v1/auth/consent', data: {
      'consentType': consentType,
      'consentVersion': consentVersion,
      'isGranted': isGranted,
    });
    return response.data['success'] == true;
  } catch (e) {
    debugPrint('[ApiService] saveConsentRecord error: $e');
    return false;
  }
}

/// GET /api/v1/trips/invite/:inviteCode
Future<Map<String, dynamic>?> previewInviteCode(String code) async {
  try {
    final response = await _dio.get('/api/v1/trips/invite/$code');
    if (response.data['success'] == true) {
      return response.data['data'] as Map<String, dynamic>;
    }
    return null;
  } catch (e) {
    debugPrint('[ApiService] previewInviteCode error: $e');
    return null;
  }
}

/// POST /api/v1/trips/invite/accept
Future<Map<String, dynamic>?> acceptInvite(String code) async {
  try {
    final response = await _dio.post('/api/v1/trips/invite/accept', data: {
      'inviteCode': code,
    });
    if (response.data['success'] == true) {
      return response.data['data'] as Map<String, dynamic>;
    }
    return null;
  } catch (e) {
    debugPrint('[ApiService] acceptInvite error: $e');
    return null;
  }
}

/// GET /api/v1/trips/guardian-invite/:inviteCode
Future<Map<String, dynamic>?> previewGuardianInvite(String code) async {
  try {
    final response = await _dio.get('/api/v1/trips/guardian-invite/$code');
    if (response.data['success'] == true) {
      return response.data['data'] as Map<String, dynamic>;
    }
    return null;
  } catch (e) {
    debugPrint('[ApiService] previewGuardianInvite error: $e');
    return null;
  }
}

/// PATCH /api/v1/trips/:tripId/guardians/:linkId/respond
Future<Map<String, dynamic>?> respondGuardianInvite({
  required String tripId,
  required String linkId,
  required String action,
}) async {
  try {
    final response = await _dio.patch(
      '/api/v1/trips/$tripId/guardians/$linkId/respond',
      data: {'action': action},
    );
    if (response.data['success'] == true) {
      return response.data['data'] as Map<String, dynamic>;
    }
    return null;
  } catch (e) {
    debugPrint('[ApiService] respondGuardianInvite error: $e');
    return null;
  }
}
```

**Step 3: Create deeplink_service.dart**

```dart
import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

class DeeplinkService {
  static final DeeplinkService instance = DeeplinkService._();
  DeeplinkService._();

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;

  String? pendingInviteCode;
  String? pendingGuardianCode;

  /// Initialize and listen for deep links
  Future<void> init() async {
    // Check initial link (cold start)
    try {
      final uri = await _appLinks.getInitialLink();
      if (uri != null) _handleUri(uri);
    } catch (e) {
      debugPrint('[DeeplinkService] getInitialLink error: $e');
    }

    // Listen for links while app is running (warm start)
    _sub = _appLinks.uriLinkStream.listen(
      _handleUri,
      onError: (e) => debugPrint('[DeeplinkService] stream error: $e'),
    );
  }

  void _handleUri(Uri uri) {
    debugPrint('[DeeplinkService] Received URI: $uri');

    // safetrip://invite?code=ABC123
    // https://safetrip.app/invite/ABC123
    if (uri.host == 'invite' || uri.pathSegments.contains('invite')) {
      final code = uri.queryParameters['code'] ??
          (uri.pathSegments.length > 1 ? uri.pathSegments.last : null);
      if (code != null) {
        pendingInviteCode = code;
        debugPrint('[DeeplinkService] Invite code captured: $code');
      }
    }

    // safetrip://guardian?link_id=456
    // https://safetrip.app/guardian/456
    if (uri.host == 'guardian' || uri.pathSegments.contains('guardian')) {
      final linkId = uri.queryParameters['link_id'] ??
          (uri.pathSegments.length > 1 ? uri.pathSegments.last : null);
      if (linkId != null) {
        pendingGuardianCode = linkId;
        debugPrint('[DeeplinkService] Guardian link captured: $linkId');
      }
    }
  }

  void clearInviteCode() => pendingInviteCode = null;
  void clearGuardianCode() => pendingGuardianCode = null;

  void dispose() {
    _sub?.cancel();
  }
}
```

**Step 4: Add `app_links` dependency**

```bash
cd safetrip-mobile && flutter pub add app_links
```

**Step 5: Commit**

```bash
git add safetrip-mobile/lib/features/onboarding/data/ safetrip-mobile/lib/services/api_service.dart safetrip-mobile/pubspec.yaml safetrip-mobile/pubspec.lock
git commit -m "feat(onboarding): add data layer — repository, deeplink service, API methods"
```

---

## Task 4: Move existing screens to feature module

**Files:**
- Move: `lib/screens/onboarding/screen_intro.dart` → `lib/features/onboarding/presentation/screens/screen_welcome.dart`
- Move: `lib/screens/onboarding/screen_role_select.dart` → `lib/features/onboarding/presentation/screens/screen_purpose_select.dart`
- Move: `lib/screens/auth/screen_phone_auth.dart` → `lib/features/onboarding/presentation/screens/screen_phone_auth.dart`
- Move: `lib/screens/auth/screen_terms_consent.dart` → `lib/features/onboarding/presentation/screens/screen_terms_consent.dart`
- Move: `lib/screens/auth/screen_profile_setup.dart` → `lib/features/onboarding/presentation/screens/screen_profile_setup.dart`

**Step 1: Move files with git mv (preserves history)**

```bash
cd safetrip-mobile

# Move intro → welcome
git mv lib/screens/onboarding/screen_intro.dart lib/features/onboarding/presentation/screens/screen_welcome.dart

# Move role select → purpose select
git mv lib/screens/onboarding/screen_role_select.dart lib/features/onboarding/presentation/screens/screen_purpose_select.dart

# Move auth screens
git mv lib/screens/auth/screen_phone_auth.dart lib/features/onboarding/presentation/screens/screen_phone_auth.dart
git mv lib/screens/auth/screen_terms_consent.dart lib/features/onboarding/presentation/screens/screen_terms_consent.dart
git mv lib/screens/auth/screen_profile_setup.dart lib/features/onboarding/presentation/screens/screen_profile_setup.dart
```

**Step 2: Update imports in all moved files**

Each moved file needs its relative imports updated. The pattern changes from:
- `../../core/` → `../../../../core/`
- `../../router/` → `../../../../router/`
- `../../services/` → `../../../../services/`

Update every file's import section to use the new relative paths. Also rename classes:
- `ScreenIntro` → `ScreenWelcome` in `screen_welcome.dart`
- `RoleSelectScreen` → `ScreenPurposeSelect` in `screen_purpose_select.dart`

**Step 3: Update imports in app_router.dart**

In `lib/router/app_router.dart`, change all import paths:
```dart
// Old:
import '../screens/onboarding/screen_intro.dart';
import '../screens/onboarding/screen_role_select.dart';
import '../screens/auth/screen_phone_auth.dart';
import '../screens/auth/screen_terms_consent.dart';
import '../screens/auth/screen_profile_setup.dart';

// New:
import '../features/onboarding/presentation/screens/screen_welcome.dart';
import '../features/onboarding/presentation/screens/screen_purpose_select.dart';
import '../features/onboarding/presentation/screens/screen_phone_auth.dart';
import '../features/onboarding/presentation/screens/screen_terms_consent.dart';
import '../features/onboarding/presentation/screens/screen_profile_setup.dart';
```

Update class references: `ScreenIntro()` → `ScreenWelcome()`, `RoleSelectScreen()` → `ScreenPurposeSelect()`.

**Step 4: Verify build compiles**

```bash
cd safetrip-mobile && flutter analyze --no-fatal-infos
```

**Step 5: Commit**

```bash
git add -A
git commit -m "refactor(onboarding): move screens to features/onboarding module"
```

---

## Task 5: Update route paths and flow order

**Files:**
- Modify: `safetrip-mobile/lib/router/route_paths.dart`
- Modify: `safetrip-mobile/lib/router/app_router.dart`

**Step 1: Update route_paths.dart**

Add new paths and rename existing ones to match document:

```dart
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
  static const notificationList = '/notifications';
  static const notifications = notificationList;
  static const aiBriefing = '/ai/briefing';
  static const mainGuardian = '/main/guardian';
  static const paymentPricingGuide = '/payment/pricing-guide';
  static const paymentSuccess = '/payment/success';

  // Dynamic
  static const tripDetail = '/trip/:tripId';
  static const tripSchedule = '/trip/:tripId/schedule';
  static const tripMembers = '/trip/:tripId/members';
}
```

**Step 2: Update app_router.dart route order**

Reorder the GoRoute entries to match the document flow. Key changes:
1. `/onboarding/welcome` replaces `/onboarding/intro`
2. `/onboarding/purpose` replaces `/onboarding/role`
3. `/auth/phone` comes BEFORE `/auth/terms` (flow: phone → terms)
4. Add new routes: `/auth/birth-date`, `/onboarding/invite-confirm`, `/onboarding/guardian-confirm`

The route definitions must be updated with new paths and screen class names. The `_redirect` logic must be updated to use new path constants.

**Step 3: Update redirect logic in app_router.dart**

The `_redirect` method needs these changes:
- Use `RoutePaths.onboardingWelcome` instead of `RoutePaths.onboardingIntro`
- Use `RoutePaths.onboardingPurpose` instead of `RoutePaths.roleSelect`
- Add deeplink parameter handling:
  - Check `DeeplinkService.instance.pendingInviteCode` → set scenario B
  - Check `DeeplinkService.instance.pendingGuardianCode` → set scenario C
- Auth guard must protect new paths too

**Step 4: Verify build**

```bash
cd safetrip-mobile && flutter analyze --no-fatal-infos
```

**Step 5: Commit**

```bash
git add safetrip-mobile/lib/router/
git commit -m "feat(onboarding): update routes to match document flow order"
```

---

## Task 6: Update AuthNotifier for scenario branching

**Files:**
- Modify: `safetrip-mobile/lib/router/auth_notifier.dart`

**Step 1: Add scenario fields**

Add to AuthNotifier:

```dart
import '../features/onboarding/domain/onboarding_type.dart';

// New fields:
OnboardingType? _onboardingType;
String? _pendingGuardianCode;
bool _consentCompleted = false;
bool _profileCompleted = false;

// New getters:
OnboardingType? get onboardingType => _onboardingType;
String? get pendingGuardianCode => _pendingGuardianCode;
bool get consentCompleted => _consentCompleted;
bool get profileCompleted => _profileCompleted;
```

**Step 2: Add scenario setter methods**

```dart
void setOnboardingType(OnboardingType type) {
  _onboardingType = type;
  notifyListeners();
}

void setPendingGuardianCode(String code) {
  _pendingGuardianCode = code;
  _onboardingType = OnboardingType.guardian;
  notifyListeners();
}

void clearPendingGuardianCode() {
  _pendingGuardianCode = null;
  notifyListeners();
}

Future<void> markConsentCompleted() async {
  _consentCompleted = true;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('consent_completed', true);
  notifyListeners();
}

Future<void> markProfileCompleted() async {
  _profileCompleted = true;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('profile_completed', true);
  notifyListeners();
}
```

**Step 3: Update `_loadState()` to restore new fields**

```dart
// Add to _loadState():
_consentCompleted = prefs.getBool('consent_completed') ?? false;
_profileCompleted = prefs.getBool('profile_completed') ?? false;
```

**Step 4: Update `signOut()` to clear new keys**

```dart
// Add to signOut():
await prefs.remove('consent_completed');
await prefs.remove('profile_completed');
_onboardingType = null;
_pendingGuardianCode = null;
_consentCompleted = false;
_profileCompleted = false;
```

**Step 5: Commit**

```bash
git add safetrip-mobile/lib/router/auth_notifier.dart
git commit -m "feat(onboarding): extend AuthNotifier with scenario branching fields"
```

---

## Task 7: Refactor terms consent screen (§8 alignment)

**Files:**
- Modify: `safetrip-mobile/lib/features/onboarding/presentation/screens/screen_terms_consent.dart`

**Step 1: Update consent items**

Replace the current 5 checkboxes with 4 standard + 2 EU-conditional:

Current items: termsOfService, privacyPolicy, locationTerms, ageConsent, marketingConsent
New items: termsOfService, privacyPolicy, lbsTerms, marketing + (EU: gdpr, firebaseTransfer)

Key changes:
- Remove `_ageConsent` checkbox (age is now handled by birth date screen)
- Add EU detection via `WidgetsBinding.instance.platformDispatcher.locale` or timezone
- Add conditional GDPR + Firebase international transfer checkboxes
- Update `_onSubmit()` to call `OnboardingRepository.saveAllConsents()` instead of `ApiService.saveConsent()`
- After submit, navigate to `/auth/birth-date` instead of `/auth/phone` (flow order changed: phone comes BEFORE terms now, so terms navigates to birth-date)

**Step 2: Add EU user detection**

```dart
bool get _isEuUser {
  final locale = WidgetsBinding.instance.platformDispatcher.locale;
  const euCountries = ['AT','BE','BG','HR','CY','CZ','DK','EE','FI','FR',
    'DE','GR','HU','IE','IT','LV','LT','LU','MT','NL','PL','PT','RO',
    'SK','SI','ES','SE'];
  return euCountries.contains(locale.countryCode?.toUpperCase());
}
```

**Step 3: Update navigation**

After consent submit:
```dart
// Navigate to birth date (next step in document flow)
if (mounted) {
  context.push(RoutePaths.authBirthDate, extra: {'role': widget.selectedRole});
}
```

**Step 4: Verify build**

```bash
cd safetrip-mobile && flutter analyze --no-fatal-infos
```

**Step 5: Commit**

```bash
git add safetrip-mobile/lib/features/onboarding/presentation/screens/screen_terms_consent.dart
git commit -m "feat(onboarding): align terms consent with §8 — remove age checkbox, add EU items"
```

---

## Task 8: Create birth date screen

**Files:**
- Create: `safetrip-mobile/lib/features/onboarding/presentation/screens/screen_birth_date.dart`

**Step 1: Create the screen**

The birth date screen:
- CupertinoDatePicker for selecting date
- Age calculation on selection
- 18+: normal proceed to profile
- 14-17: show warning banner, set `is_minor=true` (Phase 2: parental consent)
- <14: show warning modal, set `is_minor=true` (Phase 2: legal guardian OTP)
- Navigate to profile setup on [다음]

```dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../router/route_paths.dart';
import '../../../../services/api_service.dart';

class ScreenBirthDate extends StatefulWidget {
  const ScreenBirthDate({super.key, required this.role});
  final String role;

  @override
  State<ScreenBirthDate> createState() => _ScreenBirthDateState();
}

class _ScreenBirthDateState extends State<ScreenBirthDate> {
  DateTime _selectedDate = DateTime(2000, 1, 1);
  bool _hasSelected = false;

  int get _age {
    final now = DateTime.now();
    int age = now.year - _selectedDate.year;
    if (now.month < _selectedDate.month ||
        (now.month == _selectedDate.month && now.day < _selectedDate.day)) {
      age--;
    }
    return age;
  }

  String? get _ageWarning {
    if (!_hasSelected) return null;
    if (_age < 14) return '만 14세 미만은 법정대리인의 동의가 필요합니다. (Phase 2 구현 예정)';
    if (_age < 18) return '만 18세 미만은 보호자 동의가 필요할 수 있습니다. (Phase 2 구현 예정)';
    return null;
  }

  Future<void> _onNext() async {
    if (!_hasSelected) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_minor', _age < 18);
    await prefs.setString('date_of_birth',
        '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}');

    if (mounted) {
      context.push(RoutePaths.authProfile, extra: {
        'userId': prefs.getString('user_id') ?? '',
        'role': widget.role,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('생년월일')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: AppSpacing.xl),
                    Text('생년월일을 입력해주세요',
                        style: AppTypography.titleLarge
                            .copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: AppSpacing.sm),
                    Text('서비스 이용 연령 확인을 위해 필요합니다',
                        style: AppTypography.bodyMedium
                            .copyWith(color: AppColors.textTertiary)),
                    const SizedBox(height: AppSpacing.xxl),
                    Expanded(
                      child: CupertinoDatePicker(
                        mode: CupertinoDatePickerMode.date,
                        initialDateTime: _selectedDate,
                        minimumDate: DateTime(1920),
                        maximumDate: DateTime.now(),
                        onDateTimeChanged: (date) {
                          setState(() {
                            _selectedDate = date;
                            _hasSelected = true;
                          });
                        },
                      ),
                    ),
                    if (_ageWarning != null)
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        margin: const EdgeInsets.only(top: AppSpacing.md),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.warning_amber,
                                color: Colors.orange.shade700, size: 20),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(_ageWarning!,
                                  style: AppTypography.bodySmall
                                      .copyWith(color: Colors.orange.shade800)),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: SizedBox(
                width: double.infinity,
                height: AppSpacing.buttonHeight,
                child: ElevatedButton(
                  onPressed: _hasSelected ? _onNext : null,
                  child: const Text('다음'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

**Step 2: Register route in app_router.dart**

Add GoRoute for `/auth/birth-date`:
```dart
GoRoute(
  path: RoutePaths.authBirthDate,
  builder: (context, state) {
    final extra = state.extra as Map<String, dynamic>? ?? {};
    return ScreenBirthDate(role: extra['role'] as String? ?? 'crew');
  },
),
```

**Step 3: Commit**

```bash
git add safetrip-mobile/lib/features/onboarding/presentation/screens/screen_birth_date.dart safetrip-mobile/lib/router/app_router.dart
git commit -m "feat(onboarding): add birth date screen with age calculation"
```

---

## Task 9: Create invite confirm screen (Scenario B)

**Files:**
- Create: `safetrip-mobile/lib/features/onboarding/presentation/screens/screen_invite_confirm.dart`

**Step 1: Create the screen**

This screen shows invite code preview info (trip name, captain, role) and lets user confirm or reject.

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../router/route_paths.dart';
import '../../data/onboarding_repository.dart';

class ScreenInviteConfirm extends StatefulWidget {
  const ScreenInviteConfirm({super.key, required this.inviteCode});
  final String inviteCode;

  @override
  State<ScreenInviteConfirm> createState() => _ScreenInviteConfirmState();
}

class _ScreenInviteConfirmState extends State<ScreenInviteConfirm> {
  final _repo = OnboardingRepository();
  bool _isLoading = true;
  bool _isJoining = false;
  Map<String, dynamic>? _inviteInfo;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadInviteInfo();
  }

  Future<void> _loadInviteInfo() async {
    try {
      final info = await _repo.previewInviteCode(widget.inviteCode);
      if (mounted) {
        setState(() {
          _inviteInfo = info;
          _isLoading = false;
          if (info == null) _error = '초대코드가 만료되었거나 유효하지 않습니다.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = '초대코드 확인 중 오류가 발생했습니다.';
        });
      }
    }
  }

  Future<void> _onAccept() async {
    setState(() => _isJoining = true);
    try {
      final result = await _repo.acceptInvite(widget.inviteCode);
      if (result != null && mounted) {
        final prefs = await SharedPreferences.getInstance();
        final groupId = result['group_id']?.toString() ?? '';
        if (groupId.isNotEmpty) {
          await prefs.setString('group_id', groupId);
        }
        context.go(RoutePaths.main);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('참여에 실패했습니다.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isJoining = false);
    }
  }

  void _onReject() {
    context.go(RoutePaths.onboardingPurpose);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('여행 초대 확인')),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _buildError()
                : _buildContent(),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
            const SizedBox(height: AppSpacing.lg),
            Text(_error!, textAlign: TextAlign.center,
                style: AppTypography.bodyLarge),
            const SizedBox(height: AppSpacing.xl),
            TextButton(
              onPressed: () => context.go(RoutePaths.onboardingPurpose),
              child: const Text('돌아가기'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final info = _inviteInfo!;
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: [
                const SizedBox(height: AppSpacing.xxl),
                const Icon(Icons.flight_takeoff, size: 64,
                    color: AppColors.primaryTeal),
                const SizedBox(height: AppSpacing.xl),
                Text('여행에 초대되었습니다!',
                    style: AppTypography.titleLarge
                        .copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: AppSpacing.xxl),
                _infoRow('여행명', info['trip_title'] ?? info['title'] ?? ''),
                _infoRow('캡틴', info['captain_name'] ?? info['created_by'] ?? ''),
                _infoRow('역할', _roleLabel(info['target_role'] ?? info['role'] ?? 'crew')),
                if (info['start_date'] != null)
                  _infoRow('기간', '${info['start_date']} ~ ${info['end_date'] ?? ''}'),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isJoining ? null : _onReject,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(AppSpacing.buttonHeight),
                  ),
                  child: const Text('거절'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isJoining ? null : _onAccept,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(AppSpacing.buttonHeight),
                  ),
                  child: _isJoining
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('참여 확인'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style: AppTypography.bodyMedium
                    .copyWith(color: AppColors.textTertiary)),
          ),
          Expanded(
            child: Text(value,
                style: AppTypography.bodyLarge
                    .copyWith(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'captain': return '캡틴 (여행장)';
      case 'crew_chief': return '크루장';
      case 'crew': return '크루';
      default: return role;
    }
  }
}
```

**Step 2: Register route in app_router.dart**

```dart
GoRoute(
  path: RoutePaths.onboardingInviteConfirm,
  builder: (context, state) {
    final extra = state.extra as Map<String, dynamic>? ?? {};
    return ScreenInviteConfirm(
      inviteCode: extra['inviteCode'] as String? ?? '',
    );
  },
),
```

**Step 3: Commit**

```bash
git add safetrip-mobile/lib/features/onboarding/presentation/screens/screen_invite_confirm.dart safetrip-mobile/lib/router/app_router.dart
git commit -m "feat(onboarding): add invite confirm screen (Scenario B)"
```

---

## Task 10: Create guardian confirm screen (Scenario C)

**Files:**
- Create: `safetrip-mobile/lib/features/onboarding/presentation/screens/screen_guardian_confirm.dart`

**Step 1: Create the screen**

Similar to invite confirm, but shows guardian-specific info (member name, trip info, guardian role explanation).

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../router/route_paths.dart';
import '../../data/onboarding_repository.dart';

class ScreenGuardianConfirm extends StatefulWidget {
  const ScreenGuardianConfirm({super.key, required this.guardianCode});
  final String guardianCode;

  @override
  State<ScreenGuardianConfirm> createState() => _ScreenGuardianConfirmState();
}

class _ScreenGuardianConfirmState extends State<ScreenGuardianConfirm> {
  final _repo = OnboardingRepository();
  bool _isLoading = true;
  bool _isResponding = false;
  Map<String, dynamic>? _inviteInfo;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadInfo();
  }

  Future<void> _loadInfo() async {
    try {
      final info = await _repo.previewGuardianInvite(widget.guardianCode);
      if (mounted) {
        setState(() {
          _inviteInfo = info;
          _isLoading = false;
          if (info == null) _error = '가디언 초대가 만료되었거나 유효하지 않습니다.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = '초대 확인 중 오류가 발생했습니다.';
        });
      }
    }
  }

  Future<void> _onAccept() async {
    setState(() => _isResponding = true);
    try {
      final tripId = _inviteInfo?['trip_id']?.toString() ?? '';
      final linkId = _inviteInfo?['link_id']?.toString() ?? '';
      final result = await _repo.respondGuardianInvite(
        tripId: tripId,
        linkId: linkId,
        action: 'accepted',
      );
      if (result != null && mounted) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_role', 'guardian');
        context.go(RoutePaths.mainGuardian);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('수락에 실패했습니다.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isResponding = false);
    }
  }

  Future<void> _onReject() async {
    setState(() => _isResponding = true);
    try {
      final tripId = _inviteInfo?['trip_id']?.toString() ?? '';
      final linkId = _inviteInfo?['link_id']?.toString() ?? '';
      await _repo.respondGuardianInvite(
        tripId: tripId,
        linkId: linkId,
        action: 'rejected',
      );
    } catch (_) {}
    if (mounted) context.go(RoutePaths.onboardingPurpose);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('가디언 초대')),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _buildError()
                : _buildContent(),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
            const SizedBox(height: AppSpacing.lg),
            Text(_error!, textAlign: TextAlign.center,
                style: AppTypography.bodyLarge),
            const SizedBox(height: AppSpacing.xl),
            TextButton(
              onPressed: () => context.go(RoutePaths.onboardingPurpose),
              child: const Text('돌아가기'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final info = _inviteInfo!;
    final memberName = info['traveler_name'] ?? info['member_name'] ?? '멤버';
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: [
                const SizedBox(height: AppSpacing.xxl),
                const Icon(Icons.shield_outlined, size: 64,
                    color: AppColors.primaryTeal),
                const SizedBox(height: AppSpacing.xl),
                Text('$memberName님이\n가디언으로 초대했습니다',
                    textAlign: TextAlign.center,
                    style: AppTypography.titleLarge
                        .copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: AppSpacing.xxl),
                if (info['trip_title'] != null)
                  _infoRow('여행', info['trip_title']),
                if (info['start_date'] != null)
                  _infoRow('기간', '${info['start_date']} ~ ${info['end_date'] ?? ''}'),
                const SizedBox(height: AppSpacing.xl),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.primaryTeal.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('가디언으로서:',
                          style: AppTypography.bodyMedium
                              .copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: AppSpacing.sm),
                      _bulletPoint('멤버의 위치를 확인할 수 있습니다'),
                      _bulletPoint('긴급 알림을 받을 수 있습니다'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isResponding ? null : _onReject,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(AppSpacing.buttonHeight),
                  ),
                  child: const Text('거절'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isResponding ? null : _onAccept,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(AppSpacing.buttonHeight),
                  ),
                  child: _isResponding
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('수락'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          SizedBox(width: 60,
            child: Text(label,
                style: AppTypography.bodyMedium
                    .copyWith(color: AppColors.textTertiary))),
          Expanded(
            child: Text(value,
                style: AppTypography.bodyLarge
                    .copyWith(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _bulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.sm, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(color: AppColors.primaryTeal)),
          Expanded(child: Text(text, style: AppTypography.bodyMedium)),
        ],
      ),
    );
  }
}
```

**Step 2: Register route in app_router.dart**

```dart
GoRoute(
  path: RoutePaths.onboardingGuardianConfirm,
  builder: (context, state) {
    final extra = state.extra as Map<String, dynamic>? ?? {};
    return ScreenGuardianConfirm(
      guardianCode: extra['guardianCode'] as String? ?? '',
    );
  },
),
```

**Step 3: Commit**

```bash
git add safetrip-mobile/lib/features/onboarding/presentation/screens/screen_guardian_confirm.dart safetrip-mobile/lib/router/app_router.dart
git commit -m "feat(onboarding): add guardian confirm screen (Scenario C)"
```

---

## Task 11: Update purpose select screen for scenario branching

**Files:**
- Modify: `safetrip-mobile/lib/features/onboarding/presentation/screens/screen_purpose_select.dart`

**Step 1: Update navigation**

Currently all roles go to `/auth/terms`. With the new flow order (phone → terms), all roles should go to `/auth/phone`:

```dart
void _onRoleSelected(BuildContext context, String role) {
  // New flow: purpose → phone (not terms)
  context.push(RoutePaths.authPhone, extra: {'role': role});
}
```

**Step 2: Add invite code input option**

When "초대코드 입력" is tapped, navigate to the join code screen (which already exists at `screen_trip_join_code.dart`) OR show an inline input. For consistency with the document, the crew role button should:
1. First go to phone auth
2. After auth + consent + profile, redirect to invite confirm

Alternative simpler approach: keep the "초대코드 입력" button going to the join code input screen first, then after entering the code, proceed through auth flow with the code stored.

Use the simpler approach:
```dart
// "초대코드 입력" button:
onPressed: () {
  context.push(RoutePaths.tripJoin); // existing join code screen
}

// "가디언으로 참여" button:
onPressed: () {
  _onRoleSelected(context, 'guardian');
}
```

**Step 3: Commit**

```bash
git add safetrip-mobile/lib/features/onboarding/presentation/screens/screen_purpose_select.dart
git commit -m "feat(onboarding): update purpose select navigation for new flow"
```

---

## Task 12: Update phone auth screen for new flow position

**Files:**
- Modify: `safetrip-mobile/lib/features/onboarding/presentation/screens/screen_phone_auth.dart`

**Step 1: Update navigation after auth**

Currently after OTP success, navigates to `/auth/profile-setup`. With new flow, should navigate to `/auth/terms`:

```dart
// In _syncAndNavigate(), change:
context.push(RoutePaths.profileSetup, extra: {'userId': userId, 'role': widget.role});

// To:
context.push(RoutePaths.authTerms, extra: {'role': widget.role});
```

Also store userId in SharedPreferences at this point (it's already being stored).

**Step 2: Handle returning user (Scenario D)**

Add check after `syncUserWithFirebase()`:
```dart
// If user already has consent + profile completed, skip to main (Scenario D)
final prefs = await SharedPreferences.getInstance();
final consentDone = prefs.getBool('consent_completed') ?? false;
final onboardingDone = prefs.getBool('onboarding_completed') ?? false;

if (onboardingDone && consentDone) {
  // Scenario D: returning user — skip to main
  await widget.authNotifier.setAuthenticated(
    hasTrip: (prefs.getString('group_id') ?? '').isNotEmpty,
  );
  if (mounted) context.go(RoutePaths.main);
  return;
}
```

**Step 3: Commit**

```bash
git add safetrip-mobile/lib/features/onboarding/presentation/screens/screen_phone_auth.dart
git commit -m "feat(onboarding): phone auth navigates to terms, handles returning users"
```

---

## Task 13: Update profile setup for new flow

**Files:**
- Modify: `safetrip-mobile/lib/features/onboarding/presentation/screens/screen_profile_setup.dart`

**Step 1: Remove birth date from profile**

Birth date is now a separate screen (Task 8). Remove birth date field from profile setup:
- Remove `_birthDateController`, `_selectedBirthDate`, `_selectBirthDate()`, `_calculateAge()`
- Remove the birth date `TextFormField` from the form
- Keep: name, emergency contact, profile photo

**Step 2: Update navigation after profile**

After profile submit, check scenario type to determine next screen:

```dart
// After saving profile:
await widget.authNotifier.completeOnboarding();
await widget.authNotifier.markProfileCompleted();

final prefs = await SharedPreferences.getInstance();

// Check for pending invite code (Scenario B)
final pendingCode = prefs.getString('pending_invite_code');
if (pendingCode != null && pendingCode.isNotEmpty && mounted) {
  context.go(RoutePaths.onboardingInviteConfirm, extra: {
    'inviteCode': pendingCode,
  });
  return;
}

// Check for pending guardian code (Scenario C)
final pendingGuardian = prefs.getString('pending_guardian_code');
if (pendingGuardian != null && pendingGuardian.isNotEmpty && mounted) {
  context.go(RoutePaths.onboardingGuardianConfirm, extra: {
    'guardianCode': pendingGuardian,
  });
  return;
}

// Scenario A: captain — go to trip create or main
if (widget.role == 'captain') {
  await widget.authNotifier.setAuthenticated(hasTrip: false);
  if (mounted) context.go(RoutePaths.tripCreate);
} else {
  final groupId = prefs.getString('group_id') ?? '';
  await widget.authNotifier.setAuthenticated(hasTrip: groupId.isNotEmpty);
  if (mounted) context.go(RoutePaths.main);
}
```

**Step 3: Commit**

```bash
git add safetrip-mobile/lib/features/onboarding/presentation/screens/screen_profile_setup.dart
git commit -m "feat(onboarding): remove birth date from profile, add scenario branching"
```

---

## Task 14: Update trip join code screen with real API

**Files:**
- Modify: `safetrip-mobile/lib/screens/trip/screen_trip_join_code.dart`

**Step 1: Replace stub with real API**

Currently uses `dummy_group_id`. Replace with:

```dart
import '../../features/onboarding/data/onboarding_repository.dart';

// In _onJoin():
final repo = OnboardingRepository();
final info = await repo.previewInviteCode(_fullCode);
if (info == null) {
  // Invalid or expired code
  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('유효하지 않은 초대코드입니다. 캡틴에게 확인해주세요.')),
    );
  }
  return;
}

// Store the code and navigate to auth flow
final prefs = await SharedPreferences.getInstance();
await prefs.setString('pending_invite_code', _fullCode);

if (mounted) {
  // If not authenticated, go through auth flow first
  final userId = prefs.getString('user_id');
  if (userId == null || userId.isEmpty) {
    context.push(RoutePaths.authPhone, extra: {'role': 'crew'});
  } else {
    // Already authenticated, go directly to invite confirm
    context.go(RoutePaths.onboardingInviteConfirm, extra: {
      'inviteCode': _fullCode,
    });
  }
}
```

**Step 2: Update code length from 7 to 6**

Check if invite codes from backend are 6 chars (from `Math.random().toString(36).substring(2, 8).toUpperCase()` → 6 chars). Update controller count from 7 to 6 if needed.

**Step 3: Commit**

```bash
git add safetrip-mobile/lib/screens/trip/screen_trip_join_code.dart
git commit -m "feat(onboarding): connect trip join code to real API"
```

---

## Task 15: Add 15-day trip duration limit

**Files:**
- Modify: `safetrip-mobile/lib/screens/trip/screen_trip_create.dart`

**Step 1: Add duration validation after date range selection**

In the date range picker callback:

```dart
if (picked != null) {
  final duration = picked.end.difference(picked.start).inDays;
  if (duration > 15) {
    // Show 15-day limit modal
    if (mounted) _showTripDurationLimitModal(duration);
    return;
  }
  setState(() {
    _startDate = picked.start;
    _endDate = picked.end;
  });
}
```

**Step 2: Create the limit modal**

```dart
void _showTripDurationLimitModal(int days) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('여행 기간은 최대 15일입니다'),
      content: Text(
        '${days}일 여행을 계획 중이신가요?\n\n'
        '두 개의 여행으로 나누어 생성하세요.\n'
        '예: 1차 여행 (1~15일) + 2차 (16~${days}일)',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            // Auto-set first 15 days
            setState(() {
              _endDate = _startDate!.add(const Duration(days: 14));
            });
          },
          child: const Text('1차 여행 생성'),
        ),
      ],
    ),
  );
}
```

**Step 3: Add inline warning at 15 days**

In the UI, below the date range display:
```dart
if (_startDate != null && _endDate != null) ...[
  final days = _endDate!.difference(_startDate!).inDays + 1;
  if (days >= 14)
    Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        days == 15
            ? '여행 기간이 최대(15일)에 달했습니다'
            : '$days일 여행',
        style: TextStyle(
          color: days == 15 ? Colors.orange : AppColors.textTertiary,
          fontSize: 13,
        ),
      ),
    ),
],
```

**Step 4: Commit**

```bash
git add safetrip-mobile/lib/screens/trip/screen_trip_create.dart
git commit -m "feat(onboarding): add 15-day trip duration limit with modal"
```

---

## Task 16: Initialize deep link service in main.dart

**Files:**
- Modify: `safetrip-mobile/lib/main.dart`

**Step 1: Initialize DeeplinkService**

Add after Firebase init, before `runApp`:

```dart
import 'features/onboarding/data/deeplink_service.dart';

// In main(), after Firebase setup:
await DeeplinkService.instance.init();
```

**Step 2: Pass deep link params to AuthNotifier**

In `_MyAppState.initState()`:

```dart
@override
void initState() {
  super.initState();
  _authNotifier = AuthNotifier();
  _appRouter = AppRouter(_authNotifier);

  // Check for pending deep link params
  final deeplink = DeeplinkService.instance;
  if (deeplink.pendingInviteCode != null) {
    _authNotifier.setPendingInviteCode(deeplink.pendingInviteCode!);
  }
  if (deeplink.pendingGuardianCode != null) {
    _authNotifier.setPendingGuardianCode(deeplink.pendingGuardianCode!);
  }
}
```

**Step 3: Configure app_links in platform files**

For Android (`android/app/src/main/AndroidManifest.xml`), add intent filter:
```xml
<intent-filter android:autoVerify="true">
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="safetrip" />
</intent-filter>
```

For iOS (`ios/Runner/Info.plist`), add URL scheme:
```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>safetrip</string>
        </array>
    </dict>
</array>
```

**Step 4: Commit**

```bash
git add safetrip-mobile/lib/main.dart safetrip-mobile/android/app/src/main/AndroidManifest.xml safetrip-mobile/ios/Runner/Info.plist
git commit -m "feat(onboarding): initialize deep link service in main.dart"
```

---

## Task 17: Update redirect logic for complete scenario routing

**Files:**
- Modify: `safetrip-mobile/lib/router/app_router.dart`

**Step 1: Rewrite `_redirect()` with scenario branching**

```dart
String? _redirect(BuildContext context, GoRouterState state) {
  final path = state.uri.path;
  final isLoading = authNotifier.isLoading;
  final isAuth = authNotifier.isAuthenticated;

  // Still loading → stay on splash
  if (isLoading) return path == RoutePaths.splash ? null : RoutePaths.splash;

  // Splash: decide where to go
  if (path == RoutePaths.splash) {
    if (!isAuth) {
      // Check for deep link scenarios
      if (authNotifier.pendingInviteCode != null) {
        return RoutePaths.authPhone; // B: invite code → auth first
      }
      if (authNotifier.pendingGuardianCode != null) {
        return RoutePaths.authPhone; // C: guardian → auth first
      }
      // A or D: normal flow
      return authNotifier.isFirstLaunch
          ? RoutePaths.onboardingWelcome
          : RoutePaths.onboardingPurpose;
    }
    // Authenticated: go to main
    return authNotifier.hasActiveTrip
        ? RoutePaths.main
        : RoutePaths.noTripHome;
  }

  // Protect auth/onboarding routes from authenticated users
  final onboardingPaths = [
    RoutePaths.onboardingWelcome,
    RoutePaths.onboardingPurpose,
    RoutePaths.authPhone,
    RoutePaths.authTerms,
    RoutePaths.authBirthDate,
    RoutePaths.authProfile,
  ];
  if (isAuth && onboardingPaths.contains(path)) {
    return authNotifier.hasActiveTrip
        ? RoutePaths.main
        : RoutePaths.noTripHome;
  }

  return null;
}
```

**Step 2: Verify all routes are registered**

Ensure all GoRoute entries exist for every RoutePaths constant used.

**Step 3: Verify build**

```bash
cd safetrip-mobile && flutter analyze --no-fatal-infos
```

**Step 4: Commit**

```bash
git add safetrip-mobile/lib/router/app_router.dart
git commit -m "feat(onboarding): complete redirect logic with scenario branching"
```

---

## Task 18: Final integration verification

**Step 1: Full build verification**

```bash
cd safetrip-mobile && flutter analyze --no-fatal-infos
```

**Step 2: Test each scenario manually**

Test scenarios (if device available):
1. **A**: Fresh install → Welcome → Purpose("여행 만들기") → Phone → OTP → Terms → BirthDate → Profile → TripCreate → Main
2. **B**: Fresh install → Purpose("초대코드 입력") → Code Input → Phone → OTP → Terms → BirthDate → Profile → InviteConfirm → Main
3. **C**: Deep link `safetrip://guardian?link_id=xxx` → Phone → OTP → Terms → GuardianConfirm → Main(Guardian)
4. **D**: Return after token valid → Splash → Main directly

**Step 3: Verify file structure matches design**

```bash
find safetrip-mobile/lib/features/onboarding -type f | sort
```

Expected output:
```
safetrip-mobile/lib/features/onboarding/data/deeplink_service.dart
safetrip-mobile/lib/features/onboarding/data/onboarding_repository.dart
safetrip-mobile/lib/features/onboarding/domain/consent_model.dart
safetrip-mobile/lib/features/onboarding/domain/onboarding_step.dart
safetrip-mobile/lib/features/onboarding/domain/onboarding_type.dart
safetrip-mobile/lib/features/onboarding/presentation/screens/screen_birth_date.dart
safetrip-mobile/lib/features/onboarding/presentation/screens/screen_guardian_confirm.dart
safetrip-mobile/lib/features/onboarding/presentation/screens/screen_invite_confirm.dart
safetrip-mobile/lib/features/onboarding/presentation/screens/screen_phone_auth.dart
safetrip-mobile/lib/features/onboarding/presentation/screens/screen_profile_setup.dart
safetrip-mobile/lib/features/onboarding/presentation/screens/screen_purpose_select.dart
safetrip-mobile/lib/features/onboarding/presentation/screens/screen_terms_consent.dart
safetrip-mobile/lib/features/onboarding/presentation/screens/screen_welcome.dart
safetrip-mobile/lib/features/onboarding/providers/onboarding_provider.dart
```

**Step 4: Final commit (if any remaining changes)**

```bash
git add -A && git status
# Only commit if there are changes
```
