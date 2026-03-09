---
date: '2026-03-08'
version: v3.7
part: 1/3
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
> [Part 1: 개요·ERD·테이블 A~F](07_T2_DB_설계_및_관계_v3_7_Part1.md) |
> [Part 2: 테이블 G~N·인덱스](07_T2_DB_설계_및_관계_v3_7_Part2.md) |
> [Part 3: 운영·부록](07_T2_DB_설계_및_관계_v3_7_Part3.md)


# SafeTrip — DB 설계 및 관계 v3.7

## 1. 문서 개요

### 1.1 목적 및 범위

본 문서는 SafeTrip 앱의 전체 데이터베이스 설계를 정의한다. v2.0에서 미해결로 남은 이슈를 전부 해소하고, 비즈니스 원칙 v5.1의 과금 모델(§09), B2B 프레임워크(§12), 미성년자 보호(§10), 데이터 생명주기(§13), 삭제 및 비활성화(§14) 정책을 DB 스키마에 완전히 반영한다. Firebase RTDB 스키마도 처음으로 공식 문서화한다.

### 1.2 기준 문서

| 상위 문서 | 버전 | 참조 내용 |
|----------|:----:|----------|
| SafeTrip_비즈니스_원칙 | **v5.1** | 역할 체계, 프라이버시 등급, 과금 모델, 여행 기간 정책, 가디언 유/무료 구분, B2B 프레임워크, 미성년자 보호, 데이터 생명주기, 삭제 및 비활성화 원칙 |
| SafeTrip_마스터_원칙_거버넌스 | v2.0 | 문서 계층, 변경 전파 규칙, 품질 체크리스트 |
| 03_아키텍처_구조 | v1.0 | NestJS + Firebase + PostgreSQL 기술 스택 |
| SafeTrip_긴급_구조기관_연동_원칙 | v1.0 | TB_SOS_RESCUE_LOG, TB_EMERGENCY_NUMBER |
| SafeTrip_미성년자_보호_원칙 | v1.0 | TB_MINOR_CONSENT, TB_USER 미성년자 컬럼 |
| SafeTrip_개인정보처리방침_원칙 | v1.0 | TB_USER_CONSENT, TB_DATA_DELETION_LOG |
| SafeTrip_위치기반서비스_이용약관_원칙 | v1.0 | TB_LOCATION_ACCESS_LOG, TB_LOCATION_SHARING_PAUSE_LOG |

### 1.3 버전별 변경 요약

#### v2.0 → v3.0

| 항목 | v2.0 | v3.0 |
|------|:----:|:----:|
| 테이블 수 | 38개 | **71개** (v3.6 기준) |
| 도메인 수 | 10개 | **13개** |
| 비즈니스 원칙 기준 | v5.0 (참조만) | **v5.0 완전 반영** |
| RTDB 스키마 | 미포함 | **신규 도메인 [M]** |
| 결제/과금 테이블 | 미포함 | **신규 도메인 [K] (4개)** |
| B2B 테이블 | 미포함 | **신규 도메인 [L] (4개)** |
| TB_GUARDIAN_LINK | 미정의 | **신규 (실제 구현 반영)** |
| TB_TRIP_SETTINGS | 미정의 | **신규** |
| TB_COUNTRY | 미정의 | **신규** |
| 알려진 이슈 | 5개 미해결 | **0개 (전부 해소)** |

#### v3.6 → v3.7

| 항목 | v3.6 | v3.7 |
|------|:----:|:----:|
| 테이블 수 | 71개 | **84개** |
| 도메인 수 | 14개 | **14개** (변동 없음) |
| TB_COUNTRY_SAFETY | 존재 | **제거** (DB에 미존재) |
| [C] 가디언 | 5개 | **7개** (+tb_guardian_message, +tb_guardian_release_request) |
| [D] 일정 | 5개 | **12개** (+스케줄 협업 테이블 7개) |
| [G] 채팅 | 5개 | **6개** (+tb_chat_reaction) |
| [J] 운영/로그 | 3개 | **5개** (+tb_country_emergency_contact, +tb_safety_guide_cache) |
| [N] AI | 1개 | **3개** (+tb_ai_subscription, +tb_ai_usage_log) |
| 기존 테이블 컬럼 | — | **22개 테이블 컬럼 추가/수정** |
| 구현 정합성 | 문서↔DB 불일치 | **실제 DB 기준 전면 재정렬** |

---

## 2. DB 환경

### 2.1 PostgreSQL (주 데이터베이스)

| 항목 | 값 |
|------|-----|
| DBMS | PostgreSQL 15 + PostGIS (지리 데이터 지원) |
| 개발 DB | `safetrip_dev` |
| 포트 | 5432 |
| 스키마 파일 | `safetrip-server-api/scripts/local/01-init-schema.sql` |
| 인코딩 | UTF-8 |
| 타임존 | UTC (클라이언트에서 로컬 변환) |

### 2.2 Firebase Realtime Database (실시간 데이터)

| 항목 | 값 |
|------|-----|
| 서비스 | Firebase RTDB |
| URL | `safetrip-urock-default-rtdb.firebaseio.com` |
| 용도 | 가디언 메시지, 실시간 위치 스트리밍, Presence |
| 스키마 | §4 도메인 [M] 참조 |

---

## 3. 도메인 구조 및 ERD

### 3.1 도메인 영역 분류

SafeTrip v3.7의 84개 PostgreSQL 테이블은 14개 도메인 영역으로 분류된다.

| # | 도메인 | 테이블 수 | 변경 | 핵심 테이블 |
|:-:|--------|:--------:|:----:|------------|
| A | 사용자 및 인증 | **3** | 동일 | TB_USER, TB_EMERGENCY_CONTACT, TB_PARENTAL_CONSENT |
| B | 그룹 및 여행 | **8** | **−1 v3.7** | TB_GROUP, TB_TRIP, TB_GROUP_MEMBER, TB_INVITE_CODE, TB_TRIP_SETTINGS, TB_COUNTRY, TB_ATTENDANCE_CHECK, TB_ATTENDANCE_RESPONSE |
| C | 보호자(가디언) | **7** | **+2 v3.7** | TB_GUARDIAN, TB_GUARDIAN_LINK, TB_GUARDIAN_PAUSE, TB_GUARDIAN_LOCATION_REQUEST, TB_GUARDIAN_SNAPSHOT, **TB_GUARDIAN_MESSAGE**, **TB_GUARDIAN_RELEASE_REQUEST** |
| D | 일정 및 지오펜스 | **12** | **+7 v3.7** | TB_SCHEDULE, TB_TRAVEL_SCHEDULE, TB_GEOFENCE, TB_GEOFENCE_EVENT, TB_GEOFENCE_PENALTY, **TB_SCHEDULE_COMMENT**, **TB_SCHEDULE_HISTORY**, **TB_SCHEDULE_REACTION**, **TB_SCHEDULE_TEMPLATE**, **TB_SCHEDULE_VOTE**, **TB_SCHEDULE_VOTE_OPTION**, **TB_SCHEDULE_VOTE_RESPONSE** |
| E | 위치 및 이동기록 | **9** | 동일 | TB_LOCATION_SHARING, TB_LOCATION, TB_STAY_POINT, TB_SESSION_MAP_IMAGE, TB_PLANNED_ROUTE, TB_ROUTE_DEVIATION, TB_LOCATION_SCHEDULE, TB_MOVEMENT_SESSION |
| F | 안전 및 SOS | **9** | 동일 | TB_HEARTBEAT, TB_SOS_EVENT, TB_POWER_EVENT, TB_SOS_RESCUE_LOG, TB_SOS_CANCEL_LOG, TB_EMERGENCY, TB_EMERGENCY_RECIPIENT, TB_NO_RESPONSE_EVENT, TB_SAFETY_CHECKIN |
| G | 채팅 | **6** | **+1 v3.7** | TB_CHAT_MESSAGE, TB_CHAT_POLL, TB_CHAT_POLL_VOTE, TB_CHAT_READ_STATUS, TB_CHAT_ROOM, **TB_CHAT_REACTION** |
| H | 알림 | **5** | 동일 | TB_NOTIFICATION, TB_NOTIFICATION_SETTING, TB_EVENT_NOTIFICATION_CONFIG, TB_FCM_TOKEN, TB_NOTIFICATION_PREFERENCE |
| I | 법적 동의 및 개인정보 | 6 | 동일 | TB_USER_CONSENT, TB_MINOR_CONSENT, TB_LOCATION_ACCESS_LOG, TB_LOCATION_SHARING_PAUSE_LOG, TB_DATA_DELETION_LOG, TB_DATA_PROVISION_LOG |
| J | 운영 및 로그 | **5** | **+2 v3.7** | TB_EVENT_LOG, TB_LEADER_TRANSFER_LOG, TB_EMERGENCY_NUMBER, **TB_COUNTRY_EMERGENCY_CONTACT**, **TB_SAFETY_GUIDE_CACHE** |
| K | 결제/과금 | **5** | 동일 | TB_PAYMENT, TB_SUBSCRIPTION, TB_BILLING_ITEM, TB_REFUND_LOG, TB_REDEEM_CODE |
| L | B2B | **7** | 동일 | TB_B2B_CONTRACT, TB_B2B_SCHOOL, TB_B2B_INVITE_BATCH, TB_B2B_MEMBER_LOG, TB_B2B_ORGANIZATION, TB_B2B_ADMIN, TB_B2B_DASHBOARD_CONFIG |
| **M** | **Firebase RTDB** | **—** | 동일 | **별도 스키마 (RTDB JSON 노드)** |
| N | AI | **3** | **+2 v3.7** | TB_AI_USAGE, **TB_AI_SUBSCRIPTION**, **TB_AI_USAGE_LOG** |

> **PostgreSQL 합계: 84개 독립 테이블** (v3.7: 실제 DB 기준 전면 재정렬 — TB_COUNTRY_SAFETY 제거, 14개 신규 테이블 추가, 22개 기존 테이블 컬럼 수정). RTDB는 별도 문서화.

### 3.2 ERD 관계도 (전체)

