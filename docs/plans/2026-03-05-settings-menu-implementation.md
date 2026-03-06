# Settings Menu Implementation Plan (P0 + P1)

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement the settings menu per `Master_docs/15_T3_설정_메뉴_원칙.md` — 3-layer settings hub with P0 (MVP) and P1 (런칭 직전) features.

**Architecture:** Restructure the existing `screen_settings_main.dart` into a Settings Hub with Layer 1 (앱 전역) always visible and Layer 2 (여행별) conditionally shown. Add 5 new sub-screens under `lib/screens/settings/`. Enhance 2 existing screens (privacy, guardian). Layer 3 (역할별 권한) is applied within each screen via `AppCache.memberRole`.

**Tech Stack:** Flutter/Dart, go_router, SharedPreferences, AppCache, ApiService (Dio), FirebaseAuth, permission_handler, app_settings

---

## Task 1: Add API Methods to ApiService

**Files:**
- Modify: `safetrip-mobile/lib/services/api_service.dart`

**Step 1: Add 4 new API methods at the bottom of `ApiService` class**

Add after line ~1131 (before the closing `}`):

```dart
  // ===== Settings: Trip Detail =====

  /// GET /api/v1/trips/:tripId — 여행 상세 조회
  Future<Map<String, dynamic>?> getTripById(String tripId) async {
    try {
      final response = await _dio.get('/api/v1/trips/$tripId');
      if (response.data['success'] == true) {
        return response.data['data'] as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      debugPrint('[ApiService] getTripById Error: $e');
      return null;
    }
  }

  // ===== Settings: My Guardians =====

  /// GET /api/v1/trips/:tripId/guardians/me — 내 가디언 목록 조회
  Future<List<Map<String, dynamic>>> getMyGuardians(String tripId) async {
    try {
      final response = await _dio.get('/api/v1/trips/$tripId/guardians/me');
      if (response.data['success'] == true && response.data['data'] != null) {
        return List<Map<String, dynamic>>.from(response.data['data']);
      }
      return [];
    } catch (e) {
      debugPrint('[ApiService] getMyGuardians Error: $e');
      return [];
    }
  }

  /// DELETE /api/v1/trips/:tripId/guardians/:linkId — 가디언 연결 해제
  Future<bool> removeGuardianLink(String tripId, String linkId) async {
    try {
      final response = await _dio.delete('/api/v1/trips/$tripId/guardians/$linkId');
      return response.data['success'] == true;
    } catch (e) {
      debugPrint('[ApiService] removeGuardianLink Error: $e');
      return false;
    }
  }

  /// POST /api/v1/trips/:tripId/guardians — 가디언 초대
  Future<Map<String, dynamic>?> addGuardian(String tripId, String guardianPhone) async {
    try {
      final response = await _dio.post(
        '/api/v1/trips/$tripId/guardians',
        data: {'guardian_phone': guardianPhone},
      );
      if (response.data['success'] == true) {
        return response.data['data'] as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      debugPrint('[ApiService] addGuardian Error: $e');
      return null;
    }
  }

  // ===== Settings: Account Deletion =====

  /// PATCH /api/v1/users/me — 계정 삭제 요청 (deletion_requested_at 설정)
  Future<bool> requestAccountDeletion() async {
    try {
      final response = await _dio.patch('/api/v1/users/me', data: {
        'deletionRequestedAt': DateTime.now().toIso8601String(),
      });
      return response.data['success'] == true;
    } catch (e) {
      debugPrint('[ApiService] requestAccountDeletion Error: $e');
      return false;
    }
  }

  /// PATCH /api/v1/users/me — 계정 삭제 철회 (deletion_requested_at null)
  Future<bool> cancelAccountDeletion() async {
    try {
      final response = await _dio.patch('/api/v1/users/me', data: {
        'deletionRequestedAt': null,
      });
      return response.data['success'] == true;
    } catch (e) {
      debugPrint('[ApiService] cancelAccountDeletion Error: $e');
      return false;
    }
  }

  // ===== Settings: Consent =====

  /// GET /api/v1/auth/consent — 동의 현황 조회
  Future<List<Map<String, dynamic>>> getConsentHistory() async {
    try {
      final response = await _dio.get('/api/v1/auth/consent');
      if (response.data['success'] == true && response.data['data'] != null) {
        return List<Map<String, dynamic>>.from(response.data['data']);
      }
      return [];
    } catch (e) {
      debugPrint('[ApiService] getConsentHistory Error: $e');
      return [];
    }
  }
```

**Step 2: Verify build compiles**

Run: `cd safetrip-mobile && flutter analyze lib/services/api_service.dart`
Expected: No errors

**Step 3: Commit**

```
feat(settings): add API methods for trip detail, guardians, account deletion, consent
```

