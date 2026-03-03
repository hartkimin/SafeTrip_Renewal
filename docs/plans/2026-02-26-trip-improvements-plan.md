# SafeTrip 8개 이슈 개선 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** SafeTrip Flutter 앱의 역할 표시 버그, 날짜 버그, 초대코드 관리, 멤버 추가, 배터리 색상, 여행전환 UI 등 8개 이슈를 수정한다.

**Architecture:** 도메인 B 접근법 — 멤버 도메인(최우선) → 여행정보 도메인 → UI 흐름 도메인 순서로 진행. 각 도메인은 독립 파일 단위로 수정하며, MainScreen(`screen_main.dart`)은 여행정보 도메인에서 한 번만 수정한다.

**Tech Stack:** Flutter/Dart, `font_awesome_flutter`, `intl`, `share_plus`, `flutter/services` (Clipboard)

---

## 도메인 1: 멤버 (최우선)

### Task 1: 배터리 색상 단계별 표시

**Files:**
- Modify: `safetrip-mobile/lib/screens/main/bottom_sheets/bottom_sheet_2_member.dart:4491-4497`

**Step 1: `_getBatteryColor` 메서드 추가**

`_getBatteryIcon` 메서드 바로 아래에 추가:

```dart
Color _getBatteryColor(int level, {bool isCharging = false}) {
  if (isCharging) return Colors.blue;
  if (level > 60) return Colors.green;
  if (level > 20) return Colors.orange;
  return Colors.red;
}
```

**Step 2: 배터리 아이콘에 색상 적용**

`bottom_sheet_2_member.dart` 라인 ~1195 부근 배터리 아이콘 위젯:

현재:
```dart
Icon(
  batteryIsCharging == true
      ? FontAwesomeIcons.batteryFull
      : _getBatteryIcon(finalBatteryLevel),
  color: AppTokens.text03,
),
```

변경:
```dart
Icon(
  batteryIsCharging == true
      ? FontAwesomeIcons.batteryFull
      : _getBatteryIcon(finalBatteryLevel),
  color: _getBatteryColor(
    finalBatteryLevel,
    isCharging: batteryIsCharging == true,
  ),
  size: 14,
),
```

**Step 3: 배터리 텍스트에도 색상 적용**

배터리 퍼센트 Text 위젯 (~라인 1208):
```dart
Text(
  '$finalBatteryLevel%',
  style: AppTokens.textStyle(
    fontSize: AppTokens.fontSize11,
    color: _getBatteryColor(
      finalBatteryLevel,
      isCharging: batteryIsCharging == true,
    ),
  ),
),
```

**Step 4: 핫 리로드로 확인**

멤버 탭에서 배터리 아이콘이 초록/주황/빨강으로 단계별 표시되는지 확인.

---

### Task 2: 초대코드 관리 모달 — 코드 생성 기능 추가

**Files:**
- Modify: `safetrip-mobile/lib/screens/main/bottom_sheets/modals/invite_code_management_modal.dart`

**Step 1: 상태 변수 및 `_showCreateCodeDialog` 메서드 추가**

`_InviteCodeManagementModalState` 클래스 내부에 추가:

