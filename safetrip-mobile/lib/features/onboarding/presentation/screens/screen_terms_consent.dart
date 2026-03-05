import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../constants/app_terms.dart';
import '../../../../router/route_paths.dart';
import '../../data/onboarding_repository.dart';

/// A-07 Terms Consent Screen
class ScreenTermsConsent extends StatefulWidget {
  const ScreenTermsConsent({super.key, required this.selectedRole});
  final String selectedRole;

  @override
  State<ScreenTermsConsent> createState() => _ScreenTermsConsentState();
}

class _ScreenTermsConsentState extends State<ScreenTermsConsent> {
  final OnboardingRepository _repo = OnboardingRepository();
  bool _isLoading = false;

  bool _termsOfService = false;
  bool _privacyPolicy = false;
  bool _locationTerms = false;
  bool _marketingConsent = false;

  // EU-only consent fields
  bool? _gdprConsent;
  bool? _firebaseTransfer;

  bool get _isEuUser {
    final locale = WidgetsBinding.instance.platformDispatcher.locale;
    const euCountries = [
      'AT', 'BE', 'BG', 'HR', 'CY', 'CZ', 'DK', 'EE', 'FI', 'FR',
      'DE', 'GR', 'HU', 'IE', 'IT', 'LV', 'LT', 'LU', 'MT', 'NL',
      'PL', 'PT', 'RO', 'SK', 'SI', 'ES', 'SE',
    ];
    return euCountries.contains(locale.countryCode?.toUpperCase());
  }

  bool get _allRequiredChecked {
    final base = _termsOfService && _privacyPolicy && _locationTerms;
    if (_isEuUser) return base && (_gdprConsent ?? false) && (_firebaseTransfer ?? false);
    return base;
  }

  bool get _allChecked {
    if (_isEuUser) return _allRequiredChecked && _marketingConsent;
    return _termsOfService && _privacyPolicy && _locationTerms && _marketingConsent;
  }

  bool get _isPartiallyChecked {
    final anyChecked = _termsOfService || _privacyPolicy || _locationTerms || _marketingConsent ||
        (_gdprConsent ?? false) || (_firebaseTransfer ?? false);
    return anyChecked && !_allChecked;
  }

  @override
  void initState() {
    super.initState();
    if (_isEuUser) {
      _gdprConsent = false;
      _firebaseTransfer = false;
    }
  }

  void _toggleAll(bool? value) {
    final newValue = value ?? false;
    setState(() {
      _termsOfService = newValue;
      _privacyPolicy = newValue;
      _locationTerms = newValue;
      _marketingConsent = newValue;
      if (_isEuUser) {
        _gdprConsent = newValue;
        _firebaseTransfer = newValue;
      }
    });
  }

