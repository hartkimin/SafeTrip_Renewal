-- ============================================================
-- SafeTrip DB Schema v3.5.1
-- 01: [A] 사용자 및 인증 + [B] 그룹 및 여행
-- 기준 문서: 07_T2_DB_설계_및_관계_v3_5_1.md
-- ============================================================

-- ------------------------------------------
-- [A] 도메인: 사용자 및 인증
-- ------------------------------------------

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
    minor_status             VARCHAR(20) DEFAULT 'adult',  -- adult | minor_over14 | minor_under14 | minor_child
    minor_status_updated_at  TIMESTAMPTZ,
    guardian_pause_blocked   BOOLEAN DEFAULT FALSE,
    ai_intelligence_blocked  BOOLEAN DEFAULT FALSE,
    last_verification_at     TIMESTAMPTZ,
    last_login_at            TIMESTAMPTZ,
    last_active_at           TIMESTAMPTZ,
    created_at               TIMESTAMPTZ DEFAULT NOW(),
    updated_at               TIMESTAMPTZ,
    deletion_requested_at    TIMESTAMPTZ,
    deleted_at               TIMESTAMPTZ
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

-- ------------------------------------------
-- [B] 도메인: 그룹 및 여행
-- ------------------------------------------

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
    privacy_level            VARCHAR(20) DEFAULT 'standard',
    sharing_mode             VARCHAR(20) DEFAULT 'voluntary',
    schedule_type            VARCHAR(20) DEFAULT 'always',
    schedule_buffer_minutes  INTEGER DEFAULT 15,
    b2b_contract_id          UUID,
    has_minor_members        BOOLEAN DEFAULT FALSE,
    reactivated_at           TIMESTAMPTZ,
    reactivation_count       INTEGER DEFAULT 0,
    created_by               VARCHAR(128),
    created_at               TIMESTAMPTZ DEFAULT NOW(),
    updated_at               TIMESTAMPTZ,
    deleted_at               TIMESTAMPTZ,
    CONSTRAINT chk_trip_duration CHECK (end_date IS NULL OR start_date IS NULL OR end_date - start_date <= 15),
    CONSTRAINT chk_reactivation_count CHECK (reactivation_count <= 1)
);

CREATE INDEX idx_trips_group    ON tb_trip(group_id);
CREATE INDEX idx_trips_status   ON tb_trip(status);
CREATE INDEX idx_trips_dates    ON tb_trip(start_date, end_date);
CREATE INDEX idx_trips_b2b      ON tb_trip(b2b_contract_id) WHERE b2b_contract_id IS NOT NULL;

-- 4.5 TB_GROUP_MEMBER (그룹 멤버)
CREATE TABLE tb_group_member (
    member_id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id                 UUID NOT NULL REFERENCES tb_group(group_id) ON DELETE CASCADE,
    user_id                  VARCHAR(128) NOT NULL REFERENCES tb_user(user_id) ON DELETE CASCADE,
    member_role              VARCHAR(30) DEFAULT 'crew'
        CHECK (member_role IN ('captain', 'crew_chief', 'crew', 'guardian')),
    trip_id                  UUID NOT NULL REFERENCES tb_trip(trip_id),
    is_admin                 BOOLEAN DEFAULT FALSE,
    is_guardian              BOOLEAN DEFAULT FALSE,
    can_edit_schedule        BOOLEAN DEFAULT FALSE,
    can_edit_geofence        BOOLEAN DEFAULT FALSE,
    can_view_all_locations   BOOLEAN DEFAULT TRUE,
    can_attendance_check     BOOLEAN DEFAULT TRUE,
    traveler_user_id         VARCHAR(128),
    location_sharing_enabled BOOLEAN DEFAULT TRUE,
    status                   VARCHAR(20) DEFAULT 'active',
    joined_at                TIMESTAMPTZ DEFAULT NOW(),
    left_at                  TIMESTAMPTZ,
    UNIQUE(group_id, user_id)
);

