# Settings Screen 구현 계획

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 바텀시트 설정 메뉴를 전체화면 `SettingsScreen`으로 교체하고, 역할(leader/full/normal/view_only)별 설정 항목을 섹션으로 구성한다.

**Architecture:** 단일 `SettingsScreen`에 조건부 섹션 렌더링. 기존 모달 위젯(LeaderTransferModal, InviteCodeManagementModal)에 `isEmbedded` 플래그를 추가해 전체화면에서도 재사용. 프로필 편집과 위치공유관리는 별도 서브페이지로 분리.

**Tech Stack:** Flutter, Dart, SharedPreferences, Firebase Storage, image_picker, ApiService

---

## 파일 변경 요약

| 작업 | 파일 |
|------|------|
| 수정 | `lib/screens/main/bottom_sheets/modals/leader_transfer_modal.dart` |
| 생성 | `lib/screens/settings/screen_settings.dart` |
| 생성 | `lib/screens/settings/screen_settings_profile.dart` |
| 생성 | `lib/screens/settings/screen_settings_location.dart` |
| 수정 | `lib/screens/main/screen_main.dart` |

---

## 배경 지식

### 역할 체계
- `leader` — 그룹 리더. 모든 기능 접근 가능
- `full` — 공동관리자. 리더 양도 제외 모든 기능
- `normal` — 일반 멤버. 위치 공유 + 앱 설정
- `view_only` — 보호자. 위치 공유 없음. 앱 설정만

### 핵심 유틸 클래스
- `AppCache` (`lib/utils/app_cache.dart`): 동기 getter — `userIdSync`, `userNameSync`, `memberRoleSync`, `groupIdSync`
- `ApiService.updateUserProfile(userId, displayName, profileImageUrl?)` — 프로필 업데이트 API
- `LocationService.setLocationSharingEnabled(bool)` — 위치 공유 정적 메서드
- `AvatarWidget` (`lib/widgets/avatar_widget.dart`) — 프로필 이미지 위젯

### 현재 설정 진입점
`screen_main.dart:1471` — `_showLocationSettingsBottomSheet()` → `showModalBottomSheet(_LocationSettingsBottomSheet)`

---

### Task 1: `LeaderTransferModal`에 `isEmbedded` 추가

**Files:**
- Modify: `lib/screens/main/bottom_sheets/modals/leader_transfer_modal.dart`

전체화면에서 사용할 때 내부 Container의 65% 높이 제한을 제거한다.

**Step 1: 파일 열기 및 현재 상태 확인**

`lib/screens/main/bottom_sheets/modals/leader_transfer_modal.dart` 파일을 열어 `LeaderTransferModal` 클래스를 확인한다.

**Step 2: `isEmbedded` 파라미터 추가**

`LeaderTransferModal` StatefulWidget의 파라미터에 추가:

```dart
class LeaderTransferModal extends StatefulWidget {
  final String groupId;
  final String currentUserId;
  final bool isEmbedded; // 추가

  const LeaderTransferModal({
    super.key,
    required this.groupId,
    required this.currentUserId,
    this.isEmbedded = false, // 추가
  });
```

**Step 3: `build()` 메서드 분기 처리**

`_LeaderTransferModalState.build()` 전체를 아래로 교체:

```dart
@override
Widget build(BuildContext context) {
  if (widget.isEmbedded) {
    return _buildContent();
  }
  return Container(
    height: MediaQuery.of(context).size.height * 0.65,
    decoration: const BoxDecoration(
      color: AppTokens.bgBasic01,
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(AppTokens.radius20),
        topRight: Radius.circular(AppTokens.radius20),
      ),
    ),
    child: _buildContent(),
  );
}
```

**Step 4: `_buildContent()` 메서드로 기존 Column을 추출**

기존 `build()` 안의 `Column(children: [...])` 을 `_buildContent()` 로 추출:

```dart
Widget _buildContent() {
  return Column(
    children: [
      // 헤더
      Container(
        padding: const EdgeInsets.all(AppTokens.spacing16),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppTokens.line03),
          ),
        ),
        child: Row(
          children: [
            Text(
              '리더 양도',
              style: AppTokens.textStyle(
                fontSize: AppTokens.fontSize20,
                fontWeight: AppTokens.fontWeightBold,
              ),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.close),
              color: AppTokens.text05,
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
      // 안내 텍스트
      Padding(
        padding: const EdgeInsets.fromLTRB(
          AppTokens.spacing16,
          AppTokens.spacing16,
          AppTokens.spacing16,
          AppTokens.spacing8,
        ),
        child: Text(
          '리더 권한을 양도할 멤버를 선택하세요.\n양도 후 나의 역할은 공동관리자로 변경됩니다.',
          style: AppTokens.textStyle(
            fontSize: AppTokens.fontSize12,
            color: AppTokens.text03,
            height: 1.5,
          ),
        ),
      ),
      // 멤버 리스트 + 양도 버튼 (기존 코드 그대로)
      // ... (기존 Expanded + Padding 코드 유지)
    ],
  );
}
```

