---
date: '2026-03-05'
version: v3.6
part: 3/3
tags:
  - SafeTrip
  - 프로젝트현황
  - DB
  - 스키마
status: completed
기준문서:
  - SafeTrip_비즈니스_원칙_v5_1
  - SafeTrip_마스터_원칙_거버넌스_v2_0
분할정보:
  - "Part 1: §1~§3, §4 도메인 [A]~[F] — 개요, ERD, 테이블 명세 전반"
  - "Part 2: §4 도메인 [G]~[N], §5 — 테이블 명세 후반, 인덱스"
  - "Part 3: §6~§13, 부록 A~C — 운영 정책, 부록"
---

> **📂 분할 문서 네비게이션**
> [Part 1: 개요·ERD·테이블 A~F](07_T2_DB_설계_및_관계_v3_6_Part1.md) |
> [Part 2: 테이블 G~N·인덱스](07_T2_DB_설계_및_관계_v3_6_Part2.md) |
> [Part 3: 운영·부록](07_T2_DB_설계_및_관계_v3_6_Part3.md)

# SafeTrip — DB 설계 및 관계 v3.6 (Part 3)

## 6. 데이터 보관 및 생명주기

> 비즈니스 원칙 v5.1 §13 데이터 생명주기 기본 정책 반영

| 데이터 유형 | 보관 기간 | 근거 |
|-----------|----------|------|
| 사용자 계정 (soft delete) | 삭제 요청 후 7일 유예 → hard delete | 비즈니스 원칙 v5.1 §14.4 |
| 위치 로그 (**TB_LOCATION**, 구 TB_LOCATION_LOG) | 여행 종료 후 90일 | 위치정보법 준수 |
| 미성년자 위치 로그 | 여행 종료 후 **30일** (단축) | 미성년자 보호 원칙 §5 |
| 위치 접근 이력 (TB_LOCATION_ACCESS_LOG) | 생성 후 6개월 (expired_at) | 위치정보법 제16조 |
| Heartbeat (TB_HEARTBEAT) | 여행 종료 후 30일 | 서비스 운영 목적 |
| SOS 이벤트 (TB_SOS_EVENT) | 해소 후 **3년** (법적 보존) | 긴급 구조 기록 |
| 채팅 메시지 (TB_CHAT_MESSAGE) | 여행 종료 후 90일 | 서비스 이용약관 |
| 가디언 메시지 (RTDB) | 여행 종료 후 30일 | 서비스 이용약관 |
| 알림 (TB_NOTIFICATION) | 생성 후 30일 (expires_at) | 저장 공간 효율 |
| 동의 이력 (TB_USER_CONSENT) | 동의 철회 후 **5년** | 개인정보보호법 |
| 결제 이력 (TB_PAYMENT) | 결제일로부터 **5년** | 전자상거래법 |
| 환불 이력 (TB_REFUND_LOG) | 환불일로부터 5년 | 전자상거래법 |
| B2B 계약 (TB_B2B_CONTRACT) | 계약 종료 후 **3년** | 상법 계약 보존 의무 |
| 데이터 제공 이력 (TB_DATA_PROVISION_LOG) | **영구 보존** | 법적 감사 대상 |
| 실시간 위치 (RTDB) | **24시간** 자동 만료 | 실시간 목적 |
| 가디언 긴급 위치 요청 (TB_GUARDIAN_LOCATION_REQUEST) | 만료(`expires_at`) 후 **30일** | 서비스 운영 감사 |
| 가디언 스냅샷 (TB_GUARDIAN_SNAPSHOT) | 여행 종료 후 **30일** | 최소 보관 원칙 (비즈니스 원칙 v5.1 §13.1) |
| 이동 경로 세션 이미지 (TB_SESSION_MAP_IMAGE) | 여행 종료 후 **90일** | 이동기록 원칙 §6 |

---

## 7. 역할별 데이터 접근 매트릭스

| 테이블 | 캡틴 | 크루장 | 크루 | 가디언 |
|--------|:----:|:-----:|:----:|:-----:|
| TB_USER (본인) | RW | RW | RW | R |
| TB_GROUP | RW | R | R | — |
| TB_TRIP | RW | R | R | R (연결 멤버 여행) |
| TB_TRIP_SETTINGS | RW | R | — | — |
| TB_GROUP_MEMBER | RW | R (자기 그룹) | R (본인) | R (연결 멤버) |
| TB_GUARDIAN_LINK | RW | R | R (본인 관련) | RW (본인) |
| TB_COUNTRY | R | R | R | R |
| TB_SCHEDULE / TB_TRAVEL_SCHEDULE | RW | RW | R | R |
| TB_GEOFENCE | RW | RW | R | R |
| **TB_LOCATION** (구 TB_LOCATION_LOG) | R (전 멤버) | R (자기 그룹) | R (본인만) | R (연결 멤버) |
| TB_SESSION_MAP_IMAGE | R (본인) | — | R (본인) | — |
| TB_PLANNED_ROUTE | RW | RW | R | R (연결 멤버) |
| TB_ROUTE_DEVIATION | R (전 멤버) | R (자기 그룹) | R (본인만) | R (연결 멤버) |
| TB_HEARTBEAT | R (전 멤버) | R (자기 그룹) | — | R (연결 멤버) |
| TB_SOS_EVENT | RW | R | R (본인) | R (연결 멤버) |
| TB_CHAT_MESSAGE | RW | RW | RW | — |
| TB_NOTIFICATION | — (수신만) | — (수신만) | — (수신만) | — (수신만) |
| TB_INVITE_CODE | RW | R | — | — |
| TB_PAYMENT | R (본인) | — | R (본인) | R (본인) |
| **TB_GUARDIAN_LOCATION_REQUEST** | W (요청 수신 확인) | — | W (승인/거부) | W (요청 발송) |
| **TB_GUARDIAN_SNAPSHOT** | R (연결 멤버 그룹) | — | — | R (연결 멤버만) |
| RTDB guardian_messages | RW (captain 채널) | — | RW (본인 채널) | RW (본인 채널) |
| **TB_PARENTAL_CONSENT** | — | — | — | — (시스템 전용) |
| **TB_COUNTRY_SAFETY** | R | R | R | R |
| **TB_GEOFENCE_EVENT** | R (전 멤버) | R (자기 그룹) | R (본인) | R (연결 멤버) |
| **TB_GEOFENCE_PENALTY** | RW | R | R (본인) | — |
| **TB_MOVEMENT_SESSION** | R (전 멤버) | R (자기 그룹) | R (본인) | — |
| **TB_EMERGENCY** | RW | R | R (본인) | R (연결 멤버) |
| **TB_EMERGENCY_RECIPIENT** | R | R | R (본인) | R (본인) |
| **TB_NO_RESPONSE_EVENT** | RW | R | R (본인) | R (연결 멤버) |
| **TB_SAFETY_CHECKIN** | R (전 멤버) | R (자기 그룹) | RW (본인) | R (연결 멤버) |
| **TB_CHAT_ROOM** | RW | R | R | — |
| **TB_FCM_TOKEN** | — (시스템) | — (시스템) | — (시스템) | — (시스템) |
| **TB_NOTIFICATION_PREFERENCE** | RW (본인) | RW (본인) | RW (본인) | RW (본인) |
| **TB_REDEEM_CODE** | R (본인) | R (본인) | R (본인) | — |
| **TB_B2B_ORGANIZATION** | R (B2B 관리자) | — | — | — |
| **TB_B2B_ADMIN** | RW (B2B 관리자) | — | — | — |
| **TB_B2B_DASHBOARD_CONFIG** | RW (B2B 관리자) | — | — | — |
| **TB_AI_USAGE** | R (본인) | R (본인) | R (본인) | — |

