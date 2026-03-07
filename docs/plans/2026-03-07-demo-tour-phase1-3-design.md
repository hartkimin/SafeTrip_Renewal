# Demo Tour Phase 1~3 전체 구현 설계

| 항목 | 내용 |
|------|------|
| **날짜** | 2026-03-07 |
| **기준 문서** | DOC-T3-DMO-030 v2.1 (데모 투어 체험 원칙) |
| **범위** | Phase 1 (P0) + Phase 2 (P1) + Phase 3 (P2~P3) |
| **접근 방식** | GAP-First 순차 구현 |

---

## 현황: 기존 구현 커버리지 (~70%)

### 이미 완료 (변경 불필요)
- Demo Badge (D3) — `demo_badge.dart`
- Role Panel (§3.4) — `demo_role_panel.dart` (4역할, 접근 권한)
- Time Slider (§3.2) — `demo_time_slider.dart` (D-7~D+15, 15일 제한, 햅틱)
- Guardian Compare (§3.3) — `demo_guardian_compare.dart` (무료/유료 비교, 1,900원)
- Conversion Modal (§3.8) — `demo_conversion_modal.dart` (3 CTA)
- Scenario Selection (§3.6) — `screen_demo_scenario_select.dart` (3카드)
- Event Simulator — `demo_event_simulator.dart` (타이머 기반 재생)
- State Provider — `demo_state_provider.dart` (Riverpod, 역할별 접근 제어)
- Complete Screen — `screen_demo_complete.dart`
- Route Definitions — `app_router.dart` (demo routes)
- JSON Scenarios — `scenario_s1.json`, `scenario_s2.json`, `scenario_s3.json`

### GAP (구현 필요)
| GAP | 심각도 | Phase |
|-----|--------|-------|
| 웰컴화면 CTA '먼저 둘러보기' | MEDIUM | Phase 1 |
| 이벤트 타입 고도화 | LOW | Phase 2 |
| 이벤트 토스트 위젯 | LOW | Phase 2 |
| 등급 비교 체험 패널 (§3.5) | HIGH | Phase 3 (P2) |
| 코치마크 UI 시스템 (§3.7) | HIGH | Phase 3 (P2) |
| Analytics 7종 이벤트 (§3.8) | CRITICAL | Phase 3 (P3) |
| 메모리 최적화 검증 (§3.9) | LOW | Phase 3 (P3) |

---

## Phase 1 (P0 MVP) — 웰컴화면 CTA 보완

### 변경: `screen_welcome.dart`
- 마지막 슬라이드(CTA 슬라이드)에 "먼저 둘러보기" 보조 TextButton 추가
- "시작하기" 버튼 아래에 배치
- 탭 시 `RoutePaths.demoScenarioSelect`로 이동
- Purpose 화면의 기존 데모 진입점 유지

---

## Phase 2 (P1) — 이벤트 시뮬레이션 고도화

### 변경: `demo_event_simulator.dart`
- 특화 이벤트 타입 추가: `member_left`, `schedule_changed`, `geofence_violation`
- 이벤트별 콜백 분기 강화

### 신규: `demo_event_toast.dart`
- 이벤트 타입별 아이콘+색상 매핑
  - SOS = 빨강 + warning icon
  - 지오펜스 = 주황 + location_off icon
  - 일정변경 = 파랑 + event_note icon
  - 멤버이탈 = 노랑 + person_off icon
  - 채팅 = 그린 + chat icon
- 3초 자동 소멸, 탭으로 즉시 닫기

### 보강: 시나리오 JSON 파일 (s1, s2, s3)
- 특화 이벤트 데이터 추가 (member_left, schedule_changed 등)

---

## Phase 3 (P2~P3) — 등급 비교 + 코치마크 + Analytics

### P2-1: 등급 비교 체험 패널

**신규: `demo_grade_compare.dart`**
- 3-탭 토글: [안전 최우선] [표준] [프라이버시 우선]
- 현재 선택 등급 강조 (밑줄 + 색상)
- 등급별 차이 시각화 (5행):
  - 위치 공유 범위: 24시간 ↔ 일정 연동만
  - 가디언 공유: 항상 ↔ 스케줄 OFF 비공유
  - 마커 표시: 실시간 ↔ 체크포인트만
  - 가디언 일시 중지: 불가 ↔ 최대 24시간
  - 지오펜스→가디언: 항상 ↔ 전달 안 함
- `DemoState.switchGrade()` 호출
- DemoModeWrapper에 접근 버튼 추가 (전체 역할 접근 가능, §4 기준)

### P2-2: 코치마크 시스템

**신규: `demo_coachmark.dart`**
- CustomPainter + Overlay 기반 커스텀 말풍선
- 반투명 배경 (타겟 영역만 하이라이트)
- 화살표 포인팅 (타겟 위치 기반 자동 방향)
- "Skip All" 버튼 (모든 코치마크 건너뛰기)
- 탭으로 개별 소멸
- `DemoState.viewedCoachmarks` 기반 1회 표시

**신규: `demo_coachmark_data.dart`**
- 6개 코치마크 정의 (§3.7 텍스트 그대로):

