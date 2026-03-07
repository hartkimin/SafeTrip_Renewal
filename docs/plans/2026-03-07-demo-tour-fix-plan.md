# 데모 투어 체험(30_T3) 스펙 정합 수정 구현 플랜

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 30_T3 §10 검증 체크리스트 9개 PARTIAL 항목을 스펙에 맞게 수정

**Architecture:** 기존 데모 모듈(21개 파일) 내부 수정 + 신규 위젯 1개 추가. 파일 간 의존성 낮아 순차 구현 가능.

**Tech Stack:** Flutter/Dart, Riverpod, connectivity_plus

**설계 문서:** `docs/plans/2026-03-07-demo-tour-fix-design.md`

---

## Task 1: 15일 툴팁 텍스트 수정 (F4)

**Files:**
- Modify: `safetrip-mobile/lib/features/demo/presentation/widgets/demo_time_slider.dart:149`

**Step 1: 툴팁 텍스트 변경**

```dart
// Line 149 — Before:
"최대 15일까지 시뮬레이션 가능합니다"
// After:
"여행은 최대 15일까지 설정 가능합니다. 분할 생성해 주세요"
```

**Step 2: Commit**

```bash
git add safetrip-mobile/lib/features/demo/presentation/widgets/demo_time_slider.dart
git commit -m "fix(demo): 15일 제한 툴팁 텍스트 스펙 정합 (§3.2, §6)"
```

---

## Task 2: 가디언 비교 라벨/버튼 수정 (F5)

**Files:**
- Modify: `safetrip-mobile/lib/features/demo/presentation/widgets/demo_guardian_compare.dart`

**Step 1: "히스토리 분석" → "히스토리 조회" 라벨 수정**

비교 테이블 6번째 항목 (lines ~82-83, ~101-102 부근):
```dart
// Before:
'히스토리 분석'
// After:
'히스토리 조회'
```

**Step 2: 업그레이드 다이얼로그 버튼 수정**

`_showUpgradeDialog()` 메서드 (line ~165-189):
- "취소" 버튼 → "실제 앱 시작하기" 버튼으로 변경
- onPressed: `Navigator.pop(context)` 후 `DemoConversionModal.show(context)` 호출

```dart
TextButton(
  onPressed: () {
    Navigator.pop(context);
    DemoConversionModal.show(context);
  },
  child: const Text('실제 앱 시작하기'),
),
```

**Step 3: import 추가**

```dart
import 'demo_conversion_modal.dart';
```

**Step 4: Commit**

```bash
git add safetrip-mobile/lib/features/demo/presentation/widgets/demo_guardian_compare.dart
git commit -m "fix(demo): 가디언 비교 라벨·업그레이드 모달 버튼 스펙 정합 (§3.3)"
```

---

## Task 3: 데모 배지 2개 화면 추가 (F1)

**Files:**
- Modify: `safetrip-mobile/lib/features/demo/presentation/screens/screen_demo_scenario_select.dart`
- Modify: `safetrip-mobile/lib/features/demo/presentation/screens/screen_demo_complete.dart`

**Step 1: screen_demo_scenario_select.dart에 DemoBadge 추가**

`build()` 메서드의 Scaffold body를 Stack으로 감싸고 DemoBadge 오버레이:
```dart
import '../widgets/demo_badge.dart';

// build() 내 body를 Stack으로 래핑:
body: Stack(
  children: [
    // 기존 body 내용 (Column/ListView 등),
    Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Center(child: DemoBadge()),
      ),
    ),
  ],
),
```

**Step 2: screen_demo_complete.dart에 DemoBadge 추가**

동일 패턴으로 Stack + Positioned DemoBadge 추가.

**Step 3: Commit**

```bash
git add safetrip-mobile/lib/features/demo/presentation/screens/screen_demo_scenario_select.dart
git add safetrip-mobile/lib/features/demo/presentation/screens/screen_demo_complete.dart
git commit -m "fix(demo): 시나리오선택·완료 화면에 데모 배지 추가 (D3)"
```

