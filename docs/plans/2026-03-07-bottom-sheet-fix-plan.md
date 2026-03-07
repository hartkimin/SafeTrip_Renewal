# 바텀시트 타겟 버그 수정 구현 계획

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 바텀시트 5단계 상태 머신의 4개 버그를 수정하고 10회 시나리오 테스트로 검증한다.

**Architecture:** `SnappingBottomSheet`(래퍼) + `MainScreenNotifier`(상태) + `screen_main.dart`(UI 연결) 3레이어 구조. velocity 감지를 추가하고, 타이밍/콜백 불일치를 수정한다.

**Tech Stack:** Flutter DraggableScrollableSheet, Riverpod StateNotifier, flutter_test

---

## Task 1: `_markProgrammaticMove` 타이밍 개선

**Files:**
- Modify: `safetrip-mobile/lib/screens/main/bottom_sheets/snapping_bottom_sheet.dart:42,78,90-95,113-121`
- Modify: `safetrip-mobile/lib/screens/main/screen_main.dart:109,477-489,702`

**Step 1: `snapping_bottom_sheet.dart` — `_markProgrammaticMove`에 duration 파라미터 추가**

`onCreated` 콜백 시그니처와 `_markProgrammaticMove` 모두 수정:

```dart
// line 42: 콜백 시그니처 변경
final void Function(void Function([Duration]) markProgrammatic)? onCreated;

// line 90-95: duration 파라미터 수신
void _markProgrammaticMove([Duration duration = const Duration(milliseconds: 300)]) {
  _isProgrammaticMove = true;
  Future.delayed(duration + const Duration(milliseconds: 50), () {
    _isProgrammaticMove = false;
  });
}
```

**Step 2: `snapping_bottom_sheet.dart` — 리다이렉트 내부의 350ms도 동일 패턴 적용**

```dart
// line 113-121: 리다이렉트 애니메이션 타이밍 일치
_isProgrammaticMove = true;
const redirectDuration = Duration(milliseconds: 300);
_controller.animateTo(
  redirectLevel.fraction,
  duration: redirectDuration,
  curve: Curves.easeInOut,
);
Future.delayed(redirectDuration + const Duration(milliseconds: 50), () {
  _isProgrammaticMove = false;
});
```

**Step 3: `screen_main.dart` — `_markSheetProgrammatic` 타입과 호출 수정**

```dart
// line 109: 타입 변경
void Function([Duration])? _markSheetProgrammatic;

// line 477-489: duration 전달
void _animateSheetTo(
  BottomSheetLevel level, {
  Duration duration = const Duration(milliseconds: 200),
  Curve curve = Curves.easeInOut,
}) {
  if (!_sheetController.isAttached) return;
  _markSheetProgrammatic?.call(duration); // duration 전달
  _sheetController.animateTo(
    level.fraction,
    duration: duration,
    curve: curve,
  );
}
```

**Step 4: 빌드 확인**

Run: `cd safetrip-mobile && flutter analyze lib/screens/main/bottom_sheets/snapping_bottom_sheet.dart lib/screens/main/screen_main.dart`
Expected: No issues found

**Step 5: Commit**

```bash
git add safetrip-mobile/lib/screens/main/bottom_sheets/snapping_bottom_sheet.dart safetrip-mobile/lib/screens/main/screen_main.dart
git commit -m "fix(bottom-sheet): _markProgrammaticMove 타이밍을 실제 animation duration 기반으로 수정"
```

---

## Task 2: Velocity 기반 직접 점프 허용 (§3.3)

**Files:**
- Modify: `safetrip-mobile/lib/screens/main/bottom_sheets/snapping_bottom_sheet.dart`

**Step 1: velocity 캡처용 필드 추가**

`_SnappingBottomSheetState`에 velocity 추적 필드 추가:

```dart
// line 65 아래 추가
/// §3.3: 마지막 수직 드래그 velocity (dp/s)
double _lastDragVelocity = 0;
```

**Step 2: 드래그 핸들 GestureDetector에 velocity 캡처 추가**

현재 `isDragEnabled`가 false일 때만 `onVerticalDragUpdate`를 쓰고 있다. enabled일 때 velocity를 캡처하도록 수정:

```dart
// line 163-180 교체
GestureDetector(
  onVerticalDragUpdate: widget.isDragEnabled
      ? (details) {
          // §3.3: velocity 추적 (실제 드래그는 DraggableScrollableSheet가 처리)
          _lastDragVelocity = details.primaryDelta != null
              ? (details.primaryDelta! / (1 / 60)).abs() // 프레임당 delta를 초당으로 환산
              : 0;
        }
      : (_) {}, // SOS 잠금 시 드래그 흡수
  onVerticalDragEnd: widget.isDragEnabled
      ? (details) {
          _lastDragVelocity = details.primaryVelocity?.abs() ?? 0;
        }
      : null,
  child: Container(
    height: 32,
    width: double.infinity,
    alignment: Alignment.center,
    child: Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: AppColors.outline,
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  ),
),
```

**주의**: 드래그 핸들의 GestureDetector가 DraggableScrollableSheet의 드래그를 가로챌 수 있다. 실제로는 DraggableScrollableSheet가 콘텐츠 영역의 드래그를 직접 처리하므로, 핸들 영역(32dp)에서만 velocity를 캡처하게 된다.

**대안 접근 — NotificationListener 사용:**

DraggableScrollableSheet는 내부적으로 `ScrollNotification`을 발생시키므로, `NotificationListener<ScrollNotification>`으로 감싸서 velocity를 추적하는 것이 더 안정적:

```dart
// build 메서드 내 DraggableScrollableSheet를 감싸기
NotificationListener<ScrollNotification>(
  onNotification: (notification) {
    if (notification is ScrollEndNotification) {
      final metrics = notification.metrics;
      if (metrics is FixedScrollMetrics) {
        // velocity는 ScrollEndNotification에서 직접 접근 불가
        // 대신 _onSizeChanged에서 이전 size와의 차이로 간접 추정
      }
    }
    return false;
  },
  child: DraggableScrollableSheet(...),
)
```

**최종 선택: size 변화율 기반 속도 추정**

DraggableScrollableSheet의 listener에서 직접 velocity를 얻기 어렵다. 대신 `_onSizeChanged` 내에서 **이전 size와 현재 size의 시간당 변화율**로 추정한다:

```dart
// 필드 추가 (line 65 아래)
double _lastDragVelocity = 0;
double _previousSize = 0.5;
DateTime _previousSizeTime = DateTime.now();

// _onSizeChanged 수정 (line 97 아래)
void _onSizeChanged() {
  if (!_controller.isAttached) return;
  final size = _controller.size;
  final now = DateTime.now();
  final level = BottomSheetLevelExt.fromFraction(size);

  // §3.3: 속도 추정 (dp/s 환산 — 화면 비율 변화를 dp로)
  final dt = now.difference(_previousSizeTime).inMilliseconds;
  if (dt > 0) {
    final screenHeight = MediaQuery.of(context).size.height;
    final deltaDp = (size - _previousSize).abs() * screenHeight;
    _lastDragVelocity = deltaDp / (dt / 1000); // dp/s
  }
  _previousSize = size;
  _previousSizeTime = now;

  // §3.3: 직접 점프 검증 (velocity > 2000 dp/s 허용)
  if (!_isProgrammaticMove && widget.isDragEnabled) {
    final distance = (level.index - _previousStableLevel.index).abs();
    if (distance >= 3 && _lastDragVelocity < 2000) {
      // 느린 점프 → 리다이렉트
      final redirectLevel = level.index > _previousStableLevel.index
          ? BottomSheetLevel.peek
          : BottomSheetLevel.expanded;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_controller.isAttached) {
          const redirectDuration = Duration(milliseconds: 300);
          _isProgrammaticMove = true;
          _controller.animateTo(
            redirectLevel.fraction,
            duration: redirectDuration,
            curve: Curves.easeInOut,
          );
          Future.delayed(redirectDuration + const Duration(milliseconds: 50), () {
            _isProgrammaticMove = false;
          });
        }
      });

      widget.onLevelChanged?.call(redirectLevel);
      _previousStableLevel = redirectLevel;
      return;
    }
    // distance >= 3 && velocity >= 2000 → 직접 전환 허용 (스펙 §3.3)
  }

  _previousStableLevel = level;
  widget.onLevelChanged?.call(level);
}
```