```
═══════════════════════════════════════════════════════════════════════
                        [A] 사용자 및 인증
═══════════════════════════════════════════════════════════════════════

TB_USER ─────────────────────────────────────────────────────────────
  │ PK: user_id (VARCHAR 128, Firebase UID)
  │
  ├── 1:N → TB_EMERGENCY_CONTACT        (user_id)
  ├── 1:N → TB_GROUP                     (owner_user_id)
  ├── 1:N → TB_TRIP                      (created_by)
  ├── 1:N → TB_GROUP_MEMBER              (user_id)
  ├── 1:N → TB_GUARDIAN                  (traveler_user_id / guardian_user_id)
  ├── 1:N → TB_GUARDIAN_LINK             (member_id / guardian_id)
  ├── 1:N → TB_GUARDIAN_MESSAGE          (sender_id)       -- v3.7 신규
  ├── 1:N → TB_GUARDIAN_RELEASE_REQUEST  (requested_by)    -- v3.7 신규
  ├── 1:N → TB_USER_CONSENT             (user_id)
  ├── 1:N → TB_MINOR_CONSENT            (user_id)
  ├── 1:N → TB_NOTIFICATION             (user_id)
  ├── 1:N → TB_NOTIFICATION_SETTING     (user_id)
  ├── 1:N → TB_HEARTBEAT                (user_id)
  ├── 1:N → TB_CHAT_MESSAGE             (sender_id)
  ├── 1:N → TB_CHAT_REACTION            (user_id)          -- v3.7 신규
  ├── 1:N → TB_LOCATION                 (user_id)
  ├── 1:N → TB_PAYMENT                  (user_id)
  ├── 1:N → TB_LOCATION_ACCESS_LOG      (user_id / accessed_by)
  ├── 1:N → TB_AI_USAGE                 (user_id)
  ├── 1:N → TB_AI_SUBSCRIPTION          (user_id)          -- v3.7 신규
  └── 1:1 → TB_PARENTAL_CONSENT        (user_id)

═══════════════════════════════════════════════════════════════════════
                       [B] 그룹 및 여행
═══════════════════════════════════════════════════════════════════════

TB_GROUP ─── 1:N → TB_GROUP_MEMBER
         ─── 1:1 → TB_TRIP
         ─── 1:N → TB_INVITE_CODE
         ─── 1:N → TB_GEOFENCE
         ─── 1:N → TB_CHAT_MESSAGE
         ─── 1:N → TB_EVENT_LOG

TB_TRIP  ─── 1:N → TB_GROUP_MEMBER      (trip_id)
         ─── 1:N → TB_SCHEDULE          (trip_id)
         ─── 1:N → TB_TRAVEL_SCHEDULE   (trip_id)
         ─── 1:N → TB_GEOFENCE          (trip_id)
         ─── 1:N → TB_HEARTBEAT         (trip_id)
         ─── 1:N → TB_SOS_EVENT         (trip_id)
         ─── 1:N → TB_NOTIFICATION      (trip_id)
         ─── 1:N → TB_CHAT_MESSAGE      (trip_id)
         ─── 1:N → TB_GUARDIAN_LINK     (trip_id)
         ─── 1:1 → TB_TRIP_SETTINGS     (trip_id)
         ─── N:1 → TB_B2B_CONTRACT      (b2b_contract_id, NULL=B2C)

═══════════════════════════════════════════════════════════════════════
                       [C] 보호자(가디언)
═══════════════════════════════════════════════════════════════════════

TB_GUARDIAN_LINK ─── N:M (멤버 ↔ 가디언 연결, trip 단위)
                 ─── 1:N → TB_GUARDIAN_PAUSE (link_id)
                 ─── 1:N → TB_GUARDIAN_MESSAGE         (link_id)    -- v3.7 신규
                 ─── 1:N → TB_GUARDIAN_RELEASE_REQUEST  (link_id)    -- v3.7 신규

TB_GUARDIAN_MESSAGE ─── N:1 → TB_TRIP           (trip_id)            -- v3.7 신규
                    ─── N:1 → TB_GUARDIAN_LINK  (link_id)
                    ─── N:1 → TB_USER           (sender_id)

TB_GUARDIAN_RELEASE_REQUEST ─── N:1 → TB_GUARDIAN_LINK (link_id)     -- v3.7 신규
                             ─── N:1 → TB_TRIP          (trip_id)
                             ─── N:1 → TB_USER          (requested_by)

TB_GUARDIAN_LOCATION_REQUEST ─── N:1 → TB_GROUP  (group_id)
                              ─── N:1 → TB_USER   (guardian_user_id: 요청자)
                              ─── N:1 → TB_USER   (target_user_id: 피요청자)

TB_GUARDIAN_SNAPSHOT ─── N:1 → TB_GROUP  (group_id)
                     ─── N:1 → TB_USER   (user_id: 여행자)

═══════════════════════════════════════════════════════════════════════
              [D] 일정 및 지오펜스
═══════════════════════════════════════════════════════════════════════

TB_SCHEDULE ─── 1:N → TB_SCHEDULE_COMMENT    (schedule_id)      -- v3.7 신규
            ─── 1:N → TB_SCHEDULE_HISTORY    (schedule_id)      -- v3.7 신규
            ─── 1:N → TB_SCHEDULE_REACTION   (schedule_id)      -- v3.7 신규
            ─── 1:N → TB_SCHEDULE_VOTE       (schedule_id)      -- v3.7 신규

TB_SCHEDULE_VOTE ─── 1:N → TB_SCHEDULE_VOTE_OPTION   (vote_id)  -- v3.7 신규
TB_SCHEDULE_VOTE_OPTION ── 1:N → TB_SCHEDULE_VOTE_RESPONSE (option_id) -- v3.7 신규

TB_SCHEDULE_TEMPLATE (독립 — 여행 일정 템플릿)                    -- v3.7 신규

TB_GEOFENCE ─── 1:N → TB_GEOFENCE_EVENT      (geofence_id)
TB_GEOFENCE_EVENT ── 1:N → TB_GEOFENCE_PENALTY (event_id)

═══════════════════════════════════════════════════════════════════════
                  [E] 위치 및 이동기록
═══════════════════════════════════════════════════════════════════════

TB_LOCATION ─── N:1 → TB_USER            (user_id)
            ─── 세션 그룹 → movement_session_id (UUID, 논리키)
            ─── 1:1 캐시 → TB_SESSION_MAP_IMAGE (session_id)

TB_SESSION_MAP_IMAGE ─── N:1 → TB_USER   (user_id)

TB_PLANNED_ROUTE ─── N:1 → TB_TRIP       (trip_id)
                 ─── N:1 → TB_USER        (user_id)
                 ─── 1:N → TB_ROUTE_DEVIATION (route_id)

TB_ROUTE_DEVIATION ─── N:1 → TB_PLANNED_ROUTE (route_id)
                   ─── N:1 → TB_TRIP           (trip_id)
                   ─── N:1 → TB_USER           (user_id)

TB_MOVEMENT_SESSION ─── N:1 → TB_USER   (user_id)
                    ─── N:1 → TB_TRIP   (trip_id)               -- v3.7 추가
                    ─── 1:N → TB_LOCATION (movement_session_id FK)

═══════════════════════════════════════════════════════════════════════
                       [F] 안전 및 SOS
═══════════════════════════════════════════════════════════════════════

TB_SOS_EVENT ─── 1:N → TB_SOS_RESCUE_LOG   (sos_event_id)
             ─── 1:N → TB_SOS_CANCEL_LOG   (sos_event_id)
             ─── 1:N → TB_DATA_PROVISION_LOG (sos_event_id)

═══════════════════════════════════════════════════════════════════════
               [F] 안전 및 SOS — v3.6 신규 테이블
═══════════════════════════════════════════════════════════════════════

TB_EMERGENCY ─── N:1 → TB_USER              (user_id)
             ─── N:1 → TB_TRIP              (trip_id)
             ─── 1:N → TB_EMERGENCY_RECIPIENT (emergency_id)

TB_NO_RESPONSE_EVENT ─── N:1 → TB_USER      (user_id)
                     ─── N:1 → TB_TRIP       (trip_id)

TB_SAFETY_CHECKIN ─── N:1 → TB_USER         (user_id)
                  ─── N:1 → TB_TRIP          (trip_id)

═══════════════════════════════════════════════════════════════════════
                       [G] 채팅
═══════════════════════════════════════════════════════════════════════

TB_CHAT_MESSAGE ─── 1:N → TB_CHAT_POLL     (message_id)
                ─── 1:N → TB_CHAT_REACTION  (message_id)        -- v3.7 신규
                ─── self  → reply_to_id     (답글 구조)

TB_CHAT_POLL    ─── 1:N → TB_CHAT_POLL_VOTE (poll_id)

TB_CHAT_ROOM ─── 1:N → TB_CHAT_MESSAGE      (room_id)
             ─── N:1 → TB_TRIP               (trip_id)

═══════════════════════════════════════════════════════════════════════
                       [H] 알림
═══════════════════════════════════════════════════════════════════════

TB_USER ─── 1:N → TB_FCM_TOKEN              (user_id)
TB_USER ─── 1:N → TB_NOTIFICATION_PREFERENCE (user_id)

═══════════════════════════════════════════════════════════════════════
                       [J] 운영 및 로그 — v3.7 신규 테이블
═══════════════════════════════════════════════════════════════════════

TB_SAFETY_GUIDE_CACHE (독립 — MOFA API 캐시, country_code+data_type UNIQUE)  -- v3.7 신규
TB_COUNTRY_EMERGENCY_CONTACT (독립 — 국가별 긴급연락처)                       -- v3.7 신규

═══════════════════════════════════════════════════════════════════════
                       [K] 결제/과금
═══════════════════════════════════════════════════════════════════════

TB_SUBSCRIPTION ─── 1:N → TB_PAYMENT        (subscription_id)
TB_PAYMENT      ─── 1:N → TB_BILLING_ITEM   (payment_id)
TB_PAYMENT      ─── 1:N → TB_REFUND_LOG     (payment_id)
TB_PAYMENT      ─── N:1 → TB_GUARDIAN_LINK  (결제 완료 시 is_paid=TRUE)

TB_REDEEM_CODE (독립 — 코드 기반 리딤)                           -- v3.6 신규

═══════════════════════════════════════════════════════════════════════
                       [L] B2B
═══════════════════════════════════════════════════════════════════════

TB_B2B_CONTRACT ─── 1:N → TB_B2B_INVITE_BATCH (contract_id)
TB_B2B_SCHOOL   ─── 1:N → TB_B2B_CONTRACT     (school_id)
TB_B2B_INVITE_BATCH ─── 1:N → TB_B2B_MEMBER_LOG (batch_id)

TB_B2B_ORGANIZATION ─── 1:N → TB_B2B_CONTRACT         (org_id) -- v3.6 신규
                    ─── 1:N → TB_B2B_ADMIN             (org_id) -- v3.6 신규
                    ─── 1:N → TB_B2B_DASHBOARD_CONFIG  (org_id) -- v3.6 신규

═══════════════════════════════════════════════════════════════════════
               [B] 출석 체크 (v3.5 신규 — 비즈니스 원칙 v5.1 §05.5)
═══════════════════════════════════════════════════════════════════════

TB_ATTENDANCE_CHECK    ─── N:1 → TB_TRIP          (trip_id)
                       ─── N:1 → TB_GROUP         (group_id)
                       ─── N:1 → TB_USER          (initiated_by: captain/crew_chief)
                       ─── 1:N → TB_ATTENDANCE_RESPONSE (check_id)

TB_ATTENDANCE_RESPONSE ─── N:1 → TB_ATTENDANCE_CHECK (check_id)
                       ─── N:1 → TB_USER              (user_id: 응답 멤버)
                       -- UNIQUE(check_id, user_id)

═══════════════════════════════════════════════════════════════════════
                       [N] AI
═══════════════════════════════════════════════════════════════════════

TB_AI_USAGE ─── N:1 → TB_USER  (user_id)

TB_AI_SUBSCRIPTION ─── N:1 → TB_USER  (user_id)                -- v3.7 신규

TB_AI_USAGE_LOG (독립 — AI 호출 로그, user_id 논리키)             -- v3.7 신규
```

---

## 4. 테이블 상세 명세

---

### [A] 도메인: 사용자 및 인증

---

#### 4.1 TB_USER (사용자)

> 출처: 01-init-schema.sql, 11-migration-profile-columns.sql, 20-migration-schema-sync.sql, user.entity.ts
> v3.0 변경: 미성년자 컬럼 추가
> v3.7 변경: 프로필·온보딩·프라이버시 컬럼 12개 추가 (실제 DB 기준)

```sql
CREATE TABLE tb_user (
    user_id                  VARCHAR(128) PRIMARY KEY,    -- Firebase UID
    phone_number             VARCHAR(20),
    phone_country_code       VARCHAR(5),
    display_name             VARCHAR(100),
    nickname                 VARCHAR(50),                  -- v3.7: 고유 닉네임 (UNIQUE INDEX)
    profile_image_url        TEXT,
    email                    VARCHAR(255),
    date_of_birth            DATE,
    location_sharing_mode    VARCHAR(20),                  -- always | in_trip | off
    fcm_token                TEXT,
    install_id               VARCHAR(100),
    device_info              JSONB,
    user_status              VARCHAR(20) DEFAULT 'active', -- active | inactive | banned
    -- ▼ v3.7: 프로필 확장 컬럼
    avatar_id                VARCHAR(30),                  -- 프로필 아바타 ID
    privacy_level            VARCHAR(20) DEFAULT 'standard', -- safety_first | standard | privacy_first
    image_review_status      VARCHAR(20) DEFAULT 'none',  -- none | pending | approved | rejected
    is_active                BOOLEAN DEFAULT TRUE,
    -- ▼ v3.7: 온보딩 추적
    is_onboarding_complete   BOOLEAN DEFAULT FALSE,
    onboarding_step          VARCHAR(50),                  -- 현재 온보딩 단계
    onboarding_completed     BOOLEAN DEFAULT FALSE,        -- 온보딩 완료 플래그
    -- ▼ v3.7: 약관 동의
    terms_version            VARCHAR(20),                  -- 동의한 약관 버전
    terms_agreed_at          TIMESTAMPTZ,                  -- 약관 동의 시각
    -- ▼ 미성년자 보호 원칙 §13 반영
    minor_status             VARCHAR(20) DEFAULT 'adult',  -- adult | minor_over14 | minor_under14 | minor_child
    minor_status_updated_at  TIMESTAMPTZ,
    guardian_pause_blocked   BOOLEAN DEFAULT FALSE,        -- 미성년자: 가디언 일시중지 차단
    ai_intelligence_blocked  BOOLEAN DEFAULT FALSE,        -- 미성년자: AI 개인 분석 차단
    guardian_consent_id      UUID,                         -- FK→tb_minor_consent (미성년자 보호자 동의)
    -- ▼ 시스템 컬럼
    last_verification_at     TIMESTAMPTZ,
    last_login_at            TIMESTAMPTZ,
    last_active_at           TIMESTAMPTZ,
    created_at               TIMESTAMPTZ DEFAULT NOW(),
    updated_at               TIMESTAMPTZ,
    -- ▼ v3.5: 계정 삭제 유예 기간 추적 (비즈니스 원칙 v5.1 §14 — 7일 유예 후 hard delete)
    deletion_requested_at    TIMESTAMPTZ,                  -- 삭제 요청 시각 (7일 유예 기산점)
    deletion_reason          TEXT,                         -- v3.7: 삭제 사유
    deleted_at               TIMESTAMPTZ                   -- soft delete
);

CREATE UNIQUE INDEX idx_user_nickname ON tb_user(nickname) WHERE nickname IS NOT NULL;
```

