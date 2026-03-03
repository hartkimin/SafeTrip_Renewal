-- ============================================================================
-- SafeTrip Database Schema
-- PostgreSQL 14+ with PostGIS Extension
-- Version: 1.0
-- Created: 2024-03-15
-- ============================================================================

-- ============================================================================
-- Extensions
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "postgis";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";  -- For text search

-- ============================================================================
-- 1. CORE TABLES (핵심 테이블)
-- ============================================================================

-- 1.1 Users (사용자)
-- 사용자 계정 및 프로필 정보
CREATE TABLE TB_USER (
    -- 기본 정보
    user_id VARCHAR(128) PRIMARY KEY NOT NULL,
    phone_number VARCHAR(20) NOT NULL,
    phone_country_code VARCHAR(5) NOT NULL,

    -- 프로필
    display_name VARCHAR(100),
    profile_image_url TEXT,
    date_of_birth VARCHAR(8),

    -- 인증
    last_verification_at TIMESTAMPTZ,
    -- Note: is_phone_verified는 Firebase Auth에서 관리됨

    -- 설정
    language VARCHAR(10) DEFAULT 'ko',
    timezone VARCHAR(50) DEFAULT 'Asia/Seoul',

    -- 알림 설정
    notification_enabled BOOLEAN DEFAULT TRUE,
    push_enabled BOOLEAN DEFAULT TRUE,
    sms_enabled BOOLEAN DEFAULT TRUE,
    email_enabled BOOLEAN DEFAULT TRUE,

    -- 프라이버시 설정
    location_sharing_mode VARCHAR(20) DEFAULT 'normal',
    -- Note: location_sharing_enabled, geofencing_enabled는 Firebase Realtime Database에 저장됨

    -- 메타데이터
    created_at TIMESTAMPTZ DEFAULT (now() AT TIME ZONE 'UTC'),
    updated_at TIMESTAMPTZ DEFAULT (now() AT TIME ZONE 'UTC'),
    last_login_at TIMESTAMPTZ,
    last_active_at TIMESTAMPTZ,
    deleted_at TIMESTAMPTZ,
    app_check_token_last_verified_at TIMESTAMP,
    -- Note: last_mqtt_received_at, mqtt_client_id, last_location_*, battery_level,
    --       last_geofence_*, last_activity_type, app_version, last_battery_is_charging,
    --       stationary_geofence_*, mock_detected_at는 Firebase Realtime Database에 저장됨

    -- 제약조건
    CONSTRAINT chk_phone_format CHECK (phone_number ~ '^\+?[0-9]{10,15}$')
);

CREATE INDEX idx_users_phone ON TB_USER(phone_number);
CREATE INDEX idx_users_created_at ON TB_USER(created_at);

COMMENT ON TABLE TB_USER IS '사용자 계정 및 프로필 정보';
COMMENT ON COLUMN TB_USER.user_id IS 'Firebase Auth UID (VARCHAR(128))';
COMMENT ON COLUMN TB_USER.phone_number IS 'Phone number (login ID, E.164 format recommended, can be duplicated for different users)';
COMMENT ON COLUMN TB_USER.last_verification_at IS '마지막 인증 시각 (Firebase Auth 인증 시각)';
COMMENT ON COLUMN TB_USER.location_sharing_mode IS 'normal, privacy, minimal';
COMMENT ON COLUMN TB_USER.app_check_token_last_verified_at IS 'App Check 토큰 마지막 검증 시각';


-- 1.2 Trips (여행)
-- 개별 여행 컨텍스트
CREATE TABLE TB_TRIP (
    -- 기본 정보
    trip_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- 여행 정보
    country_code VARCHAR(3) NOT NULL,
    country_name VARCHAR(100) NOT NULL,
    destination_city VARCHAR(100),

    -- 기간
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,

    -- 여행 유형
    trip_type VARCHAR(20) NOT NULL,

    -- 상태
    status VARCHAR(20) DEFAULT 'active',

    -- 결제 정보
    plan_type VARCHAR(20),
    plan_start_at TIMESTAMP,
    plan_end_at TIMESTAMP,
    billing_status VARCHAR(20) DEFAULT 'trial',

    -- 메타데이터
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP,

    -- 그룹 연결
    group_id UUID REFERENCES TB_GROUP(group_id) ON DELETE SET NULL,

    -- 제약조건
    CONSTRAINT chk_trip_dates CHECK (end_date >= start_date),
    CONSTRAINT chk_trip_type CHECK (trip_type IN ('personal', 'group'))
);

CREATE INDEX idx_trips_status ON TB_TRIP(status);
CREATE INDEX idx_trips_dates ON TB_TRIP(start_date, end_date);
CREATE INDEX idx_trips_country ON TB_TRIP(country_code);
CREATE INDEX idx_trips_group_id ON TB_TRIP(group_id);

COMMENT ON TABLE TB_TRIP IS '개별 여행 컨텍스트';
COMMENT ON COLUMN TB_TRIP.trip_type IS 'personal, group';
COMMENT ON COLUMN TB_TRIP.status IS 'active, completed, cancelled';
COMMENT ON COLUMN TB_TRIP.billing_status IS 'trial, active, grace, locked';


-- 1.3 Groups (그룹)
-- 그룹 여행 정보
CREATE TABLE TB_GROUP (
    -- 기본 정보
    group_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- 그룹 정보
    group_name VARCHAR(100) NOT NULL,
    group_description TEXT,
    group_type VARCHAR(20) DEFAULT 'standard',

    -- 초대 코드
    invite_code VARCHAR(8) UNIQUE NOT NULL,
    invite_link TEXT,

    -- 크기 제한
    max_members INTEGER DEFAULT 100,
    current_member_count INTEGER DEFAULT 0,

    -- 관리자
    owner_user_id VARCHAR(128) REFERENCES TB_USER(user_id),

    -- 상태
    status VARCHAR(20) DEFAULT 'active',

    -- 메타데이터
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP,

    CONSTRAINT chk_member_count CHECK (current_member_count <= max_members)
);

CREATE INDEX idx_groups_invite_code ON TB_GROUP(invite_code);
CREATE INDEX idx_groups_owner ON TB_GROUP(owner_user_id);
CREATE INDEX idx_groups_status ON TB_GROUP(status);

COMMENT ON TABLE TB_GROUP IS '그룹 여행 정보';
COMMENT ON COLUMN TB_GROUP.group_type IS 'standard, school, agency';


-- 1.4 Group_Members (그룹 멤버)
-- 그룹 참여자 관리
CREATE TABLE TB_GROUP_MEMBER (
    -- 기본 정보
    member_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id UUID NOT NULL REFERENCES TB_GROUP(group_id) ON DELETE CASCADE,
    user_id VARCHAR(128) NOT NULL REFERENCES TB_USER(user_id) ON DELETE CASCADE,

    -- 권한
    is_admin BOOLEAN DEFAULT FALSE,
    can_edit_schedule BOOLEAN DEFAULT FALSE,
    can_edit_geofence BOOLEAN DEFAULT FALSE,
    can_view_all_locations BOOLEAN DEFAULT TRUE,
    can_attendance_check BOOLEAN DEFAULT TRUE,

    -- 역할 (captain/crew_chief/crew/guardian)
    member_role VARCHAR(20) DEFAULT 'crew'
        CHECK (member_role IN ('captain', 'crew_chief', 'crew', 'guardian')),

    -- 보호자 역할
    is_guardian BOOLEAN DEFAULT FALSE NOT NULL,
    traveler_user_id VARCHAR(128) REFERENCES TB_USER(user_id) ON DELETE CASCADE,

    -- 상태
    status VARCHAR(20) DEFAULT 'active',

    -- 메타데이터
    joined_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    left_at TIMESTAMPTZ,

    -- 제약조건
    UNIQUE(group_id, user_id)
);

CREATE INDEX idx_group_members_group ON TB_GROUP_MEMBER(group_id);
CREATE INDEX idx_group_members_user ON TB_GROUP_MEMBER(user_id);
CREATE INDEX idx_group_members_is_admin ON TB_GROUP_MEMBER(is_admin);
CREATE INDEX idx_group_members_is_guardian ON TB_GROUP_MEMBER(is_guardian) WHERE is_guardian = TRUE;
CREATE INDEX idx_group_members_traveler ON TB_GROUP_MEMBER(traveler_user_id) WHERE traveler_user_id IS NOT NULL;

COMMENT ON TABLE TB_GROUP_MEMBER IS '그룹 참여자 관리';
COMMENT ON COLUMN TB_GROUP_MEMBER.member_role IS '역할: captain(그룹장), crew_chief(공동관리자), crew(일반멤버), guardian(모니터링전용)';
COMMENT ON COLUMN TB_GROUP_MEMBER.is_admin IS '관리자 여부';
COMMENT ON COLUMN TB_GROUP_MEMBER.can_edit_schedule IS '일정 편집 가능 여부';
COMMENT ON COLUMN TB_GROUP_MEMBER.can_edit_geofence IS '지오펜스 편집 가능 여부';
COMMENT ON COLUMN TB_GROUP_MEMBER.can_view_all_locations IS '전체 위치 조회 권한';
COMMENT ON COLUMN TB_GROUP_MEMBER.can_attendance_check IS '출석체크 가능 여부 (FALSE면 출석체크 푸시를 받지 않음)';
COMMENT ON COLUMN TB_GROUP_MEMBER.is_guardian IS '보호자 역할 여부 (그룹 멤버 중 보호자 식별, member_role=guardian과 연동)';
COMMENT ON COLUMN TB_GROUP_MEMBER.traveler_user_id IS '보호자가 모니터링하는 여행자 ID (NULL이면 그룹 전체 모니터링, is_guardian=true일 때만 의미 있음)';


