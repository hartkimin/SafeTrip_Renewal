# Bottom Sheet Spec Compliance Design

| Item | Value |
|------|-------|
| Date | 2026-03-05 |
| Spec | `Master_docs/11_T2_바텀시트_동작_규칙.md` v2.0 |
| Scope | P0 + P1 전체 + §3.3 전환 제약 + §7.4 세부 화면 전환 |

## Problem

바텀시트 동작 규칙(§1-§12)과 현재 구현 간 4개 불일치 항목 발견.

## Findings

### Already Correct (10 items)
- §2: 5단계 상태 enum + snap sizes (0.10~1.00)
- §5.1: 탭별 기본 높이
- §5.2: 여행 상태별 초기 높이
- §7.2: 탭 전환 시 높이 결정 로직
- §7.3: 탭별 최소 요구 높이
- §4.4: 동일 탭 재탭 동작
- §10.1~10.3: SOS 발동/해제 동작
- §6.1: 키보드 출현/닫힘 처리
- §6.2: 채팅탭 키보드 닫힘 → expanded
- §4.2: Snap 동작

### Issues to Fix (4 items)

#### Issue 1: Animation Timing (§3.1)
- `_animateSheetTo` defaults to 200ms for all cases
- Spec: tab tap from collapsed → half should be 250ms easeInOut
- Fix: Pass 250ms duration for same-tab re-tap collapsed→half transition

#### Issue 2: No Trip State (§8.2)
- Spec: `none` status → collapsed, tab bar disabled, "+ 새 여행 만들기" CTA
- Current: Only collapsed height applied, tab bar remains active, no CTA
- Fix: Disable tab bar when none, show CTA content in bottom sheet

#### Issue 3: Transition Constraints (§3.3)
- Spec: full→collapsed direct only at velocity > 2000 dp/s
- Spec: collapsed→full direct only with two-finger swipe
- Current: DraggableScrollableSheet default snap physics
- Fix: Post-hoc validation in onLevelChanged + two-finger gesture detector

#### Issue 4: Detail View Transitions (§7.4)
- Spec: Detail view entry → full, back → restore previous level
- Current: Not implemented
- Fix: Add preDetailLevel to state, enter/exit callbacks, apply to Member tab

## Design

### Section 1: Animation Timing
- In `_handleTabChanged`, when same-tab re-tap from collapsed → half, use 250ms duration
- All other animations keep current values (already match spec)

### Section 2: No Trip State
- `screen_main.dart`: Check tripStatus == 'none', disable tab bar, show CTA
- CTA: Centered card with "+" icon and "새 여행 만들기" text, taps to trip creation
- Tab bar: `isDisabled: true` (reuse SOS mechanism)
- Sheet locked at collapsed, drag disabled

### Section 3: Transition Constraints
- Track `_previousLevel` in SnappingBottomSheet state
- In `_onSizeChanged`: if level jump >= 3 indices (full↔collapsed), animate to intermediate
- Full→collapsed blocked → animate to expanded instead
- Collapsed→full blocked → animate to peek instead
- Wrap sheet area with RawGestureDetector for two-finger vertical drag detection
- On two-finger up swipe from collapsed: animate to full

### Section 4: Detail View Transitions
- Add `preDetailLevel` to MainScreenState
- Add `enterDetailView()`: save current level, return full
- Add `exitDetailView()`: restore preDetailLevel
- Pass callbacks to tab content widgets
- Apply to BottomSheetMember: member card tap → enterDetail, back → exitDetail

## Files to Modify

| File | Changes |
|------|---------|
| `main_screen_provider.dart` | preDetailLevel field, enterDetailView/exitDetailView, previousLevel tracking |
| `screen_main.dart` | Animation timing, none state handling, CTA widget, two-finger gesture, detail callbacks |
| `snapping_bottom_sheet.dart` | Previous level tracking, jump validation in onLevelChanged |
| `bottom_navigation_bar.dart` | No changes needed (isDisabled already exists) |
| `bottom_sheet_2_member.dart` | Detail view callbacks on member selection/back |