> R = 읽기, W = 쓰기, — = 접근 불가. 프라이버시 등급에 따라 추가 제한 적용.
> `TB_GUARDIAN_SNAPSHOT`: `privacy_first` 등급에서 데이터 없음 (가디언도 접근 불가)

---

## 8. 프라이버시 등급별 데이터 동작 차이

> 비즈니스 원칙 v5.1 §05.5

| 데이터 동작 | 안전 최우선 | 표준 | 프라이버시 우선 |
|-----------|:---------:|:----:|:-----------:|
| 실시간 위치 공유 | 항상 ON | 일정 연동 또는 항상 | 일정 연동 |
| 위치 갱신 주기 | 30초 | 60초 | 120초 |
| Heartbeat 주기 | 1분 | 3분 | 5분 |
| 이동기록 저장 | 항상 | 공유 시간만 | 공유 시간만 |
| 가디언 일시중지 | ❌ 불가 | 최대 12시간 | 최대 24시간 |
| 비공유 구간 마스킹 | 없음 (항상 공유) | 회색 표시 | 회색 + "데이터 없음" |
| OFF 시간대 가디언 공유 | ✅ 실시간 | ✅ 30분 스냅샷 (`TB_GUARDIAN_SNAPSHOT`) | ❌ 비공유 |
| 가디언 긴급 위치 요청 | ❌ 불필요 (항상 실시간) | ❌ 불필요 (스냅샷 제공) | ✅ 가능 (`TB_GUARDIAN_LOCATION_REQUEST`) |
| SOS 위치 전송 | ✅ 항상 | ✅ 항상 | ✅ 항상 (예외 없음) |
| 지오펜스 가디언 알림 | ✅ 항상 | ON 시간만 | ❌ 없음 |

---

## 9. 마이그레이션 파일 목록

### 9.1 기 적용된 마이그레이션

| 파일 | 내용 | 상태 |
|------|------|:----:|
| `01-init-schema.sql` | 초기 스키마 | ✅ 적용됨 |
| `02-seed-test-data.sql` | 테스트 데이터 (7명 사용자) | ✅ 적용됨 |
| `migration-fix-trip-id-null.sql` | tb_group_member.trip_id NULL 수정 (26건) | ✅ 적용됨 |
| `migration-guardian-system.sql` | 보호자 시스템 스키마 (tb_guardian_link, tb_trip_settings) | ✅ 적용됨 |
| `migration-phase1.sql` | 1차 마이그레이션 | ✅ 적용됨 |
| `migration-phase2.sql` | 2차 마이그레이션 | ✅ 적용됨 |
| `migration-phase3.sql` | 3차 마이그레이션 | ✅ 적용됨 |
| `migration-role-rename.sql` | 역할명 변경 마이그레이션 | ✅ 적용됨 |

### 9.2 v3.0 신규 마이그레이션 (예정)

| 파일 (제안) | 내용 | 우선순위 |
|------------|------|:-------:|
| `migration-v3-trip-constraints.sql` | TB_TRIP CHECK 제약(15일), 인덱스 추가 | 🔴 P0 |
| `migration-v3-guardian-paid.sql` | TB_GUARDIAN is_paid/paid_at, TB_GUARDIAN_LINK payment_id | 🔴 P0 |
| `migration-v3-country.sql` | TB_COUNTRY 생성 + 초기 국가 데이터 시드 | 🔴 P0 |
| `migration-v3-heartbeat-sos.sql` | TB_HEARTBEAT, TB_SOS_EVENT, TB_POWER_EVENT 생성 | 🟠 P1 |
| `migration-v3-chat-system.sql` | 채팅 4개 테이블 생성 | 🟠 P1 |
| `migration-v3-notification-system.sql` | 알림 2개 테이블 생성 | 🟠 P1 |
| `migration-v3-location-tracking.sql` | **TB_LOCATION** 생성 (실제 구현), TB_STAY_POINT, **TB_SESSION_MAP_IMAGE**, **TB_PLANNED_ROUTE**, **TB_ROUTE_DEVIATION** | 🟠 P1 |
| `migration-v3-payment-system.sql` | 결제 4개 테이블 (K 도메인) | 🟠 P1 |
| `migration-v3-consent-system.sql` | 동의 관리 6개 테이블 (I 도메인) | 🟡 P2 |
| `migration-v3-b2b-system.sql` | B2B 4개 테이블 (L 도메인) | 🟡 P2 |
| `migration-v3-emergency-system.sql` | TB_EMERGENCY_NUMBER, TB_SOS_RESCUE_LOG, TB_SOS_CANCEL_LOG | 🟡 P2 |
| `migration-v3-user-minor.sql` | TB_USER 미성년자 컬럼 추가 | 🟡 P2 |
| `migration-v3-guardian-location.sql` | **TB_GUARDIAN_LOCATION_REQUEST**, **TB_GUARDIAN_SNAPSHOT**, TB_TRIP.b2b_contract_id/has_minor_members 추가 (v3.2 신규) | 🟡 P2 |
| `migration-v3-legal-logs.sql` | TB_DATA_DELETION_LOG, TB_DATA_PROVISION_LOG | 🟢 P3 |

### 9.3 v3.3 DB 무결성 패치 마이그레이션 (예정)

| 파일 (제안) | 내용 | 우선순위 |
|------------|------|:-------:|
| `migration-v3.3-timestamp-fix.sql` | TB_SESSION_MAP_IMAGE/PLANNED_ROUTE/ROUTE_DEVIATION TIMESTAMP→TIMESTAMPTZ 변환 (10건) | 🟠 P1 |
| `migration-v3.3-fk-integrity.sql` | TB_LOCATION_ACCESS_LOG.trip_id VARCHAR→UUID, TB_LOCATION_SHARING_PAUSE_LOG.trip_id VARCHAR→UUID, SOS/Chat/동의/B2B 누락 FK 추가 (15건) | 🟠 P1 |
| `migration-v3.3-on-delete.sql` | TB_GUARDIAN_LINK.trip_id, TB_HEARTBEAT, TB_SOS_EVENT, TB_POWER_EVENT ON DELETE 정책 추가 (9건) | 🟠 P1 |
| `migration-v3.3-guardian-link-nullable.sql` | TB_GUARDIAN_LINK.guardian_id NOT NULL 제거 (미가입 가디언 초대 지원) | 🔴 P0 |
| `migration-v3.3-guardian-trip-id.sql` | TB_GUARDIAN_LOCATION_REQUEST, TB_GUARDIAN_SNAPSHOT에 trip_id 컬럼 추가 | 🟡 P2 |
| `migration-v3.3-event-log-session.sql` | TB_EVENT_LOG.movement_session_id UUID 컬럼 + 인덱스 추가 | 🟡 P2 |

### 9.4 v3.5 비즈니스 원칙 정합 마이그레이션 (예정)

