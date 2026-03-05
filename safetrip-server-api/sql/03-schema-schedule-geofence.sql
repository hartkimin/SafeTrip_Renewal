-- ============================================================
-- SafeTrip DB Schema v3.5.1
-- 03: [D] 일정 및 지오펜스 도메인
-- 기준 문서: 07_T2_DB_설계_및_관계_v3_5_1.md
-- ============================================================

-- 4.12 TB_SCHEDULE (기본 일정)
CREATE TABLE tb_schedule (
    schedule_id   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id       UUID NOT NULL REFERENCES tb_trip(trip_id),
    title         VARCHAR(200) NOT NULL,
    description   TEXT,
    schedule_date DATE,
    start_time    TIMESTAMPTZ,
    end_time      TIMESTAMPTZ,
    location      VARCHAR(200),
    location_lat  DOUBLE PRECISION,
    location_lng  DOUBLE PRECISION,
    all_day       BOOLEAN DEFAULT FALSE,
    order_index   INTEGER DEFAULT 0,
    created_by    VARCHAR(128) REFERENCES tb_user(user_id),
    created_at    TIMESTAMPTZ DEFAULT NOW(),
    updated_at    TIMESTAMPTZ
);

CREATE INDEX idx_schedule_trip ON tb_schedule(trip_id, schedule_date);

-- 4.13 TB_TRAVEL_SCHEDULE (고급 일정)
CREATE TABLE tb_travel_schedule (
    travel_schedule_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id           UUID NOT NULL REFERENCES tb_trip(trip_id),
    group_id          UUID REFERENCES tb_group(group_id),
    schedule_date     DATE,
    title             VARCHAR(200),
    description       TEXT,
    location          VARCHAR(200),
    estimated_cost    DECIMAL(10,2),
    booking_reference VARCHAR(100),
    geofence_id       UUID REFERENCES tb_geofence(geofence_id),
    created_by        VARCHAR(128) REFERENCES tb_user(user_id),
    created_at        TIMESTAMPTZ DEFAULT NOW(),
    updated_at        TIMESTAMPTZ
);

CREATE INDEX idx_travel_schedule_group ON tb_travel_schedule(group_id);
CREATE INDEX idx_travel_schedule_trip  ON tb_travel_schedule(trip_id);

-- 4.14 TB_GEOFENCE (안전 구역)
CREATE TABLE tb_geofence (
    geofence_id     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id        UUID REFERENCES tb_group(group_id),
    trip_id         UUID NOT NULL REFERENCES tb_trip(trip_id),
    name            VARCHAR(200),
    latitude        DOUBLE PRECISION,
    longitude       DOUBLE PRECISION,
    radius_meters   INTEGER DEFAULT 200,
    geofence_type   VARCHAR(20) DEFAULT 'safe',  -- safe | watch | danger
    is_active       BOOLEAN DEFAULT TRUE,
    created_by      VARCHAR(128) REFERENCES tb_user(user_id),
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ
);

CREATE INDEX idx_geofence_group  ON tb_geofence(group_id);
CREATE INDEX idx_geofence_trip   ON tb_geofence(trip_id);
CREATE INDEX idx_geofence_active ON tb_geofence(group_id, is_active) WHERE is_active = TRUE;
