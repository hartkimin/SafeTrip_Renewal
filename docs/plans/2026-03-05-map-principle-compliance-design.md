# 지도 기본화면 고유 원칙 (DOC-T3-MAP-017) 준수 구현 설계

**날짜**: 2026-03-05
**기준 문서**: `Master_docs/17_T3_지도_기본화면_고유_원칙.md` v1.1
**범위**: P0 + P1 전체 (Phase 1 런칭 필수 + 핵심 기능)
**접근 방식**: 점진적 강화 (Incremental Enhancement) — 기존 Stack 아키텍처 유지
**지도 SDK**: FlutterMap + OpenStreetMap (현행 유지)

---

## 1. 갭 분석 요약

### 구현 완료 (7)
- Layer 0 지도 타일 (FlutterMap + OSM)
- Layer 2 멤버 위치 마커 기본 (MarkerManager + Firebase RTDB)
- Layer 5 SOS 버튼 (3초 롱프레스, 항상 표시)
- Layer 6 SOS 오버레이 기본 (상단 빨간 배너)
- 오프라인 배너 표시
- 가디언 분리 화면 (screen_main_guardian.dart)
- 멤버 마커 애니메이션 (jump/breathing/move)

### 부분 구현 (5)
- 마커 클러스터링: threshold=18 → 원칙 3단계(15/12-14/11)로 변경 필요
- 역할별 마커 색상: 원칙 색상 코드와 불일치 가능
- 프라이버시 등급: Provider에 3등급 존재하나 마커 필터링 미구현
- 오프라인 SOS: 로컬 큐잉 존재하나 지도 타일 오프라인 미지원
- 카메라 기본 위치: 기본 줌 15 설정됨, 상태별 분기 미구현

### 미구현 (12)
- Layer 1 안전시설 오버레이 (P1)
- Layer 3 일정/장소 마커 지도 표시 (P1)
- Layer 4 이벤트/알림 마커 (P1)
- 레이어 토글 UI 바텀시트 패널 (P1)
- SOS→카메라 자동 이동 (P0)
- 지오펜스 이탈→카메라 이동 (P1)
- 앱 복귀→내 위치 카메라 (P1)
- 자동 전환 큐 시스템 P0>P1>P2 (P1)
- 터치 인터랙션 우선순위 (P1)
- 가디언 바운딩 박스 카메라 (P1)
- 오프라인 지도 다운로드 50km/500MB (P1)
- 멤버 마커 프로필 미니카드 (P1)

---

## 2. 섹션 1: 레이어 상태 관리 + 토글 UI (§3)

### 신규 파일
- `providers/map_layer_provider.dart` — 7개 레이어 ON/OFF 상태 + SharedPreferences 영속화
- `bottom_sheets/bottom_sheet_layer_settings.dart` — 레이어 토글 패널 (바텀시트)

### 변경 파일
- `screen_main.dart` — 레이어 설정 버튼 추가 (Layer 5), 조건부 렌더링

### MapLayerState 설계

```dart
class MapLayerState {
  final bool layer1SafetyFacilities;  // 안전시설 (토글 가능)
  final bool layer2MemberMarkers;     // 멤버 위치 (토글 가능)
  final bool layer3SchedulePlaces;    // 일정/장소 (토글 가능)
  final bool layer4EventAlerts;       // 이벤트/알림 (캡틴/크루장 전용)
}
```

### 규칙
- Layer 0 (지도 타일), Layer 5 (UI 컨트롤): 항상 ON → 토글 UI 미표시
- Layer 6 (긴급 오버레이): SOS 상태 자동 제어 → 토글 UI 미표시
- 토글 상태 변경 시 즉시 SharedPreferences 저장 → 앱 재시작 복원
- Layer 4 토글은 캡틴/크루장에게만 표시

### 토글 UI
- 레이어 설정 버튼: 지도 우측 상단 (layers 아이콘)
- 탭 시 바텀시트로 토글 패널
- 각 레이어: Switch + 아이콘 + 설명 텍스트

---

## 3. 섹션 2: 카메라 자동 전환 시스템 (§4)

