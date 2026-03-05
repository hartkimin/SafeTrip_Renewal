---
date: '2026-03-05'
version: v3.6
part: 2/3
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

# SafeTrip — DB 설계 및 관계 v3.6 (Part 2)

## 4. 테이블 상세 명세 (계속)

### [G] 도메인: 채팅

---

#### 4.22g TB_CHAT_ROOM (채팅방) ⭐ 신규 v3.6

> 출처: chat.entity.ts — 채팅 메시지의 컨테이너 역할. 여행당 그룹/가디언/DM 채팅방 구분.
> v3.6: 신규 정의. TB_CHAT_MESSAGE.room_id FK의 부모 테이블.

```sql
CREATE TABLE tb_chat_room (
    room_id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id              UUID NOT NULL REFERENCES tb_trip(trip_id),
    room_type            VARCHAR(20) DEFAULT 'group',   -- group | guardian | dm
    room_name            VARCHAR(100),
    is_active            BOOLEAN DEFAULT TRUE,
    created_at           TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_chat_room_trip ON tb_chat_room(trip_id);
```

#### 4.23 TB_CHAT_MESSAGE (채팅 메시지)

> 출처: SafeTrip_채팅탭_원칙_v1_0

```sql
CREATE TABLE tb_chat_message (
    message_id         BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    trip_id            UUID NOT NULL REFERENCES tb_trip(trip_id),
    group_id           UUID NOT NULL REFERENCES tb_group(group_id),
    -- ▼ v3.5: FK 추가 (NULL = 시스템 메시지)
    sender_id          VARCHAR(128) REFERENCES tb_user(user_id) ON DELETE SET NULL,
    message_type       VARCHAR(20) NOT NULL,
        -- text | image | video | file | location | poll | system
    content            TEXT,
    media_urls         JSONB,                      -- [{url, type, size, thumbnail}]
    location_data      JSONB,                      -- {lat, lng, address, place_name}
    reply_to_id        BIGINT,                     -- 답글 대상 message_id
    system_event_type  VARCHAR(50),
    system_event_level VARCHAR(20),               -- INFO | SCHEDULE | WARNING | CRITICAL | CELEBRATION
    is_pinned          BOOLEAN DEFAULT FALSE,
    pinned_by          VARCHAR(128),
    deleted_by         VARCHAR(128),
    created_at         TIMESTAMPTZ DEFAULT NOW(),
    updated_at         TIMESTAMPTZ
);

CREATE INDEX idx_chat_message_trip   ON tb_chat_message(trip_id, created_at DESC);
CREATE INDEX idx_chat_message_type   ON tb_chat_message(message_type);
CREATE INDEX idx_chat_message_system ON tb_chat_message(system_event_level)
    WHERE message_type = 'system';
```

#### 4.24 TB_CHAT_POLL (투표)

```sql
CREATE TABLE tb_chat_poll (
    poll_id        BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    message_id     BIGINT NOT NULL REFERENCES tb_chat_message(message_id) ON DELETE CASCADE,
    trip_id        UUID NOT NULL REFERENCES tb_trip(trip_id) ON DELETE CASCADE,
    creator_id     VARCHAR(128) NOT NULL REFERENCES tb_user(user_id) ON DELETE SET NULL,
    title          VARCHAR(200) NOT NULL,
    options        JSONB NOT NULL,                 -- [{id, text, color}]
    allow_multiple BOOLEAN DEFAULT FALSE,
    is_anonymous   BOOLEAN DEFAULT FALSE,
    closes_at      TIMESTAMPTZ,
    is_closed      BOOLEAN DEFAULT FALSE,
    closed_by      VARCHAR(128),
    created_at     TIMESTAMPTZ DEFAULT NOW()
);
```

#### 4.25 TB_CHAT_POLL_VOTE (투표 응답)

```sql
CREATE TABLE tb_chat_poll_vote (
    vote_id          BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    poll_id          BIGINT NOT NULL REFERENCES tb_chat_poll(poll_id) ON DELETE CASCADE,
    user_id          VARCHAR(128) NOT NULL REFERENCES tb_user(user_id) ON DELETE CASCADE,
    selected_options INTEGER[] NOT NULL,
    voted_at         TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(poll_id, user_id)
);
```

#### 4.26 TB_CHAT_READ_STATUS (읽음 상태)

```sql
CREATE TABLE tb_chat_read_status (
    trip_id              UUID NOT NULL REFERENCES tb_trip(trip_id) ON DELETE CASCADE,
    user_id              VARCHAR(128) NOT NULL REFERENCES tb_user(user_id) ON DELETE CASCADE,
    last_read_message_id BIGINT,
    last_read_at         TIMESTAMPTZ,
    PRIMARY KEY (trip_id, user_id)
);
```

---

### [H] 도메인: 알림

---

#### 4.27 TB_NOTIFICATION (알림)

> 출처: SafeTrip_알림버튼_원칙_v1_0

```sql
CREATE TABLE tb_notification (
    notification_id  BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    user_id          VARCHAR(128) NOT NULL REFERENCES tb_user(user_id),
    trip_id          UUID REFERENCES tb_trip(trip_id),
    event_type       VARCHAR(50) NOT NULL,
    priority         VARCHAR(10) NOT NULL,          -- P0 | P1 | P2 | P3 | P4
    channel          VARCHAR(30) NOT NULL,          -- FCM 채널 ID
    title            TEXT NOT NULL,
    body             TEXT NOT NULL,
    icon             VARCHAR(10),
    color            VARCHAR(7),                    -- HEX
    deeplink         TEXT,
    related_user_id  VARCHAR(128),
    related_event_id BIGINT,
    location_data    JSONB,
    is_read          BOOLEAN DEFAULT FALSE,
    read_at          TIMESTAMPTZ,
    is_deleted       BOOLEAN DEFAULT FALSE,
    fcm_sent         BOOLEAN DEFAULT FALSE,
    fcm_sent_at      TIMESTAMPTZ,
    created_at       TIMESTAMPTZ DEFAULT NOW(),
    expires_at       TIMESTAMPTZ
);

CREATE INDEX idx_notification_user_read ON tb_notification(user_id, is_read, is_deleted);
CREATE INDEX idx_notification_trip      ON tb_notification(trip_id, created_at DESC);
CREATE INDEX idx_notification_priority  ON tb_notification(priority, is_read);
CREATE INDEX idx_notification_expires   ON tb_notification(expires_at) WHERE is_deleted = FALSE;
```

#### 4.28 TB_NOTIFICATION_SETTING (알림 설정)

```sql
CREATE TABLE tb_notification_setting (
    user_id    VARCHAR(128) NOT NULL REFERENCES tb_user(user_id),
    event_type VARCHAR(50) NOT NULL,
    is_enabled BOOLEAN DEFAULT TRUE,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (user_id, event_type)
);
```

#### 4.29 TB_EVENT_NOTIFICATION_CONFIG (알림 규칙 — 그룹 단위)

```sql
CREATE TABLE tb_event_notification_config (
    config_id        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id         UUID REFERENCES tb_group(group_id),
    event_type       VARCHAR(50),
    notify_admins    BOOLEAN DEFAULT TRUE,
    notify_guardians BOOLEAN DEFAULT TRUE,
    notify_members   BOOLEAN DEFAULT FALSE,
    notify_self      BOOLEAN DEFAULT TRUE,
    is_enabled       BOOLEAN DEFAULT TRUE,
    title_template   TEXT,
    body_template    TEXT,
    UNIQUE(group_id, event_type)
);
```

