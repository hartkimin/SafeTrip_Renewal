# 멤버별 이동기록 화면 구현 설계

**날짜**: 2026-03-07
**기준 문서**: 25_T3_멤버별_이동기록_원칙_v1.2
**구현 범위**: P0 ~ P3 (Phase 1 핵심 ~ Phase 2 인사이트)
**접근법**: 기존 locations 모듈 보강 + Flutter feature 신규 생성

---

## 1. 현황 분석

### 구현 완료
- 백엔드: 이동 세션 API(9.4~9.9), 실시간 위치 WebSocket/RTDB, 가디언 프라이버시 필터링
- DB: TB_LOCATION, TB_MOVEMENT_SESSION, TB_STAY_POINT 등 9개 테이블
- Flutter: SessionService, ApiService에 세션 조회 메서드 존재

### 미구현 (본 설계 대상)
- 역할별 접근 권한 검증 (§7 매트릭스)
- 프라이버시 마스킹 (§8 등급별 동작)
- 가디언 is_paid 접근 범위 제어 (§9)
- Flutter 이동기록 화면 (타임라인 뷰, 지도 뷰)
- 체류 지점 감지 알고리즘 (§12)
- 이동기록 인사이트 (§13)
- 내보내기 기능 (§10.3)

---

## 2. 백엔드 아키텍처

### 2.1 Guard & Interceptor 구조

```
AuthMiddleware (기존)
  → RoleAccessGuard — §7 역할별 접근 권한 검증
    → Controller 메서드
      → PrivacyMaskingInterceptor — §8 응답 마스킹
        → GuardianAccessFilter — §9 가디언 접근 범위 필터링
```

**RoleAccessGuard** (`locations/guards/role-access.guard.ts`):
- 요청자 역할(캡틴/크루장/크루/가디언) 판별
- 대상 멤버와의 관계 검증
- §7.1 매트릭스 기반 접근 허용/거부
- 데코레이터: `@RequireRole()`, `@AllowSelfAccess()`

**PrivacyMaskingInterceptor** (`locations/interceptors/privacy-masking.interceptor.ts`):
- privacy_first + 비연동 시간대 → 500m 격자 스냅
- standard → 정확 주소 제거 (도로명 수준)
- 본인 조회 시 마스킹 미적용 (M1)
- SOS 시 마스킹 자동 해제 + tb_event_log 기록

**GuardianAccessFilter** (서비스 레벨):
- is_paid = FALSE → recorded_at >= NOW() - 24h
- is_paid = TRUE → 전체 보존 기간

### 2.2 신규 API 엔드포인트

| Method | Path | 설명 | 우선순위 |
|--------|------|------|---------|
| GET | `/trips/:tripId/members/:userId/movement-history` | 멤버 이동기록 | P0 |
| GET | `/trips/:tripId/members/:userId/movement-history/timeline` | 타임라인 뷰 데이터 | P1 |
| GET | `/trips/:tripId/members/:userId/stay-points` | 체류 지점 목록 | P1 |
| GET | `/trips/:tripId/members/:userId/movement-sessions/:sessionId/stats` | 세션 통계 | P1 |
| GET | `/trips/:tripId/members/:userId/insights` | 개인 인사이트 | P3 |
| GET | `/trips/:tripId/insights/group` | 그룹 인사이트 | P3 |
| POST | `/trips/:tripId/members/:userId/movement-history/export` | 내보내기 | P2 |

### 2.3 체류 지점 감지 (§12)

서버 사이드 체류 판정 (is_movement_end 트리거):
- 반경 100m + 5분 + 3포인트 → TB_STAY_POINT INSERT
- 클러스터링: 200m + 30분 이내 인접 체류 지점 병합
- 이상 감지: 10km/60초 점프 필터링, accuracy > 100m 제외

---

## 3. Flutter 프론트엔드 아키텍처

### 3.1 디렉토리 구조