| 파일 (제안) | 내용 | 우선순위 |
|------------|------|:-------:|
| `migration-v3.5-location-sharing-trip.sql` | TB_LOCATION_SHARING: trip_id 컬럼 + visibility_type 컬럼 추가, idx_location_sharing_trip 인덱스 | 🔴 P0 |
| `migration-v3.5-guardian-link-unique.sql` | TB_GUARDIAN_LINK: UNIQUE 제약 제거 + 부분 인덱스 2개 추가 | 🔴 P0 |
| `migration-v3.5-payment-types.sql` | TB_PAYMENT payment_type CHECK 교체 + trip_id 컬럼 추가, TB_SUBSCRIPTION plan_type CHECK 확장, TB_BILLING_ITEM item_type CHECK 확장 | 🔴 P0 |
| `migration-v3.5-captain-unique.sql` | TB_GROUP_MEMBER captain 유일성 부분 인덱스 추가 | 🔴 P0 |
| `migration-v3.5-location-schedule.sql` | TB_LOCATION_SCHEDULE 신규 생성 | 🟠 P1 |
| `migration-v3.5-attendance-check.sql` | TB_ATTENDANCE_CHECK + TB_ATTENDANCE_RESPONSE 신규 생성 | 🟠 P1 |
| `migration-v3.5-trip-reactivation.sql` | TB_TRIP: reactivated_at + reactivation_count 컬럼 추가 | 🟠 P1 |
| `migration-v3.5-user-deletion-grace.sql` | TB_USER: deletion_requested_at 컬럼 추가 | 🟡 P2 |
| `migration-v3.5-guardian-pause-compat.sql` | TB_GUARDIAN_PAUSE: group_id + guardian_user_id 컬럼 추가 | 🟡 P2 |
| `migration-v3.5-fk-chat-refund-provision.sql` | TB_CHAT_MESSAGE.sender_id FK, TB_REFUND_LOG user_id FK+nullable, TB_DATA_PROVISION_LOG FK | 🟡 P2 |
| `migration-v3.5-guardian-auto-respond.sql` | TB_GUARDIAN_LOCATION_REQUEST: auto_responded + auto_response_reason 컬럼, hourly 인덱스 | 🟡 P2 |
| `migration-v3.5-b2b-max-trips.sql` | TB_B2B_CONTRACT: max_trips 컬럼 추가 | 🟢 P3 |
| `migration-v3.5-geofence-is-active.sql` | TB_GEOFENCE: is_active 컬럼 확인 (01-init-schema.sql 이미 존재) + 인덱스 추가 | 🟢 P3 |

### 9.5 v3.5.1 비즈니스 원칙 v5.1 정합 마이그레이션 (예정)

| 파일 (제안) | 내용 | 우선순위 |
|------------|------|:-------:|
| `migration-v3.5.1-location-schedule-specific-date.sql` | TB_LOCATION_SCHEDULE: specific_date DATE 컬럼 추가, CONSTRAINT chk_schedule_scope 추가, idx_location_schedule_date 부분 인덱스 추가 | 🟠 P1 |
| `migration-v3.5.1-refund-log-policy.sql` | TB_REFUND_LOG: refund_policy VARCHAR(30) 컬럼 추가 (기존 행은 NULL 허용) | 🟡 P2 |

---

## 10. 알려진 이슈

> **v3.5 기준 미해결 이슈: 0개** (v3.3 이슈 전부 해소 + v3.5 신규 18개 이슈 전부 해소)

| # | 이슈 | 해소 방법 |
|:-:|------|----------|
| 1 | TB_TRIP 컬럼 불일치 | ✅ §4.4에서 최종 스키마 확정 (v3.0) |
| 2 | tb_group_member.trip_id NULL | ✅ §4.5에서 NOT NULL 확정 + INDEX 추가 (v3.0) |
| 3 | schedule.service.ts TB_TRAVEL_SCHEDULE 불일치 | ✅ §4.13에서 location_lat/lng 명시 추가 (v3.0) |
| 4 | 비즈니스 원칙 v5.0 스키마 미반영 | ✅ CHECK 제약, is_paid, privacy_level 전면 반영 (v3.0) |
| 5 | 신규 테이블 미생성 | ✅ 마이그레이션 계획 §9.2에 전부 포함 (v3.0) |
| 6 | TIMESTAMP 타임존 미반영 (이동경로 테이블 10건) | ✅ v3.3 TIMESTAMPTZ로 전환 |
| 7 | trip_id VARCHAR(128) 타입 오류 2건 | ✅ v3.3 UUID + FK 정규화 |
| 8 | SOS/채팅/동의/B2B 테이블 FK 15건 누락 | ✅ v3.3 FK 추가 + ON DELETE 정책 명시 |
| 9 | guardian_link.guardian_id NOT NULL → 미가입 초대 불가 | ✅ v3.3 nullable 전환 |
| 10 | guardian_location_request/snapshot에 trip_id 없음 | ✅ v3.3 trip_id 컬럼 추가 |
| 11 | event_log에 movement_session_id 없음 | ✅ v3.3 논리키 컬럼 추가 |
| 12 | TB_LOCATION_SHARING에 trip_id / visibility_type 없음 | ✅ v3.5 trip_id FK + visibility_type CHECK(all/admin_only/specified) 추가 |
| 13 | 위치 공유 일정 테이블(TB_LOCATION_SCHEDULE) 누락 | ✅ v3.5 §4.15a 신규 생성 |
| 14 | 출석 체크 테이블 누락 | ✅ v3.5 §4.22a/b TB_ATTENDANCE_CHECK + TB_ATTENDANCE_RESPONSE 신규 생성 |
| 15 | TB_TRIP 재활성화 이력 추적 불가 | ✅ v3.5 reactivated_at + reactivation_count + CHECK(≤1) 추가 |
| 16 | 계정 삭제 7일 유예 미지원 | ✅ v3.5 TB_USER.deletion_requested_at 추가 |
| 17 | TB_GUARDIAN_LINK UNIQUE 제약 불완전 (NULL 미등록 가디언 중복 허용) | ✅ v3.5 UNIQUE 제거 → 부분 인덱스 2개로 대체 |
| 18 | 캡틴 유일성 DB 미강제 | ✅ v3.5 idx_group_member_captain 부분 유니크 인덱스 추가 |
| 19 | TB_CHAT_MESSAGE.sender_id FK 누락 | ✅ v3.5 REFERENCES tb_user(user_id) ON DELETE SET NULL 추가 |
| 20 | TB_REFUND_LOG.user_id FK 누락 + NOT NULL 오류 | ✅ v3.5 FK 추가 + NULLABLE 전환 |
| 21 | TB_DATA_PROVISION_LOG FK 2건 누락 | ✅ v3.5 sos_event_id FK + processed_by_user_id FK 추가 |
| 22 | TB_PAYMENT payment_type Appendix C 불일치 | ✅ v3.5 CHECK 전면 교체 (trip_base/addon_* 5종 + b2b_contract) |
| 23 | TB_SUBSCRIPTION plan_type Appendix C 불일치 | ✅ v3.5 CHECK 교체 (free/trip_base/addon_*/b2b_school/b2b_corporate) |
| 24 | TB_BILLING_ITEM item_type Appendix C 불일치 | ✅ v3.5 CHECK 교체 (trip_base/addon_*/b2b_seat/movement_session) |
| 25 | TB_GUARDIAN_PAUSE Appendix C 비정규화 부재 | ✅ v3.5 group_id + guardian_user_id 컬럼 추가 |
| 26 | TB_B2B_CONTRACT max_trips 없음 | ✅ v3.5 max_trips INTEGER DEFAULT NULL 추가 |
| 27 | TB_GEOFENCE is_active 누락 | ✅ v3.5 is_active BOOLEAN DEFAULT TRUE 복원 + 부분 인덱스 추가 |
| 28 | TB_GUARDIAN_LOCATION_REQUEST 자동 응답 추적 불가 | ✅ v3.5 auto_responded + auto_response_reason 추가 |
| 29 | 시간당 3회 제한 쿼리 인덱스 없음 | ✅ v3.5 idx_guardian_location_request_hourly 추가 |
| 30 | 구현에만 존재하는 17개 테이블 문서 미반영 | ✅ v3.6 — 17개 테이블(TB_PARENTAL_CONSENT 외 16개) 전부 문서화 |