#### 4.29a TB_FCM_TOKEN (FCM 토큰 관리) ⭐ 신규 v3.6

> 출처: notification.entity.ts — Firebase Cloud Messaging 토큰 다중 디바이스 관리
> v3.6: 신규 정의. TB_USER.fcm_token(단일 값) 대신 다중 디바이스 지원.

```sql
CREATE TABLE tb_fcm_token (
    token_id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id              VARCHAR(128) NOT NULL REFERENCES tb_user(user_id),
    token                TEXT NOT NULL,
    device_type          VARCHAR(20),                   -- ios | android | web
    is_active            BOOLEAN DEFAULT TRUE,
    last_used_at         TIMESTAMPTZ,
    created_at           TIMESTAMPTZ DEFAULT NOW(),
    updated_at           TIMESTAMPTZ
);

CREATE INDEX idx_fcm_token_user ON tb_fcm_token(user_id);
CREATE INDEX idx_fcm_token_active ON tb_fcm_token(user_id, is_active) WHERE is_active = TRUE;
```

#### 4.29b TB_NOTIFICATION_PREFERENCE (알림 세부 설정) ⭐ 신규 v3.6

> 출처: notification.entity.ts — 알림 유형별 푸시/인앱 개별 설정
> v3.6: 신규 정의. TB_NOTIFICATION_SETTING(이벤트별 on/off)과 병행 사용.

```sql
CREATE TABLE tb_notification_preference (
    preference_id        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id              VARCHAR(128) NOT NULL REFERENCES tb_user(user_id),
    notification_type    VARCHAR(40) NOT NULL,           -- emergency | location | chat | schedule | geofence 등
    is_enabled           BOOLEAN DEFAULT TRUE,
    is_push_enabled      BOOLEAN DEFAULT TRUE,
    is_in_app_enabled    BOOLEAN DEFAULT TRUE,
    created_at           TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_notification_pref_user ON tb_notification_preference(user_id);
```

---

### [I] 도메인: 법적 동의 및 개인정보

---

#### 4.30 TB_USER_CONSENT (사용자 동의)

> 출처: SafeTrip_개인정보처리방침_원칙_v1_0, 비즈니스 원칙 v5.1 §01.5

```sql
CREATE TABLE tb_user_consent (
    consent_id      BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    user_id         VARCHAR(128) NOT NULL REFERENCES tb_user(user_id) ON DELETE SET NULL,
    consent_type    VARCHAR(50) NOT NULL,
        -- terms_of_service | privacy_policy | location_collection |
        -- lbs_terms | international_transfer | ai_data_usage |
        -- marketing | minor_guardian |
        -- location_third_party | guardian_location_share
    consent_version VARCHAR(20) NOT NULL,
    is_agreed       BOOLEAN NOT NULL,
    agreed_at       TIMESTAMPTZ,
    withdrawn_at    TIMESTAMPTZ,
    guardian_user_id VARCHAR(128),                 -- 14세 미만 대리 동의
    ip_address      VARCHAR(45),
    device_info     JSONB,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ
);

CREATE INDEX idx_user_consent_user ON tb_user_consent(user_id);
CREATE INDEX idx_user_consent_type ON tb_user_consent(consent_type, consent_version);
```

#### 4.31 TB_MINOR_CONSENT (미성년자 동의)

> 출처: SafeTrip_미성년자_보호_원칙_v1_0

```sql
CREATE TABLE tb_minor_consent (
    consent_id     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id        VARCHAR(128) NOT NULL REFERENCES tb_user(user_id) ON DELETE SET NULL,
    minor_status   VARCHAR(20) NOT NULL,            -- minor_child | minor_under14 | minor_over14
    consent_type   VARCHAR(30) NOT NULL,            -- legal_guardian | parent_notification | b2b_school
    guardian_phone VARCHAR(20),
    guardian_email VARCHAR(255),
    guardian_user_id VARCHAR(128) REFERENCES tb_user(user_id) ON DELETE SET NULL,
    b2b_school_id  VARCHAR(128),
    b2b_contract_id UUID REFERENCES tb_b2b_contract(contract_id),
    consent_items  JSONB,                           -- [{item, agreed, required}]
    consented_at   TIMESTAMPTZ,
    consent_method VARCHAR(20),                     -- sms_auth | email_auth | b2b_csv | offline_paper
    ip_address     VARCHAR(45),
    expires_at     TIMESTAMPTZ,
    revoked_at     TIMESTAMPTZ,
    revoke_reason  TEXT,
    created_at     TIMESTAMPTZ DEFAULT NOW(),
    updated_at     TIMESTAMPTZ
);

CREATE INDEX idx_minor_consent_user     ON tb_minor_consent(user_id);
CREATE INDEX idx_minor_consent_guardian ON tb_minor_consent(guardian_user_id);
CREATE INDEX idx_minor_consent_school   ON tb_minor_consent(b2b_school_id);
```

#### 4.32 TB_LOCATION_ACCESS_LOG (위치정보 접근 이력)

> 출처: SafeTrip_위치기반서비스_이용약관_원칙_v1_0

```sql
CREATE TABLE tb_location_access_log (
    log_id               BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    user_id              VARCHAR(128) NOT NULL,     -- 위치정보 주체
    accessed_by_user_id  VARCHAR(128),              -- 열람자 (NULL = 시스템)
    access_type          VARCHAR(30) NOT NULL,
        -- realtime_view | history_view | sos_broadcast |
        -- geofence_alert | guardian_snapshot | guardian_request |
        -- attendance_check | ai_analysis | safety_guide
    trip_id              UUID REFERENCES tb_trip(trip_id) ON DELETE SET NULL,
    location_data        JSONB,                     -- 암호화된 좌표 데이터
    access_purpose       VARCHAR(200),
    created_at           TIMESTAMPTZ DEFAULT NOW(),
    expired_at           TIMESTAMPTZ                -- created_at + 6개월
);

CREATE INDEX idx_loc_access_user    ON tb_location_access_log(user_id, created_at DESC);
CREATE INDEX idx_loc_access_type    ON tb_location_access_log(access_type);
CREATE INDEX idx_loc_access_expired ON tb_location_access_log(expired_at);
```

#### 4.33 TB_LOCATION_SHARING_PAUSE_LOG (가디언 위치공유 일시중지 이력)

> 출처: SafeTrip_위치기반서비스_이용약관_원칙_v1_0

```sql
CREATE TABLE tb_location_sharing_pause_log (
    pause_log_id         BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    user_id              VARCHAR(128) NOT NULL,
    guardian_user_id     VARCHAR(128) NOT NULL,
    trip_id              UUID NOT NULL REFERENCES tb_trip(trip_id) ON DELETE CASCADE,
    link_id              UUID REFERENCES tb_guardian_link(link_id),
    privacy_level        VARCHAR(20) NOT NULL,
    pause_duration_hours INTEGER NOT NULL,
    max_allowed_hours    INTEGER NOT NULL,
    paused_at            TIMESTAMPTZ NOT NULL,
    resumed_at           TIMESTAMPTZ,
    resume_reason        VARCHAR(30),
        -- auto_expire | user_manual | sos_override | admin_override
    created_at           TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_pause_log_user ON tb_location_sharing_pause_log(user_id, trip_id);
```

