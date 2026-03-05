-- ============================================================
-- SafeTrip DB Schema v3.5.1
-- 04: [E] 위치 및 이동기록 도메인
-- 기준 문서: 07_T2_DB_설계_및_관계_v3_5_1.md
-- ============================================================

-- 4.15 TB_LOCATION_SHARING (위치 공유 설정)
CREATE TABLE tb_location_sharing (
    location_sharing_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id             UUID NOT NULL REFERENCES tb_trip(trip_id),
    user_id             VARCHAR(128) NOT NULL REFERENCES tb_user(user_id),
    visibility_type     VARCHAR(20) DEFAULT 'all'
        CHECK (visibility_type IN ('all', 'admin_only', 'specified')),
    visibility_member_ids JSONB,
    is_active           BOOLEAN DEFAULT TRUE,
    created_at          TIMESTAMPTZ DEFAULT NOW(),
    updated_at          TIMESTAMPTZ
);

CREATE INDEX idx_location_sharing_user ON tb_location_sharing(user_id);
CREATE INDEX idx_location_sharing_trip ON tb_location_sharing(trip_id);

-- 4.15a TB_LOCATION_SCHEDULE (위치 공유 시간대 스케줄)
CREATE TABLE tb_location_schedule (
    schedule_id   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id       UUID NOT NULL REFERENCES tb_trip(trip_id) ON DELETE CASCADE,
    user_id       VARCHAR(128) NOT NULL REFERENCES tb_user(user_id) ON DELETE CASCADE,
    day_of_week   VARCHAR(10),                             -- Mon | Tue | ... | Sun (NULL = daily)
    share_start   TIME NOT NULL,
    share_end     TIME NOT NULL,
    specific_date DATE,
    created_at    TIMESTAMPTZ DEFAULT NOW(),
    updated_at    TIMESTAMPTZ
);

CREATE INDEX idx_location_schedule_trip ON tb_location_schedule(trip_id);
CREATE INDEX idx_location_schedule_user ON tb_location_schedule(trip_id, user_id);
CREATE INDEX idx_location_schedule_date ON tb_location_schedule(trip_id, specific_date)
    WHERE specific_date IS NOT NULL;