#### 4.2 TB_EMERGENCY_CONTACT (비상 연락처)

> 출처: SafeTrip_프로필화면_원칙_v1_0

```sql
CREATE TABLE tb_emergency_contact (
    contact_id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             VARCHAR(128) NOT NULL REFERENCES tb_user(user_id),
    contact_name        VARCHAR(100) NOT NULL,
    phone_number        VARCHAR(20) NOT NULL,
    phone_country_code  VARCHAR(5),
    relationship        VARCHAR(20),                     -- parent | spouse | sibling | friend | other
    sort_order          INTEGER DEFAULT 0,
    created_at          TIMESTAMPTZ DEFAULT NOW(),
    updated_at          TIMESTAMPTZ
);
```

#### 4.2a TB_PARENTAL_CONSENT (보호자 동의) ⭐ 신규 v3.6

> 출처: user.entity.ts — 미성년자 부모/보호자 동의 OTP 인증 관리
> v3.6: 신규 정의. TB_USER.user_id를 PK로 사용하는 1:1 관계.

```sql
CREATE TABLE tb_parental_consent (
    user_id          VARCHAR(128) PRIMARY KEY REFERENCES tb_user(user_id),
    parent_name      VARCHAR(50),
    parent_phone     VARCHAR(20),
    relationship     VARCHAR(20),              -- parent | guardian | teacher
    consent_otp      VARCHAR(10),              -- OTP 인증 코드
    is_verified      BOOLEAN DEFAULT FALSE,
    verified_at      TIMESTAMPTZ,
    created_at       TIMESTAMPTZ DEFAULT NOW()
);
```

---

### [B] 도메인: 그룹 및 여행

---

#### 4.3 TB_GROUP (그룹)

> 출처: 01-init-schema.sql, 20-migration-schema-sync.sql
> v3.7 변경: is_active, created_by 추가

```sql
CREATE TABLE tb_group (
    group_id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_name            VARCHAR(200),
    group_description     TEXT,
    group_type            VARCHAR(20) DEFAULT 'travel',  -- travel | b2b_school | b2b_corporate
    owner_user_id         VARCHAR(128) REFERENCES tb_user(user_id),
    invite_code           VARCHAR(8) UNIQUE,
    invite_link           TEXT,
    current_member_count  INTEGER DEFAULT 0,
    max_members           INTEGER DEFAULT 50,
    status                VARCHAR(20) DEFAULT 'active',  -- active | inactive
    is_active             BOOLEAN DEFAULT TRUE,           -- v3.7: 활성 상태 플래그
    created_by            VARCHAR(128),                   -- v3.7: 생성자 user_id
    expires_at            TIMESTAMPTZ,
    created_at            TIMESTAMPTZ DEFAULT NOW(),
    updated_at            TIMESTAMPTZ,
    deleted_at            TIMESTAMPTZ
);
```

#### 4.4 TB_TRIP (여행)

> 출처: 01-init-schema.sql, 비즈니스 원칙 v5.1 §02.3, §03.6
> v3.0 변경: CHECK 제약조건 적용 확정, 프라이버시/일정 컬럼 확정

```sql
CREATE TABLE tb_trip (
    trip_id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id                 UUID REFERENCES tb_group(group_id),
    trip_name                VARCHAR(200),
    destination              VARCHAR(200),
    destination_city         VARCHAR(200),
    destination_country_code VARCHAR(10),
    country_code             VARCHAR(10),
    country_name             VARCHAR(100),
    trip_type                VARCHAR(20),                  -- group | solo
    start_date               DATE,
    end_date                 DATE,
    status                   VARCHAR(20),                  -- planning | active | completed
    -- ▼ 비즈니스 원칙 v5.1 프라이버시 등급
    privacy_level            VARCHAR(20) DEFAULT 'standard', -- safety_first | standard | privacy_first
    -- ▼ 비즈니스 원칙 v5.1 위치 공유 모드
    sharing_mode             VARCHAR(20) DEFAULT 'voluntary', -- forced | voluntary
    -- ▼ 일정 연동 공유 설정
    schedule_type            VARCHAR(20) DEFAULT 'always',   -- always | time_based | schedule_linked
    schedule_buffer_minutes  INTEGER DEFAULT 15,              -- 0 | 15 | 30
    -- ▼ B2B 연동 (비즈니스 원칙 v5.1 §12 반영)
    b2b_contract_id          UUID REFERENCES tb_b2b_contract(contract_id), -- NULL이면 B2C 여행
    -- ▼ 미성년자 포함 여부 (비즈니스 원칙 v5.1 §13 — 등급 강제 검증용)
    has_minor_members        BOOLEAN DEFAULT FALSE,
    -- ▼ v3.5: 여행 재활성화 추적 (비즈니스 원칙 v5.1 §02.6 — completed→active 24시간 내 1회 가능)
    reactivated_at           TIMESTAMPTZ,                  -- 마지막 재활성화 시각
    reactivation_count       INTEGER DEFAULT 0,            -- 재활성화 횟수 (최대 1회)
    -- ▼ 시스템 컬럼
    created_by               VARCHAR(128) REFERENCES tb_user(user_id),
    created_at               TIMESTAMPTZ DEFAULT NOW(),
    updated_at               TIMESTAMPTZ,
    deleted_at               TIMESTAMPTZ,
    -- ▼ 비즈니스 원칙 v5.1 §02.3: 여행 기간 최대 15일
    CONSTRAINT chk_trip_duration CHECK (end_date IS NULL OR start_date IS NULL OR end_date - start_date <= 15),
    -- ▼ v3.5: 재활성화 횟수 1회 제한
    CONSTRAINT chk_reactivation_count CHECK (reactivation_count <= 1)
);

CREATE INDEX idx_trips_group    ON tb_trip(group_id);
CREATE INDEX idx_trips_status   ON tb_trip(status);
CREATE INDEX idx_trips_dates    ON tb_trip(start_date, end_date);
CREATE INDEX idx_trips_b2b      ON tb_trip(b2b_contract_id) WHERE b2b_contract_id IS NOT NULL;
```

> **비즈니스 원칙 v5.1 반영사항**:
> - `privacy_level`: 3등급 프라이버시 시스템 (§03.6)
> - `sharing_mode`: 강제/자유 공유 모드 (§05.2)
> - `schedule_type`: 일정 연동 공유 유형 A/B/C (§05.3)
> - `CHECK 제약조건`: 여행 기간 15일 제한 (§02.3)
> - `b2b_contract_id`: B2B 계약 연결 — NULL이면 B2C, 값 있으면 B2B 여행 (§12)
> - `has_minor_members`: 미성년자 포함 여행 시 safety_first 등급 강제 (§13.2)

#### 4.5 TB_GROUP_MEMBER (그룹 멤버 — 역할 핵심)

> 출처: 01-init-schema.sql, migration-guardian-system.sql, 20-migration-schema-sync.sql
> v3.0 변경: trip_id NOT NULL 확정, 권한 컬럼 복원, member_role에 guardian 포함
> v3.7 변경: can_manage_members, can_send_notifications, can_view_location, can_manage_geofences 추가

```sql
CREATE TABLE tb_group_member (
    member_id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id                 UUID NOT NULL REFERENCES tb_group(group_id) ON DELETE CASCADE,
    user_id                  VARCHAR(128) NOT NULL REFERENCES tb_user(user_id) ON DELETE CASCADE,
    -- ▼ 4-tier 역할 모델
    member_role              VARCHAR(30) DEFAULT 'crew'
        CHECK (member_role IN ('captain', 'crew_chief', 'crew', 'guardian')),
    -- ▼ trip_id: NOT NULL (v2.0 주요 버그 수정 — getUserTrips INNER JOIN 실패 방지)
    trip_id                  UUID NOT NULL REFERENCES tb_trip(trip_id),
    -- ▼ 세분화 권한 컬럼 (역할별 기본값으로 설정)
    is_admin                 BOOLEAN DEFAULT FALSE,           -- 관리자 여부 (captain/crew_chief)
    is_guardian              BOOLEAN DEFAULT FALSE,           -- 레거시 (member_role='guardian'으로 대체)
    can_edit_schedule        BOOLEAN DEFAULT FALSE,
    can_edit_geofence        BOOLEAN DEFAULT FALSE,
    can_view_all_locations   BOOLEAN DEFAULT TRUE,
    can_attendance_check     BOOLEAN DEFAULT TRUE,
    -- ▼ v3.7: 추가 권한 컬럼
    can_manage_members       BOOLEAN DEFAULT FALSE,           -- 멤버 관리 권한
    can_send_notifications   BOOLEAN DEFAULT FALSE,           -- 알림 전송 권한
    can_view_location        BOOLEAN DEFAULT TRUE,            -- 위치 조회 권한
    can_manage_geofences     BOOLEAN DEFAULT FALSE,           -- 지오펜스 관리 권한
    -- ▼ 보호자 역할 (레거시)
    traveler_user_id         VARCHAR(128) REFERENCES tb_user(user_id),
    -- ▼ 위치 공유 마스터 스위치
    location_sharing_enabled BOOLEAN DEFAULT TRUE,
    status                   VARCHAR(20) DEFAULT 'active',   -- active | left
    joined_at                TIMESTAMPTZ DEFAULT NOW(),
    left_at                  TIMESTAMPTZ,
    UNIQUE(group_id, user_id)
);

CREATE INDEX idx_group_members_group ON tb_group_member(group_id);
CREATE INDEX idx_group_members_user  ON tb_group_member(user_id);
CREATE INDEX idx_group_members_role  ON tb_group_member(member_role);
CREATE INDEX idx_group_members_trip  ON tb_group_member(trip_id);
-- ▼ v3.5: 그룹당 활성 captain은 1명만 허용 (비즈니스 원칙 v5.1 §08.2)
CREATE UNIQUE INDEX idx_group_member_captain
    ON tb_group_member(group_id)
    WHERE member_role = 'captain' AND status = 'active';
```

> **역할별 기본 권한 설정 (INSERT 시 trigger 또는 서비스 레이어)**:
> - `captain`: is_admin=TRUE, can_edit_schedule=TRUE, can_edit_geofence=TRUE, can_attendance_check=TRUE
> - `crew_chief`: is_admin=TRUE, can_edit_schedule=TRUE, can_edit_geofence=TRUE, can_attendance_check=TRUE
> - `crew`: 기본값 (모두 FALSE 또는 기본값)
> - `guardian`: can_view_all_locations=FALSE (연결된 멤버만)

#### 4.6 TB_INVITE_CODE (역할별 초대코드)

> 출처: 01-init-schema.sql, SafeTrip_초대코드_원칙_v1_0
> v3.7 변경: used_count→current_uses 이름 변경, model_type 추가, code/target_role/expires_at NOT NULL

```sql
CREATE TABLE tb_invite_code (
    invite_code_id  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id        UUID REFERENCES tb_group(group_id),
    trip_id         UUID REFERENCES tb_trip(trip_id),
    code            VARCHAR(7) NOT NULL UNIQUE,
    target_role     VARCHAR(30) NOT NULL,            -- crew_chief | crew | guardian
    model_type      VARCHAR(30),                     -- v3.7: 코드 유형 (일반/B2B/이벤트 등)
    max_uses        INTEGER DEFAULT 1,
    current_uses    INTEGER DEFAULT 0,               -- v3.7: used_count에서 이름 변경
    expires_at      TIMESTAMPTZ NOT NULL,
    created_by      VARCHAR(128) REFERENCES tb_user(user_id),
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    is_active       BOOLEAN DEFAULT TRUE,
    -- ▼ B2B 일괄 초대코드 참조
    b2b_batch_id    UUID REFERENCES tb_b2b_invite_batch(batch_id)
);

CREATE INDEX idx_invite_code_group ON tb_invite_code(group_id);
CREATE INDEX idx_invite_code_code  ON tb_invite_code(code) WHERE is_active = TRUE;
```