#### 4.34 TB_DATA_DELETION_LOG (데이터 삭제 이력)

> 출처: SafeTrip_개인정보처리방침_원칙_v1_0

```sql
CREATE TABLE tb_data_deletion_log (
    deletion_id    BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    user_id        VARCHAR(128) NOT NULL,            -- FK 아님 (삭제 후에도 기록 보존)
    deletion_type  VARCHAR(30) NOT NULL,
        -- account_soft_delete | account_hard_delete |
        -- location_batch_delete | trip_data_delete | consent_withdrawal
    affected_tables TEXT[],
    record_count   INTEGER,
    requested_by   VARCHAR(20),                      -- user | system | admin
    executed_at    TIMESTAMPTZ DEFAULT NOW(),
    notes          TEXT
);
```

#### 4.35 TB_DATA_PROVISION_LOG (데이터 제공 이력)

> 출처: SafeTrip_긴급_구조기관_연동_원칙_v1_0

```sql
CREATE TABLE tb_data_provision_log (
    provision_id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    -- ▼ v3.5: FK 추가 (영구 보존 목적 — ON DELETE SET NULL)
    sos_event_id         BIGINT REFERENCES tb_sos_event(id) ON DELETE SET NULL,
    requesting_agency    VARCHAR(100),
    request_type         VARCHAR(30),  -- emergency_rescue | warrant | official_request
    legal_basis          TEXT,
    provided_items       JSONB,
    processed_by         VARCHAR(128),               -- 'system' 또는 admin user_id 문자열
    -- ▼ v3.5: FK용 별도 컬럼 (processed_by가 'system' 혼용이므로 분리)
    processed_by_user_id VARCHAR(128) REFERENCES tb_user(user_id) ON DELETE SET NULL,
    requested_at         TIMESTAMPTZ,
    provided_at          TIMESTAMPTZ,
    created_at           TIMESTAMPTZ DEFAULT NOW()
);
```

---

### [J] 도메인: 운영 및 로그

---

#### 4.36 TB_EVENT_LOG (이벤트 기록)

> 출처: 01-init-schema.sql

```sql
CREATE TABLE tb_event_log (
    event_id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id           UUID REFERENCES tb_group(group_id),
    user_id            VARCHAR(128) REFERENCES tb_user(user_id),
    event_type         VARCHAR(50),
        -- SOS | geofence_enter | geofence_exit | attendance |
        -- member_joined | member_left | member_removed |
        -- role_changed | leader_transferred | schedule_modified |
        -- guardian_linked | guardian_unlinked | guardian_paused |
        -- movement_start | movement_end | route_deviation
    movement_session_id UUID,                       -- 이동 세션 집계용 논리키 (FK 없음)
    event_data         JSONB,
    created_at         TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_event_log_group   ON tb_event_log(group_id);
CREATE INDEX idx_event_log_type    ON tb_event_log(event_type);
CREATE INDEX idx_event_log_session ON tb_event_log(movement_session_id) WHERE movement_session_id IS NOT NULL;
```

#### 4.37 TB_LEADER_TRANSFER_LOG (리더 이양 기록)

> 출처: 01-init-schema.sql

```sql
CREATE TABLE tb_leader_transfer_log (
    transfer_id    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id       UUID REFERENCES tb_group(group_id),
    from_user_id   VARCHAR(128) REFERENCES tb_user(user_id),
    to_user_id     VARCHAR(128) REFERENCES tb_user(user_id),
    transferred_at TIMESTAMPTZ DEFAULT NOW(),
    -- ▼ v3.0 추가: 이전 캡틴 강등 시 is_admin 처리 확인 (v2.0 버그 수정)
    from_user_new_role VARCHAR(30) DEFAULT 'crew_chief'  -- 강등 후 역할
);
```

> **v2.0 버그 수정**: `leader-transfer.service.ts`에서 원 캡틴 강등 시 `is_admin=TRUE` 버그 → `is_admin=FALSE`로 올바르게 처리 (이 컬럼으로 추적 가능)

#### 4.38 TB_EMERGENCY_NUMBER (긴급 전화번호 DB)

> 출처: SafeTrip_긴급_구조기관_연동_원칙_v1_0

```sql
CREATE TABLE tb_emergency_number (
    number_id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    country_code       VARCHAR(5) NOT NULL,
    number_type        VARCHAR(20) NOT NULL,         -- general | police | fire | ambulance | coast_guard
    phone_number       VARCHAR(30) NOT NULL,
    phone_number_intl  VARCHAR(30),
    display_name_ko    VARCHAR(100),
    display_name_en    VARCHAR(100),
    display_name_local VARCHAR(100),
    description        TEXT,
    is_primary         BOOLEAN DEFAULT FALSE,
    is_free_call       BOOLEAN DEFAULT TRUE,
    available_24h      BOOLEAN DEFAULT TRUE,
    notes              TEXT,
    source             VARCHAR(20),                  -- manual | mofa_api | external
    verified_at        TIMESTAMPTZ,
    created_at         TIMESTAMPTZ DEFAULT NOW(),
    updated_at         TIMESTAMPTZ,
    UNIQUE(country_code, number_type, phone_number)
);

CREATE INDEX idx_emergency_number_country ON tb_emergency_number(country_code);
CREATE INDEX idx_emergency_number_type    ON tb_emergency_number(number_type);
```

---

### [K] 도메인: 결제/과금 ⭐ 신규

> 출처: 비즈니스 원칙 v5.1 §11 과금 모델 원칙

---

#### 4.39 TB_SUBSCRIPTION (구독/플랜)

> 사용자의 서비스 구독 정보. 가디언 추가 유료화는 트랜잭션 과금 방식이므로, 정기 구독이 아닌 여행 단위 구독도 지원.

```sql
CREATE TABLE tb_subscription (
    subscription_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         VARCHAR(128) NOT NULL REFERENCES tb_user(user_id),
    -- ▼ v3.5: Appendix C 기준으로 plan_type 확장 (기존 free/b2b_* 유지 + addon 추가)
    plan_type       VARCHAR(30) NOT NULL
        CHECK (plan_type IN (
            'free',             -- 무료 (기본)
            'trip_base',        -- 여행 기본 이용 (유료 여행)
            'addon_movement',   -- 움직임 세션 애드온
            'addon_ai_plus',    -- AI Plus 애드온
            'addon_ai_pro',     -- AI Pro 애드온
            'addon_guardian',   -- 추가 가디언 슬롯
            'b2b_school',       -- B2B 학교 계약
            'b2b_corporate'     -- B2B 기업 계약
        )),
    status          VARCHAR(20) DEFAULT 'active',  -- active | cancelled | expired | suspended
    trip_id         UUID REFERENCES tb_trip(trip_id),   -- 여행 단위 구독인 경우
    started_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at      TIMESTAMPTZ,                   -- NULL = 여행 종료 시 자동 만료
    auto_renew      BOOLEAN DEFAULT FALSE,
    cancelled_at    TIMESTAMPTZ,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ
);

CREATE INDEX idx_subscription_user   ON tb_subscription(user_id);
CREATE INDEX idx_subscription_status ON tb_subscription(status);
```