```dart
const coachmarks = [
  CoachmarkDef(id: 'map_tab', text: '멤버들의 실시간 위치가 지도에 표시됩니다...'),
  CoachmarkDef(id: 'role_panel', text: '역할을 바꿔가며 각 역할의 기능 차이를...'),
  CoachmarkDef(id: 'guardian_compare', text: '무료·유료 가디언의 차이를 직접...'),
  CoachmarkDef(id: 'time_slider', text: '슬라이더를 움직여 여행 전·중·후...'),
  CoachmarkDef(id: 'sos_button', text: 'SOS 버튼은 긴급 상황 시...'),
  CoachmarkDef(id: 'grade_compare', text: '프라이버시 등급을 바꾸면...'),
];
```

**코치마크 표시 트리거:**
| 화면/위젯 | 트리거 시점 |
|-----------|------------|
| 지도 탭 | 데모 메인 진입 시 |
| 역할 전환 패널 | 패널 최초 열기 시 |
| 가디언 과금 패널 | 비교 뷰 최초 열기 시 |
| 타임 슬라이더 | 슬라이더 최초 표시 시 |
| SOS 버튼 | 안전가이드 탭 최초 진입 시 |
| 등급 비교 패널 | 패널 최초 열기 시 |

### P3-1: Analytics 서비스

**신규: `demo_analytics.dart`**
- Firebase Analytics 래핑 클래스
- 7종 이벤트 메서드:

```dart
class DemoAnalytics {
  static void demoStarted();
  static void scenarioSelected(String scenarioId);
  static void roleSwitched(String fromRole, String toRole);
  static void gradeSwitched(String grade);
  static void guardianUpgradeViewed();
  static void demoCompleted(int durationSec, String scenarioId);
  static void demoConverted(String ctaType);
}
```

**이벤트 삽입 위치:**
| 파일 | 이벤트 | 삽입 위치 |
|------|--------|----------|
| `screen_demo_scenario_select.dart` | `demo_started` | initState |
| `screen_demo_scenario_select.dart` | `demo_scenario_selected` | _selectScenario() |
| `demo_role_panel.dart` | `demo_role_switched` | _switchRole() |
| `demo_grade_compare.dart` | `demo_grade_switched` | _switchGrade() |
| `demo_guardian_compare.dart` | `demo_guardian_upgrade_viewed` | show() |
| `screen_demo_complete.dart` | `demo_completed` | initState |
| `demo_conversion_modal.dart` | `demo_converted` | CTA onTap |

### P3-2: 메모리 최적화 검증
- `demo_mode_wrapper.dart` dispose() 정리 확인
- 시나리오 JSON 200KB 이하 검증
- 프로필 이미지 미사용 확인 (현재 아이콘 기반)

---

## 전체 파일 변경 목록

### 신규 파일 (5개)
1. `lib/features/demo/presentation/widgets/demo_grade_compare.dart`
2. `lib/features/demo/presentation/widgets/demo_coachmark.dart`
3. `lib/features/demo/presentation/widgets/demo_coachmark_data.dart`
4. `lib/features/demo/presentation/widgets/demo_event_toast.dart`
5. `lib/features/demo/data/demo_analytics.dart`

### 수정 파일 (11개)
1. `lib/features/onboarding/presentation/screens/screen_welcome.dart` — CTA 추가
2. `lib/features/demo/data/demo_event_simulator.dart` — 이벤트 타입 고도화
3. `lib/features/demo/presentation/widgets/demo_mode_wrapper.dart` — 등급비교 접근, 코치마크 트리거
4. `lib/features/demo/presentation/screens/screen_demo_scenario_select.dart` — Analytics 삽입
5. `lib/features/demo/presentation/screens/screen_demo_complete.dart` — Analytics 삽입
6. `lib/features/demo/presentation/widgets/demo_role_panel.dart` — Analytics 삽입
7. `lib/features/demo/presentation/widgets/demo_guardian_compare.dart` — Analytics 삽입
8. `lib/features/demo/presentation/widgets/demo_conversion_modal.dart` — Analytics 삽입
9. `assets/demo/scenario_s1.json` — 이벤트 보강
10. `assets/demo/scenario_s2.json` — 이벤트 보강
11. `assets/demo/scenario_s3.json` — 이벤트 보강

---

## §10 검증 체크리스트 대응

| # | 체크 항목 | 구현 대응 |
|---|----------|----------|
| 1 | 데모 배지 전 화면 | ✅ 기존 구현 |
| 2 | 서버 API 미호출 | ✅ 로컬 JSON, Analytics만 예외 |
| 3 | 3개 시나리오 전환 | ✅ 기존 구현 |
| 4 | 4역할 지원 | ✅ 기존 구현 |
| 5 | 15일 제한 | ✅ 기존 구현 |
| 6 | 가디언 무료/유료 | ✅ 기존 구현 |
| 7 | 3등급 비교 | **신규**: demo_grade_compare.dart |
| 8 | 전환 유도 모달 | ✅ 기존 구현 |
| 9 | 데이터 격리 | ✅ 기존 구현 |
| 10 | 오프라인 동작 | ✅ 로컬 assets 기반 |
| 11 | 비즈니스 원칙 참조 | ✅ 문서 내 §번호 명시 |
| 12 | 코치마크 1회 | **신규**: demo_coachmark.dart |
