# 데모 투어 체험(30_T3) 스펙 정합 수정 설계

> **검증 기준**: `Master_docs/30_T3_데모_투어_체험_원칙.md` v2.1, §10 체크리스트 12항목
> **검증 결과**: 3 PASS / 9 PARTIAL → 9건 전체 수정

---

## 수정 대상 9건 요약

| # | 체크리스트 | 파일 | 수정 내용 |
|---|----------|------|----------|
| F1 | #1 데모 배지 | `screen_demo_scenario_select.dart`, `screen_demo_complete.dart` | 두 화면에 DemoBadge 위젯 추가 |
| F2 | #3 memberCount | `screen_demo_scenario_select.dart` | 카드 멤버 수에 가디언 포함 (S1: 33, S3: 18) |
| F3 | #4 canAccess() UI 적용 | `demo_mode_wrapper.dart`, 각 탭 위젯 | 잠긴 기능에 🔒 + 그레이아웃 오버레이 |
| F4 | #5 15일 툴팁 텍스트 | `demo_time_slider.dart` | "여행은 최대 15일까지 설정 가능합니다. 분할 생성해 주세요" |
| F5 | #6 가디언 업그레이드 모달 | `demo_guardian_compare.dart` | "실제 앱 시작하기" 버튼 추가, "히스토리 분석" → "히스토리 조회" |
| F6 | #7 등급 비교 3열 레이아웃 | `demo_grade_compare.dart` | 탭 방식 → 3열 나란히 비교 테이블 |
| F7 | #9 Riverpod 격리 | `demo_state_provider.dart`, `screen_demo_scenario_select.dart` | SharedPreferences 키에 demo_ 프리픽스 |
| F8 | #10 오프라인 가드 | `demo_conversion_modal.dart`, `screen_demo_complete.dart` | 전환 CTA에 connectivity 체크 + 비활성 처리 |
| F9 | #12 코치마크 트리거 + 화살표 | `demo_mode_wrapper.dart`, `demo_coachmark.dart` | #2~#6 트리거 경로 추가, 화살표 삼각형 CustomPaint |

---

## F1. 데모 배지 — 2개 화면 추가 (D3)

**스펙**: "모든 화면 상단에 '데모 모드' 배지를 항상 표시" (§2 D3)

**현상**: `ScreenDemoScenarioSelect`와 `ScreenDemoComplete`는 `DemoModeWrapper` 밖에 있어 배지 미표시.

**수정**:
- 두 화면의 `Scaffold.body` 최상위를 `Stack`으로 감싸고 `DemoBadge` 위젯을 오버레이 추가.
- `DemoBadge`는 이미 `demo_badge.dart`에 독립 위젯으로 존재하므로 import만 추가.

```dart
// screen_demo_scenario_select.dart — build() 내부
Stack(
  children: [
    // 기존 Scaffold body 내용
    ...,
    const Positioned(
      top: 0, left: 0, right: 0,
      child: SafeArea(child: Center(child: DemoBadge())),
    ),
  ],
)
```

`screen_demo_complete.dart`도 동일 패턴.

---

## F2. memberCount 가디언 포함 (§3.1)

**스펙**: S1 = "캡틴 1 + 크루장 2 + 크루 20 + 가디언 10" = **33명**

**현상**: `screen_demo_scenario_select.dart` 카드에 하드코딩: S1 `Members: 33`, S2 `Members: 6`, S3 `Members: 18`.
→ 실제 확인 결과 이미 정확한 숫자가 하드코딩되어 있음. 하지만 `_selectScenario()`에서 `tripProvider.setCurrentTripDetails()`에 전달하는 `memberCount`가 가디언 제외 가능성 확인 필요.

**수정**:
- `_selectScenario()` 내 `memberCount` 계산 시 `scenario.members.length` (전체) 사용.
- JSON의 `members` 배열에 가디언 포함되어 있으므로 `.length`로 총원 반영.

---

## F3. canAccess() UI 적용 — 잠금 아이콘 (§3.4)

**스펙**: "해당 역할에서 접근 불가한 기능은 자물쇠 아이콘(🔒) + 그레이아웃 처리" (§3.4)

**현상**: `canAccess()` 메서드는 `DemoState`에 구현되어 있으나, UI 위젯에서 한 번도 호출하지 않음.

**수정 접근법**: `DemoModeWrapper`에 역할 기반 잠금 오버레이 헬퍼 위젯 `DemoLockOverlay`를 추가.