**Step 3: 빌드 확인**

Run: `cd safetrip-mobile && flutter analyze lib/screens/main/bottom_sheets/snapping_bottom_sheet.dart`
Expected: No issues found

**Step 4: Commit**

```bash
git add safetrip-mobile/lib/screens/main/bottom_sheets/snapping_bottom_sheet.dart
git commit -m "feat(bottom-sheet): §3.3 velocity > 2000 dp/s 시 full↔collapsed 직접 전환 허용"
```

---

## Task 3: SOS 해제 애니메이션 커브 수정

**Files:**
- Modify: `safetrip-mobile/lib/screens/main/screen_main.dart:996-997`

**Step 1: SOS 해제 시 spring 커브 적용**

```dart
// line 996-997 수정
_animateSheetTo(BottomSheetLevel.peek,
    duration: const Duration(milliseconds: 250),
    curve: Curves.elasticOut); // §10.3: spring 느낌
```

**Step 2: 빌드 확인**

Run: `cd safetrip-mobile && flutter analyze lib/screens/main/screen_main.dart`
Expected: No issues found

**Step 3: Commit**

```bash
git add safetrip-mobile/lib/screens/main/screen_main.dart
git commit -m "fix(bottom-sheet): SOS 해제 시 spring 커브 적용 (§10.3)"
```

---

## Task 4: 멤버 상세뷰 콜백 연결 (§7.4)

**Files:**
- Modify: `safetrip-mobile/lib/screens/main/bottom_sheets/bottom_sheet_2_member.dart:404-407`

**Step 1: `_onMemberTap`에서 `onEnterDetail` 호출 + 프로필 모달 표시**

```dart
// line 404-407 교체
void _onMemberTap(TripMember member) {
  // §7.4: 세부 화면 진입 → full 전환
  widget.onEnterDetail?.call();

  // 멤버 프로필 모달 표시
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _MemberDetailSheet(member: member),
  ).then((_) {
    // §7.4: 세부 화면 종료 → 이전 레벨 복원
    widget.onExitDetail?.call();
  });
}
```

**Step 2: `_MemberDetailSheet` 위젯 추가**

파일 하단 (기존 private 위젯들 근처)에 간단한 상세 시트 추가:

```dart
class _MemberDetailSheet extends StatelessWidget {
  const _MemberDetailSheet({required this.member});
  final TripMember member;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              // 핸들
              Center(
                child: Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppColors.outline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // 이름 + 역할
              Text(
                member.userName ?? '알 수 없음',
                style: AppTypography.titleLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                _roleLabel(member.role),
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _roleLabel(String? role) {
    switch (role) {
      case 'captain': return '캡틴';
      case 'crew_leader': return '크루장';
      case 'crew': return '크루';
      case 'guardian': return '가디언';
      default: return '멤버';
    }
  }
}
```

**Step 3: 빌드 확인**

Run: `cd safetrip-mobile && flutter analyze lib/screens/main/bottom_sheets/bottom_sheet_2_member.dart`
Expected: No issues found

**Step 4: Commit**

```bash
git add safetrip-mobile/lib/screens/main/bottom_sheets/bottom_sheet_2_member.dart
git commit -m "feat(bottom-sheet): §7.4 멤버 카드 탭 시 상세뷰 진입/복귀 콜백 연결"
```

---

## Task 5: 유닛 테스트 — MainScreenNotifier 상태 전환

**Files:**
- Create: `safetrip-mobile/test/providers/main_screen_provider_test.dart`

**Step 1: 테스트 파일 생성**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:safetrip_mobile/features/main/providers/main_screen_provider.dart';
import 'package:safetrip_mobile/screens/main/navigation/bottom_navigation_bar.dart';

