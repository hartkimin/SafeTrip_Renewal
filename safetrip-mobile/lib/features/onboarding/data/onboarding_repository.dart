import '../../../services/api_service.dart';

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
  Future<Map<String, dynamic>?> previewInviteCode(String code) async {
    return _api.previewInviteCode(code);
  }

  /// Accept invite code — Scenario B (B-9)
  Future<Map<String, dynamic>?> acceptInvite(String code) async {
    return _api.acceptInvite(code);
  }

  /// Preview guardian invite — Scenario C (C-6)
  Future<Map<String, dynamic>?> previewGuardianInvite(String code) async {
    return _api.previewGuardianInvite(code);
  }

  /// Respond to guardian invite — Scenario C (C-7)
  Future<Map<String, dynamic>?> respondGuardianInvite({
    required String tripId,
    required String linkId,
    required String action,
  }) async {
    return _api.respondGuardianInvite(
      tripId: tripId,
      linkId: linkId,
      action: action,
    );
  }
}