-- 1.5 Guardians (보호자)
-- 보호자 관계 관리
CREATE TABLE TB_GUARDIAN (
    -- 기본 정보
    guardian_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- 관계
    traveler_user_id VARCHAR(128) NOT NULL REFERENCES TB_USER(user_id) ON DELETE CASCADE,
    guardian_user_id VARCHAR(128) REFERENCES TB_USER(user_id) ON DELETE CASCADE,
    trip_id UUID REFERENCES TB_TRIP(trip_id) ON DELETE CASCADE,

    -- 보호자 유형
    guardian_type VARCHAR(20) DEFAULT 'primary',

    -- 권한
    can_view_location BOOLEAN DEFAULT TRUE,
    can_request_checkin BOOLEAN DEFAULT TRUE,
    can_receive_sos BOOLEAN DEFAULT TRUE,

    -- 초대 정보
    invite_status VARCHAR(20) DEFAULT 'pending',
    invited_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    accepted_at TIMESTAMP,
    
    -- 보호자 초대 코드 (보호자가 참여할 때 사용)
    guardian_invite_code VARCHAR(8) UNIQUE,
    
    -- 보호자 전화번호 (여행자가 입력한 번호, 보호자 인증 시 확인용)
    guardian_phone VARCHAR(20),

    -- 메타데이터
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP,

    -- 제약조건
    UNIQUE(traveler_user_id, guardian_user_id, trip_id)
);

CREATE INDEX idx_guardians_traveler ON TB_GUARDIAN(traveler_user_id);
CREATE INDEX idx_guardians_guardian ON TB_GUARDIAN(guardian_user_id);
CREATE INDEX idx_guardians_trip ON TB_GUARDIAN(trip_id);
CREATE INDEX idx_guardians_invite_code ON TB_GUARDIAN(guardian_invite_code);

COMMENT ON TABLE TB_GUARDIAN IS '보호자 관계 관리';
COMMENT ON COLUMN TB_GUARDIAN.guardian_type IS 'primary, secondary, temporary';
COMMENT ON COLUMN TB_GUARDIAN.guardian_invite_code IS '보호자 초대 코드 (6-8자리 영숫자)';
COMMENT ON COLUMN TB_GUARDIAN.guardian_phone IS '보호자 전화번호 (여행자가 입력한 번호, E.164 형식)';


-- ============================================================================
-- 2. LOCATION & SAFETY TABLES (위치 및 안전 관련 테이블)
-- ============================================================================

-- 2.1 Locations (위치 기록)
-- 실시간 위치 추적 및 이력
CREATE TABLE TB_LOCATION (
    -- 기본 정보
    location_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id VARCHAR(128) NOT NULL REFERENCES TB_USER(user_id) ON DELETE CASCADE,
    -- Note: trip_id는 제거됨 (user_id 기반으로 관리)

    -- 좌표
    latitude DECIMAL(10, 8) NOT NULL,
    longitude DECIMAL(11, 8) NOT NULL,
    accuracy DECIMAL(6, 2),
    altitude DECIMAL(8, 2),

    -- PostGIS 지원
    geom GEOGRAPHY(POINT, 4326),

    -- 주소 정보 (Reverse Geocoding)
    address TEXT,
    city VARCHAR(100),
    country VARCHAR(100),

    -- 이동 정보
    speed DECIMAL(6, 2),
    heading DECIMAL(5, 2),

    -- 디바이스 상태
    battery_level INTEGER,
    network_type VARCHAR(20),

    -- 추적 모드
    tracking_mode VARCHAR(20) DEFAULT 'normal',

    -- 이동 세션 정보
    movement_session_id UUID,
    is_movement_start BOOLEAN DEFAULT FALSE,
    is_movement_end BOOLEAN DEFAULT FALSE,

    -- Activity Recognition
    activity_type VARCHAR(20),
    activity_confidence INTEGER,

    -- 사용자별 순차 인덱스 (자동 증가)
    i_idx BIGINT,

    -- 메타데이터
    recorded_at TIMESTAMPTZ NOT NULL DEFAULT (now() AT TIME ZONE 'UTC'),
    synced_at TIMESTAMPTZ,
    is_offline BOOLEAN DEFAULT FALSE,

    -- 제약조건
    CONSTRAINT chk_latitude CHECK (latitude BETWEEN -90 AND 90),
    CONSTRAINT chk_longitude CHECK (longitude BETWEEN -180 AND 180),
    CONSTRAINT chk_battery CHECK (battery_level BETWEEN 0 AND 100)
);

-- PostGIS 인덱스 (공간 쿼리 최적화)
CREATE INDEX idx_locations_geom ON TB_LOCATION USING GIST(geom);
CREATE INDEX idx_locations_user_id ON TB_LOCATION(user_id);
CREATE INDEX idx_locations_recorded_at ON TB_LOCATION(recorded_at DESC);
CREATE INDEX idx_locations_coords ON TB_LOCATION(latitude, longitude);
CREATE INDEX idx_locations_movement_session ON TB_LOCATION(movement_session_id) WHERE movement_session_id IS NOT NULL;
CREATE INDEX idx_locations_movement_session_user ON TB_LOCATION(user_id, movement_session_id, recorded_at) WHERE movement_session_id IS NOT NULL;
CREATE INDEX idx_locations_movement_start ON TB_LOCATION(user_id, is_movement_start) WHERE is_movement_start = TRUE;
CREATE INDEX idx_locations_movement_end ON TB_LOCATION(user_id, is_movement_end) WHERE is_movement_end = TRUE;
CREATE INDEX idx_locations_user_idx ON TB_LOCATION(user_id, i_idx);

COMMENT ON TABLE TB_LOCATION IS '실시간 위치 추적 및 이력 (user_id 기반, trip_id 제거)';
COMMENT ON COLUMN TB_LOCATION.tracking_mode IS 'normal, power_saving, minimal, sos';
COMMENT ON COLUMN TB_LOCATION.movement_session_id IS '이동 세션 ID (같은 이동 구간의 위치들을 그룹화)';
COMMENT ON COLUMN TB_LOCATION.is_movement_start IS '이동 시작 여부 (정지 → 이동 전환 시 TRUE)';
COMMENT ON COLUMN TB_LOCATION.is_movement_end IS '이동 종료 여부 (이동 → 정지 전환 시 TRUE, 5분 이상 정지 후 확정)';
COMMENT ON COLUMN TB_LOCATION.activity_type IS 'Activity Recognition: still, walking, running, on_bicycle, in_vehicle, unknown';
COMMENT ON COLUMN TB_LOCATION.activity_confidence IS 'Activity Recognition 신뢰도 (0-100)';
COMMENT ON COLUMN TB_LOCATION.i_idx IS 'User별 순차 인덱스 (자동 증가, 삽입 순서 보장)';


