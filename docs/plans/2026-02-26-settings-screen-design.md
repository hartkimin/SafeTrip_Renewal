# 설정 화면 전체화면 전환 & 역할별 설정 메뉴 설계

**날짜:** 2026-02-26
**상태:** 승인됨

---

## 개요

현재 `_LocationSettingsBottomSheet`(바텀시트)를 `SettingsScreen`(전체화면 Scaffold)으로 교체하고, 역할(`leader` / `full` / `normal` / `view_only`)에 맞는 설정 항목을 섹션별로 구성한다. 별도 모달로 흩어진 기능(위치공유관리, 초대코드관리, 리더양도)을 설정 화면 안에 통합한다.

---

## 새로 생성할 파일

```
safetrip-mobile/lib/screens/settings/
├── screen_settings.dart           ← 메인 설정 전체화면
├── screen_settings_profile.dart   ← 프로필 편집 서브페이지
└── screen_settings_location.dart  ← 위치 공유 관리(멤버별) 서브페이지
```

기존 `LeaderTransferModal`, `InviteCodeManagementModal`은 Scaffold로 래핑하여 서브페이지로 열린다(별도 파일 불필요).

---

## 역할별 항목 매핑

| 항목 | leader | full | normal | view_only |
|------|:------:|:----:|:------:|:---------:|
| [프로필] 이름·사진 편집 | ✅ | ✅ | ✅ | ✅ |
| [위치] 위치 공유 ON/OFF 토글 | ✅ | ✅ | ✅ | ❌ |
| [위치] 위치 공유 관리 (멤버별) | ✅ | ✅ | ✅ | ❌ |
| [그룹관리] 초대코드 관리 | ✅ | ✅ | ❌ | ❌ |
| [그룹관리] 리더 양도 | ✅ | ❌ | ❌ | ❌ |
| [앱] 로그 보기 | ✅ | ✅ | ✅ | ✅ |
| [앱] 이미지 캐시 삭제 | ✅ | ✅ | ✅ | ✅ |
| [계정] 로그아웃 | ✅ | ✅ | ✅ | ✅ |

---

## 화면 레이아웃 (SettingsScreen)

```
Scaffold
  AppBar: "설정" 타이틀 + 역할 배지 칩 + 닫기(X) 버튼

  Body (SingleChildScrollView):

  ┌─ 프로필 카드 ─────────────────────────────┐
  │  [CircleAvatar]  사용자 이름               │
  │                  역할명 · 전화번호          │
  │                              [편집 →]      │
  └────────────────────────────────────────────┘

  ─── 위치 ───────────────────  (normal/full/leader만)
  ▸ 위치 공유              [Switch 토글, 즉시 API 호출]
  ▸ 위치 공유 관리         [→ chevron → SettingsLocationScreen]

  ─── 그룹 관리 ──────────────  (full/leader만)
  ▸ 초대코드 관리          [→ chevron → Scaffold(InviteCodeManagementModal)]
  ▸ 리더 양도              [→ chevron → Scaffold(LeaderTransferModal), leader만]

  ─── 앱 ─────────────────────  (모든 역할)
  ▸ 로그 보기              [→ chevron → LogScreen]
  ▸ 이미지 캐시 삭제       [→ chevron, 확인 다이얼로그]

  ─── 계정 ───────────────────  (모든 역할)
  ▸ 로그아웃               [빨간색 텍스트 + → chevron, 확인 다이얼로그]
```

---

## SettingsScreen 파라미터

```dart
SettingsScreen({
  required String currentUserId,
  required String groupId,
  required String userRole,         // _currentUserRole (leader/full/normal/view_only)
  required LocationService? locationService,
  required String userName,
  String? phoneNumber,
  String? profileImageUrl,
})
```

---

## SettingsProfileScreen (프로필 편집)

기존 `ProfileScreen`의 이름 변경 + 프로필 사진 변경 로직을 추출.
API: `ApiService.updateUserProfile()` 재사용.
저장 완료 시 `AppCache` 갱신 후 `Navigator.pop(true)`.

---

## SettingsLocationScreen (위치 공유 관리)

기존 `LocationSharingModal`의 콘텐츠를 Scaffold로 래핑.
마스터 ON/OFF + 멤버별 토글 구조 그대로 유지.

---

## 진입점 변경

`screen_main.dart`의 `_showLocationSettingsBottomSheet()` 함수를 아래로 교체:

```dart
void _openSettingsScreen() {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => SettingsScreen(
        currentUserId: AppCache.userIdSync ?? '',
        groupId: AppCache.groupIdSync ?? '',
        userRole: _currentUserRole,
        locationService: _locationService,
        userName: AppCache.userNameSync ?? '',
        phoneNumber: AppCache.phoneNumberSync,
        profileImageUrl: _userProfileImageUrl,
      ),
    ),
  );
}
```

기존 `_LocationSettingsBottomSheet` 위젯 클래스는 삭제.

---

## 데이터 반환

- 위치 공유 토글: 즉시 API 호출 (현재 방식 유지)
- 프로필 편집: `Navigator.pop(true)` → `screen_main.dart`에서 `_loadTripInfo()` 재호출
- 리더 양도: `Navigator.pop(true)` → `screen_main.dart`에서 역할 재로드