#### 4.40 TB_PAYMENT (결제 내역)

> 비즈니스 원칙 v5.1 §09.3: 가디언 3번째 이상 추가 시 유료 결제 필요

```sql
CREATE TABLE tb_payment (
    payment_id       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id          VARCHAR(128) NOT NULL REFERENCES tb_user(user_id),
    subscription_id  UUID REFERENCES tb_subscription(subscription_id),
    -- ▼ v3.5: Appendix C 기준으로 payment_type 전면 교체
    payment_type     VARCHAR(30) NOT NULL
        CHECK (payment_type IN (
            'trip_base',        -- 여행 기본 이용료 (6인~ 유료, 비즈니스 원칙 §09.1)
            'addon_movement',   -- 움직임 세션 애드온 (2,900원/세션)
            'addon_ai_plus',    -- AI Plus 애드온 (4,900원/월 or 2,900원/여행)
            'addon_ai_pro',     -- AI Pro 애드온 (9,900원/월 or 5,900원/여행)
            'addon_guardian',   -- 추가 가디언 슬롯 (1,900원/여행, 3번째 이상)
            'b2b_contract'      -- B2B 계약 일괄 과금
        )),
    -- ▼ v3.5: trip_id 추가 (Appendix C 기준 — 여행 단위 결제 직접 연결)
    trip_id          UUID REFERENCES tb_trip(trip_id) ON DELETE SET NULL,
    amount           DECIMAL(10, 2) NOT NULL,
    currency         VARCHAR(3) DEFAULT 'KRW',
    status           VARCHAR(20) DEFAULT 'pending',
        -- pending | completed | failed | refunded | cancelled
    pg_provider      VARCHAR(30),                  -- toss | kakao | inicis | stripe
    pg_payment_key   VARCHAR(200),                 -- PG사 고유 결제키
    pg_order_id      VARCHAR(100),
    pg_receipt_url   TEXT,
    paid_at          TIMESTAMPTZ,
    failed_at        TIMESTAMPTZ,
    failure_reason   TEXT,
    metadata         JSONB,                        -- 추가 컨텍스트 (guardian_link_id 등)
    created_at       TIMESTAMPTZ DEFAULT NOW(),
    updated_at       TIMESTAMPTZ
);

CREATE INDEX idx_payment_user   ON tb_payment(user_id);
CREATE INDEX idx_payment_status ON tb_payment(status);
CREATE INDEX idx_payment_pg_key ON tb_payment(pg_payment_key);
```

#### 4.41 TB_BILLING_ITEM (결제 항목 명세)

> 하나의 결제에 여러 항목이 포함될 경우를 위한 명세 테이블

```sql
CREATE TABLE tb_billing_item (
    item_id       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    payment_id    UUID NOT NULL REFERENCES tb_payment(payment_id),
    -- ▼ v3.5: Appendix C 기준으로 item_type 확장
    item_type     VARCHAR(30) NOT NULL
        CHECK (item_type IN (
            'trip_base',        -- 여행 기본 이용료
            'addon_movement',   -- 움직임 애드온 (세션 단위)
            'addon_ai_plus',    -- AI Plus 애드온
            'addon_ai_pro',     -- AI Pro 애드온
            'addon_guardian',   -- 추가 가디언 슬롯
            'b2b_seat',         -- B2B 좌석
            'movement_session'  -- 개별 이동 세션 과금
        )),
    item_name     VARCHAR(100) NOT NULL,
    quantity      INTEGER DEFAULT 1,
    unit_price    DECIMAL(10, 2) NOT NULL,
    total_price   DECIMAL(10, 2) NOT NULL,
    reference_id  VARCHAR(128),                    -- guardian_link_id, trip_id 등
    created_at    TIMESTAMPTZ DEFAULT NOW()
);
```

#### 4.42 TB_REFUND_LOG (환불 기록)

> 비즈니스 원칙 v5.1 §09.7: 환불 규칙 및 이력 관리

```sql
CREATE TABLE tb_refund_log (
    refund_id       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    payment_id      UUID NOT NULL REFERENCES tb_payment(payment_id),
    -- ▼ v3.5: FK 추가 + NOT NULL 제거 (사용자 삭제 후에도 환불 기록 보존용)
    user_id         VARCHAR(128) REFERENCES tb_user(user_id) ON DELETE SET NULL,
    refund_amount   DECIMAL(10, 2) NOT NULL,
    refund_reason   VARCHAR(100),
        -- user_request | service_error | admin_override | duplicate_payment
    -- ▼ v3.5.1: 적용된 환불 정책 추적 (비즈니스 원칙 v5.1 §09.7)
    refund_policy   VARCHAR(30),
        -- planning_full       : planning 상태에서 전액 환불 (100%)
        -- active_24h_half     : active 상태 + 여행 시작 24시간 이내 50% 환불
        -- active_no_refund    : active 상태 + 여행 시작 24시간 이후 환불 불가 (0%)
        -- completed_no_refund : completed 상태 환불 불가 (0%)
        -- admin_override      : 관리자 수동 환불
    refund_status   VARCHAR(20) DEFAULT 'pending',
        -- pending | completed | rejected
    pg_refund_key   VARCHAR(200),
    requested_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at    TIMESTAMPTZ,
    rejected_at     TIMESTAMPTZ,
    rejection_reason TEXT,
    processed_by    VARCHAR(128),                  -- admin user_id 또는 'system'
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_refund_payment ON tb_refund_log(payment_id);
CREATE INDEX idx_refund_user    ON tb_refund_log(user_id);
```

#### 4.42a TB_REDEEM_CODE (리딤 코드) ⭐ 신규 v3.6

> 출처: payment.entity.ts — 프로모션, 할인, 보너스 일수 등 리딤 코드 관리
> v3.6: 신규 정의. 결제 시 적용되는 코드 테이블.

```sql
CREATE TABLE tb_redeem_code (
    code_id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code                 VARCHAR(50) NOT NULL UNIQUE,
    code_type            VARCHAR(30) NOT NULL,           -- PLAN-PERSONAL-7D | PLAN-GROUP-30D 등
    plan_type            VARCHAR(20),
    discount_rate        DECIMAL(5, 2),                  -- 할인율 (%) (예: 10.00 = 10%)
    bonus_days           INTEGER,                        -- 보너스 일수
    max_uses             INTEGER DEFAULT 1,
    current_uses         INTEGER DEFAULT 0,
    valid_from           TIMESTAMPTZ DEFAULT NOW(),
    valid_until          TIMESTAMPTZ,
    issued_by            VARCHAR(100),                   -- admin 또는 system
    issued_reason        TEXT,                           -- promotional | customer_retention 등
    is_active            BOOLEAN DEFAULT TRUE,
    created_at           TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_redeem_code_code  ON tb_redeem_code(code);
CREATE INDEX idx_redeem_code_valid ON tb_redeem_code(valid_from, valid_until);
```

---

### [L] 도메인: B2B ⭐ 신규

> 출처: 비즈니스 원칙 v5.1 §12 B2B 프레임워크

---

#### 4.42b TB_B2B_ORGANIZATION (B2B 조직) ⭐ 신규 v3.6

