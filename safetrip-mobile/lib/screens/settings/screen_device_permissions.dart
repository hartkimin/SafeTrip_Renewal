import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// 설정 > 기기 권한 화면
/// 위치·알림·카메라 권한 상태를 확인하고 요청/설정 이동을 제공한다.
class ScreenDevicePermissions extends StatefulWidget {
  const ScreenDevicePermissions({super.key});

  @override
  State<ScreenDevicePermissions> createState() =>
      _ScreenDevicePermissionsState();
}

class _ScreenDevicePermissionsState extends State<ScreenDevicePermissions>
    with WidgetsBindingObserver {
  PermissionStatus _locationStatus = PermissionStatus.denied;
  PermissionStatus _notificationStatus = PermissionStatus.denied;
  PermissionStatus _cameraStatus = PermissionStatus.denied;

  /// locationAlways가 granted이면 true, 아니면 whenInUse fallback 결과를 사용.
  bool _isLocationAlways = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAllPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAllPermissions();
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Permission Checking
  // ═══════════════════════════════════════════════════════════════════════

  Future<void> _checkAllPermissions() async {
    final locationAlways = await Permission.locationAlways.status;
    final locationWhenInUse = await Permission.locationWhenInUse.status;
    final notification = await Permission.notification.status;
    final camera = await Permission.camera.status;

    if (!mounted) return;

    setState(() {
      _isLocationAlways = locationAlways.isGranted;
      _locationStatus =
          locationAlways.isGranted ? locationAlways : locationWhenInUse;
      _notificationStatus = notification;
      _cameraStatus = camera;
    });
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Permission Requesting
  // ═══════════════════════════════════════════════════════════════════════

  Future<void> _requestLocationPermission() async {
    // Try locationAlways first
    var status = await Permission.locationAlways.status;

    if (status.isPermanentlyDenied) {
      await openAppSettings();
      return;
    }

    if (!status.isGranted) {
      // Must request whenInUse first before requesting always
      final whenInUse = await Permission.locationWhenInUse.request();
      if (whenInUse.isGranted) {
        status = await Permission.locationAlways.request();
      } else if (whenInUse.isPermanentlyDenied) {
        await openAppSettings();
        return;
      } else {
        status = whenInUse;
      }
    }

    await _checkAllPermissions();
  }

  Future<void> _requestNotificationPermission() async {
    final status = await Permission.notification.status;

    if (status.isPermanentlyDenied) {
      await openAppSettings();
      return;
    }

    await Permission.notification.request();
    await _checkAllPermissions();
  }

  Future<void> _requestCameraPermission() async {
    final status = await Permission.camera.status;

    if (status.isPermanentlyDenied) {
      await openAppSettings();
      return;
    }

    await Permission.camera.request();
    await _checkAllPermissions();
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Build
  // ═══════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final isLocationGranted = _locationStatus.isGranted;

    return Scaffold(
      backgroundColor: AppColors.surfaceVariant,
      appBar: AppBar(
        title: const Text('기기 권한'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        children: [
          // ── Warning Banner (위치 미허용 시) ──────────────────────
          if (!isLocationGranted) _buildWarningBanner(),

          const SizedBox(height: AppSpacing.sm),

          // ── Permission Tiles ─────────────────────────────────────
          Container(
            color: AppColors.surface,
            child: Column(
              children: [
                _buildPermissionTile(
                  icon: Icons.location_on_outlined,
                  title: '위치 권한',
                  subtitle: _locationSubtitle,
                  status: _locationStatus,
                  onTap: _requestLocationPermission,
                ),
                const Divider(height: 1, indent: AppSpacing.lg + 40),
                _buildPermissionTile(
                  icon: Icons.notifications_outlined,
                  title: '알림 권한',
                  subtitle: '푸시 알림 수신',
                  status: _notificationStatus,
                  onTap: _requestNotificationPermission,
                ),
                const Divider(height: 1, indent: AppSpacing.lg + 40),
                _buildPermissionTile(
                  icon: Icons.camera_alt_outlined,
                  title: '카메라 권한',
                  subtitle: '프로필 사진 촬영',
                  status: _cameraStatus,
                  onTap: _requestCameraPermission,
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // ── Help Text ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenPaddingH,
            ),
            child: Text(
              '권한이 거부된 경우, 기기 설정에서 직접 변경할 수 있습니다.',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textTertiary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Location Subtitle
  // ═══════════════════════════════════════════════════════════════════════

  String get _locationSubtitle {
    if (_isLocationAlways) {
      return '항상 허용';
    }
    if (_locationStatus.isGranted) {
      return '앱 사용 중에만 허용';
    }
    if (_locationStatus.isDenied || _locationStatus.isPermanentlyDenied) {
      return '위치 권한이 꺼져 있습니다';
    }
    return '위치 권한 확인 필요';
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Warning Banner
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildWarningBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenPaddingH,
        vertical: AppSpacing.md,
      ),
      color: AppColors.semanticWarning.withValues(alpha: 0.1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: AppColors.semanticWarning,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              '위치 권한이 필요합니다. 설정에서 \'항상 허용\'으로 변경해 주세요.',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textWarning,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Permission Tile
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildPermissionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required PermissionStatus status,
    required VoidCallback onTap,
  }) {
    final isGranted = status.isGranted;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      leading: Icon(icon, color: AppColors.textSecondary, size: 24),
      title: Text(title, style: AppTypography.bodyLarge),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          subtitle,
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textTertiary,
          ),
        ),
      ),
      trailing: _buildStatusBadge(isGranted),
      onTap: onTap,
    );
  }

  Widget _buildStatusBadge(bool isGranted) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: isGranted
            ? AppColors.semanticSuccess.withValues(alpha: 0.1)
            : AppColors.semanticWarning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radius12),
      ),
      child: Text(
        isGranted ? '허용됨' : '거부됨',
        style: AppTypography.labelSmall.copyWith(
          color: isGranted
              ? AppColors.semanticSuccess
              : AppColors.semanticWarning,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