-- 4.16 TB_LOCATION (위치 기록)
CREATE TABLE tb_location (
    location_id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id              VARCHAR(128) NOT NULL REFERENCES tb_user(user_id),
    trip_id              UUID REFERENCES tb_trip(trip_id),
    group_id             UUID REFERENCES tb_group(group_id),
    latitude             DOUBLE PRECISION NOT NULL,
    longitude            DOUBLE PRECISION NOT NULL,
    accuracy             DOUBLE PRECISION,
    speed                DOUBLE PRECISION,
    bearing              DOUBLE PRECISION,
    altitude             DOUBLE PRECISION,
    battery_level        INTEGER,
    network_type         VARCHAR(20),
    is_sharing           BOOLEAN DEFAULT TRUE,
    motion_state         VARCHAR(20),
    provider             VARCHAR(20),
    movement_session_id  UUID,
    recorded_at          TIMESTAMPTZ NOT NULL,
    server_received_at   TIMESTAMPTZ DEFAULT NOW(),
    created_at           TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_locations_user_id     ON tb_location(user_id);
CREATE INDEX idx_locations_recorded_at ON tb_location(recorded_at DESC);
CREATE INDEX idx_locations_trip        ON tb_location(trip_id);
CREATE INDEX idx_locations_movement_session ON tb_location(movement_session_id)
    WHERE movement_session_id IS NOT NULL;

-- 4.17 TB_STAY_POINT (체류 지점 감지)
CREATE TABLE tb_stay_point (
    stay_point_id    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id          VARCHAR(128) NOT NULL REFERENCES tb_user(user_id),
    trip_id          UUID REFERENCES tb_trip(trip_id),
    latitude         DOUBLE PRECISION NOT NULL,
    longitude        DOUBLE PRECISION NOT NULL,
    arrived_at       TIMESTAMPTZ NOT NULL,
    left_at          TIMESTAMPTZ,
    duration_minutes INTEGER,
    place_name       VARCHAR(200)
);

-- 4.17a TB_SESSION_MAP_IMAGE (세션 지도 이미지 캐시)
CREATE TABLE tb_session_map_image (
    image_id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    movement_session_id  UUID NOT NULL,
    trip_id              UUID REFERENCES tb_trip(trip_id),
    user_id              VARCHAR(128) NOT NULL REFERENCES tb_user(user_id),
    image_url            TEXT NOT NULL,
    storage_type         VARCHAR(20) DEFAULT 'firebase',
    created_at           TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_session_map_image_user ON tb_session_map_image(user_id);

-- 4.17b TB_PLANNED_ROUTE (계획된 경로)
CREATE TABLE tb_planned_route (
    route_id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id            UUID NOT NULL REFERENCES tb_trip(trip_id) ON DELETE CASCADE,
    user_id            VARCHAR(128) NOT NULL REFERENCES tb_user(user_id) ON DELETE CASCADE,
    route_name         VARCHAR(200),
    start_location     VARCHAR(200) NOT NULL,
    end_location       VARCHAR(200) NOT NULL,
    start_latitude     DOUBLE PRECISION NOT NULL,
    start_longitude    DOUBLE PRECISION NOT NULL,
    end_latitude       DOUBLE PRECISION NOT NULL,
    end_longitude      DOUBLE PRECISION NOT NULL,
    route_path         JSONB NOT NULL,
    waypoints          JSONB,
    total_distance     DECIMAL(10,2),
    estimated_duration INTEGER,
    deviation_threshold INTEGER DEFAULT 100,
    is_active          BOOLEAN DEFAULT TRUE,
    scheduled_start    TIMESTAMPTZ,
    scheduled_end      TIMESTAMPTZ,
    created_at         TIMESTAMPTZ DEFAULT NOW(),
    updated_at         TIMESTAMPTZ,
    deleted_at         TIMESTAMPTZ
);

CREATE INDEX idx_planned_routes_trip   ON tb_planned_route(trip_id);
CREATE INDEX idx_planned_routes_user   ON tb_planned_route(user_id);
CREATE INDEX idx_planned_routes_active ON tb_planned_route(is_active) WHERE is_active = TRUE;

-- 4.17c TB_ROUTE_DEVIATION (경로 이탈 감지 로그)
CREATE TABLE tb_route_deviation (
    deviation_id        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    route_id            UUID NOT NULL REFERENCES tb_planned_route(route_id) ON DELETE CASCADE,
    trip_id             UUID NOT NULL REFERENCES tb_trip(trip_id) ON DELETE CASCADE,
    user_id             VARCHAR(128) NOT NULL REFERENCES tb_user(user_id) ON DELETE CASCADE,
    latitude            DOUBLE PRECISION NOT NULL,
    longitude           DOUBLE PRECISION NOT NULL,
    distance_meters     DOUBLE PRECISION NOT NULL,
    deviation_status    VARCHAR(20) NOT NULL DEFAULT 'active',   -- active | resolved | ignored
    severity            VARCHAR(20) DEFAULT 'low',               -- low | medium | high | critical
    started_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    ended_at            TIMESTAMPTZ,
    duration            INTEGER,
    guardian_notified    BOOLEAN DEFAULT FALSE,
    notification_sent_at TIMESTAMPTZ,
    consecutive_count   INTEGER DEFAULT 1,
    created_at          TIMESTAMPTZ DEFAULT NOW(),
    updated_at          TIMESTAMPTZ
);

CREATE INDEX idx_route_deviations_route  ON tb_route_deviation(route_id);
CREATE INDEX idx_route_deviations_trip   ON tb_route_deviation(trip_id);
CREATE INDEX idx_route_deviations_user   ON tb_route_deviation(user_id);
CREATE INDEX idx_route_deviations_status ON tb_route_deviation(deviation_status);