---

## 11. 구현 우선순위

| 우선순위 | 테이블 그룹 | Phase | 설명 |
|:-------:|-----------|:-----:|------|
| 🔴 P0 | TB_COUNTRY | Phase 1 | countries API 즉시 복구 |
| 🔴 P0 | TB_TRIP (CHECK 적용), TB_GROUP_MEMBER (인덱스), TB_GUARDIAN_LINK (payment_id) | Phase 1 | 비즈니스 원칙 v5.1 필수 |
| 🔴 P0 | TB_HEARTBEAT, TB_SOS_EVENT, TB_POWER_EVENT | Phase 1 | SOS 핵심 기능 |
| 🟠 P1 | TB_PAYMENT, TB_SUBSCRIPTION, TB_BILLING_ITEM | Phase 1 | 가디언 유료화 |
| 🟠 P1 | TB_CHAT_MESSAGE, TB_CHAT_POLL, TB_CHAT_POLL_VOTE, TB_CHAT_READ_STATUS | Phase 1 | 채팅 기능 |
| 🟠 P1 | TB_NOTIFICATION, TB_NOTIFICATION_SETTING | Phase 1 | 알림 시스템 |
| 🟠 P1 | **TB_LOCATION** (구현완료), TB_STAY_POINT, **TB_SESSION_MAP_IMAGE** (구현완료), **TB_PLANNED_ROUTE**, **TB_ROUTE_DEVIATION** | Phase 1 | 이동경로 추적 |
| 🟡 P2 | TB_USER_CONSENT, TB_MINOR_CONSENT | Phase 2 | 동의 관리 |
| 🟡 P2 | TB_LOCATION_ACCESS_LOG, TB_LOCATION_SHARING_PAUSE_LOG | Phase 2 | 위치정보법 준수 |
| 🟡 P2 | TB_EMERGENCY_NUMBER, TB_SOS_RESCUE_LOG, TB_SOS_CANCEL_LOG | Phase 2 | SOS 구조 연동 |
| 🟡 P2 | TB_B2B_CONTRACT, TB_B2B_SCHOOL, TB_B2B_INVITE_BATCH, TB_B2B_MEMBER_LOG | Phase 2 | B2B |
| 🟡 P2 | TB_REFUND_LOG | Phase 2 | 환불 관리 |
| 🟡 P2 | **TB_GUARDIAN_LOCATION_REQUEST**, **TB_GUARDIAN_SNAPSHOT**, TB_TRIP 컬럼 추가 (`b2b_contract_id`, `has_minor_members`) | Phase 2 | 프라이버시 등급별 가디언 기능 완성 |
| 🟢 P3 | TB_DATA_DELETION_LOG, TB_DATA_PROVISION_LOG | Phase 3 | 법적 감사 기록 |
| 🔴 P0 | TB_LOCATION_SHARING (trip_id + visibility_type), TB_GUARDIAN_LINK (부분 인덱스 2개), TB_PAYMENT/SUBSCRIPTION/BILLING_ITEM (CHECK 업데이트), TB_GROUP_MEMBER captain 유일성 인덱스 | Phase 1 | v3.5 비즈니스 원칙 P0 정합 |
| 🟠 P1 | **TB_LOCATION_SCHEDULE** | Phase 1 | 위치 공유 일정 (§04.3) — 요일/시간대별 공유 ON/OFF |
| 🟠 P1 | **TB_ATTENDANCE_CHECK**, **TB_ATTENDANCE_RESPONSE** | Phase 1 | 출석 체크 기능 |
| 🟠 P1 | TB_TRIP (reactivated_at, reactivation_count + CHECK) | Phase 1 | 여행 재활성화 추적 (§02.6) |
| 🟡 P2 | TB_USER (deletion_requested_at), TB_GUARDIAN_PAUSE (group_id/guardian_user_id), TB_CHAT_MESSAGE/REFUND_LOG/DATA_PROVISION_LOG FK, TB_GUARDIAN_LOCATION_REQUEST (auto_responded) | Phase 2 | v3.5 무결성 패치 |
| 🟢 P3 | TB_B2B_CONTRACT (max_trips), TB_GEOFENCE (is_active 인덱스) | Phase 3 | v3.5 Appendix C 정합 보완 |
| 🔴 P0 | TB_EMERGENCY, TB_EMERGENCY_RECIPIENT, TB_CHAT_ROOM | Phase 1 | v3.6 긴급 상황 통합 관리 + 채팅방 컨테이너 |
| 🟠 P1 | TB_GEOFENCE_EVENT, TB_GEOFENCE_PENALTY, TB_FCM_TOKEN, TB_SAFETY_CHECKIN | Phase 1 | v3.6 지오펜스 이벤트, FCM 다중 디바이스, 안전 체크인 |
| 🟠 P1 | TB_AI_USAGE, TB_NO_RESPONSE_EVENT | Phase 1 | v3.6 AI 사용 추적, 무응답 이벤트 |
| 🟡 P2 | TB_B2B_ORGANIZATION, TB_B2B_ADMIN, TB_B2B_DASHBOARD_CONFIG | Phase 2 | v3.6 B2B 조직/관리자/대시보드 |
| 🟡 P2 | TB_REDEEM_CODE, TB_NOTIFICATION_PREFERENCE | Phase 2 | v3.6 리딤 코드, 알림 세부 설정 |
| 🟢 P3 | TB_PARENTAL_CONSENT, TB_COUNTRY_SAFETY, TB_MOVEMENT_SESSION | Phase 3 | v3.6 보호자 동의, 국가 안전, 이동 세션 집계 |

---

## 12. 오프라인 대응

> 비즈니스 원칙 v5.1 §15 오프라인 기본 정책

| 테이블/노드 | 오프라인 시 로컬 저장 | 동기화 전략 |
|--------|:-----------------:|-----------|
| TB_LOCATION (구 TB_LOCATION_LOG) | ✅ SQLite 로컬 큐 | 온라인 복귀 시 배치 업로드 (`is_offline=TRUE` 플래그 포함) |
| TB_HEARTBEAT | ✅ 마지막 1건 로컬 저장 | LAST_BEACON 이벤트 발생 |
| TB_CHAT_MESSAGE | ✅ 로컬 큐잉 | 온라인 복귀 시 순서 보장 발송 |
| TB_SCHEDULE | ✅ 로컬 캐시 | 서버 timestamp 기준 충돌 해결 |
| TB_NOTIFICATION | ❌ | 온라인 복귀 시 서버에서 일괄 fetch |
| TB_SOS_EVENT | ✅ SMS 폴백 | SOS는 오프라인에서도 SMS 발송 시도 |
| RTDB guardian_messages | ✅ RTDB offline_queue | 온라인 복귀 시 자동 동기화 (Firebase SDK) |
| RTDB location_realtime | ✅ RTDB offline_queue | 온라인 복귀 시 배치 flush |