---

## Task 4: memberCount 가디언 포함 (F2)

**Files:**
- Modify: `safetrip-mobile/lib/features/demo/presentation/screens/screen_demo_scenario_select.dart`

**Step 1: _selectScenario() 내 memberCount 확인 및 수정**

`_selectScenario()` 메서드에서 `tripProvider.setCurrentTripDetails()` 호출 시:
```dart
// memberCount를 전체 멤버(가디언 포함)로 전달
memberCount: scenario.members.length,  // 가디언 포함 전체
```

가디언 수도 별도 전달 확인:
```dart
guardianCount: scenario.members.where((m) => m.role == 'guardian').length,
```

**Step 2: Commit**

```bash
git add safetrip-mobile/lib/features/demo/presentation/screens/screen_demo_scenario_select.dart
git commit -m "fix(demo): memberCount에 가디언 포함 (§3.1 S1:33, S3:18)"
```

---

## Task 5: SharedPreferences 데모 격리 (F7)

**Files:**
- Modify: `safetrip-mobile/lib/features/demo/presentation/screens/screen_demo_scenario_select.dart`
- Modify: `safetrip-mobile/lib/features/demo/presentation/widgets/demo_conversion_modal.dart`
- Modify: `safetrip-mobile/lib/features/demo/presentation/screens/screen_demo_complete.dart`

**Step 1: _selectScenario()에서 demo_ 프리픽스 적용**

```dart
// Before:
prefs.setString('user_id', captain.id);
prefs.setString('user_name', captain.name);
prefs.setString('group_id', scenario.scenarioId);
prefs.setString('user_role', 'captain');

// After:
prefs.setString('demo_user_id', captain.id);
prefs.setString('demo_user_name', captain.name);
prefs.setString('demo_group_id', scenario.scenarioId);
prefs.setString('demo_user_role', 'captain');
prefs.setBool('is_demo_mode', true);  // 이건 유지
```

**Step 2: _clearDemoState()에서 demo_ 프리픽스 키 제거**

`demo_conversion_modal.dart`와 `screen_demo_complete.dart` 양쪽 모두:
```dart
// Before:
prefs.remove('user_id');
prefs.remove('user_name');
// After:
prefs.remove('demo_user_id');
prefs.remove('demo_user_name');
prefs.remove('demo_group_id');
prefs.remove('demo_user_role');
prefs.remove('is_demo_mode');
```

**Step 3: 데모 모드에서 demo_ 키 참조 확인**

데모 중 `user_id` 를 직접 참조하는 코드가 있는지 검색 후 `demo_user_id`로 변경.

**Step 4: Commit**

```bash
git add safetrip-mobile/lib/features/demo/presentation/screens/screen_demo_scenario_select.dart
git add safetrip-mobile/lib/features/demo/presentation/widgets/demo_conversion_modal.dart
git add safetrip-mobile/lib/features/demo/presentation/screens/screen_demo_complete.dart
git commit -m "fix(demo): SharedPreferences 키에 demo_ 프리픽스로 격리 (D4)"
```

---

## Task 6: 전환 CTA 오프라인 가드 (F8)

**Files:**
- Modify: `safetrip-mobile/lib/features/demo/presentation/widgets/demo_conversion_modal.dart`
- Modify: `safetrip-mobile/lib/features/demo/presentation/screens/screen_demo_complete.dart`

**Step 1: demo_conversion_modal.dart에 connectivity 체크 추가**

