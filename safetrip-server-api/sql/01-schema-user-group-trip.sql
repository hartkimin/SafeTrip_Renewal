-- ============================================================
-- SafeTrip DB Schema v3.4.1
-- 01: [A] 사용자 및 인증 + [B] 그룹 및 여행
-- 기준 문서: 07_T2_DB_설계_및_관계_v3_4.md §4.1~4.8
-- ============================================================

-- ──────────────────────────────────────────────
-- [A] 도메인: 사용자 및 인증
-- ──────────────────────────────────────────────

-- 4.1 TB_USER (사용자)
CREATE TABLE tb_user (
    user_id                  VARCHAR(128) PRIMARY KEY,    -- Firebase UID
    phone_number             VARCHAR(20),
    phone_country_code       VARCHAR(5),
    display_name             VARCHAR(100),
    profile_image_url        TEXT,
    email                    VARCHAR(255),
    date_of_birth            DATE,
    location_sharing_mode    VARCHAR(20),                  -- always | in_trip | off
    fcm_token                TEXT,
    install_id               VARCHAR(100),
    device_info              JSONB,
    user_status              VARCHAR(20) DEFAULT 'active', -- active | inactive | banned
    -- ▼ 미성년자 보호 원칙 §13 반영
    minor_status             VARCHAR(20) DEFAULT 'adult',  -- adult | minor_over14 | minor_under14 | minor_child
    minor_status_updated_at  TIMESTAMPTZ,
    guardian_consent_id      UUID,                         -- TB_MINOR_CONSENT FK (99-deferred-fk.sql)
    guardian_pause_blocked    BOOLEAN DEFAULT FALSE,        -- 미성년자: 가디언 일시중지 차단
    ai_intelligence_blocked  BOOLEAN DEFAULT FALSE,        -- 미성년자: AI 개인 분석 차단
    -- ▼ 시스템 컬럼
    last_verification_at     TIMESTAMPTZ,
    last_login_at            TIMESTAMPTZ,
    last_active_at           TIMESTAMPTZ,
    created_at               TIMESTAMPTZ DEFAULT NOW(),
    updated_at               TIMESTAMPTZ,
    -- ▼ v3.4: 계정 삭제 유예 기간 추적 (비즈니스 원칙 v5.1 §14 — 7일 유예 후 hard delete)
    deletion_requested_at    TIMESTAMPTZ,                  -- 삭제 요청 시각 (7일 유예 기산점)
    deleted_at               TIMESTAMPTZ                   -- soft delete
);

-- 4.2 TB_EMERGENCY_CONTACT (비상 연락처)
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

-- ──────────────────────────────────────────────
-- [B] 도메인: 그룹 및 여행
-- ──────────────────────────────────────────────

-- 4.3 TB_GROUP (그룹)
CREATE TABLE tb_group (
    group_id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_name            VARCHAR(200) NOT NULL,
    group_description     TEXT,
    group_type            VARCHAR(20) DEFAULT 'travel',  -- travel | b2b_school | b2b_corporate
    owner_user_id         VARCHAR(128) REFERENCES tb_user(user_id),
    invite_code           VARCHAR(8) UNIQUE,
    invite_link           TEXT,
    current_member_count  INTEGER DEFAULT 0,
    max_members           INTEGER DEFAULT 50,
    status                VARCHAR(20) DEFAULT 'active',  -- active | inactive
    expires_at            TIMESTAMPTZ,
    created_at            TIMESTAMPTZ DEFAULT NOW(),
    updated_at            TIMESTAMPTZ,
    deleted_at            TIMESTAMPTZ
);

-- 4.4 TB_TRIP (여행)
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
    b2b_contract_id          UUID,                            -- TB_B2B_CONTRACT FK (99-deferred-fk.sql)
    -- ▼ 미성년자 포함 여부 (비즈니스 원칙 v5.1 §13 — 등급 강제 검증용)
    has_minor_members        BOOLEAN DEFAULT FALSE,
    -- ▼ v3.4: 여행 재활성화 추적 (비즈니스 원칙 v5.1 §02.6 — completed→active 24시간 내 1회 가능)
    reactivated_at           TIMESTAMPTZ,                  -- 마지막 재활성화 시각
    reactivation_count       INTEGER DEFAULT 0,            -- 재활성화 횟수 (최대 1회)
    -- ▼ 시스템 컬럼
    created_by               VARCHAR(128) REFERENCES tb_user(user_id),
    created_at               TIMESTAMPTZ DEFAULT NOW(),
    updated_at               TIMESTAMPTZ,
    deleted_at               TIMESTAMPTZ,
    -- ▼ 비즈니스 원칙 v5.1 §02.3: 여행 기간 최대 15일
    CONSTRAINT chk_trip_duration CHECK (end_date IS NULL OR start_date IS NULL OR end_date - start_date <= 15),
    -- ▼ v3.4: 재활성화 횟수 1회 제한
    CONSTRAINT chk_reactivation_count CHECK (reactivation_count <= 1)
);

CREATE INDEX idx_trips_group    ON tb_trip(group_id);
CREATE INDEX idx_trips_status   ON tb_trip(status);
CREATE INDEX idx_trips_dates    ON tb_trip(start_date, end_date);
CREATE INDEX idx_trips_b2b      ON tb_trip(b2b_contract_id) WHERE b2b_contract_id IS NOT NULL;

-- 4.5 TB_GROUP_MEMBER (그룹 멤버 — 역할 핵심)
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
-- ▼ v3.4: 그룹당 활성 captain은 1명만 허용 (비즈니스 원칙 v5.1 §08.2)
CREATE UNIQUE INDEX idx_group_member_captain
    ON tb_group_member(group_id)
    WHERE member_role = 'captain' AND status = 'active';

-- 4.6 TB_INVITE_CODE (역할별 초대코드)
CREATE TABLE tb_invite_code (
    invite_code_id  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id        UUID REFERENCES tb_group(group_id),
    trip_id         UUID REFERENCES tb_trip(trip_id),
    code            VARCHAR(7) UNIQUE,
    target_role     VARCHAR(30),                    -- crew_chief | crew | guardian
    max_uses        INTEGER DEFAULT 1,
    used_count      INTEGER DEFAULT 0,
    expires_at      TIMESTAMPTZ,
    created_by      VARCHAR(128) REFERENCES tb_user(user_id),
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    is_active       BOOLEAN DEFAULT TRUE,
    -- ▼ B2B 일괄 초대코드 참조
    b2b_batch_id    UUID                            -- TB_B2B_INVITE_BATCH FK (99-deferred-fk.sql)
);

CREATE INDEX idx_invite_code_group ON tb_invite_code(group_id);
CREATE INDEX idx_invite_code_code  ON tb_invite_code(code) WHERE is_active = TRUE;

-- 4.7 TB_TRIP_SETTINGS (여행 설정)
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

-- 4.8 TB_COUNTRY (국가 목록)
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