---

## Task 2: Add Routes for New Settings Screens

**Files:**
- Modify: `safetrip-mobile/lib/router/route_paths.dart`
- Modify: `safetrip-mobile/lib/router/app_router.dart`

**Step 1: Add route paths**

In `route_paths.dart`, add under the `// Settings` section (after line 32):

```dart
  static const profileEdit = '/settings/profile';
  static const devicePermissions = '/settings/permissions';
  static const notificationSettings = '/settings/notifications';
  static const privacyManagement = '/settings/privacy-management';
  static const accountDelete = '/settings/account-delete';
```

**Step 2: Add route registrations in app_router.dart**

Import the new screens at the top and add GoRoute entries. These screens will be created in subsequent tasks, so use `PlaceholderScreen` initially:

```dart
GoRoute(
  path: RoutePaths.profileEdit,
  builder: (context, state) => const PlaceholderScreen(title: '프로필 편집'),
),
GoRoute(
  path: RoutePaths.devicePermissions,
  builder: (context, state) => const PlaceholderScreen(title: '기기 권한'),
),
GoRoute(
  path: RoutePaths.notificationSettings,
  builder: (context, state) => const PlaceholderScreen(title: '알림 설정'),
),
GoRoute(
  path: RoutePaths.privacyManagement,
  builder: (context, state) => const PlaceholderScreen(title: '개인정보 관리'),
),
GoRoute(
  path: RoutePaths.accountDelete,
  builder: (context, state) => const PlaceholderScreen(title: '계정 삭제'),
),
```

**Step 3: Commit**

```
feat(settings): add route paths for 5 new settings sub-screens
```

---

## Task 3: Restructure Settings Hub (screen_settings_main.dart)

**Files:**
- Modify: `safetrip-mobile/lib/screens/settings/screen_settings_main.dart`

**Step 1: Full rewrite of `screen_settings_main.dart`**

Replace the entire file content with the Settings Hub that:
1. Shows profile card with navigation to profile edit
2. Shows Layer 1 (앱 전역 설정) always
3. Shows Layer 2 (여행별 설정) only when `AppCache.tripId` is set
4. Loads user role from `AppCache.memberRole` for Layer 3 access control
5. Shows trip info (name, dates) in Layer 2 header

```dart
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
  String _userName = '';
  String _userId = '';
  String? _profileImageUrl;
  String? _phoneNumber;

  // Layer 2: 여행 정보
  String? _tripId;
  String? _tripTitle;
  String? _tripStartDate;
  String? _tripEndDate;
  String? _memberRole; // captain | crew_chief | crew | guardian

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      _userName = prefs.getString('user_name') ?? '사용자';
      _userId = prefs.getString('user_id') ?? '';
      _profileImageUrl = prefs.getString('profile_image_url');
      _phoneNumber = prefs.getString('phone_number');
      _tripId = await AppCache.tripId;
      _memberRole = await AppCache.memberRole;

      // Load trip details if trip active
      if (_tripId != null && _tripId!.isNotEmpty) {
        final apiService = ApiService();
        final trip = await apiService.getTripById(_tripId!);
        if (trip != null) {
          _tripTitle = trip['title'] as String?;
          _tripStartDate = trip['start_date'] as String?;
          _tripEndDate = trip['end_date'] as String?;
        }
      }
    } catch (e) {
      debugPrint('[Settings] 로드 에러: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool get _hasActiveTrip => _tripId != null && _tripId!.isNotEmpty;
  bool get _isCaptain => _memberRole == 'captain';

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
                // ── 프로필 카드 ──
                _buildProfileCard(),

                // ── Layer 1: 앱 전역 설정 ──
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

                // ── Layer 2: 여행별 설정 (여행 참여 시만) ──
                if (_hasActiveTrip) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _buildTripSectionHeader(),
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

                // ── 앱 버전 ──
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
                  if (_phoneNumber != null)
                    Text(
                      _phoneNumber!,
                      style: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary),
                    ),
                  Text(
                    '프로필 수정하기',
                    style: AppTypography.bodySmall.copyWith(color: AppColors.primaryTeal),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.outline),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
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
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
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
          if (_tripTitle != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                const Icon(Icons.flight_takeoff, size: 16, color: AppColors.primaryTeal),
                const SizedBox(width: AppSpacing.xs),
                Text(_tripTitle!, style: AppTypography.titleMedium),
              ],
            ),
          ],
          if (_tripStartDate != null && _tripEndDate != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              '$_tripStartDate ~ $_tripEndDate',
              style: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary),
            ),
          ],
        ],
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
```

**Step 2: Verify build**

Run: `cd safetrip-mobile && flutter analyze lib/screens/settings/screen_settings_main.dart`

**Step 3: Commit**

