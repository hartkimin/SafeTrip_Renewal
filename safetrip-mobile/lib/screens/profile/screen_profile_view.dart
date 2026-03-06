import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/constants/avatar_constants.dart';
import '../../widgets/guardian_badge.dart';
import '../../services/api_service.dart';

/// 타인 프로필 조회 화면 (DOC-T3-PRF-027 §3.2)
///
/// 역할별 필터링된 정보를 서버에서 받아 표시한다.
/// 캡틴: 긴급연락처, 위치, 배정조 포함
/// 크루: 기본 정보 + 여행 상태
/// 비연결 가디언: 닉네임 + 사진만
class ScreenProfileView extends StatefulWidget {
  final String userId;
  final String? tripId;

  const ScreenProfileView({
    super.key,
    required this.userId,
    this.tripId,
  });

  @override
  State<ScreenProfileView> createState() => _ScreenProfileViewState();
}

class _ScreenProfileViewState extends State<ScreenProfileView> {
  bool _isLoading = true;
  Map<String, dynamic>? _profile;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await ApiService().getFilteredUserProfile(
        widget.userId,
        tripId: widget.tripId,
      );
      if (mounted) {
        setState(() {
          _profile = response;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '프로필을 불러올 수 없습니다';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceVariant,
      appBar: AppBar(
        title: const Text('프로필'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline,
                          size: 48, color: AppColors.textTertiary),
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: AppTypography.bodyMedium
                            .copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                )
              : _buildProfile(),
    );
  }

  Widget _buildProfile() {
    final profile = _profile!;
    final isDeleted = profile['is_deleted'] == true;
    final displayName = profile['display_name'] ?? '알 수 없음';
    final avatarId = profile['avatar_id'] as String?;
    final avatar = AvatarConstants.getById(avatarId);
    final memberRole = profile['member_role'] as String?;
    final travelStatus = profile['travel_status'] as String?;
    final emergencyContacts = profile['emergency_contacts'] as List?;
    final hasLocation = profile['last_location'] == true;
    final assignedGroup = profile['assigned_group'] as String?;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.lg),

          // ── Avatar + Name ──
          Center(
            child: Column(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: avatar != null
                          ? Color(avatar.color).withValues(alpha: 0.2)
                          : AppColors.outline,
                      child: avatar != null
                          ? Text(avatar.icon,
                              style: const TextStyle(fontSize: 40))
                          : Icon(
                              isDeleted ? Icons.person_off : Icons.person,
                              size: 40,
                              color: AppColors.textTertiary,
                            ),
                    ),
                    // Guardian badge icon on avatar
                    if (memberRole == 'guardian')
                      const Positioned(
                        bottom: 0,
                        right: 0,
                        child: GuardianBadge.icon(isPaid: false),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  displayName,
                  style: AppTypography.titleLarge,
                ),
                if (memberRole != null) ...[
                  const SizedBox(height: 4),
                  _buildRoleBadge(memberRole),
                ],
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // ── Travel Status ──
          if (travelStatus != null)
            _buildInfoTile(
              icon: Icons.flight_takeoff,
              label: '여행 상태',
              value: travelStatus,
            ),

          // ── Location ──
          if (hasLocation)
            _buildInfoTile(
              icon: Icons.location_on,
              label: '위치 공유',
              value: '위치 확인 가능',
            ),

          // ── Assigned Group ──
          if (assignedGroup != null)
            _buildInfoTile(
              icon: Icons.group,
              label: '배정 조',
              value: assignedGroup,
            ),

          // ── Emergency Contacts (Captain only) ──
          if (emergencyContacts != null && emergencyContacts.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenPaddingH,
                vertical: AppSpacing.xs,
              ),
              child: Text(
                '긴급 연락처',
                style: AppTypography.labelSmall
                    .copyWith(color: AppColors.textTertiary),
              ),
            ),
            ...emergencyContacts.map(
              (contact) => Container(
                color: AppColors.surface,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenPaddingH,
                  vertical: AppSpacing.inputPaddingV,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(contact['contact_name'] ?? '',
                              style: AppTypography.bodyLarge),
                          Text(
                            contact['phone_number'] ?? '',
                            style: AppTypography.bodySmall
                                .copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.phone,
                          size: 20, color: AppColors.primaryTeal),
                      onPressed: () {
                        // TODO: launch phone call
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],

          // ── Deleted User Notice ──
          if (isDeleted)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.screenPaddingH),
              child: Text(
                '탈퇴한 사용자입니다',
                style: AppTypography.bodyMedium
                    .copyWith(color: AppColors.textTertiary),
                textAlign: TextAlign.center,
              ),
            ),

          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

  Widget _buildRoleBadge(String role) {
    final label = switch (role) {
      'captain' => '캡틴',
      'crew_chief' => '크루장',
      'crew' => '크루',
      'guardian' => '가디언',
      _ => role,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: AppTypography.labelSmall
            .copyWith(color: AppColors.textSecondary),
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenPaddingH,
        vertical: AppSpacing.inputPaddingV,
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.textTertiary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: AppTypography.labelSmall
                        .copyWith(color: AppColors.textTertiary)),
                Text(value, style: AppTypography.bodyLarge),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
