# 지도 기본화면 정합성 수정 설계

| 항목 | 내용 |
|------|------|
| **문서 참조** | 17_T3_지도_기본화면_고유_원칙 v1.1 (DOC-T3-MAP-017) |
| **작성일** | 2026-03-07 |
| **목적** | 문서 17_T3 대비 코드 정합성 검증 결과, 미구현/불완전 항목 수정 + 테스트 |

---

## 1. 검증 결과 요약

전체 정합률: 약 78% (11/14 항목 구현 확인)

### 1.1 정상 구현 (수정 불필요)

- ✅ 7단계 레이어 시스템 (Layer 0~6) — map_layer_provider.dart
- ✅ SOS 버튼 (Layer 5, G5 원칙) — sos_button.dart
- ✅ SOS 긴급 오버레이 (Layer 6) — sos_overlay.dart
- ✅ 카메라 자동 전환 우선순위 큐 (P0>P1>P2) — map_camera_transition_manager.dart
- ✅ 멤버 마커 역할별 색상 (#FFD700, #FF8C00, #2196F3, #4CAF50, #9C27B0) — map_constants.dart
- ✅ 마커 클러스터링 3단계 (줌 15/12/11) — marker_manager.dart
- ✅ 멤버 미니 카드 (이름, 역할, 배터리, 업데이트 시각) — member_mini_card.dart
- ✅ 레이어 토글 패널 (바텀시트, SharedPreferences 저장) — bottom_sheet_layer_settings.dart
- ✅ 오프라인 배너 (오렌지색, 시각 표시) — offline_banner.dart
- ✅ 빈 영역 탭 → 미니카드 닫기 — screen_main.dart
- ✅ 가디언 전용 뷰 (screen_main_guardian.dart)

### 1.2 수정 필요 항목

| # | 이슈 | 우선순위 | 유형 | 영향 파일 |
|---|------|:---:|------|----------|
| F1 | 이벤트 상세 바텀시트 미구현 | P0 | 신규 생성 | `event_detail_modal.dart` (신규), `screen_main.dart` |
| F2 | 지오펜스 Circle 레이어 미연동 + 정보 팝업 미구현 | P0 | 신규 + 수정 | `geofence_info_modal.dart` (신규), `geofence_map_renderer.dart`, `screen_main.dart` |
| F3 | LocationSharingModal 프라이버시 등급 UI 분기 미구현 | P0 | 수정 | `location_sharing_modal.dart` |
| F4 | 오프라인 감지 임계값 20분→5분 | P1 | 수정 | `location_service.dart` (LocationConfig) |
| F5 | 일정 마커 탭 핸들러 stub → 상세 모달 연결 | P1 | 수정 | `screen_main.dart` |
| F6 | SOS 앱 재시작 시 상태 복원 | P1 | 수정 | `sos_service.dart`, app init 로직 |
| F7 | SOS 위치 미확인 시 "위치 확인 중" 오버레이 | P1 | 수정 | `sos_service.dart`, `sos_overlay.dart` |
| F8 | 지오펜스 이탈 경보음 | P2 | 수정 | `geofence_manager.dart` or screen_main.dart |
| F9 | 유료/무료 가디언 기능 분기 강화 | P2 | 수정 | `guardian_filter.dart` |

---

## 2. 수정 설계

### F1: 이벤트 상세 바텀시트

**문서 요구**: §5.4 "이벤트 마커 탭: 이벤트 상세 바텀시트 표시 (지오펜스 이탈, 출석 체크 등)"

**현상**: event_marker_manager.dart에 onEventMarkerTap 콜백 존재하나, screen_main.dart에서 debugPrint만 호출

**설계**:
- 신규 파일: `lib/screens/main/bottom_sheets/modals/event_detail_modal.dart`
- 이벤트 타입별 UI:
  - 지오펜스 이탈: 멤버명, 지오펜스명, 이탈 시각, 위치
  - 출석 체크: 멤버명, 장소명, 체크 시각
- screen_main.dart의 onEventMarkerTap 콜백에서 showModalBottomSheet 호출

### F2: 지오펜스 Circle 레이어 + 정보 팝업

**문서 요구**: §3 Layer 4 "지오펜스 경보 마커", §5.4 "지오펜스 영역 탭: 지오펜스 정보 팝업"

**현상**: GeofenceMapRenderer 존재하나 FlutterMap에 CircleLayer 미연동. 탭 핸들러 없음.

**설계**:
- geofence_map_renderer.dart: onGeofenceTap 콜백 추가
- screen_main.dart: FlutterMap children에 CircleLayer 추가
- 신규 파일: `lib/screens/main/bottom_sheets/modals/geofence_info_modal.dart`
  - 지오펜스명, 반경, 활성 상태
  - 캡틴/크루장: 편집 버튼 포함

### F3: LocationSharingModal 프라이버시 등급 UI

**문서 요구**: §6 프라이버시 등급별 마커 표시 동작

**현상**: privacyLevel 파라미터 없음, 3등급 분기 로직 없음

**설계**:
- LocationSharingModal에 `privacyLevel` 파라미터 추가
- safety_first: 토글 비활성화 + "항상 공유" 안내문
- standard: 현재 동작 유지 (멤버별 ON/OFF 토글)
- privacy_first: 일정 연동 안내 + 버퍼 구간(±15분) 설명
- screen_main.dart에서 privacyLevel 전달

### F4: 오프라인 감지 임계값

**문서 요구**: §7.1 "멤버 위치 업데이트 5분 이상 없음 → 오프라인 배지"

**현상**: LocationConfig.offlineThresholdMinutes = 20

**설계**: 값을 5로 변경. MapConstants.offlineThreshold와 일치시킴.

### F5: 일정 마커 탭 핸들러

**문서 요구**: §5.4 "일정 마커 탭: 일정 상세 미니 카드 표시"

**현상**: onScheduleMarkerTap에서 debugPrint만 호출

**설계**: 기존 schedule_detail_modal.dart을 재활용하여 showModalBottomSheet 연결

### F6: SOS 앱 재시작 복원

**문서 요구**: §7.3 "SOS 발동 중 앱 재시작 → 서버에서 상태 복원, Layer 6 재활성화"

**설계**:
- sos_service.dart에 `checkActiveSos(tripId)` 메서드 추가
- 앱 초기화 시 서버에서 활성 SOS 상태 조회
- 활성 SOS 있으면 Layer 6 복원

### F7: SOS 위치 미확인 UI

**문서 요구**: §7.3 "SOS 발신자 위치 미확인 → '위치 확인 중' 오버레이"

**설계**:
- sos_overlay.dart에 `isLocationPending` 파라미터 추가
- 위치 null일 때 "SOS 발신 — 위치 확인 중" 텍스트 + 마지막 알려진 위치로 카메라 이동

### F8: 지오펜스 이탈 경보음

**설계**: screen_main.dart의 지오펜스 이벤트 리스너에서 AudioPlayer로 경보음 재생

### F9: 유료/무료 가디언 기능 분기

**설계**: guardian_filter.dart에 is_paid 기반 일정 마커 접근 분기 추가

---

## 3. 테스트 계획

### 단위 테스트
- MapCameraTransitionManager: P0>P1>P2 우선순위 큐 동작
- MapLayerState: 레이어 토글 + SharedPreferences 저장/복원
- MarkerManager: 프라이버시 등급별 필터링 (safety_first/standard/privacy_first)
- OfflineMapService: 캐시 만료/정리 로직

### 위젯 테스트
- SosButton: 3초 롱프레스 → 활성화, 해제 버튼 전환
- SosOverlay: 다수 SOS 사용자 표시, 위치 미확인 상태
- EventDetailModal: 이벤트 타입별 렌더링
- GeofenceInfoModal: 정보 표시 + 편집 버튼 (역할별)
- LocationSharingModal: 프라이버시 등급별 UI 분기

---

## 4. 변경 파일 목록

### 신규 생성
1. `lib/screens/main/bottom_sheets/modals/event_detail_modal.dart`
2. `lib/screens/main/bottom_sheets/modals/geofence_info_modal.dart`
3. `test/map/` 디렉토리 테스트 파일들

### 수정
4. `lib/screens/main/screen_main.dart` — Circle 레이어 연동, 탭 핸들러 연결
5. `lib/managers/geofence_map_renderer.dart` — onGeofenceTap 콜백
6. `lib/screens/main/bottom_sheets/modals/location_sharing_modal.dart` — privacyLevel 분기
7. `lib/services/location_service.dart` — offlineThresholdMinutes 수정
8. `lib/services/sos_service.dart` — checkActiveSos, 위치 미확인 처리
9. `lib/widgets/components/sos_overlay.dart` — isLocationPending 파라미터
