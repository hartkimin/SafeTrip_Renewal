-- ============================================================
-- SafeTrip DB Schema v3.5.1
-- 02: [C] 보호자(가디언) 도메인
-- 기준 문서: 07_T2_DB_설계_및_관계_v3_5_1.md
-- ============================================================

-- 4.9 TB_GUARDIAN (보호자)
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
    is_minor_guardian    BOOLEAN DEFAULT FALSE,
    consent_id           UUID,
    auto_notify_sos      BOOLEAN DEFAULT TRUE,
    auto_notify_geofence BOOLEAN DEFAULT TRUE,
    is_paid              BOOLEAN DEFAULT FALSE,
    paid_at              TIMESTAMPTZ,
    payment_id           UUID,
    created_at           TIMESTAMPTZ DEFAULT NOW(),
    accepted_at          TIMESTAMPTZ,
    expires_at           TIMESTAMPTZ
);

CREATE INDEX idx_guardian_traveler ON tb_guardian(traveler_user_id);
CREATE INDEX idx_guardian_guardian ON tb_guardian(guardian_user_id);
CREATE INDEX idx_guardian_trip     ON tb_guardian(trip_id);

-- 4.10 TB_GUARDIAN_LINK (가디언-멤버 연결)
CREATE TABLE tb_guardian_link (
    link_id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id              UUID NOT NULL REFERENCES tb_trip(trip_id) ON DELETE CASCADE,
    member_id            VARCHAR(128) NOT NULL REFERENCES tb_user(user_id),
    guardian_id          VARCHAR(128) REFERENCES tb_user(user_id) ON DELETE SET NULL,
    guardian_phone       VARCHAR(20),
    status               VARCHAR(20) DEFAULT 'pending'
        CHECK (status IN ('pending', 'accepted', 'rejected', 'cancelled')),
    guardian_type        VARCHAR(20) DEFAULT 'personal'
        CHECK (guardian_type IN ('personal', 'group')),
    is_paid              BOOLEAN DEFAULT FALSE,
    paid_at              TIMESTAMPTZ,
    payment_id           UUID,
    can_view_location    BOOLEAN DEFAULT TRUE,
    can_receive_sos      BOOLEAN DEFAULT TRUE,
    can_request_checkin  BOOLEAN DEFAULT TRUE,
    can_send_message     BOOLEAN DEFAULT TRUE,
    invited_at           TIMESTAMPTZ DEFAULT NOW(),
    responded_at         TIMESTAMPTZ,
    created_at           TIMESTAMPTZ DEFAULT NOW(),
    updated_at           TIMESTAMPTZ
);

CREATE INDEX idx_guardian_link_trip     ON tb_guardian_link(trip_id);
CREATE INDEX idx_guardian_link_member   ON tb_guardian_link(member_id);
CREATE INDEX idx_guardian_link_guardian ON tb_guardian_link(guardian_id);
CREATE INDEX idx_guardian_link_status   ON tb_guardian_link(status);
CREATE UNIQUE INDEX idx_guardian_link_active
    ON tb_guardian_link(trip_id, member_id, guardian_id)
    WHERE guardian_id IS NOT NULL;
CREATE UNIQUE INDEX idx_guardian_link_pending
    ON tb_guardian_link(trip_id, member_id, guardian_phone)
    WHERE guardian_id IS NULL AND guardian_phone IS NOT NULL;

-- 4.11 TB_GUARDIAN_PAUSE (가디언 일시중지)
CREATE TABLE tb_guardian_pause (
    pause_id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    link_id           UUID NOT NULL REFERENCES tb_guardian_link(link_id),
    user_id           VARCHAR(128) NOT NULL REFERENCES tb_user(user_id),
    trip_id           UUID NOT NULL REFERENCES tb_trip(trip_id),
    group_id          UUID REFERENCES tb_group(group_id) ON DELETE CASCADE,
    guardian_user_id  VARCHAR(128) REFERENCES tb_user(user_id) ON DELETE SET NULL,
    paused_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    resume_at         TIMESTAMPTZ NOT NULL,
    is_active         BOOLEAN DEFAULT TRUE,
    pause_reason      VARCHAR(50),                   -- user_request | minor_blocked
    created_at        TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_guardian_pause_link ON tb_guardian_pause(link_id);
CREATE INDEX idx_guardian_pause_user ON tb_guardian_pause(user_id, trip_id);

-- 4.11a TB_GUARDIAN_LOCATION_REQUEST (가디언 긴급 위치 요청)
CREATE TABLE tb_guardian_location_request (
    request_id       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id         UUID NOT NULL REFERENCES tb_group(group_id),
    trip_id          UUID NOT NULL REFERENCES tb_trip(trip_id) ON DELETE CASCADE,
    guardian_user_id VARCHAR(128) NOT NULL REFERENCES tb_user(user_id),
    target_user_id   VARCHAR(128) NOT NULL REFERENCES tb_user(user_id),
    status           VARCHAR(20) DEFAULT 'pending'
        CHECK (status IN ('pending', 'approved', 'ignored', 'expired')),
    requested_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    responded_at          TIMESTAMPTZ,
    expires_at            TIMESTAMPTZ NOT NULL,
    auto_responded        BOOLEAN DEFAULT FALSE,
    auto_response_reason  VARCHAR(50),               -- standard_grade_auto | sos_override
    created_at            TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_guardian_location_request_target
    ON tb_guardian_location_request(target_user_id, status);
CREATE INDEX idx_guardian_location_request_guardian
    ON tb_guardian_location_request(guardian_user_id, requested_at DESC);
CREATE INDEX idx_guardian_location_request_trip
    ON tb_guardian_location_request(trip_id);
CREATE INDEX idx_guardian_location_request_hourly
    ON tb_guardian_location_request(guardian_user_id, requested_at DESC);

-- 4.11b TB_GUARDIAN_SNAPSHOT (가디언 위치 스냅샷)
CREATE TABLE tb_guardian_snapshot (
    snapshot_id  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id     UUID NOT NULL REFERENCES tb_group(group_id),
    trip_id      UUID NOT NULL REFERENCES tb_trip(trip_id) ON DELETE CASCADE,
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
