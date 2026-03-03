-- ============================================================
-- SafeTrip DB Schema v3.4.1
-- 06: [G] 채팅 도메인 (4 tables)
-- 기준 문서: 07_T2_DB_설계_및_관계_v3_4.md §4.23~4.26
-- ============================================================

-- 4.23 TB_CHAT_MESSAGE (채팅 메시지)
CREATE TABLE tb_chat_message (
    message_id         BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    trip_id            UUID NOT NULL REFERENCES tb_trip(trip_id),
    group_id           UUID NOT NULL REFERENCES tb_group(group_id),
    -- ▼ v3.4: FK 추가 (NULL = 시스템 메시지)
    sender_id          VARCHAR(128) REFERENCES tb_user(user_id) ON DELETE SET NULL,
    message_type       VARCHAR(20) NOT NULL,
        -- text | image | video | file | location | poll | system
    content            TEXT,
    media_urls         JSONB,                      -- [{url, type, size, thumbnail}]
    location_data      JSONB,                      -- {lat, lng, address, place_name}
    reply_to_id        BIGINT,                     -- 답글 대상 message_id
    system_event_type  VARCHAR(50),
    system_event_level VARCHAR(20),               -- INFO | SCHEDULE | WARNING | CRITICAL | CELEBRATION
    is_pinned          BOOLEAN DEFAULT FALSE,
    pinned_by          VARCHAR(128),
    deleted_by         VARCHAR(128),
    created_at         TIMESTAMPTZ DEFAULT NOW(),
    updated_at         TIMESTAMPTZ
);

CREATE INDEX idx_chat_message_trip   ON tb_chat_message(trip_id, created_at DESC);
CREATE INDEX idx_chat_message_type   ON tb_chat_message(message_type);
CREATE INDEX idx_chat_message_system ON tb_chat_message(system_event_level)
    WHERE message_type = 'system';

-- 4.24 TB_CHAT_POLL (투표)
CREATE TABLE tb_chat_poll (
    poll_id        BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    message_id     BIGINT NOT NULL REFERENCES tb_chat_message(message_id) ON DELETE CASCADE,
    trip_id        UUID NOT NULL REFERENCES tb_trip(trip_id) ON DELETE CASCADE,
    creator_id     VARCHAR(128) NOT NULL REFERENCES tb_user(user_id) ON DELETE SET NULL,
    title          VARCHAR(200) NOT NULL,
    options        JSONB NOT NULL,                 -- [{id, text, color}]
    allow_multiple BOOLEAN DEFAULT FALSE,
    is_anonymous   BOOLEAN DEFAULT FALSE,
    closes_at      TIMESTAMPTZ,
    is_closed      BOOLEAN DEFAULT FALSE,
    closed_by      VARCHAR(128),
    created_at     TIMESTAMPTZ DEFAULT NOW()
);

-- 4.25 TB_CHAT_POLL_VOTE (투표 응답)
CREATE TABLE tb_chat_poll_vote (
    vote_id          BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    poll_id          BIGINT NOT NULL REFERENCES tb_chat_poll(poll_id) ON DELETE CASCADE,
    user_id          VARCHAR(128) NOT NULL REFERENCES tb_user(user_id) ON DELETE CASCADE,
    selected_options INTEGER[] NOT NULL,
    voted_at         TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(poll_id, user_id)
);

-- 4.26 TB_CHAT_READ_STATUS (읽음 상태)
CREATE TABLE tb_chat_read_status (
    trip_id              UUID NOT NULL REFERENCES tb_trip(trip_id) ON DELETE CASCADE,
    user_id              VARCHAR(128) NOT NULL REFERENCES tb_user(user_id) ON DELETE CASCADE,
    last_read_message_id BIGINT,
    last_read_at         TIMESTAMPTZ,
    PRIMARY KEY (trip_id, user_id)
);
