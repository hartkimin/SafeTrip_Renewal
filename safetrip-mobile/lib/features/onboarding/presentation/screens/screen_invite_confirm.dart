import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../router/route_paths.dart';
import '../../data/onboarding_repository.dart';

class ScreenInviteConfirm extends StatefulWidget {
  const ScreenInviteConfirm({super.key, required this.inviteCode});
  final String inviteCode;

  @override
  State<ScreenInviteConfirm> createState() => _ScreenInviteConfirmState();
}

class _ScreenInviteConfirmState extends State<ScreenInviteConfirm> {
  final _repo = OnboardingRepository();
  bool _isLoading = true;
  bool _isJoining = false;
  Map<String, dynamic>? _inviteInfo;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadInviteInfo();
  }

  Future<void> _loadInviteInfo() async {
    try {
      final info = await _repo.previewInviteCode(widget.inviteCode);
      if (mounted) {
        setState(() {
          _inviteInfo = info;
          _isLoading = false;
          if (info == null) _error = '초대코드가 만료되었거나 유효하지 않습니다.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = '초대코드 확인 중 오류가 발생했습니다.';
        });
      }
    }
  }

  Future<void> _onAccept() async {
    setState(() => _isJoining = true);
    try {
      final result = await _repo.acceptInvite(widget.inviteCode);
      if (result != null && mounted) {
        final prefs = await SharedPreferences.getInstance();
        final groupId = result['group_id']?.toString() ?? '';
        if (groupId.isNotEmpty) {
          await prefs.setString('group_id', groupId);
        }
        await prefs.remove('pending_invite_code');
        if (mounted) context.go(RoutePaths.main);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('참여에 실패했습니다.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isJoining = false);
    }
  }

  void _onReject() {
    context.go(RoutePaths.onboardingPurpose);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('여행 초대 확인')),
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
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: [
                const SizedBox(height: AppSpacing.xxl),
                const Icon(Icons.flight_takeoff, size: 64,
                    color: AppColors.primaryTeal),
                const SizedBox(height: AppSpacing.xl),
                Text('여행에 초대되었습니다!',
                    style: AppTypography.titleLarge
                        .copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: AppSpacing.xxl),
                _infoRow('여행명', info['trip_title'] ?? info['title'] ?? ''),
                _infoRow('캡틴', info['captain_name'] ?? info['created_by'] ?? ''),
                _infoRow('역할', _roleLabel(info['target_role'] ?? info['role'] ?? 'crew')),
                if (info['start_date'] != null)
                  _infoRow('기간', '${info['start_date']} ~ ${info['end_date'] ?? ''}'),
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
                  onPressed: _isJoining ? null : _onReject,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(AppSpacing.buttonHeight),
                  ),
                  child: const Text('거절'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isJoining ? null : _onAccept,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(AppSpacing.buttonHeight),
                  ),
                  child: _isJoining
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('참여 확인'),
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
          SizedBox(
            width: 80,
            child: Text(label,
                style: AppTypography.bodyMedium
                    .copyWith(color: AppColors.textTertiary)),
          ),
          Expanded(
            child: Text(value,
                style: AppTypography.bodyLarge
                    .copyWith(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'captain': return '캡틴 (여행장)';
      case 'crew_chief': return '크루장';
      case 'crew': return '크루';
      default: return role;
    }
  }
}