> 출처: b2b.entity.ts — B2B 고객사 조직 정보 (학교, 기업, 여행사, 정부기관)
> v3.6: 신규 정의. TB_B2B_CONTRACT의 상위 개체.

```sql
CREATE TABLE tb_b2b_organization (
    org_id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_name             VARCHAR(200) NOT NULL,
    org_type             VARCHAR(30) NOT NULL,           -- school | corporate | agency | government
    business_number      VARCHAR(20),                    -- 사업자등록번호
    contact_name         VARCHAR(50),
    contact_email        VARCHAR(200),
    contact_phone        VARCHAR(20),
    is_active            BOOLEAN DEFAULT TRUE,
    created_at           TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_b2b_org_type ON tb_b2b_organization(org_type);
```

#### 4.42c TB_B2B_ADMIN (B2B 관리자) ⭐ 신규 v3.6

> 출처: b2b.entity.ts — B2B 조직별 관리자 역할 할당
> v3.6: 신규 정의.

```sql
CREATE TABLE tb_b2b_admin (
    admin_id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id               UUID NOT NULL REFERENCES tb_b2b_organization(org_id),
    user_id              VARCHAR(128) NOT NULL REFERENCES tb_user(user_id),
    admin_role           VARCHAR(20) DEFAULT 'org_admin', -- org_admin | trip_manager | viewer
    is_active            BOOLEAN DEFAULT TRUE,
    created_at           TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_b2b_admin_org  ON tb_b2b_admin(org_id);
CREATE INDEX idx_b2b_admin_user ON tb_b2b_admin(user_id);
```

#### 4.42d TB_B2B_DASHBOARD_CONFIG (B2B 대시보드 설정) ⭐ 신규 v3.6

> 출처: b2b.entity.ts — B2B 대시보드 커스터마이징 설정
> v3.6: 신규 정의.

```sql
CREATE TABLE tb_b2b_dashboard_config (
    config_id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id               UUID NOT NULL REFERENCES tb_b2b_organization(org_id),
    contract_id          UUID REFERENCES tb_b2b_contract(contract_id),
    config_key           VARCHAR(100) NOT NULL,           -- dashboard_theme | report_frequency 등
    config_value         JSONB NOT NULL,
    created_at           TIMESTAMPTZ DEFAULT NOW(),
    updated_at           TIMESTAMPTZ
);

CREATE INDEX idx_b2b_dashboard_org ON tb_b2b_dashboard_config(org_id);
```

#### 4.43 TB_B2B_CONTRACT (B2B 계약)

> B2B 고객사(학교, 기업, 여행사)와의 계약 정보

```sql
CREATE TABLE tb_b2b_contract (
    contract_id      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    contract_code    VARCHAR(20) UNIQUE NOT NULL,  -- 계약 식별 코드
    contract_type    VARCHAR(20) NOT NULL,
        -- school | corporate | travel_agency | insurance
    company_name     VARCHAR(200) NOT NULL,
    contact_name     VARCHAR(100),
    contact_email    VARCHAR(255),
    contact_phone    VARCHAR(20),
    -- ▼ 계약 조건
    max_groups       INTEGER DEFAULT 1,            -- 동시 생성 가능한 그룹 수 (Appendix C: max_trips에 해당)
    max_members_per_group INTEGER DEFAULT 50,      -- 그룹당 최대 멤버 수 (Appendix C: max_members_per_trip)
    -- ▼ v3.5: Appendix C 호환 컬럼 추가 (max_groups 별칭 — 여행 수 제한 관점)
    max_trips        INTEGER DEFAULT NULL,         -- NULL이면 max_groups로 대체 (Appendix C 정합용)
    guardian_model   VARCHAR(20) DEFAULT 'A',      -- A (개별 동의) | B (일괄 등록)
    sla_level        VARCHAR(20) DEFAULT 'standard', -- standard | premium | enterprise
    -- ▼ 계약 기간
    started_at       DATE NOT NULL,
    expires_at       DATE,
    -- ▼ 상태
    status           VARCHAR(20) DEFAULT 'active',  -- active | suspended | expired
    -- ▼ 참조 (학교 계약 시)
    school_id        UUID REFERENCES tb_b2b_school(school_id) ON DELETE SET NULL,
    -- ▼ 시스템
    created_at       TIMESTAMPTZ DEFAULT NOW(),
    updated_at       TIMESTAMPTZ
);

CREATE INDEX idx_b2b_contract_type   ON tb_b2b_contract(contract_type);
CREATE INDEX idx_b2b_contract_status ON tb_b2b_contract(status);
```

#### 4.44 TB_B2B_SCHOOL (학교 정보)

> B2B 학교 고객 전용. 수학여행, 어학연수 시나리오에서 학교 정보를 별도 관리.

```sql
CREATE TABLE tb_b2b_school (
    school_id       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_name     VARCHAR(200) NOT NULL,
    school_code     VARCHAR(50),                   -- 학교 코드 (교육부 기준)
    region          VARCHAR(100),                  -- 시/도
    district        VARCHAR(100),                  -- 시/군/구
    school_type     VARCHAR(20),                   -- elementary | middle | high | university
    contact_teacher VARCHAR(100),
    contact_phone   VARCHAR(20),
    contact_email   VARCHAR(255),
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ
);
```

#### 4.45 TB_B2B_INVITE_BATCH (B2B 일괄 초대)

> 비즈니스 원칙 v5.1 §12.3: CSV 일괄 초대코드 생성 관리

```sql
CREATE TABLE tb_b2b_invite_batch (
    batch_id      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    contract_id   UUID NOT NULL REFERENCES tb_b2b_contract(contract_id),
    group_id      UUID REFERENCES tb_group(group_id),
    batch_name    VARCHAR(200),                    -- "2026 수학여행 3학년 2반"
    target_role   VARCHAR(30) NOT NULL,            -- crew | guardian
    total_count   INTEGER NOT NULL,
    used_count    INTEGER DEFAULT 0,
    csv_file_url  TEXT,                            -- 업로드된 CSV 파일
    status        VARCHAR(20) DEFAULT 'active',    -- active | expired | cancelled
    created_by    VARCHAR(128) REFERENCES tb_user(user_id),
    expires_at    TIMESTAMPTZ,
    created_at    TIMESTAMPTZ DEFAULT NOW(),
    updated_at    TIMESTAMPTZ
);

CREATE INDEX idx_b2b_invite_batch_contract ON tb_b2b_invite_batch(contract_id);
```

#### 4.46 TB_B2B_MEMBER_LOG (B2B 멤버 참여 기록)

> B2B 계약으로 합류한 멤버의 이력 추적

```sql
CREATE TABLE tb_b2b_member_log (
    log_id        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    batch_id      UUID NOT NULL REFERENCES tb_b2b_invite_batch(batch_id),
    user_id       VARCHAR(128) REFERENCES tb_user(user_id),
    invite_code   VARCHAR(7),
    joined_at     TIMESTAMPTZ,
    member_role   VARCHAR(30),
    -- ▼ 미성년자 동의 연동 (§13)
    minor_consent_id UUID REFERENCES tb_minor_consent(consent_id),
    notes         TEXT,
    created_at    TIMESTAMPTZ DEFAULT NOW()
);
```

---

### [M] 도메인: Firebase RTDB 스키마 ⭐ 신규

