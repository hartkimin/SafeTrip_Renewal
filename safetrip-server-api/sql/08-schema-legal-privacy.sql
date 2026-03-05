-- ============================================================
-- SafeTrip DB Schema v3.4.1
-- 08: [I] 법적 동의 및 개인정보 도메인 (6 tables)
-- 기준 문서: 07_T2_DB_설계_및_관계_v3_4.md §4.30~4.35
-- ============================================================

-- 4.30 TB_USER_CONSENT (사용자 동의)
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

-- 4.31 TB_MINOR_CONSENT (미성년자 동의)
CREATE TABLE tb_minor_consent (
    consent_id     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id        VARCHAR(128) NOT NULL REFERENCES tb_user(user_id) ON DELETE SET NULL,
    minor_status   VARCHAR(20) NOT NULL,            -- minor_child | minor_under14 | minor_over14
    consent_type   VARCHAR(30) NOT NULL,            -- legal_guardian | parent_notification | b2b_school
    guardian_phone VARCHAR(20),
    guardian_email VARCHAR(255),
    guardian_user_id VARCHAR(128) REFERENCES tb_user(user_id) ON DELETE SET NULL,
    b2b_school_id  VARCHAR(128),
    b2b_contract_id UUID,                              -- TB_B2B_CONTRACT FK (후행 추가)
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

-- 4.32 TB_LOCATION_ACCESS_LOG (위치정보 접근 이력)
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

-- 4.33 TB_LOCATION_SHARING_PAUSE_LOG (가디언 위치공유 일시중지 이력) ⭐ 신규
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

-- 4.34 TB_DATA_DELETION_LOG (데이터 삭제 이력)
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

-- 4.35 TB_DATA_PROVISION_LOG (데이터 제공 이력) ⭐ 신규
CREATE TABLE tb_data_provision_log (
    provision_id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    -- ▼ v3.4: FK 추가 (영구 보존 목적 — ON DELETE SET NULL)
    sos_event_id         BIGINT REFERENCES tb_sos_event(id) ON DELETE SET NULL,
    requesting_agency    VARCHAR(100),
    request_type         VARCHAR(30),  -- emergency_rescue | warrant | official_request
    legal_basis          TEXT,
    provided_items       JSONB,
    processed_by         VARCHAR(128),               -- 'system' 또는 admin user_id 문자열
    -- ▼ v3.4: FK용 별도 컬럼 (processed_by가 'system' 혼용이므로 분리)
    processed_by_user_id VARCHAR(128) REFERENCES tb_user(user_id) ON DELETE SET NULL,
    requested_at         TIMESTAMPTZ,
    provided_at          TIMESTAMPTZ,
    created_at           TIMESTAMPTZ DEFAULT NOW()
);