#### 4.7 TB_TRIP_SETTINGS (여행 설정) ⭐ 신규

> 출처: 가디언 시스템 구현 (migration-guardian-system.sql)
> v3.0: 새로 정의

```sql
CREATE TABLE tb_trip_settings (
    setting_id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id                       UUID NOT NULL UNIQUE REFERENCES tb_trip(trip_id),
    -- ▼ 가디언 메시지 설정
    captain_receive_guardian_msg  BOOLEAN DEFAULT TRUE,  -- 캡틴이 가디언 메시지를 수신할지 여부
    guardian_msg_enabled          BOOLEAN DEFAULT TRUE,  -- 가디언 메시지 기능 활성화
    -- ▼ SOS 설정
    sos_auto_trigger_enabled      BOOLEAN DEFAULT TRUE,  -- Heartbeat 기반 자동 SOS
    sos_heartbeat_timeout_min     INTEGER DEFAULT 30,    -- 타임아웃 기준 (분)
    -- ▼ 출석 체크 설정
    attendance_check_enabled      BOOLEAN DEFAULT TRUE,
    -- ▼ 지오펜스 설정
    geofence_guardian_notify      BOOLEAN DEFAULT TRUE,  -- 가디언에게 지오펜스 알림 전달 여부
    -- ▼ 시스템
    created_at                    TIMESTAMPTZ DEFAULT NOW(),
    updated_at                    TIMESTAMPTZ
);
```

#### 4.8 TB_COUNTRY (국가 목록) ⭐ 신규

> 출처: 비즈니스 원칙 v5.1, GET /api/v1/countries API 지원
> v3.0: 신규 (v2.0에서 미정의로 countries API 500 에러 발생)

```sql
CREATE TABLE tb_country (
    country_id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    country_code        VARCHAR(5) NOT NULL UNIQUE,  -- ISO 3166-1 alpha-2 (KR, JP, US ...)
    country_name_ko     VARCHAR(100) NOT NULL,
    country_name_en     VARCHAR(100) NOT NULL,
    country_flag_emoji  VARCHAR(10),                 -- 🇰🇷
    phone_code          VARCHAR(10),                 -- +82, +81 ...
    region              VARCHAR(50),                 -- Asia, Europe, Americas ...
    mofa_travel_alert   VARCHAR(20) DEFAULT 'none',  -- none | watch | warning | danger | ban
    mofa_alert_updated_at TIMESTAMPTZ,
    is_popular          BOOLEAN DEFAULT FALSE,        -- 자주 가는 국가 상단 표시
    sort_order          INTEGER DEFAULT 0,
    created_at          TIMESTAMPTZ DEFAULT NOW(),
    updated_at          TIMESTAMPTZ
);

CREATE INDEX idx_country_code   ON tb_country(country_code);
CREATE INDEX idx_country_region ON tb_country(region);
```

> **v3.7 변경**: TB_COUNTRY_SAFETY 제거됨. 실제 DB에 존재하지 않으며, 안전 정보 기능은 [J] 도메인의 TB_SAFETY_GUIDE_CACHE와 TB_COUNTRY_EMERGENCY_CONTACT로 대체.

---

### [C] 도메인: 보호자(가디언)

---

#### 4.9 TB_GUARDIAN (보호자 — 레거시 유지)

> 출처: migration-guardian-system.sql, 비즈니스 원칙 v5.1 §03.1
> v3.0: TB_GUARDIAN_LINK(신규)와 병행 사용. 향후 TB_GUARDIAN_LINK로 완전 마이그레이션 예정.

```sql
CREATE TABLE tb_guardian (
    guardian_id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    traveler_user_id     VARCHAR(128) REFERENCES tb_user(user_id),
    guardian_user_id     VARCHAR(128) REFERENCES tb_user(user_id),
    trip_id              UUID REFERENCES tb_trip(trip_id),
    guardian_type        VARCHAR(20),                     -- primary | secondary | group
    can_view_location    BOOLEAN DEFAULT TRUE,
    can_request_checkin  BOOLEAN DEFAULT TRUE,
    can_receive_sos      BOOLEAN DEFAULT TRUE,
    invite_status        VARCHAR(20),                     -- pending | accepted | rejected
    guardian_invite_code VARCHAR(20),
    -- ▼ 미성년자 보호 원칙 §13
    is_minor_guardian    BOOLEAN DEFAULT FALSE,
    consent_id           UUID,
    auto_notify_sos      BOOLEAN DEFAULT TRUE,
    auto_notify_geofence BOOLEAN DEFAULT TRUE,
    -- ▼ 비즈니스 원칙 v5.1 §09.3: 가디언 유/무료 구분
    is_paid              BOOLEAN DEFAULT FALSE,
    paid_at              TIMESTAMPTZ,
    payment_id           UUID REFERENCES tb_payment(payment_id),
    -- ▼ 시스템
    created_at           TIMESTAMPTZ DEFAULT NOW(),
    accepted_at          TIMESTAMPTZ,
    expires_at           TIMESTAMPTZ
);

CREATE INDEX idx_guardian_traveler ON tb_guardian(traveler_user_id);
CREATE INDEX idx_guardian_guardian ON tb_guardian(guardian_user_id);
CREATE INDEX idx_guardian_trip     ON tb_guardian(trip_id);
```

#### 4.10 TB_GUARDIAN_LINK (가디언-멤버 연결)

> 출처: migration-guardian-system.sql (실제 구현), 20-migration-schema-sync.sql
> v3.0: 신규 정의. 실제 구현에서 사용하는 가디언 링크 테이블.
> v3.7 변경: accepted_at 추가
> 컬럼명: member_id / guardian_id / status (v2.0의 traveler_user_id/guardian_user_id/invite_status 대체)

```sql
CREATE TABLE tb_guardian_link (
    link_id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id              UUID NOT NULL REFERENCES tb_trip(trip_id) ON DELETE CASCADE,
    -- ▼ 연결 대상 (멤버 = 보호 받는 사람)
    member_id            VARCHAR(128) NOT NULL REFERENCES tb_user(user_id),
    -- ▼ 가디언 (보호자) — NULL 허용: 전화번호만 입력한 미가입 가디언 초대 지원
    guardian_id          VARCHAR(128) REFERENCES tb_user(user_id) ON DELETE SET NULL,
    guardian_phone       VARCHAR(20),                     -- 초대 시 입력한 전화번호 (미가입 가디언은 필수)
    -- ▼ 링크 상태
    status               VARCHAR(20) DEFAULT 'pending'
        CHECK (status IN ('pending', 'accepted', 'rejected', 'cancelled')),
    -- ▼ 가디언 유형
    guardian_type        VARCHAR(20) DEFAULT 'personal'
        CHECK (guardian_type IN ('personal', 'group')),
    -- ▼ 결제 연동 (비즈니스 원칙 v5.1 §09.3: 무료 2명 초과 시 유료)
    is_paid              BOOLEAN DEFAULT FALSE,
    paid_at              TIMESTAMPTZ,
    payment_id           UUID REFERENCES tb_payment(payment_id),
    -- ▼ 권한 설정
    can_view_location    BOOLEAN DEFAULT TRUE,
    can_receive_sos      BOOLEAN DEFAULT TRUE,
    can_request_checkin  BOOLEAN DEFAULT TRUE,
    can_send_message     BOOLEAN DEFAULT TRUE,            -- 가디언 메시지 전송 가능
    -- ▼ 시스템
    invited_at           TIMESTAMPTZ DEFAULT NOW(),
    responded_at         TIMESTAMPTZ,
    accepted_at          TIMESTAMPTZ,                    -- v3.7: 수락 시각
    created_at           TIMESTAMPTZ DEFAULT NOW(),
    updated_at           TIMESTAMPTZ
    -- ▼ v3.5: UNIQUE(trip_id, member_id, guardian_id) 제거 — guardian_id NULL 허용으로 NULL≠NULL 문제 발생
    -- 대신 아래 부분 인덱스 2개로 중복 방지
);

-- RTDB 가디언 메시지 채널키: link_{link_id}
-- 예: guardian_messages/{tripId}/link_{linkId}/messages/{msgId}

CREATE INDEX idx_guardian_link_trip     ON tb_guardian_link(trip_id);
CREATE INDEX idx_guardian_link_member   ON tb_guardian_link(member_id);
CREATE INDEX idx_guardian_link_guardian ON tb_guardian_link(guardian_id);
CREATE INDEX idx_guardian_link_status   ON tb_guardian_link(status);
-- ▼ v3.5: 부분 인덱스로 UNIQUE 보장 (guardian_id NULL 허용 환경에서 안전한 중복 방지)
-- 가입 완료된 가디언: (trip, member, guardian) 조합 중복 금지
CREATE UNIQUE INDEX idx_guardian_link_active
    ON tb_guardian_link(trip_id, member_id, guardian_id)
    WHERE guardian_id IS NOT NULL;
-- 초대 전 상태(미가입): 같은 전화번호로 중복 초대 금지
CREATE UNIQUE INDEX idx_guardian_link_pending
    ON tb_guardian_link(trip_id, member_id, guardian_phone)
    WHERE guardian_id IS NULL AND guardian_phone IS NOT NULL;
```

> **비즈니스 원칙 v5.1 §03.1 반영**:
> - 개인 가디언 무료 2명: `is_paid = FALSE` (RTDB 채널 link_{linkId}에서 message 전송 가능)
> - 3번째 이상 가디언: `is_paid = TRUE` 필요 (TB_PAYMENT 결제 완료 후 활성화)
> - 전체(group) 가디언: 여행당 최대 2명 (무료, 추가 불가)
> - `guardian_id NULL` 허용: 전화번호(`guardian_phone`)만 입력한 미가입 가디언 초대 → 앱 설치·가입 후 `guardian_id` 업데이트. `status='pending'` 상태에서 실명 가디언으로 연결.

#### 4.11 TB_GUARDIAN_PAUSE (가디언 일시중지)

> 출처: SafeTrip_설정_메뉴_원칙_v1_0
> v3.0 변경: link_id 참조 추가

```sql
CREATE TABLE tb_guardian_pause (
    pause_id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    link_id           UUID NOT NULL REFERENCES tb_guardian_link(link_id),
    user_id           VARCHAR(128) NOT NULL REFERENCES tb_user(user_id),
    trip_id           UUID NOT NULL REFERENCES tb_trip(trip_id),
    -- ▼ v3.5: Appendix C 호환 컬럼 추가 (de-normalization intentional)
    group_id          UUID REFERENCES tb_group(group_id) ON DELETE CASCADE,
    guardian_user_id  VARCHAR(128) REFERENCES tb_user(user_id) ON DELETE SET NULL,
    paused_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    resume_at         TIMESTAMPTZ NOT NULL,          -- 자동 재개 시각
    is_active         BOOLEAN DEFAULT TRUE,
    pause_reason      VARCHAR(50),                   -- user_request | minor_blocked
    created_at        TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_guardian_pause_link ON tb_guardian_pause(link_id);
CREATE INDEX idx_guardian_pause_user ON tb_guardian_pause(user_id, trip_id);
```

> **프라이버시 등급별 최대 일시중지 시간** (§05.6):
> - 안전 최우선: 불가 (INSERT 차단)
> - 표준: 최대 12시간
> - 프라이버시 우선: 최대 24시간
> - 미성년자(minor_under14, minor_child): `guardian_pause_blocked=TRUE`이면 항상 불가

#### 4.11a TB_GUARDIAN_LOCATION_REQUEST (가디언 긴급 위치 요청) ⭐ 신규

> 출처: 비즈니스 원칙 v5.1 부록 B 시나리오 5, 부록 C
> v3.2: 신규 정의. 프라이버시 우선(`privacy_first`) 등급에서 위치 비공유 상태인 여행자에게 가디언이 긴급 1회 위치 공유를 요청하는 기능의 DB 기반.

