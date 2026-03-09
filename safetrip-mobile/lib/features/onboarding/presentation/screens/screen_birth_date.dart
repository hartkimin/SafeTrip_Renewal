import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  bool _parentalConsentVerified = false;

  int get _age {
    final now = DateTime.now();
    int age = now.year - _selectedDate.year;
    if (now.month < _selectedDate.month ||
        (now.month == _selectedDate.month && now.day < _selectedDate.day)) {
      age--;
    }
    return age;
  }

  bool get _needsParentalConsent => _hasSelected && _age < 14;

  String? get _ageWarning {
    if (!_hasSelected) return null;
    if (_age < 14) {
      if (_parentalConsentVerified) return null;
      return '만 14세 미만은 법정대리인의 동의가 필요합니다.';
    }
    if (_age < 18) return '만 18세 미만 사용자는 일부 기능이 제한될 수 있습니다.';
    return null;
  }

  bool get _canProceed {
    if (!_hasSelected) return false;
    if (_needsParentalConsent && !_parentalConsentVerified) return false;
    return true;
  }

  Future<void> _onNext() async {
    if (!_canProceed) return;

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

  void _showParentalConsentSheet() {
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ParentalConsentSheet(
        onVerified: () {
          setState(() => _parentalConsentVerified = true);
        },
      ),
    );
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
                      child: CupertinoTheme(
                        data: const CupertinoThemeData(
                          textTheme: CupertinoTextThemeData(
                            dateTimePickerTextStyle: TextStyle(
                              fontSize: 22,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                        ),
                        child: CupertinoDatePicker(
                          mode: CupertinoDatePickerMode.date,
                          initialDateTime: _selectedDate,
                          minimumDate: DateTime(1920),
                          maximumDate: DateTime.now(),
                          onDateTimeChanged: (date) {
                            setState(() {
                              _selectedDate = date;
                              _hasSelected = true;
                              // 날짜 변경 시 이전 인증 초기화
                              _parentalConsentVerified = false;
                            });
                          },
                        ),
                      ),
                    ),
                    // 인증 완료 배지
                    if (_needsParentalConsent && _parentalConsentVerified)
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        margin: const EdgeInsets.only(top: AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.primaryTeal.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color:
                                  AppColors.primaryTeal.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle,
                                color: AppColors.primaryTeal, size: 20),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text('법정대리인 동의가 완료되었습니다.',
                                  style: AppTypography.bodySmall
                                      .copyWith(color: AppColors.primaryTeal)),
                            ),
                          ],
                        ),
                      ),
                    // 경고/안내 메시지
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
                child: _needsParentalConsent && !_parentalConsentVerified
                    ? ElevatedButton(
                        onPressed: _hasSelected
                            ? _showParentalConsentSheet
                            : null,
                        child: const Text('법정대리인 동의 받기'),
                      )
                    : ElevatedButton(
                        onPressed: _canProceed ? _onNext : null,
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

// ─────────────────────────────────────────────
// 법정대리인 동의 바텀시트
// ─────────────────────────────────────────────

enum _ConsentStep { info, otp }

class _ParentalConsentSheet extends StatefulWidget {
  const _ParentalConsentSheet({required this.onVerified});
  final VoidCallback onVerified;

  @override
  State<_ParentalConsentSheet> createState() => _ParentalConsentSheetState();
}

class _ParentalConsentSheetState extends State<_ParentalConsentSheet> {
  final ApiService _api = ApiService();

  _ConsentStep _step = _ConsentStep.info;
  bool _isLoading = false;

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _otpFocusNode = FocusNode();
  String _relationship = '부';

  // OTP 타이머
  int _remainingSeconds = 180;
  Timer? _timer;
  bool _canResend = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    _otpFocusNode.dispose();
    _timer?.cancel();
    super.dispose();
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
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

  String get _fullPhone {
    final raw = _phoneController.text.trim().replaceAll('-', '');
    if (raw.startsWith('0')) return '+82${raw.substring(1)}';
    return '+82$raw';
  }

  Future<void> _sendOtp() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    if (name.isEmpty || phone.isEmpty) {
      _showError('보호자 이름과 전화번호를 입력해주세요.');
      return;
    }

    setState(() => _isLoading = true);
    final ok = await _api.sendMinorConsentOtp(_fullPhone);
    setState(() => _isLoading = false);

    if (!ok) {
      _showError('인증번호 전송에 실패했습니다. 다시 시도해주세요.');
      return;
    }

    setState(() => _step = _ConsentStep.otp);
    _startTimer();
    _otpFocusNode.requestFocus();
  }

  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) return;

    setState(() => _isLoading = true);
    final ok = await _api.submitParentalConsent(
      parentName: _nameController.text.trim(),
      parentPhone: _fullPhone,
      relationship: _relationship,
      otp: otp,
    );
    setState(() => _isLoading = false);

    if (!ok) {
      _showError('인증번호가 올바르지 않습니다.');
      return;
    }

    widget.onVerified();
    if (mounted) Navigator.of(context).pop();
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.sosDanger),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.lg),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 핸들바
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppColors.outline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // 타이틀
              Text(
                _step == _ConsentStep.info
                    ? '법정대리인(보호자) 동의'
                    : '인증번호 입력',
                style: AppTypography.titleLarge
                    .copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                _step == _ConsentStep.info
                    ? '만 14세 미만 사용자는 법정대리인의 동의가\n필요합니다. 보호자 정보를 입력해주세요.'
                    : '보호자 전화번호로 전송된 6자리 인증번호를\n입력해주세요.',
                style: AppTypography.bodyMedium
                    .copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.xl),

              if (_step == _ConsentStep.info) ...[
                _buildInfoStep(),
              ] else ...[
                _buildOtpStep(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 보호자 이름
        Text('보호자 이름', style: AppTypography.labelLarge),
        const SizedBox(height: AppSpacing.xs),
        TextField(
          controller: _nameController,
          decoration: InputDecoration(
            hintText: '홍길동',
            filled: true,
            fillColor: AppColors.surfaceVariant,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radius12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // 관계
        Text('관계', style: AppTypography.labelLarge),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: ['부', '모', '기타'].map((r) {
            final selected = _relationship == r;
            return Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: ChoiceChip(
                label: Text(r),
                selected: selected,
                onSelected: (_) => setState(() => _relationship = r),
                selectedColor: AppColors.primaryTeal.withValues(alpha: 0.15),
                labelStyle: AppTypography.bodyMedium.copyWith(
                  color: selected ? AppColors.primaryTeal : AppColors.textSecondary,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radius12),
                  side: BorderSide(
                    color: selected
                        ? AppColors.primaryTeal
                        : AppColors.outline,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: AppSpacing.lg),

        // 보호자 전화번호
        Text('보호자 전화번호', style: AppTypography.labelLarge),
        const SizedBox(height: AppSpacing.xs),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(AppSpacing.radius12),
          ),
          child: Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Text('🇰🇷 +82', style: AppTypography.bodyLarge),
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
        ),
        const SizedBox(height: AppSpacing.xl),

        // 동의 안내
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '• 개인정보보호법 제22조에 따라 만 14세 미만 아동의 개인정보 수집 시 법정대리인의 동의가 필요합니다.\n'
            '• 인증번호는 보호자 전화번호로 발송됩니다.',
            style: AppTypography.bodySmall
                .copyWith(color: AppColors.textTertiary, height: 1.5),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // 인증번호 요청 버튼
        SizedBox(
          width: double.infinity,
          height: AppSpacing.buttonHeight,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _sendOtp,
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  )
                : const Text('인증번호 요청'),
          ),
        ),
      ],
    );
  }

  Widget _buildOtpStep() {
    return Column(
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
            if (val.length == 6) _verifyOtp();
          },
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _formatTime(_remainingSeconds),
              style: AppTypography.labelMedium
                  .copyWith(color: AppColors.sosDanger),
            ),
            const SizedBox(width: AppSpacing.md),
            TextButton(
              onPressed: _canResend ? _sendOtp : null,
              child: const Text('재전송'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        SizedBox(
          width: double.infinity,
          height: AppSpacing.buttonHeight,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _verifyOtp,
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  )
                : const Text('동의 완료'),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextButton(
          onPressed: () {
            _timer?.cancel();
            setState(() {
              _step = _ConsentStep.info;
              _otpController.clear();
            });
          },
          child: Text('보호자 정보 다시 입력',
              style: AppTypography.bodySmall
                  .copyWith(color: AppColors.textTertiary)),
        ),
      ],
    );
  }
}
