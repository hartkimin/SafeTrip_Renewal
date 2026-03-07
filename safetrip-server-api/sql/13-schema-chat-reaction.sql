-- ============================================================
-- SafeTrip DB Schema — Phase 3: Reactions + Full-Text Search
-- 기준: DOC-T3-CHT-020 §9 (리액션), §7 (메시지 검색)
-- ============================================================

-- pg_trgm 확장 (ILIKE 고속 검색용)
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- 4.27 TB_CHAT_REACTION (채팅 리액션)
CREATE TABLE IF NOT EXISTS tb_chat_reaction (
    reaction_id  BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    message_id   BIGINT NOT NULL REFERENCES tb_chat_message(message_id) ON DELETE CASCADE,
    user_id      VARCHAR(128) NOT NULL REFERENCES tb_user(user_id) ON DELETE CASCADE,
    emoji        VARCHAR(10) NOT NULL,
    created_at   TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(message_id, user_id, emoji)
);

-- Full-text trigram index on chat message content
CREATE INDEX IF NOT EXISTS idx_chat_message_content_trgm
    ON tb_chat_message USING gin (content gin_trgm_ops)
    WHERE content IS NOT NULL AND deleted_by IS NULL;