```
feat(settings): restructure settings hub with Layer 1/Layer 2 structure (§3.2)
```

---

## Task 4: Create Profile Edit Screen

**Files:**
- Create: `safetrip-mobile/lib/screens/settings/screen_profile_edit.dart`
- Modify: `safetrip-mobile/lib/router/app_router.dart` (replace PlaceholderScreen)

**Step 1: Create `screen_profile_edit.dart`**

Implements spec §4.1:
- 프로필 사진 변경 (image_picker)
- 표시 이름 편집
- 전화번호 확인 (변경 불가, 읽기 전용)
- 언어 설정 (시스템 따름 / 수동 선택) — defer to P2, show read-only for now

```dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../services/api_service.dart';
import '../../utils/app_cache.dart';
import '../../widgets/avatar_widget.dart';

class ScreenProfileEdit extends StatefulWidget {
  const ScreenProfileEdit({super.key});

  @override
  State<ScreenProfileEdit> createState() => _ScreenProfileEditState();
}

class _ScreenProfileEditState extends State<ScreenProfileEdit> {
  final _nameController = TextEditingController();
  final _imagePicker = ImagePicker();
  final _apiService = ApiService();

  bool _isLoading = true;
  bool _isSaving = false;
  String _userId = '';
  String? _phoneNumber;
  String? _profileImageUrl;
  File? _selectedImage;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      _userId = prefs.getString('user_id') ?? '';
      _phoneNumber = prefs.getString('phone_number');
      _profileImageUrl = prefs.getString('profile_image_url');

      final user = await _apiService.getUserById(_userId);
      if (user != null) {
        _nameController.text = user['display_name'] ?? '';
        _phoneNumber = user['phone_number'] ?? _phoneNumber;
        _profileImageUrl = user['profile_image_url'];
      } else {
        _nameController.text = prefs.getString('user_name') ?? '';
      }
    } catch (e) {
      debugPrint('[ProfileEdit] 로드 에러: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
    );
    if (picked != null && mounted) {
      setState(() => _selectedImage = File(picked.path));
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이름을 입력해주세요.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _apiService.updateUserProfile(_userId, name);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_name', name);
      await AppCache.setUserInfo(userName: name);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('프로필이 저장되었습니다.')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('저장에 실패했습니다. 다시 시도해주세요.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceVariant,
      appBar: AppBar(
        title: const Text('프로필 편집'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('저장'),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                const SizedBox(height: AppSpacing.xl),
                // 프로필 사진
                Center(
                  child: GestureDetector(
                    onTap: _pickImage,
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: AppColors.surfaceVariant,
                          backgroundImage: _selectedImage != null
                              ? FileImage(_selectedImage!)
                              : (_profileImageUrl != null
                                  ? NetworkImage(_profileImageUrl!) as ImageProvider
                                  : null),
                          child: _selectedImage == null && _profileImageUrl == null
                              ? Text(
                                  _nameController.text.isNotEmpty ? _nameController.text[0] : '?',
                                  style: AppTypography.titleLarge,
                                )
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: AppColors.primaryTeal,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),

                // 표시 이름
                Container(
                  color: AppColors.surface,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('표시 이름', style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary)),
                      const SizedBox(height: AppSpacing.sm),
                      TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          hintText: '이름을 입력하세요',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),

                // 전화번호 (읽기 전용)
                Container(
                  color: AppColors.surface,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('전화번호', style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary)),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          const Icon(Icons.phone, size: 18, color: AppColors.textSecondary),
                          const SizedBox(width: AppSpacing.sm),
                          Text(_phoneNumber ?? '-', style: AppTypography.bodyLarge),
                          const Spacer(),
                          Text('변경 불가', style: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),

                // 언어 설정
                Container(
                  color: AppColors.surface,
                  child: ListTile(
                    leading: const Icon(Icons.language, color: AppColors.textSecondary),
                    title: const Text('언어 설정'),
                    subtitle: const Text('시스템 설정 따름'),
                    trailing: const Icon(Icons.chevron_right, size: 20, color: AppColors.outline),
                    onTap: () {}, // P2: 언어 선택 화면
                  ),
                ),
              ],
            ),
    );
  }
}
```

**Step 2: Update `app_router.dart` to use the real screen**

Replace the PlaceholderScreen for profileEdit:
```dart
import '../screens/settings/screen_profile_edit.dart';
// ...
GoRoute(
  path: RoutePaths.profileEdit,
  builder: (context, state) => const ScreenProfileEdit(),
),
```

**Step 3: Commit**

```
feat(settings): add profile edit screen (§4.1)
```

---

## Task 5: Create Device Permissions Screen

**Files:**
- Create: `safetrip-mobile/lib/screens/settings/screen_device_permissions.dart`
- Modify: `safetrip-mobile/lib/router/app_router.dart`