### 신규 파일
- `managers/map_camera_transition_manager.dart` — 자동 전환 큐 + 우선순위

### 변경 파일
- `managers/camera_controller.dart` — 전환 매니저 연동
- `screen_main.dart` — 전환 매니저 초기화 + 이벤트 리스닝

### 전환 규칙

| 우선순위 | 트리거 | 카메라 동작 | 레이어 동작 |
|:--------:|--------|-----------|-----------|
| P0 | SOS 발동 | 발신자 위치, 줌 16 고정 | Layer 6 강제 활성화 |
| P1 | 지오펜스 이탈 | 이탈 멤버 위치 이동 | Layer 4 경보 마커 |
| P1 | 앱 복귀 | 내 위치 복귀 | 직전 레이어 유지 |
| P2 | 멤버 오프라인 | 이동 없음 | "마지막 알려진 위치" 표시 |
| P2 | 일정 시작 | 일정 장소 (선택 알림) | Layer 3 마커 강조 |

### 충돌 해결
- P0 처리 중 P1/P2 → 큐에 보관 → SOS 해제 후 순차 처리
- 여행 상태별 기본 카메라: active→내 위치(줌15), planning→목적지(줌12), demo→기본위치(줌12)

### 가디언 카메라
- 1명 연결: 해당 멤버 위치, 줌 15
- 2명+ 연결: 전체 멤버 바운딩 박스 auto-fit
- 위치 미확인: 여행 목적지 기준

---

## 4. 섹션 3: 멤버 마커 시스템 강화 (§5, §6)

### 변경 파일
- `managers/marker_manager.dart` — 역할별 색상, 3단계 클러스터링, 탭 미니카드
- `constants/map_constants.dart` — 클러스터링 3단계 + 역할 색상 상수

### 신규 파일
- `widgets/map/member_mini_card.dart` — 멤버 마커 탭 미니카드

### 역할별 마커 색상 (§5.3)

| 역할 | 색상 | 아이콘 |
|------|:----:|--------|
| 캡틴 | #FFD700 황금색 | 별 |
| 크루장 | #FF8C00 주황색 | 다이아몬드 |
| 크루 | #2196F3 파란색 | 원형 |
| 내 위치 | #4CAF50 초록색 | 펄스 애니메이션 |
| 가디언 연결 멤버 | #9C27B0 보라색 | 방패 |

### 3단계 클러스터링 (§5.2)

| 줌 | 표시 방식 |
|:--:|----------|
| 15+ | 개별 마커 + 이름 라벨 |
| 12~14 | ≤3명 개별, ≥4명 클러스터(숫자 배지) |
| ≤11 | 클러스터만 + 바운딩 박스 auto-fit |

### 터치 인터랙션 우선순위 (§5.4)
```
SOS 버튼 > 멤버 마커 > 이벤트 마커 > 일정 마커 > 지오펜스 > 빈 영역
```

### 프라이버시 등급별 마커 표시 (§6)

| 등급 | 멤버 마커 | 가디언 뷰 |
|------|----------|----------|
| safety_first | 전체 항상 실시간 | 연결 멤버 항상 실시간 |
| standard | 공유 ON만 표시 | ON→실시간, OFF→30분 스냅샷 |
| privacy_first | 일정 시간만 표시 | 일정 시간만, OFF→비공유 |

---

## 5. 섹션 4: Layer 1/3/4 콘텐츠

### Layer 1: 안전시설 오버레이

**신규 파일:**
- `managers/safety_facility_manager.dart` — 데이터 로드 + 마커 생성
- `models/safety_facility.dart` — 안전시설 모델

**데이터 소스:** `GET /api/v1/countries/:code/safety-facilities?lat=&lng=&radius=` (백엔드 신규 API)

**마커 스타일:** 병원(녹색 십자), 경찰서(파란 방패), 대사관(빨간 국기)

### Layer 3: 일정/장소 마커

**신규 파일:**
- `managers/schedule_marker_manager.dart` — 일정 장소 마커 + 경로 라인