```sql
CREATE TABLE tb_guardian_location_request (
    request_id       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id         UUID NOT NULL REFERENCES tb_group(group_id),
    trip_id          UUID NOT NULL REFERENCES tb_trip(trip_id) ON DELETE CASCADE,
    -- ▼ 요청자: 가디언 (위치를 보고 싶은 쪽)
    guardian_user_id VARCHAR(128) NOT NULL REFERENCES tb_user(user_id),
    -- ▼ 피요청자: 여행자/크루 (위치 공유 요청을 받는 쪽)
    target_user_id   VARCHAR(128) NOT NULL REFERENCES tb_user(user_id),
    -- ▼ 요청 상태
    status           VARCHAR(20) DEFAULT 'pending'
        CHECK (status IN ('pending', 'approved', 'ignored', 'expired')),
    -- ▼ 타임스탬프
    requested_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    responded_at          TIMESTAMPTZ,                     -- 승인/무시 시각
    expires_at            TIMESTAMPTZ NOT NULL,            -- 기본 10분 후 자동 만료
    -- ▼ v3.5: 표준 등급 자동 응답 지원 (비즈니스 원칙 v5.1 §05.3)
    auto_responded        BOOLEAN DEFAULT FALSE,           -- 표준 등급에서 멤버 승인 없이 자동 응답
    auto_response_reason  VARCHAR(50),                     -- standard_grade_auto | sos_override
    created_at            TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_guardian_location_request_target
    ON tb_guardian_location_request(target_user_id, status);
CREATE INDEX idx_guardian_location_request_guardian
    ON tb_guardian_location_request(guardian_user_id, requested_at DESC);
CREATE INDEX idx_guardian_location_request_trip
    ON tb_guardian_location_request(trip_id);
-- ▼ v3.5: 시간당 3회 rate limiting 지원 (비즈니스 원칙 v5.1 §03.4, §05.3)
-- 서비스 레이어: SELECT COUNT(*) WHERE guardian_user_id=$1 AND requested_at > NOW()-INTERVAL '1 hour'
CREATE INDEX idx_guardian_location_request_hourly
    ON tb_guardian_location_request(guardian_user_id, requested_at DESC);
```

> **비즈니스 원칙 v5.1 §05.5 반영**:
> - `pending`: 여행자가 아직 응답 전 (FCM 알림 전송됨)
> - `approved`: 여행자가 승인 → 가디언에게 1회성 현재 위치 전송
> - `ignored`: 여행자가 거부 또는 10분 경과 → 가디언에게 "응답 없음" 표시
> - `expired`: `expires_at` 경과 (cron 또는 서비스 레이어 처리)
> - 승인 시 `GUARDIAN_LOCATION_REQUEST + APPROVED` 이벤트 → `TB_EVENT_LOG` 기록
> - 이벤트 로그: `GUARDIAN_LOCATION_REQUEST`, `APPROVED`, `GUARDIAN_ALERT` (무응답 시 추가 알림 발송 가능)

#### 4.11b TB_GUARDIAN_SNAPSHOT (가디언 위치 스냅샷) ⭐ 신규

> 출처: 비즈니스 원칙 v5.1 부록 B 시나리오 4, 부록 C
> v3.2: 신규 정의. 표준(`standard`) 등급에서 위치 비공유 시간대에 가디언 전용으로 30분마다 자동 저장되는 최소 위치 스냅샷.

```sql
CREATE TABLE tb_guardian_snapshot (
    snapshot_id  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id     UUID NOT NULL REFERENCES tb_group(group_id),
    trip_id      UUID NOT NULL REFERENCES tb_trip(trip_id) ON DELETE CASCADE,
    -- ▼ 스냅샷 대상 (여행자/크루)
    user_id      VARCHAR(128) NOT NULL REFERENCES tb_user(user_id),
    latitude     DOUBLE PRECISION NOT NULL,
    longitude    DOUBLE PRECISION NOT NULL,
    captured_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_guardian_snapshot_user
    ON tb_guardian_snapshot(user_id, captured_at DESC);
CREATE INDEX idx_guardian_snapshot_group
    ON tb_guardian_snapshot(group_id, captured_at DESC);
CREATE INDEX idx_guardian_snapshot_trip
    ON tb_guardian_snapshot(trip_id, captured_at DESC);
```

> **비즈니스 원칙 v5.1 §05.4 표준 등급 비공유 시간대 동작**:
> - 여행자가 `time_based` 비공유 구간에 진입하면 30분 간격으로 이 테이블에 스냅샷 삽입
> - 가디언 앱 화면: "마지막 확인: 23분 전 · 호텔 근처" 형태로 표시
> - `privacy_first` 등급에서는 이 테이블에 데이터가 쌓이지 않음 (비공유 시 완전 차단)
> - 데이터 보존: 여행 종료 후 30일 자동 삭제 (비즈니스 원칙 v5.1 §13.1)
> - `TB_LOCATION_ACCESS_LOG`에 `access_type = 'guardian_snapshot'`으로 접근 기록

#### 4.11c TB_GUARDIAN_MESSAGE (가디언 1:1 메시지) ⭐ 신규 v3.7

> 출처: 12-schema-guardian-message.sql
> v3.7: 신규 정의. 가디언-멤버 간 1:1 채팅 메시지 (그룹채팅과 별도).

```sql
CREATE TABLE tb_guardian_message (
    message_id   BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    trip_id      UUID NOT NULL REFERENCES tb_trip(trip_id),
    link_id      UUID NOT NULL REFERENCES tb_guardian_link(link_id),
    sender_type  VARCHAR(20) NOT NULL CHECK (sender_type IN ('member','guardian')),
    sender_id    VARCHAR(128) NOT NULL REFERENCES tb_user(user_id),
    message_type VARCHAR(20) NOT NULL DEFAULT 'text'
                 CHECK (message_type IN ('text','location_card','system')),
    content      TEXT,
    card_data    JSONB,                              -- location_card 유형 시 좌표/주소 JSON
    is_read      BOOLEAN DEFAULT FALSE,
    sent_at      TIMESTAMPTZ DEFAULT NOW(),
    created_at   TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_guardian_msg_link ON tb_guardian_message(link_id, sent_at DESC);
CREATE INDEX idx_guardian_msg_trip ON tb_guardian_message(trip_id);
```

#### 4.11d TB_GUARDIAN_RELEASE_REQUEST (가디언 해제 요청) ⭐ 신규 v3.7

> 출처: migration-guardian-release-request.sql
> v3.7: 신규 정의. 가디언 해제 요청 관리 (멤버/가디언 → Captain 승인).

```sql
CREATE TABLE tb_guardian_release_request (
    request_id    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    link_id       UUID NOT NULL REFERENCES tb_guardian_link(link_id) ON DELETE CASCADE,
    trip_id       UUID NOT NULL REFERENCES tb_trip(trip_id) ON DELETE CASCADE,
    requested_by  VARCHAR(128) NOT NULL REFERENCES tb_user(user_id),
    status        VARCHAR(20) NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'approved', 'rejected')),
    captain_id    VARCHAR(128) REFERENCES tb_user(user_id), -- 승인/거부한 Captain
    responded_at  TIMESTAMPTZ,
    created_at    TIMESTAMPTZ DEFAULT NOW(),
    updated_at    TIMESTAMPTZ DEFAULT NOW()
);
```

---

### [D] 도메인: 일정 및 지오펜스

---

#### 4.12 TB_SCHEDULE (기본 일정)

> 출처: 01-init-schema.sql, 20-migration-schema-sync.sql
> v3.7 변경: title, description, all_day 추가

```sql
CREATE TABLE tb_schedule (
    schedule_id   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id       UUID REFERENCES tb_trip(trip_id),
    schedule_name VARCHAR(200),
    title         VARCHAR(200),                       -- v3.7: 일정 제목 (schedule_name에서 복사)
    description   TEXT,                               -- v3.7: 일정 설명
    all_day       BOOLEAN DEFAULT FALSE,              -- v3.7: 종일 일정 여부
    schedule_date DATE,
    start_time    TIME,
    end_time      TIME,
    location_name VARCHAR(200),
    location_address TEXT,
    location_lat  DOUBLE PRECISION,
    location_lng  DOUBLE PRECISION,
    notes         TEXT,
    order_index   INTEGER,
    created_by    VARCHAR(128) REFERENCES tb_user(user_id),
    created_at    TIMESTAMPTZ DEFAULT NOW(),
    updated_at    TIMESTAMPTZ
);

CREATE INDEX idx_schedule_trip ON tb_schedule(trip_id, schedule_date);
```

#### 4.13 TB_TRAVEL_SCHEDULE (고급 일정) — 스키마 확정