```dart
// 코드 생성 관련 상태
bool _isCreating = false;

Future<void> _showCreateCodeDialog() async {
  String selectedRole = 'normal';
  int maxUses = 5;
  int expiresInDays = 7;

  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radius16),
        ),
        title: Text(
          '초대코드 생성',
          style: AppTokens.textStyle(
            fontSize: AppTokens.fontSize18,
            fontWeight: AppTokens.fontWeightBold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('역할', style: AppTokens.textStyle(fontSize: AppTokens.fontSize14, fontWeight: AppTokens.fontWeightSemibold)),
            const SizedBox(height: AppTokens.spacing8),
            DropdownButtonFormField<String>(
              value: selectedRole,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTokens.radius8)),
              ),
              items: const [
                DropdownMenuItem(value: 'full', child: Text('공동관리자')),
                DropdownMenuItem(value: 'normal', child: Text('일반 멤버')),
                DropdownMenuItem(value: 'view_only', child: Text('모니터링 전용')),
              ],
              onChanged: (v) => setDialogState(() => selectedRole = v!),
            ),
            const SizedBox(height: AppTokens.spacing12),
            Text('최대 사용 횟수', style: AppTokens.textStyle(fontSize: AppTokens.fontSize14, fontWeight: AppTokens.fontWeightSemibold)),
            const SizedBox(height: AppTokens.spacing8),
            DropdownButtonFormField<int>(
              value: maxUses,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTokens.radius8)),
              ),
              items: const [
                DropdownMenuItem(value: 1, child: Text('1회')),
                DropdownMenuItem(value: 5, child: Text('5회')),
                DropdownMenuItem(value: 10, child: Text('10회')),
                DropdownMenuItem(value: 9999, child: Text('무제한')),
              ],
              onChanged: (v) => setDialogState(() => maxUses = v!),
            ),
            const SizedBox(height: AppTokens.spacing12),
            Text('유효기간', style: AppTokens.textStyle(fontSize: AppTokens.fontSize14, fontWeight: AppTokens.fontWeightSemibold)),
            const SizedBox(height: AppTokens.spacing8),
            DropdownButtonFormField<int>(
              value: expiresInDays,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTokens.radius8)),
              ),
              items: const [
                DropdownMenuItem(value: 1, child: Text('1일')),
                DropdownMenuItem(value: 3, child: Text('3일')),
                DropdownMenuItem(value: 7, child: Text('7일')),
                DropdownMenuItem(value: 0, child: Text('무기한')),
              ],
              onChanged: (v) => setDialogState(() => expiresInDays = v!),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('취소', style: AppTokens.textStyle(color: AppTokens.text03)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _createCode(
                role: selectedRole,
                maxUses: maxUses,
                expiresInDays: expiresInDays == 0 ? null : expiresInDays,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTokens.primaryTeal,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTokens.radius8),
              ),
            ),
            child: Text('생성', style: AppTokens.textStyle(color: Colors.white, fontWeight: AppTokens.fontWeightSemibold)),
          ),
        ],
      ),
    ),
  );
}

Future<void> _createCode({
  required String role,
  required int maxUses,
  int? expiresInDays,
}) async {
  setState(() => _isCreating = true);
  final result = await _apiService.createInviteCode(
    groupId: widget.groupId,
    targetRole: role,
    maxUses: maxUses,
    expiresInDays: expiresInDays,
  );
  if (mounted) {
    setState(() => _isCreating = false);
    if (result != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('초대코드가 생성되었습니다')),
      );
      _loadCodes();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('초대코드 생성에 실패했습니다')),
      );
    }
  }
}
```

**Step 2: 헤더에 "코드 생성" 버튼 추가**

`build()` 메서드의 헤더 Row에서 `IconButton(icon: Icon(Icons.close), ...)` 앞에 추가:

```dart
if (_isCreating)
  const SizedBox(
    width: 20, height: 20,
    child: CircularProgressIndicator(strokeWidth: 2, color: AppTokens.primaryTeal),
  )
else
  IconButton(
    icon: const Icon(Icons.add_circle_outline),
    color: AppTokens.primaryTeal,
    tooltip: '새 코드 생성',
    onPressed: _showCreateCodeDialog,
  ),
const SizedBox(width: AppTokens.spacing4),
```

**Step 3: 핫 리로드로 확인**

초대코드 관리 모달에서 `+` 버튼 탭 → 생성 다이얼로그 → 역할/횟수/기간 선택 → 생성 → 목록에 새 코드 표시.

---

### Task 3: 멤버 추가 모달 신규 생성

**Files:**
- Create: `safetrip-mobile/lib/screens/main/bottom_sheets/modals/add_member_modal.dart`

**Step 1: 파일 생성**

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../constants/app_tokens.dart';
import '../../../../services/api_service.dart';
import '../../../../utils/app_cache.dart';
import '../../../../utils/share_helper.dart';
import 'invite_code_management_modal.dart';

/// 멤버 추가 모달 — 초대코드 탭 + 직접 검색 탭
class AddMemberModal extends StatefulWidget {
  final String groupId;

  const AddMemberModal({super.key, required this.groupId});

  @override
  State<AddMemberModal> createState() => _AddMemberModalState();
}