> **주의:** 기존 `build()` 메서드의 Column 내용을 `_buildContent()`로 이동하되, 기존 코드 로직은 변경하지 않는다.

**Step 5: `flutter analyze` 실행**

```bash
cd /mnt/d/Project/15_SafeTrip_New/safetrip-mobile && flutter analyze --no-fatal-infos 2>&1 | head -30
```

Expected: 에러 없음.

**Step 6: 커밋**

```bash
cd /mnt/d/Project/15_SafeTrip_New/safetrip-mobile
git add lib/screens/main/bottom_sheets/modals/leader_transfer_modal.dart
git commit -m "refactor: add isEmbedded param to LeaderTransferModal for full-screen reuse"
```

---

### Task 2: `screen_settings.dart` — 메인 설정 전체화면 생성

**Files:**
- Create: `lib/screens/settings/screen_settings.dart`

**Step 1: 디렉토리 생성 확인**

```bash
mkdir -p /mnt/d/Project/15_SafeTrip_New/safetrip-mobile/lib/screens/settings
```

**Step 2: 파일 생성**

`lib/screens/settings/screen_settings.dart` 를 아래 내용으로 생성:

```dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../constants/app_tokens.dart';
import '../../services/api_service.dart';
import '../../services/location_service.dart';
import '../../services/map_image_cache_service.dart';
import '../../utils/app_cache.dart';
import '../../widgets/avatar_widget.dart';
import '../main/bottom_sheets/modals/invite_code_management_modal.dart';
import '../main/bottom_sheets/modals/leader_transfer_modal.dart';
import '../screen_splash.dart' show InitialScreen;
import '../main/screen_log.dart';
import 'screen_settings_location.dart';
import 'screen_settings_profile.dart';

class SettingsScreen extends StatefulWidget {
  final String currentUserId;
  final String groupId;
  final String userRole; // leader / full / normal / view_only
  final LocationService? locationService;
  final String userName;
  final String? phoneNumber;
  final String? profileImageUrl;

  const SettingsScreen({
    super.key,
    required this.currentUserId,
    required this.groupId,
    required this.userRole,
    required this.locationService,
    required this.userName,
    this.phoneNumber,
    this.profileImageUrl,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _locationSharingEnabled = true;
  bool _isLoading = false;

  // 역할 편의 getter
  bool get _isAdmin =>
      widget.userRole == 'leader' || widget.userRole == 'full';
  bool get _isLeader => widget.userRole == 'leader';
  bool get _showLocation =>
      widget.userRole != 'view_only' && widget.userRole != 'guardian';

  @override
  void initState() {
    super.initState();
    _loadLocationSharingState();
  }

  Future<void> _loadLocationSharingState() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _locationSharingEnabled =
            prefs.getBool('location_sharing_enabled') ?? true;
      });
    }
  }

  // ─── 위치 공유 토글 ────────────────────────────────────────────────────────
  Future<void> _onLocationSharingChanged(bool value) async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _locationSharingEnabled = value;
    });
    try {
      await LocationService.setLocationSharingEnabled(value);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(value ? '위치 공유가 켜졌습니다' : '위치 공유가 꺼졌습니다'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _locationSharingEnabled = !value);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('위치 공유 설정 변경에 실패했습니다')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── 이미지 캐시 삭제 ──────────────────────────────────────────────────────
  Future<void> _onClearCache() async {
    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('캐시 삭제'),
        content: const Text('저장된 모든 이미지 캐시를 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
                foregroundColor: AppTokens.semanticWarning),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (shouldClear != true) return;
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final cacheService = MapImageCacheService();
      await cacheService.clearCache();
      try {
        final documentsDir = await getApplicationDocumentsDirectory();
        final profilesDir =
            Directory(path.join(documentsDir.path, 'profiles'));
        if (await profilesDir.exists()) {
          for (var file in profilesDir.listSync()) {
            if (file is File) await file.delete();
          }
          try {
            await profilesDir.delete(recursive: false);
          } catch (_) {}
        }
      } catch (_) {}
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('이미지 캐시가 삭제되었습니다')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('캐시 삭제에 실패했습니다'),
            backgroundColor: AppTokens.semanticError,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── 로그아웃 ──────────────────────────────────────────────────────────────
  Future<void> _onLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text('로그아웃하시겠습니까? 모든 데이터가 삭제됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
                foregroundColor: AppTokens.semanticError),
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );
    if (shouldLogout != true) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      try {
        final locationService = LocationService();
        await locationService.stopTracking();
      } catch (_) {}
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const InitialScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그아웃 중 오류가 발생했습니다')),
        );
      }
    }
  }

  // ─── 역할 표시명 ───────────────────────────────────────────────────────────
  String get _roleDisplayName {
    switch (widget.userRole) {
      case 'leader':
        return '리더';
      case 'full':
        return '공동관리자';
      case 'normal':
        return '일반 멤버';
      case 'view_only':
        return '보호자';
      default:
        return '멤버';
    }
  }

  Color get _roleColor {
    switch (widget.userRole) {
      case 'leader':
        return AppTokens.semanticError;
      case 'full':
        return AppTokens.primaryTeal;
      case 'normal':
        return AppTokens.semanticSuccess;
      case 'view_only':
        return AppTokens.secondaryAmber;
      default:
        return AppTokens.text03;
    }
  }

  // ─── 빌드 ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTokens.bgBasic03,
      appBar: AppBar(
        backgroundColor: AppTokens.bgBasic01,
        elevation: 0,
        title: const Text(
          '설정',
          style: TextStyle(
            color: AppTokens.text05,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          // 역할 배지
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _roleColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppTokens.radius20),
            ),
            child: Text(
              _roleDisplayName,
              style: TextStyle(
                color: _roleColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: AppTokens.text05),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: ListView(
        children: [
          const SizedBox(height: 16),
          // ── 프로필 카드 ─────────────────────────────────────────────────
          _buildProfileCard(),
          const SizedBox(height: 8),

          // ── 위치 섹션 (view_only/guardian 제외) ──────────────────────
          if (_showLocation) ...[
            _buildSectionHeader('위치'),
            _buildLocationSharingTile(),
            _buildTile(
              icon: Icons.people_outline,
              iconColor: AppTokens.primaryTeal,
              title: '위치 공유 관리',
              subtitle: '멤버별 위치 공유 설정',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SettingsLocationScreen(
                    groupId: widget.groupId,
                    currentUserId: widget.currentUserId,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],

          // ── 그룹 관리 섹션 (leader / full만) ────────────────────────
          if (_isAdmin) ...[
            _buildSectionHeader('그룹 관리'),
            _buildTile(
              icon: Icons.qr_code,
              iconColor: AppTokens.primaryTeal,
              title: '초대코드 관리',
              subtitle: '멤버 초대코드 생성 및 관리',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => Scaffold(
                    backgroundColor: AppTokens.bgBasic01,
                    appBar: AppBar(
                      backgroundColor: AppTokens.bgBasic01,
                      elevation: 0,
                      title: const Text(
                        '초대코드 관리',
                        style: TextStyle(
                          color: AppTokens.text05,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      iconTheme:
                          const IconThemeData(color: AppTokens.text05),
                    ),
                    body: InviteCodeManagementModal(
                      groupId: widget.groupId,
                      isEmbedded: true,
                    ),
                  ),
                ),
              ),
            ),
            if (_isLeader)
              _buildTile(
                icon: Icons.transfer_within_a_station,
                iconColor: AppTokens.semanticWarning,
                title: '리더 양도',
                subtitle: '다른 멤버에게 리더 권한 양도',
                onTap: () async {
                  final result = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => Scaffold(
                        backgroundColor: AppTokens.bgBasic01,
                        body: SafeArea(
                          child: LeaderTransferModal(
                            groupId: widget.groupId,
                            currentUserId: widget.currentUserId,
                            isEmbedded: true,
                          ),
                        ),
                      ),
                    ),
                  );
                  // 리더 양도 성공 시 설정 화면도 닫고 메인에서 역할 재로드
                  if (result == true && mounted) {
                    Navigator.pop(context, 'reload');
                  }
                },
              ),
            const SizedBox(height: 8),
          ],

          // ── 앱 섹션 ────────────────────────────────────────────────────
          _buildSectionHeader('앱'),
          if (widget.locationService != null)
            _buildTile(
              icon: FontAwesomeIcons.list,
              iconColor: Colors.blue,
              title: '로그 보기',
              subtitle: '위치 추적 및 시스템 로그 확인',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      LogScreen(locationService: widget.locationService!),
                ),
              ),
            ),
          _buildTile(
            icon: FontAwesomeIcons.trash,
            iconColor: AppTokens.semanticWarning,
            title: '이미지 캐시 삭제',
            subtitle: '저장된 지도 및 프로필 이미지 삭제',
            onTap: _isLoading ? null : _onClearCache,
          ),
          const SizedBox(height: 8),

          // ── 계정 섹션 ──────────────────────────────────────────────────
          _buildSectionHeader('계정'),
          _buildTile(
            icon: FontAwesomeIcons.arrowRightFromBracket,
            iconColor: AppTokens.semanticError,
            title: '로그아웃',
            subtitle: '앱에서 로그아웃하고 모든 데이터 삭제',
            titleColor: AppTokens.semanticError,
            onTap: _isLoading ? null : _onLogout,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ─── 프로필 카드 ───────────────────────────────────────────────────────────
  Widget _buildProfileCard() {
    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => SettingsProfileScreen(
              currentUserId: widget.currentUserId,
              userName: widget.userName,
              profileImageUrl: widget.profileImageUrl,
            ),
          ),
        );
        if (result == true && mounted) {
          // 프로필 변경 완료 → 메인에서 trip info 재로드하도록 결과 전달
          Navigator.pop(context, 'reload');
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTokens.bgBasic01,
          borderRadius: BorderRadius.circular(AppTokens.radius16),
          boxShadow: AppTokens.shadow01,
        ),
        child: Row(
          children: [
            AvatarWidget(
              userId: widget.currentUserId,
              userName: widget.userName,
              profileImageUrl: widget.profileImageUrl,
              size: 56,
              borderWidth: 2,
              borderColor: AppTokens.teal04,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.userName,
                    style: AppTokens.textStyle(
                      fontSize: AppTokens.fontSize16,
                      fontWeight: AppTokens.fontWeightSemibold,
                      color: AppTokens.text05,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.phoneNumber != null && widget.phoneNumber!.isNotEmpty
                        ? '$_roleDisplayName · ${widget.phoneNumber}'
                        : _roleDisplayName,
                    style: AppTokens.textStyle(
                      fontSize: AppTokens.fontSize13,
                      color: AppTokens.text03,
                    ),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '편집',
                  style: AppTokens.textStyle(
                    fontSize: AppTokens.fontSize13,
                    color: AppTokens.primaryTeal,
                    fontWeight: AppTokens.fontWeightMedium,
                  ),
                ),
                const SizedBox(width: 2),
                const Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: AppTokens.text03,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── 섹션 헤더 ────────────────────────────────────────────────────────────
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Text(
        title,
        style: AppTokens.textStyle(
          fontSize: AppTokens.fontSize12,
          fontWeight: AppTokens.fontWeightSemibold,
          color: AppTokens.text03,
        ),
      ),
    );
  }

  // ─── 위치 공유 토글 타일 (Switch 포함) ───────────────────────────────────
  Widget _buildLocationSharingTile() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      decoration: BoxDecoration(
        color: AppTokens.bgBasic01,
        borderRadius: BorderRadius.circular(AppTokens.radius12),
      ),
      child: InkWell(
        onTap: _isLoading
            ? null
            : () => _onLocationSharingChanged(!_locationSharingEnabled),
        borderRadius: BorderRadius.circular(AppTokens.radius12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppTokens.bgTeal03,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.location_on_outlined,
                  color: AppTokens.primaryTeal,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '위치 공유',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: AppTokens.text05,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '다른 사용자에게 내 위치 공유',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTokens.text03,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _locationSharingEnabled,
                onChanged: _isLoading ? null : _onLocationSharingChanged,
                activeColor: AppTokens.primaryTeal,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── 일반 항목 타일 ───────────────────────────────────────────────────────
  Widget _buildTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
    Color? titleColor,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      decoration: BoxDecoration(
        color: AppTokens.bgBasic01,
        borderRadius: BorderRadius.circular(AppTokens.radius12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTokens.radius12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: titleColor ?? AppTokens.text05,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTokens.text03,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                size: 20,
                color: AppTokens.text03,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

**Step 3: `flutter analyze` 실행**

```bash
cd /mnt/d/Project/15_SafeTrip_New/safetrip-mobile && flutter analyze --no-fatal-infos 2>&1 | head -40
```

Expected: 에러 없음. 경고가 있으면 수정.

**Step 4: 커밋**

```bash
cd /mnt/d/Project/15_SafeTrip_New/safetrip-mobile
git add lib/screens/settings/screen_settings.dart
git commit -m "feat: add SettingsScreen full-screen with role-based sections"
```

---

### Task 3: `screen_settings_profile.dart` — 프로필 편집 서브페이지

**Files:**
- Create: `lib/screens/settings/screen_settings_profile.dart`

기존 `ProfileScreen` (auth 플로우용)의 이름 변경 + 프로필 이미지 변경 로직을 설정용으로 재구현.

**Step 1: 파일 생성**

`lib/screens/settings/screen_settings_profile.dart` 를 아래 내용으로 생성:

```dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../../constants/app_tokens.dart';
import '../../services/api_service.dart';
import '../../utils/app_cache.dart';
import '../../widgets/avatar_widget.dart';