CREATE INDEX idx_group_members_group ON tb_group_member(group_id);
CREATE INDEX idx_group_members_user  ON tb_group_member(user_id);
CREATE INDEX idx_group_members_role  ON tb_group_member(member_role);
CREATE INDEX idx_group_members_trip  ON tb_group_member(trip_id);
CREATE UNIQUE INDEX idx_group_member_captain
    ON tb_group_member(group_id)
    WHERE member_role = 'captain' AND status = 'active';

-- 4.6 TB_INVITE_CODE (역할별 초대코드)
CREATE TABLE tb_invite_code (
    invite_code_id  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id        UUID REFERENCES tb_group(group_id),
    trip_id         UUID REFERENCES tb_trip(trip_id),
    code            VARCHAR(7) UNIQUE,
    target_role     VARCHAR(30),
    max_uses        INTEGER DEFAULT 1,
    used_count      INTEGER DEFAULT 0,
    expires_at      TIMESTAMPTZ,
    created_by      VARCHAR(128) REFERENCES tb_user(user_id),
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    is_active       BOOLEAN DEFAULT TRUE,
    b2b_batch_id    UUID
);

CREATE INDEX idx_invite_code_group ON tb_invite_code(group_id);
CREATE INDEX idx_invite_code_code  ON tb_invite_code(code) WHERE is_active = TRUE;

-- 4.7 TB_TRIP_SETTINGS (여행 설정)
CREATE TABLE tb_trip_settings (
    setting_id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id                       UUID NOT NULL UNIQUE REFERENCES tb_trip(trip_id),
    captain_receive_guardian_msg  BOOLEAN DEFAULT TRUE,
    guardian_msg_enabled          BOOLEAN DEFAULT TRUE,
    sos_auto_trigger_enabled      BOOLEAN DEFAULT TRUE,
    sos_heartbeat_timeout_min     INTEGER DEFAULT 30,
    attendance_check_enabled      BOOLEAN DEFAULT TRUE,
    geofence_guardian_notify      BOOLEAN DEFAULT TRUE,
    created_at                    TIMESTAMPTZ DEFAULT NOW(),
    updated_at                    TIMESTAMPTZ
);

-- 4.8 TB_COUNTRY (국가 목록)
CREATE TABLE tb_country (
    country_id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    country_code        VARCHAR(5) NOT NULL UNIQUE,
    country_name_ko     VARCHAR(100) NOT NULL,
    country_name_en     VARCHAR(100) NOT NULL,
    country_flag_emoji  VARCHAR(10),
    phone_code          VARCHAR(10),
    region              VARCHAR(50),
    mofa_travel_alert   VARCHAR(20) DEFAULT 'none',
    mofa_alert_updated_at TIMESTAMPTZ,
    is_popular          BOOLEAN DEFAULT FALSE,
    sort_order          INTEGER DEFAULT 0,
    created_at          TIMESTAMPTZ DEFAULT NOW(),
    updated_at          TIMESTAMPTZ
);

CREATE INDEX idx_country_code   ON tb_country(country_code);
CREATE INDEX idx_country_region ON tb_country(region);

-- 4.8a TB_ATTENDANCE_CHECK (출석 체크)
CREATE TABLE tb_attendance_check (
    check_id      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id       UUID NOT NULL REFERENCES tb_trip(trip_id),
    group_id      UUID NOT NULL REFERENCES tb_group(group_id),
    initiated_by  VARCHAR(128) NOT NULL REFERENCES tb_user(user_id),
    deadline_at   TIMESTAMPTZ NOT NULL,
    created_at    TIMESTAMPTZ DEFAULT NOW()
);

-- 4.8b TB_ATTENDANCE_RESPONSE (출석 응답)
CREATE TABLE tb_attendance_response (
    response_id    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    check_id       UUID NOT NULL REFERENCES tb_attendance_check(check_id),
    user_id        VARCHAR(128) NOT NULL REFERENCES tb_user(user_id),
    response_type  VARCHAR(20) DEFAULT 'unknown',  -- present | absent | unknown
    responded_at   TIMESTAMPTZ,
    created_at     TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(check_id, user_id)
);