**동기화 우선순위** (온라인 복귀 시):
```
1. SOS 이벤트 → 2. 가디언 긴급 알림 → 3. 위치 데이터 → 4. 일정 → 5. 채팅 → 6. 로그
```

---

## 13. 검증 체크리스트

| # | 체크 항목 | 상태 |
|:-:|----------|:----:|
| 1 | 문서 목적과 적용 범위가 명시되어 있다 | ✅ |
| 2 | 기준 문서(비즈니스 원칙 v5.1)가 명시되어 있다 | ✅ |
| 3 | 역할별(캡틴/크루장/크루/가디언) 접근 권한이 정의되어 있다 (§7) | ✅ |
| 4 | 프라이버시 등급별 동작 차이가 정의되어 있다 (§8) | ✅ |
| 5 | 에러 및 엣지케이스 처리가 포함되어 있다 (§10 알려진 이슈) | ✅ |
| 6 | 검증 체크리스트가 포함되어 있다 (§13) | ✅ |
| 7 | 기존 문서 대비 변경/확장 사항이 명시되어 있다 (§1.3) | ✅ |
| 8 | DB 스키마가 필요한 경우 테이블 구조가 포함되어 있다 | ✅ (54개 + RTDB) — v3.5: TB_LOCATION_SCHEDULE·TB_ATTENDANCE_CHECK·TB_ATTENDANCE_RESPONSE 추가 |
| 9 | 구현 우선순위(P0~P3)와 Phase 배치가 포함되어 있다 (§11) | ✅ |
| 10 | 오프라인 동작이 해당되는 경우 대응 방안이 포함되어 있다 (§12) | ✅ |
| 11 | 가디언 과금(무료/유료)이 해당되는 경우 과금 분기가 포함되어 있다 | ✅ (TB_GUARDIAN_LINK §4.10, TB_PAYMENT §4.40) |
| 12 | 여행 기간 제한(15일)이 해당되는 경우 제한 처리가 포함되어 있다 | ✅ (TB_TRIP CHECK §4.4) |
| 13 | Firebase RTDB 스키마가 문서화되어 있다 | ✅ (§4.47~4.50) |
| 14 | 결제/과금 테이블이 비즈니스 원칙 v5.1 §09와 연계되어 있다 | ✅ (§4.39~4.42) |
| 15 | B2B 프레임워크 테이블이 비즈니스 원칙 v5.1 §12와 연계되어 있다 | ✅ (§4.43~4.46) |
| 16 | 프라이버시 등급별 가디언 기능(긴급 위치 요청, 30분 스냅샷)이 DB에 정의되어 있다 | ✅ (§4.11a TB_GUARDIAN_LOCATION_REQUEST, §4.11b TB_GUARDIAN_SNAPSHOT) |
| 17 | TB_TRIP에 B2B 계약 연결 컬럼 및 미성년자 포함 여부 컬럼이 포함되어 있다 | ✅ (§4.4 b2b_contract_id, has_minor_members) |
| 18 | 위치 공유 가시성 타입(visibility_type)이 DB에 정의되어 있다 | ✅ (§4.15 TB_LOCATION_SHARING.visibility_type CHECK) |
| 19 | 위치 공유 일정(TB_LOCATION_SCHEDULE)이 DB에 정의되어 있다 | ✅ (§4.15a — 요일/시간대별 공유 ON/OFF) |
| 20 | 출석 체크(TB_ATTENDANCE_CHECK/RESPONSE)가 DB에 정의되어 있다 | ✅ (§4.22a/b — captain/crew_chief 시작, 멤버 응답) |
| 21 | 캡틴 유일성이 DB 부분 인덱스로 강제된다 | ✅ (idx_group_member_captain WHERE member_role='captain') |
| 22 | 계정 삭제 7일 유예 기간이 DB에 정의되어 있다 | ✅ (TB_USER.deletion_requested_at §4.1) |
| 23 | 구현 엔티티와 문서 테이블 1:1 매핑이 완료되어 있다 | ✅ (v3.6 — 71개 테이블, 24개 엔티티 파일) |
| 24 | 신규 도메인 N(AI)이 정의되어 있다 | ✅ (§4.52 TB_AI_USAGE) |

---

## 부록 A: 테이블 전체 목록 (PostgreSQL 54개)

