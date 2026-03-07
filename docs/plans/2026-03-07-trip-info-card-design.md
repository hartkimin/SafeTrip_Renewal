# 여행정보카드 구현 설계서

**날짜**: 2026-03-07
**기준 문서**: 24_T3_여행정보카드_원칙 v1.0 (DOC-T3-TIC-024)
**구현 범위**: P0 ~ P3 전체 (21개 기능)

---

## 결정사항 요약

| 항목 | 결정 |
|------|------|
| 구현 범위 | P0 ~ P3 전체 21개 기능 |
| 기존 코드 | TopTripInfoCard 전면 재작성 |
| DB 마이그레이션 | TB_TRIP_CARD_VIEW SQL 뷰 포함 |
| API 설계 | GET /trips/card-view 전용 엔드포인트 신규 |
| 접근법 | Strategy 패턴 — 상태별 콘텐츠 위젯 분리 |

---

## 1. 전체 아키텍처

### 1.1 파일 구조

```
safetrip-mobile/lib/features/trip_card/
├── models/
│   └── trip_card_data.dart          # TB_TRIP_CARD_VIEW 매핑 모델
├── providers/
│   └── trip_card_provider.dart      # 카드 데이터 Riverpod provider
├── services/
│   └── trip_card_service.dart       # API 호출 서비스
├── widgets/
│   ├── trip_info_card_section.dart   # 최상위 컨테이너
│   ├── member_trip_card.dart         # 멤버 여행 카드
│   ├── planning_card_content.dart    # planning 상태 콘텐츠
│   ├── active_card_content.dart      # active 상태 콘텐츠
│   ├── completed_card_content.dart   # completed 상태 콘텐츠
│   ├── guardian_card.dart            # 가디언 카드 (무료/유료/전체)
│   ├── no_trip_cta.dart              # 탐색 모드 CTA
│   ├── trip_switch_bottom_sheet.dart  # 여행 전환 바텀시트
│   ├── privacy_badge.dart            # 프라이버시 등급 배지
│   ├── d_day_badge.dart              # D-day 배지
│   └── offline_banner.dart           # 오프라인 배지
└── utils/
    └── trip_card_utils.dart          # D-day 계산, 상태 유틸

safetrip-server-api/
├── sql/
│   └── migration-trip-card-view.sql  # TB_TRIP_CARD_VIEW 생성
└── src/modules/trips/
    ├── trips.controller.ts           # GET /trips/card-view 추가
    └── trips.service.ts              # getCardView() 메서드 추가
```

### 1.2 데이터 플로우

```
[PostgreSQL TB_TRIP_CARD_VIEW]
       ↓ SQL View
[GET /api/v1/trips/card-view]
       ↓ JSON Response
[TripCardService.fetchCardData()]
       ↓
[TripCardProvider (Riverpod StateNotifier)]
       ↓ state changes
[TripInfoCardSection]
  ├── MemberTripCard → PlanningContent / ActiveContent / CompletedContent
  ├── GuardianCard → Free / Paid / Full
  └── NoTripCta
```

---

## 2. 상태별 카드 UI

### 2.1 MemberTripCard Strategy

| 상태 | 콘텐츠 위젯 | 1행 | 2행 | 3행 |
|------|------------|-----|-----|-----|
| planning | PlanningCardContent | [예정]+국기+여행명+D-N+👥N명+[전환▼] | 📅 기간 (N일) | 프라이버시 배지 |
| active | ActiveCardContent | [진행 중]+국기+여행명+여행 중+👥N명+[전환▼] | 📅 기간 \| N일째 진행 중 | 오늘 일정 요약 |
| completed | CompletedCardContent | [완료]+국기+여행명+완료+👥N명+[열람▼] | 📅 기간 (N일) | 통계+재활성화 버튼 |
| none | NoTripCta | "여행이 없습니다" | [+새 여행 만들기][초대코드 입력] | — |

### 2.2 가디언 카드 3종

| 타입 | 표시 정보 | 하단 추가 |
|------|----------|----------|
| 무료 | 멤버 이름+기간+상태+위치 ON/OFF | 유료 전환 유도 문구+버튼 |
| 유료 | 무료+프라이버시 배지+일정 요약+위치 상태 | — |
| 전체 | 여행명+기간+전체 멤버 공유 현황 | — |

