-- ============================================================
-- SafeTrip DB Schema v3.4.1
-- 09: [J] 운영 및 로그 도메인 (3 tables)
-- 기준 문서: 07_T2_DB_설계_및_관계_v3_4.md §4.36~4.38
-- ============================================================

-- 4.36 TB_EVENT_LOG (이벤트 기록)
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

-- 4.37 TB_LEADER_TRANSFER_LOG (리더 이양 기록) ⭐ 신규
CREATE TABLE tb_leader_transfer_log (
    transfer_id    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id       UUID REFERENCES tb_group(group_id),
    from_user_id   VARCHAR(128) REFERENCES tb_user(user_id),
    to_user_id     VARCHAR(128) REFERENCES tb_user(user_id),
    transferred_at TIMESTAMPTZ DEFAULT NOW(),
    -- ▼ v3.0 추가: 이전 캡틴 강등 시 is_admin 처리 확인 (v2.0 버그 수정)
    from_user_new_role VARCHAR(30) DEFAULT 'crew_chief'  -- 강등 후 역할
);

-- 4.38 TB_EMERGENCY_NUMBER (긴급 전화번호 DB) ⭐ 신규
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