| # | 테이블명 | 도메인 | v3.0 상태 | 출처 문서 |
|:-:|---------|:------:|:---------:|----------|
| 1 | TB_USER | A | 기존+확장 | init-schema, 미성년자 보호 |
| 2 | TB_EMERGENCY_CONTACT | A | 기존 | 프로필 원칙 |
| 3 | TB_GROUP | B | 기존+확장 | init-schema |
| 4 | TB_TRIP | B | 기존+확장 | init-schema, 비즈니스 v5.1 |
| 5 | TB_GROUP_MEMBER | B | 기존+확장 | init-schema (trip_id NOT NULL 확정) |
| 6 | TB_INVITE_CODE | B | 기존+확장 | init-schema, B2B batch_id 추가 |
| 7 | **TB_TRIP_SETTINGS** | B | **신규** | guardian-migration, 가디언 메시지 |
| 8 | **TB_COUNTRY** | B | **신규** | 비즈니스 원칙 v5.1, countries API |
| 9 | TB_GUARDIAN | C | 기존+확장 | guardian-migration, 비즈니스 v5.1 |
| 10 | **TB_GUARDIAN_LINK** | C | **신규** | guardian-migration (실제 구현 반영) |
| 11 | TB_GUARDIAN_PAUSE | C | 기존+확장 | 설정 메뉴 원칙 (link_id 참조 추가) |
| 50 | **TB_GUARDIAN_LOCATION_REQUEST** | C | **신규 (v3.2)** | 비즈니스 원칙 v5.1 부록 C, 시나리오 5 |
| 51 | **TB_GUARDIAN_SNAPSHOT** | C | **신규 (v3.2)** | 비즈니스 원칙 v5.1 부록 C, 시나리오 4 |
| 12 | TB_SCHEDULE | D | 기존 | init-schema |
| 13 | TB_TRAVEL_SCHEDULE | D | 기존+확장 | init-schema (lat/lng 확정) |
| 14 | TB_GEOFENCE | D | 기존 | init-schema |
| 15 | TB_LOCATION_SHARING | E | 기존 | init-schema |
| 16 | **TB_LOCATION** (구 TB_LOCATION_LOG) | E | **구현완료** | database-schema.sql, 이동기록 원칙 |
| 17 | TB_STAY_POINT | E | 기존(미생성) | 이동기록 원칙 |
| 47 | **TB_SESSION_MAP_IMAGE** | E | **신규(구현완료)** | database-schema.sql, map-image.service.ts |
| 48 | **TB_PLANNED_ROUTE** | E | **신규** | database-schema.sql, Route Deviation |
| 49 | **TB_ROUTE_DEVIATION** | E | **신규** | database-schema.sql, Route Deviation |
| 18 | TB_HEARTBEAT | F | 기존(미생성) | SOS 원칙 |
| 19 | TB_SOS_EVENT | F | 기존(미생성) | SOS 원칙 |
| 20 | TB_POWER_EVENT | F | 기존(미생성) | SOS 원칙 |
| 21 | TB_SOS_RESCUE_LOG | F | 기존(미생성) | 긴급 구조 연동 원칙 |
| 22 | TB_SOS_CANCEL_LOG | F | 기존(미생성) | 긴급 구조 연동 원칙 |
| 23 | TB_CHAT_MESSAGE | G | 기존(미생성) | 채팅탭 원칙 |
| 24 | TB_CHAT_POLL | G | 기존(미생성) | 채팅탭 원칙 |
| 25 | TB_CHAT_POLL_VOTE | G | 기존(미생성) | 채팅탭 원칙 |
| 26 | TB_CHAT_READ_STATUS | G | 기존(미생성) | 채팅탭 원칙 |
| 27 | TB_NOTIFICATION | H | 기존(미생성) | 알림 원칙 |
| 28 | TB_NOTIFICATION_SETTING | H | 기존(미생성) | 알림 원칙 |
| 29 | TB_EVENT_NOTIFICATION_CONFIG | H | 기존 | init-schema |
| 30 | TB_USER_CONSENT | I | 기존(미생성) | 개인정보처리방침 원칙 |
| 31 | TB_MINOR_CONSENT | I | 기존(미생성)+확장 | 미성년자 보호 원칙 (b2b_contract_id 추가) |
| 32 | TB_LOCATION_ACCESS_LOG | I | 기존(미생성) | LBS 이용약관 원칙 |
| 33 | TB_LOCATION_SHARING_PAUSE_LOG | I | 기존(미생성)+확장 | LBS 이용약관 원칙 (link_id 추가) |
| 34 | TB_DATA_DELETION_LOG | I | 기존(미생성) | 개인정보처리방침 원칙 |
| 35 | TB_DATA_PROVISION_LOG | I | 기존(미생성) | 긴급 구조 연동 원칙 |
| 36 | TB_EVENT_LOG | J | 기존+확장 | init-schema (guardian event 추가) |
| 37 | TB_LEADER_TRANSFER_LOG | J | 기존+확장 | init-schema (from_user_new_role 추가) |
| 38 | TB_EMERGENCY_NUMBER | J | 기존(미생성) | 긴급 구조 연동 원칙 |
| 39 | **TB_SUBSCRIPTION** | K | **신규** | 비즈니스 원칙 v5.1 §11 |
| 40 | **TB_PAYMENT** | K | **신규** | 비즈니스 원칙 v5.1 §09.3, §11 |
| 41 | **TB_BILLING_ITEM** | K | **신규** | 비즈니스 원칙 v5.1 §11 |
| 42 | **TB_REFUND_LOG** | K | **신규** | 비즈니스 원칙 v5.1 §09.6 |
| 43 | **TB_B2B_CONTRACT** | L | **신규** | 비즈니스 원칙 v5.1 §12 |
| 44 | **TB_B2B_SCHOOL** | L | **신규** | 비즈니스 원칙 v5.1 §12 |
| 45 | **TB_B2B_INVITE_BATCH** | L | **신규** | 비즈니스 원칙 v5.1 §12.3 |
| 46 | **TB_B2B_MEMBER_LOG** | L | **신규** | 비즈니스 원칙 v5.1 §12 |
| 52 | **TB_LOCATION_SCHEDULE** | E | **신규 (v3.5)** | 비즈니스 원칙 v5.1 §04.3, 위치 공유 일정 (요일/특정 일자/전체 기간) |
| 53 | **TB_ATTENDANCE_CHECK** | B | **신규 (v3.5)** | 비즈니스 원칙 v5.1 §05.5 출석 체크 |
| 54 | **TB_ATTENDANCE_RESPONSE** | B | **신규 (v3.5)** | 비즈니스 원칙 v5.1 §05.5 출석 체크 응답 |
| 55 | **TB_PARENTAL_CONSENT** | A | **신규 (v3.6)** | user.entity.ts, 미성년자 보호 |
| 56 | **TB_COUNTRY_SAFETY** | B | **신규 (v3.6)** | country-safety.entity.ts, MOFA 연동 |
| 57 | **TB_GEOFENCE_EVENT** | D | **신규 (v3.6)** | geofence.entity.ts |
| 58 | **TB_GEOFENCE_PENALTY** | D | **신규 (v3.6)** | geofence.entity.ts |
| 59 | **TB_MOVEMENT_SESSION** | E | **신규 (v3.6)** | location.entity.ts |
| 60 | **TB_EMERGENCY** | F | **신규 (v3.6)** | emergency.entity.ts, 긴급 상황 통합 |
| 61 | **TB_EMERGENCY_RECIPIENT** | F | **신규 (v3.6)** | emergency.entity.ts |
| 62 | **TB_NO_RESPONSE_EVENT** | F | **신규 (v3.6)** | emergency.entity.ts |
| 63 | **TB_SAFETY_CHECKIN** | F | **신규 (v3.6)** | emergency.entity.ts |
| 64 | **TB_CHAT_ROOM** | G | **신규 (v3.6)** | chat.entity.ts |
| 65 | **TB_FCM_TOKEN** | H | **신규 (v3.6)** | notification.entity.ts |
| 66 | **TB_NOTIFICATION_PREFERENCE** | H | **신규 (v3.6)** | notification.entity.ts |
| 67 | **TB_REDEEM_CODE** | K | **신규 (v3.6)** | payment.entity.ts |
| 68 | **TB_B2B_ORGANIZATION** | L | **신규 (v3.6)** | b2b.entity.ts |
| 69 | **TB_B2B_ADMIN** | L | **신규 (v3.6)** | b2b.entity.ts |
| 70 | **TB_B2B_DASHBOARD_CONFIG** | L | **신규 (v3.6)** | b2b.entity.ts |
| 71 | **TB_AI_USAGE** | N | **신규 (v3.6)** | ai.entity.ts, AI 기능 사용 추적 |

**RTDB 노드 (5개)**:

| # | 노드명 | 용도 |
|:-:|--------|------|
| M1 | guardian_messages | 가디언-멤버 1:1 메시지 |
| M2 | location_realtime | 실시간 위치 스트리밍 |
| M3 | presence | 유저 온라인 상태 |
| M4 | offline_queue | 오프라인 큐 |
| **M5** | **realtime_users** | **이동 세션 활성 상태 추적 (active_session_id)** |

---

## 부록 B: 기능 원칙 문서 → 테이블 매핑