```
features/movement_history/
├── presentation/
│   ├── screens/screen_movement_history.dart
│   ├── widgets/
│   │   ├── timeline_view.dart
│   │   ├── timeline_event_marker.dart
│   │   ├── time_slider.dart
│   │   ├── map_route_view.dart
│   │   ├── stay_point_marker.dart
│   │   ├── date_navigator.dart
│   │   ├── privacy_masking_overlay.dart
│   │   ├── session_stats_card.dart
│   │   ├── guardian_upgrade_modal.dart
│   │   ├── insight_dashboard.dart
│   │   └── export_dialog.dart
│   └── controllers/movement_history_controller.dart
├── providers/
│   ├── movement_history_provider.dart
│   ├── timeline_provider.dart
│   └── insight_provider.dart
├── models/
│   ├── movement_history_data.dart
│   ├── timeline_event.dart
│   ├── stay_point.dart
│   └── session_stats.dart
└── services/movement_history_service.dart
```

### 3.2 화면 구성 (§5, §6)

- 상단: 멤버 이름 + 날짜 선택기
- 탭 전환: [타임라인] ↔ [지도] (양방향 연동, M2)
- 시간 슬라이더: 00:00~23:59 분 단위, 핀치 줌
- 타임라인: 이벤트 마커 8종 (§5.3), 시간순 과거→현재 (M3)
- 지도: 폴리라인 + 체류 마커 + 클러스터링 (§6)
- 하단: 일일 통계 요약

### 3.3 양방향 연동 (M2)

- 타임라인 이벤트 탭 → MapController.animateCamera()
- 지도 경로 탭 → ScrollController.animateTo()
- MovementHistoryController의 selectedEventNotifier 공유

### 3.4 진입 경로

1. 멤버탭 > 멤버 상세 > "이동기록 보기" 버튼
2. 지도 화면 > 멤버 마커 탭 > BottomSheet > "이동기록" 링크

### 3.5 가디언 전용 처리

- 무료 가디언 + 당일 외 날짜 → GuardianUpgradeModal (§9.3)
- 무료: 내보내기/인사이트 비표시 / 유료: 표시

---

## 4. 에러 처리 (§14)

| 에러 | 백엔드 | Flutter |
|------|--------|---------|
| 권한 없음 | 403 | SnackBar + 복귀 |
| 무료 가디언 범위 초과 | 403 + upgrade_required | GuardianUpgradeModal |
| 보존 기간 만료 | 404 + data_expired | "기간 만료" 안내 |
| GPS 데이터 없음 | 빈 배열 | 플레이스홀더 |
| 가디언 연결 해제 | 403 + link_cancelled | "연결 해제" 안내 |

---

## 5. 오프라인/보존 정책 (§10, §16)

- 타임라인/지도 데이터 로컬 캐시 (Hive/SQLite)
- 오프라인 시 캐시 표시 + "오프라인 모드" 배너
- 보존 기간: 성인 90일, 미성년자 30일
- 만료 7일 전 푸시 알림
- 내보내기: PDF (지도 캡처 + 타임라인), CSV (원시 좌표)
- 삭제: 소프트 삭제 → 익명화 → 물리 삭제

---

## 6. 테스트 전략 (§18)

### P0 검증
1. 캡틴 전체 멤버 이동기록 조회 성공
2. 크루장 소속 조 외 멤버 조회 시 403
3. 크루 본인 외 멤버 조회 시 403
4. 무료 가디언 24h 초과 시 과금 안내 모달
5. 유료 가디언 전체 기간 조회 성공
6. 프라이버시우선 비연동 마스킹 확인
7. SOS 시 마스킹 자동 해제 + 로그

### P1 검증
8. 보존 기간 만료 7일 전 알림
9. 유료 가디언 결제 후 is_paid=TRUE
10. 체류 지점 감지 정확도
11. 오프라인 저장 후 배치 동기화
13. 여행 기간 15일 제한

### P2 검증
12. 타임라인-지도 양방향 연동
