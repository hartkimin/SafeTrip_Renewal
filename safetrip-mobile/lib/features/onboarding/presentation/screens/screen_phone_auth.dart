import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../router/auth_notifier.dart';
import '../../../../router/route_paths.dart';
import '../../../../services/api_service.dart';
import '../../../../services/auth/firebase_auth_service.dart';
import '../../../../utils/phone_parser.dart';

enum _PhoneAuthStep { enterPhone, enterOtp }

class PhoneAuthScreen extends StatefulWidget {
  const PhoneAuthScreen({
    super.key,
    required this.role,
    required this.authNotifier,
  });
  final String role;
  final AuthNotifier authNotifier;

  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseAuthService _authService = FirebaseAuthService.instance;
  final ApiService _apiService = ApiService();
  bool _isLoading = false;
  final String _countryCode = '+82';

  _PhoneAuthStep _step = _PhoneAuthStep.enterPhone;

  final TextEditingController _phoneController = TextEditingController();
  final ValueNotifier<bool> _phoneHasText = ValueNotifier<bool>(false);

  final TextEditingController _otpController = TextEditingController();
  final FocusNode _otpFocusNode = FocusNode();
  final ValueNotifier<bool> _otpHasText = ValueNotifier<bool>(false);
  String? _currentVerificationId;
  int? _forceResendingToken;

  int _remainingSeconds = 180;
  Timer? _timer;
  bool _canResend = false;

  late final AnimationController _slideController;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));

    _phoneController.addListener(() {
      _phoneHasText.value = _phoneController.text.isNotEmpty;
    });
  }

  @override
  void dispose() {
    _slideController.dispose();
    _timer?.cancel();
    _phoneController.dispose();
    _phoneHasText.dispose();
    _otpController.dispose();
    _otpFocusNode.dispose();
    _otpHasText.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _remainingSeconds = 180;
    _canResend = false;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        if (mounted) setState(() => _remainingSeconds--);
      } else {
        if (mounted) setState(() => _canResend = true);
        timer.cancel();
      }
    });
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  Future<void> _sendCode() async {
    final phoneInput = _phoneController.text.trim();
    if (phoneInput.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final fullPhone = PhoneParser.combinePhoneNumber(
        _countryCode,
        phoneInput,
      );

      await _authService.verifyPhoneNumber(
        phoneNumber: fullPhone,
        forceResendingToken: _forceResendingToken,
        verificationCompleted: (credential) async {
          final userCredential = await FirebaseAuth.instance
              .signInWithCredential(credential);
          await _syncAndNavigate(userCredential);
        },
        verificationFailed: (e) {
          setState(() => _isLoading = false);
          _showError(e.message ?? '인증번호 전송에 실패했습니다.');
        },
        codeSent: (verificationId, resendToken) {
          setState(() {
            _currentVerificationId = verificationId;
            _forceResendingToken = resendToken;
            _step = _PhoneAuthStep.enterOtp;
            _isLoading = false;
          });
          _startTimer();
          _slideController.forward(from: 0);
          _otpFocusNode.requestFocus();
        },
        codeAutoRetrievalTimeout: (verificationId) {
          _currentVerificationId = verificationId;
        },
      );
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('오류가 발생했습니다: $e');
    }
  }

  Future<void> _verifyCode() async {
    final code = _otpController.text.trim();
    if (code.length != 6 || _currentVerificationId == null) return;

    setState(() => _isLoading = true);
    try {
      final userCredential = await _authService.signInWithCredential(
        verificationId: _currentVerificationId!,
        smsCode: code,
      );
      await _syncAndNavigate(userCredential);
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('인증번호가 올바르지 않습니다.');
    }
  }

  Future<void> _syncAndNavigate(UserCredential userCredential) async {
    try {
      final idToken = await userCredential.user?.getIdToken();
      if (idToken == null) throw Exception('Token error');

      final userData = await _apiService.syncUserWithFirebase(
        idToken,
        _countryCode,
      );
      if (userData == null) throw Exception('Sync error');

      final prefs = await SharedPreferences.getInstance();
      final userId = userData['user_id'] as String;
      await prefs.setString('user_id', userId);
      await prefs.setString(
        'auth_verified_at',
        DateTime.now().toUtc().toIso8601String(),
      );

      if (!mounted) return;

      // Scenario D: returning user who already completed onboarding — skip to main
      final consentDone = prefs.getBool('consent_completed') ?? false;
      final onboardingDone = prefs.getBool('onboarding_completed') ?? false;

      if (onboardingDone && consentDone) {
        await widget.authNotifier.setAuthenticated(
          hasTrip: (prefs.getString('group_id') ?? '').isNotEmpty,
        );
        if (mounted) context.go(RoutePaths.main);
        return;
      }

      // 약관 동의 화면으로 이동
      context.push(
        RoutePaths.authTerms,
        extra: {'role': widget.role},
      );

      await widget.authNotifier.setAuthenticated(hasTrip: false);
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('사용자 동기화에 실패했습니다.');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.sosDanger),
    );
  }

  void _onBack() {
    if (_step == _PhoneAuthStep.enterOtp) {
      setState(() {
        _step = _PhoneAuthStep.enterPhone;
        _otpController.clear();
      });
      _slideController.reverse();
    } else {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOtp = _step == _PhoneAuthStep.enterOtp;
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _onBack,
        ),
        title: Text(isOtp ? '인증번호 입력' : '전화번호 입력'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.lg),
              Text(
                isOtp ? '전송된 6자리 코드를\n입력해주세요' : 'SafeTrip 시작을 위해\n전화번호가 필요합니다',
                style: AppTypography.headlineMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              if (!isOtp) _buildPhoneInput() else _buildOtpInput(),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: AppSpacing.buttonHeight,
                child: ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : (isOtp ? _verifyCode : _sendCode),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(isOtp ? '인증하기' : '인증번호 받기'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneInput() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppSpacing.radius12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Text('🇰🇷 $_countryCode', style: AppTypography.bodyLarge),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                hintText: '010-0000-0000',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtpInput() {
    return SlideTransition(
      position: _slideAnimation,
      child: Column(
        children: [
          TextField(
            controller: _otpController,
            focusNode: _otpFocusNode,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: AppTypography.displayLarge.copyWith(letterSpacing: 8),
            decoration: const InputDecoration(hintText: '000000'),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            onChanged: (val) {
              if (val.length == 6) _verifyCode();
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _formatTime(_remainingSeconds),
                style: AppTypography.labelMedium.copyWith(
                  color: AppColors.sosDanger,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              TextButton(
                onPressed: _canResend ? _sendCode : null,
                child: const Text('재전송'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
