import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/onboarding/domain/onboarding_type.dart';

/// 앱의 인증 상태 및 온보딩 흐름을 관리하는 클래스
class AuthNotifier extends ChangeNotifier {
  AuthNotifier() {
    _loadState();
  }

  bool _isAuthenticated = false;
  bool _hasActiveTrip = false;
  bool _isFirstLaunch = true;
  bool _isLoading = true;
  String? _pendingInviteCode;
  String _onboardingStep = 'complete';
  OnboardingType? _onboardingType;
  String? _pendingGuardianCode;
  bool _consentCompleted = false;
  bool _profileCompleted = false;

  // §6.1: invite deeplink received but code parse failed
  bool _inviteDeeplinkFailed = false;

  // Splash initialization state (DOC-T3-SPL-028 §4, §7)
  bool _initCompleted = false;
  bool _requiresForceUpdate = false;
  String? _forceUpdateStoreUrl;
  bool _isOffline = false;
  bool _optionalUpdateAvailable = false;
  String? _optionalUpdateStoreUrl;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  bool get isAuthenticated => _isAuthenticated;
  bool get hasActiveTrip => _hasActiveTrip;
  bool get isFirstLaunch => _isFirstLaunch;
  bool get isLoading => _isLoading;
  String? get pendingInviteCode => _pendingInviteCode;
  String get onboardingStep => _onboardingStep;
  OnboardingType? get onboardingType => _onboardingType;
  String? get pendingGuardianCode => _pendingGuardianCode;
  bool get consentCompleted => _consentCompleted;
  bool get profileCompleted => _profileCompleted;
  bool get inviteDeeplinkFailed => _inviteDeeplinkFailed;
  bool get initCompleted => _initCompleted;
  bool get requiresForceUpdate => _requiresForceUpdate;
  String? get forceUpdateStoreUrl => _forceUpdateStoreUrl;
  bool get isOffline => _isOffline;
  bool get optionalUpdateAvailable => _optionalUpdateAvailable;
  String? get optionalUpdateStoreUrl => _optionalUpdateStoreUrl;

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();

    final userId = prefs.getString('user_id');
    final authVerifiedAtStr = prefs.getString('auth_verified_at');
    final groupId = prefs.getString('group_id');
    final onboardingCompleted = prefs.getBool('onboarding_completed') ?? false;

    bool tokenValid = false;
    if (userId != null && userId.isNotEmpty && authVerifiedAtStr != null) {
      final verifiedAt = DateTime.tryParse(authVerifiedAtStr);
      if (verifiedAt != null) {
        // 인증 후 30일간 유효한 것으로 간주
        tokenValid = DateTime.now().toUtc().difference(verifiedAt).inDays < 30;
      }
    }

    _isAuthenticated = tokenValid;
    _hasActiveTrip = groupId != null && groupId.isNotEmpty;
    _isFirstLaunch = !onboardingCompleted;
    _onboardingStep = prefs.getString('onboarding_step') ?? 'complete';
    _consentCompleted = prefs.getBool('consent_completed') ?? false;
    _profileCompleted = prefs.getBool('profile_completed') ?? false;
    _isLoading = false;

    notifyListeners();
  }

  Future<void> completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);
    _isFirstLaunch = false;
    notifyListeners();
  }

  Future<void> setAuthenticated({required bool hasTrip}) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString('auth_verified_at') == null) {
      await prefs.setString('auth_verified_at', DateTime.now().toUtc().toIso8601String());
    }
    _isAuthenticated = true;
    _hasActiveTrip = hasTrip;
    notifyListeners();
  }

  Future<void> setDemoAuthenticated() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_verified_at', DateTime.now().toUtc().toIso8601String());
    _isAuthenticated = true;
    _hasActiveTrip = true; // 데모 모드는 활성 여행이 있다고 가정
    notifyListeners();
  }

  Future<void> signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      debugPrint('[AuthNotifier] SignOut Error: $e');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_id');
    await prefs.remove('auth_verified_at');
    await prefs.remove('group_id');
    await prefs.remove('onboarding_step');
    await prefs.remove('consent_completed');
    await prefs.remove('profile_completed');

    _isAuthenticated = false;
    _hasActiveTrip = false;
    _onboardingStep = 'complete';
    _onboardingType = null;
    _pendingGuardianCode = null;
    _consentCompleted = false;
    _profileCompleted = false;
    notifyListeners();
  }

  void setPendingInviteCode(String code) {
    _pendingInviteCode = code;
    notifyListeners();
  }

  void clearPendingInviteCode() {
    _pendingInviteCode = null;
    notifyListeners();
  }

  /// §6.1: Mark that an invite deeplink was received but parsing failed
  void setInviteDeeplinkFailed() {
    _inviteDeeplinkFailed = true;
    notifyListeners();
  }

  void clearInviteDeeplinkFailed() {
    _inviteDeeplinkFailed = false;
  }

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

  /// Called by SplashInitializer when background tasks complete (DOC-T3-SPL-028 §5)
  void setInitResult({
    required bool firebaseSuccess,
    required bool requiresForceUpdate,
    String? forceUpdateStoreUrl,
    bool isOffline = false,
    bool optionalUpdateAvailable = false,
    String? optionalUpdateStoreUrl,
  }) {
    if (!firebaseSuccess && _isAuthenticated) {
      // Firebase token refresh failed — force re-login via Route A (§11.1)
      // Spec: "로컬 토큰 삭제 → 경로 A(신규 유저 흐름) 분기"
      // Set _isFirstLaunch=true to route to Welcome screen (in-memory only, intentional)
      _isAuthenticated = false;
      _isFirstLaunch = true;
    }
    _requiresForceUpdate = requiresForceUpdate;
    _forceUpdateStoreUrl = forceUpdateStoreUrl;
    _isOffline = isOffline;
    _optionalUpdateAvailable = optionalUpdateAvailable;
    _optionalUpdateStoreUrl = optionalUpdateStoreUrl;
    _initCompleted = true;

    // Start connectivity monitoring for offline banner auto-dismiss (§13.2)
    _connectivitySub ??= Connectivity().onConnectivityChanged.listen((results) {
      final nowOffline = results.every((r) => r == ConnectivityResult.none);
      if (_isOffline != nowOffline) {
        _isOffline = nowOffline;
        notifyListeners();
      }
    });

    notifyListeners();
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }
}
