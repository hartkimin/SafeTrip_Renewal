-- ============================================================
-- SafeTrip DB Schema v3.4.1
-- 05: [F] 안전 및 SOS 도메인
-- 기준 문서: 07_T2_DB_설계_및_관계_v3_4.md §4.18~4.22b
-- ============================================================

-- 4.18 TB_HEARTBEAT (생존 신호)
CREATE TABLE tb_heartbeat (
    id             BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    user_id        VARCHAR(128) NOT NULL REFERENCES tb_user(user_id) ON DELETE CASCADE,
    trip_id        UUID NOT NULL REFERENCES tb_trip(trip_id) ON DELETE CASCADE,
    timestamp      TIMESTAMPTZ NOT NULL,
    location_lat   DECIMAL,
    location_lng   DECIMAL,
    battery_level  INTEGER,
    battery_charging BOOLEAN,
    network_type   VARCHAR(10),                        -- wifi | 4g | 5g | none
    app_state      VARCHAR(20),                        -- foreground | background | doze
    motion_state   VARCHAR(20)                         -- moving | stationary | unknown
);

CREATE INDEX idx_heartbeat_user ON tb_heartbeat(user_id, timestamp DESC);
CREATE INDEX idx_heartbeat_trip ON tb_heartbeat(trip_id, timestamp DESC);

-- 4.19 TB_SOS_EVENT (SOS 이벤트)
CREATE TABLE tb_sos_event (
    id              BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    event_type      VARCHAR(20) NOT NULL,              -- SOS | AUTO_SOS | OFFLINE_SOS
    sender_id       VARCHAR(128) REFERENCES tb_user(user_id) ON DELETE SET NULL,
    trip_id         UUID REFERENCES tb_trip(trip_id) ON DELETE SET NULL,
    trigger_type    VARCHAR(30),                       -- manual | heartbeat_timeout | battery_drain
    suspicion_score INTEGER,
    location_lat    DECIMAL,
    location_lng    DECIMAL,
    battery_level   INTEGER,
    sent_at         TIMESTAMPTZ NOT NULL,
    resolved_at     TIMESTAMPTZ,
    resolved_by     VARCHAR(128),
    resolution_type VARCHAR(30)                        -- confirmed_safe | power_recovery | false_alarm
);

-- 4.20 TB_POWER_EVENT (전원 이벤트)
CREATE TABLE tb_power_event (
    id                   BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    event_type           VARCHAR(20) NOT NULL,          -- LAST_BEACON | SHUTDOWN | POWER_RECOVERY
    user_id              VARCHAR(128) REFERENCES tb_user(user_id) ON DELETE SET NULL,
    trip_id              UUID REFERENCES tb_trip(trip_id) ON DELETE SET NULL,
    location_lat         DECIMAL,
    location_lng         DECIMAL,
    battery_level        INTEGER,
    offline_duration_min INTEGER,
    timestamp            TIMESTAMPTZ NOT NULL
);

-- 4.21 TB_SOS_RESCUE_LOG (구조 연동 기록)
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

-- 4.22 TB_SOS_CANCEL_LOG (SOS 해제 기록)
CREATE TABLE tb_sos_cancel_log (
    cancel_log_id    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sos_event_id     BIGINT NOT NULL REFERENCES tb_sos_event(id) ON DELETE CASCADE,
    group_id         UUID REFERENCES tb_group(group_id) ON DELETE SET NULL,
    cancelled_by     VARCHAR(128) REFERENCES tb_user(user_id) ON DELETE SET NULL,
    cancel_reason    VARCHAR(30),                      -- user_cancelled | captain_cancelled | auto_resolved
    cancel_within_sec INTEGER,
    created_at       TIMESTAMPTZ DEFAULT NOW()
);

-- 4.22a TB_ATTENDANCE_CHECK (출석 체크 세션 — v3.4 신규)
CREATE TABLE tb_attendance_check (
    check_id      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id       UUID NOT NULL REFERENCES tb_trip(trip_id) ON DELETE CASCADE,
    group_id      UUID NOT NULL REFERENCES tb_group(group_id) ON DELETE CASCADE,
    initiated_by  VARCHAR(128) REFERENCES tb_user(user_id) ON DELETE SET NULL,
    status        VARCHAR(20) DEFAULT 'ongoing'
        CHECK (status IN ('ongoing', 'completed', 'cancelled')),
    deadline_at   TIMESTAMPTZ NOT NULL,                -- 응답 마감 시각
    created_at    TIMESTAMPTZ DEFAULT NOW(),
    completed_at  TIMESTAMPTZ
);

CREATE INDEX idx_attendance_check_trip  ON tb_attendance_check(trip_id, created_at DESC);
CREATE INDEX idx_attendance_check_group ON tb_attendance_check(group_id, status);

-- 4.22b TB_ATTENDANCE_RESPONSE (출석 체크 응답 — v3.4 신규)
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