### 2.3 색상 매핑

```
planning  → AppColors.tripPlanning (회색)
active    → AppColors.tripActive (초록)
completed → AppColors.tripCompleted (파란/회색)
guardian  → 별도 정의 (보라/회색 계열)
```

---

## 3. 백엔드 API & DB

### 3.1 DB 마이그레이션: TB_TRIP_CARD_VIEW

문서 §11.3의 SQL 뷰 그대로 생성. 추가로 가디언 조회 확장 쿼리 포함.

### 3.2 API 엔드포인트

```
GET /api/v1/trips/card-view
```

응답:
```json
{
  "memberTrips": [{
    "tripId", "tripName", "status", "startDate", "endDate",
    "tripDays", "privacyLevel", "sharingMode",
    "countryCode", "countryName", "destinationCity",
    "hasMinorMembers", "reactivationCount",
    "dDay", "currentDay", "memberCount", "canReactivate",
    "userRole", "todayScheduleSummary",
    "totalDistance", "visitedPlaces"
  }],
  "guardianTrips": [{
    "tripId", "memberName", "tripName", "status",
    "startDate", "endDate", "guardianType",
    "locationSharingStatus", "privacyLevel",
    "todayScheduleSummary"
  }]
}
```

### 3.3 서버 15일 검증 강화

createTrip(), updateTrip()에 명시적 15일 검증 + 400 에러(TRIP_DURATION_EXCEEDED)

### 3.4 여행 상태 자동 전환

end_date 도래 시 completed 자동 전환 로직 (API 호출 시 검사)

### 3.5 재활성화 엔드포인트

```
PATCH /api/v1/trips/:tripId/reactivate
```

조건: reactivation_count == 0 AND updated_at > NOW() - 24h

---

## 4. 오프라인 대응 & 에러 처리

### 4.1 오프라인 배지

ConnectivityProvider 활용 → [오프라인 — 마지막 동기화: HH:MM]
캐시: SharedPreferences 24시간 유효

### 4.2 에러 처리

| 에러 | UI 처리 |
|------|---------|
| 네트워크 오류 | 스켈레톤 UI → 재시도 버튼 |
| 서버 500 | 에러 메시지 + 재시도 |
| 여행 삭제됨 | 카드 제거 + 토스트 |
| 강퇴됨 | 카드 제거 + 알림 |
| 15일 초과 | 달력 피커 비활성화 + 안내 텍스트 |

### 4.3 복수 active 여행 경고

active 여행 2개 이상 → "진행 중인 여행 N개" 경고 배지

---

## 5. P0~P3 기능 매핑

### P0 (8개) — 런칭 필수
- P0-1: 카드 기본 렌더링 (3행 레이아웃)
- P0-2: 상태별 카드 변형 (planning/active/completed)
- P0-3: D-day 계산 및 표시
- P0-4: 15일 제한 달력 피커
- P0-5: 서버 15일 검증
- P0-6: 여행 전환 바텀시트
- P0-7: 탐색 모드 CTA
- P0-8: 프라이버시 등급 배지

### P1 (5개) — Phase 1 핵심
- P1-1: 가디언 카드 분리 표시
- P1-2: 무료/유료 가디언 카드 차이
- P1-3: 유료 전환 유도 UI
- P1-4: 오프라인 배지 + 캐시
- P1-5: 여행 상태 자동 전환

### P2 (4개) — Phase 2 확장
- P2-1: 재활성화 버튼
- P2-2: 오늘 일정 요약
- P2-3: D-1/D-0 알림 연동
- P2-4: 복수 active 여행 경고

### P3 (4개) — Phase 3 고도화
- P3-1: completed 카드 통계
- P3-2: 미성년자 포함 아이콘
- P3-3: 여행 히스토리 열람
- P3-4: TB_TRIP_CARD_VIEW 캐싱

---

## 6. 검증 체크리스트 (12항목)

문서 §14의 12개 검증 항목 전체 적용.
