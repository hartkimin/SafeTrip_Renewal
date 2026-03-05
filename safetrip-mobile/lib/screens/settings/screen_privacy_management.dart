import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../router/route_paths.dart';
import '../../services/api_service.dart';

/// 개인정보 관리 화면 (설정 메뉴 원칙 8)
///
/// Section 1: 약관/동의 현황 (8.1) — 필수 약관 3개 + 마케팅 토글
/// Section 2: 내 정보 (8.2) — 열람 요청, 데이터 삭제 요청
class ScreenPrivacyManagement extends StatefulWidget {
  const ScreenPrivacyManagement({super.key});

  @override
  State<ScreenPrivacyManagement> createState() =>
      _ScreenPrivacyManagementState();
}

class _ScreenPrivacyManagementState extends State<ScreenPrivacyManagement> {
  final ApiService _apiService = ApiService();

  bool _isLoading = true;
  List<Map<String, dynamic>> _consentHistory = [];
  bool _marketingEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadConsentHistory();
  }

  Future<void> _loadConsentHistory() async {
    setState(() => _isLoading = true);

    try {
      final history = await _apiService.getConsentHistory();
      _consentHistory = history;

      // Find marketing consent from the list
      final marketingConsent = _consentHistory.firstWhere(
        (c) =>
            (c['consent_type'] as String?)?.toLowerCase() == 'marketing' ||
            (c['consentType'] as String?)?.toLowerCase() == 'marketing',
        orElse: () => <String, dynamic>{},
      );
      if (marketingConsent.isNotEmpty) {
        _marketingEnabled =
            marketingConsent['is_granted'] == true ||
            marketingConsent['isGranted'] == true;
      }
    } catch (e) {
      debugPrint('[ScreenPrivacyManagement] _loadConsentHistory Error: $e');
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // Helper: consent date lookup
  // ═══════════════════════════════════════════════════════════════════

  /// Extract formatted date from consent list by type.
  /// Parses ISO 8601 and returns "YYYY.MM.DD".
  String? _findConsentDate(String type) {
    final record = _consentHistory.firstWhere(
      (c) {
        final consentType =
            (c['consent_type'] as String? ?? c['consentType'] as String? ?? '')
                .toLowerCase();
        return consentType == type.toLowerCase();
      },
      orElse: () => <String, dynamic>{},
    );

    if (record.isEmpty) return null;

    final dateStr =
        record['consented_at'] as String? ??
        record['consentedAt'] as String? ??
        record['created_at'] as String? ??
        record['createdAt'] as String?;

    if (dateStr == null) return null;

    try {
      final date = DateTime.parse(dateStr);
      return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // Marketing toggle handler
  // ═══════════════════════════════════════════════════════════════════

  Future<void> _onMarketingToggle(bool value) async {
    setState(() => _marketingEnabled = value);

    final success = await _apiService.saveConsentRecord(
      consentType: 'marketing',
      consentVersion: '1.0',
      isGranted: value,
    );

    if (!success && mounted) {
      // Revert on failure
      setState(() => _marketingEnabled = !value);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('마케팅 동의 변경에 실패했습니다.')),
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // Data view request
  // ═══════════════════════════════════════════════════════════════════

  Future<void> _onDataViewRequest() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('내 정보 열람 요청'),
        content: const Text(
          '등록된 이메일로 48시간 내에 개인정보 열람 자료가 발송됩니다.\n\n'
          '요청 후 7일 내 재요청은 차단됩니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.primaryTeal),
            child: const Text('요청'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('열람 요청이 접수되었습니다.')),
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // Build
  // ═══════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceVariant,
      appBar: AppBar(
        title: const Text('개인정보 관리'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                // ── Section 1: 약관·동의 현황 (8.1) ─────────────────
                _buildSectionHeader('약관·동의 현황'),

                _buildConsentItem(
                  title: '서비스이용약관',
                  consentType: 'terms_of_service',
                ),
                const Divider(height: 1),
                _buildConsentItem(
                  title: '개인정보처리방침',
                  consentType: 'privacy_policy',
                ),
                const Divider(height: 1),
                _buildConsentItem(
                  title: '위치기반서비스 이용약관',
                  consentType: 'location_terms',
                ),
                const Divider(height: 1),

                // Marketing toggle
                _buildMarketingToggle(),

                // ── Section 2: 내 정보 (8.2) ────────────────────────
                _buildSectionHeader('내 정보'),

                _buildActionTile(
                  title: '내 정보 열람 요청',
                  onTap: _onDataViewRequest,
                ),
                const Divider(height: 1),
                _buildActionTile(
                  title: '데이터 삭제 요청',
                  titleColor: AppColors.sosDanger,
                  onTap: () => context.push(RoutePaths.accountDelete),
                ),

                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // Section Header
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Text(
        title,
        style: AppTypography.labelSmall.copyWith(
          color: AppColors.textTertiary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // Consent Item (required)
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildConsentItem({
    required String title,
    required String consentType,
  }) {
    final consentDate = _findConsentDate(consentType);

    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(title, style: AppTypography.bodyLarge),
                    const SizedBox(width: AppSpacing.sm),
                    _buildRequiredBadge(),
                  ],
                ),
                if (consentDate != null)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: Text(
                      '동의일: $consentDate',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // Required Badge
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildRequiredBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.primaryTeal.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radius4),
      ),
      child: Text(
        '필수',
        style: AppTypography.labelSmall.copyWith(
          color: AppColors.primaryTeal,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // Marketing Toggle
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildMarketingToggle() {
    return Container(
      color: AppColors.surface,
      child: SwitchListTile(
        title: Text('마케팅 정보 수신', style: AppTypography.bodyLarge),
        value: _marketingEnabled,
        onChanged: _onMarketingToggle,
        activeColor: AppColors.primaryTeal,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // Action Tile
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildActionTile({
    required String title,
    required VoidCallback onTap,
    Color? titleColor,
  }) {
    return Container(
      color: AppColors.surface,
      child: ListTile(
        title: Text(
          title,
          style: AppTypography.bodyLarge.copyWith(color: titleColor),
        ),
        trailing: const Icon(
          Icons.chevron_right,
          size: 20,
          color: AppColors.outline,
        ),
        onTap: onTap,
      ),
    );
  }
}
