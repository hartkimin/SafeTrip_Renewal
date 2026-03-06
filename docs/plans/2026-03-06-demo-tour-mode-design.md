# Demo Tour Mode Design — Phase 1+2 (P0+P1)

| 항목 | 내용 |
|------|------|
| **문서 ID** | `DESIGN-DEMO-030` |
| **스펙 문서** | `30_T3_데모_투어_체험_원칙.md` v2.1 |
| **구현 범위** | Phase 1 (P0) + Phase 2 (P1) |
| **작성일** | 2026-03-06 |
| **접근법** | DemoScope + DemoModeWrapper (Provider Override) |

---

## 1. 구현 범위

### Phase 1 (P0)
- 3개 시나리오 기본 플로우 (S1/S2/S3)
- 역할 전환 패널 (캡틴/크루장/크루/가디언)
- 데모 배지 (모든 화면 상단)
- 전환 유도 모달 (데모 종료 시)

### Phase 2 (P1)
- 가디언 과금 체험 비교 뷰
- 15일 타임 슬라이더
- 이벤트 시뮬레이션 자동 재생

---

## 2. 아키텍처

### 접근법: DemoScope + DemoModeWrapper

```
DemoModeWrapper (오버레이: 배지 + 역할전환 + 탈출구)
  └─ ProviderScope (overrides: [demoTripProvider, demoLocationProvider, ...])
      └─ 기존 ScreenMain (그대로 사용)
```

- D2 원칙: 실제 앱과 동일한 UI (기존 화면 재사용)
- D4 원칙: Provider override로 완전 격리

### 파일 구조

```
safetrip-mobile/
├── assets/demo/
│   ├── scenario_s1.json
│   ├── scenario_s2.json
│   └── scenario_s3.json
│
├── lib/features/demo/
│   ├── data/
│   │   ├── demo_scenario_loader.dart
│   │   └── demo_location_simulator.dart
│   ├── models/
│   │   └── demo_scenario.dart
│   ├── providers/
│   │   ├── demo_state_provider.dart
│   │   ├── demo_trip_provider.dart
│   │   └── demo_location_provider.dart
│   └── presentation/
│       ├── screens/
│       │   ├── screen_demo_scenario_select.dart
│       │   └── screen_demo_complete.dart
│       └── widgets/
│           ├── demo_mode_wrapper.dart
│           ├── demo_badge.dart
│           ├── demo_role_panel.dart
│           ├── demo_time_slider.dart
│           ├── demo_guardian_compare.dart
│           └── demo_conversion_modal.dart
```

---

## 3. DemoState (핵심 상태)

```dart
class DemoState {
  final DemoScenario? currentScenario;
  final DemoRole currentRole;           // captain/crewChief/crew/guardian
  final PrivacyGrade currentGrade;      // safetyFirst/standard/privacyFirst
  final DateTime currentSimTime;        // 타임 슬라이더 현재 시점
  final bool isEventPlaying;
  final int currentEventIndex;
  final Set<String> viewedCoachmarks;
  final bool isGuardianUpgraded;        // 유료 가디언 체험 중
}
```

---

## 4. 시나리오 JSON 구조

```json
{
  "scenario_id": "s1",
  "title": "학생 단체 여행 (제주도)",
  "privacy_grade": "safety_first",
  "duration_days": 3,
  "destination": { "name": "제주도", "country_code": "KR", "lat": 33.4996, "lng": 126.5312, "timezone": "Asia/Seoul" },
  "members": [...],
  "guardian_links": [...],
  "schedules": [...],
  "simulation_events": [...],
  "location_tracks": { "member_id": [{"t": 0, "lat": ..., "lng": ...}] }
}
```

---

## 5. 기존 코드 수정 범위 (최소)

| 파일 | 변경 |
|------|------|
| route_paths.dart | 데모 시나리오/완료 경로 추가 |
| app_router.dart | 새 라우트 등록 |
| screen_trip_demo.dart | 시나리오 선택으로 리다이렉트 |
| screen_main.dart | isDemoMode 파라미터 → DemoModeWrapper 래핑 |
| pubspec.yaml | assets/demo/ 등록 |

---

## 6. P1 기능 상세

### 15일 타임 슬라이더
- 수평 슬라이더 D-7 ~ D+N+3
- D+16 이상 회색 잠금 + 진동 햅틱
- 슬라이더 이동 → DemoState.currentSimTime 갱신

### 가디언 과금 비교 뷰
- 좌(무료) / 우(유료) 비교 레이아웃
- "업그레이드 체험하기" → 안내 모달 → 전환

### 이벤트 자동 재생
- 타이머 기반 순차 이벤트 실행
- 역할 전환 시 일시 정지 → 재개
