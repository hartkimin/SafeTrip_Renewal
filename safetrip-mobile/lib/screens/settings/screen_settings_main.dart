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
  bool _isLoading = false;
  String _userName = '';
  String _userId = '';
  String? _profileImageUrl;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName = prefs.getString('user_name') ?? '사용자';
      _userId = prefs.getString('user_id') ?? '';
      _profileImageUrl = prefs.getString('profile_image_url');
    });
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
          _buildProfileCard(),
          const SizedBox(height: AppSpacing.lg),

          _buildSectionHeader('위치 및 안전'),
          _buildMenuTile(
            icon: Icons.location_on_outlined,
            title: '위치 공유 설정',
            onTap: () => context.push(RoutePaths.privacySettings),
          ),
          _buildMenuTile(
            icon: Icons.shield_outlined,
            title: '가디언 관리',
            onTap: () => context.push(RoutePaths.guardianManagement),
          ),
          _buildMenuTile(
            icon: Icons.battery_saver_outlined,
            title: '배터리 최적화 안내',
            onTap: () {},
          ),

          const SizedBox(height: AppSpacing.sm),
          _buildSectionHeader('알림'),
          _buildMenuTile(
            icon: Icons.notifications_none_outlined,
            title: '알림 설정',
            onTap: () {},
          ),

          const SizedBox(height: AppSpacing.sm),
          _buildSectionHeader('계정'),
          _buildMenuTile(
            icon: Icons.logout_outlined,
            title: '로그아웃',
            onTap: _onLogout,
          ),
          _buildMenuTile(
            icon: Icons.person_off_outlined,
            title: '계정 탈퇴',
            titleColor: AppColors.sosDanger,
            onTap: () {},
          ),

          const SizedBox(height: 40),
          Center(
            child: Text(
              '앱 버전 v1.1.0',
              style: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildProfileCard() {
    return Container(
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
                Text('프로필 수정하기', style: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.outline),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
      child: Text(
        title,
        style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary, fontWeight: FontWeight.bold),
      ),
    );
  }

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
        title: Text(title, style: AppTypography.bodyLarge.copyWith(color: titleColor)),
        trailing: const Icon(Icons.chevron_right, size: 20, color: AppColors.outline),
        onTap: onTap,
      ),
    );
  }

  Future<void> _onLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text('로그아웃하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
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
