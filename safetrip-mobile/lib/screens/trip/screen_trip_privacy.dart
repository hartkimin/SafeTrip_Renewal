import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../services/api_service.dart';
import '../../utils/app_cache.dart';

class ScreenTripPrivacy extends StatefulWidget {
  const ScreenTripPrivacy({super.key});

  @override
  State<ScreenTripPrivacy> createState() => _ScreenTripPrivacyState();
}

class _ScreenTripPrivacyState extends State<ScreenTripPrivacy> {
  bool _isLoading = true;
  String? _tripId;
  String? _userId;

  // 프라이버시 등급: 'safety_first', 'standard', 'privacy_first'
  final String _privacyLevel = 'standard';

  // 위치 공유 ON/OFF
  bool _isSharing = true;

  // 공개 범위: 'all', 'admin_only', 'specified'
  String _visibilityType = 'all';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      _userId = prefs.getString('user_id');
      _tripId = await AppCache.tripId;

      if (_tripId != null && _userId != null) {
        final apiService = ApiService();
        // 1. 여행 정보에서 프라이버시 등급 가져오기 (실제로는 tripId로 조회 필요)
        // TODO: getTripById 메서드 구현 후 연동
        await apiService.getUserById(_userId!);

        // 2. 현재 공유 설정 가져오기
        final settings = await apiService.getSharingSettings(
          _tripId!,
          _userId!,
        );
        if (settings != null && settings.isNotEmpty) {
          final s = settings.first;
          setState(() {
            _isSharing = s['is_sharing'] ?? true;
            _visibilityType = s['visibility_type'] ?? 'all';
          });
        }
      }
    } catch (e) {
      debugPrint('[PrivacyScreen] 로드 에러: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updatePrivacy(bool isSharing, String visibility) async {
    if (_tripId == null || _userId == null) return;

    setState(() => _isLoading = true);
    try {
      final apiService = ApiService();
      await apiService.updateSharing(_tripId!, _userId!, isSharing, visibility);
      setState(() {
        _isSharing = isSharing;
        _visibilityType = visibility;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('프라이버시 설정이 저장되었습니다.')));
      }
    } catch (e) {
      debugPrint('[PrivacyScreen] 저장 에러: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceVariant,
      appBar: AppBar(
        title: const Text('프라이버시 설정'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                _buildCurrentTripInfo(),
                const SizedBox(height: AppSpacing.md),

                _buildSectionHeader('여행 프라이버시 등급'),
                _buildPrivacyLevelCard(),

                const SizedBox(height: AppSpacing.sm),
                _buildSectionHeader('내 위치 공유'),
                _buildSharingToggle(),

                if (_isSharing) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _buildSectionHeader('공개 범위'),
                  _buildVisibilitySelector(),
                ],

                const SizedBox(height: AppSpacing.xl),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  child: Text(
                    '※ 안전 최우선 등급은 긴급 상황 시 모든 설정을 무시하고 위치가 공유될 수 있습니다.',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
              ],
            ),
    );
  }

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

  Widget _buildCurrentTripInfo() {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          const Icon(Icons.flight_takeoff, color: AppColors.primaryTeal),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '현재 참여 중인 여행',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
                const Text(
                  '파리 에펠탑 투어',
                  style: AppTypography.titleMedium,
                ), // 실제 데이터 연동 필요
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyLevelCard() {
    Color levelColor;
    String levelName;
    String levelDesc;
    IconData levelIcon;

    switch (_privacyLevel) {
      case 'safety_first':
        levelColor = AppColors.privacySafetyFirst;
        levelName = '안전 최우선';
        levelDesc = '긴급 상황 발생 시 즉시 위치가 공유되며, 가디언이 실시간으로 보호합니다.';
        levelIcon = Icons.shield;
        break;
      case 'privacy_first':
        levelColor = AppColors.privacyFirst;
        levelName = '프라이버시 우선';
        levelDesc = '스케줄 외 시간에는 위치가 비공개되며, 최소한의 정보만 공유합니다.';
        levelIcon = Icons.lock;
        break;
      case 'standard':
      default:
        levelColor = AppColors.privacyStandard;
        levelName = '표준';
        levelDesc = '정상 시에는 실시간 위치를, 정지 시에는 저빈도로 위치를 공유합니다.';
        levelIcon = Icons.location_on;
        break;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: levelColor.withValues(alpha: 0.3), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(levelIcon, color: levelColor),
              const SizedBox(width: AppSpacing.sm),
              Text(
                levelName,
                style: AppTypography.titleMedium.copyWith(color: levelColor),
              ),
              const Spacer(),
              // TODO: 캡틴 역할일 때만 변경 버튼 표시
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(levelDesc, style: AppTypography.bodySmall),
        ],
      ),
    );
  }

  Widget _buildSharingToggle() {
    return Container(
      color: AppColors.surface,
      child: SwitchListTile(
        title: const Text('실시간 위치 공유'),
        subtitle: Text(
          _isSharing ? '다른 멤버들이 내 위치를 볼 수 있습니다.' : '내 위치가 다른 멤버들에게 숨겨집니다.',
        ),
        value: _isSharing,
        activeThumbColor: AppColors.primaryTeal,
        onChanged: (val) => _updatePrivacy(val, _visibilityType),
      ),
    );
  }

  Widget _buildVisibilitySelector() {
    return Container(
      color: AppColors.surface,
      child: Column(
        children: [
          _buildVisibilityOption('전체 공개', 'all', Icons.groups_outlined),
          const Divider(height: 1, indent: 56),
          _buildVisibilityOption(
            '캡틴/크루장에게만',
            'admin_only',
            Icons.admin_panel_settings_outlined,
          ),
          const Divider(height: 1, indent: 56),
          _buildVisibilityOption(
            '지정된 멤버만',
            'specified',
            Icons.person_add_alt_1_outlined,
          ),
        ],
      ),
    );
  }

  Widget _buildVisibilityOption(String title, String value, IconData icon) {
    final isSelected = _visibilityType == value;
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? AppColors.primaryTeal : AppColors.textSecondary,
      ),
      title: Text(
        title,
        style: AppTypography.bodyLarge.copyWith(
          color: isSelected ? AppColors.primaryTeal : AppColors.textPrimary,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: isSelected
          ? const Icon(Icons.check, color: AppColors.primaryTeal)
          : null,
      onTap: () => _updatePrivacy(_isSharing, value),
    );
  }
}
