-- ============================================================
-- SafeTrip DB Schema v3.4.1
-- 04: [E] 위치 및 이동기록 도메인
-- 기준 문서: 07_T2_DB_설계_및_관계_v3_4.md §4.15~4.17c
-- ============================================================

-- 4.15 TB_LOCATION_SHARING (위치 공유 설정)
CREATE TABLE tb_location_sharing (
    sharing_id      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id        UUID REFERENCES tb_group(group_id),
    -- ▼ v3.4: trip_id 추가 — 위치 공유는 여행 단위로 관리
    trip_id         UUID REFERENCES tb_trip(trip_id) ON DELETE CASCADE,
    user_id         VARCHAR(128) REFERENCES tb_user(user_id),
    target_user_id  VARCHAR(128) REFERENCES tb_user(user_id),
    is_sharing      BOOLEAN DEFAULT TRUE,
    -- ▼ v3.4: 공개 범위 3단계 (비즈니스 원칙 v5.1 §04.4)
    visibility_type VARCHAR(20) DEFAULT 'all'
        CHECK (visibility_type IN (
            'all',          -- 전체 공개
            'admin_only',   -- 관리자만
            'specified'     -- 지정 멤버
        )),
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ
);

CREATE INDEX idx_location_sharing_user   ON tb_location_sharing(user_id);
CREATE INDEX idx_location_sharing_target ON tb_location_sharing(target_user_id);
CREATE INDEX idx_location_sharing_trip   ON tb_location_sharing(trip_id);

-- 4.15a TB_LOCATION_SCHEDULE (위치 공유 시간대 스케줄 — v3.4 신규)
CREATE TABLE tb_location_schedule (
    schedule_id   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id       UUID NOT NULL REFERENCES tb_trip(trip_id) ON DELETE CASCADE,
    user_id       VARCHAR(128) NOT NULL REFERENCES tb_user(user_id) ON DELETE CASCADE,
    -- ▼ 적용 범위 (비즈니스 원칙 v5.1 §04.3 3가지 옵션)
    day_of_week   INTEGER CHECK (day_of_week BETWEEN 0 AND 6),  -- 0=일, 1=월 ... 6=토
    specific_date DATE,                                          -- 특정 일자
    -- ▼ day_of_week, specific_date 동시 지정 금지 (상호 배타적)
    CONSTRAINT chk_schedule_scope
        CHECK (day_of_week IS NULL OR specific_date IS NULL),
    -- ▼ 공유 시간대
    share_start   TIME NOT NULL,
    share_end     TIME NOT NULL,
    is_active     BOOLEAN DEFAULT TRUE,
    created_at    TIMESTAMPTZ DEFAULT NOW(),
    updated_at    TIMESTAMPTZ
);

CREATE INDEX idx_location_schedule_trip  ON tb_location_schedule(trip_id);
CREATE INDEX idx_location_schedule_user  ON tb_location_schedule(trip_id, user_id);
CREATE INDEX idx_location_schedule_date  ON tb_location_schedule(trip_id, specific_date) WHERE specific_date IS NOT NULL;

