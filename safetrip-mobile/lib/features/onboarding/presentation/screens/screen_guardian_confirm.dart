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
        await prefs.remove('pending_guardian_code');
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