ConsumerWidget → ConsumerStatefulWidget 변환 또는 FutureBuilder 사용:
```dart
import 'package:connectivity_plus/connectivity_plus.dart';

// build() 내부:
final connectivityResult = await Connectivity().checkConnectivity();
final isOffline = connectivityResult == ConnectivityResult.none;

// "여행 만들기" 버튼:
ElevatedButton(
  onPressed: isOffline ? null : () => _exitAndNavigate(context, ref, RoutePaths.authPhone),
  child: Text('여행 만들기'),
),

// "초대코드로 참여" 버튼:
OutlinedButton(
  onPressed: isOffline ? null : () => _exitAndNavigate(context, ref, RoutePaths.tripJoin),
  child: Text('초대코드로 참여'),
),

// 오프라인 안내 텍스트:
if (isOffline)
  Padding(
    padding: EdgeInsets.only(top: 8),
    child: Text(
      '온라인 연결 후 이용 가능합니다',
      style: AppTypography.bodySmall.copyWith(color: AppColors.textWarning),
    ),
  ),
```

**Step 2: screen_demo_complete.dart에 동일 패턴 적용**

**Step 3: Commit**

```bash
git add safetrip-mobile/lib/features/demo/presentation/widgets/demo_conversion_modal.dart
git add safetrip-mobile/lib/features/demo/presentation/screens/screen_demo_complete.dart
git commit -m "fix(demo): 전환 CTA 오프라인 시 비활성 + 안내 (§8)"
```

---

## Task 7: canAccess() UI 잠금 오버레이 (F3)

**Files:**
- Create: `safetrip-mobile/lib/features/demo/presentation/widgets/demo_lock_overlay.dart`
- Modify: `safetrip-mobile/lib/features/demo/presentation/widgets/demo_mode_wrapper.dart`

**Step 1: DemoLockOverlay 위젯 생성**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../providers/demo_state_provider.dart';

class DemoLockOverlay extends ConsumerWidget {
  const DemoLockOverlay({
    super.key,
    required this.feature,
    required this.child,
    this.message,
  });