class _AddMemberModalState extends State<AddMemberModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ApiService _apiService = ApiService();

  // 직접 검색 탭 상태
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  String _selectedRole = 'normal';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchUsers(String query) async {
    if (query.trim().length < 2) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _isSearching = true);
    try {
      final results = await _apiService.searchUsers(query.trim());
      if (mounted) setState(() => _searchResults = results);
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _inviteUser(Map<String, dynamic> user) async {
    final userId = user['user_id'] as String?;
    if (userId == null) return;

    String selectedRole = _selectedRole;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radius16),
          ),
          title: Text(
            '역할 선택',
            style: AppTokens.textStyle(
              fontSize: AppTokens.fontSize16,
              fontWeight: AppTokens.fontWeightBold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${user['user_name'] ?? user['phone_number'] ?? '사용자'}를 어떤 역할로 초대할까요?',
                style: AppTokens.textStyle(fontSize: AppTokens.fontSize14, color: AppTokens.text04),
              ),
              const SizedBox(height: AppTokens.spacing12),
              DropdownButtonFormField<String>(
                value: selectedRole,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTokens.radius8)),
                ),
                items: const [
                  DropdownMenuItem(value: 'full', child: Text('공동관리자')),
                  DropdownMenuItem(value: 'normal', child: Text('일반 멤버')),
                  DropdownMenuItem(value: 'view_only', child: Text('모니터링 전용')),
                ],
                onChanged: (v) => setDialogState(() => selectedRole = v!),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('취소', style: AppTokens.textStyle(color: AppTokens.text03)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTokens.primaryTeal,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTokens.radius8),
                ),
              ),
              child: Text('초대', style: AppTokens.textStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    final result = await _apiService.inviteUserToGroup(
      groupId: widget.groupId,
      targetUserId: userId,
      role: selectedRole,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result ? '초대되었습니다' : '초대에 실패했습니다'),
        ),
      );
      if (result) Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.80,
      decoration: const BoxDecoration(
        color: AppTokens.bgBasic01,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(AppTokens.radius20),
          topRight: Radius.circular(AppTokens.radius20),
        ),
      ),
      child: Column(
        children: [
          // 헤더
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTokens.spacing16,
              AppTokens.spacing16,
              AppTokens.spacing8,
              0,
            ),
            child: Row(
              children: [
                Text(
                  '멤버 추가',
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
          // 탭 바
          TabBar(
            controller: _tabController,
            labelColor: AppTokens.primaryTeal,
            unselectedLabelColor: AppTokens.text03,
            indicatorColor: AppTokens.primaryTeal,
            tabs: const [
              Tab(text: '초대코드'),
              Tab(text: '직접 검색'),
            ],
          ),
          // 탭 뷰
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildInviteCodeTab(),
                _buildDirectSearchTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInviteCodeTab() {
    return InviteCodeManagementModal(groupId: widget.groupId);
  }

  Widget _buildDirectSearchTab() {
    return Padding(
      padding: const EdgeInsets.all(AppTokens.spacing16),
      child: Column(
        children: [
          // 검색 입력
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: '이름 또는 전화번호로 검색',
              hintStyle: AppTokens.textStyle(color: AppTokens.text03),
              prefixIcon: const Icon(Icons.search, color: AppTokens.text03),
              suffixIcon: _isSearching
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppTokens.primaryTeal),
                      ),
                    )
                  : null,
              filled: true,
              fillColor: AppTokens.bgBasic03,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTokens.radius12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppTokens.spacing16,
                vertical: AppTokens.spacing12,
              ),
            ),
            onChanged: (v) => _searchUsers(v),
          ),
          const SizedBox(height: AppTokens.spacing12),
          // 검색 결과
          Expanded(
            child: _searchResults.isEmpty
                ? Center(
                    child: Text(
                      _searchController.text.length < 2
                          ? '2자 이상 입력하세요'
                          : '검색 결과가 없습니다',
                      style: AppTokens.textStyle(
                        fontSize: AppTokens.fontSize14,
                        color: AppTokens.text03,
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: _searchResults.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: AppTokens.line03),
                    itemBuilder: (ctx, i) {
                      final user = _searchResults[i];
                      final name = user['user_name'] as String? ?? '';
                      final phone = user['phone_number'] as String? ?? '';
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppTokens.bgTeal03,
                          child: Text(
                            name.isNotEmpty ? name[0] : '?',
                            style: AppTokens.textStyle(
                              color: AppTokens.primaryTeal,
                              fontWeight: AppTokens.fontWeightBold,
                            ),
                          ),
                        ),
                        title: Text(name, style: AppTokens.textStyle(fontWeight: AppTokens.fontWeightSemibold)),
                        subtitle: Text(phone, style: AppTokens.textStyle(fontSize: AppTokens.fontSize12, color: AppTokens.text03)),
                        trailing: ElevatedButton(
                          onPressed: () => _inviteUser(user),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTokens.primaryTeal,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppTokens.radius8),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            minimumSize: const Size(0, 32),
                          ),
                          child: Text('초대', style: AppTokens.textStyle(color: Colors.white, fontSize: AppTokens.fontSize13)),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
```

**Step 2: `InviteCodeManagementModal`이 단독/임베드 양쪽으로 동작하도록 수정**

`InviteCodeManagementModal.build()` 에서 `Container` 감싸는 부분을:
- `isEmbedded` 생성자 파라미터 추가 (`final bool isEmbedded; const InviteCodeManagementModal({..., this.isEmbedded = false})`)
- `isEmbedded == true`이면 최상위 Container 높이 지정 없이 `Column`만 반환

---

### Task 4: 멤버탭 헤더에 "멤버 추가" 버튼 연결

**Files:**
- Modify: `safetrip-mobile/lib/screens/main/bottom_sheets/bottom_sheet_2_member.dart`

**Step 1: `searchUsers` 및 `inviteUserToGroup` API 메서드 추가**

`safetrip-mobile/lib/services/api_service.dart`에 추가:

```dart
/// 사용자 검색 (이름 또는 전화번호)
Future<List<Map<String, dynamic>>> searchUsers(String query) async {
  try {
    final response = await _dio.get(
      '/api/v1/users/search',
      queryParameters: {'q': query},
    );
    debugPrint('[API] searchUsers ${jsonEncode(response.data)}');
    if (response.data['success'] == true && response.data['data'] != null) {
      final data = response.data['data'];
      if (data is List) return data.cast<Map<String, dynamic>>();
    }
    return [];
  } catch (e) {
    debugPrint('[API] searchUsers 실패: $e');
    return [];
  }
}

/// 그룹에 사용자 직접 초대
Future<bool> inviteUserToGroup({
  required String groupId,
  required String targetUserId,
  required String role,
}) async {
  try {
    final response = await _dio.post(
      '/api/v1/groups/$groupId/members',
      data: {'user_id': targetUserId, 'role': role},
    );
    return response.data['success'] == true;
  } catch (e) {
    debugPrint('[API] inviteUserToGroup 실패: $e');
    return false;
  }
}
```

**Step 2: 멤버탭 헤더에 "멤버 추가" 버튼 추가**

`bottom_sheet_2_member.dart`에서 멤버 탭 헤더 행(Row)을 찾아 끝에 추가 (그룹 관리자/리더 권한일 때만):

```dart
// import 추가 (파일 상단)
import 'modals/add_member_modal.dart';
```

멤버 헤더 Row에 추가:
```dart
IconButton(
  icon: const Icon(Icons.person_add_outlined, size: 20),
  color: AppTokens.primaryTeal,
  tooltip: '멤버 추가',
  onPressed: () async {
    final groupId = await AppCache.groupId;
    if (groupId == null || !mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddMemberModal(groupId: groupId),
    );
  },
),
```

**Step 3: 핫 리로드 후 확인**

멤버 탭 → `+` 아이콘 → 모달 열림 → 초대코드 탭 (코드 목록 + 생성) / 직접 검색 탭 (검색 → 초대) 동작 확인.

---

## 도메인 2: 여행정보

### Task 5: 날짜 하루 차이 버그 수정

**Files:**
- Modify: `safetrip-mobile/lib/screens/trip/screen_trip_create.dart:206-207`

**Step 1: 날짜 포맷 수정**

현재 코드:
```dart
final startDateStr = _startDate!.toIso8601String().split('T')[0];
final endDateStr = _endDate!.toIso8601String().split('T')[0];
```

수정:
```dart
final startDateStr = DateFormat('yyyy-MM-dd').format(_startDate!);
final endDateStr = DateFormat('yyyy-MM-dd').format(_endDate!);
```

`intl`은 이미 import되어 있음 (`import 'package:intl/intl.dart';` 확인 필요, 없으면 추가).

**Step 2: 핫 리로드 후 확인**

여행 생성 → 2026-03-05 선택 → 확인 화면에서 "2026-03-05"로 표시되는지 확인.

---

### Task 6: 역할 표시 버그 수정 (리더 → 여행자 표시)

**Files:**
- Modify: `safetrip-mobile/lib/screens/main/screen_main.dart:544-677`
- Modify: `safetrip-mobile/lib/screens/main/screen_main.dart:3779`

**Step 1: `_loadTripInfo()`에 역할 해석 로직 추가**

`_loadTripInfo()` 메서드 내에서 `members` 처리 후, 현재 사용자 role 결정 추가 (라인 ~632 이후):

```dart
// 현재 사용자의 역할 결정
String resolvedUserRole = AppCache.userRoleSync ?? 'traveler';
if (currentUserId != null) {
  final currentUserList = members.cast<Map<String, dynamic>>().where(
    (m) => m['user_id'] == currentUserId,
  ).toList();
  if (currentUserList.isNotEmpty) {
    final memberRole = currentUserList.first['member_role'] as String?;
    if (memberRole != null) {
      resolvedUserRole = memberRole;
    } else {
      resolvedUserRole = currentUserList.first['user_role'] as String? ?? 'traveler';
    }
  }
  // 그룹 생성자 확인 (레거시 호환)
  final creatorId = groupInfo?['creator_id'] as String? ??
      tripInfo?['creator_id'] as String?;
  if (creatorId == currentUserId && resolvedUserRole == 'traveler') {
    resolvedUserRole = 'leader';
  }
}
```

**Step 2: `setState` 블록에 역할 상태 변수 저장**

`_MainScreenState`에 상태 변수 추가:
```dart
String _currentUserRole = 'traveler'; // _loadTripInfo에서 설정
```

`setState` 블록 안에:
```dart
_currentUserRole = resolvedUserRole;
```

**Step 3: `TripInfoCard` 호출부 수정 (라인 3779)**

현재:
```dart
userRole: AppCache.userRoleSync ?? 'traveler',
```

변경:
```dart
userRole: _currentUserRole,
```

**Step 4: 핫 리로드 후 확인**

여행 생성자 로그인 → 여행정보카드에서 "리더 ⭐" 칩이 표시되는지 확인.

---

### Task 7: 국가명 / 여행명 분리 표시

**Files:**
- Modify: `safetrip-mobile/lib/widgets/trip_info_card.dart`

**Step 1: `TripInfoCard`에 `countryName` 파라미터 추가**

`TripInfoCard` 클래스 파라미터:
```dart
final String? countryName; // 국가명 (예: '일본', '태국')
```

생성자:
```dart
this.countryName,
```

**Step 2: 여행명 표시 위에 국가명 행 추가**

`tripName`을 표시하는 `Flexible(child: Text(widget.tripName, ...))` 위에:

```dart
if (widget.countryName != null) ...[
  Row(
    children: [
      if (widget.countryCode != null)
        CountryFlag.fromCountryCode(
          widget.countryCode!,
          width: 16,
          height: 12,
        ),
      if (widget.countryCode != null) const SizedBox(width: 4),
      Text(
        widget.countryName!,
        style: AppTokens.textStyle(
          fontSize: AppTokens.fontSize12,
          color: AppTokens.text03,
          fontWeight: AppTokens.fontWeightMedium,
        ),
      ),
    ],
  ),
  const SizedBox(height: 2),
],
```

**Step 3: `screen_main.dart`에서 `countryName` 전달**

`TripInfoCard(` 호출부에 추가:
```dart
countryName: _destinationName, // _countryCodeToName[_countryCode] 또는 _destinationName
```

**Step 4: 권한별 역할 칩 확장**

`trip_info_card.dart`의 `_resolveRoleLabel()`:

현재 케이스에 추가:
```dart
case 'full':
  return '공동관리자';
case 'normal':
  return '일반 멤버';
case 'view_only':
  return '모니터링';
```

`_roleColor` getter도 동일하게 확장:
```dart
case 'full':
  return AppTokens.primaryTeal;
case 'normal':
  return AppTokens.semanticSuccess;
case 'view_only':
  return AppTokens.secondaryAmber;
```

---

### Task 8: 여행전환 목록 미표시 수정

**Files:**
- Modify: `safetrip-mobile/lib/screens/main/screen_main.dart:1426`

**Step 1: `_showTripSwitchModal`에서 await 추가**

현재 (라인 ~1426):
```dart
void _showTripSwitchModal() {
  TripSwitchModal.show(
    context,
    trips: _tripList.isNotEmpty ? _tripList : [ ... ],
    ...
  );
}
```

수정:
```dart
Future<void> _showTripSwitchModal() async {
  // 최신 여행 목록 로드 후 모달 표시
  await _loadUserTripList();
  if (!mounted) return;
  TripSwitchModal.show(
    context,
    trips: _tripList.isNotEmpty ? _tripList : [ ... ],
    ...
  );
}
```

**Step 2: 호출부도 `async/await` 패턴으로 수정**

`_showTripSwitchModal`을 호출하는 버튼의 `onTap`이 `void`이면 `() async { await _showTripSwitchModal(); }` 로 수정.

---

## 도메인 3: UI 흐름

### Task 9: 여행전환화면 "참여코드로 참여하기" 버튼 추가

**Files:**
- Modify: `safetrip-mobile/lib/widgets/trip_switch_modal.dart:505-590`
- Modify: `safetrip-mobile/lib/screens/main/screen_main.dart` (`_showTripSwitchModal` 호출부)
- Modify: `safetrip-mobile/lib/screens/trip/screen_trip_selection.dart` (JoinType import 확인)

**Step 1: `TripSwitchModal._buildBottomSection`에 참여 버튼 추가**

"새 여행 계획하기" `GestureDetector` 뒤에 추가:

```dart
const SizedBox(height: AppTokens.spacing4),
GestureDetector(
  onTap: () {
    Navigator.pop(context);
    widget.onJoinTrip?.call();
  },
  child: Padding(
    padding: const EdgeInsets.symmetric(vertical: AppTokens.spacing10),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.qr_code_scanner_rounded,
          size: 18,
          color: AppTokens.text04,
        ),
        const SizedBox(width: AppTokens.spacing4),
        Text(
          '참여코드로 참여하기',
          style: AppTokens.textStyle(
            fontSize: AppTokens.fontSize14,
            fontWeight: AppTokens.fontWeightMedium,
            color: AppTokens.text04,
          ),
        ),
      ],
    ),
  ),
),
```

**Step 2: `screen_main.dart` → `_showTripSwitchModal`에 `onJoinTrip` 콜백 연결**

```dart
TripSwitchModal.show(
  context,
  trips: ...,
  currentGroupId: ...,
  onTripSelected: ...,
  onCreateTrip: ...,
  onJoinTrip: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ScreenTripJoinCode(joinType: JoinType.traveler),
      ),
    );
  },
);
```

import 확인:
```dart
import '../trip/screen_trip_join_code.dart';
```

**Step 3: 핫 리로드 후 확인**

여행전환 모달 하단에 "참여코드로 참여하기" 버튼이 표시되고, 탭 시 코드 입력 화면으로 이동하는지 확인.

---

## 실행 순서 요약

```
Task 1: 배터리 색상 (2분)
Task 2: 초대코드 생성 버튼 (10분)
Task 3: AddMemberModal 신규 생성 (20분)
Task 4: 멤버탭 버튼 + API 메서드 (10분)
Task 5: 날짜 버그 (2분)
Task 6: 역할 버그 (10분)
Task 7: 국가명/여행명 분리 + 칩 확장 (10분)
Task 8: 여행전환 목록 (5분)
Task 9: 참여코드 버튼 (5분)
```