**Step 1: Create `screen_device_permissions.dart`**

Implements spec §4.1 and §4.2:
- 위치 권한: 항상 허용 / 앱 사용 중만 / 거부
- 알림 권한: 시스템 설정으로 이동
- 카메라 권한 (프로필 사진용)
- 권한 현황 배지 표시 (미허용 시 경고)

Uses `permission_handler` package (already in pubspec) and `app_settings` for OS settings navigation.

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

class ScreenDevicePermissions extends StatefulWidget {
  const ScreenDevicePermissions({super.key});

  @override
  State<ScreenDevicePermissions> createState() => _ScreenDevicePermissionsState();
}

class _ScreenDevicePermissionsState extends State<ScreenDevicePermissions> with WidgetsBindingObserver {
  bool _isLoading = true;
  PermissionStatus _locationStatus = PermissionStatus.denied;
  PermissionStatus _notificationStatus = PermissionStatus.denied;
  PermissionStatus _cameraStatus = PermissionStatus.denied;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissions(); // Re-check when returning from settings
    }
  }

  Future<void> _checkPermissions() async {
    setState(() => _isLoading = true);
    _locationStatus = await Permission.locationAlways.status;
    if (_locationStatus == PermissionStatus.denied) {
      _locationStatus = await Permission.locationWhenInUse.status;
    }
    _notificationStatus = await Permission.notification.status;
    _cameraStatus = await Permission.camera.status;
    if (mounted) setState(() => _isLoading = false);
  }

  String _statusLabel(PermissionStatus status) {
    switch (status) {
      case PermissionStatus.granted:
      case PermissionStatus.limited:
        return '허용됨';
      case PermissionStatus.denied:
        return '거부됨';
      case PermissionStatus.permanentlyDenied:
        return '영구 거부됨';
      case PermissionStatus.restricted:
        return '제한됨';
      case PermissionStatus.provisional:
        return '임시 허용';
    }
  }

  Color _statusColor(PermissionStatus status) {
    if (status == PermissionStatus.granted || status == PermissionStatus.limited) {
      return AppColors.semanticSuccess;
    }
    return AppColors.semanticWarning;
  }

  Future<void> _requestPermission(Permission permission) async {
    final status = await permission.request();
    if (status == PermissionStatus.permanentlyDenied) {
      await openAppSettings();
    }
    _checkPermissions();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceVariant,
      appBar: AppBar(
        title: const Text('기기 권한'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                const SizedBox(height: AppSpacing.sm),
                // §4.2 위치 권한 배너
                if (_locationStatus != PermissionStatus.granted) ...[
                  Container(
                    color: AppColors.semanticWarning.withValues(alpha: 0.1),
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber, color: AppColors.semanticWarning),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            '위치 권한이 필요합니다. 설정에서 \'항상 허용\'으로 변경해 주세요.',
                            style: AppTypography.bodySmall.copyWith(color: AppColors.semanticWarning),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                _buildPermissionTile(
                  icon: Icons.location_on_outlined,
                  title: '위치 권한',
                  subtitle: _locationStatus == PermissionStatus.granted
                      ? '항상 허용 — 전체 기능 정상 동작'
                      : '위치 관련 기능이 제한됩니다',
                  status: _locationStatus,
                  onTap: () => _requestPermission(Permission.locationAlways),
                ),
                const Divider(height: 1),
                _buildPermissionTile(
                  icon: Icons.notifications_outlined,
                  title: '알림 권한',
                  subtitle: '푸시 알림 수신',
                  status: _notificationStatus,
                  onTap: () => _requestPermission(Permission.notification),
                ),
                const Divider(height: 1),
                _buildPermissionTile(
                  icon: Icons.camera_alt_outlined,
                  title: '카메라 권한',
                  subtitle: '프로필 사진 촬영',
                  status: _cameraStatus,
                  onTap: () => _requestPermission(Permission.camera),
                ),

                const SizedBox(height: AppSpacing.xl),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: Text(
                    '권한이 거부된 경우, 기기 설정에서 직접 변경할 수 있습니다.',
                    style: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildPermissionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required PermissionStatus status,
    required VoidCallback onTap,
  }) {
    return Container(
      color: AppColors.surface,
      child: ListTile(
        leading: Icon(icon, color: AppColors.textSecondary),
        title: Text(title, style: AppTypography.bodyLarge),
        subtitle: Text(subtitle, style: AppTypography.bodySmall),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _statusColor(status).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _statusLabel(status),
                style: AppTypography.bodySmall.copyWith(color: _statusColor(status)),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 20, color: AppColors.outline),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}
```

**Step 2: Update `app_router.dart`**

**Step 3: Commit**

```
feat(settings): add device permissions screen (§4.1, §4.2)
```

---

## Task 6: Create Notification Settings Screen

**Files:**
- Create: `safetrip-mobile/lib/screens/settings/screen_notification_settings.dart`
- Modify: `safetrip-mobile/lib/router/app_router.dart`

**Step 1: Create `screen_notification_settings.dart`**

Implements spec §4.1 전역 알림:
- SOS 알림: 항상 ON (비활성화 불가)
- 가디언 알림: ON/OFF
- 채팅 알림: ON/OFF
- 일정 알림: ON/OFF
- 마케팅 알림: ON/OFF

Uses `SharedPreferences` for local toggle state.

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

class ScreenNotificationSettings extends StatefulWidget {
  const ScreenNotificationSettings({super.key});

  @override
  State<ScreenNotificationSettings> createState() => _ScreenNotificationSettingsState();
}

class _ScreenNotificationSettingsState extends State<ScreenNotificationSettings> {
  bool _guardianNotif = true;
  bool _chatNotif = true;
  bool _scheduleNotif = true;
  bool _marketingNotif = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _guardianNotif = prefs.getBool('notif_guardian') ?? true;
      _chatNotif = prefs.getBool('notif_chat') ?? true;
      _scheduleNotif = prefs.getBool('notif_schedule') ?? true;
      _marketingNotif = prefs.getBool('notif_marketing') ?? false;
    });
  }

  Future<void> _saveToggle(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceVariant,
      appBar: AppBar(
        title: const Text('전역 알림 설정'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        children: [
          const SizedBox(height: AppSpacing.sm),
          // SOS 알림 — 항상 ON, 비활성화 불가
          _buildNotifTile(
            title: 'SOS 알림',
            subtitle: '긴급 상황 알림은 항상 활성화됩니다',
            value: true,
            enabled: false,
            onChanged: null,
          ),
          const Divider(height: 1),
          _buildNotifTile(
            title: '가디언 알림',
            subtitle: '가디언 연결 요청 및 상태 변경',
            value: _guardianNotif,
            onChanged: (v) {
              setState(() => _guardianNotif = v);
              _saveToggle('notif_guardian', v);
            },
          ),
          const Divider(height: 1),
          _buildNotifTile(
            title: '채팅 알림',
            subtitle: '새 메시지 수신',
            value: _chatNotif,
            onChanged: (v) {
              setState(() => _chatNotif = v);
              _saveToggle('notif_chat', v);
            },
          ),
          const Divider(height: 1),
          _buildNotifTile(
            title: '일정 알림',
            subtitle: '일정 시작 전 리마인더',
            value: _scheduleNotif,
            onChanged: (v) {
              setState(() => _scheduleNotif = v);
              _saveToggle('notif_schedule', v);
            },
          ),
          const Divider(height: 1),
          _buildNotifTile(
            title: '마케팅 알림',
            subtitle: '이벤트 및 혜택 안내',
            value: _marketingNotif,
            onChanged: (v) {
              setState(() => _marketingNotif = v);
              _saveToggle('notif_marketing', v);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNotifTile({
    required String title,
    required String subtitle,
    required bool value,
    bool enabled = true,
    required ValueChanged<bool>? onChanged,
  }) {
    return Container(
      color: AppColors.surface,
      child: SwitchListTile(
        title: Text(
          title,
          style: AppTypography.bodyLarge.copyWith(
            color: enabled ? null : AppColors.textTertiary,
          ),
        ),
        subtitle: Text(subtitle, style: AppTypography.bodySmall),
        value: value,
        activeColor: AppColors.primaryTeal,
        onChanged: enabled ? onChanged : null,
      ),
    );
  }
}
```

**Step 2: Update `app_router.dart`**

**Step 3: Commit**

```
feat(settings): add notification settings screen with SOS always-on (§4.1)
```

---

## Task 7: Create Privacy Management Screen

**Files:**
- Create: `safetrip-mobile/lib/screens/settings/screen_privacy_management.dart`
- Modify: `safetrip-mobile/lib/router/app_router.dart`

**Step 1: Create `screen_privacy_management.dart`**

Implements spec §8:
- 약관·동의 현황 조회 (§8.1)
- 내 정보 열람 요청 (§8.2) — 48시간 이메일 발송 안내
- 마케팅 동의 변경 (§8.3) — 토글 즉시 반영

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../services/api_service.dart';

class ScreenPrivacyManagement extends StatefulWidget {
  const ScreenPrivacyManagement({super.key});

  @override
  State<ScreenPrivacyManagement> createState() => _ScreenPrivacyManagementState();
}

class _ScreenPrivacyManagementState extends State<ScreenPrivacyManagement> {
  final _apiService = ApiService();
  bool _isLoading = true;
  bool _marketingConsent = false;
  List<Map<String, dynamic>> _consents = [];

  @override
  void initState() {
    super.initState();
    _loadConsents();
  }

  Future<void> _loadConsents() async {
    setState(() => _isLoading = true);
    try {
      _consents = await _apiService.getConsentHistory();
      // Find marketing consent
      final marketing = _consents.where(
        (c) => c['consent_type'] == 'marketing',
      );
      if (marketing.isNotEmpty) {
        _marketingConsent = marketing.last['is_granted'] == true;
      }
    } catch (e) {
      debugPrint('[PrivacyManagement] 로드 에러: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleMarketing(bool value) async {
    setState(() => _marketingConsent = value);
    try {
      await _apiService.saveConsentRecord(
        consentType: 'marketing',
        consentVersion: '1.0',
        isGranted: value,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('변경에 실패했습니다.')),
        );
        setState(() => _marketingConsent = !value);
      }
    }
  }

  Future<void> _requestDataExport() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('내 정보 열람 요청'),
        content: const Text(
          '등록된 이메일로 48시간 내에 개인정보 열람 자료가 발송됩니다.\n\n요청 후 7일 내 재요청은 차단됩니다.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('요청'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('열람 요청이 접수되었습니다. 48시간 내 이메일로 발송됩니다.')),
      );
    }
  }

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
                // §8.1 약관·동의 현황
                _buildSectionHeader('약관·동의 현황'),
                _buildConsentItem('서비스이용약관', '필수', _findConsentDate('terms_of_service')),
                const Divider(height: 1),
                _buildConsentItem('개인정보처리방침', '필수', _findConsentDate('privacy_policy')),
                const Divider(height: 1),
                _buildConsentItem('위치기반서비스 이용약관', '필수', _findConsentDate('location_terms')),
                const Divider(height: 1),

                // §8.3 마케팅 동의
                Container(
                  color: AppColors.surface,
                  child: SwitchListTile(
                    title: const Text('마케팅 정보 수신'),
                    subtitle: Text(
                      _marketingConsent ? '동의함' : '거부함',
                      style: AppTypography.bodySmall,
                    ),
                    value: _marketingConsent,
                    activeColor: AppColors.primaryTeal,
                    onChanged: _toggleMarketing,
                  ),
                ),

                const SizedBox(height: AppSpacing.sm),

                // §8.2 내 정보 열람 요청
                _buildSectionHeader('내 정보'),
                Container(
                  color: AppColors.surface,
                  child: ListTile(
                    leading: const Icon(Icons.download_outlined, color: AppColors.textSecondary),
                    title: const Text('내 정보 열람 요청'),
                    subtitle: const Text('48시간 내 이메일로 발송'),
                    trailing: const Icon(Icons.chevron_right, size: 20, color: AppColors.outline),
                    onTap: _requestDataExport,
                  ),
                ),
                const Divider(height: 1),
                Container(
                  color: AppColors.surface,
                  child: ListTile(
                    leading: const Icon(Icons.delete_outline, color: AppColors.sosDanger),
                    title: Text('데이터 삭제 요청', style: TextStyle(color: AppColors.sosDanger)),
                    subtitle: const Text('계정 삭제 흐름으로 연결됩니다'),
                    trailing: const Icon(Icons.chevron_right, size: 20, color: AppColors.outline),
                    onTap: () => context.push('/settings/account-delete'),
                  ),
                ),
              ],
            ),
    );
  }

  String? _findConsentDate(String type) {
    final match = _consents.where((c) => c['consent_type'] == type);
    if (match.isNotEmpty) {
      final date = match.last['created_at'] ?? match.last['consented_at'];
      if (date != null) {
        final dt = DateTime.tryParse(date.toString());
        if (dt != null) return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';
      }
    }
    return null;
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

  Widget _buildConsentItem(String title, String badge, String? date) {
    return Container(
      color: AppColors.surface,
      child: ListTile(
        title: Row(
          children: [
            Text(title, style: AppTypography.bodyLarge),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primaryTeal.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(badge, style: AppTypography.bodySmall.copyWith(color: AppColors.primaryTeal)),
            ),
          ],
        ),
        subtitle: date != null ? Text('동의일: $date') : null,
      ),
    );
  }
}
```

**Step 2: Update `app_router.dart`**

**Step 3: Commit**

```
feat(settings): add privacy management screen — consent history, data export, marketing toggle (§8)
```

---

## Task 8: Create Account Deletion Screen

**Files:**
- Create: `safetrip-mobile/lib/screens/settings/screen_account_delete.dart`
- Modify: `safetrip-mobile/lib/router/app_router.dart`

**Step 1: Create `screen_account_delete.dart`**

Implements spec §7:
- Step 1: 확인 화면 (즉시삭제/익명화/영구보관 안내)
- Step 2: active 여행 참여 시 탈퇴 안내
- Step 3: 삭제 요청 API 호출
- Step 4: 완료 안내 (7일 유예)

OTP 재인증은 FirebaseAuth 재인증으로 대체 (이미 phone auth 기반).

```dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../router/route_paths.dart';
import '../../services/api_service.dart';
import '../../services/location_service.dart';
import '../../utils/app_cache.dart';