**동작:**
- 여행 일정 장소를 핀 마커로 표시
- 일정 순서대로 PolylineLayer 경로 연결
- 탭 → 일정 상세 미니카드 (장소명, 시간, [지도▶])
- 일정 시작 시 해당 마커 강조 (확대 + 색상 변경)

### Layer 4: 이벤트/알림 마커

**신규 파일:**
- `managers/event_marker_manager.dart` — 지오펜스 경보/출석 체크 마커

**동작:**
- 지오펜스 이탈 → 이탈 위치에 빨간 삼각형 경고 마커
- 캡틴/크루장 전용 레이어

---

## 6. 섹션 5: 오프라인 지도 + 에러/엣지케이스

### 오프라인 지도 다운로드 (§9.1)

**신규 파일:**
- `services/offline_map_service.dart` — 타일 다운로드/캐시/만료 관리
- `screens/settings/screen_offline_map.dart` — 수동 다운로드 UI

**규칙:**
- 여행 목적지 중심 반경 50km, 줌 10~16
- 최대 500MB/국가
- planning→active 전환 시 Wi-Fi에서 자동 시작
- 종료 후 30일 만료

### 에러 처리 (§7)

**위치 오류:**
- GPS 없음 → 회색 마커 + "마지막 알려진 위치" 시각
- 5분 미갱신 → "오프라인" 배지 + 캡틴 알림
- 권한 없음 → 권한 다이얼로그 (타 멤버 마커 정상)

**렌더링 오류:**
- 타일 실패 → 오프라인 캐시 대체
- 캐시 없음 → 회색 배경 + 좌표 점
- 마커 실패 → 기본 핀 폴백

**SOS 엣지케이스:**
- 앱 재시작 → 서버에서 SOS 상태 복원
- 오프라인 → Layer 6 유지, 로컬 큐잉
- 동시 다수 → 최근 발신자 위치로 이동

### 오프라인 UI (§9.3)
- 오렌지색 배너: "오프라인 상태 — 실시간 위치가 업데이트되지 않습니다"
- 각 멤버 마커에 마지막 업데이트 시각 ("10분 전")
- SOS 오프라인에서도 항상 활성

---

## 7. 신규 파일 목록 (총 10개)

| # | 파일 경로 | 목적 |
|---|----------|------|
| 1 | `providers/map_layer_provider.dart` | 레이어 ON/OFF 상태 관리 |
| 2 | `bottom_sheets/bottom_sheet_layer_settings.dart` | 레이어 토글 UI |
| 3 | `managers/map_camera_transition_manager.dart` | 카메라 자동 전환 큐 |
| 4 | `widgets/map/member_mini_card.dart` | 멤버 마커 탭 미니카드 |
| 5 | `managers/safety_facility_manager.dart` | 안전시설 데이터+마커 |
| 6 | `models/safety_facility.dart` | 안전시설 모델 |
| 7 | `managers/schedule_marker_manager.dart` | 일정 장소 마커+경로 |
| 8 | `managers/event_marker_manager.dart` | 이벤트/경보 마커 |
| 9 | `services/offline_map_service.dart` | 오프라인 타일 캐시 |
| 10 | `screens/settings/screen_offline_map.dart` | 오프라인 다운로드 UI |

## 8. 변경 파일 목록 (총 7개)

| # | 파일 경로 | 변경 내용 |
|---|----------|----------|
| 1 | `screen_main.dart` | 레이어 토글 버튼, 조건부 렌더링, 전환 매니저 |
| 2 | `screen_main_guardian.dart` | 가디언 카메라 규칙, 바운딩 박스 |
| 3 | `managers/marker_manager.dart` | 역할 색상, 3단계 클러스터링, 프라이버시 필터 |
| 4 | `managers/camera_controller.dart` | 전환 매니저 연동 |
| 5 | `constants/map_constants.dart` | 색상/클러스터 상수 |
| 6 | `widgets/components/offline_banner.dart` | 오렌지색 + 메시지 변경 |
| 7 | `widgets/components/sos_overlay.dart` | Layer 6 전체 화면 오버레이 강화 |
