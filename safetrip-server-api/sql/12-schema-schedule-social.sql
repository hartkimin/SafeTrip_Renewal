-- ============================================================
-- SafeTrip DB Schema v3.6
-- 12: [P3] 일정 소셜 기능 (댓글, 리액션)
-- ============================================================

CREATE TABLE IF NOT EXISTS tb_schedule_comment (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    schedule_id     UUID NOT NULL REFERENCES tb_travel_schedule(travel_schedule_id) ON DELETE CASCADE,
    user_id         VARCHAR(128) NOT NULL REFERENCES tb_user(user_id),
    content         TEXT NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at      TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_schedule_comment_schedule ON tb_schedule_comment(schedule_id);

CREATE TABLE IF NOT EXISTS tb_schedule_reaction (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    schedule_id     UUID NOT NULL REFERENCES tb_travel_schedule(travel_schedule_id) ON DELETE CASCADE,
    user_id         VARCHAR(128) NOT NULL REFERENCES tb_user(user_id),
    emoji           VARCHAR(10) NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_schedule_reaction UNIQUE(schedule_id, user_id, emoji)
);

CREATE INDEX IF NOT EXISTS idx_schedule_reaction_schedule ON tb_schedule_reaction(schedule_id);
