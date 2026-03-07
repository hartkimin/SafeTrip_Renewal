-- ============================================================
-- 12-schema-guardian-message.sql
-- Guardian 1:1 Chat Messages (Phase 2)
-- ============================================================

CREATE TABLE IF NOT EXISTS tb_guardian_message (
    message_id   BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    trip_id      UUID NOT NULL REFERENCES tb_trip(trip_id),
    link_id      UUID NOT NULL REFERENCES tb_guardian_link(link_id),
    sender_type  VARCHAR(20) NOT NULL CHECK (sender_type IN ('member','guardian')),
    sender_id    VARCHAR(128) NOT NULL REFERENCES tb_user(user_id),
    message_type VARCHAR(20) NOT NULL DEFAULT 'text'
                 CHECK (message_type IN ('text','location_card','system')),
    content      TEXT,
    card_data    JSONB,
    is_read      BOOLEAN DEFAULT FALSE,
    sent_at      TIMESTAMPTZ DEFAULT NOW(),
    created_at   TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_guardian_msg_link ON tb_guardian_message(link_id, sent_at DESC);
CREATE INDEX IF NOT EXISTS idx_guardian_msg_trip ON tb_guardian_message(trip_id);
