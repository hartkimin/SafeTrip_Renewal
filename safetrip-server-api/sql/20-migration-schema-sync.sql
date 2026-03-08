-- 20-migration-schema-sync.sql
-- Entity ↔ DB 스키마 정합성 마이그레이션
-- 2026-03-07: 엔티티에 정의되어 있지만 DB에 없는 컬럼/테이블 추가

BEGIN;

-- ============================================================================
-- 1. tb_user 누락 컬럼 추가
-- ============================================================================
ALTER TABLE tb_user ADD COLUMN IF NOT EXISTS avatar_id VARCHAR(30);
ALTER TABLE tb_user ADD COLUMN IF NOT EXISTS privacy_level VARCHAR(20) DEFAULT 'standard';
ALTER TABLE tb_user ADD COLUMN IF NOT EXISTS image_review_status VARCHAR(20) DEFAULT 'none';
ALTER TABLE tb_user ADD COLUMN IF NOT EXISTS onboarding_completed BOOLEAN DEFAULT FALSE;
ALTER TABLE tb_user ADD COLUMN IF NOT EXISTS deletion_reason TEXT;

-- ============================================================================
-- 2. tb_parental_consent (누락 테이블)
-- ============================================================================
CREATE TABLE IF NOT EXISTS tb_parental_consent (
    user_id VARCHAR(128) PRIMARY KEY REFERENCES tb_user(user_id),
    parent_name VARCHAR(50),
    parent_phone VARCHAR(20),
    relationship VARCHAR(20),
    consent_otp VARCHAR(10),
    is_verified BOOLEAN DEFAULT FALSE,
    verified_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- 3. tb_chat_room (누락 테이블)
-- ============================================================================
CREATE TABLE IF NOT EXISTS tb_chat_room (
    room_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id UUID REFERENCES tb_trip(trip_id),
    room_type VARCHAR(20) DEFAULT 'group',
    room_name VARCHAR(100),
    created_by VARCHAR(128),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- 4. tb_fcm_token (누락 테이블)
-- ============================================================================
CREATE TABLE IF NOT EXISTS tb_fcm_token (
    token_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id VARCHAR(128) NOT NULL REFERENCES tb_user(user_id),
    token TEXT NOT NULL,
    device_type VARCHAR(20),
    device_info JSONB,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_fcm_token_user ON tb_fcm_token(user_id);

-- ============================================================================
-- 5. tb_notification_preference (누락 테이블)
-- ============================================================================
CREATE TABLE IF NOT EXISTS tb_notification_preference (
    preference_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id VARCHAR(128) NOT NULL REFERENCES tb_user(user_id),
    notification_type VARCHAR(40) NOT NULL,
    is_enabled BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, notification_type)
);

-- ============================================================================
-- 6. tb_emergency (누락 테이블)
-- ============================================================================
CREATE TABLE IF NOT EXISTS tb_emergency (
    emergency_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id UUID REFERENCES tb_trip(trip_id),
    user_id VARCHAR(128) NOT NULL REFERENCES tb_user(user_id),
    emergency_type VARCHAR(30) NOT NULL DEFAULT 'sos',
    status VARCHAR(20) DEFAULT 'active',
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    description TEXT,
    resolved_at TIMESTAMPTZ,
    resolved_by VARCHAR(128),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- 7. tb_emergency_recipient (누락 테이블)
-- ============================================================================
CREATE TABLE IF NOT EXISTS tb_emergency_recipient (
    recipient_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    emergency_id UUID REFERENCES tb_emergency(emergency_id),
    user_id VARCHAR(128) NOT NULL,
    notified_at TIMESTAMPTZ,
    acknowledged_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- 8. tb_no_response_event (누락 테이블)
-- ============================================================================
CREATE TABLE IF NOT EXISTS tb_no_response_event (
    event_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id VARCHAR(128) NOT NULL REFERENCES tb_user(user_id),
    trip_id UUID REFERENCES tb_trip(trip_id),
    check_type VARCHAR(20) DEFAULT 'safety_checkin',
    triggered_at TIMESTAMPTZ DEFAULT NOW(),
    resolved_at TIMESTAMPTZ,
    status VARCHAR(20) DEFAULT 'pending',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- 9. tb_safety_checkin (누락 테이블)
-- ============================================================================
CREATE TABLE IF NOT EXISTS tb_safety_checkin (
    checkin_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id VARCHAR(128) NOT NULL REFERENCES tb_user(user_id),
    trip_id UUID REFERENCES tb_trip(trip_id),
    checkin_type VARCHAR(20) DEFAULT 'manual',
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    message TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- 10. tb_geofence_event (누락 테이블)
-- ============================================================================
CREATE TABLE IF NOT EXISTS tb_geofence_event (
    event_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    geofence_id UUID REFERENCES tb_geofence(geofence_id),
    user_id VARCHAR(128) NOT NULL,
    event_type VARCHAR(20) NOT NULL,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    triggered_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- 11. tb_geofence_penalty (누락 테이블)
-- ============================================================================
CREATE TABLE IF NOT EXISTS tb_geofence_penalty (
    penalty_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    geofence_event_id UUID REFERENCES tb_geofence_event(event_id),
    user_id VARCHAR(128) NOT NULL,
    penalty_type VARCHAR(30),
    penalty_amount INTEGER DEFAULT 0,
    applied_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- 12. tb_movement_session (누락 테이블)
-- ============================================================================
CREATE TABLE IF NOT EXISTS tb_movement_session (
    session_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id VARCHAR(128) NOT NULL REFERENCES tb_user(user_id),
    trip_id UUID REFERENCES tb_trip(trip_id),
    start_time TIMESTAMPTZ NOT NULL,
    end_time TIMESTAMPTZ,
    distance_meters DOUBLE PRECISION DEFAULT 0,
    duration_seconds INTEGER DEFAULT 0,
    transport_mode VARCHAR(20),
    start_latitude DOUBLE PRECISION,
    start_longitude DOUBLE PRECISION,
    end_latitude DOUBLE PRECISION,
    end_longitude DOUBLE PRECISION,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- 13. tb_redeem_code (누락 테이블)
-- ============================================================================
CREATE TABLE IF NOT EXISTS tb_redeem_code (
    code_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    code_type VARCHAR(20) DEFAULT 'promo',
    value_amount INTEGER DEFAULT 0,
    max_uses INTEGER DEFAULT 1,
    current_uses INTEGER DEFAULT 0,
    valid_from TIMESTAMPTZ DEFAULT NOW(),
    valid_until TIMESTAMPTZ,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- 14. tb_schedule_history (실패한 마이그레이션 재실행)
-- ============================================================================
CREATE TABLE IF NOT EXISTS tb_schedule_history (
    history_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    schedule_id UUID REFERENCES tb_schedule(schedule_id),
    changed_by VARCHAR(128),
    change_type VARCHAR(30),
    previous_data JSONB,
    new_data JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- 15. tb_schedule_comment (실패한 마이그레이션 재실행)
-- ============================================================================
CREATE TABLE IF NOT EXISTS tb_schedule_comment (
    comment_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    schedule_id UUID REFERENCES tb_schedule(schedule_id),
    user_id VARCHAR(128) NOT NULL,
    content TEXT NOT NULL,
    parent_comment_id UUID,
    is_deleted BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- 16. tb_schedule_reaction (실패한 마이그레이션 재실행)
-- ============================================================================
CREATE TABLE IF NOT EXISTS tb_schedule_reaction (
    reaction_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    schedule_id UUID REFERENCES tb_schedule(schedule_id),
    user_id VARCHAR(128) NOT NULL,
    reaction_type VARCHAR(20) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(schedule_id, user_id, reaction_type)
);

-- ============================================================================
-- 17. tb_ai_usage (실패한 마이그레이션 재실행 - user_id를 varchar로)
-- ============================================================================
CREATE TABLE IF NOT EXISTS tb_ai_usage (
    usage_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id VARCHAR(128) NOT NULL REFERENCES tb_user(user_id),
    feature_type VARCHAR(30) NOT NULL,
    daily_count INTEGER DEFAULT 0,
    monthly_count INTEGER DEFAULT 0,
    usage_date DATE DEFAULT CURRENT_DATE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS tb_ai_usage_log (
    log_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id VARCHAR(128) NOT NULL,
    feature_type VARCHAR(30) NOT NULL,
    input_tokens INTEGER DEFAULT 0,
    output_tokens INTEGER DEFAULT 0,
    model_name VARCHAR(50),
    cost_usd NUMERIC(10,6) DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS tb_ai_subscription (
    subscription_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id VARCHAR(128) NOT NULL REFERENCES tb_user(user_id),
    plan_type VARCHAR(20) DEFAULT 'free',
    daily_limit INTEGER DEFAULT 10,
    monthly_limit INTEGER DEFAULT 100,
    is_active BOOLEAN DEFAULT TRUE,
    started_at TIMESTAMPTZ DEFAULT NOW(),
    expires_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- 18. tb_chat_message 누락 컬럼
-- ============================================================================
ALTER TABLE tb_chat_message ADD COLUMN IF NOT EXISTS room_id UUID;
ALTER TABLE tb_chat_message ADD COLUMN IF NOT EXISTS is_deleted BOOLEAN DEFAULT FALSE;
ALTER TABLE tb_chat_message ADD COLUMN IF NOT EXISTS metadata JSONB;

-- ============================================================================
-- 19. tb_group 누락 컬럼
-- ============================================================================
ALTER TABLE tb_group ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT TRUE;
ALTER TABLE tb_group ADD COLUMN IF NOT EXISTS created_by VARCHAR(128);

-- ============================================================================
-- 20. tb_group_member 누락 컬럼
-- ============================================================================
ALTER TABLE tb_group_member ADD COLUMN IF NOT EXISTS can_manage_members BOOLEAN DEFAULT FALSE;
ALTER TABLE tb_group_member ADD COLUMN IF NOT EXISTS can_send_notifications BOOLEAN DEFAULT FALSE;
ALTER TABLE tb_group_member ADD COLUMN IF NOT EXISTS can_view_location BOOLEAN DEFAULT TRUE;
ALTER TABLE tb_group_member ADD COLUMN IF NOT EXISTS can_manage_geofences BOOLEAN DEFAULT FALSE;

-- ============================================================================
-- 21. tb_notification 누락 컬럼
-- ============================================================================
ALTER TABLE tb_notification ADD COLUMN IF NOT EXISTS notification_type VARCHAR(40);
ALTER TABLE tb_notification ADD COLUMN IF NOT EXISTS data JSONB;

-- ============================================================================
-- 22. tb_guardian_link 누락 컬럼
-- ============================================================================
ALTER TABLE tb_guardian_link ADD COLUMN IF NOT EXISTS accepted_at TIMESTAMPTZ;

-- ============================================================================
-- 23. tb_schedule 누락 컬럼 (title/description/all_day)
-- ============================================================================
ALTER TABLE tb_schedule ADD COLUMN IF NOT EXISTS title VARCHAR(200);
ALTER TABLE tb_schedule ADD COLUMN IF NOT EXISTS description TEXT;
ALTER TABLE tb_schedule ADD COLUMN IF NOT EXISTS all_day BOOLEAN DEFAULT FALSE;
-- title을 schedule_name에서 복사
UPDATE tb_schedule SET title = schedule_name WHERE title IS NULL AND schedule_name IS NOT NULL;

-- ============================================================================
-- 24. tb_location 누락 컬럼
-- ============================================================================
ALTER TABLE tb_location ADD COLUMN IF NOT EXISTS trip_id UUID;
ALTER TABLE tb_location ADD COLUMN IF NOT EXISTS group_id UUID;
ALTER TABLE tb_location ADD COLUMN IF NOT EXISTS bearing DOUBLE PRECISION;
ALTER TABLE tb_location ADD COLUMN IF NOT EXISTS is_sharing BOOLEAN DEFAULT TRUE;
ALTER TABLE tb_location ADD COLUMN IF NOT EXISTS motion_state VARCHAR(20);
ALTER TABLE tb_location ADD COLUMN IF NOT EXISTS provider VARCHAR(20);
ALTER TABLE tb_location ADD COLUMN IF NOT EXISTS server_received_at TIMESTAMPTZ;

-- ============================================================================
-- 25. tb_location_sharing 누락 컬럼
-- ============================================================================
ALTER TABLE tb_location_sharing ADD COLUMN IF NOT EXISTS visibility_member_ids JSONB;
ALTER TABLE tb_location_sharing ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT TRUE;

-- ============================================================================
-- 26. tb_trip_card_view 뷰 생성
-- ============================================================================
CREATE OR REPLACE VIEW tb_trip_card_view AS
SELECT
    t.trip_id,
    t.trip_name,
    t.status,
    t.start_date,
    t.end_date,
    t.end_date - t.start_date                          AS trip_days,
    t.privacy_level,
    t.sharing_mode,
    t.schedule_type,
    t.country_code,
    t.country_name,
    t.destination_city,
    t.has_minor_members,
    t.reactivated_at,
    t.reactivation_count,
    t.group_id,
    t.updated_at,
    CASE
        WHEN t.status = 'active'    THEN 0
        WHEN t.status = 'planning'  THEN (t.start_date - CURRENT_DATE)
        ELSE NULL
    END                                                 AS d_day,
    CASE
        WHEN t.status = 'active'
            THEN (CURRENT_DATE - t.start_date + 1)
        ELSE NULL
    END                                                 AS current_day,
    (
        SELECT COUNT(*)
        FROM tb_group_member gm
        WHERE gm.trip_id = t.trip_id
          AND gm.status = 'active'
          AND gm.member_role IN ('captain', 'crew_chief', 'crew')
    )                                                   AS member_count,
    CASE
        WHEN t.status = 'completed'
         AND t.reactivation_count = 0
         AND t.updated_at > NOW() - INTERVAL '24 hours'
            THEN TRUE
        ELSE FALSE
    END                                                 AS can_reactivate
FROM tb_trip t
WHERE t.deleted_at IS NULL;

COMMIT;