| 기능 원칙 문서 | 참조하는 테이블 |
|--------------|--------------|
| SafeTrip_비즈니스_원칙_v5_1 | TB_TRIP (`b2b_contract_id`, `has_minor_members`, `reactivated_at`, `reactivation_count` 포함), TB_GUARDIAN, TB_GUARDIAN_LINK, TB_GUARDIAN_LOCATION_REQUEST, TB_GUARDIAN_SNAPSHOT, TB_GROUP_MEMBER, TB_PAYMENT, TB_SUBSCRIPTION, TB_LOCATION_SCHEDULE, TB_ATTENDANCE_CHECK, TB_ATTENDANCE_RESPONSE |
| SafeTrip_SOS_원칙_v1_0 | TB_HEARTBEAT, TB_SOS_EVENT, TB_POWER_EVENT, TB_SOS_RESCUE_LOG, TB_SOS_CANCEL_LOG |
| SafeTrip_긴급_구조기관_연동_원칙_v1_0 | TB_EMERGENCY_NUMBER, TB_SOS_RESCUE_LOG, TB_DATA_PROVISION_LOG |
| SafeTrip_미성년자_보호_원칙_v1_0 | TB_USER (minor_status), TB_MINOR_CONSENT, TB_GUARDIAN_LINK, TB_GUARDIAN_PAUSE |
| SafeTrip_채팅탭_원칙_v1_0 | TB_CHAT_MESSAGE, TB_CHAT_POLL, TB_CHAT_POLL_VOTE, TB_CHAT_READ_STATUS |
| SafeTrip_알림버튼_원칙_v1_0 | TB_NOTIFICATION, TB_NOTIFICATION_SETTING, TB_EVENT_NOTIFICATION_CONFIG |
| SafeTrip_개인정보처리방침_원칙_v1_0 | TB_USER_CONSENT, TB_DATA_DELETION_LOG |
| SafeTrip_위치기반서비스_이용약관_원칙_v1_0 | TB_LOCATION_ACCESS_LOG, TB_LOCATION_SHARING_PAUSE_LOG |
| SafeTrip_멤버별_이동기록_화면_원칙_v1_0 | **TB_LOCATION** (실제 구현, 구 TB_LOCATION_LOG), TB_STAY_POINT, **TB_SESSION_MAP_IMAGE**, **TB_PLANNED_ROUTE**, **TB_ROUTE_DEVIATION** |
| SafeTrip_설정_메뉴_원칙_v1_0 | TB_GUARDIAN_PAUSE, TB_TRIP_SETTINGS |
| SafeTrip_초대코드_원칙_v1_0 | TB_INVITE_CODE, TB_B2B_INVITE_BATCH |
| SafeTrip_프로필화면_원칙_v1_0 | TB_EMERGENCY_CONTACT |
| 12_일정탭_원칙_v1_0 | TB_TRAVEL_SCHEDULE, TB_SCHEDULE, TB_GEOFENCE |
| 비즈니스_원칙_v5_0_§11 | TB_PAYMENT, TB_SUBSCRIPTION, TB_BILLING_ITEM, TB_REFUND_LOG |
| 비즈니스_원칙_v5_0_§12 | TB_B2B_CONTRACT, TB_B2B_SCHOOL, TB_B2B_INVITE_BATCH, TB_B2B_MEMBER_LOG |

---

## 부록 C: v2.0 → v3.0 상세 변경 이력

| 변경 유형 | 대상 | 변경 내용 |
|----------|------|----------|
| **신규 테이블** | TB_TRIP_SETTINGS | 여행 설정 (captain_receive_guardian_msg 포함) |
| **신규 테이블** | TB_COUNTRY | 국가 목록 (countries API 500 에러 해소) |
| **신규 테이블** | TB_GUARDIAN_LINK | 가디언-멤버 연결 (실제 구현 반영, 컬럼명 정정) |
| **신규 테이블** | TB_PAYMENT, TB_SUBSCRIPTION, TB_BILLING_ITEM, TB_REFUND_LOG | 결제/과금 도메인 |
| **신규 테이블** | TB_B2B_CONTRACT, TB_B2B_SCHOOL, TB_B2B_INVITE_BATCH, TB_B2B_MEMBER_LOG | B2B 도메인 |
| **신규 섹션** | RTDB 도메인 [M] | Firebase RTDB 스키마 공식 문서화 |
| **컬럼 추가** | TB_GROUP.group_type | b2b_school, b2b_corporate 구분 |
| **컬럼 추가** | TB_TRIP.sharing_mode | forced / voluntary 위치 공유 모드 |
| **컬럼 확정** | TB_TRIP (CHECK 제약) | 15일 제한 CHECK 적용 확정 |
| **컬럼 확정** | TB_GROUP_MEMBER.trip_id | NOT NULL 확정 + INDEX 추가 |
| **컬럼 확정** | TB_GROUP_MEMBER 권한 컬럼 | is_admin, can_edit_schedule 등 6개 복원 |
| **컬럼 추가** | TB_GUARDIAN.payment_id | 결제 연동 FK 추가 |
| **컬럼 추가** | TB_GUARDIAN_PAUSE.link_id | TB_GUARDIAN_LINK FK 추가 |
| **컬럼 추가** | TB_LEADER_TRANSFER_LOG.from_user_new_role | 강등 후 역할 추적 |
| **컬럼 추가** | TB_INVITE_CODE.b2b_batch_id | B2B 일괄 초대 연동 |
| **컬럼 추가** | TB_MINOR_CONSENT.b2b_contract_id | B2B 학교 계약 연동 |
| **컬럼 추가** | TB_LOCATION_SHARING_PAUSE_LOG.link_id | TB_GUARDIAN_LINK FK 추가 |
| **스키마 확정** | TB_TRAVEL_SCHEDULE | location_lat/lng 명시 추가 (서비스 레이어 오류 방지) |
| **버그 수정** | TB_EVENT_LOG.event_type | guardian_linked, guardian_unlinked, guardian_paused 추가 |
| **이슈 해소** | v2.0 Known Issue #1~5 | 전부 해소 (§10 참조) |
| **테이블 확장** | TB_LOCATION_LOG → **TB_LOCATION** | 실제 구현 반영 — PostGIS geom, movement_session_id, activity_type, i_idx 등 대폭 확장 |
| **신규 테이블** | **TB_SESSION_MAP_IMAGE** | 이동 세션 지도 이미지 캐시 (Firebase Storage URL 우선) |
| **신규 테이블** | **TB_PLANNED_ROUTE** | Route Deviation Detection용 사전 계획 경로 |
| **신규 테이블** | **TB_ROUTE_DEVIATION** | 경로 이탈 감지 로그 (심각도 4단계: low/medium/high/critical) |
| **컬럼 추가** | TB_EVENT_LOG.movement_session_id | 이동 세션 이벤트 집계 (`session_event` type 지원) |

### v3.1 (2026-03-01) — 이동경로 도메인 실제 구현 반영

| 변경 유형 | 대상 | 변경 내용 |
|----------|------|----------|
| **테이블 교체** | TB_LOCATION_LOG → **TB_LOCATION** | 실제 구현 반영 (PostGIS, movement_session_id, Activity Recognition) |
| **신규 테이블** | **TB_SESSION_MAP_IMAGE** | 이동 세션 지도 이미지 캐시 |
| **신규 테이블** | **TB_PLANNED_ROUTE** | 계획 경로 (Route Deviation 원점) |
| **신규 테이블** | **TB_ROUTE_DEVIATION** | 경로 이탈 감지 로그 |
| **RTDB 노드** | M5 `realtime_users` | active_session_id 추적 |

### v3.2 (2026-03-01) — 비즈니스 원칙 v5.0 완전 정합 검토 반영

| 변경 유형 | 대상 | 변경 내용 |
|----------|------|----------|
| **신규 테이블** | **TB_GUARDIAN_LOCATION_REQUEST** | 긴급 위치 요청 (프라이버시 우선 등급, §05.5, 시나리오 5) |
| **신규 테이블** | **TB_GUARDIAN_SNAPSHOT** | 가디언 위치 스냅샷 30분 (표준 등급 비공유 시간대, §05.4, 시나리오 4) |
| **컬럼 추가** | **TB_TRIP.b2b_contract_id** | B2B 계약 연결 (NULL=B2C, 부록 C §v4.0) |
| **컬럼 추가** | **TB_TRIP.has_minor_members** | 미성년자 포함 여부 (safety_first 강제, §13.2) |
| **도메인 C** | 테이블 수 3→5 | 신규 2개 추가 |
| **합계** | PostgreSQL 49→51개 | 신규 2개 테이블 추가 |