> Firebase Realtime Database는 PostgreSQL과 별도로 운영된다.
> 실시간성이 요구되는 데이터(메시지, 위치 스트리밍, Presence)에 사용한다.

---

#### 4.47 RTDB: guardian_messages (가디언 메시지)

> 경로 구조: `guardian_messages/{tripId}/{channelKey}/messages/{msgId}`

```json
{
  "guardian_messages": {
    "{tripId}": {
      "{channelKey}": {
        "messages": {
          "{msgId}": {
            "senderId": "firebase_uid",
            "senderRole": "member | guardian | captain",
            "text": "메시지 내용",
            "timestamp": 1709120000000,
            "readBy": {
              "{userId}": true
            }
          }
        },
        "metadata": {
          "linkId": "uuid",              // TB_GUARDIAN_LINK.link_id (link_ 채널)
          "memberId": "firebase_uid",
          "guardianId": "firebase_uid",
          "createdAt": 1709120000000
        }
      }
    }
  }
}
```

**채널키(channelKey) 규칙**:

| 채널 유형 | 키 형식 | 설명 |
|----------|---------|------|
| 멤버 ↔ 가디언 1:1 | `link_{linkId}` | TB_GUARDIAN_LINK.link_id 기반 |
| 가디언 → 캡틴 | `captain_{guardianId}` | 가디언이 캡틴에게 직접 연락 |
| 여행 전체 가디언 공지 | `group_guardian` | 캡틴→전체 가디언 공지 |

**RTDB Security Rules 핵심**:
- `link_{linkId}` 채널: 해당 link의 member_id와 guardian_id만 읽기/쓰기 가능
- `captain_{guardianId}` 채널: 캡틴과 해당 guardian_id만 접근 가능

---

#### 4.48 RTDB: location_realtime (실시간 위치)

> 경로 구조: `location_realtime/{tripId}/{userId}`

```json
{
  "location_realtime": {
    "{tripId}": {
      "{userId}": {
        "lat": 37.5665,
        "lng": 126.9780,
        "accuracy": 10.5,
        "speed": 0.0,
        "bearing": 180.0,
        "battery": 72,
        "isSharing": true,
        "updatedAt": 1709120000000
      }
    }
  }
}
```

> **역할**: 실시간 위치 스트리밍만 담당. 영속적인 이동 경로는 PostgreSQL **TB_LOCATION**에 배치 저장 (구 `TB_LOCATION_LOG`→`TB_LOCATION`으로 구현).
> RTDB `realtime_users/{userId}/active_session_id` 노드에서 현재 진행 중인 이동 세션 ID 추적.

---

#### 4.49 RTDB: presence (온라인 상태)

> 경로 구조: `presence/{userId}`

```json
{
  "presence": {
    "{userId}": {
      "state": "online | offline | away",
      "lastSeen": 1709120000000,
      "currentTripId": "uuid | null",
      "appState": "foreground | background"
    }
  }
}
```

---

#### 4.50 RTDB: offline_queue (오프라인 큐)

> 경로 구조: `offline_queue/{userId}/{queueId}`

```json
{
  "offline_queue": {
    "{userId}": {
      "{queueId}": {
        "type": "location | chat | sos",
        "payload": {},
        "createdAt": 1709120000000,
        "synced": false
      }
    }
  }
}
```

---

#### 4.51 RTDB: realtime_users (이동 세션 활성 상태)

> 경로 구조: `realtime_users/{userId}`
> **v3.0 추가**: 이동 세션 서비스(`location.service.ts`)가 현재 진행 중인 세션 ID를 조회할 때 사용.
> 세션 목록 API에서 `activeSessionId`와 비교해 `is_ongoing` 플래그를 설정함.

```json
{
  "realtime_users": {
    "{userId}": {
      "active_session_id": "uuid-of-ongoing-movement-session | null"
    }
  }
}
```

> **역할**: 진행 중인 이동 세션을 실시간으로 추적. Flutter 앱이 이동 시작(`is_movement_start=TRUE`) 시 이 노드에 세션 ID를 기록하고, 이동 종료 시 `null`로 초기화.

---

**RTDB 노드 전체 목록 (v3.0 기준 5개)**:

| 노드 | 경로 | 용도 |
|------|------|------|
| M1 | `guardian_messages/{tripId}/{channelKey}/messages` | 가디언-멤버 1:1 메시지 |
| M2 | `location_realtime/{tripId}/{userId}` | 실시간 위치 스트리밍 |
| M3 | `presence/{userId}` | 유저 온라인 상태 |
| M4 | `offline_queue/{userId}/{queueId}` | 오프라인 큐 |
| M5 | `realtime_users/{userId}/active_session_id` | 이동 세션 활성 상태 추적 |

---

### [N] 도메인: AI ⭐ 신규 v3.6

---

#### 4.52 TB_AI_USAGE (AI 사용 추적) ⭐ 신규 v3.6

> 출처: ai.entity.ts — AI 기능별 일일 사용량 추적 및 할당량 관리
> v3.6: 신규 정의. 비즈니스 원칙 v5.1 AI 기능 요금제(addon_ai_plus/pro) 기반 사용량 제한.

```sql
CREATE TABLE tb_ai_usage (
    usage_id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id              VARCHAR(128) NOT NULL REFERENCES tb_user(user_id),
    trip_id              UUID REFERENCES tb_trip(trip_id),
    usage_date           DATE NOT NULL,                  -- 일일 할당량 기준 날짜
    feature_type         VARCHAR(30) NOT NULL,           -- recommendation | optimization | chat | briefing | intelligence
    use_count            INTEGER DEFAULT 0,
    created_at           TIMESTAMPTZ DEFAULT NOW(),
    updated_at           TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_ai_usage_user_date ON tb_ai_usage(user_id, usage_date);
CREATE INDEX idx_ai_usage_trip      ON tb_ai_usage(trip_id) WHERE trip_id IS NOT NULL;
```

> **할당량 체크 로직**: `SELECT use_count FROM tb_ai_usage WHERE user_id=$1 AND usage_date=CURRENT_DATE AND feature_type=$2`
> - free 플랜: feature별 일 3회
> - addon_ai_plus: feature별 일 20회
> - addon_ai_pro: feature별 일 100회

---

## 5. 주요 인덱스 전체 목록

### 5.1 핵심 인덱스 (v1.0 기존)