-- 4.16 TB_LOCATION (이동 경로 기록 — 실제 구현, 구 TB_LOCATION_LOG)
CREATE TABLE tb_location (
    -- 기본 정보
    location_id       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id           VARCHAR(128) NOT NULL REFERENCES tb_user(user_id) ON DELETE CASCADE,

    -- 좌표
    latitude          DECIMAL(10, 8) NOT NULL,
    longitude         DECIMAL(11, 8) NOT NULL,
    accuracy          DECIMAL(6, 2),
    altitude          DECIMAL(8, 2),

    -- PostGIS 지원
    geom              GEOGRAPHY(POINT, 4326),       -- PostGIS 공간 인덱스용

    -- 주소 정보 (Reverse Geocoding)
    address           TEXT,
    city              VARCHAR(100),
    country           VARCHAR(100),

    -- 이동 정보
    speed             DECIMAL(6, 2),
    heading           DECIMAL(5, 2),                -- 이동 방향 (도)

    -- 디바이스 상태
    battery_level     INTEGER,
    network_type      VARCHAR(20),

    -- 추적 모드
    tracking_mode     VARCHAR(20) DEFAULT 'normal', -- normal | power_saving | minimal | sos

    -- 이동 세션 정보
    movement_session_id UUID,                       -- 같은 이동 구간 그룹화 (논리키)
    is_movement_start BOOLEAN DEFAULT FALSE,        -- 정지 → 이동 전환 시 TRUE
    is_movement_end   BOOLEAN DEFAULT FALSE,        -- 이동 → 정지 전환 시 TRUE

    -- Activity Recognition
    activity_type     VARCHAR(20),                  -- still | walking | running | on_bicycle | in_vehicle | unknown
    activity_confidence INTEGER,                    -- 신뢰도 (0-100)

    -- 사용자별 순차 인덱스
    i_idx             BIGINT,

    -- 메타데이터
    recorded_at       TIMESTAMPTZ NOT NULL DEFAULT (now() AT TIME ZONE 'UTC'),
    synced_at         TIMESTAMPTZ,
    is_offline        BOOLEAN DEFAULT FALSE,

    -- 제약조건
    CONSTRAINT chk_latitude  CHECK (latitude  BETWEEN -90  AND 90),
    CONSTRAINT chk_longitude CHECK (longitude BETWEEN -180 AND 180),
    CONSTRAINT chk_battery   CHECK (battery_level BETWEEN 0 AND 100)
);

-- PostGIS 공간 인덱스
CREATE INDEX idx_locations_geom                ON tb_location USING GIST(geom);
CREATE INDEX idx_locations_user_id             ON tb_location(user_id);
CREATE INDEX idx_locations_recorded_at         ON tb_location(recorded_at DESC);
CREATE INDEX idx_locations_coords              ON tb_location(latitude, longitude);
CREATE INDEX idx_locations_movement_session    ON tb_location(movement_session_id) WHERE movement_session_id IS NOT NULL;
CREATE INDEX idx_locations_movement_session_user ON tb_location(user_id, movement_session_id, recorded_at) WHERE movement_session_id IS NOT NULL;
CREATE INDEX idx_locations_movement_start      ON tb_location(user_id, is_movement_start) WHERE is_movement_start = TRUE;
CREATE INDEX idx_locations_movement_end        ON tb_location(user_id, is_movement_end)   WHERE is_movement_end   = TRUE;
CREATE INDEX idx_locations_user_idx            ON tb_location(user_id, i_idx);

-- 4.17 TB_STAY_POINT (체류 지점 감지)
CREATE TABLE tb_stay_point (
    stay_id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id         UUID NOT NULL REFERENCES tb_group(group_id),
    user_id          VARCHAR(128) NOT NULL REFERENCES tb_user(user_id),
    center_lat       DOUBLE PRECISION NOT NULL,
    center_lng       DOUBLE PRECISION NOT NULL,
    arrived_at       TIMESTAMPTZ NOT NULL,
    departed_at      TIMESTAMPTZ,
    duration_minutes INTEGER,
    created_at       TIMESTAMPTZ DEFAULT NOW()
);