  Future<void> _onSubmit() async {
    if (!_allRequiredChecked || _isLoading) return;

    setState(() => _isLoading = true);
    try {
      await _repo.saveAllConsents(
        termsOfService: _termsOfService,
        privacyPolicy: _privacyPolicy,
        lbsTerms: _locationTerms,
        marketing: _marketingConsent,
        gdpr: _gdprConsent,
        firebaseTransfer: _firebaseTransfer,
      );
      if (!mounted) return;
      context.push(RoutePaths.authBirthDate, extra: {'role': widget.selectedRole});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('동의 저장에 실패했습니다.')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showTermsDetail(String title, String content) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.bottomSheetRadius)),
          ),
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.md),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(title, style: AppTypography.titleLarge),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Text(
                    content,
                    style: AppTypography.bodyMedium.copyWith(height: 1.6),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('약관 동의'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      '서비스 이용을 위한\n약관 동의가 필요합니다',
                      style: AppTypography.headlineMedium.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    _MasterCheckbox(
                      isChecked: _allChecked,
                      isIndeterminate: _isPartiallyChecked,
                      onChanged: _toggleAll,
                    ),
                    const Divider(height: AppSpacing.xl),
                    _ConsentItem(
                      label: '서비스 이용약관',
                      isRequired: true,
                      isChecked: _termsOfService,
                      onChanged: (v) => setState(() => _termsOfService = v ?? false),
                      onViewTap: () => _showTermsDetail('서비스 이용약관', AppTerms.termsOfService),
                    ),
                    _ConsentItem(
                      label: '개인정보처리방침',
                      isRequired: true,
                      isChecked: _privacyPolicy,
                      onChanged: (v) => setState(() => _privacyPolicy = v ?? false),
                      onViewTap: () => _showTermsDetail('개인정보처리방침', AppTerms.privacyPolicy),
                    ),
                    _ConsentItem(
                      label: '위치기반서비스 이용약관',
                      isRequired: true,
                      isChecked: _locationTerms,
                      onChanged: (v) => setState(() => _locationTerms = v ?? false),
                      onViewTap: () => _showTermsDetail('위치기반서비스 이용약관', AppTerms.locationTerms),
                    ),
                    _ConsentItem(
                      label: '마케팅 정보 수신 동의',
                      isRequired: false,
                      isChecked: _marketingConsent,
                      onChanged: (v) => setState(() => _marketingConsent = v ?? false),
                      onViewTap: () => _showTermsDetail('마케팅 정보 수신 동의', AppTerms.marketingConsent),
                    ),
                    if (_isEuUser) ...[
                      _ConsentItem(
                        label: 'GDPR 개인정보 처리 동의',
                        isRequired: true,
                        isChecked: _gdprConsent ?? false,
                        onChanged: (v) => setState(() => _gdprConsent = v ?? false),
                        onViewTap: () => _showTermsDetail(
                          'GDPR 개인정보 처리 동의',
                          'SafeTrip은 EU 일반개인정보보호법(GDPR)에 따라 귀하의 개인정보를 처리합니다.\n\n'
                          '처리 근거: 서비스 제공을 위한 계약 이행 및 동의\n'
                          '데이터 처리자: SafeTrip (주)유록\n'
                          '보유 기간: 서비스 이용 기간 및 관련 법령에 따른 보존 기간\n\n'
                          '귀하는 다음의 권리를 행사할 수 있습니다:\n'
                          '- 개인정보 접근권\n'
                          '- 정정권\n'
                          '- 삭제권(잊힐 권리)\n'
                          '- 처리 제한권\n'
                          '- 데이터 이동권\n'
                          '- 처리 반대권\n\n'
                          '권리 행사 및 문의: privacy@safetrip.app',
                        ),
                      ),
                      _ConsentItem(
                        label: 'Firebase 국외 이전 동의',
                        isRequired: true,
                        isChecked: _firebaseTransfer ?? false,
                        onChanged: (v) => setState(() => _firebaseTransfer = v ?? false),
                        onViewTap: () => _showTermsDetail(
                          'Firebase 국외 이전 동의',
                          'SafeTrip은 서비스 제공을 위해 Google Firebase를 이용하며, '
                          '이에 따라 귀하의 개인정보가 대한민국 및 미국 소재 서버로 이전됩니다.\n\n'
                          '이전되는 정보: 인증 정보, 실시간 위치 데이터, 푸시 알림 토큰\n'
                          '이전 목적: 사용자 인증, 실시간 데이터베이스, 푸시 알림 서비스\n'
                          '수탁자: Google LLC (미국)\n'
                          '보호 조치: Google은 EU-US Data Privacy Framework에 참여하고 있으며, '
                          '적절한 보호 조치를 시행하고 있습니다.\n\n'
                          '귀하는 이 동의를 철회할 수 있으며, 철회 시 서비스 이용이 제한될 수 있습니다.',
                        ),
                      ),
                    ],
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
                  onPressed: _allRequiredChecked && !_isLoading ? _onSubmit : null,
                  child: _isLoading
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('동의하고 시작하기'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MasterCheckbox extends StatelessWidget {
  const _MasterCheckbox({required this.isChecked, required this.isIndeterminate, required this.onChanged});
  final bool isChecked;
  final bool isIndeterminate;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!isChecked),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isChecked ? AppColors.primaryTeal.withValues(alpha: 0.05) : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(AppSpacing.radius12),
          border: Border.all(color: isChecked ? AppColors.primaryTeal : AppColors.outline),
        ),
        child: Row(
          children: [
            Checkbox(
              value: isIndeterminate ? null : isChecked,
              tristate: true,
              onChanged: onChanged,
              activeColor: AppColors.primaryTeal,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text('전체 동의', style: AppTypography.labelLarge.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class _ConsentItem extends StatelessWidget {
  const _ConsentItem({required this.label, required this.isRequired, required this.isChecked, required this.onChanged, required this.onViewTap});
  final String label;
  final bool isRequired;
  final bool isChecked;
  final ValueChanged<bool?> onChanged;
  final VoidCallback onViewTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Checkbox(
          value: isChecked,
          onChanged: onChanged,
          activeColor: AppColors.primaryTeal,
        ),
        Expanded(
          child: GestureDetector(
            onTap: () => onChanged(!isChecked),
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: isRequired ? '[필수] ' : '[선택] ',
                    style: AppTypography.bodyMedium.copyWith(
                      color: isRequired ? AppColors.primaryCoral : AppColors.textTertiary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextSpan(
                    text: label,
                    style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary),
                  ),
                ],
              ),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right, color: AppColors.textTertiary),
          onPressed: onViewTap,
        ),
      ],
    );
  }
}