-- 2.2 SOS_Alerts (긴급 알림)
-- SOS 긴급 상황 기록
CREATE TABLE TB_SOS_ALERT (
    -- 기본 정보
    sos_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id VARCHAR(128) NOT NULL REFERENCES TB_USER(user_id) ON DELETE CASCADE,
    trip_id UUID REFERENCES TB_TRIP(trip_id) ON DELETE CASCADE,
    location_id UUID REFERENCES TB_LOCATION(location_id),

    -- SOS 유형
    alert_type VARCHAR(20) NOT NULL,

    -- 트리거 방식
    trigger_method VARCHAR(20) NOT NULL,

    -- 위치 (스냅샷)
    latitude DECIMAL(10, 8),
    longitude DECIMAL(11, 8),
    address TEXT,

    -- 메시지
    user_message TEXT,

    -- 상태
    status VARCHAR(20) DEFAULT 'sent',

    -- 에스컬레이션
    escalation_level INTEGER DEFAULT 1,

    -- 응답 정보
    first_response_at TIMESTAMP,
    first_responder_user_id VARCHAR(128) REFERENCES TB_USER(user_id),
    resolved_at TIMESTAMP,

    -- 증거 수집
    has_video BOOLEAN DEFAULT FALSE,
    has_audio BOOLEAN DEFAULT FALSE,
    video_url TEXT,
    audio_url TEXT,

    -- 취소 정보
    is_cancelled BOOLEAN DEFAULT FALSE,
    cancelled_at TIMESTAMP,
    cancellation_reason TEXT,

    -- 메타데이터
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_sos_user_id ON TB_SOS_ALERT(user_id);
CREATE INDEX idx_sos_trip_id ON TB_SOS_ALERT(trip_id);
CREATE INDEX idx_sos_status ON TB_SOS_ALERT(status);
CREATE INDEX idx_sos_created_at ON TB_SOS_ALERT(created_at DESC);

COMMENT ON TABLE TB_SOS_ALERT IS 'SOS 긴급 상황 기록';
COMMENT ON COLUMN TB_SOS_ALERT.alert_type IS 'emergency, crime, medical, embassy, local_help';
COMMENT ON COLUMN TB_SOS_ALERT.trigger_method IS 'manual, auto_impact, auto_inactivity, voice, gesture';
COMMENT ON COLUMN TB_SOS_ALERT.status IS 'sent, acknowledged, resolved, cancelled, false_alarm';


-- 2.3 SOS_Recipients (SOS 수신자)
-- SOS 알림 전송 및 응답 추적
CREATE TABLE TB_SOS_RECIPIENT (
    -- 기본 정보
    recipient_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sos_id UUID NOT NULL REFERENCES TB_SOS_ALERT(sos_id) ON DELETE CASCADE,
    recipient_user_id VARCHAR(128) NOT NULL REFERENCES TB_USER(user_id),

    -- 수신자 유형
    recipient_type VARCHAR(20) NOT NULL,

    -- 전송 채널
    channels JSONB,

    -- 전송 상태
    push_status VARCHAR(20),
    sms_status VARCHAR(20),
    email_status VARCHAR(20),

    -- 응답
    is_acknowledged BOOLEAN DEFAULT FALSE,
    acknowledged_at TIMESTAMP,
    response_message TEXT,

    -- 메타데이터
    sent_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_sos_recipients_sos ON TB_SOS_RECIPIENT(sos_id);
CREATE INDEX idx_sos_recipients_user ON TB_SOS_RECIPIENT(recipient_user_id);

COMMENT ON TABLE TB_SOS_RECIPIENT IS 'SOS 알림 전송 및 응답 추적';
COMMENT ON COLUMN TB_SOS_RECIPIENT.recipient_type IS 'guardian, group_member, emergency_contact';


-- 2.4 Geofences (지오펜스)
-- 안전/주의/위험 구역 설정
CREATE TABLE TB_GEOFENCE (
    geofence_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id UUID REFERENCES TB_TRIP(trip_id) ON DELETE CASCADE,
    group_id UUID REFERENCES TB_GROUP(group_id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    type VARCHAR(20) NOT NULL,
    shape_type VARCHAR(20) NOT NULL,
    center_latitude DECIMAL(10, 8),
    center_longitude DECIMAL(11, 8),
    radius_meters INTEGER,
    polygon_geom GEOGRAPHY(POLYGON, 4326),
    polygon_coordinates JSONB,
    is_always_active BOOLEAN DEFAULT FALSE,
    valid_from TIMESTAMPTZ,
    valid_until TIMESTAMPTZ,
    trigger_on_enter BOOLEAN DEFAULT TRUE,
    trigger_on_exit BOOLEAN DEFAULT TRUE,
    dwell_time_seconds INTEGER DEFAULT 60,
    notify_group BOOLEAN DEFAULT FALSE,
    notify_guardians BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_geofences_group ON TB_GEOFENCE(group_id);
CREATE INDEX idx_geofences_valid_time ON TB_GEOFENCE(valid_from, valid_until);

COMMENT ON TABLE TB_GEOFENCE IS '안전/주의/위험 구역 설정';


-- 2.5 Geofence_Events (지오펜스 이벤트)
-- 지오펜스 진입/이탈 기록
-- TB_GEOFENCE_EVENT 테이블은 TB_EVENT_LOG로 통합되어 삭제됨
-- 기존 데이터 마이그레이션이 필요한 경우 별도 스크립트 실행
-- DROP TABLE IF EXISTS TB_GEOFENCE_EVENT CASCADE;


-- 2.6 Safety_Checkins (안전 체크인)
-- 사용자 안전 상태 확인
CREATE TABLE TB_SAFETY_CHECKIN (
    -- 기본 정보
    checkin_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id VARCHAR(128) NOT NULL REFERENCES TB_USER(user_id) ON DELETE CASCADE,
    trip_id UUID REFERENCES TB_TRIP(trip_id) ON DELETE CASCADE,
    location_id UUID REFERENCES TB_LOCATION(location_id),

    -- 체크인 유형
    checkin_type VARCHAR(20) NOT NULL,

    -- 위치 (스냅샷)
    latitude DECIMAL(10, 8),
    longitude DECIMAL(11, 8),
    address TEXT,

    -- 상태
    status VARCHAR(20) DEFAULT 'safe',
    message TEXT,

    -- 디바이스 상태
    battery_level INTEGER,
    network_type VARCHAR(20),

    -- 요청자 정보 (보호자 요청 시)
    requested_by_user_id VARCHAR(128) REFERENCES TB_USER(user_id),
    requested_at TIMESTAMP,

    -- 공유 범위
    visibility VARCHAR(20) DEFAULT 'all',

    -- 메타데이터
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_safety_checkins_user ON TB_SAFETY_CHECKIN(user_id);
CREATE INDEX idx_safety_checkins_trip ON TB_SAFETY_CHECKIN(trip_id);
CREATE INDEX idx_safety_checkins_created ON TB_SAFETY_CHECKIN(created_at DESC);

COMMENT ON TABLE TB_SAFETY_CHECKIN IS '사용자 안전 상태 확인';
COMMENT ON COLUMN TB_SAFETY_CHECKIN.checkin_type IS 'manual, guardian_request, scheduled, auto';
COMMENT ON COLUMN TB_SAFETY_CHECKIN.status IS 'safe, need_help, no_response';
COMMENT ON COLUMN TB_SAFETY_CHECKIN.visibility IS 'private, guardians, group, all';


-- ============================================================================
-- 3. COMMUNICATION & ACTIVITY TABLES (소통 및 활동 관련 테이블)
-- ============================================================================

-- 3.1 Group_Messages (그룹 채팅)
-- 그룹 채팅 메시지
CREATE TABLE TB_GROUP_MESSAGE (
    -- 기본 정보
    message_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id UUID NOT NULL REFERENCES TB_GROUP(group_id) ON DELETE CASCADE,
    sender_user_id VARCHAR(128) NOT NULL REFERENCES TB_USER(user_id) ON DELETE CASCADE,

    -- 메시지 내용
    message_type VARCHAR(20) DEFAULT 'text',
    message_text TEXT,

    -- 미디어
    media_url TEXT,
    media_type VARCHAR(20),

    -- 위치 공유 (메시지 내)
    shared_location_id UUID REFERENCES TB_LOCATION(location_id),
    latitude DECIMAL(10, 8),
    longitude DECIMAL(11, 8),

    -- 답장
    reply_to_message_id UUID REFERENCES TB_GROUP_MESSAGE(message_id),

    -- 상태
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMP,

    -- 메타데이터
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_group_messages_group ON TB_GROUP_MESSAGE(group_id, created_at DESC);
CREATE INDEX idx_group_messages_sender ON TB_GROUP_MESSAGE(sender_user_id);

COMMENT ON TABLE TB_GROUP_MESSAGE IS '그룹 채팅 메시지';
COMMENT ON COLUMN TB_GROUP_MESSAGE.message_type IS 'text, image, location, system';


-- 3.2 Message_Reads (메시지 읽음 상태)
-- 그룹 메시지 읽음 추적
CREATE TABLE TB_MESSAGE_READ (
    -- 기본 정보
    read_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    message_id UUID NOT NULL REFERENCES TB_GROUP_MESSAGE(message_id) ON DELETE CASCADE,
    user_id VARCHAR(128) NOT NULL REFERENCES TB_USER(user_id) ON DELETE CASCADE,

    -- 읽음 정보
    read_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    -- 제약조건
    UNIQUE(message_id, user_id)
);

CREATE INDEX idx_message_reads_message ON TB_MESSAGE_READ(message_id);
CREATE INDEX idx_message_reads_user ON TB_MESSAGE_READ(user_id);

COMMENT ON TABLE TB_MESSAGE_READ IS '그룹 메시지 읽음 추적';


-- 3.3 Group_Announcements (그룹 공지)
-- 관리자 공지사항
CREATE TABLE TB_GROUP_NOTICE (
    -- 기본 정보
    notice_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id UUID NOT NULL REFERENCES TB_GROUP(group_id) ON DELETE CASCADE,
    author_user_id VARCHAR(128) NOT NULL REFERENCES TB_USER(user_id) ON DELETE CASCADE,

    -- 공지 내용
    title VARCHAR(200) NOT NULL,
    content TEXT NOT NULL,

    -- 우선순위
    priority VARCHAR(20) DEFAULT 'normal',

    -- 확인 요청
    requires_acknowledgement BOOLEAN DEFAULT FALSE,

    -- 상태
    is_pinned BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,

    -- 메타데이터
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP
);

CREATE INDEX idx_notices_group ON TB_GROUP_NOTICE(group_id, created_at DESC);
CREATE INDEX idx_notices_priority ON TB_GROUP_NOTICE(priority);

COMMENT ON TABLE TB_GROUP_NOTICE IS '관리자 공지사항';
COMMENT ON COLUMN TB_GROUP_NOTICE.priority IS 'urgent, high, normal, low';


-- 3.4 Announcement_Reads (공지 확인)
-- 공지사항 확인 추적
CREATE TABLE TB_NOTICE_READ (
    -- 기본 정보
    read_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    notice_id UUID NOT NULL REFERENCES TB_GROUP_NOTICE(notice_id) ON DELETE CASCADE,
    user_id VARCHAR(128) NOT NULL REFERENCES TB_USER(user_id) ON DELETE CASCADE,

    -- 확인 정보
    acknowledged BOOLEAN DEFAULT TRUE,
    acknowledged_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    -- 제약조건
    UNIQUE(notice_id, user_id)
);

CREATE INDEX idx_notice_reads_notice ON TB_NOTICE_READ(notice_id);
CREATE INDEX idx_notice_reads_user ON TB_NOTICE_READ(user_id);

COMMENT ON TABLE TB_NOTICE_READ IS '공지사항 확인 추적';


-- ============================================================================
-- 4. BILLING & SUBSCRIPTION TABLES (결제 및 구독 관련 테이블)
-- ============================================================================

-- 4.1 Subscriptions (구독/요금제)
-- 사용자 구독 정보
CREATE TABLE TB_SUBSCRIPTION (
    -- 기본 정보
    subscription_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id VARCHAR(128) NOT NULL REFERENCES TB_USER(user_id) ON DELETE CASCADE,
    trip_id UUID REFERENCES TB_TRIP(trip_id) ON DELETE CASCADE,

    -- 플랜 정보
    plan_type VARCHAR(20) NOT NULL,
    plan_category VARCHAR(20) DEFAULT 'individual',

    -- 할인
    discount_rate DECIMAL(5, 2) DEFAULT 0,
    discount_reason VARCHAR(50),

    -- 가격 (KRW)
    original_price INTEGER NOT NULL,
    final_price INTEGER NOT NULL,

    -- 기간
    start_date TIMESTAMP NOT NULL,
    end_date TIMESTAMP NOT NULL,

    -- 상태
    status VARCHAR(20) DEFAULT 'active',

    -- 자동 갱신
    auto_renew BOOLEAN DEFAULT FALSE,

    -- 메타데이터
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    cancelled_at TIMESTAMP
);

CREATE INDEX idx_subscriptions_user ON TB_SUBSCRIPTION(user_id);
CREATE INDEX idx_subscriptions_trip ON TB_SUBSCRIPTION(trip_id);
CREATE INDEX idx_subscriptions_status ON TB_SUBSCRIPTION(status);
CREATE INDEX idx_subscriptions_dates ON TB_SUBSCRIPTION(start_date, end_date);

COMMENT ON TABLE TB_SUBSCRIPTION IS '사용자 구독 정보';
COMMENT ON COLUMN TB_SUBSCRIPTION.plan_type IS '1day, 3day, 7day, 15day, 30day';
COMMENT ON COLUMN TB_SUBSCRIPTION.plan_category IS 'individual, group, school, agency';
COMMENT ON COLUMN TB_SUBSCRIPTION.status IS 'trial, active, grace, expired, cancelled';


-- 4.2 Payments (결제)
-- 결제 내역
CREATE TABLE TB_PAYMENT (
    -- 기본 정보
    payment_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id VARCHAR(128) NOT NULL REFERENCES TB_USER(user_id) ON DELETE CASCADE,
    subscription_id UUID REFERENCES TB_SUBSCRIPTION(subscription_id),

    -- 결제 정보
    payment_method VARCHAR(20) NOT NULL,
    amount INTEGER NOT NULL,
    currency VARCHAR(3) DEFAULT 'KRW',

    -- 외부 결제 ID
    external_payment_id VARCHAR(100),
    pg_provider VARCHAR(50),

    -- 상태
    status VARCHAR(20) DEFAULT 'pending',

    -- 환불 정보
    refund_amount INTEGER DEFAULT 0,
    refunded_at TIMESTAMP,
    refund_reason TEXT,

    -- 메타데이터
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP,
    failed_at TIMESTAMP,
    failure_reason TEXT
);

CREATE INDEX idx_payments_user ON TB_PAYMENT(user_id);
CREATE INDEX idx_payments_subscription ON TB_PAYMENT(subscription_id);
CREATE INDEX idx_payments_status ON TB_PAYMENT(status);
CREATE INDEX idx_payments_created ON TB_PAYMENT(created_at DESC);

COMMENT ON TABLE TB_PAYMENT IS '결제 내역';
COMMENT ON COLUMN TB_PAYMENT.payment_method IS 'card, kakao_pay, toss_pay, bank_transfer';
COMMENT ON COLUMN TB_PAYMENT.status IS 'pending, completed, failed, refunded, cancelled';


-- 4.3 Redeem_Codes (리딤 코드)
-- 초대 코드 및 프로모션 코드
CREATE TABLE TB_REDEEM_CODE (
    -- 기본 정보
    code_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) UNIQUE NOT NULL,

    -- 코드 유형
    code_type VARCHAR(30) NOT NULL,

    -- 혜택
    plan_type VARCHAR(20),
    discount_rate DECIMAL(5, 2),
    bonus_days INTEGER,

    -- 제한
    max_uses INTEGER DEFAULT 1,
    current_uses INTEGER DEFAULT 0,

    -- 유효기간
    valid_from TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    valid_until TIMESTAMP,

    -- 발급 정보
    issued_by VARCHAR(100),
    issued_reason TEXT,

    -- 상태
    is_active BOOLEAN DEFAULT TRUE,

    -- 메타데이터
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT chk_max_uses CHECK (current_uses <= max_uses)
);

CREATE INDEX idx_redeem_codes_code ON TB_REDEEM_CODE(code);
CREATE INDEX idx_redeem_codes_valid ON TB_REDEEM_CODE(valid_from, valid_until);

COMMENT ON TABLE TB_REDEEM_CODE IS '초대 코드 및 프로모션 코드';
COMMENT ON COLUMN TB_REDEEM_CODE.code_type IS 'PLAN-PERSONAL-7D, PLAN-GROUP-30D, BUNDLE-PARTNER-X';


-- 4.4 Code_Redemptions (코드 사용 내역)
-- 코드 사용 추적
CREATE TABLE TB_CODE_REDEMPTION (
    -- 기본 정보
    redemption_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code_id UUID NOT NULL REFERENCES TB_REDEEM_CODE(code_id) ON DELETE CASCADE,
    user_id VARCHAR(128) NOT NULL REFERENCES TB_USER(user_id) ON DELETE CASCADE,

    -- 적용 결과
    subscription_id UUID REFERENCES TB_SUBSCRIPTION(subscription_id),

    -- 상태
    status VARCHAR(20) DEFAULT 'success',
    failure_reason TEXT,

    -- 메타데이터
    redeemed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    device_id VARCHAR(100),
    ip_address INET
);

CREATE INDEX idx_redemptions_code ON TB_CODE_REDEMPTION(code_id);
CREATE INDEX idx_redemptions_user ON TB_CODE_REDEMPTION(user_id);
CREATE INDEX idx_redemptions_redeemed ON TB_CODE_REDEMPTION(redeemed_at DESC);

COMMENT ON TABLE TB_CODE_REDEMPTION IS '코드 사용 추적';
COMMENT ON COLUMN TB_CODE_REDEMPTION.status IS 'success, failed, revoked';


-- ============================================================================
-- 5. SYSTEM & LOG TABLES (시스템 및 로그 테이블)
-- ============================================================================

-- 5.1 Notifications (알림)
-- 푸시/SMS/이메일 알림 로그
CREATE TABLE TB_NOTIFICATION (
    -- 기본 정보
    notification_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id VARCHAR(128) NOT NULL REFERENCES TB_USER(user_id) ON DELETE CASCADE,

    -- 알림 유형
    notification_type VARCHAR(30) NOT NULL,

    -- 관련 엔티티
    related_entity_type VARCHAR(30),
    related_entity_id UUID,

    -- 내용
    title VARCHAR(200) NOT NULL,
    body TEXT NOT NULL,

    -- 전송 채널
    channel VARCHAR(20) NOT NULL,

    -- 상태
    status VARCHAR(20) DEFAULT 'pending',

    -- 전송 정보
    sent_at TIMESTAMP,
    delivered_at TIMESTAMP,
    read_at TIMESTAMP,
    failed_reason TEXT,

    -- 우선순위
    priority VARCHAR(20) DEFAULT 'normal',

    -- 메타데이터
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_notifications_user ON TB_NOTIFICATION(user_id, created_at DESC);
CREATE INDEX idx_notifications_type ON TB_NOTIFICATION(notification_type);
CREATE INDEX idx_notifications_status ON TB_NOTIFICATION(status);

COMMENT ON TABLE TB_NOTIFICATION IS '푸시/SMS/이메일 알림 로그';
COMMENT ON COLUMN TB_NOTIFICATION.notification_type IS 'sos, checkin_request, geofence, group_message, notice, system';
COMMENT ON COLUMN TB_NOTIFICATION.channel IS 'push, sms, email';
COMMENT ON COLUMN TB_NOTIFICATION.status IS 'pending, sent, delivered, failed, read';


-- 5.2 Activity_Logs (활동 로그)
-- 사용자 활동 추적 (감사/분석)
CREATE TABLE TB_ACTIVITY_LOG (
    -- 기본 정보
    log_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id VARCHAR(128) REFERENCES TB_USER(user_id) ON DELETE SET NULL,

    -- 활동 정보
    activity_type VARCHAR(50) NOT NULL,
    entity_type VARCHAR(30),
    entity_id UUID,

    -- 세부 정보
    details JSONB,

    -- 디바이스 정보
    device_id VARCHAR(100),
    device_type VARCHAR(20),
    app_version VARCHAR(20),

    -- 네트워크
    ip_address INET,
    user_agent TEXT,

    -- 메타데이터
    occurred_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_activity_logs_user ON TB_ACTIVITY_LOG(user_id, occurred_at DESC);
CREATE INDEX idx_activity_logs_type ON TB_ACTIVITY_LOG(activity_type);
CREATE INDEX idx_activity_logs_occurred ON TB_ACTIVITY_LOG(occurred_at DESC);

COMMENT ON TABLE TB_ACTIVITY_LOG IS '사용자 활동 추적 (감사/분석)';
COMMENT ON COLUMN TB_ACTIVITY_LOG.activity_type IS 'login, logout, trip_start, sos_sent, group_join';
COMMENT ON COLUMN TB_ACTIVITY_LOG.device_type IS 'ios, android, web';


-- 5.3 Device_Tokens (디바이스 토큰)
-- 푸시 알림용 디바이스 토큰
CREATE TABLE TB_DEVICE_TOKEN (
    -- 기본 정보
    token_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id VARCHAR(128) NOT NULL REFERENCES TB_USER(user_id) ON DELETE CASCADE,

    -- 토큰 정보
    device_token TEXT NOT NULL UNIQUE,
    platform VARCHAR(20) NOT NULL,

    -- 디바이스 정보
    device_id VARCHAR(100),
    device_model VARCHAR(100),
    os_version VARCHAR(20),
    app_version VARCHAR(20),

    -- App Check (보안 검증)
    app_check_token VARCHAR(500),
    app_check_verified BOOLEAN DEFAULT FALSE,
    app_check_verified_at TIMESTAMP,

    -- 상태
    is_active BOOLEAN DEFAULT TRUE,

    -- 메타데이터
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    last_used_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT chk_platform CHECK (platform IN ('ios', 'android'))
);

CREATE INDEX idx_device_tokens_user ON TB_DEVICE_TOKEN(user_id);
CREATE INDEX idx_device_tokens_token ON TB_DEVICE_TOKEN(device_token);
CREATE INDEX idx_device_tokens_app_check_verified ON TB_DEVICE_TOKEN(app_check_verified) WHERE app_check_verified = TRUE;

COMMENT ON TABLE TB_DEVICE_TOKEN IS '푸시 알림용 디바이스 토큰';
COMMENT ON COLUMN TB_DEVICE_TOKEN.platform IS 'ios, android';
COMMENT ON COLUMN TB_DEVICE_TOKEN.app_check_token IS 'App Check 토큰 (보안 검증용)';
COMMENT ON COLUMN TB_DEVICE_TOKEN.app_check_verified IS 'App Check 검증 완료 여부';
COMMENT ON COLUMN TB_DEVICE_TOKEN.app_check_verified_at IS 'App Check 검증 시각';


-- 5.4 Planned Routes (계획된 경로)
-- Route Deviation Detection을 위한 사전 계획 경로
CREATE TABLE TB_PLANNED_ROUTE (
    route_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id UUID NOT NULL REFERENCES TB_TRIP(trip_id) ON DELETE CASCADE,
    user_id VARCHAR(128) NOT NULL REFERENCES TB_USER(user_id) ON DELETE CASCADE,

    -- 경로 정보
    route_name VARCHAR(200),
    start_location VARCHAR(200) NOT NULL,
    end_location VARCHAR(200) NOT NULL,
    start_coords GEOGRAPHY(Point, 4326) NOT NULL,
    end_coords GEOGRAPHY(Point, 4326) NOT NULL,

    -- 경로 데이터 (GeoJSON LineString)
    route_path JSONB NOT NULL,
    waypoints JSONB,

    -- 경로 속성
    total_distance DECIMAL(10, 2),
    estimated_duration INTEGER,

    -- 이탈 감지 설정
    deviation_threshold INTEGER DEFAULT 100,
    is_active BOOLEAN DEFAULT true,

    -- 일정
    scheduled_start TIMESTAMP,
    scheduled_end TIMESTAMP,

    -- 메타데이터
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP
);

CREATE INDEX idx_planned_routes_trip ON TB_PLANNED_ROUTE(trip_id);
CREATE INDEX idx_planned_routes_user ON TB_PLANNED_ROUTE(user_id);
CREATE INDEX idx_planned_routes_active ON TB_PLANNED_ROUTE(is_active) WHERE is_active = true;
CREATE INDEX idx_planned_routes_schedule ON TB_PLANNED_ROUTE(scheduled_start, scheduled_end);
CREATE INDEX idx_planned_routes_start_geom ON TB_PLANNED_ROUTE USING GIST(start_coords);
CREATE INDEX idx_planned_routes_end_geom ON TB_PLANNED_ROUTE USING GIST(end_coords);

COMMENT ON TABLE TB_PLANNED_ROUTE IS '사전 계획된 여행 경로 (Route Deviation Detection용)';
COMMENT ON COLUMN TB_PLANNED_ROUTE.route_path IS 'GeoJSON LineString 형식의 경로 데이터';
COMMENT ON COLUMN TB_PLANNED_ROUTE.waypoints IS '경유지 목록 JSON: [{"name":"...", "lat":..., "lng":..., "order":1}]';
COMMENT ON COLUMN TB_PLANNED_ROUTE.deviation_threshold IS '이탈 감지 임계값 (미터, 기본 100m)';
COMMENT ON COLUMN TB_PLANNED_ROUTE.total_distance IS '전체 경로 거리 (km)';
COMMENT ON COLUMN TB_PLANNED_ROUTE.estimated_duration IS '예상 소요 시간 (분)';


-- 5.5 Route Deviations (경로 이탈 감지 로그)
CREATE TABLE TB_ROUTE_DEVIATION (
    deviation_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    route_id UUID NOT NULL REFERENCES TB_PLANNED_ROUTE(route_id) ON DELETE CASCADE,
    trip_id UUID NOT NULL REFERENCES TB_TRIP(trip_id) ON DELETE CASCADE,
    user_id VARCHAR(128) NOT NULL REFERENCES TB_USER(user_id) ON DELETE CASCADE,

    -- 이탈 위치
    deviation_location GEOGRAPHY(Point, 4326) NOT NULL,
    deviation_distance DECIMAL(10, 2) NOT NULL,

    -- 이탈 상태
    deviation_status VARCHAR(20) NOT NULL DEFAULT 'active',
    severity VARCHAR(20) DEFAULT 'low',

    -- 이탈 시간
    started_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ended_at TIMESTAMP,
    duration INTEGER,

    -- 알림 여부
    guardian_notified BOOLEAN DEFAULT false,
    notification_sent_at TIMESTAMP,

    -- 연속 이탈 카운트
    consecutive_count INTEGER DEFAULT 1,

    -- 메타데이터
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT chk_deviation_status CHECK (deviation_status IN ('active', 'resolved', 'ignored')),
    CONSTRAINT chk_severity CHECK (severity IN ('low', 'medium', 'high', 'critical'))
);

CREATE INDEX idx_route_deviations_route ON TB_ROUTE_DEVIATION(route_id);
CREATE INDEX idx_route_deviations_trip ON TB_ROUTE_DEVIATION(trip_id);
CREATE INDEX idx_route_deviations_user ON TB_ROUTE_DEVIATION(user_id);
CREATE INDEX idx_route_deviations_status ON TB_ROUTE_DEVIATION(deviation_status);
CREATE INDEX idx_route_deviations_started ON TB_ROUTE_DEVIATION(started_at DESC);
CREATE INDEX idx_route_deviations_geom ON TB_ROUTE_DEVIATION USING GIST(deviation_location);

COMMENT ON TABLE TB_ROUTE_DEVIATION IS '경로 이탈 감지 로그 (Route Deviation Detection)';
COMMENT ON COLUMN TB_ROUTE_DEVIATION.deviation_distance IS '계획된 경로로부터의 거리 (미터)';
COMMENT ON COLUMN TB_ROUTE_DEVIATION.deviation_status IS 'active(이탈 중), resolved(경로 복귀), ignored(무시됨)';
COMMENT ON COLUMN TB_ROUTE_DEVIATION.severity IS 'low(<100m), medium(100-300m), high(300-500m), critical(>500m)';
COMMENT ON COLUMN TB_ROUTE_DEVIATION.consecutive_count IS '연속 이탈 횟수 (3회 이상 시 경고 알림)';
COMMENT ON COLUMN TB_ROUTE_DEVIATION.duration IS '이탈 지속 시간 (초)';


-- 5.6 Travel Schedules (여행 일정)
-- 그룹 일정 관리 (Travel Schedule Board)
CREATE TABLE TB_TRAVEL_SCHEDULE (
    schedule_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id UUID REFERENCES TB_TRIP(trip_id) ON DELETE CASCADE,
    group_id UUID REFERENCES TB_GROUP(group_id) ON DELETE CASCADE,
    created_by VARCHAR(128) NOT NULL REFERENCES TB_USER(user_id) ON DELETE CASCADE,

    -- 일정 정보
    title VARCHAR(200) NOT NULL,
    description TEXT,
    schedule_type VARCHAR(50) NOT NULL,

    -- 장소 정보
    location_name VARCHAR(200),
    location_address VARCHAR(500),
    location_coords GEOGRAPHY(Point, 4326),

    -- 일정 시간
    start_time TIMESTAMP NOT NULL,
    end_time TIMESTAMP,
    all_day BOOLEAN DEFAULT false,

    -- 참석자
    participants JSONB,

    -- 비용 정보
    estimated_cost DECIMAL(10, 2),
    currency_code VARCHAR(3),

    -- 예약 정보
    booking_reference VARCHAR(100),
    booking_status VARCHAR(20),
    booking_url TEXT,

    -- 알림 설정
    reminder_enabled BOOLEAN DEFAULT true,
    reminder_time INTEGER DEFAULT 60,

    -- 첨부 파일
    attachments JSONB,

    -- 메타데이터
    is_completed BOOLEAN DEFAULT false,
    completed_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP,

    CONSTRAINT chk_schedule_type CHECK (schedule_type IN ('flight', 'accommodation', 'restaurant', 'activity', 'transportation', 'meeting', 'other')),
    CONSTRAINT chk_booking_status CHECK (booking_status IN ('pending', 'confirmed', 'cancelled', 'completed'))
);

CREATE INDEX idx_travel_schedules_trip ON TB_TRAVEL_SCHEDULE(trip_id);
CREATE INDEX idx_travel_schedules_group ON TB_TRAVEL_SCHEDULE(group_id);
CREATE INDEX idx_travel_schedules_creator ON TB_TRAVEL_SCHEDULE(created_by);
CREATE INDEX idx_travel_schedules_time ON TB_TRAVEL_SCHEDULE(start_time, end_time);
CREATE INDEX idx_travel_schedules_type ON TB_TRAVEL_SCHEDULE(schedule_type);
CREATE INDEX idx_travel_schedules_geom ON TB_TRAVEL_SCHEDULE USING GIST(location_coords);

COMMENT ON TABLE TB_TRAVEL_SCHEDULE IS '여행 일정 관리 (Travel Schedule Board)';
COMMENT ON COLUMN TB_TRAVEL_SCHEDULE.schedule_type IS 'flight(항공), accommodation(숙소), restaurant(식당), activity(활동), transportation(교통), meeting(미팅), other(기타)';
COMMENT ON COLUMN TB_TRAVEL_SCHEDULE.participants IS '참석자 목록 JSON: [{"user_id":"...", "name":"...", "status":"confirmed"}]';
COMMENT ON COLUMN TB_TRAVEL_SCHEDULE.reminder_time IS '알림 시간 (분 전, 기본 60분)';
COMMENT ON COLUMN TB_TRAVEL_SCHEDULE.attachments IS '첨부 파일 JSON: [{"file_name":"...", "file_url":"...", "file_type":"pdf"}]';
COMMENT ON COLUMN TB_TRAVEL_SCHEDULE.booking_status IS '예약 상태: pending(대기), confirmed(확정), cancelled(취소), completed(완료)';


-- 5.7 Countries (국가 기본 정보) - 거의 변경되지 않는 정적 데이터
CREATE TABLE TB_COUNTRY (
    -- ========== 기본 정보 ==========
    country_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    country_code VARCHAR(3) UNIQUE NOT NULL,
    country_name_en VARCHAR(100) NOT NULL,
    country_name_ko VARCHAR(100),
    country_name_local VARCHAR(100),
    flag_emoji VARCHAR(10),
    iso_alpha2 VARCHAR(2),
    continent VARCHAR(50),

    -- ========== 언어 정보 ==========
    primary_language VARCHAR(50),
    common_languages JSONB,
    language_tips TEXT,

    -- ========== 시간대 정보 ==========
    timezone VARCHAR(50),
    utc_offset VARCHAR(10),
    dst_info JSONB,

    -- ========== 통화 정보 (기본) ==========
    currency_code VARCHAR(3),
    currency_name VARCHAR(50),
    currency_symbol VARCHAR(10),

    -- ========== 교통 정보 ==========
    driving_side VARCHAR(10),
    international_license_accepted BOOLEAN,

    -- ========== 통신 정보 ==========
    sim_availability TEXT,
    roaming_info TEXT,
    wifi_availability TEXT,
    internet_censorship TEXT,

    -- ========== 전압 및 플러그 ==========
    voltage VARCHAR(20),
    frequency VARCHAR(20),
    plug_types VARCHAR(50),

    -- ========== 의료 정보 ==========
    health_insurance_required BOOLEAN,

    -- ========== 기타 실용 정보 ==========
    tap_water_safe BOOLEAN,
    cost_level VARCHAR(20),
    popular_payment_methods TEXT,

    -- ========== 여행 가이드 데이터 (통합) ==========
    travel_guide_data JSONB, -- 비자, 긴급연락처, 대사관, 기후, 문화, 안전 등 통합 데이터

    -- ========== 메타데이터 ==========
    is_active BOOLEAN DEFAULT true,
    data_quality_score INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP
);

CREATE INDEX idx_countries_code ON TB_COUNTRY(country_code);
CREATE INDEX idx_countries_alpha2 ON TB_COUNTRY(iso_alpha2);
CREATE INDEX idx_countries_continent ON TB_COUNTRY(continent);
CREATE INDEX idx_countries_active ON TB_COUNTRY(is_active) WHERE is_active = true;

-- GIN 인덱스 (JSONB 필드 검색용)
CREATE INDEX idx_countries_languages_gin ON TB_COUNTRY USING GIN(common_languages);
CREATE INDEX idx_countries_travel_guide_gin ON TB_COUNTRY USING GIN(travel_guide_data);

COMMENT ON TABLE TB_COUNTRY IS '국가 기본 정보 (정적 데이터) - 언어, 문화, 긴급연락처, 대사관 등';
COMMENT ON COLUMN TB_COUNTRY.country_code IS 'ISO 3166-1 alpha-3 (KOR, USA, JPN)';
COMMENT ON COLUMN TB_COUNTRY.iso_alpha2 IS 'ISO 3166-1 alpha-2 (KR, US, JP) - API/URL용';


-- 5.5 Country Regions (국가 내 지역 정보)
-- 날씨, 지역별 안전 정보를 위한 지역 구분
CREATE TABLE TB_COUNTRY_REGION (
    region_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    country_code VARCHAR(3) NOT NULL,
    region_code VARCHAR(50) NOT NULL,
    region_name_en VARCHAR(100) NOT NULL,
    region_name_ko VARCHAR(100),
    region_name_local VARCHAR(100),
    region_type VARCHAR(20),

    -- ========== 위치 정보 ==========
    latitude DECIMAL(10, 8),
    longitude DECIMAL(11, 8),
    geom GEOGRAPHY(Point, 4326),

    -- ========== 주요 도시 여부 ==========
    is_capital BOOLEAN DEFAULT false,
    is_major_city BOOLEAN DEFAULT false,
    population INTEGER,

    -- ========== 지역 특성 ==========
    timezone VARCHAR(50),
    utc_offset VARCHAR(10),

    -- ========== 메타데이터 ==========
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP,

    FOREIGN KEY (country_code) REFERENCES TB_COUNTRY(country_code) ON DELETE CASCADE,
    UNIQUE(country_code, region_code)
);

CREATE INDEX idx_regions_country ON TB_COUNTRY_REGION(country_code);
CREATE INDEX idx_regions_geom ON TB_COUNTRY_REGION USING GIST(geom);
CREATE INDEX idx_regions_major ON TB_COUNTRY_REGION(is_major_city) WHERE is_major_city = true;
CREATE INDEX idx_regions_active ON TB_COUNTRY_REGION(is_active) WHERE is_active = true;

COMMENT ON TABLE TB_COUNTRY_REGION IS '국가 내 지역 정보 (도시, 주, 광역 등) - 지역별 날씨 및 안전 정보 제공';
COMMENT ON COLUMN TB_COUNTRY_REGION.region_type IS '지역 타입: city(도시), state(주/도), province(성), district(구역)';
COMMENT ON COLUMN TB_COUNTRY_REGION.geom IS 'PostGIS 지리 좌표 (EPSG:4326)';


-- 5.6 MOFA Risks (외교부 위험 정보) - 자주 업데이트되는 동적 데이터
CREATE TABLE TB_MOFA_RISK (
    risk_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    country_code VARCHAR(3) NOT NULL,
    region_code VARCHAR(50),

    -- ========== 위험 정보 ==========
    risk_level VARCHAR(20) NOT NULL DEFAULT 'very_low',
    risk_description TEXT,
    alert_url TEXT,
    alert_details JSONB,

    -- ========== 특별 경보 ==========
    special_alerts JSONB,
    travel_ban BOOLEAN DEFAULT false,

    -- ========== 유효 기간 ==========
    valid_from TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    valid_until TIMESTAMP,

    -- ========== 메타데이터 ==========
    is_current BOOLEAN DEFAULT true,
    source VARCHAR(50) DEFAULT 'MOFA',
    synced_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (country_code) REFERENCES TB_COUNTRY(country_code) ON DELETE CASCADE
);

CREATE INDEX idx_mofa_country ON TB_MOFA_RISK(country_code);
CREATE INDEX idx_mofa_region ON TB_MOFA_RISK(country_code, region_code);
CREATE INDEX idx_mofa_level ON TB_MOFA_RISK(risk_level);
CREATE INDEX idx_mofa_current ON TB_MOFA_RISK(is_current) WHERE is_current = true;
CREATE INDEX idx_mofa_valid ON TB_MOFA_RISK(valid_from, valid_until);

COMMENT ON TABLE TB_MOFA_RISK IS '외교부 여행 경보 정보 (시계열 데이터, 자주 업데이트)';
COMMENT ON COLUMN TB_MOFA_RISK.risk_level IS '위험 단계: very_low(녹색), low(파란색), medium(노란색), high(주황색), very_high(빨간색)';
COMMENT ON COLUMN TB_MOFA_RISK.region_code IS '지역별 위험 정보 (NULL이면 국가 전체)';
COMMENT ON COLUMN TB_MOFA_RISK.is_current IS '현재 유효한 경보 여부';
COMMENT ON COLUMN TB_MOFA_RISK.special_alerts IS '특별 경보 JSON: [{"type":"terrorism","level":"high","message":"..."}]';


-- 5.7 Weather Data (날씨 정보) - 실시간 업데이트되는 동적 데이터
CREATE TABLE TB_WEATHER_DATA (
    weather_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    country_code VARCHAR(3) NOT NULL,
    region_id UUID,

    -- ========== 위치 정보 ==========
    location_name VARCHAR(100),
    latitude DECIMAL(10, 8),
    longitude DECIMAL(11, 8),

    -- ========== 날씨 정보 ==========
    temperature DECIMAL(5, 2),
    feels_like DECIMAL(5, 2),
    temp_min DECIMAL(5, 2),
    temp_max DECIMAL(5, 2),
    humidity INTEGER,
    pressure INTEGER,

    -- ========== 기상 상태 ==========
    weather_condition VARCHAR(50),
    weather_description TEXT,
    weather_icon VARCHAR(10),

    -- ========== 바람 ==========
    wind_speed DECIMAL(5, 2),
    wind_direction INTEGER,
    wind_gust DECIMAL(5, 2),

    -- ========== 구름 및 가시거리 ==========
    cloudiness INTEGER,
    visibility INTEGER,

    -- ========== 강수 ==========
    rain_1h DECIMAL(5, 2),
    rain_3h DECIMAL(5, 2),
    snow_1h DECIMAL(5, 2),
    snow_3h DECIMAL(5, 2),

    -- ========== 일출/일몰 ==========
    sunrise TIMESTAMP,
    sunset TIMESTAMP,

    -- ========== 경보 정보 ==========
    weather_alerts JSONB,

    -- ========== 예보 타입 ==========
    forecast_type VARCHAR(20) NOT NULL DEFAULT 'current',
    forecast_time TIMESTAMP,

    -- ========== API 정보 ==========
    api_provider VARCHAR(50),
    api_response JSONB,

    -- ========== 메타데이터 ==========
    recorded_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (country_code) REFERENCES TB_COUNTRY(country_code) ON DELETE CASCADE,
    FOREIGN KEY (region_id) REFERENCES TB_COUNTRY_REGION(region_id) ON DELETE CASCADE
);

-- 파티셔닝 준비 (시계열 데이터)
CREATE INDEX idx_weather_country ON TB_WEATHER_DATA(country_code);
CREATE INDEX idx_weather_region ON TB_WEATHER_DATA(region_id);
CREATE INDEX idx_weather_location ON TB_WEATHER_DATA(latitude, longitude);
CREATE INDEX idx_weather_recorded ON TB_WEATHER_DATA(recorded_at DESC);
CREATE INDEX idx_weather_forecast ON TB_WEATHER_DATA(forecast_type, forecast_time);

-- GIN 인덱스
CREATE INDEX idx_weather_alerts_gin ON TB_WEATHER_DATA USING GIN(weather_alerts);

COMMENT ON TABLE TB_WEATHER_DATA IS '국가/지역별 날씨 정보 (실시간 및 예보 데이터)';
COMMENT ON COLUMN TB_WEATHER_DATA.forecast_type IS '예보 타입: current(현재), hourly(시간별), daily(일별)';
COMMENT ON COLUMN TB_WEATHER_DATA.weather_alerts IS '기상 경보 JSON: [{"event":"Heavy Rain","severity":"moderate","description":"...","start":"...","end":"..."}]';
COMMENT ON COLUMN TB_WEATHER_DATA.api_provider IS 'API 제공자: OpenWeatherMap, WeatherAPI, etc.';


-- 5.8 Exchange Rates (환율 정보) - 매일 업데이트되는 동적 데이터
CREATE TABLE TB_EXCHANGE_RATE (
    rate_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    country_code VARCHAR(3) NOT NULL,
    currency_code VARCHAR(3) NOT NULL,

    -- ========== 환율 정보 (USD 기준) ==========
    rate_to_usd DECIMAL(12, 6) NOT NULL,
    rate_from_usd DECIMAL(12, 6) NOT NULL,

    -- ========== 환율 정보 (KRW 기준) ==========
    rate_to_krw DECIMAL(12, 6),
    rate_from_krw DECIMAL(12, 6),

    -- ========== 변동 정보 ==========
    change_24h DECIMAL(8, 4),
    change_percent_24h DECIMAL(6, 2),

    -- ========== API 정보 ==========
    api_provider VARCHAR(50),

    -- ========== 유효 기간 ==========
    valid_date DATE NOT NULL,
    valid_from TIMESTAMP NOT NULL,
    valid_until TIMESTAMP,

    -- ========== 메타데이터 ==========
    is_current BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (country_code) REFERENCES TB_COUNTRY(country_code) ON DELETE CASCADE,
    UNIQUE(country_code, valid_date)
);

CREATE INDEX idx_exchange_country ON TB_EXCHANGE_RATE(country_code);
CREATE INDEX idx_exchange_currency ON TB_EXCHANGE_RATE(currency_code);
CREATE INDEX idx_exchange_date ON TB_EXCHANGE_RATE(valid_date DESC);
CREATE INDEX idx_exchange_current ON TB_EXCHANGE_RATE(country_code, is_current) WHERE is_current = true;

COMMENT ON TABLE TB_EXCHANGE_RATE IS '국가별 환율 정보 (일별 업데이트)';
COMMENT ON COLUMN TB_EXCHANGE_RATE.country_code IS '국가 코드 (FK) - ISO 3166-1 alpha-3';
COMMENT ON COLUMN TB_EXCHANGE_RATE.currency_code IS 'ISO 4217 통화 코드 (JPY, USD, KRW 등)';
COMMENT ON COLUMN TB_EXCHANGE_RATE.rate_to_usd IS '해당 통화 1단위 = X USD (예: 1 JPY = 0.0067 USD)';
COMMENT ON COLUMN TB_EXCHANGE_RATE.rate_from_usd IS '1 USD = X 해당 통화 (예: 1 USD = 149.50 JPY)';
COMMENT ON COLUMN TB_EXCHANGE_RATE.is_current IS '현재 유효한 환율 여부';


-- ============================================================================
-- TRIGGERS & FUNCTIONS
-- ============================================================================

-- Update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply to all tables with updated_at column
CREATE TRIGGER trg_users_updated_at BEFORE UPDATE ON TB_USER
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER trg_trips_updated_at BEFORE UPDATE ON TB_TRIP
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER trg_groups_updated_at BEFORE UPDATE ON TB_GROUP
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER trg_sos_alerts_updated_at BEFORE UPDATE ON TB_SOS_ALERT
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER trg_geofences_updated_at BEFORE UPDATE ON TB_GEOFENCE
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER trg_group_messages_updated_at BEFORE UPDATE ON TB_GROUP_MESSAGE
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER trg_group_notices_updated_at BEFORE UPDATE ON TB_GROUP_NOTICE
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER trg_subscriptions_updated_at BEFORE UPDATE ON TB_SUBSCRIPTION
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER trg_countries_updated_at BEFORE UPDATE ON TB_COUNTRY
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();


-- Update group member count
CREATE OR REPLACE FUNCTION update_group_member_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE TB_GROUP
        SET current_member_count = current_member_count + 1
        WHERE group_id = NEW.group_id;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE TB_GROUP
        SET current_member_count = current_member_count - 1
        WHERE group_id = OLD.group_id;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_member_count
AFTER INSERT OR DELETE ON TB_GROUP_MEMBER
FOR EACH ROW EXECUTE FUNCTION update_group_member_count();


-- Update geom from latitude/longitude
CREATE OR REPLACE FUNCTION update_location_geom()
RETURNS TRIGGER AS $$
BEGIN
    NEW.geom = ST_SetSRID(ST_MakePoint(NEW.longitude, NEW.latitude), 4326)::geography;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_location_geom
BEFORE INSERT OR UPDATE ON TB_LOCATION
FOR EACH ROW EXECUTE FUNCTION update_location_geom();


-- Set location index (user별 순차 인덱스)
CREATE OR REPLACE FUNCTION set_location_idx()
RETURNS TRIGGER AS $$
BEGIN
    -- user_id별로 최대 i_idx를 찾아서 +1
    SELECT COALESCE(MAX(i_idx), 0) + 1
    INTO NEW.i_idx
    FROM TB_LOCATION
    WHERE user_id = NEW.user_id;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_set_location_idx
BEFORE INSERT ON TB_LOCATION
FOR EACH ROW EXECUTE FUNCTION set_location_idx();


-- ============================================================================
-- INITIAL DATA (시드 데이터)
-- ============================================================================

-- 샘플 국가 데이터 (한국, 미국, 일본) - 상세 정보 포함
-- Sample Data: Countries (기본 정보)
INSERT INTO TB_COUNTRY (
    country_code, iso_alpha2, country_name_en, country_name_ko, country_name_local,
    flag_emoji, continent,
    primary_language, common_languages, language_tips,
    timezone, utc_offset, dst_info,
    currency_code, currency_name, currency_symbol,
    visa_required, visa_free_duration, entry_requirements,
    emergency_police, emergency_fire, emergency_ambulance, emergency_coast_guard,
    embassies, climate_type, best_season,
    driving_side, international_license_accepted, transportation_tips,
    sim_availability, roaming_info, wifi_availability,
    voltage, frequency, plug_types,
    health_insurance_required, medical_facilities_quality,
    cultural_notes, etiquette_tips, tipping_culture,
    safety_tips, travel_tips,
    tap_water_safe, cost_level, popular_payment_methods,
    is_active, data_quality_score
) VALUES
(
    'JPN', 'JP', 'Japan', '일본', '日本',
    '🇯🇵', 'Asia',
    'Japanese', '["Japanese", "English (limited)"]', '영어 통용도가 낮으므로 번역 앱 필수',
    'Asia/Tokyo', '+09:00', '{"has_dst": false}',
    'JPY', 'Japanese Yen', '¥',
    false, 90, '90일 무비자 입국 가능 (관광 목적)',
    '110', '119', '119', '118',
    '[
        {
            "name": "주일본대한민국대사관",
            "address": "도쿄도 미나토구 미나미아자부 1-7-32",
            "phone": "+81-3-3452-7611",
            "emergency_phone": "+81-80-0000-0000",
            "email": "consul-jp@mofa.go.kr",
            "hours": "09:00-12:00, 13:30-17:30 (월-금)",
            "lat": 35.6486,
            "lng": 139.7326
        }
    ]',
    'Temperate (4 seasons)', '봄(3-5월) 벚꽃 시즌, 가을(9-11월) 단풍 시즌',
    'left', true, 'JR패스 추천, Suica/PASMO 카드 필수',
    '편의점/공항에서 선불 SIM 구매 가능', '한국 통신사 로밍 지원', '대부분 지역 무료 WiFi 제공',
    '100V', '50/60Hz', 'A, B',
    false, 'excellent',
    '조용하고 예의를 중시하는 문화', '공공장소에서 조용히, 신발 벗기', '팁 문화 없음',
    '[
        {"category": "범죄", "tip": "치안이 매우 좋으나 소매치기 주의", "priority": "low"},
        {"category": "자연재해", "tip": "지진 발생 시 행동 요령 숙지", "priority": "high"},
        {"category": "교통", "tip": "좌측 통행 주의", "priority": "medium"}
    ]',
    '{"immigration": "90일 무비자", "currency": "엔화 (JPY), 1000엔 ≈ 10,000원", "transport": "JR패스, Suica 카드", "sim": "편의점 구매 가능", "voltage": "100V, A/B형 플러그"}',
    true, 'high', '현금, 신용카드, IC카드',
    true, 95
),
(
    'USA', 'US', 'United States', '미국', 'United States',
    '🇺🇸', 'North America',
    'English', '["English", "Spanish"]', '영어 공용어, 스페인어도 많이 사용됨',
    'America/New_York', '-05:00', '{"has_dst": true, "start": "2024-03-10", "end": "2024-11-03"}',
    'USD', 'US Dollar', '$',
    true, 90, 'ESTA 비자면제 (90일, 사전 승인 필요)',
    '911', '911', '911', '911',
    '[
        {
            "name": "주미국대한민국대사관",
            "address": "2450 Massachusetts Avenue NW, Washington, DC 20008",
            "phone": "+1-202-939-5600",
            "emergency_phone": "+1-202-939-5633",
            "email": "info@koreanembassy.org",
            "hours": "09:00-17:30 (월-금)",
            "lat": 38.9175,
            "lng": -77.0558
        }
    ]',
    'Continental (varied)', '지역에 따라 계절 다름, 대체로 봄/가을 추천',
    'right', true, '렌터카 추천, 대중교통은 대도시만 발달',
    '공항/매장에서 선불 SIM 구매', '한국 통신사 로밍 지원', '대부분 지역 WiFi 제공',
    '120V', '60Hz', 'A, B',
    true, 'excellent',
    '개인주의 문화, 프라이버시 존중', '팁 문화 필수 (15-20%)', '팁 필수 (레스토랑 15-20%)',
    '[
        {"category": "범죄", "tip": "지역별 치안 편차 큼, 야간 외출 주의", "priority": "medium"},
        {"category": "건강", "tip": "의료비 매우 비싸므로 여행자 보험 필수", "priority": "high"},
        {"category": "교통", "tip": "우측 통행, 교통법규 준수", "priority": "medium"}
    ]',
    '{"immigration": "ESTA 비자면제 90일", "currency": "달러 (USD)", "transport": "렌터카 추천", "sim": "공항 구매 가능", "voltage": "120V, A/B형 플러그"}',
    true, 'very_high', '신용카드 중심, 현금 덜 사용',
    true, 90
),
(
    'KOR', 'KR', 'South Korea', '대한민국', '한국',
    '🇰🇷', 'Asia',
    'Korean', '["Korean", "English (limited)"]', '서울/관광지는 영어 통용, 지방은 제한적',
    'Asia/Seoul', '+09:00', '{"has_dst": false}',
    'KRW', 'Korean Won', '₩',
    false, 90, '대부분 국가 90일 무비자 입국 가능',
    '112', '119', '119', '122',
    '[]',
    'Temperate (4 seasons)', '봄(4-5월), 가을(9-11월) 추천',
    'right', true, '대중교통 매우 발달 (지하철, 버스)',
    '편의점/공항에서 선불 SIM 쉽게 구매', '로밍 지원', '전국 무료 WiFi 잘 되어있음',
    '220V', '60Hz', 'C, F',
    false, 'excellent',
    '빠른 템포, 디지털 문화 발달', '식사 시 어른 먼저, 양손 사용', '팁 문화 없음 (서비스료 포함)',
    '[
        {"category": "범죄", "tip": "치안 매우 우수, 야간 외출도 안전", "priority": "low"},
        {"category": "교통", "tip": "대중교통 이용 편리, T-money 카드 필수", "priority": "low"},
        {"category": "건강", "tip": "수돗물 음용 가능, 의료 시설 우수", "priority": "low"}
    ]',
    '{"immigration": "90일 무비자", "currency": "원화 (KRW)", "transport": "T-money 카드, 대중교통 발달", "sim": "편의점 구매 가능", "voltage": "220V, C/F형 플러그"}',
    true, 'medium', '카드/현금/모바일결제 모두 발달',
    true, 100
)
ON CONFLICT (country_code) DO NOTHING;


-- Sample Data: Country Regions (지역 정보)
INSERT INTO TB_COUNTRY_REGION (
    country_code, region_code, region_name_en, region_name_ko, region_name_local,
    region_type, latitude, longitude, is_capital, is_major_city, population,
    timezone, utc_offset
) VALUES
('JPN', 'tokyo', 'Tokyo', '도쿄', '東京', 'city', 35.6762, 139.6503, true, true, 13960000, 'Asia/Tokyo', '+09:00'),
('JPN', 'osaka', 'Osaka', '오사카', '大阪', 'city', 34.6937, 135.5023, false, true, 2691000, 'Asia/Tokyo', '+09:00'),
('JPN', 'kyoto', 'Kyoto', '교토', '京都', 'city', 35.0116, 135.7681, false, true, 1464000, 'Asia/Tokyo', '+09:00'),
('USA', 'new_york', 'New York', '뉴욕', 'New York', 'city', 40.7128, -74.0060, false, true, 8336000, 'America/New_York', '-05:00'),
('USA', 'los_angeles', 'Los Angeles', '로스앤젤레스', 'Los Angeles', 'city', 34.0522, -118.2437, false, true, 3979000, 'America/Los_Angeles', '-08:00'),
('USA', 'washington_dc', 'Washington D.C.', '워싱턴 D.C.', 'Washington D.C.', 'city', 38.9072, -77.0369, true, true, 705000, 'America/New_York', '-05:00'),
('KOR', 'seoul', 'Seoul', '서울', '서울', 'city', 37.5665, 126.9780, true, true, 9776000, 'Asia/Seoul', '+09:00'),
('KOR', 'busan', 'Busan', '부산', '부산', 'city', 35.1796, 129.0756, false, true, 3448000, 'Asia/Seoul', '+09:00'),
('KOR', 'jeju', 'Jeju', '제주', '제주', 'province', 33.4996, 126.5312, false, true, 670000, 'Asia/Seoul', '+09:00')
ON CONFLICT (country_code, region_code) DO NOTHING;


-- Sample Data: MOFA Risks (외교부 위험 정보)
INSERT INTO TB_MOFA_RISK (
    country_code, region_code, risk_level, risk_description, alert_url,
    special_alerts, travel_ban, valid_from, is_current
) VALUES
('JPN', NULL, 'very_low', '전 지역 안전. 자연재해(지진, 태풍) 대비 필요', 'https://www.0404.go.kr/country/JPN',
    '[{"type": "earthquake", "level": "low", "message": "지진 빈발 지역, 대피 요령 숙지"}]',
    false, CURRENT_TIMESTAMP, true),
('USA', NULL, 'low', '전반적으로 안전하나 지역별 치안 편차 큼', 'https://www.0404.go.kr/country/USA',
    '[{"type": "crime", "level": "medium", "message": "대도시 특정 지역 야간 외출 주의"}]',
    false, CURRENT_TIMESTAMP, true),
('KOR', NULL, 'very_low', '전 지역 안전. 세계 최고 수준의 치안', 'https://www.0404.go.kr/country/KOR',
    '[]',
    false, CURRENT_TIMESTAMP, true)
ON CONFLICT DO NOTHING;


-- Sample Data: Weather Data (날씨 정보 - 현재 날씨)
INSERT INTO TB_WEATHER_DATA (
    country_code, region_id, location_name, latitude, longitude,
    temperature, feels_like, temp_min, temp_max, humidity, pressure,
    weather_condition, weather_description, weather_icon,
    wind_speed, wind_direction, cloudiness, visibility,
    sunrise, sunset,
    forecast_type, forecast_time, api_provider, recorded_at
) VALUES
(
    'JPN',
    (SELECT region_id FROM TB_COUNTRY_REGION WHERE country_code = 'JPN' AND region_code = 'tokyo'),
    'Tokyo', 35.6762, 139.6503,
    12.5, 10.2, 9.0, 15.0, 65, 1013,
    'Clear', 'clear sky', '01d',
    3.5, 180, 20, 10000,
    '2025-02-01 06:30:00', '2025-02-01 17:15:00',
    'current', CURRENT_TIMESTAMP, 'OpenWeatherMap', CURRENT_TIMESTAMP
),
(
    'USA',
    (SELECT region_id FROM TB_COUNTRY_REGION WHERE country_code = 'USA' AND region_code = 'new_york'),
    'New York', 40.7128, -74.0060,
    -2.0, -6.5, -4.0, 1.0, 70, 1018,
    'Snow', 'light snow', '13d',
    8.5, 315, 90, 5000,
    '2025-02-01 07:15:00', '2025-02-01 17:30:00',
    'current', CURRENT_TIMESTAMP, 'OpenWeatherMap', CURRENT_TIMESTAMP
),
(
    'KOR',
    (SELECT region_id FROM TB_COUNTRY_REGION WHERE country_code = 'KOR' AND region_code = 'seoul'),
    'Seoul', 37.5665, 126.9780,
    -5.0, -8.0, -7.0, -3.0, 45, 1025,
    'Clouds', 'few clouds', '02d',
    4.2, 270, 30, 10000,
    '2025-02-01 07:45:00', '2025-02-01 17:50:00',
    'current', CURRENT_TIMESTAMP, 'OpenWeatherMap', CURRENT_TIMESTAMP
)
ON CONFLICT DO NOTHING;


-- Sample Data: Exchange Rates (환율 정보)
INSERT INTO TB_EXCHANGE_RATE (
    country_code, currency_code, rate_to_usd, rate_from_usd, rate_to_krw, rate_from_krw,
    change_24h, change_percent_24h, api_provider, valid_date, valid_from, is_current
) VALUES
('JPN', 'JPY', 0.0067, 149.50, 8.95, 0.112, -0.50, -0.33, 'ExchangeRatesAPI', CURRENT_DATE, CURRENT_TIMESTAMP, true),
('USA', 'USD', 1.0, 1.0, 1335.0, 0.000749, 0.0, 0.0, 'ExchangeRatesAPI', CURRENT_DATE, CURRENT_TIMESTAMP, true),
('KOR', 'KRW', 0.000749, 1335.0, 1.0, 1.0, -2.0, -0.15, 'ExchangeRatesAPI', CURRENT_DATE, CURRENT_TIMESTAMP, true)
ON CONFLICT (country_code, valid_date) DO NOTHING;


-- ============================================================================
-- 5. EVENT LOG (통합 이벤트 로그)
-- ============================================================================

-- 5.1 Event Log (통합 이벤트 로그 테이블)
-- 모든 이벤트(지오펜스, 이동 세션, 이동 상태, 앱 상태, SOS)를 하나의 테이블에 저장
CREATE TABLE TB_EVENT_LOG (
    -- 기본 정보
    event_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id VARCHAR(128) NOT NULL REFERENCES TB_USER(user_id) ON DELETE CASCADE,
    group_id UUID REFERENCES TB_GROUP(group_id) ON DELETE SET NULL,
    
    -- 이벤트 유형
    event_type VARCHAR(50) NOT NULL,
    event_subtype VARCHAR(50),
    
    -- 위치 정보
    latitude DECIMAL(10, 8),
    longitude DECIMAL(11, 8),
    address TEXT,
    
    -- 공용 상태 정보
    battery_level INTEGER,
    battery_is_charging BOOLEAN,
    network_type VARCHAR(20),
    app_version VARCHAR(50),
    
    -- 참조 엔티티 (선택적)
    geofence_id UUID, -- 지오펜스 ID (Firebase에 저장된 geofence_id 참조, 외래키 제약조건 없음)
    movement_session_id UUID,
    location_id UUID REFERENCES TB_LOCATION(location_id) ON DELETE SET NULL,
    sos_id UUID REFERENCES TB_SOS_ALERT(sos_id) ON DELETE SET NULL,
    
    -- 이벤트별 상세 정보 (JSONB)
    event_data JSONB,
    
    -- 메타데이터
    occurred_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 인덱스 생성
CREATE INDEX idx_event_log_user ON TB_EVENT_LOG(user_id);
CREATE INDEX idx_event_log_group ON TB_EVENT_LOG(group_id);
CREATE INDEX idx_event_log_type ON TB_EVENT_LOG(event_type);
CREATE INDEX idx_event_log_subtype ON TB_EVENT_LOG(event_subtype);
CREATE INDEX idx_event_log_geofence ON TB_EVENT_LOG(geofence_id);
CREATE INDEX idx_event_log_session ON TB_EVENT_LOG(movement_session_id);
CREATE INDEX idx_event_log_sos ON TB_EVENT_LOG(sos_id);
CREATE INDEX idx_event_log_occurred ON TB_EVENT_LOG(occurred_at DESC);
CREATE INDEX idx_event_log_data ON TB_EVENT_LOG USING GIN(event_data);

-- 주석
COMMENT ON TABLE TB_EVENT_LOG IS '통합 이벤트 로그 (지오펜스, 이동 세션, 이동 상태, 앱 상태, SOS)';
COMMENT ON COLUMN TB_EVENT_LOG.event_type IS '이벤트 타입: geofence, session, session_event, device_status, sos';
COMMENT ON COLUMN TB_EVENT_LOG.event_subtype IS '이벤트 서브타입: geofence(enter, exit, dwell), session(start, end, kill, premature_end), session_event(rapid_acceleration, rapid_deceleration, speeding), device_status(battery_warning, mock_location, location_permission_denied, network_change, app_lifecycle), sos(emergency, crime, medical) 등';
COMMENT ON COLUMN TB_EVENT_LOG.event_data IS '이벤트별 상세 정보 (JSONB)';


-- ============================================================================
-- 5.2 Session Map Image (세션별 지도 이미지 캐시)
-- ============================================================================
-- 이동 세션의 지도 이미지를 캐싱하여 성능 최적화
-- Firebase Storage URL과 Base64를 모두 지원 (점진적 마이그레이션)
CREATE TABLE tb_session_map_image (
    session_id UUID PRIMARY KEY,
    user_id VARCHAR(128) NOT NULL REFERENCES TB_USER(user_id) ON DELETE CASCADE,
    map_image_url TEXT,
    map_image_base64 TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 인덱스 생성
CREATE INDEX idx_session_map_image_user_id ON tb_session_map_image(user_id);
CREATE INDEX idx_session_map_image_created_at ON tb_session_map_image(created_at DESC);
CREATE INDEX idx_session_map_image_url ON tb_session_map_image(map_image_url) WHERE map_image_url IS NOT NULL;

-- 주석
COMMENT ON TABLE tb_session_map_image IS '세션별 지도 이미지 캐시 (Firebase Storage URL 우선, Base64는 하위 호환성)';
COMMENT ON COLUMN tb_session_map_image.session_id IS 'movement_session_id (세션 고유 식별자)';
COMMENT ON COLUMN tb_session_map_image.user_id IS '사용자 ID (외래 키: TB_USER.user_id)';
COMMENT ON COLUMN tb_session_map_image.map_image_url IS 'Firebase Storage에 저장된 지도 이미지 URL (공유 스토리지)';
COMMENT ON COLUMN tb_session_map_image.map_image_base64 IS 'Base64 인코딩된 지도 이미지 (하위 호환성, 점진적 제거 예정)';


-- ============================================================================
-- END OF SCHEMA
-- ============================================================================