### v3.3 (2026-03-01) — DB 무결성 패치 (TIMESTAMP→TIMESTAMPTZ, FK, ON DELETE)

| 변경 유형 | 대상 | 변경 내용 |
|----------|------|----------|
| **타입 수정** | TB_SESSION_MAP_IMAGE, TB_PLANNED_ROUTE, TB_ROUTE_DEVIATION (10건) | TIMESTAMP → TIMESTAMPTZ (UTC 기준 명시) |
| **FK 추가** | TB_LOCATION_ACCESS_LOG.trip_id, TB_LOCATION_SHARING_PAUSE_LOG.trip_id | VARCHAR → UUID + FK |
| **FK + ON DELETE 추가** | SOS/채팅/동의/B2B 테이블 15건 | 누락 FK + ON DELETE 정책 명시 |
| **nullable 전환** | TB_GUARDIAN_LINK.guardian_id | NOT NULL 제거 (미가입 가디언 초대 지원) |
| **컬럼 추가** | TB_GUARDIAN_LOCATION_REQUEST.trip_id, TB_GUARDIAN_SNAPSHOT.trip_id | trip_id 컬럼 추가 |
| **컬럼 추가** | TB_EVENT_LOG.movement_session_id | 이동 세션 이벤트 집계 (`session_event` type 지원) |
| **합계** | v3.3 패치 6종 | 이슈 #6~11 전부 해소 |

### v3.5 (2026-03-01) — 비즈니스 원칙 v5.0 전면 정합 검토 반영 (기준: v5.0)

| 변경 유형 | 대상 | 변경 내용 |
|----------|------|----------|
| **신규 테이블** | **TB_LOCATION_SCHEDULE** | 위치 공유 일정 (§04.3) — 요일별/시간대별 공유 ON/OFF |
| **신규 테이블** | **TB_ATTENDANCE_CHECK** | 출석 체크 — captain/crew_chief가 시작, deadline_at 설정 |
| **신규 테이블** | **TB_ATTENDANCE_RESPONSE** | 출석 체크 응답 — 멤버별 present/absent/unknown |
| **컬럼 추가** | TB_LOCATION_SHARING: trip_id, visibility_type | 여행별 가시성 타입 (all/admin_only/specified) |
| **컬럼 추가** | TB_TRIP: reactivated_at, reactivation_count + CHECK(≤1) | 여행 재활성화 추적 (§02.6, completed→active 최대 1회/24h) |
| **컬럼 추가** | TB_USER: deletion_requested_at | 계정 삭제 7일 유예 기산점 (§06) |
| **컬럼 추가** | TB_GUARDIAN_PAUSE: group_id, guardian_user_id | Appendix C 비정규화 정합 (link 없이 조회 지원) |
| **컬럼 추가** | TB_GUARDIAN_LOCATION_REQUEST: auto_responded, auto_response_reason | 자동 응답(standard 등급 자동/SOS override) 추적 |
| **컬럼 추가** | TB_B2B_CONTRACT: max_trips | Appendix C §12 정합 |
| **컬럼 복원** | TB_GEOFENCE: is_active | 01-init-schema 컬럼 문서 명시 복원 + 부분 인덱스 추가 |
| **FK 추가** | TB_CHAT_MESSAGE.sender_id → TB_USER | ON DELETE SET NULL |
| **FK 추가** | TB_REFUND_LOG.user_id → TB_USER + nullable | ON DELETE SET NULL |
| **FK 추가** | TB_DATA_PROVISION_LOG: sos_event_id, processed_by_user_id | FK + ON DELETE SET NULL |
| **CHECK 교체** | TB_PAYMENT.payment_type | Appendix C 정합 (trip_base/addon_* 5종 + b2b_contract) |
| **CHECK 교체** | TB_SUBSCRIPTION.plan_type | Appendix C 정합 (free/trip_base/addon_*/b2b_school/b2b_corporate) |
| **CHECK 교체** | TB_BILLING_ITEM.item_type | Appendix C 정합 (trip_base/addon_*/b2b_seat/movement_session) |
| **인덱스 추가** | TB_GUARDIAN_LINK | 부분 인덱스 2개 (active: guardian_id NOT NULL, pending: guardian_phone NOT NULL) |
| **인덱스 추가** | TB_GROUP_MEMBER | captain 유일성 부분 인덱스 (WHERE member_role='captain' AND status='active') |
| **인덱스 추가** | TB_GUARDIAN_LOCATION_REQUEST | hourly 복합 인덱스 (guardian_user_id, requested_at DESC) |
| **합계** | PostgreSQL 51→54개 | 신규 3개 테이블, 총 18건 이슈 해소 |

### v3.5.1 (2026-03-01) — 비즈니스 원칙 v5.1 정합 보완

| 변경 유형 | 대상 | 변경 내용 |
|----------|------|----------|
| **기준 문서 갱신** | 문서 전체 | 기준 문서 SafeTrip_비즈니스_원칙 v5.0 → **v5.1** |
| **도메인 집계 수정** | §3.1 도메인 구조 | "v3.3의 51개" → **"v3.5의 54개"**, B 도메인 6→8, E 도메인 7→8, TB_ATTENDANCE_CHECK/RESPONSE·TB_LOCATION_SCHEDULE 목록 반영 |
| **ERD 추가** | §3.2 ERD 관계도 | TB_ATTENDANCE_CHECK, TB_ATTENDANCE_RESPONSE 관계 신규 정의 |
| **컬럼 추가** | TB_LOCATION_SCHEDULE: **specific_date DATE** | 비즈니스 원칙 v5.1 §04.3 "특정 일자에만 선택적 적용" 옵션 지원. CONSTRAINT chk_schedule_scope (day_of_week, specific_date 상호 배타) 추가. idx_location_schedule_date 부분 인덱스 추가 |
| **컬럼 추가** | TB_REFUND_LOG: **refund_policy VARCHAR(30)** | 비즈니스 원칙 v5.1 §09.7 환불 규칙 추적 (planning_full / active_24h_half / active_no_refund / completed_no_refund / admin_override) |
| **설명 보완** | TB_LOCATION_SHARING | visibility_type='specified' 시 다중 멤버 지정 방법(N행 패턴) 및 멤버 탈퇴 시 연쇄 처리 의무 명시 |
| **합계** | 6건 보완 | 비즈니스 원칙 v5.1 완전 정합 달성 |

### v3.5.1p (2026-03-02) — 비즈니스 원칙 v5.1 기준 불일치 항목 점검 및 수정

| 변경 유형 | 대상 | 변경 내용 |
|----------|------|----------|
| **버전 참조 수정** | 문서 본문 전체 | `비즈니스 원칙 v5.0` 잔존 참조 26건 → **v5.1** 로 일괄 수정 (변경이력 항목·역사적 기록 제외) |
| **수정 대상** | ERD 주석, SQL 인라인 주석, 출처 주석, 반영사항 블록, 부록 A 테이블 목록, §11 구현 우선순위, §12 오프라인 대응 | 현재 스키마 주석 전체를 기준 문서 v5.1로 통일 |

---

> **본 문서는 SafeTrip DB 설계의 단일 진실 공급원(Single Source of Truth)이다.**
> 테이블 구조 변경 시 반드시 본 문서를 먼저 갱신하고, 마이그레이션 파일을 작성한다.
> 비즈니스 원칙 메이저 변경 시 본 문서도 함께 갱신해야 한다 (§5.4 변경 전파 규칙 참조).