```dart
class DemoLockOverlay extends ConsumerWidget {
  const DemoLockOverlay({
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
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock, size: 32, color: AppColors.textTertiary),
              if (message != null)
                Text(message!, style: AppTypography.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}
```

**적용 위치** (§4 매트릭스 기준):
- 가디언 과금 체험 버튼 (`_GuardianCompareButton`): `feature: 'guardian_billing'`
- SOS 버튼: `feature: 'sos'`
- 채팅 탭 (bottom nav): `feature: 'chat'`
- 멤버 탭: `feature: 'member_tab'`

---

## F4. 15일 툴팁 텍스트 수정 (§3.2)

**스펙 §6**: "여행은 최대 15일까지 설정 가능합니다. 분할 생성해 주세요"

**현상**: 현재 텍스트 = "최대 15일까지 시뮬레이션 가능합니다" (접두사 "여행은" 누락, "분할 생성해 주세요" 누락)

**수정**: `demo_time_slider.dart` 라인 149:
```dart
// Before:
"최대 15일까지 시뮬레이션 가능합니다"
// After:
"여행은 최대 15일까지 설정 가능합니다. 분할 생성해 주세요"
```

---

## F5. 가디언 업그레이드 모달 수정 (§3.3)

**스펙 §3.3**: 안내 모달에 `[계속 체험하기]  [실제 앱 시작하기]` 2개 버튼. "히스토리 조회" 라벨.

**현상**:
1. 업그레이드 다이얼로그에 "실제 앱 시작하기" 버튼 없음 ("취소"와 "계속 체험하기"만)
2. 비교 테이블에 "히스토리 분석"으로 표기 (스펙은 "히스토리 조회")

**수정**:
- `demo_guardian_compare.dart` 업그레이드 다이얼로그:
  - "취소" → "실제 앱 시작하기" (DemoConversionModal.show() 호출)
  - "계속 체험하기" 유지
- 비교 테이블 6번째 항목: "히스토리 분석" → "히스토리 조회"

---

## F6. 등급 비교 3열 나란히 레이아웃 (§3.5)

**스펙 §3.5**:
```
[안전 최우선]    [표준]    [프라이버시 우선]
     ↑
   현재 선택
```
+ 5개 차이 항목을 3열로 나란히 비교

**현상**: 탭 전환 방식으로 한 번에 1등급만 표시.

**수정**: `demo_grade_compare.dart` 전면 재작성.
- 5개 비교 행 × 4열 (항목명 + 3등급) 테이블
- 현재 선택 등급 컬럼 강조 (배경색 + 상단 "현재" 뱃지)
- 탭은 제거하고 3열 헤더 + 비교 행 레이아웃

```
┌────────────────┬──────────────┬──────────────┬──────────────┐
│                │ 안전 최우선   │    표준       │ 프라이버시   │
│                │   [현재]     │              │    우선       │
├────────────────┼──────────────┼──────────────┼──────────────┤
│ 위치 공유 범위  │ 24시간 실시간 │ 24시간       │ 일정 연동만   │
│ 가디언 공유     │ 항상 공유     │ ON시 실시간   │ OFF시 비공유  │
│ 마커 표시       │ 실시간 갱신   │ 실시간 갱신   │ 체크포인트만  │
│ 가디언 일시중지  │ 불가         │ 최대 12시간   │ 최대 24시간   │
│ 지오펜스→가디언  │ 항상         │ ON시만        │ 전달 안 함    │
└────────────────┴──────────────┴──────────────┴──────────────┘
```

---

## F7. SharedPreferences 데모 격리 (D4)

**스펙**: "실제 계정·데이터·결제 정보와 완전히 격리" (D4)

**현상**: `_selectScenario()`에서 SharedPreferences에 `user_id`, `user_name` 등을 데모 프리픽스 없이 직접 저장 → 실제 앱 데이터 오염 가능.

**수정**:
- `screen_demo_scenario_select.dart`에서 SharedPreferences 키에 `demo_` 프리픽스:
  ```dart
  prefs.setString('demo_user_id', captain.id);
  prefs.setString('demo_user_name', captain.name);
  // 기존 user_id / user_name 은 건드리지 않음
  ```
- `_clearDemoState()`에서도 `demo_` 프리픽스 키 제거.
- 데모 모드에서 user_id 참조하는 코드 → `demo_user_id` 사용하도록 변경.

---

## F8. 전환 CTA 오프라인 가드 (§8)

**스펙 §8**: "온라인 필요 기능 → '온라인 연결 후 이용 가능합니다' 안내 + 버튼 비활성"

