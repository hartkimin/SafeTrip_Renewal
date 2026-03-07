-- ============================================================
-- SafeTrip DB Schema v3.6
-- 15: [N] AI 도메인 (2 tables)
-- 기준 문서: 26_T3_AI_기능_원칙_v1.1 §12
-- ============================================================

-- §12.1 TB_AI_USAGE_LOG (AI 사용 이력 — 건별 로그)
CREATE TABLE IF NOT EXISTS tb_ai_usage_log (
    log_id          UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id         UUID REFERENCES tb_user(user_id) ON DELETE SET NULL,
    trip_id         UUID REFERENCES tb_trip(trip_id) ON DELETE SET NULL,
    ai_type         VARCHAR(20) NOT NULL
                    CHECK (ai_type IN ('safety', 'convenience', 'intelligence')),
    feature_name    VARCHAR(50) NOT NULL,
    model_used      VARCHAR(50),
    is_cached       BOOLEAN DEFAULT FALSE,
    is_fallback     BOOLEAN DEFAULT FALSE,
    fallback_reason VARCHAR(100),
    latency_ms      INTEGER,
    is_minor_user   BOOLEAN DEFAULT FALSE,
    privacy_level   VARCHAR(20),
    feedback        SMALLINT CHECK (feedback IN (-1, 0, 1)),
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    expires_at      TIMESTAMPTZ
);

CREATE INDEX idx_ai_usage_log_user    ON tb_ai_usage_log (user_id);
CREATE INDEX idx_ai_usage_log_trip    ON tb_ai_usage_log (trip_id);
CREATE INDEX idx_ai_usage_log_type    ON tb_ai_usage_log (ai_type, feature_name);
CREATE INDEX idx_ai_usage_log_expires ON tb_ai_usage_log (expires_at);

-- §12.2 TB_AI_SUBSCRIPTION (AI 구독 정보)
CREATE TABLE IF NOT EXISTS tb_ai_subscription (
    subscription_id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id         UUID NOT NULL REFERENCES tb_user(user_id) ON DELETE CASCADE,
    plan_type       VARCHAR(20) NOT NULL
                    CHECK (plan_type IN ('ai_plus', 'ai_pro')),
    billing_cycle   VARCHAR(10) NOT NULL
                    CHECK (billing_cycle IN ('monthly', 'per_trip')),
    trip_id         UUID REFERENCES tb_trip(trip_id) ON DELETE SET NULL,
    status          VARCHAR(20) DEFAULT 'active'
                    CHECK (status IN ('active', 'cancelled', 'expired', 'grace_period')),
    started_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at      TIMESTAMPTZ NOT NULL,
    grace_until     TIMESTAMPTZ,
    payment_id      UUID REFERENCES tb_payment(payment_id) ON DELETE SET NULL,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_ai_subscription_user   ON tb_ai_subscription (user_id);
CREATE INDEX idx_ai_subscription_status ON tb_ai_subscription (status, expires_at);
CREATE INDEX idx_ai_subscription_trip   ON tb_ai_subscription (trip_id)
    WHERE trip_id IS NOT NULL;

CREATE UNIQUE INDEX idx_ai_subscription_active_monthly
    ON tb_ai_subscription (user_id, plan_type)
    WHERE billing_cycle = 'monthly' AND status IN ('active', 'grace_period');
