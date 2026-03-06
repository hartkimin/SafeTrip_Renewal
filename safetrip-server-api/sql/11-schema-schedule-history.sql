-- ============================================================
-- SafeTrip DB Schema v3.6
-- 11: [D] 일정 수정 이력 (일정탭 원칙 §8.2)
-- ============================================================

CREATE TABLE IF NOT EXISTS tb_schedule_history (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    schedule_id     UUID NOT NULL,
    modified_by     VARCHAR(128) NOT NULL REFERENCES tb_user(user_id),
    field_name      VARCHAR(50) NOT NULL,
    old_value       TEXT,
    new_value       TEXT,
    modified_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_schedule_history_schedule ON tb_schedule_history(schedule_id);
CREATE INDEX IF NOT EXISTS idx_schedule_history_modified ON tb_schedule_history(modified_at);