-- 4.17a TB_SESSION_MAP_IMAGE (세션 지도 이미지 캐시)
CREATE TABLE tb_session_map_image (
    session_id       UUID PRIMARY KEY,             -- movement_session_id (세션 고유 식별자)
    user_id          VARCHAR(128) NOT NULL REFERENCES tb_user(user_id) ON DELETE CASCADE,
    map_image_url    TEXT,                         -- Firebase Storage에 저장된 지도 이미지 URL
    map_image_base64 TEXT,                         -- Base64 인코딩 이미지 (하위 호환성)
    created_at       TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_session_map_image_user_id    ON tb_session_map_image(user_id);
CREATE INDEX idx_session_map_image_created_at ON tb_session_map_image(created_at DESC);
CREATE INDEX idx_session_map_image_url        ON tb_session_map_image(map_image_url) WHERE map_image_url IS NOT NULL;

-- 4.17b TB_PLANNED_ROUTE (계획된 경로)
CREATE TABLE tb_planned_route (
    route_id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id            UUID NOT NULL REFERENCES tb_trip(trip_id) ON DELETE CASCADE,
    user_id            VARCHAR(128) NOT NULL REFERENCES tb_user(user_id) ON DELETE CASCADE,

    -- 경로 정보
    route_name         VARCHAR(200),
    start_location     VARCHAR(200) NOT NULL,
    end_location       VARCHAR(200) NOT NULL,
    start_coords       GEOGRAPHY(Point, 4326) NOT NULL,
    end_coords         GEOGRAPHY(Point, 4326) NOT NULL,

    -- 경로 데이터 (GeoJSON LineString)
    route_path         JSONB NOT NULL,             -- GeoJSON LineString 형식
    waypoints          JSONB,                      -- [{name, lat, lng, order}]

    -- 경로 속성
    total_distance     DECIMAL(10, 2),             -- 전체 경로 거리 (km)
    estimated_duration INTEGER,                    -- 예상 소요 시간 (분)

    -- 이탈 감지 설정
    deviation_threshold INTEGER DEFAULT 100,       -- 이탈 감지 임계값 (미터)
    is_active          BOOLEAN DEFAULT TRUE,

    -- 일정
    scheduled_start    TIMESTAMPTZ,
    scheduled_end      TIMESTAMPTZ,

    -- 메타데이터
    created_at         TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at         TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    deleted_at         TIMESTAMPTZ
);

CREATE INDEX idx_planned_routes_trip       ON tb_planned_route(trip_id);
CREATE INDEX idx_planned_routes_user       ON tb_planned_route(user_id);
CREATE INDEX idx_planned_routes_active     ON tb_planned_route(is_active) WHERE is_active = TRUE;
CREATE INDEX idx_planned_routes_schedule   ON tb_planned_route(scheduled_start, scheduled_end);
CREATE INDEX idx_planned_routes_start_geom ON tb_planned_route USING GIST(start_coords);
CREATE INDEX idx_planned_routes_end_geom   ON tb_planned_route USING GIST(end_coords);

-- 4.17c TB_ROUTE_DEVIATION (경로 이탈 감지 로그)
CREATE TABLE tb_route_deviation (
    deviation_id        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    route_id            UUID NOT NULL REFERENCES tb_planned_route(route_id) ON DELETE CASCADE,
    trip_id             UUID NOT NULL REFERENCES tb_trip(trip_id) ON DELETE CASCADE,
    user_id             VARCHAR(128) NOT NULL REFERENCES tb_user(user_id) ON DELETE CASCADE,

    -- 이탈 위치
    deviation_location  GEOGRAPHY(Point, 4326) NOT NULL,
    deviation_distance  DECIMAL(10, 2) NOT NULL,   -- 계획 경로로부터의 거리 (미터)

    -- 이탈 상태
    deviation_status    VARCHAR(20) NOT NULL DEFAULT 'active',
                                                   -- active | resolved | ignored
    severity            VARCHAR(20) DEFAULT 'low', -- low(<100m) | medium(100-300m) | high(300-500m) | critical(>500m)

    -- 이탈 시간
    started_at          TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ended_at            TIMESTAMPTZ,
    duration            INTEGER,                   -- 이탈 지속 시간 (초)

    -- 알림 여부
    guardian_notified   BOOLEAN DEFAULT FALSE,
    notification_sent_at TIMESTAMPTZ,

    -- 연속 이탈 카운트 (3회 이상 시 경고 알림)
    consecutive_count   INTEGER DEFAULT 1,

    -- 메타데이터
    created_at          TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT chk_deviation_status CHECK (deviation_status IN ('active', 'resolved', 'ignored')),
    CONSTRAINT chk_severity         CHECK (severity IN ('low', 'medium', 'high', 'critical'))
);

CREATE INDEX idx_route_deviations_route   ON tb_route_deviation(route_id);
CREATE INDEX idx_route_deviations_trip    ON tb_route_deviation(trip_id);
CREATE INDEX idx_route_deviations_user    ON tb_route_deviation(user_id);
CREATE INDEX idx_route_deviations_status  ON tb_route_deviation(deviation_status);
CREATE INDEX idx_route_deviations_started ON tb_route_deviation(started_at DESC);
CREATE INDEX idx_route_deviations_geom    ON tb_route_deviation USING GIST(deviation_location);
