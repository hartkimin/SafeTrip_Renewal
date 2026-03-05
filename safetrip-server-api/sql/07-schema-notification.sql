-- ============================================================
-- SafeTrip DB Schema v3.4.1
-- 07: [H] 알림 도메인 (3 tables)
-- 기준 문서: 07_T2_DB_설계_및_관계_v3_4.md §4.27~4.29
-- ============================================================

-- 4.27 TB_NOTIFICATION (알림)
CREATE TABLE tb_notification (
    notification_id  BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    user_id          VARCHAR(128) NOT NULL REFERENCES tb_user(user_id),
    trip_id          UUID REFERENCES tb_trip(trip_id),
    event_type       VARCHAR(50) NOT NULL,
    priority         VARCHAR(10) NOT NULL,          -- P0 | P1 | P2 | P3 | P4
    channel          VARCHAR(30) NOT NULL,          -- FCM 채널 ID
    title            TEXT NOT NULL,
    body             TEXT NOT NULL,
    icon             VARCHAR(10),
    color            VARCHAR(7),                    -- HEX
    deeplink         TEXT,
    related_user_id  VARCHAR(128),
    related_event_id BIGINT,
    location_data    JSONB,
    is_read          BOOLEAN DEFAULT FALSE,
    read_at          TIMESTAMPTZ,
    is_deleted       BOOLEAN DEFAULT FALSE,
    fcm_sent         BOOLEAN DEFAULT FALSE,
    fcm_sent_at      TIMESTAMPTZ,
    created_at       TIMESTAMPTZ DEFAULT NOW(),
    expires_at       TIMESTAMPTZ
);

CREATE INDEX idx_notification_user_read ON tb_notification(user_id, is_read, is_deleted);
CREATE INDEX idx_notification_trip      ON tb_notification(trip_id, created_at DESC);
CREATE INDEX idx_notification_priority  ON tb_notification(priority, is_read);
CREATE INDEX idx_notification_expires   ON tb_notification(expires_at) WHERE is_deleted = FALSE;

-- 4.28 TB_NOTIFICATION_SETTING (알림 설정 — 사용자별 이벤트 유형 on/off)
CREATE TABLE tb_notification_setting (
    user_id    VARCHAR(128) NOT NULL REFERENCES tb_user(user_id),
    event_type VARCHAR(50) NOT NULL,
    is_enabled BOOLEAN DEFAULT TRUE,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (user_id, event_type)
);

-- 4.29 TB_EVENT_NOTIFICATION_CONFIG (알림 규칙 — 그룹 단위)
CREATE TABLE tb_event_notification_config (
    config_id        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id         UUID REFERENCES tb_group(group_id),
    event_type       VARCHAR(50),
    notify_admins    BOOLEAN DEFAULT TRUE,
    notify_guardians BOOLEAN DEFAULT TRUE,
    notify_members   BOOLEAN DEFAULT FALSE,
    notify_self      BOOLEAN DEFAULT TRUE,
    is_enabled       BOOLEAN DEFAULT TRUE,
    title_template   TEXT,
    body_template    TEXT,
    UNIQUE(group_id, event_type)
);
