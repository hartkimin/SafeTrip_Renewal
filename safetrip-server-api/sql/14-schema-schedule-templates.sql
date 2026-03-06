-- ============================================================
-- SafeTrip DB Schema v3.6
-- 14: [P3] 일정 템플릿
-- ============================================================

CREATE TABLE IF NOT EXISTS tb_schedule_template (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name            VARCHAR(200) NOT NULL,
    category        VARCHAR(50),
    items           JSONB NOT NULL DEFAULT '[]',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Seed some sample templates
INSERT INTO tb_schedule_template (name, category, items) VALUES
('도쿄 3일 기본', 'japan_tokyo', '[{"title":"나리타공항 도착","schedule_type":"move","start_time":"14:00","end_time":"16:00"},{"title":"시부야 탐방","schedule_type":"sightseeing","start_time":"17:00","end_time":"20:00"},{"title":"이자카야 저녁","schedule_type":"meal","start_time":"20:00","end_time":"22:00"}]')
ON CONFLICT DO NOTHING;
