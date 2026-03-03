-- ============================================================
-- SafeTrip DB Schema v3.4.1
-- 03: [D] 일정 및 지오펜스 도메인
-- 기준 문서: 07_T2_DB_설계_및_관계_v3_4.md §4.12~4.14
-- ============================================================

-- 4.12 TB_SCHEDULE (기본 일정)
CREATE TABLE tb_schedule (
    schedule_id   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id       UUID REFERENCES tb_trip(trip_id),
    schedule_name VARCHAR(200),
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

-- 4.14 TB_GEOFENCE (안전 구역)
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
    -- ▼ v3.4: is_active 복원
    is_active            BOOLEAN DEFAULT TRUE,
    schedule_id          UUID REFERENCES tb_schedule(schedule_id),
    created_by           VARCHAR(128) REFERENCES tb_user(user_id),
    created_at           TIMESTAMPTZ DEFAULT NOW(),
    updated_at           TIMESTAMPTZ
);

CREATE INDEX idx_geofence_group    ON tb_geofence(group_id);
CREATE INDEX idx_geofence_trip     ON tb_geofence(trip_id);
CREATE INDEX idx_geofence_active   ON tb_geofence(group_id, is_active) WHERE is_active = TRUE;

-- 4.13 TB_TRAVEL_SCHEDULE (고급 일정 — 스키마 확정)
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
