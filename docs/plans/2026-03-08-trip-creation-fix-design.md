# 여행 생성 버그 수정 설계

**날짜**: 2026-03-08
**증상**: 여행 생성 후 메인 화면으로 이동되지만 여행 카드가 표시되지 않음

## 근본 원인

여행 생성 API는 성공하지만, `GET /trips/card-view` 조회가 실패하여 카드 미표시.
주요 원인: `tb_trip_card_view` SQL 뷰 미생성, 에러 피드백 부재, tripProvider 미연동.

## 수정 항목 (6건)

### 1. DB 마이그레이션 — `tb_group.created_by` + `tb_trip_card_view`

**파일**: `safetrip-server-api/sql/20-migration-schema-sync.sql`

- `tb_group`에 `created_by VARCHAR(128)` 컬럼 추가 (엔티티에 정의되어 있으나 DB 누락)
- `tb_trip_card_view` 뷰 생성 (`CREATE OR REPLACE VIEW`) 포함 — 기존 SKIP 코멘트 대체

### 2. API 에러 전달 개선

**파일**: `safetrip-mobile/lib/services/api_service.dart`

- `createTrip()` 메서드에서 catch 후 `return null` → `rethrow`로 변경
- 호출자가 에러를 인지하고 사용자에게 피드백 가능

### 3. 프론트 여행 생성 화면 수정

**파일**: `safetrip-mobile/lib/screens/trip/screen_trip_create.dart`

- `tripType: 'leisure'` → `'group'`으로 변경 (solo 선택 기능은 추후)
- `fetchCardView()` 호출에 `await` 추가
- `trip == null` 시 에러 스낵바 표시

### 4. 백엔드 트랜잭션 래핑

**파일**: `safetrip-server-api/src/modules/trips/trips.service.ts`

- `create()` 메서드에 `queryRunner` 트랜잭션 적용
- Group → Trip → Member → ChatRoom 전체를 하나의 트랜잭션으로 묶음
- 부분 실패 시 rollback

### 5. card-view 엔드포인트 방어 로직

**파일**: `safetrip-server-api/src/modules/trips/trips.service.ts`

- `getCardView()` memberTrips 쿼리에 try-catch 추가
- `tb_trip_card_view` 미존재 시 `tb_trip` 직접 JOIN fallback 쿼리 실행

### 6. tripProvider 연동

**파일**: `safetrip-mobile/lib/screens/trip/screen_trip_create.dart`

- 여행 생성 성공 후 `tripProvider.notifier.setCurrentTripDetails()` 호출
- 생성 응답에서 tripName, status, startDate 등 추출하여 설정