> 출처: 01-init-schema.sql, 12_일정탭_원칙_v1_0
> v3.0: 스키마 확정 (v2.0 Known Issue #3 해소)

```sql
CREATE TABLE tb_travel_schedule (
    schedule_id       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id          UUID REFERENCES tb_group(group_id),
    trip_id           UUID REFERENCES tb_trip(trip_id),
    created_by        VARCHAR(128) REFERENCES tb_user(user_id),
    title             VARCHAR(300) NOT NULL,
    description       TEXT,
    schedule_type     VARCHAR(50),
        -- flight | hotel | activity | transport | meal | meeting | other
    start_time        TIMESTAMPTZ NOT NULL,
    end_time          TIMESTAMPTZ,
    all_day           BOOLEAN DEFAULT FALSE,
    location_name     VARCHAR(300),
    location_address  TEXT,
    location_lat      DOUBLE PRECISION,
    location_lng      DOUBLE PRECISION,
    location_coords   GEOGRAPHY(Point, 4326),         -- PostGIS 타입
    participants      JSONB,                           -- [user_id, ...]
    estimated_cost    DECIMAL(12, 2),
    currency_code     VARCHAR(3),
    booking_reference VARCHAR(100),
    booking_status    VARCHAR(30),                     -- confirmed | pending | cancelled
    booking_url       TEXT,
    reminder_enabled  BOOLEAN DEFAULT FALSE,
    reminder_time     INTERVAL,
    attachments       JSONB,                           -- [{name, url, type}]
    is_completed      BOOLEAN DEFAULT FALSE,
    completed_at      TIMESTAMPTZ,
    timezone          VARCHAR(50),
    geofence_id       UUID REFERENCES tb_geofence(geofence_id),
    created_at        TIMESTAMPTZ DEFAULT NOW(),
    updated_at        TIMESTAMPTZ,
    deleted_at        TIMESTAMPTZ
);

CREATE INDEX idx_travel_schedule_group      ON tb_travel_schedule(group_id);
CREATE INDEX idx_travel_schedule_trip       ON tb_travel_schedule(trip_id);
CREATE INDEX idx_travel_schedule_start_time ON tb_travel_schedule(start_time);
```

> **v2.0 Known Issue #3 해소**: `location_lat`, `location_lng` 컬럼을 명시적으로 추가하여 서비스 레이어 오류 방지. `location_coords`(PostGIS)와 병행 사용.

#### 4.14 TB_GEOFENCE (안전 구역)

> 출처: 01-init-schema.sql

```sql
CREATE TABLE tb_geofence (
    geofence_id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id             UUID REFERENCES tb_group(group_id),
    trip_id              UUID REFERENCES tb_trip(trip_id),
    name                 VARCHAR(200) NOT NULL,
    description          TEXT,
    type                 VARCHAR(20),                 -- safe | watch | danger | stationary
    shape_type           VARCHAR(20),                 -- circle | polygon
    center_latitude      DOUBLE PRECISION,
    center_longitude     DOUBLE PRECISION,
    radius_meters        INTEGER,
    polygon_coordinates  JSONB,                       -- [[lat,lng], ...]
    is_always_active     BOOLEAN DEFAULT TRUE,
    valid_from           TIMESTAMPTZ,
    valid_until          TIMESTAMPTZ,
    trigger_on_enter     BOOLEAN DEFAULT TRUE,
    trigger_on_exit      BOOLEAN DEFAULT TRUE,
    dwell_time_seconds   INTEGER DEFAULT 0,
    notify_group         BOOLEAN DEFAULT TRUE,
    notify_guardians     BOOLEAN DEFAULT TRUE,
    -- ▼ v3.5: is_active 복원 (01-init-schema.sql에 존재하나 v3.3 문서에서 누락됨)
    is_active            BOOLEAN DEFAULT TRUE,
    schedule_id          UUID REFERENCES tb_schedule(schedule_id),
    created_by           VARCHAR(128) REFERENCES tb_user(user_id),
    created_at           TIMESTAMPTZ DEFAULT NOW(),
    updated_at           TIMESTAMPTZ
);

CREATE INDEX idx_geofence_group    ON tb_geofence(group_id);
CREATE INDEX idx_geofence_trip     ON tb_geofence(trip_id);
CREATE INDEX idx_geofence_active   ON tb_geofence(group_id, is_active) WHERE is_active = TRUE;
```

#### 4.14a TB_GEOFENCE_EVENT (지오펜스 진입/이탈 이벤트)

> 출처: 20-migration-schema-sync.sql (실제 DB 기준)
> v3.7 변경: trip_id/dwell_time_seconds 제거, occurred_at→triggered_at, geofence_id/lat/lng nullable, event_type VARCHAR(20)

```sql
CREATE TABLE tb_geofence_event (
    event_id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    geofence_id          UUID REFERENCES tb_geofence(geofence_id),
    user_id              VARCHAR(128) NOT NULL,
    event_type           VARCHAR(20) NOT NULL,        -- enter | exit
    latitude             DOUBLE PRECISION,
    longitude            DOUBLE PRECISION,
    triggered_at         TIMESTAMPTZ DEFAULT NOW(),
    created_at           TIMESTAMPTZ DEFAULT NOW()
);
```

#### 4.14b TB_GEOFENCE_PENALTY (지오펜스 위반 패널티)

> 출처: 20-migration-schema-sync.sql (실제 DB 기준)
> v3.7 변경: event_id→geofence_event_id, trip_id/penalty_reason/cumulative_violations/resolved_at 제거, penalty_amount/applied_at 추가

```sql
CREATE TABLE tb_geofence_penalty (
    penalty_id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    geofence_event_id       UUID REFERENCES tb_geofence_event(event_id),
    user_id                 VARCHAR(128) NOT NULL,
    penalty_type            VARCHAR(30),
    penalty_amount          INTEGER DEFAULT 0,
    applied_at              TIMESTAMPTZ DEFAULT NOW(),
    created_at              TIMESTAMPTZ DEFAULT NOW()
);
```

#### 4.14c TB_SCHEDULE_HISTORY (일정 수정 이력) ⭐ 신규 v3.7

> 출처: 11-schema-schedule-history.sql

```sql
CREATE TABLE tb_schedule_history (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    schedule_id     UUID NOT NULL REFERENCES tb_travel_schedule(travel_schedule_id) ON DELETE CASCADE,
    modified_by     VARCHAR(128) NOT NULL REFERENCES tb_user(user_id),
    field_name      VARCHAR(50) NOT NULL,
    old_value       TEXT,
    new_value       TEXT,
    modified_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_schedule_history_schedule ON tb_schedule_history(schedule_id);
CREATE INDEX idx_schedule_history_modified ON tb_schedule_history(modified_at);
```

#### 4.14d TB_SCHEDULE_COMMENT (일정 댓글) ⭐ 신규 v3.7

> 출처: 12-schema-schedule-social.sql

```sql
CREATE TABLE tb_schedule_comment (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    schedule_id     UUID NOT NULL REFERENCES tb_travel_schedule(travel_schedule_id) ON DELETE CASCADE,
    user_id         VARCHAR(128) NOT NULL REFERENCES tb_user(user_id),
    content         TEXT NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at      TIMESTAMPTZ
);

CREATE INDEX idx_schedule_comment_schedule ON tb_schedule_comment(schedule_id);
```

#### 4.14e TB_SCHEDULE_REACTION (일정 리액션) ⭐ 신규 v3.7

> 출처: 12-schema-schedule-social.sql

```sql
CREATE TABLE tb_schedule_reaction (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    schedule_id     UUID NOT NULL REFERENCES tb_travel_schedule(travel_schedule_id) ON DELETE CASCADE,
    user_id         VARCHAR(128) NOT NULL REFERENCES tb_user(user_id),
    emoji           VARCHAR(10) NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_schedule_reaction UNIQUE(schedule_id, user_id, emoji)
);

CREATE INDEX idx_schedule_reaction_schedule ON tb_schedule_reaction(schedule_id);
```

#### 4.14f TB_SCHEDULE_VOTE (일정 투표) ⭐ 신규 v3.7

> 출처: 13-schema-schedule-voting.sql

```sql
CREATE TABLE tb_schedule_vote (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id         UUID NOT NULL REFERENCES tb_trip(trip_id) ON DELETE CASCADE,
    title           VARCHAR(200) NOT NULL,
    created_by      VARCHAR(128) NOT NULL REFERENCES tb_user(user_id),
    status          VARCHAR(20) NOT NULL DEFAULT 'open',
    deadline        TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_schedule_vote_trip ON tb_schedule_vote(trip_id);
```

#### 4.14g TB_SCHEDULE_VOTE_OPTION (투표 옵션) ⭐ 신규 v3.7

> 출처: 13-schema-schedule-voting.sql

```sql
CREATE TABLE tb_schedule_vote_option (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vote_id         UUID NOT NULL REFERENCES tb_schedule_vote(id) ON DELETE CASCADE,
    label           VARCHAR(200) NOT NULL,
    schedule_data   JSONB
);
```

#### 4.14h TB_SCHEDULE_VOTE_RESPONSE (투표 응답) ⭐ 신규 v3.7

> 출처: 13-schema-schedule-voting.sql

```sql
CREATE TABLE tb_schedule_vote_response (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vote_id         UUID NOT NULL REFERENCES tb_schedule_vote(id) ON DELETE CASCADE,
    option_id       UUID NOT NULL REFERENCES tb_schedule_vote_option(id) ON DELETE CASCADE,
    user_id         VARCHAR(128) NOT NULL REFERENCES tb_user(user_id),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_vote_response UNIQUE(vote_id, user_id)
);
```

#### 4.14i TB_SCHEDULE_TEMPLATE (일정 템플릿) ⭐ 신규 v3.7

> 출처: 14-schema-schedule-templates.sql

```sql
CREATE TABLE tb_schedule_template (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name            VARCHAR(200) NOT NULL,
    category        VARCHAR(50),
    items           JSONB NOT NULL DEFAULT '[]',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

---

### [E] 도메인: 위치 및 이동기록

---

#### 4.15 TB_LOCATION_SHARING (위치 공유 설정)

> 출처: 01-init-schema.sql, 20-migration-schema-sync.sql
> v3.7 변경: visibility_member_ids, is_active 추가

```sql
CREATE TABLE tb_location_sharing (
    sharing_id      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id        UUID REFERENCES tb_group(group_id),
    -- ▼ v3.5: trip_id 추가 — 위치 공유는 여행 단위로 관리 (같은 그룹 내 여행별 설정 분리)
    trip_id         UUID REFERENCES tb_trip(trip_id) ON DELETE CASCADE,
    user_id         VARCHAR(128) REFERENCES tb_user(user_id),
    target_user_id  VARCHAR(128) REFERENCES tb_user(user_id),
    is_sharing      BOOLEAN DEFAULT TRUE,
    -- ▼ v3.5: 공개 범위 3단계 (비즈니스 원칙 v5.1 §04.4)
    visibility_type VARCHAR(20) DEFAULT 'all'
        CHECK (visibility_type IN (
            'all',          -- 전체 공개: 그룹 모든 멤버가 위치 조회 가능
            'admin_only',   -- 관리자만: captain/crew_chief만 위치 조회 가능
            'specified'     -- 지정 멤버: target_user_id로 지정된 멤버만 가능
        )),
    -- ▼ v3.7: 지정 멤버 목록 (JSONB 배열 — specified 타입에서 사용)
    visibility_member_ids JSONB,                     -- ["userId1", "userId2", ...]
    is_active       BOOLEAN DEFAULT TRUE,            -- v3.7: 활성 상태 플래그
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ
);

CREATE INDEX idx_location_sharing_user   ON tb_location_sharing(user_id);
CREATE INDEX idx_location_sharing_target ON tb_location_sharing(target_user_id);
CREATE INDEX idx_location_sharing_trip   ON tb_location_sharing(trip_id);
```

#### 4.15a TB_LOCATION_SCHEDULE (위치 공유 시간대 스케줄) ⭐ 신규 v3.5

> 출처: 비즈니스 원칙 v5.1 §04.3 유형 B (time_based)
> v3.5: 신규 정의. `schedule_type = 'time_based'`인 여행에서 요일/시간대별 위치 공유 ON/OFF 설정.
> v3.5.1: `specific_date DATE` 컬럼 추가 — 비즈니스 원칙 v5.1 §04.3 "특정 일자에만 선택적으로 적용" 옵션 지원.

```sql
CREATE TABLE tb_location_schedule (
    schedule_id   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id       UUID NOT NULL REFERENCES tb_trip(trip_id) ON DELETE CASCADE,
    user_id       VARCHAR(128) NOT NULL REFERENCES tb_user(user_id) ON DELETE CASCADE,
    -- ▼ 적용 범위 (비즈니스 원칙 v5.1 §04.3 3가지 옵션)
    -- 옵션 A: 여행 전체 기간 적용 → day_of_week IS NULL AND specific_date IS NULL
    -- 옵션 B: 요일별 적용 → day_of_week IS NOT NULL, specific_date IS NULL
    -- 옵션 C: 특정 일자 적용 → specific_date IS NOT NULL, day_of_week IS NULL
    day_of_week   INTEGER CHECK (day_of_week BETWEEN 0 AND 6),  -- 0=일, 1=월 ... 6=토
    specific_date DATE,                                          -- 특정 일자 (예: 2026-04-15)
    -- ▼ day_of_week, specific_date 동시 지정 금지 (상호 배타적)
    CONSTRAINT chk_schedule_scope
        CHECK (day_of_week IS NULL OR specific_date IS NULL),
    -- ▼ 공유 시간대
    share_start   TIME NOT NULL,           -- 예) 09:00 (공유 시작 시각)
    share_end     TIME NOT NULL,           -- 예) 18:00 (공유 종료 시각)
    is_active     BOOLEAN DEFAULT TRUE,
    created_at    TIMESTAMPTZ DEFAULT NOW(),
    updated_at    TIMESTAMPTZ
);

CREATE INDEX idx_location_schedule_trip  ON tb_location_schedule(trip_id);
CREATE INDEX idx_location_schedule_user  ON tb_location_schedule(trip_id, user_id);
CREATE INDEX idx_location_schedule_date  ON tb_location_schedule(trip_id, specific_date) WHERE specific_date IS NOT NULL;
```

> **적용 범위 결정 로직** (비즈니스 원칙 v5.1 §04.3):
> - `day_of_week IS NULL AND specific_date IS NULL` → 여행 전체 기간에 동일 시간대 적용
> - `day_of_week IS NOT NULL` → 해당 요일에만 적용 (NULL이면 해당 요일 미지정)
> - `specific_date IS NOT NULL` → 해당 날짜에만 적용 (다른 날짜 무시)
> - 서비스 레이어는 현재 시각과 `share_start~share_end` 범위를 비교해 위치 공유 여부를 결정한다.

#### 4.16 TB_LOCATION_LOG → TB_LOCATION (이동 경로 기록)

> 출처: SafeTrip_멤버별_이동기록_화면_원칙_v1_0 (원칙 정의) + database-schema.sql (실제 구현)
>
> ⚠️ **v3.0 실제 구현 반영**: 원칙 문서에서 정의한 `TB_LOCATION_LOG`는 실제 구현에서 `TB_LOCATION`으로 확장되었다.
> PostGIS 공간 컬럼(`geom`), 이동 세션 그룹핑(`movement_session_id`), Activity Recognition, 순차 인덱스(`i_idx`) 등이 추가된 실제 구현 스키마가 `TB_LOCATION`이다.
> 기존 코드/서비스/문서에서 `TB_LOCATION_LOG`를 참조하는 경우 `TB_LOCATION`으로 갱신해야 한다.

**▼ 원칙 문서 정의 (참고 — 실제 구현과 다름)**

```sql
-- [원칙 문서 정의 — 실제 DB에는 TB_LOCATION으로 생성됨]
CREATE TABLE tb_location_log (
    log_id        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id      UUID NOT NULL REFERENCES tb_group(group_id),
    user_id       VARCHAR(128) NOT NULL REFERENCES tb_user(user_id),
    latitude      DOUBLE PRECISION NOT NULL,
    longitude     DOUBLE PRECISION NOT NULL,
    accuracy      REAL,                            -- 위치 정확도 (미터)
    speed         REAL,                            -- 순간 속도 (m/s)
    bearing       REAL,                            -- 이동 방향 (도)
    altitude      REAL,                            -- 고도 (미터)
    battery_level SMALLINT,                        -- 기록 시점 배터리 (%)
    is_sharing    BOOLEAN DEFAULT TRUE,            -- 공유 상태에서 기록된 데이터인지
    recorded_at   TIMESTAMPTZ NOT NULL,
    created_at    TIMESTAMPTZ DEFAULT NOW()
);
```

**▼ 실제 구현 스키마 (database-schema.sql + 20-migration-schema-sync.sql — 실제 테스트 검증 완료)**

```sql
CREATE TABLE tb_location (
    -- 기본 정보
    location_id       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id           VARCHAR(128) NOT NULL REFERENCES tb_user(user_id) ON DELETE CASCADE,
    -- ▼ v3.7: trip_id, group_id 추가 (여행/그룹 단위 위치 조회 지원)
    trip_id           UUID,
    group_id          UUID,

    -- 좌표
    latitude          DECIMAL(10, 8) NOT NULL,
    longitude         DECIMAL(11, 8) NOT NULL,
    accuracy          DECIMAL(6, 2),
    altitude          DECIMAL(8, 2),

    -- PostGIS 지원
    geom              GEOGRAPHY(POINT, 4326),       -- PostGIS 공간 인덱스용

    -- 주소 정보 (Reverse Geocoding)
    address           TEXT,
    city              VARCHAR(100),
    country           VARCHAR(100),

    -- 이동 정보
    speed             DECIMAL(6, 2),
    heading           DECIMAL(5, 2),                -- 이동 방향 (도)
    bearing           DOUBLE PRECISION,              -- v3.7: 방위각 (도)

    -- 디바이스 상태
    battery_level     INTEGER,
    network_type      VARCHAR(20),

    -- v3.7: 추가 메타데이터
    is_sharing        BOOLEAN DEFAULT TRUE,          -- 공유 상태 플래그
    motion_state      VARCHAR(20),                   -- moving | stationary | unknown
    provider          VARCHAR(20),                   -- gps | network | fused
    server_received_at TIMESTAMPTZ,                  -- 서버 수신 시각

    -- 추적 모드
    tracking_mode     VARCHAR(20) DEFAULT 'normal', -- normal | power_saving | minimal | sos

    -- 이동 세션 정보
    movement_session_id UUID,                       -- 같은 이동 구간 그룹화 (논리키)
    is_movement_start BOOLEAN DEFAULT FALSE,        -- 정지 → 이동 전환 시 TRUE
    is_movement_end   BOOLEAN DEFAULT FALSE,        -- 이동 → 정지 전환 시 TRUE (5분 이상 정지 후 확정)

    -- Activity Recognition
    activity_type     VARCHAR(20),                  -- still | walking | running | on_bicycle | in_vehicle | unknown
    activity_confidence INTEGER,                    -- 신뢰도 (0-100)

    -- 사용자별 순차 인덱스 (자동 증가, 삽입 순서 보장)
    i_idx             BIGINT,

    -- 메타데이터
    recorded_at       TIMESTAMPTZ NOT NULL DEFAULT (now() AT TIME ZONE 'UTC'),
    synced_at         TIMESTAMPTZ,
    is_offline        BOOLEAN DEFAULT FALSE,

    -- 제약조건
    CONSTRAINT chk_latitude  CHECK (latitude  BETWEEN -90  AND 90),
    CONSTRAINT chk_longitude CHECK (longitude BETWEEN -180 AND 180),
    CONSTRAINT chk_battery   CHECK (battery_level BETWEEN 0 AND 100)
);