  final String feature;
  final Widget child;
  final String? message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final demoState = ref.watch(demoStateProvider);
    if (!demoState.isActive || demoState.canAccess(feature)) {
      return child;
    }
    return Stack(
      children: [
        Opacity(opacity: 0.3, child: IgnorePointer(child: child)),
        Positioned.fill(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock, size: 32, color: AppColors.textTertiary),
                if (message != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    message!,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textTertiary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
```

**Step 2: demo_mode_wrapper.dart에 잠금 오버레이 적용**

`_GuardianCompareButton`을 `DemoLockOverlay(feature: 'guardian_billing', ...)` 로 래핑.

**Step 3: 하단 네비게이션 탭에도 적용**

가디언 역할일 때 채팅 탭은 이미 `if (!isGuardian)` 조건으로 숨겨져 있으므로 별도 잠금 불필요.
→ 단, 가디언 역할에서 멤버 탭 접근 시 잠금 처리 필요.

**Step 4: Commit**

```bash
git add safetrip-mobile/lib/features/demo/presentation/widgets/demo_lock_overlay.dart
git add safetrip-mobile/lib/features/demo/presentation/widgets/demo_mode_wrapper.dart
git commit -m "feat(demo): 역할별 기능 잠금 오버레이 UI (§3.4 canAccess)"
```

---

## Task 8: 등급 비교 3열 레이아웃 (F6)

**Files:**
- Modify: `safetrip-mobile/lib/features/demo/presentation/widgets/demo_grade_compare.dart`

**Step 1: 전면 재작성 — 3열 비교 테이블**

기존 탭 기반 UI를 제거하고 3열 나란히 비교 테이블로 교체:
- 헤더 행: 3열 (안전 최우선 / 표준 / 프라이버시 우선) + 현재 선택 "현재" 뱃지
- 비교 행 5개: §5 프라이버시 등급별 동작 차이 테이블 기준
  1. 위치 공유 범위: "24시간 실시간" / "24시간" / "일정 연동만"
  2. 가디언 공유: "항상 공유" / "ON시 실시간" / "OFF시 비공유"
  3. 마커 표시: "실시간 갱신" / "실시간 갱신" / "체크포인트만"
  4. 가디언 일시중지: "불가" / "최대 12시간" / "최대 24시간"
  5. 지오펜스→가디언: "항상" / "ON시만" / "전달 안 함"
- 헤더 탭 시 `switchGrade()` 호출 (기존 로직 유지)
- 현재 선택 컬럼 배경색 강조

**Step 2: Commit**

```bash
git add safetrip-mobile/lib/features/demo/presentation/widgets/demo_grade_compare.dart
git commit -m "fix(demo): 등급 비교 3열 나란히 레이아웃으로 재작성 (§3.5)"
```

---

## Task 9: 코치마크 체이닝 트리거 + 화살표 (F9)

**Files:**
- Modify: `safetrip-mobile/lib/features/demo/presentation/widgets/demo_coachmark.dart`
- Modify: `safetrip-mobile/lib/features/demo/presentation/widgets/demo_mode_wrapper.dart`

**Step 1: 코치마크 화살표 삼각형 추가**

`demo_coachmark.dart`에 `_ArrowPainter` CustomPainter 추가:
```dart
class _ArrowPainter extends CustomPainter {
  _ArrowPainter({required this.direction, required this.color});
  final ArrowDirection direction;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path();
    switch (direction) {
      case ArrowDirection.up:
        path.moveTo(0, size.height);
        path.lineTo(size.width / 2, 0);
        path.lineTo(size.width, size.height);
      case ArrowDirection.down:
        path.moveTo(0, 0);
        path.lineTo(size.width / 2, size.height);
        path.lineTo(size.width, 0);
      case ArrowDirection.left:
        path.moveTo(size.width, 0);
        path.lineTo(0, size.height / 2);
        path.lineTo(size.width, size.height);
      case ArrowDirection.right:
        path.moveTo(0, 0);
        path.lineTo(size.width, size.height / 2);
        path.lineTo(0, size.height);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
```

`DemoCoachmarkOverlay.build()` 내 툴팁 컨테이너에 화살표 위젯 배치.

**Step 2: 코치마크 체이닝 트리거**

`demo_mode_wrapper.dart`의 `_showCoachmark()` onDismiss 콜백에서 다음 미조회 코치마크 자동 표시:

```dart
void _showNextCoachmark(int currentIndex) {
  final state = ref.read(demoStateProvider);
  for (int i = currentIndex + 1; i < kDemoCoachmarks.length; i++) {
    if (!state.viewedCoachmarks.contains(kDemoCoachmarks[i].id)) {
      _showCoachmarkByIndex(i);
      return;
    }
  }
}
```

`_showCoachmark()` 호출 시 onDismiss에 `_showNextCoachmark(index)` 연결.

각 코치마크의 `targetRect` 계산은 GlobalKey를 사용하여 해당 위젯의 화면 위치를 가져옴.

**Step 3: Commit**

```bash
git add safetrip-mobile/lib/features/demo/presentation/widgets/demo_coachmark.dart
git add safetrip-mobile/lib/features/demo/presentation/widgets/demo_mode_wrapper.dart
git commit -m "fix(demo): 코치마크 체이닝 트리거 + 화살표 삼각형 (§3.7)"
```

---

## 최종 검증

모든 Task 완료 후 §10 체크리스트 12항목 재검증:
1. ✅ 데모 배지 모든 화면 (F1)
2. ✅ 서버 API 미호출 (기존 PASS)
3. ✅ 3개 시나리오 + memberCount (F2)
4. ✅ 역할 전환 + canAccess UI (F3)
5. ✅ 15일 제한 텍스트 (F4)
6. ✅ 가디언 과금 체험 (F5)
7. ✅ 등급 비교 3열 (F6)
8. ✅ 전환 유도 모달 (기존 PASS)
9. ✅ 실제 데이터 격리 (F7)
10. ✅ 오프라인 대응 (F8)
11. ✅ 거버넌스 참조 (기존 PASS)
12. ✅ 코치마크 첫 방문 + 체이닝 (F9)
