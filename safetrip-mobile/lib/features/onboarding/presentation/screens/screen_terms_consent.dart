import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../constants/app_terms.dart';
import '../../../../router/route_paths.dart';
import '../../../../services/api_service.dart';

/// A-07 Terms Consent Screen
class ScreenTermsConsent extends StatefulWidget {
  const ScreenTermsConsent({super.key, required this.selectedRole});
  final String selectedRole;

  @override
  State<ScreenTermsConsent> createState() => _ScreenTermsConsentState();
}

class _ScreenTermsConsentState extends State<ScreenTermsConsent> {
  final ApiService _apiService = ApiService();
  bool _isLoading = false;

  bool _termsOfService = false;
  bool _privacyPolicy = false;
  bool _locationTerms = false;
  bool _ageConsent = false;
  bool _marketingConsent = false;

  bool get _allRequiredChecked =>
      _termsOfService && _privacyPolicy && _locationTerms && _ageConsent;

  bool get _allChecked => _allRequiredChecked && _marketingConsent;

  bool get _isPartiallyChecked =>
      (_termsOfService || _privacyPolicy || _locationTerms || _ageConsent || _marketingConsent) &&
      !_allChecked;

  void _toggleAll(bool? value) {
    final newValue = value ?? false;
    setState(() {
      _termsOfService = newValue;
      _privacyPolicy = newValue;
      _locationTerms = newValue;
      _ageConsent = newValue;
      _marketingConsent = newValue;
    });
  }

  Future<void> _onSubmit() async {
    if (!_allRequiredChecked || _isLoading) return;

    setState(() => _isLoading = true);
    try {
      await _apiService.saveConsent(
        role: widget.selectedRole,
        termsOfService: _termsOfService,
        privacyPolicy: _privacyPolicy,
        locationTerms: _locationTerms,
        marketingConsent: _marketingConsent,
      );
      if (!mounted) return;
      context.push(RoutePaths.authPhone, extra: {'role': widget.selectedRole});
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
                      label: '개인정보 처리방침',
                      isRequired: true,
                      isChecked: _privacyPolicy,
                      onChanged: (v) => setState(() => _privacyPolicy = v ?? false),
                      onViewTap: () => _showTermsDetail('개인정보 처리방침', AppTerms.privacyPolicy),
                    ),
                    _ConsentItem(
                      label: '위치정보 이용약관',
                      isRequired: true,
                      isChecked: _locationTerms,
                      onChanged: (v) => setState(() => _locationTerms = v ?? false),
                      onViewTap: () => _showTermsDetail('위치정보 이용약관', AppTerms.locationTerms),
                    ),
                    _ConsentItem(
                      label: '만 14세 이상 이용 동의',
                      isRequired: true,
                      isChecked: _ageConsent,
                      onChanged: (v) => setState(() => _ageConsent = v ?? false),
                      onViewTap: () => _showTermsDetail('만 14세 이상 이용 동의', AppTerms.ageConsent),
                    ),
                    _ConsentItem(
                      label: '마케팅 수신 동의',
                      isRequired: false,
                      isChecked: _marketingConsent,
                      onChanged: (v) => setState(() => _marketingConsent = v ?? false),
                      onViewTap: () => _showTermsDetail('마케팅 수신 동의', AppTerms.marketingConsent),
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