```sql
-- 그룹 멤버
CREATE INDEX idx_group_members_group ON tb_group_member(group_id);
CREATE INDEX idx_group_members_user  ON tb_group_member(user_id);
CREATE INDEX idx_group_members_role  ON tb_group_member(member_role);
CREATE INDEX idx_group_members_trip  ON tb_group_member(trip_id);  -- v3.0 추가

-- 여행
CREATE INDEX idx_trips_group  ON tb_trip(group_id);
CREATE INDEX idx_trips_status ON tb_trip(status);
CREATE INDEX idx_trips_dates  ON tb_trip(start_date, end_date);

-- 보호자
CREATE INDEX idx_guardian_traveler  ON tb_guardian(traveler_user_id);
CREATE INDEX idx_guardian_link_trip ON tb_guardian_link(trip_id);
CREATE INDEX idx_guardian_link_member   ON tb_guardian_link(member_id);
CREATE INDEX idx_guardian_link_guardian ON tb_guardian_link(guardian_id);

-- 지오펜스
CREATE INDEX idx_geofence_group ON tb_geofence(group_id);
CREATE INDEX idx_geofence_trip  ON tb_geofence(trip_id);

-- 이벤트
CREATE INDEX idx_event_log_group   ON tb_event_log(group_id);
CREATE INDEX idx_event_log_type    ON tb_event_log(event_type);
CREATE INDEX idx_event_log_session ON tb_event_log(movement_session_id) WHERE movement_session_id IS NOT NULL;

-- 초대코드
CREATE INDEX idx_invite_code_group ON tb_invite_code(group_id);
CREATE INDEX idx_invite_code_code  ON tb_invite_code(code) WHERE is_active = TRUE;

-- 위치 공유
CREATE INDEX idx_location_sharing_user   ON tb_location_sharing(user_id);
CREATE INDEX idx_location_sharing_target ON tb_location_sharing(target_user_id);

-- 일정
CREATE INDEX idx_travel_schedule_group      ON tb_travel_schedule(group_id);
CREATE INDEX idx_travel_schedule_trip       ON tb_travel_schedule(trip_id);
CREATE INDEX idx_travel_schedule_start_time ON tb_travel_schedule(start_time);
```

### 5.2 신규 인덱스 (v2.0~v3.0)

