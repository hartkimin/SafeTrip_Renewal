# Profile Image Display Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Display registered profile images in TripInfoCard (member avatar stack), member tab list, map markers, and cluster marker popup.

**Architecture:**
- TripInfoCard receives a `members` list from screen_main and renders an avatar stack alongside the "참여자N" counter.
- Cluster popup (`_showClusterMemberList`) adds `AvatarWidget` per member row.
- Member tab list and map markers already have the infrastructure in place (profile_image_url flows through `_users`).

**Tech Stack:** Flutter/Dart, `AvatarWidget` (lib/widgets/avatar_widget.dart), Firebase Storage

---

### Task 1: Add `members` parameter to TripInfoCard

**Files:**
- Modify: `safetrip-mobile/lib/widgets/trip_info_card.dart`

**Step 1: Add `members` field to `TripInfoCard` widget**

In the `TripInfoCard` class (around line 399), add:
```dart
final List<Map<String, dynamic>>? members; // profile_image_url 포함
```
And add to constructor:
```dart
this.members,
```

**Step 2: Add `_buildMemberAvatarStack()` helper method**

Add this method to `_TripInfoCardState`:
```dart
Widget _buildMemberAvatarStack() {
  final members = widget.members;
  if (members == null || members.isEmpty) return const SizedBox.shrink();

  const double avatarSize = 22.0;
  const double overlap = 8.0;
  const int maxVisible = 3;

  final visibleMembers = members.take(maxVisible).toList();
  final extraCount = members.length - maxVisible;

  final List<Widget> avatarWidgets = [];
  for (int i = 0; i < visibleMembers.length; i++) {
    final m = visibleMembers[i];
    final userId = m['user_id'] as String? ?? '';
    final profileImageUrl = m['profile_image_url'] as String?;
    avatarWidgets.add(
      Positioned(
        left: i * (avatarSize - overlap),
        child: AvatarWidget(
          userId: userId,
          profileImageUrl: profileImageUrl,
          size: avatarSize,
          shape: 'circle',
          borderWidth: 1.5,
          borderColor: AppTokens.bgBasic01,
        ),
      ),
    );
  }

  final totalWidth =
      visibleMembers.length * (avatarSize - overlap) + overlap +
      (extraCount > 0 ? 20.0 : 0);

  return SizedBox(
    width: totalWidth,
    height: avatarSize,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        ...avatarWidgets,
        if (extraCount > 0)
          Positioned(
            left: visibleMembers.length * (avatarSize - overlap),
            child: Container(
              width: avatarSize,
              height: avatarSize,
              decoration: BoxDecoration(
                color: AppTokens.line03,
                shape: BoxShape.circle,
                border: Border.all(width: 1.5, color: AppTokens.bgBasic01),
              ),
              child: Center(
                child: Text(
                  '+$extraCount',
                  style: AppTokens.textStyle(
                    fontSize: 8,
                    fontWeight: AppTokens.fontWeightMedium,
                    color: AppTokens.text03,
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
```

**Step 3: Update `_buildRoleInfo()` to include avatar stack**

Replace the "참여자N" row (lines 1000-1048) with:
```dart
Row(
  children: [
    _buildMemberAvatarStack(),
    if (widget.members != null && widget.members!.isNotEmpty)
      const SizedBox(width: AppTokens.spacing6),
    Container(
      width: 6, height: 6,
      decoration: const BoxDecoration(
        color: AppTokens.primaryTeal,
        shape: BoxShape.circle,
      ),
    ),
    const SizedBox(width: 3),
    Text(
      '참여자${widget.memberCount}',
      style: AppTokens.textStyle(
        fontSize: AppTokens.fontSize11,
        fontWeight: AppTokens.fontWeightRegular,
        color: AppTokens.text03,
      ),
    ),
    Text(
      ' · ',
      style: AppTokens.textStyle(
        fontSize: AppTokens.fontSize11,
        fontWeight: AppTokens.fontWeightRegular,
        color: AppTokens.text03,
      ),
    ),
    Container(
      width: 6, height: 6,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppTokens.text03, width: 1),
      ),
    ),
    const SizedBox(width: 3),
    Text(
      '모니터링${widget.guardianCount}',
      style: AppTokens.textStyle(
        fontSize: AppTokens.fontSize11,
        fontWeight: AppTokens.fontWeightRegular,
        color: AppTokens.text03,
      ),
    ),
  ],
),
```

---

### Task 2: Pass `_users` to TripInfoCard in screen_main.dart

**Files:**
- Modify: `safetrip-mobile/lib/screens/main/screen_main.dart` (around line 3808)

**Step 1: Add `members: _users` to the TripInfoCard call in `_buildTripInfoCardAccordion()`**

```dart
TripInfoCard(
  // ... 기존 파라미터 ...
  userProfileImageUrl: _userProfileImageUrl,
  userId: AppCache.userIdSync,
  members: _users, // 추가
  onTripSwitchPressed: _showTripSwitchModal,
),
```

---

### Task 3: Add AvatarWidget to cluster member popup

**Files:**
- Modify: `safetrip-mobile/lib/screens/main/screen_main.dart` (`_showClusterMemberList`, around line 2350)

**Step 1: Add `avatar_widget.dart` import if not already present**

Check imports at top of screen_main.dart. If not present, add:
```dart
import '../../widgets/avatar_widget.dart';
```

**Step 2: Update member row in ListView.builder**

Replace the Row widget inside the `GestureDetector` (lines ~2367-2406) with:
```dart
child: Padding(
  padding: const EdgeInsets.only(bottom: 8),
  child: Row(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      // 프로필 아바타
      AvatarWidget(
        userId: userId,
        profileImageUrl: member['profile_image_url'] as String?,
        size: 24,
        shape: 'circle',
        borderWidth: 0,
      ),
      const SizedBox(width: 6),
      // 상태 dot
      Container(
        width: 8, height: 8,
        decoration: BoxDecoration(
          color: status.color,
          shape: BoxShape.circle,
        ),
      ),
      const SizedBox(width: 6),
      // 이름
      Flexible(
        child: Text(
          userName,
          style: AppTokens.textStyle(
            fontSize: AppTokens.fontSize12,
            fontWeight: AppTokens.fontWeightMedium,
            color: AppTokens.text05,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      const SizedBox(width: 6),
      // 상태 텍스트
      Text(
        status.text,
        style: AppTokens.textStyle(
          fontSize: AppTokens.fontSize11,
          fontWeight: AppTokens.fontWeightRegular,
          color: status.color,
        ),
      ),
    ],
  ),
),
```

---

### Testing

1. 여행정보카드 펼치기 → "참여자N" 줄에 프로필 아바타 스택 표시 확인
2. 멤버탭에서 각 멤버 카드의 프로필 이미지가 등록된 이미지로 표시되는지 확인
3. 지도에서 마커에 프로필 이미지가 표시되는지 확인
4. 클러스터 마커 탭 → 멤버 목록에 아바타가 표시되는지 확인
5. 프로필 이미지 없는 사용자 → fallback(avata_df.png)이 표시되는지 확인
