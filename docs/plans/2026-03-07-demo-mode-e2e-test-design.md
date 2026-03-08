# Demo Mode E2E Integration Test Design

**Date**: 2026-03-07
**Type**: Flutter Integration Test (`integration_test` package)
**Scope**: 데모 모드 전체 플로우 (시나리오 선택 → 데모 메인 → 역할 전환 → 타임라인 → 전환 CTA → 완료)
**Backend**: 불필요 (데모 모드는 100% 로컬 데이터)

---

## 디렉토리 구조

```
safetrip-mobile/
  integration_test/
    demo_flow_test.dart           ← 메인 E2E 테스트 (전체 데모 플로우)
    helpers/
      test_app.dart               ← GoRouter + ProviderScope 세팅
```

---

## 테스트 그룹 (7개)

### Group 1: 시나리오 선택 화면 렌더링

| # | 검증 항목 | 방법 |
|---|----------|------|
| 1-1 | 화면 타이틀 "데모 체험" AppBar | `find.text('데모 체험')` |
| 1-2 | 3개 시나리오 카드 렌더링 | `find.text('학생 단체 여행')`, `find.text('친구들과 해외여행')`, `find.text('해외 출장/패키지 투어')` |
| 1-3 | S1 카드: 33명, 3일, 안전최우선 | `find.text('33명')`, `find.text('3일')`, `find.text('안전최우선')` |
| 1-4 | DemoBadge "데모 모드" 표시 | `find.byType(DemoBadge)` |
| 1-5 | 뒤로가기 버튼 존재 | `find.byIcon(Icons.arrow_back)` |

### Group 2: 시나리오 로딩 → 데모 메인 진입

| # | 검증 항목 | 방법 |
|---|----------|------|
| 2-1 | S1 카드 탭 | `tester.tap(find.text('학생 단체 여행'))` |
| 2-2 | 로딩 인디케이터 표시 | `find.byType(CircularProgressIndicator)` |
| 2-3 | /demo/main 라우트 진입 | `find.byType(DemoModeWrapper)` |
| 2-4 | DemoState isActive=true | Provider 확인 |
| 2-5 | SharedPreferences 데모 키 설정 | `prefs.getBool('is_demo_mode') == true` |

### Group 3: 데모 메인 래퍼 UI 레이어

| # | 검증 항목 | 위젯/텍스트 |
|---|----------|-----------|
| 3-1 | Layer 1: DemoBadge | `find.byType(DemoBadge)` |
| 3-2 | Layer 2: DemoRolePanel | `find.byType(DemoRolePanel)` |
| 3-3 | Layer 3: DemoTimeSlider | `find.byType(DemoTimeSlider)` |
| 3-4 | Layer 5: ExitFab "실제 앱으로 전환" | `find.text('실제 앱으로 전환')` |
| 3-5 | Layer 4: 가디언 비교 버튼 | `find.text('가디언 비교')` |
| 3-6 | Layer 4b: 등급 비교 버튼 | `find.text('등급 비교')` |

### Group 4: 역할 전환 (DemoRolePanel)

| # | 검증 항목 | 방법 |
|---|----------|------|
| 4-1 | 초기 역할 "캡틴" | `find.text('캡틴')` |
| 4-2 | 패널 탭 → 확장 (4개 역할 표시) | `find.text('크루장')`, `find.text('크루')`, `find.text('가디언')` |
| 4-3 | "크루" 선택 → 역할 변경 | DemoState.currentRole == DemoRole.crew |
| 4-4 | SharedPreferences demo_user_role 업데이트 | `prefs.getString('demo_user_role') == 'crew'` |
| 4-5 | 캡틴 전용 기능 잠금 확인 | `canAccess('trip_settings') == false` |

### Group 5: 타임 슬라이더 (DemoTimeSlider)

| # | 검증 항목 | 방법 |
|---|----------|------|
| 5-1 | 라벨 "D-7", "여행 중" 표시 | `find.text('D-7')`, `find.text('여행 중')` |
| 5-2 | 현재 위치 포맷 "D-Day HH:00" | 정규식 매칭 |
| 5-3 | Slider 위젯 존재 | `find.byType(Slider)` |
| 5-4 | 슬라이더 드래그 → simTime 변경 | DemoState.currentSimTime 확인 |

### Group 6: 전환 모달 (DemoConversionModal)

| # | 검증 항목 | 방법 |
|---|----------|------|
| 6-1 | ExitFab 탭 → 모달 표시 | `find.text('SafeTrip 체험 완료!')` |
| 6-2 | "여행 만들기" CTA | `find.text('여행 만들기')` |
| 6-3 | "초대코드로 참여" CTA | `find.text('초대코드로 참여')` |
| 6-4 | "나중에 할게요" CTA | `find.text('나중에 할게요')` |
| 6-5 | "나중에 할게요" 탭 → 데모 상태 클리어 | DemoState.isActive == false |

### Group 7: 완료 화면 (ScreenDemoComplete)

| # | 검증 항목 | 방법 |
|---|----------|------|
| 7-1 | "데모 체험을 완료했습니다!" 메시지 | `find.text('데모 체험을 완료했습니다!')` |
| 7-2 | 체크 아이콘 | `find.byIcon(Icons.check_circle_outline)` |
| 7-3 | "여행 만들기" ElevatedButton | `find.widgetWithText(ElevatedButton, '여행 만들기')` |
| 7-4 | "초대코드로 참여" OutlinedButton | `find.widgetWithText(OutlinedButton, '초대코드로 참여')` |
| 7-5 | "나중에 할게요" TextButton | `find.widgetWithText(TextButton, '나중에 할게요')` |
| 7-6 | DemoBadge 표시 | `find.byType(DemoBadge)` |
| 7-7 | SharedPreferences 데모 키 모두 클리어 | `prefs.getBool('is_demo_mode') == null` |

---

## 기술적 결정

### 의존성
```yaml
dev_dependencies:
  integration_test:
    sdk: flutter
```

### 테스트 환경 설정
1. `IntegrationTestWidgetsFlutterBinding.ensureInitialized()`
2. `SharedPreferences.setMockInitialValues({})`
3. 실제 GoRouter + ProviderScope 사용
4. 시나리오 JSON 파일은 실제 asset 사용 (integration test 앱 번들 접근 가능)

### 위젯 탐색 전략
- **텍스트 기반**: 한국어 문자열로 위젯 탐색 (가장 직관적)
- **타입 기반**: `find.byType(DemoModeWrapper)` 등
- **Key 기반**: 필요시 테스트용 Key 추가

### Connectivity Mock
- `ScreenDemoComplete`와 `DemoConversionModal`은 `Connectivity().checkConnectivity()` 사용
- Integration test에서는 기본적으로 온라인 상태 가정

---

## 실행 방법

```bash
cd safetrip-mobile
flutter test integration_test/demo_flow_test.dart
```

에뮬레이터/시뮬레이터 실행 필요. Firebase 인증 불필요 (데모 모드 인증 우회).