```sql
-- 이동기록 (TB_LOCATION — 실제 구현, 구 TB_LOCATION_LOG)
CREATE INDEX idx_locations_geom                  ON tb_location USING GIST(geom);
CREATE INDEX idx_locations_user_id               ON tb_location(user_id);
CREATE INDEX idx_locations_recorded_at           ON tb_location(recorded_at DESC);
CREATE INDEX idx_locations_coords                ON tb_location(latitude, longitude);
CREATE INDEX idx_locations_movement_session      ON tb_location(movement_session_id) WHERE movement_session_id IS NOT NULL;
CREATE INDEX idx_locations_movement_session_user ON tb_location(user_id, movement_session_id, recorded_at) WHERE movement_session_id IS NOT NULL;
CREATE INDEX idx_locations_movement_start        ON tb_location(user_id, is_movement_start) WHERE is_movement_start = TRUE;
CREATE INDEX idx_locations_movement_end          ON tb_location(user_id, is_movement_end)   WHERE is_movement_end   = TRUE;
CREATE INDEX idx_locations_user_idx              ON tb_location(user_id, i_idx);

-- 세션 지도 이미지 캐시 (TB_SESSION_MAP_IMAGE)
CREATE INDEX idx_session_map_image_user_id    ON tb_session_map_image(user_id);
CREATE INDEX idx_session_map_image_created_at ON tb_session_map_image(created_at DESC);
CREATE INDEX idx_session_map_image_url        ON tb_session_map_image(map_image_url) WHERE map_image_url IS NOT NULL;

-- 계획 경로 (TB_PLANNED_ROUTE)
CREATE INDEX idx_planned_routes_trip       ON tb_planned_route(trip_id);
CREATE INDEX idx_planned_routes_user       ON tb_planned_route(user_id);
CREATE INDEX idx_planned_routes_active     ON tb_planned_route(is_active) WHERE is_active = TRUE;
CREATE INDEX idx_planned_routes_schedule   ON tb_planned_route(scheduled_start, scheduled_end);
CREATE INDEX idx_planned_routes_start_geom ON tb_planned_route USING GIST(start_coords);
CREATE INDEX idx_planned_routes_end_geom   ON tb_planned_route USING GIST(end_coords);

-- 경로 이탈 (TB_ROUTE_DEVIATION)
CREATE INDEX idx_route_deviations_route   ON tb_route_deviation(route_id);
CREATE INDEX idx_route_deviations_trip    ON tb_route_deviation(trip_id);
CREATE INDEX idx_route_deviations_user    ON tb_route_deviation(user_id);
CREATE INDEX idx_route_deviations_status  ON tb_route_deviation(deviation_status);
CREATE INDEX idx_route_deviations_started ON tb_route_deviation(started_at DESC);
CREATE INDEX idx_route_deviations_geom    ON tb_route_deviation USING GIST(deviation_location);

-- [참고] 원칙 문서에 정의된 인덱스 (TB_LOCATION_LOG — 실제 구현에서 TB_LOCATION으로 대체)
-- CREATE INDEX idx_location_log_user_time  ON tb_location_log(user_id, recorded_at DESC);  -- 대체: idx_locations_movement_session_user
-- CREATE INDEX idx_location_log_group_time ON tb_location_log(group_id, recorded_at DESC); -- 대체: idx_locations_user_id

-- Heartbeat
CREATE INDEX idx_heartbeat_user ON tb_heartbeat(user_id, timestamp DESC);
CREATE INDEX idx_heartbeat_trip ON tb_heartbeat(trip_id, timestamp DESC);

-- 채팅
CREATE INDEX idx_chat_message_trip   ON tb_chat_message(trip_id, created_at DESC);
CREATE INDEX idx_chat_message_type   ON tb_chat_message(message_type);
CREATE INDEX idx_chat_message_system ON tb_chat_message(system_event_level)
    WHERE message_type = 'system';

-- 알림
CREATE INDEX idx_notification_user_read ON tb_notification(user_id, is_read, is_deleted);
CREATE INDEX idx_notification_trip      ON tb_notification(trip_id, created_at DESC);
CREATE INDEX idx_notification_priority  ON tb_notification(priority, is_read);
CREATE INDEX idx_notification_expires   ON tb_notification(expires_at) WHERE is_deleted = FALSE;

-- 긴급 전화번호
CREATE INDEX idx_emergency_number_country ON tb_emergency_number(country_code);
CREATE INDEX idx_emergency_number_type    ON tb_emergency_number(number_type);

-- 동의 관리
CREATE INDEX idx_user_consent_user ON tb_user_consent(user_id);
CREATE INDEX idx_user_consent_type ON tb_user_consent(consent_type, consent_version);

-- 미성년자 동의
CREATE INDEX idx_minor_consent_user     ON tb_minor_consent(user_id);
CREATE INDEX idx_minor_consent_guardian ON tb_minor_consent(guardian_user_id);
CREATE INDEX idx_minor_consent_school   ON tb_minor_consent(b2b_school_id);

-- 위치 접근 로그
CREATE INDEX idx_loc_access_user    ON tb_location_access_log(user_id, created_at DESC);
CREATE INDEX idx_loc_access_type    ON tb_location_access_log(access_type);
CREATE INDEX idx_loc_access_expired ON tb_location_access_log(expired_at);

-- 가디언 일시중지 이력
CREATE INDEX idx_pause_log_user ON tb_location_sharing_pause_log(user_id, trip_id);

-- 결제 (v3.0 신규)
CREATE INDEX idx_payment_user    ON tb_payment(user_id);
CREATE INDEX idx_payment_status  ON tb_payment(status);
CREATE INDEX idx_payment_pg_key  ON tb_payment(pg_payment_key);
CREATE INDEX idx_refund_payment  ON tb_refund_log(payment_id);
CREATE INDEX idx_subscription_user ON tb_subscription(user_id);

-- B2B (v3.0 신규)
CREATE INDEX idx_b2b_contract_type   ON tb_b2b_contract(contract_type);
CREATE INDEX idx_b2b_contract_status ON tb_b2b_contract(status);
CREATE INDEX idx_b2b_invite_batch_contract ON tb_b2b_invite_batch(contract_id);

-- 국가
CREATE INDEX idx_country_code   ON tb_country(country_code);
CREATE INDEX idx_country_region ON tb_country(region);

-- 가디언 긴급 위치 요청 (v3.2 신규)
CREATE INDEX idx_guardian_location_request_target  ON tb_guardian_location_request(target_user_id, status);
CREATE INDEX idx_guardian_location_request_guardian ON tb_guardian_location_request(guardian_user_id, requested_at DESC);

-- 가디언 스냅샷 (v3.2 신규)
CREATE INDEX idx_guardian_snapshot_user  ON tb_guardian_snapshot(user_id, captured_at DESC);
CREATE INDEX idx_guardian_snapshot_group ON tb_guardian_snapshot(group_id, captured_at DESC);

-- B2B 연동 (TB_TRIP.b2b_contract_id)
CREATE INDEX idx_trips_b2b ON tb_trip(b2b_contract_id) WHERE b2b_contract_id IS NOT NULL;

-- ▼ v3.5 신규 인덱스
-- 위치 공유 (trip_id 추가)
CREATE INDEX idx_location_sharing_trip ON tb_location_sharing(trip_id);

-- 위치 공유 시간대 스케줄 (TB_LOCATION_SCHEDULE)
CREATE INDEX idx_location_schedule_trip ON tb_location_schedule(trip_id);
CREATE INDEX idx_location_schedule_user ON tb_location_schedule(trip_id, user_id);

-- 출석 체크 (TB_ATTENDANCE_CHECK / TB_ATTENDANCE_RESPONSE)
CREATE INDEX idx_attendance_check_trip     ON tb_attendance_check(trip_id, created_at DESC);
CREATE INDEX idx_attendance_check_group    ON tb_attendance_check(group_id, status);
CREATE INDEX idx_attendance_response_check ON tb_attendance_response(check_id);
CREATE INDEX idx_attendance_response_user  ON tb_attendance_response(user_id, created_at DESC);

-- 가디언 긴급 위치 요청 — 시간당 rate limiting 지원
CREATE INDEX idx_guardian_location_request_hourly
    ON tb_guardian_location_request(guardian_user_id, requested_at DESC);

-- 결제 (TB_PAYMENT trip_id)
CREATE INDEX idx_payment_trip ON tb_payment(trip_id) WHERE trip_id IS NOT NULL;

-- captain 유일성 부분 인덱스
CREATE UNIQUE INDEX idx_group_member_captain
    ON tb_group_member(group_id)
    WHERE member_role = 'captain' AND status = 'active';

-- guardian_link 부분 인덱스 (UNIQUE 재설계)
CREATE UNIQUE INDEX idx_guardian_link_active
    ON tb_guardian_link(trip_id, member_id, guardian_id)
    WHERE guardian_id IS NOT NULL;
CREATE UNIQUE INDEX idx_guardian_link_pending
    ON tb_guardian_link(trip_id, member_id, guardian_phone)
    WHERE guardian_id IS NULL AND guardian_phone IS NOT NULL;

-- geofence 활성 상태
CREATE INDEX idx_geofence_active ON tb_geofence(group_id, is_active) WHERE is_active = TRUE;

-- ▼ v3.6 신규 인덱스

-- 지오펜스 이벤트 (TB_GEOFENCE_EVENT)
CREATE INDEX idx_geofence_event_trip      ON tb_geofence_event(trip_id);
CREATE INDEX idx_geofence_event_geofence  ON tb_geofence_event(geofence_id);
CREATE INDEX idx_geofence_event_user      ON tb_geofence_event(user_id, occurred_at DESC);

-- 지오펜스 패널티 (TB_GEOFENCE_PENALTY)
CREATE INDEX idx_geofence_penalty_event ON tb_geofence_penalty(event_id);
CREATE INDEX idx_geofence_penalty_user  ON tb_geofence_penalty(user_id, trip_id);

-- 이동 세션 (TB_MOVEMENT_SESSION)
CREATE INDEX idx_movement_session_user   ON tb_movement_session(user_id);
CREATE INDEX idx_movement_session_active ON tb_movement_session(is_completed) WHERE is_completed = FALSE;

-- 긴급 상황 (TB_EMERGENCY)
CREATE INDEX idx_emergency_trip   ON tb_emergency(trip_id);
CREATE INDEX idx_emergency_user   ON tb_emergency(user_id);
CREATE INDEX idx_emergency_status ON tb_emergency(status);

-- 긴급 알림 수신자 (TB_EMERGENCY_RECIPIENT)
CREATE INDEX idx_emergency_recipient_emergency ON tb_emergency_recipient(emergency_id);
CREATE INDEX idx_emergency_recipient_user      ON tb_emergency_recipient(user_id);

-- 무응답 이벤트 (TB_NO_RESPONSE_EVENT)
CREATE INDEX idx_no_response_user   ON tb_no_response_event(user_id, trip_id);
CREATE INDEX idx_no_response_status ON tb_no_response_event(status);

-- 안전 체크인 (TB_SAFETY_CHECKIN)
CREATE INDEX idx_safety_checkin_user    ON tb_safety_checkin(user_id);
CREATE INDEX idx_safety_checkin_trip    ON tb_safety_checkin(trip_id);
CREATE INDEX idx_safety_checkin_created ON tb_safety_checkin(created_at DESC);

-- 채팅방 (TB_CHAT_ROOM)
CREATE INDEX idx_chat_room_trip ON tb_chat_room(trip_id);

-- FCM 토큰 (TB_FCM_TOKEN)
CREATE INDEX idx_fcm_token_user   ON tb_fcm_token(user_id);
CREATE INDEX idx_fcm_token_active ON tb_fcm_token(user_id, is_active) WHERE is_active = TRUE;

-- 알림 세부 설정 (TB_NOTIFICATION_PREFERENCE)
CREATE INDEX idx_notification_pref_user ON tb_notification_preference(user_id);

-- 리딤 코드 (TB_REDEEM_CODE)
CREATE INDEX idx_redeem_code_code  ON tb_redeem_code(code);
CREATE INDEX idx_redeem_code_valid ON tb_redeem_code(valid_from, valid_until);

-- B2B 조직 (TB_B2B_ORGANIZATION)
CREATE INDEX idx_b2b_org_type ON tb_b2b_organization(org_type);

-- B2B 관리자 (TB_B2B_ADMIN)
CREATE INDEX idx_b2b_admin_org  ON tb_b2b_admin(org_id);
CREATE INDEX idx_b2b_admin_user ON tb_b2b_admin(user_id);

-- B2B 대시보드 설정 (TB_B2B_DASHBOARD_CONFIG)
CREATE INDEX idx_b2b_dashboard_org ON tb_b2b_dashboard_config(org_id);

-- AI 사용 추적 (TB_AI_USAGE)
CREATE INDEX idx_ai_usage_user_date ON tb_ai_usage(user_id, usage_date);
CREATE INDEX idx_ai_usage_trip      ON tb_ai_usage(trip_id) WHERE trip_id IS NOT NULL;
```

---