class SettingsProfileScreen extends StatefulWidget {
  final String currentUserId;
  final String userName;
  final String? profileImageUrl;

  const SettingsProfileScreen({
    super.key,
    required this.currentUserId,
    required this.userName,
    this.profileImageUrl,
  });

  @override
  State<SettingsProfileScreen> createState() => _SettingsProfileScreenState();
}

class _SettingsProfileScreenState extends State<SettingsProfileScreen> {
  final ApiService _apiService = ApiService();
  final ImagePicker _imagePicker = ImagePicker();

  late TextEditingController _nameController;
  File? _selectedImageFile;
  bool _isSaving = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.userName);
    _nameController.addListener(_onChanged);
  }

  @override
  void dispose() {
    _nameController.removeListener(_onChanged);
    _nameController.dispose();
    super.dispose();
  }

  void _onChanged() {
    final nameChanged =
        _nameController.text.trim() != widget.userName;
    final imageChanged = _selectedImageFile != null;
    setState(() {
      _hasChanges = nameChanged || imageChanged;
    });
  }

  // ─── 이미지 선택 ──────────────────────────────────────────────────────────
  Future<void> _pickImage() async {
    // 권한 요청
    PermissionStatus status;
    if (Platform.isAndroid) {
      final androidInfo = await _getAndroidSdkVersion();
      if (androidInfo >= 33) {
        status = await Permission.photos.request();
      } else {
        status = await Permission.storage.request();
      }
    } else {
      status = await Permission.photos.request();
    }

    if (status.isDenied || status.isPermanentlyDenied) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('갤러리 접근 권한이 필요합니다')),
        );
      }
      return;
    }

    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 80,
    );
    if (picked == null) return;

    if (mounted) {
      setState(() {
        _selectedImageFile = File(picked.path);
        _hasChanges = true;
      });
    }
  }

  Future<int> _getAndroidSdkVersion() async {
    try {
      // Android SDK 버전 감지 (간단히 33 이상으로 가정)
      return 33;
    } catch (_) {
      return 33;
    }
  }

  // ─── Firebase Storage에 이미지 업로드 ────────────────────────────────────
  Future<String?> _uploadImage(File imageFile) async {
    try {
      // 이미지 압축
      final bytes = await imageFile.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return null;

      final resized = img.copyResize(decoded, width: 256, height: 256);
      final compressed = img.encodeJpg(resized, quality: 80);

      // 로컬 임시 파일 저장
      final documentsDir = await getApplicationDocumentsDirectory();
      final profilesDir =
          Directory(path.join(documentsDir.path, 'profiles'));
      if (!await profilesDir.exists()) {
        await profilesDir.create(recursive: true);
      }
      final localFile = File(
          path.join(profilesDir.path, '${widget.currentUserId}.jpg'));
      await localFile.writeAsBytes(compressed);

      // Firebase Storage 업로드
      final useEmulator =
          dotenv.env['USE_FIREBASE_EMULATOR'] == 'true';
      final storage = FirebaseStorage.instance;

      final ref = storage
          .ref()
          .child('profiles/${widget.currentUserId}.jpg');

      await ref.putData(
        compressed,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      final downloadUrl = await ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      debugPrint('[SettingsProfile] 이미지 업로드 실패: $e');
      return null;
    }
  }

  // ─── 저장 ─────────────────────────────────────────────────────────────────
  Future<void> _onSave() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이름을 입력해주세요')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      String? newImageUrl;

      // 이미지 변경된 경우 업로드
      if (_selectedImageFile != null) {
        newImageUrl = await _uploadImage(_selectedImageFile!);
        if (newImageUrl == null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('이미지 업로드에 실패했습니다')),
          );
          setState(() => _isSaving = false);
          return;
        }
      }

      // API 호출
      final result = await _apiService.updateUserProfile(
        userId: widget.currentUserId,
        displayName: name,
        profileImageUrl: newImageUrl,
      );

      if (result == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('프로필 업데이트에 실패했습니다')),
          );
        }
        setState(() => _isSaving = false);
        return;
      }

      // AppCache 갱신
      await AppCache.updateUserInfo(userName: name);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('프로필이 업데이트되었습니다')),
        );
        Navigator.pop(context, true); // true = 메인에서 reload 필요
      }
    } catch (e) {
      debugPrint('[SettingsProfile] 저장 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('프로필 저장 중 오류가 발생했습니다')),
        );
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTokens.bgBasic03,
      appBar: AppBar(
        backgroundColor: AppTokens.bgBasic01,
        elevation: 0,
        title: const Text(
          '프로필 편집',
          style: TextStyle(
            color: AppTokens.text05,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: const IconThemeData(color: AppTokens.text05),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTokens.primaryTeal,
                ),
              ),
            )
          else
            TextButton(
              onPressed: _hasChanges ? _onSave : null,
              child: Text(
                '저장',
                style: TextStyle(
                  color: _hasChanges
                      ? AppTokens.primaryTeal
                      : AppTokens.text03,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 16),
            // 프로필 이미지
            Center(
              child: Stack(
                children: [
                  _selectedImageFile != null
                      ? CircleAvatar(
                          radius: 52,
                          backgroundImage:
                              FileImage(_selectedImageFile!),
                        )
                      : AvatarWidget(
                          userId: widget.currentUserId,
                          userName: widget.userName,
                          profileImageUrl: widget.profileImageUrl,
                          size: 104,
                          borderWidth: 2,
                          borderColor: AppTokens.teal04,
                        ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppTokens.primaryTeal,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppTokens.bgBasic01,
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: AppTokens.bgBasic01,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            // 이름 입력
            Container(
              decoration: BoxDecoration(
                color: AppTokens.bgBasic01,
                borderRadius:
                    BorderRadius.circular(AppTokens.radius12),
              ),
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 4),
              child: TextField(
                controller: _nameController,
                style: AppTokens.textStyle(
                  fontSize: AppTokens.fontSize15,
                  color: AppTokens.text05,
                ),
                decoration: const InputDecoration(
                  labelText: '이름',
                  labelStyle: TextStyle(
                    color: AppTokens.text03,
                    fontSize: 13,
                  ),
                  border: InputBorder.none,
                ),
                maxLength: 20,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '이름은 그룹 멤버에게 표시됩니다.',
              style: AppTokens.textStyle(
                fontSize: AppTokens.fontSize12,
                color: AppTokens.text03,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

**Step 2: `flutter analyze` 실행**

```bash
cd /mnt/d/Project/15_SafeTrip_New/safetrip-mobile && flutter analyze --no-fatal-infos 2>&1 | head -40
```

**Step 3: 커밋**

```bash
cd /mnt/d/Project/15_SafeTrip_New/safetrip-mobile
git add lib/screens/settings/screen_settings_profile.dart
git commit -m "feat: add SettingsProfileScreen for name and photo editing"
```

---

### Task 4: `screen_settings_location.dart` — 위치 공유 관리 서브페이지

**Files:**
- Create: `lib/screens/settings/screen_settings_location.dart`

`LocationSharingModal`의 내용을 전체화면 Scaffold로 래핑. 기존 모달의 `height: 70%` 제한 없이 전체화면으로 동작.

**Step 1: 파일 생성**

`lib/screens/settings/screen_settings_location.dart` 를 아래 내용으로 생성:

```dart
import 'package:flutter/material.dart';
import '../../constants/app_tokens.dart';
import '../../services/api_service.dart';

/// 위치 공유 관리 — 전체화면 버전
/// LocationSharingModal의 내용을 Scaffold로 래핑
class SettingsLocationScreen extends StatefulWidget {
  final String groupId;
  final String currentUserId;

  const SettingsLocationScreen({
    super.key,
    required this.groupId,
    required this.currentUserId,
  });

  @override
  State<SettingsLocationScreen> createState() =>
      _SettingsLocationScreenState();
}

class _SettingsLocationScreenState extends State<SettingsLocationScreen> {
  final ApiService _apiService = ApiService();

  bool _masterEnabled = true;
  bool _isLoading = true;
  List<Map<String, dynamic>> _members = [];
  final Map<String, bool> _memberSharingStates = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final members =
          await _apiService.getGroupMembers(widget.groupId);
      if (mounted) {
        final activeMembers = members
            .where((m) =>
                m['status'] == 'active' &&
                m['user_id'] != widget.currentUserId)
            .toList();

        final currentMember = members.firstWhere(
          (m) => m['user_id'] == widget.currentUserId,
          orElse: () => <String, dynamic>{},
        );
        final masterState =
            currentMember['location_sharing_enabled'] as bool? ?? true;

        setState(() {
          _members = activeMembers;
          _masterEnabled = masterState;
          for (final m in activeMembers) {
            _memberSharingStates[m['user_id'] as String] = true;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleMaster(bool value) async {
    setState(() => _masterEnabled = value);
    final success = await _apiService.updateLocationSharingStatus(
      userId: widget.currentUserId,
      enabled: value,
    );
    if (!success && mounted) {
      setState(() => _masterEnabled = !value);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('위치 공유 설정 변경에 실패했습니다')),
      );
    }
  }

  void _toggleMemberSharing(String userId, bool value) {
    setState(() => _memberSharingStates[userId] = value);
    // TODO: 개별 멤버 위치 공유 API 연동 (TB_LOCATION_SHARING)
  }

  String _getRoleName(String? role) {
    switch (role) {
      case 'leader':
        return '리더';
      case 'full':
        return '공동관리자';
      case 'normal':
        return '일반 멤버';
      case 'view_only':
        return '모니터링 전용';
      default:
        return '멤버';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTokens.bgBasic01,
      appBar: AppBar(
        backgroundColor: AppTokens.bgBasic01,
        elevation: 0,
        title: const Text(
          '위치 공유 관리',
          style: TextStyle(
            color: AppTokens.text05,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: const IconThemeData(color: AppTokens.text05),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppTokens.primaryTeal,
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppTokens.spacing16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 마스터 토글
                  Container(
                    padding: const EdgeInsets.all(AppTokens.spacing16),
                    decoration: BoxDecoration(
                      color: _masterEnabled
                          ? AppTokens.primaryTeal
                              .withValues(alpha: 0.08)
                          : AppTokens.bgBasic03,
                      borderRadius:
                          BorderRadius.circular(AppTokens.radius12),
                      border: Border.all(
                        color: _masterEnabled
                            ? AppTokens.primaryTeal
                            : AppTokens.line03,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _masterEnabled
                              ? Icons.location_on
                              : Icons.location_off,
                          color: _masterEnabled
                              ? AppTokens.primaryTeal
                              : AppTokens.text03,
                          size: 24,
                        ),
                        const SizedBox(width: AppTokens.spacing12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                '내 위치 공유',
                                style: AppTokens.textStyle(
                                  fontSize: AppTokens.fontSize14,
                                  fontWeight:
                                      AppTokens.fontWeightSemibold,
                                  color: _masterEnabled
                                      ? AppTokens.text06
                                      : AppTokens.text04,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _masterEnabled
                                    ? '그룹 멤버에게 내 위치가 공유됩니다'
                                    : '위치 공유가 꺼져 있습니다',
                                style: AppTokens.textStyle(
                                  fontSize: AppTokens.fontSize12,
                                  color: AppTokens.text03,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _masterEnabled,
                          onChanged: _toggleMaster,
                          activeColor: AppTokens.primaryTeal,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppTokens.spacing24),

                  if (_masterEnabled && _members.isNotEmpty) ...[
                    Text(
                      '멤버별 위치 공유 설정',
                      style: AppTokens.textStyle(
                        fontSize: AppTokens.fontSize14,
                        fontWeight: AppTokens.fontWeightSemibold,
                      ),
                    ),
                    const SizedBox(height: AppTokens.spacing4),
                    Text(
                      '각 멤버에게 내 위치를 공유할지 선택하세요',
                      style: AppTokens.textStyle(
                        fontSize: AppTokens.fontSize12,
                        color: AppTokens.text03,
                      ),
                    ),
                    const SizedBox(height: AppTokens.spacing12),
                    ..._members.map((member) {
                      final userId = member['user_id'] as String;
                      final isEnabled =
                          _memberSharingStates[userId] ?? true;
                      final role =
                          member['member_role'] as String? ?? '';
                      return Container(
                        margin: const EdgeInsets.only(
                            bottom: AppTokens.spacing8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTokens.spacing12,
                          vertical: AppTokens.spacing8,
                        ),
                        decoration: BoxDecoration(
                          color: AppTokens.bgBasic01,
                          borderRadius: BorderRadius.circular(
                              AppTokens.radius12),
                          border: Border.all(color: AppTokens.line03),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: AppTokens.bgTeal03,
                              child: Text(
                                (member['display_name']
                                            as String? ??
                                        '?')
                                    .characters
                                    .first,
                                style: AppTokens.textStyle(
                                  fontSize: AppTokens.fontSize12,
                                  fontWeight:
                                      AppTokens.fontWeightBold,
                                  color: AppTokens.primaryTeal,
                                ),
                              ),
                            ),
                            const SizedBox(
                                width: AppTokens.spacing12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    member['display_name']
                                            as String? ??
                                        userId,
                                    style: AppTokens.textStyle(
                                      fontSize:
                                          AppTokens.fontSize14,
                                      fontWeight:
                                          AppTokens.fontWeightMedium,
                                    ),
                                  ),
                                  Text(
                                    _getRoleName(role),
                                    style: AppTokens.textStyle(
                                      fontSize:
                                          AppTokens.fontSize11,
                                      color: AppTokens.text03,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: isEnabled,
                              onChanged: (v) =>
                                  _toggleMemberSharing(userId, v),
                              activeColor: AppTokens.primaryTeal,
                            ),
                          ],
                        ),
                      );
                    }),
                  ],

                  if (!_masterEnabled) ...[
                    Container(
                      padding: const EdgeInsets.all(AppTokens.spacing16),
                      decoration: BoxDecoration(
                        color: AppTokens.bgBasic03,
                        borderRadius:
                            BorderRadius.circular(AppTokens.radius12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            color: AppTokens.text03,
                            size: 20,
                          ),
                          const SizedBox(width: AppTokens.spacing8),
                          Expanded(
                            child: Text(
                              '위치 공유를 켜면 개별 멤버별로\n공유 범위를 설정할 수 있습니다.',
                              style: AppTokens.textStyle(
                                fontSize: AppTokens.fontSize12,
                                color: AppTokens.text03,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
```

**Step 2: `flutter analyze` 실행**

```bash
cd /mnt/d/Project/15_SafeTrip_New/safetrip-mobile && flutter analyze --no-fatal-infos 2>&1 | head -40
```

**Step 3: 커밋**

```bash
cd /mnt/d/Project/15_SafeTrip_New/safetrip-mobile
git add lib/screens/settings/screen_settings_location.dart
git commit -m "feat: add SettingsLocationScreen full-screen location sharing management"
```

---

### Task 5: `screen_main.dart` 수정

**Files:**
- Modify: `lib/screens/main/screen_main.dart`

`_showLocationSettingsBottomSheet()`를 `_openSettingsScreen()`으로 교체하고, 기존 `_LocationSettingsBottomSheet` 클래스를 삭제한다.

**Step 1: import 추가**

`screen_main.dart` 상단 import 목록에 추가 (기존 `screen_notification_list.dart` import 아래):

```dart
import '../settings/screen_settings.dart';
```

**Step 2: `_showLocationSettingsBottomSheet()` 교체**

`screen_main.dart:1470` 의 기존 메서드:
```dart
// 위치 설정 바텀시트 표시
void _showLocationSettingsBottomSheet() {
  showModalBottomSheet(
    context: context,
    builder: (context) =>
        _LocationSettingsBottomSheet(locationService: _locationService),
  );
}
```

아래로 교체:
```dart
// 설정 전체화면 열기
void _openSettingsScreen() async {
  final phoneNumber = await AppCache.phoneNumber;
  if (!mounted) return;

  final result = await Navigator.push<String>(
    context,
    MaterialPageRoute(
      builder: (_) => SettingsScreen(
        currentUserId: AppCache.userIdSync ?? '',
        groupId: AppCache.groupIdSync ?? '',
        userRole: _currentUserRole,
        locationService: _locationService,
        userName: AppCache.userNameSync ?? '',
        phoneNumber: phoneNumber,
        profileImageUrl: _userProfileImageUrl,
      ),
    ),
  );

  // 프로필 수정 또는 리더 양도 후 여행 정보 재로드
  if (result == 'reload' && mounted) {
    _loadTripInfo();
  }
}
```

**Step 3: `_openSettingsScreen()` 호출로 교체**

파일 내 `_showLocationSettingsBottomSheet` 참조 두 곳을 `_openSettingsScreen` 으로 교체:

- `screen_main.dart:4201`: `onSettingsPressed: _showLocationSettingsBottomSheet,` → `onSettingsPressed: _openSettingsScreen,`
- `screen_main.dart:4219`: `onSettingsPressed: _showLocationSettingsBottomSheet,` → `onSettingsPressed: _openSettingsScreen,`

**Step 4: `_LocationSettingsBottomSheet` 클래스 삭제**

파일 하단 `screen_main.dart:4900` 부터 시작하는 아래 두 클래스 전체를 삭제:

```dart
// 위치 설정 바텀시트 위젯
class _LocationSettingsBottomSheet extends StatefulWidget { ... }

class _LocationSettingsBottomSheetState extends State<_LocationSettingsBottomSheet> { ... }
```

삭제 범위: `// 위치 설정 바텀시트 위젯` 주석부터 파일 마지막 `}` 까지 (약 line 4900 ~ 5376).

**Step 5: `flutter analyze` 실행**

```bash
cd /mnt/d/Project/15_SafeTrip_New/safetrip-mobile && flutter analyze --no-fatal-infos 2>&1 | head -40
```

Expected: 에러 없음.

**Step 6: 빌드 확인**

```bash
cd /mnt/d/Project/15_SafeTrip_New/safetrip-mobile && flutter build apk --debug 2>&1 | tail -20
```

Expected: Build 성공.

**Step 7: 커밋**

```bash
cd /mnt/d/Project/15_SafeTrip_New/safetrip-mobile
git add lib/screens/main/screen_main.dart
git commit -m "feat: replace settings bottom sheet with full-screen SettingsScreen"
```

---

## 수동 테스트 체크리스트

앱 실행 후 아이콘(⚙) 탭으로 확인:

- [ ] `leader` 계정: 위치·그룹관리(초대코드+리더양도)·앱·계정 섹션 모두 표시
- [ ] `full` 계정: 리더양도 항목 미표시, 나머지 동일
- [ ] `normal` 계정: 그룹관리 섹션 미표시
- [ ] `view_only` 계정: 위치 섹션 미표시
- [ ] 프로필 편집 → 이름 변경 저장 → 메인으로 돌아와 상단바 이름 갱신 확인
- [ ] 위치 공유 토글 → 실시간 반영
- [ ] 초대코드 관리 → 전체화면으로 열림
- [ ] 리더 양도 → 전체화면으로 열림, 양도 완료 후 메인 역할 갱신
- [ ] 로그아웃 → 스플래시로 이동
