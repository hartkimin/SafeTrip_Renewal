import 'dart:async';
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
  String _privacyLevel = 'standard';

  // 위치 공유 ON/OFF
  bool _isSharing = true;

  // 공개 범위: 'all', 'admin_only', 'specified'
  String _visibilityType = 'all';

  // 멤버 역할 및 여행 정보
  String _memberRole = 'crew';
  String _tripTitle = '';
  bool _hasMinors = false; // 미성년자 포함 여부

  // 위치 공유 일시정지
  bool _isLocationPaused = false;
  DateTime? _locationPauseEnd;
  Timer? _pauseTimer;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _pauseTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      _userId = prefs.getString('user_id');
      _tripId = await AppCache.tripId;

      // 멤버 역할 로드
      final role = await AppCache.memberRole;
      _memberRole = role ?? 'crew';

      if (_tripId != null && _userId != null) {
        final apiService = ApiService();

        // 1. 여행 정보에서 프라이버시 등급, 제목, 미성년자 여부 가져오기
        final tripData = await apiService.getTripById(_tripId!);
        if (tripData != null) {
          setState(() {
            _privacyLevel = tripData['privacy_level'] ?? 'standard';
            _tripTitle = tripData['title'] ?? '';
            _hasMinors = tripData['has_minors'] ?? false;
          });
        }

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

  Future<void> _changePrivacyLevel(String newLevel) async {
    if (_tripId == null) return;
    setState(() => _isLoading = true);
    try {
      final apiService = ApiService();
      await apiService.updateTripPrivacyLevel(_tripId!, newLevel);
      setState(() => _privacyLevel = newLevel);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('프라이버시 등급이 변경되었습니다.')),
        );
      }
    } catch (e) {
      debugPrint('[PrivacyScreen] 등급 변경 에러: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('등급 변경에 실패했습니다.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ===== 위치 공유 일시정지 헬퍼 =====

  int _getMaxPauseMinutes() {
    // SS5.4 역할/등급별 시간 제한
    if (_memberRole == 'captain') return 120;
    if (_privacyLevel == 'safety_first') return 30;
    if (_privacyLevel == 'standard') return 60;
    return 120; // privacy_first
  }

  List<int> _getPauseOptions(int max) {
    final options = <int>[];
    if (max >= 15) options.add(15);
    if (max >= 30) options.add(30);
    if (max >= 60) options.add(60);
    if (max >= 120) options.add(120);
    return options;
  }

  String _formatPauseEnd(DateTime end) {
    final h = end.hour.toString().padLeft(2, '0');
    final m = end.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Future<void> _pauseLocation(int minutes) async {
    _pauseTimer?.cancel();
    setState(() {
      _isLocationPaused = true;
      _locationPauseEnd = DateTime.now().add(Duration(minutes: minutes));
    });
    _pauseTimer = Timer(Duration(minutes: minutes), () {
      if (mounted) _resumeLocationSharing();
    });
    // Update sharing state through API
    await _updatePrivacy(false, _visibilityType);
  }

  void _resumeLocationSharing() {
    _pauseTimer?.cancel();
    setState(() {
      _isLocationPaused = false;
      _locationPauseEnd = null;
    });
    _updatePrivacy(true, _visibilityType);
  }

  // ===== 프라이버시 등급 변경 다이얼로그 =====

  void _showPrivacyChangeDialog() {
    String selected = _privacyLevel;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('프라이버시 등급 변경'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildPrivacyRadio(
                selected,
                'safety_first',
                '안전 최우선',
                '긴급 시 즉시 위치 공유, 가디언 실시간 보호',
                setDialogState,
                (v) => selected = v!,
              ),
              _buildPrivacyRadio(
                selected,
                'standard',
                '표준',
                '정상 시 실시간, 정지 시 저빈도 위치 공유',
                setDialogState,
                (v) => selected = v!,
              ),
              _buildPrivacyRadio(
                selected,
                'privacy_first',
                '프라이버시 우선',
                '스케줄 외 시간 위치 비공개, 최소 정보 공유',
                setDialogState,
                (v) => selected = v!,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.semanticWarning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber,
                      color: AppColors.semanticWarning,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '등급 변경은 모든 멤버에게 적용됩니다. 변경 사항은 즉시 반영됩니다.',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.semanticWarning,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: selected == _privacyLevel
                  ? null
                  : () {
                      Navigator.pop(ctx);
                      _changePrivacyLevel(selected);
                    },
              child: const Text('변경'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivacyRadio(
    String groupValue,
    String value,
    String label,
    String desc,
    void Function(void Function()) setDialogState,
    void Function(String?) onChanged,
  ) {
    return RadioListTile<String>(
      value: value,
      groupValue: groupValue,
      onChanged: (v) {
        onChanged(v);
        setDialogState(() {});
      },
      title: Text(
        label,
        style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(desc, style: AppTypography.bodySmall),
      activeColor: AppColors.primaryTeal,
      contentPadding: EdgeInsets.zero,
      dense: true,
    );
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

                const SizedBox(height: AppSpacing.sm),
                _buildSectionHeader('위치 공유 일시정지'),
                _buildLocationPauseCard(),

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
                Text(
                  _tripTitle.isNotEmpty ? _tripTitle : '-',
                  style: AppTypography.titleMedium,
                ),
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
              if (_memberRole == 'captain') ...[
                if (_hasMinors)
                  Tooltip(
                    message: '미성년자 포함 여행은 프라이버시 등급을 변경할 수 없습니다.',
                    child: TextButton(
                      onPressed: null,
                      child: Text(
                        '변경',
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ),
                  )
                else
                  TextButton(
                    onPressed: _showPrivacyChangeDialog,
                    child: Text(
                      '변경',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.primaryTeal,
                      ),
                    ),
                  ),
              ],
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
    final isSafetyFirst = _privacyLevel == 'safety_first';

    return Container(
      color: AppColors.surface,
      child: Column(
        children: [
          _buildVisibilityOption(
            '전체 공개',
            'all',
            Icons.groups_outlined,
            disabled: isSafetyFirst,
          ),
          const Divider(height: 1, indent: 56),
          _buildVisibilityOption(
            '캡틴/크루장에게만',
            'admin_only',
            Icons.admin_panel_settings_outlined,
            disabled: isSafetyFirst,
          ),
          const Divider(height: 1, indent: 56),
          _buildVisibilityOption(
            '지정된 멤버만',
            'specified',
            Icons.person_add_alt_1_outlined,
            disabled: isSafetyFirst,
          ),
          if (isSafetyFirst)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: Text(
                '안전 최우선 등급에서는 공개 범위를 변경할 수 없습니다.',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVisibilityOption(
    String title,
    String value,
    IconData icon, {
    bool disabled = false,
  }) {
    final isSelected = _visibilityType == value;
    return ListTile(
      leading: Icon(
        icon,
        color: disabled
            ? AppColors.textTertiary
            : isSelected
                ? AppColors.primaryTeal
                : AppColors.textSecondary,
      ),
      title: Text(
        title,
        style: AppTypography.bodyLarge.copyWith(
          color: disabled
              ? AppColors.textTertiary
              : isSelected
                  ? AppColors.primaryTeal
                  : AppColors.textPrimary,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: isSelected
          ? Icon(
              Icons.check,
              color: disabled ? AppColors.textTertiary : AppColors.primaryTeal,
            )
          : null,
      onTap: disabled ? null : () => _updatePrivacy(_isSharing, value),
    );
  }

  Widget _buildLocationPauseCard() {
    final maxPauseMinutes = _getMaxPauseMinutes();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.pause_circle_outline,
                color: _isLocationPaused
                    ? AppColors.semanticWarning
                    : AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  _isLocationPaused ? '위치 공유 일시정지 중' : '위치 공유 일시정지',
                  style: AppTypography.titleMedium.copyWith(
                    color: _isLocationPaused ? AppColors.semanticWarning : null,
                  ),
                ),
              ),
              if (_isLocationPaused)
                TextButton(
                  onPressed: _resumeLocationSharing,
                  child: const Text('재개'),
                ),
            ],
          ),
          if (_isLocationPaused && _locationPauseEnd != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              '재개 예정: ${_formatPauseEnd(_locationPauseEnd!)}',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.semanticWarning,
              ),
            ),
          ],
          if (!_isLocationPaused) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              '최대 $maxPauseMinutes분간 위치 공유를 일시정지할 수 있습니다.',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              children: _getPauseOptions(maxPauseMinutes).map((minutes) {
                return ActionChip(
                  label: Text('${minutes}분'),
                  onPressed: () => _pauseLocation(minutes),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}
