import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Firebase Authentication 서비스
/// 전화번호 인증 및 로그인을 담당한다.
class FirebaseAuthService {
  FirebaseAuthService._();
  static final FirebaseAuthService instance = FirebaseAuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// 전화번호로 SMS 인증번호 전송
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required Function(PhoneAuthCredential) verificationCompleted,
    required Function(FirebaseAuthException) verificationFailed,
    required Function(String verificationId, int? resendToken) codeSent,
    required Function(String verificationId) codeAutoRetrievalTimeout,
    int? forceResendingToken,
  }) async {
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: const Duration(seconds: 60),
        forceResendingToken: forceResendingToken,
        verificationCompleted: verificationCompleted,
        verificationFailed: verificationFailed,
        codeSent: codeSent,
        codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
      );
    } catch (e) {
      debugPrint('[FirebaseAuthService] verifyPhoneNumber Error: $e');
      rethrow;
    }
  }

  /// SMS 인증번호로 로그인
  Future<UserCredential> signInWithCredential({
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      debugPrint(
        '[FirebaseAuthService] Sign-in successful: ${userCredential.user?.uid}',
      );
      return userCredential;
    } catch (e) {
      debugPrint('[FirebaseAuthService] signInWithCredential Error: $e');
      rethrow;
    }
  }

  /// 현재 로그인한 사용자의 ID Token 가져오기 (자동 갱신 포함)
  Future<String?> getIdToken({bool forceRefresh = false}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;
      return await user.getIdToken(forceRefresh);
    } catch (e) {
      debugPrint('[FirebaseAuthService] getIdToken Error: $e');
      return null;
    }
  }

  /// 현재 사용자 정보
  User? get currentUser => _auth.currentUser;

  /// 로그아웃
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      debugPrint('[FirebaseAuthService] Sign-out successful');
    } catch (e) {
      debugPrint('[FirebaseAuthService] signOut Error: $e');
      rethrow;
    }
  }
}