**현상**: `DemoConversionModal`과 `ScreenDemoComplete`의 "여행 만들기", "초대코드로 참여" 버튼에 네트워크 체크 없음.

**수정**:
- `connectivity_plus` 패키지로 현재 연결 상태 확인.
- 오프라인 시 두 CTA 버튼 비활성 + 안내 텍스트 표시:
  ```dart
  final isOffline = connectivityResult == ConnectivityResult.none;

  ElevatedButton(
    onPressed: isOffline ? null : () => _exitAndNavigate(...),
    child: Text('여행 만들기'),
  ),
  if (isOffline)
    Text('온라인 연결 후 이용 가능합니다',
      style: AppTypography.bodySmall.copyWith(color: AppColors.textWarning)),
  ```

---

## F9. 코치마크 트리거 + 화살표 (§3.7)

### F9-A. 코치마크 #2~#6 트리거 경로

**스펙**: "처음 방문하는 기능 화면 진입 시 자동 표시"

**현상**: `_startEventSimulator()`에서 #1(map_tab)만 1초 후 자동 트리거. #2~#6은 트리거 경로 없음.

**수정**: `DemoModeWrapper.build()` 내 각 위젯에 첫 표시 로직 추가.

| 코치마크 | 트리거 위치 | 트리거 조건 |
|---------|-----------|-----------|
| #1 map_tab | `_startEventSimulator()` | 데모 시작 1초 후 (기존) |
| #2 role_panel | `DemoRolePanel` | 위젯 첫 빌드 시 |
| #3 guardian_compare | `_GuardianCompareButton` | 위젯 첫 빌드 시 + 딜레이 |
| #4 time_slider | `DemoTimeSlider` | 위젯 첫 빌드 시 + 딜레이 |
| #5 sos_button | 메인 화면 SOS 버튼 | 데모 모드 SOS 버튼 첫 노출 시 |
| #6 grade_compare | `_GradeCompareButton` | 위젯 첫 빌드 시 + 딜레이 |

구현 접근: 각 위젯에서 `ref.read(demoStateProvider).viewedCoachmarks.contains(id)` 체크 후, 미조회 시 `WidgetsBinding.instance.addPostFrameCallback`으로 코치마크 표시.
→ 순차 표시를 위해 #1 dismiss 시 #2 표시, #2 dismiss 시 #3 표시... 체이닝 방식 적용.

### F9-B. 화살표 삼각형

**스펙**: "말풍선(Tooltip) 스타일, 포인팅 화살표 포함" (§3.7)

**현상**: `arrowDirection` enum만 저장, 실제 화살표 미렌더링.

**수정**: `DemoCoachmarkOverlay.build()`에서 `CustomPaint`로 삼각형 화살표 추가.

```dart
// 툴팁 컨테이너 아래/위에 삼각형 추가
CustomPaint(
  size: Size(16, 8),
  painter: _ArrowPainter(
    direction: coachmark.arrowDirection,
    color: AppColors.surface,
  ),
)
```

`_ArrowPainter`: `Path.moveTo` → `lineTo` → `close` → `canvas.drawPath`로 삼각형 렌더링.

---

## 수정 순서

1. F4 (텍스트 1줄) → F5 (라벨/버튼) → F2 (memberCount) — 단순 텍스트/값 수정
2. F1 (배지 추가) → F7 (프리픽스) → F8 (오프라인 가드) — 소규모 로직 추가
3. F3 (canAccess UI) → F6 (3열 레이아웃) → F9 (코치마크) — 구조 변경

---

## 영향 범위

| 파일 | 수정 유형 |
|------|----------|
| `demo_time_slider.dart` | 텍스트 수정 (F4) |
| `demo_guardian_compare.dart` | 버튼/라벨 수정 (F5) |
| `screen_demo_scenario_select.dart` | 배지 추가(F1), memberCount(F2), 프리픽스(F7) |
| `screen_demo_complete.dart` | 배지 추가(F1), 오프라인 가드(F8) |
| `demo_conversion_modal.dart` | 오프라인 가드(F8) |
| `demo_grade_compare.dart` | 3열 전면 재작성(F6) |
| `demo_state_provider.dart` | 프리픽스 참조(F7) |
| `demo_mode_wrapper.dart` | canAccess UI(F3), 코치마크 체이닝(F9) |
| `demo_coachmark.dart` | 화살표 삼각형(F9) |
| **신규**: `demo_lock_overlay.dart` | 잠금 오버레이 위젯(F3) |
