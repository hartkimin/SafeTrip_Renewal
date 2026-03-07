import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'version_check_service.dart';

enum SplashPhase { branding, loading, retry }

class InitResult {
  final bool firebaseSuccess;
  final bool versionCheckSuccess;
  final VersionCheckResult versionResult;
  final bool isOffline;

  const InitResult({
    required this.firebaseSuccess,
    required this.versionCheckSuccess,
    required this.versionResult,
    required this.isOffline,
  });
}

class SplashInitializer {
  final VersionCheckService _versionService;

  SplashInitializer({VersionCheckService? versionService})
      : _versionService = versionService ?? VersionCheckService();

  Future<InitResult> initialize() async {
    bool firebaseSuccess = false;
    bool versionCheckSuccess = false;
    VersionCheckResult versionResult = VersionCheckResult.none;
    bool isOffline = false;

    final firebaseTask = _refreshFirebaseToken().then((success) {
      firebaseSuccess = success;
    });

    _refreshFcmToken(); // fire and forget

    final versionTask = _versionService.check().then((result) {
      versionResult = result;
      versionCheckSuccess = true;
    }).catchError((_) {
      versionCheckSuccess = false;
    });

    _checkCacheIntegrity(); // fire and forget

    // Task 5: Deep link parsing — handled by DeeplinkService.init() in main.dart
    // before runApp(), forwarded to AuthNotifier via onDeepLink callback.

    try {
      await Future.wait([firebaseTask, versionTask])
          .timeout(const Duration(seconds: 3));
    } on TimeoutException {
      // Distinguish true offline from slow network (§13.1)
      try {
        final connectivity = await Connectivity().checkConnectivity();
        isOffline = connectivity == ConnectivityResult.none;
      } catch (_) {
        isOffline = true;
      }
      debugPrint('[SplashInitializer] Required tasks timed out, offline=$isOffline');
    }

    return InitResult(
      firebaseSuccess: firebaseSuccess,
      versionCheckSuccess: versionCheckSuccess,
      versionResult: versionResult,
      isOffline: isOffline,
    );
  }

  Future<bool> _refreshFirebaseToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.getIdToken(true);
        debugPrint('[SplashInitializer] Firebase token refreshed');
        return true;
      }
      return true; // No user = not logged in, still success
    } catch (e) {
      debugPrint('[SplashInitializer] Firebase refresh failed: $e');
      return false;
    }
  }

  Future<void> _refreshFcmToken() async {
    try {
      await FirebaseMessaging.instance.getToken();
      debugPrint('[SplashInitializer] FCM token refreshed');
    } catch (e) {
      debugPrint('[SplashInitializer] FCM refresh failed (ignored): $e');
    }
  }

  Future<void> _checkCacheIntegrity() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      final authAt = prefs.getString('auth_verified_at');
      if (userId != null && authAt == null) {
        debugPrint('[SplashInitializer] Cache inconsistency detected, clearing');
        await prefs.remove('user_id');
      }
    } catch (e) {
      debugPrint('[SplashInitializer] Cache check failed (ignored): $e');
    }
  }
}
