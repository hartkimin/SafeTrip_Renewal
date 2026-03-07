-- ============================================================
-- SafeTrip DB Schema v3.6
-- 13: [P3] 일정 투표 시스템
-- ============================================================

CREATE TABLE IF NOT EXISTS tb_schedule_vote (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id         UUID NOT NULL REFERENCES tb_trip(trip_id) ON DELETE CASCADE,
    title           VARCHAR(200) NOT NULL,
    created_by      VARCHAR(128) NOT NULL REFERENCES tb_user(user_id),
    status          VARCHAR(20) NOT NULL DEFAULT 'open',
    deadline        TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_schedule_vote_trip ON tb_schedule_vote(trip_id);

CREATE TABLE IF NOT EXISTS tb_schedule_vote_option (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vote_id         UUID NOT NULL REFERENCES tb_schedule_vote(id) ON DELETE CASCADE,
    label           VARCHAR(200) NOT NULL,
    schedule_data   JSONB
);

CREATE TABLE IF NOT EXISTS tb_schedule_vote_response (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vote_id         UUID NOT NULL REFERENCES tb_schedule_vote(id) ON DELETE CASCADE,
    option_id       UUID NOT NULL REFERENCES tb_schedule_vote_option(id) ON DELETE CASCADE,
    user_id         VARCHAR(128) NOT NULL REFERENCES tb_user(user_id),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_vote_response UNIQUE(vote_id, user_id)
);