class ScreenAccountDelete extends StatefulWidget {
  const ScreenAccountDelete({super.key});

  @override
  State<ScreenAccountDelete> createState() => _ScreenAccountDeleteState();
}

class _ScreenAccountDeleteState extends State<ScreenAccountDelete> {
  final _apiService = ApiService();
  bool _isLoading = false;
  bool _hasActiveTrip = false;
  String? _tripTitle;

  @override
  void initState() {
    super.initState();
    _checkActiveTrip();
  }

  Future<void> _checkActiveTrip() async {
    final tripId = await AppCache.tripId;
    if (tripId != null && tripId.isNotEmpty) {
      final trip = await _apiService.getTripById(tripId);
      setState(() {
        _hasActiveTrip = true;
        _tripTitle = trip?['title'];
      });
    }
  }

  Future<void> _requestDeletion() async {
    // Step 1: Confirm dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('정말 계정을 삭제하시겠습니까?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_hasActiveTrip) ...[
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.semanticWarning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber, color: AppColors.semanticWarning, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '참여 중인 여행 "$_tripTitle"에서 탈퇴됩니다.',
                        style: AppTypography.bodySmall.copyWith(color: AppColors.semanticWarning),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            const Text('삭제 후 처리:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _buildBullet('즉시 삭제: 프로필, 이미지, 긴급 연락처'),
            _buildBullet('익명화 보관: 위치 데이터, 이벤트 로그'),
            _buildBullet('영구 보관: SOS 기록 (법적 의무)'),
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.primaryTeal.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '7일 유예 기간 내에 로그인하면 삭제를 철회할 수 있습니다.',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.sosDanger),
            child: const Text('계정 삭제 요청'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Step 2: Call API
    setState(() => _isLoading = true);
    try {
      final success = await _apiService.requestAccountDeletion();
      if (success && mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('계정 삭제 요청 완료'),
            content: const Text('7일 후 계정이 삭제됩니다.\n로그인 시 삭제를 철회할 수 있습니다.'),
            actions: [
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  // Logout
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.clear();
                  AppCache.clear();
                  await LocationService().stopTracking();
                  await FirebaseAuth.instance.signOut();
                  if (mounted) context.go(RoutePaths.splash);
                },
                child: const Text('확인'),
              ),
            ],
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('요청에 실패했습니다. 다시 시도해주세요.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('오류가 발생했습니다.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontSize: 14)),
          Expanded(child: Text(text, style: AppTypography.bodySmall)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceVariant,
      appBar: AppBar(
        title: const Text('계정 삭제'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 48, color: AppColors.sosDanger),
                  const SizedBox(height: AppSpacing.md),
                  const Text('계정을 삭제하면', style: AppTypography.titleLarge),
                  const SizedBox(height: AppSpacing.md),
                  _buildInfoCard(Icons.delete_forever, '즉시 삭제', '프로필 정보, 이미지, 긴급 연락처'),
                  const SizedBox(height: AppSpacing.sm),
                  _buildInfoCard(Icons.visibility_off, '익명화 보관', '위치 데이터, 이벤트 로그 (통계용)'),
                  const SizedBox(height: AppSpacing.sm),
                  _buildInfoCard(Icons.gavel, '영구 보관', 'SOS 기록 (법적 의무 보관)'),
                  const SizedBox(height: AppSpacing.xl),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.primaryTeal.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primaryTeal.withValues(alpha: 0.2)),
                    ),
                    child: const Text(
                      '삭제 요청 후 7일 이내에 로그인하면\n삭제를 철회할 수 있습니다.',
                      style: TextStyle(fontWeight: FontWeight.w500),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    height: AppSpacing.buttonHeight,
                    child: ElevatedButton(
                      onPressed: _requestDeletion,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.sosDanger,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('계정 삭제 요청'),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoCard(IconData icon, String title, String description) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.labelMedium),
                Text(description, style: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

**Step 2: Update `app_router.dart`**

**Step 3: Commit**

```
feat(settings): add account deletion screen with 7-day grace period (§7, §14.4)
```

---

## Task 9: Enhance Privacy Screen (screen_trip_privacy.dart)

**Files:**
- Modify: `safetrip-mobile/lib/screens/trip/screen_trip_privacy.dart`

**Step 1: Full rewrite with role-based controls**

Key changes:
- Load actual trip data (privacy level, member count, has_minors)
- Captain-only privacy level change button (§9.2)
- Privacy level change confirmation dialog with cascading effects (§5.3)
- Minors present → disable privacy change (§5.3)
- Location pause feature with role/level limits (§5.4)
- Safety-first → disable visibility scope (§10)

The file should be completely rewritten. Main additions:
1. `_memberRole` loaded from AppCache
2. `_privacyLevel` loaded from trip API response
3. `_buildPrivacyChangeButton()` — only for captains, disabled if minors present
4. `_showPrivacyChangeDialog()` — confirmation with cascading effects per §5.3
5. `_buildLocationPause()` — timer-based pause per §5.4
6. Visibility scope disabled when `_privacyLevel == 'safety_first'`

Due to the length, the full replacement is in the code above pattern. Key logic:

```dart
// Privacy level change dialog (§5.3)
Widget _buildPrivacyChangeButton() {
  if (_memberRole != 'captain') return const SizedBox.shrink();
  // Show button, disabled if has_minors
}

// Location pause (§5.4)
Widget _buildLocationPause() {
  if (_privacyLevel == 'safety_first') return const SizedBox.shrink(); // Not allowed
  if (_memberRole == 'guardian') return const SizedBox.shrink(); // N/A
  // Show pause toggle with time limits
}
```

**Step 2: Commit**

```
feat(settings): enhance privacy screen with role-based controls, privacy change dialog, location pause (§5.3, §5.4, §9.2)
```

---

## Task 10: Enhance Guardian Management Screen

**Files:**
- Modify: `safetrip-mobile/lib/screens/trip/screen_guardian_management.dart`

**Step 1: Replace mock data with real API calls**

Key changes:
1. Replace mock `_guardians` list with `apiService.getMyGuardians(tripId)`
2. `_showAddGuardianDialog()` → call `apiService.addGuardian(tripId, phone)`
3. Guardian removal → call `apiService.removeGuardianLink(tripId, linkId)` with confirmation
4. Fix paywall modal price: "1,900원/여행" (not "월 1,900원")
5. Add paid guardian removal confirmation: "해제 후 환불되지 않습니다" (§11)
6. Add max limit message (§11)

**Step 2: Commit**

```
feat(settings): connect guardian management to real API, fix paywall price, add removal confirmation (§6.3, §11)
```

---

## Task 11: Wire All Routes in app_router.dart

**Files:**
- Modify: `safetrip-mobile/lib/router/app_router.dart`

**Step 1: Replace all PlaceholderScreens with real screens**

Add imports for all 5 new screens and update route builders:

```dart
import '../screens/settings/screen_profile_edit.dart';
import '../screens/settings/screen_device_permissions.dart';
import '../screens/settings/screen_notification_settings.dart';
import '../screens/settings/screen_privacy_management.dart';
import '../screens/settings/screen_account_delete.dart';
```

Replace each `PlaceholderScreen` with the corresponding real screen widget.

**Step 2: Verify full build**

Run: `cd safetrip-mobile && flutter analyze`
Expected: No errors (warnings acceptable)

**Step 3: Commit**

```
feat(settings): wire all 5 new settings screens into app router
```

---

## Task 12: Final Build Verification

**Step 1: Run flutter analyze**

```bash
cd safetrip-mobile && flutter analyze
```

Expected: 0 errors

**Step 2: Run flutter build (check compilation)**

```bash
cd safetrip-mobile && flutter build apk --debug
```

Expected: BUILD SUCCESSFUL

**Step 3: Final commit (if any fixes needed)**

```
fix(settings): resolve build errors from settings implementation
```

---

## Verification Checklist (per spec §14)

| # | 검증 항목 | Task |
|:-:|----------|:----:|
| 1 | Layer 1/Layer 2 구분 표시 | Task 3 |
| 2 | 프로필 편집 (사진/이름/전화번호) | Task 4 |
| 3 | 기기 권한 (위치/알림/카메라) | Task 5 |
| 4 | 전역 알림 (SOS 항상 ON) | Task 6 |
| 5 | 개인정보 관리 (동의현황/열람요청/마케팅) | Task 7 |
| 6 | 계정 삭제 (7일 유예, 삭제 안내) | Task 8 |
| 7 | 프라이버시 등급 변경 다이얼로그 (캡틴 전용) | Task 9 |
| 8 | 위치 일시 중지 (역할/등급별) | Task 9 |
| 9 | 가디언 실제 API 연동 | Task 10 |
| 10 | 가디언 과금 모달 (1,900원/여행) | Task 10 |
| 11 | 유료 가디언 해제 환불 불가 안내 | Task 10 |
| 12 | 전체 라우팅 연결 | Task 11 |