-- PostGIS 공간 인덱스 (공간 쿼리 최적화)
CREATE INDEX idx_locations_geom                ON tb_location USING GIST(geom);
CREATE INDEX idx_locations_user_id             ON tb_location(user_id);
CREATE INDEX idx_locations_recorded_at         ON tb_location(recorded_at DESC);
CREATE INDEX idx_locations_coords              ON tb_location(latitude, longitude);
CREATE INDEX idx_locations_movement_session    ON tb_location(movement_session_id) WHERE movement_session_id IS NOT NULL;
CREATE INDEX idx_locations_movement_session_user ON tb_location(user_id, movement_session_id, recorded_at) WHERE movement_session_id IS NOT NULL;
CREATE INDEX idx_locations_movement_start      ON tb_location(user_id, is_movement_start) WHERE is_movement_start = TRUE;
CREATE INDEX idx_locations_movement_end        ON tb_location(user_id, is_movement_end)   WHERE is_movement_end   = TRUE;
CREATE INDEX idx_locations_user_idx            ON tb_location(user_id, i_idx);
```

> **이동 세션(movement_session_id) 개념**:
> - 앱이 감지하는 이동 구간 단위. Flutter가 `is_movement_start=TRUE` 위치와 함께 세션 ID를 생성·전송.
> - 동일한 `movement_session_id`를 가진 위치 레코드들을 시간순 연결하면 한 번의 이동 경로가 된다.
> - PostGIS `ST_MakeLine(geom ORDER BY recorded_at)` + `ST_Length(...::geography)`로 총 거리(km) 계산.
> - `activity_type = 'in_vehicle'`이 하나라도 존재하면 `vehicle_type = 'vehicle'`, 그렇지 않으면 `'walking'`.
> - RTDB `realtime_users/{userId}/active_session_id`에서 진행 중인 세션 ID 조회.
> - 종료된 세션은 위치 개수 ≥ 10개(`SESSION_SUMMARY_MIN_COUNT`)인 경우만 세션 목록에 표시.

#### 4.17 TB_STAY_POINT (체류 지점 감지)

> 출처: SafeTrip_멤버별_이동기록_화면_원칙_v1_0
> ℹ️ 원칙 문서 정의. 이동 세션 간 정지 구간을 감지·저장하는 테이블 (미구현, migration-v3-location-tracking.sql에서 생성 예정).

```sql
CREATE TABLE tb_stay_point (
    stay_id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id         UUID NOT NULL REFERENCES tb_group(group_id),
    user_id          VARCHAR(128) NOT NULL REFERENCES tb_user(user_id),
    center_lat       DOUBLE PRECISION NOT NULL,
    center_lng       DOUBLE PRECISION NOT NULL,
    arrived_at       TIMESTAMPTZ NOT NULL,
    departed_at      TIMESTAMPTZ,
    duration_minutes INTEGER,
    created_at       TIMESTAMPTZ DEFAULT NOW()
);
```

---

#### 4.17a TB_SESSION_MAP_IMAGE (세션 지도 이미지 캐시)

> 출처: database-schema.sql (실제 구현), map-image.service.ts
> v3.0 추가: 이동 세션 종료 후 Google Maps Static API로 생성한 경로 이미지를 Firebase Storage에 업로드하고 URL을 캐싱.
> 진행 중 세션(`is_ongoing=true`)은 이미지를 생성하지 않음.

```sql
CREATE TABLE tb_session_map_image (
    session_id       UUID PRIMARY KEY,             -- movement_session_id (세션 고유 식별자)
    user_id          VARCHAR(128) NOT NULL REFERENCES tb_user(user_id) ON DELETE CASCADE,
    map_image_url    TEXT,                         -- Firebase Storage에 저장된 지도 이미지 URL (우선)
    map_image_base64 TEXT,                         -- Base64 인코딩 이미지 (하위 호환성, 점진적 제거 예정)
    created_at       TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_session_map_image_user_id    ON tb_session_map_image(user_id);
CREATE INDEX idx_session_map_image_created_at ON tb_session_map_image(created_at DESC);
CREATE INDEX idx_session_map_image_url        ON tb_session_map_image(map_image_url) WHERE map_image_url IS NOT NULL;
```

> **이미지 저장 전략**:
> - Firebase Storage 경로: `{groupId}/session_maps/{userId}/{sessionId}.png`
> - URL이 있으면 Firebase Storage에서 파일 존재 여부 검증 후 반환
> - DB에 URL 있지만 Storage에 파일 없음 → 재생성 트리거
> - `map_image_base64`는 하위 호환성 용도로 유지 (URL로 마이그레이션 예정)

---

#### 4.17b TB_PLANNED_ROUTE (계획된 경로)

> 출처: database-schema.sql (실제 구현)
> Route Deviation Detection을 위해 사전에 등록하는 여행 경로.

```sql
CREATE TABLE tb_planned_route (
    route_id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id            UUID NOT NULL REFERENCES tb_trip(trip_id) ON DELETE CASCADE,
    user_id            VARCHAR(128) NOT NULL REFERENCES tb_user(user_id) ON DELETE CASCADE,

    -- 경로 정보
    route_name         VARCHAR(200),
    start_location     VARCHAR(200) NOT NULL,
    end_location       VARCHAR(200) NOT NULL,
    start_coords       GEOGRAPHY(Point, 4326) NOT NULL,
    end_coords         GEOGRAPHY(Point, 4326) NOT NULL,

    -- 경로 데이터 (GeoJSON LineString)
    route_path         JSONB NOT NULL,             -- GeoJSON LineString 형식
    waypoints          JSONB,                      -- [{"name":"...","lat":...,"lng":...,"order":1}]

    -- 경로 속성
    total_distance     DECIMAL(10, 2),             -- 전체 경로 거리 (km)
    estimated_duration INTEGER,                    -- 예상 소요 시간 (분)

    -- 이탈 감지 설정
    deviation_threshold INTEGER DEFAULT 100,       -- 이탈 감지 임계값 (미터, 기본 100m)
    is_active          BOOLEAN DEFAULT TRUE,

    -- 일정
    scheduled_start    TIMESTAMPTZ,
    scheduled_end      TIMESTAMPTZ,

    -- 메타데이터
    created_at         TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at         TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    deleted_at         TIMESTAMPTZ
);

CREATE INDEX idx_planned_routes_trip       ON tb_planned_route(trip_id);
CREATE INDEX idx_planned_routes_user       ON tb_planned_route(user_id);
CREATE INDEX idx_planned_routes_active     ON tb_planned_route(is_active) WHERE is_active = TRUE;
CREATE INDEX idx_planned_routes_schedule   ON tb_planned_route(scheduled_start, scheduled_end);
CREATE INDEX idx_planned_routes_start_geom ON tb_planned_route USING GIST(start_coords);
CREATE INDEX idx_planned_routes_end_geom   ON tb_planned_route USING GIST(end_coords);
```

---

#### 4.17c TB_ROUTE_DEVIATION (경로 이탈 감지 로그)

> 출처: database-schema.sql (실제 구현)
> 사전 계획 경로(`TB_PLANNED_ROUTE`)에서 실제 이동 경로가 벗어날 때 감지·기록하는 테이블.

```sql
CREATE TABLE tb_route_deviation (
    deviation_id        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    route_id            UUID NOT NULL REFERENCES tb_planned_route(route_id) ON DELETE CASCADE,
    trip_id             UUID NOT NULL REFERENCES tb_trip(trip_id) ON DELETE CASCADE,
    user_id             VARCHAR(128) NOT NULL REFERENCES tb_user(user_id) ON DELETE CASCADE,

    -- 이탈 위치
    deviation_location  GEOGRAPHY(Point, 4326) NOT NULL,
    deviation_distance  DECIMAL(10, 2) NOT NULL,   -- 계획 경로로부터의 거리 (미터)

    -- 이탈 상태
    deviation_status    VARCHAR(20) NOT NULL DEFAULT 'active',
                                                   -- active | resolved | ignored
    severity            VARCHAR(20) DEFAULT 'low', -- low(<100m) | medium(100-300m) | high(300-500m) | critical(>500m)

    -- 이탈 시간
    started_at          TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ended_at            TIMESTAMPTZ,
    duration            INTEGER,                   -- 이탈 지속 시간 (초)

    -- 알림 여부
    guardian_notified   BOOLEAN DEFAULT FALSE,
    notification_sent_at TIMESTAMPTZ,

    -- 연속 이탈 카운트 (3회 이상 시 경고 알림)
    consecutive_count   INTEGER DEFAULT 1,

    -- 메타데이터
    created_at          TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT chk_deviation_status CHECK (deviation_status IN ('active', 'resolved', 'ignored')),
    CONSTRAINT chk_severity         CHECK (severity IN ('low', 'medium', 'high', 'critical'))
);

CREATE INDEX idx_route_deviations_route   ON tb_route_deviation(route_id);
CREATE INDEX idx_route_deviations_trip    ON tb_route_deviation(trip_id);
CREATE INDEX idx_route_deviations_user    ON tb_route_deviation(user_id);
CREATE INDEX idx_route_deviations_status  ON tb_route_deviation(deviation_status);
CREATE INDEX idx_route_deviations_started ON tb_route_deviation(started_at DESC);
CREATE INDEX idx_route_deviations_geom    ON tb_route_deviation USING GIST(deviation_location);
```

> **심각도 기준**:
> | severity | 조건 | 알림 |
> |----------|------|------|
> | low | < 100m | 없음 |
> | medium | 100–300m | 가디언 앱 푸시 |
> | high | 300–500m | 가디언 + 캡틴 푸시 |
> | critical | > 500m | 긴급 알림 + SOS 고려 |

#### 4.17d TB_MOVEMENT_SESSION (이동 세션 집계)

> 출처: 20-migration-schema-sync.sql, migrations/20260307-add-movement-session-table.sql
> v3.7 변경: 4→14개 컬럼 완전 재작성. trip_id, 거리/시간/교통수단/좌표 추가. is_completed→is_active (의미 반전).

```sql
CREATE TABLE tb_movement_session (
    session_id       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id          VARCHAR(128) NOT NULL REFERENCES tb_user(user_id) ON DELETE CASCADE,
    trip_id          UUID REFERENCES tb_trip(trip_id),         -- v3.7: 여행 연결
    start_time       TIMESTAMPTZ NOT NULL,
    end_time         TIMESTAMPTZ,
    -- ▼ v3.7: 이동 통계
    distance_meters  DOUBLE PRECISION DEFAULT 0,
    duration_seconds INTEGER DEFAULT 0,
    transport_mode   VARCHAR(20),                              -- walking | vehicle | bicycle | unknown
    -- ▼ v3.7: 시작/종료 좌표
    start_latitude   DOUBLE PRECISION,
    start_longitude  DOUBLE PRECISION,
    end_latitude     DOUBLE PRECISION,
    end_longitude    DOUBLE PRECISION,
    -- ▼ v3.7: 상태 (is_completed → is_active로 의미 반전)
    is_active        BOOLEAN DEFAULT TRUE,
    created_at       TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_movement_session_user  ON tb_movement_session(user_id);
CREATE INDEX idx_movement_session_start ON tb_movement_session(start_time DESC);
```

> **TB_LOCATION과의 관계**: TB_LOCATION.movement_session_id → tb_movement_session.session_id FK. 세션이 진행 중(is_active=TRUE)이면 RTDB realtime_users/{userId}/active_session_id와 동기화.

---

### [F] 도메인: 안전 및 SOS

---

#### 4.18 TB_HEARTBEAT (생존 신호)

> 출처: SafeTrip_SOS_원칙_v1_0

```sql
CREATE TABLE tb_heartbeat (
    id             BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    user_id        VARCHAR(128) NOT NULL REFERENCES tb_user(user_id) ON DELETE CASCADE,
    trip_id        UUID NOT NULL REFERENCES tb_trip(trip_id) ON DELETE CASCADE,
    timestamp      TIMESTAMPTZ NOT NULL,
    location_lat   DECIMAL,
    location_lng   DECIMAL,
    battery_level  INTEGER,
    battery_charging BOOLEAN,
    network_type   VARCHAR(10),                    -- wifi | 4g | 5g | none
    app_state      VARCHAR(20),                    -- foreground | background | doze
    motion_state   VARCHAR(20)                     -- moving | stationary | unknown
);

CREATE INDEX idx_heartbeat_user ON tb_heartbeat(user_id, timestamp DESC);
CREATE INDEX idx_heartbeat_trip ON tb_heartbeat(trip_id, timestamp DESC);
```

#### 4.19 TB_SOS_EVENT (SOS 이벤트)

> 출처: SafeTrip_SOS_원칙_v1_0

```sql
CREATE TABLE tb_sos_event (
    id              BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    event_type      VARCHAR(20) NOT NULL,           -- SOS | AUTO_SOS | OFFLINE_SOS
    sender_id       VARCHAR(128) REFERENCES tb_user(user_id) ON DELETE SET NULL,
    trip_id         UUID REFERENCES tb_trip(trip_id) ON DELETE SET NULL,
    trigger_type    VARCHAR(30),                    -- manual | heartbeat_timeout | battery_drain
    suspicion_score INTEGER,
    location_lat    DECIMAL,
    location_lng    DECIMAL,
    battery_level   INTEGER,
    sent_at         TIMESTAMPTZ NOT NULL,
    resolved_at     TIMESTAMPTZ,
    resolved_by     VARCHAR(128),
    resolution_type VARCHAR(30)                     -- confirmed_safe | power_recovery | false_alarm
);
```

#### 4.20 TB_POWER_EVENT (전원 이벤트)

> 출처: SafeTrip_SOS_원칙_v1_0

```sql
CREATE TABLE tb_power_event (
    id                   BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    event_type           VARCHAR(20) NOT NULL,      -- LAST_BEACON | SHUTDOWN | POWER_RECOVERY
    user_id              VARCHAR(128) REFERENCES tb_user(user_id) ON DELETE SET NULL,
    trip_id              UUID REFERENCES tb_trip(trip_id) ON DELETE SET NULL,
    location_lat         DECIMAL,
    location_lng         DECIMAL,
    battery_level        INTEGER,
    offline_duration_min INTEGER,
    timestamp            TIMESTAMPTZ NOT NULL
);
```

#### 4.21 TB_SOS_RESCUE_LOG (구조 연동 기록)

> 출처: SafeTrip_긴급_구조기관_연동_원칙_v1_0

```sql
CREATE TABLE tb_sos_rescue_log (
    rescue_log_id   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sos_event_id    BIGINT NOT NULL REFERENCES tb_sos_event(id) ON DELETE CASCADE,
    group_id        UUID REFERENCES tb_group(group_id) ON DELETE SET NULL,
    user_id         VARCHAR(128) REFERENCES tb_user(user_id) ON DELETE SET NULL,
    action_type     VARCHAR(30) NOT NULL,
        -- dial_police | dial_ambulance | dial_fire |
        -- dial_embassy | dial_consular |
        -- copy_location | sms_fallback
    target_number   VARCHAR(30),
    target_country  VARCHAR(5),
    initiated_by    VARCHAR(128) REFERENCES tb_user(user_id) ON DELETE SET NULL,
    is_proxy_report BOOLEAN DEFAULT FALSE,
    location_shared BOOLEAN DEFAULT FALSE,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);
```

#### 4.22 TB_SOS_CANCEL_LOG (SOS 해제 기록)

> 출처: SafeTrip_긴급_구조기관_연동_원칙_v1_0

```sql
CREATE TABLE tb_sos_cancel_log (
    cancel_log_id    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sos_event_id     BIGINT NOT NULL REFERENCES tb_sos_event(id) ON DELETE CASCADE,
    group_id         UUID REFERENCES tb_group(group_id) ON DELETE SET NULL,
    cancelled_by     VARCHAR(128) REFERENCES tb_user(user_id) ON DELETE SET NULL,
    cancel_reason    VARCHAR(30),  -- user_cancelled | captain_cancelled | auto_resolved
    cancel_within_sec INTEGER,
    created_at       TIMESTAMPTZ DEFAULT NOW()
);
```

#### 4.22a TB_ATTENDANCE_CHECK (출석 체크 세션) ⭐ 신규 v3.5

> 출처: 비즈니스 원칙 v5.1 §05.5 출석 확인
> v3.5: 신규 정의. captain/crew_chief가 개시한 출석 체크 세션 기록.

```sql
CREATE TABLE tb_attendance_check (
    check_id      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id       UUID NOT NULL REFERENCES tb_trip(trip_id) ON DELETE CASCADE,
    group_id      UUID NOT NULL REFERENCES tb_group(group_id) ON DELETE CASCADE,
    initiated_by  VARCHAR(128) REFERENCES tb_user(user_id) ON DELETE SET NULL,
    status        VARCHAR(20) DEFAULT 'ongoing'
        CHECK (status IN ('ongoing', 'completed', 'cancelled')),
    deadline_at   TIMESTAMPTZ NOT NULL,       -- 응답 마감 시각
    created_at    TIMESTAMPTZ DEFAULT NOW(),
    completed_at  TIMESTAMPTZ
);

CREATE INDEX idx_attendance_check_trip  ON tb_attendance_check(trip_id, created_at DESC);
CREATE INDEX idx_attendance_check_group ON tb_attendance_check(group_id, status);
```

#### 4.22b TB_ATTENDANCE_RESPONSE (출석 체크 응답) ⭐ 신규 v3.5

> 멤버별 출석 체크 응답 결과.

```sql
CREATE TABLE tb_attendance_response (
    response_id   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    check_id      UUID NOT NULL REFERENCES tb_attendance_check(check_id) ON DELETE CASCADE,
    user_id       VARCHAR(128) NOT NULL REFERENCES tb_user(user_id) ON DELETE CASCADE,
    response_type VARCHAR(20) DEFAULT 'unknown'
        CHECK (response_type IN (
            'present',   -- 현재 위치 확인 완료
            'absent',    -- 미응답 / 비출석
            'unknown'    -- 아직 응답 전
        )),
    responded_at  TIMESTAMPTZ,
    created_at    TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(check_id, user_id)
);

CREATE INDEX idx_attendance_response_check ON tb_attendance_response(check_id);
CREATE INDEX idx_attendance_response_user  ON tb_attendance_response(user_id, created_at DESC);
```

> **동작 흐름**: captain/crew_chief가 출석 체크 개시 → TB_ATTENDANCE_CHECK 행 생성 + 그룹 전 멤버에게 FCM 알림 → 각 멤버 앱에서 확인 응답 → TB_ATTENDANCE_RESPONSE 업데이트 → deadline_at 경과 시 미응답자 `absent` 처리 → captain에게 요약 알림.

#### 4.22c TB_EMERGENCY (긴급 상황)

> 출처: 20-migration-schema-sync.sql (실제 DB 기준)
> v3.7 변경: 간소화 — severity, acknowledged_by/at, resolution_note, escalation_level, last_escalated_at 제거. trip_id nullable. updated_at 추가.

```sql
CREATE TABLE tb_emergency (
    emergency_id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id              UUID REFERENCES tb_trip(trip_id),
    user_id              VARCHAR(128) NOT NULL REFERENCES tb_user(user_id),
    emergency_type       VARCHAR(30) NOT NULL DEFAULT 'sos',
    status               VARCHAR(20) DEFAULT 'active',
    latitude             DOUBLE PRECISION,
    longitude            DOUBLE PRECISION,
    description          TEXT,
    resolved_at          TIMESTAMPTZ,
    resolved_by          VARCHAR(128),
    created_at           TIMESTAMPTZ DEFAULT NOW(),
    updated_at           TIMESTAMPTZ DEFAULT NOW()
);
```

#### 4.22d TB_EMERGENCY_RECIPIENT (긴급 알림 수신자)

> 출처: 20-migration-schema-sync.sql (실제 DB 기준)
> v3.7 변경: 간소화 — recipient_type, channels, is_acknowledged, acknowledged_at, response_message 제거. notified_at 추가.

```sql
CREATE TABLE tb_emergency_recipient (
    recipient_id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    emergency_id         UUID REFERENCES tb_emergency(emergency_id),
    user_id              VARCHAR(128) NOT NULL,
    notified_at          TIMESTAMPTZ,
    acknowledged_at      TIMESTAMPTZ,
    created_at           TIMESTAMPTZ DEFAULT NOW()
);
```

#### 4.22e TB_NO_RESPONSE_EVENT (무응답 이벤트)

> 출처: 20-migration-schema-sync.sql (실제 DB 기준)
> v3.7 변경: PK no_response_id→event_id, check_type default 'safety_checkin', status default 'pending', threshold_minutes/check_started_at 제거, triggered_at/resolved_at 추가.

```sql
CREATE TABLE tb_no_response_event (
    event_id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id              VARCHAR(128) NOT NULL REFERENCES tb_user(user_id),
    trip_id              UUID REFERENCES tb_trip(trip_id),
    check_type           VARCHAR(20) DEFAULT 'safety_checkin',
    triggered_at         TIMESTAMPTZ DEFAULT NOW(),
    resolved_at          TIMESTAMPTZ,
    status               VARCHAR(20) DEFAULT 'pending',
    created_at           TIMESTAMPTZ DEFAULT NOW()
);
```

#### 4.22f TB_SAFETY_CHECKIN (안전 체크인)

> 출처: 20-migration-schema-sync.sql (실제 DB 기준)
> v3.7 변경: 간소화 — location_id, address, status, battery_level, network_type, requested_by_user_id, requested_at, visibility 제거. checkin_type default 'manual'. 좌표 타입 DOUBLE PRECISION.

```sql
CREATE TABLE tb_safety_checkin (
    checkin_id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id              VARCHAR(128) NOT NULL REFERENCES tb_user(user_id),
    trip_id              UUID REFERENCES tb_trip(trip_id),
    checkin_type         VARCHAR(20) DEFAULT 'manual',
    latitude             DOUBLE PRECISION,
    longitude            DOUBLE PRECISION,
    message              TEXT,
    created_at           TIMESTAMPTZ DEFAULT NOW()
);
```

---