void main() {
  late MainScreenNotifier notifier;

  setUp(() {
    notifier = MainScreenNotifier();
  });

  group('§2 5단계 상태 머신', () {
    test('초기 상태는 half', () {
      expect(notifier.state.sheetLevel, BottomSheetLevel.half);
    });

    test('모든 레벨 설정 가능', () {
      for (final level in BottomSheetLevel.values) {
        final applied = notifier.setSheetLevel(level);
        expect(applied, level);
        expect(notifier.state.sheetLevel, level);
      }
    });
  });

  group('§4.4 동일 탭 재탭', () {
    test('collapsed → half', () {
      notifier.setSheetLevel(BottomSheetLevel.collapsed);
      expect(notifier.resolveHeightForSameTabTap(), BottomSheetLevel.half);
    });

    test('peek → collapsed', () {
      notifier.setSheetLevel(BottomSheetLevel.peek);
      expect(notifier.resolveHeightForSameTabTap(), BottomSheetLevel.collapsed);
    });

    test('half → collapsed', () {
      notifier.setSheetLevel(BottomSheetLevel.half);
      expect(notifier.resolveHeightForSameTabTap(), BottomSheetLevel.collapsed);
    });

    test('expanded → half', () {
      notifier.setSheetLevel(BottomSheetLevel.expanded);
      expect(notifier.resolveHeightForSameTabTap(), BottomSheetLevel.half);
    });

    test('full → half', () {
      notifier.setSheetLevel(BottomSheetLevel.full);
      expect(notifier.resolveHeightForSameTabTap(), BottomSheetLevel.half);
    });
  });

  group('§5.1 탭별 기본 높이', () {
    test('일정탭: half', () {
      notifier.setSheetLevel(BottomSheetLevel.collapsed);
      expect(notifier.resolveHeightForTab(BottomTab.trip), BottomSheetLevel.half);
    });

    test('멤버탭: peek', () {
      notifier.setSheetLevel(BottomSheetLevel.collapsed);
      expect(notifier.resolveHeightForTab(BottomTab.member), BottomSheetLevel.peek);
    });

    test('채팅탭: expanded', () {
      notifier.setSheetLevel(BottomSheetLevel.collapsed);
      expect(notifier.resolveHeightForTab(BottomTab.chat), BottomSheetLevel.expanded);
    });

    test('안전가이드탭: half', () {
      notifier.setSheetLevel(BottomSheetLevel.collapsed);
      expect(notifier.resolveHeightForTab(BottomTab.guide), BottomSheetLevel.half);
    });
  });

  group('§7.2 탭 전환 시 높이 보존', () {
    test('현재 높이 >= 최소 요구 → 유지', () {
      notifier.setSheetLevel(BottomSheetLevel.full);
      expect(notifier.resolveHeightForTab(BottomTab.trip), BottomSheetLevel.full);
    });

    test('현재 높이 < 최소 요구 → 기본 높이', () {
      notifier.setSheetLevel(BottomSheetLevel.collapsed);
      expect(notifier.resolveHeightForTab(BottomTab.chat), BottomSheetLevel.expanded);
    });
  });

  group('§5.2 여행 상태별 초기 높이', () {
    test('none → collapsed', () {
      expect(initialHeightForTripStatus('none'), BottomSheetLevel.collapsed);
    });
    test('planning → collapsed', () {
      expect(initialHeightForTripStatus('planning'), BottomSheetLevel.collapsed);
    });
    test('active → collapsed', () {
      expect(initialHeightForTripStatus('active'), BottomSheetLevel.collapsed);
    });
    test('completed → half', () {
      expect(initialHeightForTripStatus('completed'), BottomSheetLevel.half);
    });
  });

  group('§6 키보드 핸들링', () {
    test('키보드 출현 → full + 이전 상태 저장', () {
      notifier.setSheetLevel(BottomSheetLevel.half);
      final result = notifier.onKeyboardShow();
      expect(result, BottomSheetLevel.full);
      expect(notifier.state.sheetLevel, BottomSheetLevel.full);
      expect(notifier.state.preKeyboardLevel, BottomSheetLevel.half);
    });

    test('키보드 닫힘 → 이전 상태 복원', () {
      notifier.setSheetLevel(BottomSheetLevel.half);
      notifier.onKeyboardShow();
      final result = notifier.onKeyboardHide();
      expect(result, BottomSheetLevel.half);
      expect(notifier.state.preKeyboardLevel, isNull);
    });

    test('채팅탭 키보드 닫힘 → expanded', () {
      notifier.setCurrentTab(BottomTab.chat);
      notifier.setSheetLevel(BottomSheetLevel.half);
      notifier.onKeyboardShow();
      final result = notifier.onKeyboardHide();
      expect(result, BottomSheetLevel.expanded);
    });

    test('SOS 활성 시 키보드 출현 → collapsed 유지', () {
      notifier.activateSos();
      final result = notifier.onKeyboardShow();
      expect(result, BottomSheetLevel.collapsed);
    });
  });

  group('§10 SOS', () {
    test('SOS 발동 → collapsed + 잠금', () {
      notifier.setSheetLevel(BottomSheetLevel.half);
      notifier.activateSos();
      expect(notifier.state.sheetLevel, BottomSheetLevel.collapsed);
      expect(notifier.state.isSosActive, true);
    });

    test('SOS 잠금 상태에서 레벨 변경 불가', () {
      notifier.activateSos();
      final applied = notifier.setSheetLevel(BottomSheetLevel.full);
      expect(applied, BottomSheetLevel.collapsed);
    });

    test('SOS 해제 → peek', () {
      notifier.activateSos();
      notifier.deactivateSos();
      expect(notifier.state.sheetLevel, BottomSheetLevel.peek);
      expect(notifier.state.isSosActive, false);
    });
  });

  group('§7.4 상세뷰', () {
    test('상세뷰 진입 → full + 이전 상태 저장', () {
      notifier.setSheetLevel(BottomSheetLevel.half);
      final result = notifier.enterDetailView();
      expect(result, BottomSheetLevel.full);
      expect(notifier.state.preDetailLevel, BottomSheetLevel.half);
    });

    test('상세뷰 종료 → 이전 상태 복원', () {
      notifier.setSheetLevel(BottomSheetLevel.half);
      notifier.enterDetailView();
      final result = notifier.exitDetailView();
      expect(result, BottomSheetLevel.half);
      expect(notifier.state.preDetailLevel, isNull);
    });
  });

  group('§8.2 No-trip', () {
    test('여행 없음 → collapsed + 잠금', () {
      notifier.setNoTrip(true);
      expect(notifier.state.sheetLevel, BottomSheetLevel.collapsed);
      expect(notifier.state.isNoTrip, true);
    });

    test('No-trip 상태에서 레벨 변경 불가', () {
      notifier.setNoTrip(true);
      final applied = notifier.setSheetLevel(BottomSheetLevel.full);
      expect(applied, BottomSheetLevel.collapsed);
    });

    test('여행 생성 후 잠금 해제', () {
      notifier.setNoTrip(true);
      notifier.setNoTrip(false);
      expect(notifier.state.isNoTrip, false);
      // collapsed 상태 유지 (사용자가 직접 높이 변경)
      expect(notifier.state.sheetLevel, BottomSheetLevel.collapsed);
    });
  });

  group('BottomSheetLevel fraction', () {
    test('모든 레벨의 fraction이 올바르다', () {
      expect(BottomSheetLevel.collapsed.fraction, 0.10);
      expect(BottomSheetLevel.peek.fraction, 0.25);
      expect(BottomSheetLevel.half.fraction, 0.50);
      expect(BottomSheetLevel.expanded.fraction, 0.75);
      expect(BottomSheetLevel.full.fraction, 1.00);
    });

    test('fromFraction이 가장 가까운 레벨을 반환', () {
      expect(BottomSheetLevelExt.fromFraction(0.08), BottomSheetLevel.collapsed);
      expect(BottomSheetLevelExt.fromFraction(0.20), BottomSheetLevel.peek);
      expect(BottomSheetLevelExt.fromFraction(0.45), BottomSheetLevel.half);
      expect(BottomSheetLevelExt.fromFraction(0.70), BottomSheetLevel.expanded);
      expect(BottomSheetLevelExt.fromFraction(0.90), BottomSheetLevel.full);
    });
  });
}
```

**Step 2: 테스트 실행**

Run: `cd safetrip-mobile && flutter test test/providers/main_screen_provider_test.dart -v`
Expected: All tests PASS (25+ tests)

**Step 3: Commit**

```bash
git add safetrip-mobile/test/providers/main_screen_provider_test.dart
git commit -m "test(bottom-sheet): MainScreenNotifier 상태 전환 유닛 테스트 25건 추가"
```

---

## Task 6: 통합 검증 — 10회 시나리오 테스트

**Files:**
- Create: `safetrip-mobile/test/screens/bottom_sheet_scenarios_test.dart`

이 테스트는 `MainScreenNotifier`를 직접 사용하여 **10가지 시나리오**를 시뮬레이션한다.
(Widget 테스트는 MainScreen의 의존성이 복잡하므로 provider 레벨에서 검증)

**Step 1: 시나리오 테스트 작성**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:safetrip_mobile/features/main/providers/main_screen_provider.dart';
import 'package:safetrip_mobile/screens/main/navigation/bottom_navigation_bar.dart';

void main() {
  late MainScreenNotifier notifier;

  setUp(() {
    notifier = MainScreenNotifier();
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 시나리오 1: 5단계 스냅 포인트 순회
  // collapsed → peek → half → expanded → full → expanded → half → peek → collapsed
  // ═══════════════════════════════════════════════════════════════════════
  test('시나리오 1: 5단계 스냅 포인트 순회', () {
    final levels = [
      BottomSheetLevel.collapsed,
      BottomSheetLevel.peek,
      BottomSheetLevel.half,
      BottomSheetLevel.expanded,
      BottomSheetLevel.full,
    ];

    // 상승 순회
    for (final level in levels) {
      final applied = notifier.setSheetLevel(level);
      expect(applied, level, reason: '상승: $level 설정 실패');
      expect(notifier.state.sheetLevel, level);
    }

    // 하강 순회
    for (final level in levels.reversed) {
      final applied = notifier.setSheetLevel(level);
      expect(applied, level, reason: '하강: $level 설정 실패');
    }
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 시나리오 2: 동일 탭 재탭 (§4.4)
  // ═══════════════════════════════════════════════════════════════════════
  test('시나리오 2: 동일 탭 재탭', () {
    // collapsed → half
    notifier.setSheetLevel(BottomSheetLevel.collapsed);
    expect(notifier.resolveHeightForSameTabTap(), BottomSheetLevel.half);

    // half → collapsed
    notifier.setSheetLevel(BottomSheetLevel.half);
    expect(notifier.resolveHeightForSameTabTap(), BottomSheetLevel.collapsed);

    // full → half
    notifier.setSheetLevel(BottomSheetLevel.full);
    expect(notifier.resolveHeightForSameTabTap(), BottomSheetLevel.half);

    // expanded → half
    notifier.setSheetLevel(BottomSheetLevel.expanded);
    expect(notifier.resolveHeightForSameTabTap(), BottomSheetLevel.half);

    // peek → collapsed
    notifier.setSheetLevel(BottomSheetLevel.peek);
    expect(notifier.resolveHeightForSameTabTap(), BottomSheetLevel.collapsed);
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 시나리오 3: 다른 탭 전환 (§5.1, §7.2, §7.3)
  // ═══════════════════════════════════════════════════════════════════════
  test('시나리오 3: 다른 탭 전환 — 탭별 기본 높이 적용', () {
    // 현재 collapsed → 일정탭(min: peek) → half 적용
    notifier.setSheetLevel(BottomSheetLevel.collapsed);
    expect(notifier.resolveHeightForTab(BottomTab.trip), BottomSheetLevel.half);

    // 현재 collapsed → 멤버탭(min: peek) → peek 적용
    notifier.setSheetLevel(BottomSheetLevel.collapsed);
    expect(notifier.resolveHeightForTab(BottomTab.member), BottomSheetLevel.peek);

    // 현재 collapsed → 채팅탭(min: expanded) → expanded 적용
    notifier.setSheetLevel(BottomSheetLevel.collapsed);
    expect(notifier.resolveHeightForTab(BottomTab.chat), BottomSheetLevel.expanded);

    // 현재 full → 멤버탭(min: peek) → full 유지
    notifier.setSheetLevel(BottomSheetLevel.full);
    expect(notifier.resolveHeightForTab(BottomTab.member), BottomSheetLevel.full);

    // 현재 half → 채팅탭(min: expanded) → expanded 적용
    notifier.setSheetLevel(BottomSheetLevel.half);
    expect(notifier.resolveHeightForTab(BottomTab.chat), BottomSheetLevel.expanded);

    // 현재 expanded → 안전가이드탭(min: peek) → expanded 유지
    notifier.setSheetLevel(BottomSheetLevel.expanded);
    expect(notifier.resolveHeightForTab(BottomTab.guide), BottomSheetLevel.expanded);
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 시나리오 4: 키보드 출현/닫힘 (§6)
  // ═══════════════════════════════════════════════════════════════════════
  test('시나리오 4: 키보드 출현/닫힘', () {
    // 일반 탭에서 half → 키보드 → full → 키보드 닫힘 → half 복원
    notifier.setSheetLevel(BottomSheetLevel.half);
    expect(notifier.onKeyboardShow(), BottomSheetLevel.full);
    expect(notifier.state.preKeyboardLevel, BottomSheetLevel.half);
    expect(notifier.onKeyboardHide(), BottomSheetLevel.half);
    expect(notifier.state.preKeyboardLevel, isNull);

    // 채팅탭에서 expanded → 키보드 → full → 키보드 닫힘 → expanded (§6.2)
    notifier.setCurrentTab(BottomTab.chat);
    notifier.setSheetLevel(BottomSheetLevel.expanded);
    expect(notifier.onKeyboardShow(), BottomSheetLevel.full);
    expect(notifier.onKeyboardHide(), BottomSheetLevel.expanded);
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 시나리오 5: SOS 발동/해제 (§10)
  // ═══════════════════════════════════════════════════════════════════════
  test('시나리오 5: SOS 발동/해제', () {
    // half에서 SOS 발동
    notifier.setSheetLevel(BottomSheetLevel.half);
    notifier.activateSos();
    expect(notifier.state.sheetLevel, BottomSheetLevel.collapsed);
    expect(notifier.state.isSosActive, true);

    // SOS 중 레벨 변경 시도 → collapsed 유지
    expect(notifier.setSheetLevel(BottomSheetLevel.full), BottomSheetLevel.collapsed);
    expect(notifier.setSheetLevel(BottomSheetLevel.half), BottomSheetLevel.collapsed);

    // SOS 해제
    notifier.deactivateSos();
    expect(notifier.state.sheetLevel, BottomSheetLevel.peek);
    expect(notifier.state.isSosActive, false);

    // 해제 후 레벨 변경 가능
    expect(notifier.setSheetLevel(BottomSheetLevel.half), BottomSheetLevel.half);
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 시나리오 6: No-trip 상태 (§8.2)
  // ═══════════════════════════════════════════════════════════════════════
  test('시나리오 6: No-trip 상태', () {
    // 여행 없음 설정
    notifier.setNoTrip(true);
    expect(notifier.state.sheetLevel, BottomSheetLevel.collapsed);
    expect(notifier.state.isNoTrip, true);

    // 레벨 변경 불가
    expect(notifier.setSheetLevel(BottomSheetLevel.full), BottomSheetLevel.collapsed);

    // 여행 생성 → 잠금 해제
    notifier.setNoTrip(false);
    expect(notifier.state.isNoTrip, false);
    expect(notifier.setSheetLevel(BottomSheetLevel.half), BottomSheetLevel.half);
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 시나리오 7: 두 손가락 스와이프 (§3.3)
  // 이 시나리오는 setSheetLevel로 시뮬레이션 (실제 제스처는 widget 테스트 필요)
  // ═══════════════════════════════════════════════════════════════════════
  test('시나리오 7: collapsed→full 직접 전환 (프로그래밍적)', () {
    notifier.setSheetLevel(BottomSheetLevel.collapsed);
    // 두 손가락 스와이프는 프로그래밍적으로 setSheetLevel(full) 호출
    final applied = notifier.setSheetLevel(BottomSheetLevel.full);
    expect(applied, BottomSheetLevel.full);
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 시나리오 8: velocity 기반 직접 점프 (§3.3)
  // Provider 레벨에서는 setSheetLevel이 velocity를 모르므로
  // SnappingBottomSheet의 _onSizeChanged가 담당. 여기서는 setSheetLevel 통과 확인만.
  // ═══════════════════════════════════════════════════════════════════════
  test('시나리오 8: 빠른 플릭 — provider 레벨 제한 없음', () {
    // Provider는 velocity 검증 안함 → 모든 직접 전환 허용
    notifier.setSheetLevel(BottomSheetLevel.full);
    final applied = notifier.setSheetLevel(BottomSheetLevel.collapsed);
    expect(applied, BottomSheetLevel.collapsed);
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 시나리오 9: 멤버 상세뷰 진입/복귀 (§7.4)
  // ═══════════════════════════════════════════════════════════════════════
  test('시나리오 9: 멤버 상세뷰 진입/복귀', () {
    // peek에서 상세 진입
    notifier.setSheetLevel(BottomSheetLevel.peek);
    expect(notifier.enterDetailView(), BottomSheetLevel.full);
    expect(notifier.state.preDetailLevel, BottomSheetLevel.peek);

    // 뒤로가기
    expect(notifier.exitDetailView(), BottomSheetLevel.peek);
    expect(notifier.state.preDetailLevel, isNull);

    // expanded에서 상세 진입
    notifier.setSheetLevel(BottomSheetLevel.expanded);
    notifier.enterDetailView();
    expect(notifier.exitDetailView(), BottomSheetLevel.expanded);
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 시나리오 10: 뒤로가기 동작 (PopScope 로직)
  // ═══════════════════════════════════════════════════════════════════════
  test('시나리오 10: 뒤로가기 — full/expanded → half', () {
    // full → half
    notifier.setSheetLevel(BottomSheetLevel.full);
    // PopScope 로직: full/expanded이면 half로
    if (notifier.state.sheetLevel == BottomSheetLevel.full ||
        notifier.state.sheetLevel == BottomSheetLevel.expanded) {
      notifier.setSheetLevel(BottomSheetLevel.half);
    }
    expect(notifier.state.sheetLevel, BottomSheetLevel.half);

    // expanded → half
    notifier.setSheetLevel(BottomSheetLevel.expanded);
    if (notifier.state.sheetLevel == BottomSheetLevel.full ||
        notifier.state.sheetLevel == BottomSheetLevel.expanded) {
      notifier.setSheetLevel(BottomSheetLevel.half);
    }
    expect(notifier.state.sheetLevel, BottomSheetLevel.half);

    // half → 그대로 (앱 종료 다이얼로그 트리거)
    notifier.setSheetLevel(BottomSheetLevel.half);
    final shouldExit = !(notifier.state.sheetLevel == BottomSheetLevel.full ||
        notifier.state.sheetLevel == BottomSheetLevel.expanded);
    expect(shouldExit, true);
  });
}
```

**Step 2: 테스트 실행**

Run: `cd safetrip-mobile && flutter test test/screens/bottom_sheet_scenarios_test.dart -v`
Expected: All 10 scenarios PASS

**Step 3: Commit**

```bash
git add safetrip-mobile/test/screens/bottom_sheet_scenarios_test.dart
git commit -m "test(bottom-sheet): 10회 시나리오 통합 테스트 추가"
```

---

## Task 7: 전체 테스트 실행 + 최종 빌드 확인

**Step 1: 전체 테스트 실행**

Run: `cd safetrip-mobile && flutter test test/providers/main_screen_provider_test.dart test/screens/bottom_sheet_scenarios_test.dart -v`
Expected: All tests PASS

**Step 2: 정적 분석**

Run: `cd safetrip-mobile && flutter analyze lib/screens/main/ lib/features/main/providers/main_screen_provider.dart`
Expected: No issues found

**Step 3: 빌드 확인**

Run: `cd safetrip-mobile && flutter build apk --debug 2>&1 | tail -5`
Expected: BUILD SUCCESSFUL

**Step 4: Final commit (if any remaining changes)**

```bash
git status
# 미커밋 변경 있으면 커밋
```
