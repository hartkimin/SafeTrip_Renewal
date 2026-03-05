import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../router/route_paths.dart';
import '../../utils/app_cache.dart';
import '../../widgets/avatar_widget.dart';
import '../../services/location_service.dart';
import '../../services/api_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isLoading = true;

  // User info
  String _userName = '';
  String _userId = '';
  String? _profileImageUrl;
  String? _phoneNumber;

  // Trip info (Layer 2)
  String? _tripId;
  String? _tripTitle;
  String? _tripStartDate;
  String? _tripEndDate;
  bool get _hasActiveTrip => _tripId != null && _tripId!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      // 1. Load user info from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      _userId = prefs.getString('user_id') ?? '';
      _userName = prefs.getString('user_name') ?? '사용자';
      _profileImageUrl = prefs.getString('profile_image_url');
      _phoneNumber = prefs.getString('phone_number');

      // 2. Load trip/role info from AppCache
      _tripId = await AppCache.tripId;

      // 3. If active trip exists, fetch trip details from API
      if (_hasActiveTrip) {
        final tripData = await ApiService().getTripById(_tripId!);
        if (tripData != null) {
          _tripTitle = tripData['title'] as String?;
          _tripStartDate = tripData['start_date'] as String?;
          _tripEndDate = tripData['end_date'] as String?;
        }
      }
    } catch (e) {
      debugPrint('[SettingsScreen] _loadData Error: $e');
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceVariant,
      appBar: AppBar(
        title: const Text('설정'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                // ── Profile Card ──────────────────────────────────
                _buildProfileCard(),

                // ── Layer 1: App Settings ─────────────────────────
                _buildSectionHeader('앱 설정'),
                _buildMenuTile(
                  icon: Icons.phonelink_setup_outlined,
                  title: '기기 권한',
                  onTap: () => context.push(RoutePaths.devicePermissions),
                ),
                _buildMenuTile(
                  icon: Icons.notifications_none_outlined,
                  title: '전역 알림 설정',
                  onTap: () => context.push(RoutePaths.notificationSettings),
                ),
                _buildMenuTile(
                  icon: Icons.privacy_tip_outlined,
                  title: '개인정보 관리',
                  onTap: () => context.push(RoutePaths.privacyManagement),
                ),
                _buildMenuTile(
                  icon: Icons.logout_outlined,
                  title: '로그아웃',
                  onTap: _onLogout,
                ),
                _buildMenuTile(
                  icon: Icons.person_off_outlined,
                  title: '계정 삭제',
                  titleColor: AppColors.sosDanger,
                  onTap: () => context.push(RoutePaths.accountDelete),
                ),

                // ── Layer 2: Trip Settings (active trip only) ─────
                if (_hasActiveTrip) ...[
                  _buildTripSectionHeader(),
                  _buildMenuTile(
                    icon: Icons.info_outline,
                    title: '여행 정보',
                    onTap: () {}, // P2: 여행 상세 화면으로 이동
                  ),
                  _buildMenuTile(
                    icon: Icons.location_on_outlined,
                    title: '프라이버시 및 위치 공유',
                    onTap: () => context.push(RoutePaths.privacySettings),
                  ),
                  _buildMenuTile(
                    icon: Icons.shield_outlined,
                    title: '가디언 관리',
                    onTap: () => context.push(RoutePaths.guardianManagement),
                  ),
                ],

                // ── App Version ───────────────────────────────────
                const SizedBox(height: 40),
                Center(
                  child: Text(
                    '앱 버전 v1.1.0',
                    style: AppTypography.bodySmall
                        .copyWith(color: AppColors.textTertiary),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // Profile Card
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildProfileCard() {
    return InkWell(
      onTap: () => context.push(RoutePaths.profileEdit),
      child: Container(
        color: AppColors.surface,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            AvatarWidget(
              userId: _userId,
              userName: _userName,
              profileImageUrl: _profileImageUrl,
              radius: 30,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_userName, style: AppTypography.titleLarge),
                  if (_phoneNumber != null && _phoneNumber!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        _phoneNumber!,
                        style: AppTypography.bodySmall
                            .copyWith(color: AppColors.textTertiary),
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    '프로필 수정하기',
                    style: AppTypography.bodySmall
                        .copyWith(color: AppColors.primaryTeal),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 20, color: AppColors.outline),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // Section Headers
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

  Widget _buildTripSectionHeader() {
    final dateRange = (_tripStartDate != null && _tripEndDate != null)
        ? '$_tripStartDate ~ $_tripEndDate'
        : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '여행 설정',
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.textTertiary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                Icons.flight_takeoff,
                size: 16,
                color: AppColors.primaryTeal,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _tripTitle ?? '여행',
                  style: AppTypography.labelMedium.copyWith(
                    color: AppColors.primaryTeal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (dateRange != null)
            Padding(
              padding: const EdgeInsets.only(top: 2, left: 22),
              child: Text(
                dateRange,
                style: AppTypography.bodySmall
                    .copyWith(color: AppColors.textTertiary),
              ),
            ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // Menu Tile
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildMenuTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? titleColor,
  }) {
    return Container(
      color: AppColors.surface,
      child: ListTile(
        leading: Icon(icon, color: titleColor ?? AppColors.textSecondary),
        title: Text(
          title,
          style: AppTypography.bodyLarge.copyWith(color: titleColor),
        ),
        trailing:
            const Icon(Icons.chevron_right, size: 20, color: AppColors.outline),
        onTap: onTap,
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // Logout
  // ═══════════════════════════════════════════════════════════════════

  Future<void> _onLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text('로그아웃하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.sosDanger),
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      setState(() => _isLoading = true);
      try {
        // FCM 토큰 무효화
        final fcmToken = await FirebaseMessaging.instance.getToken();
        if (fcmToken != null) {
          final apiService = ApiService();
          await apiService.invalidateFCMToken(fcmToken);
        }
      } catch (e) {
        debugPrint('[Settings] FCM 토큰 무효화 실패: $e');
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      AppCache.clear();
      await LocationService().stopTracking();
      if (mounted) context.go(RoutePaths.splash);
    }
  }
}
