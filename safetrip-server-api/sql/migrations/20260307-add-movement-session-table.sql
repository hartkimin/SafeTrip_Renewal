-- 20260307-add-movement-session-table.sql
-- TB_MOVEMENT_SESSION 테이블 생성 (엔티티는 존재하나 DDL 누락)

CREATE TABLE IF NOT EXISTS tb_movement_session (
    session_id      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         VARCHAR(128) NOT NULL REFERENCES tb_user(user_id) ON DELETE CASCADE,
    start_time      TIMESTAMPTZ,
    end_time        TIMESTAMPTZ,
    is_completed    BOOLEAN DEFAULT FALSE,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_movement_session_user ON tb_movement_session(user_id);
CREATE INDEX IF NOT EXISTS idx_movement_session_start ON tb_movement_session(start_time DESC);

-- tb_location.movement_session_id에 FK 추가 (IF NOT EXISTS 패턴)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE constraint_name = 'fk_location_movement_session'
    ) THEN
        ALTER TABLE tb_location
            ADD CONSTRAINT fk_location_movement_session
            FOREIGN KEY (movement_session_id) REFERENCES tb_movement_session(session_id)
            ON DELETE SET NULL;
    END IF;
END $$;
