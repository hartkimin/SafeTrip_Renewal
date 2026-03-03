-- ============================================================
-- SafeTrip DB Schema v3.4.1
-- 02: [C] 보호자(가디언) 도메인
-- 기준 문서: 07_T2_DB_설계_및_관계_v3_4.md §4.9~4.11b
-- ============================================================

-- 4.9 TB_GUARDIAN (보호자 — 레거시 유지)
CREATE TABLE tb_guardian (
    guardian_id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    traveler_user_id     VARCHAR(128) REFERENCES tb_user(user_id),
    guardian_user_id     VARCHAR(128) REFERENCES tb_user(user_id),
    trip_id              UUID REFERENCES tb_trip(trip_id),
    guardian_type        VARCHAR(20),                     -- primary | secondary | group
    can_view_location    BOOLEAN DEFAULT TRUE,
    can_request_checkin  BOOLEAN DEFAULT TRUE,
    can_receive_sos      BOOLEAN DEFAULT TRUE,
    invite_status        VARCHAR(20),                     -- pending | accepted | rejected
    guardian_invite_code VARCHAR(20),
    -- ▼ 미성년자 보호 원칙 §13
    is_minor_guardian    BOOLEAN DEFAULT FALSE,
    consent_id           UUID,
    auto_notify_sos      BOOLEAN DEFAULT TRUE,
    auto_notify_geofence BOOLEAN DEFAULT TRUE,
    -- ▼ 비즈니스 원칙 v5.1 §09.3: 가디언 유/무료 구분
    is_paid              BOOLEAN DEFAULT FALSE,
    paid_at              TIMESTAMPTZ,
    payment_id           UUID,                            -- TB_PAYMENT FK (99-deferred-fk.sql)
    -- ▼ 시스템
    created_at           TIMESTAMPTZ DEFAULT NOW(),
    accepted_at          TIMESTAMPTZ,
    expires_at           TIMESTAMPTZ
);

CREATE INDEX idx_guardian_traveler ON tb_guardian(traveler_user_id);
CREATE INDEX idx_guardian_guardian ON tb_guardian(guardian_user_id);
CREATE INDEX idx_guardian_trip     ON tb_guardian(trip_id);

-- 4.10 TB_GUARDIAN_LINK (가디언-멤버 연결)
CREATE TABLE tb_guardian_link (
    link_id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id              UUID NOT NULL REFERENCES tb_trip(trip_id) ON DELETE CASCADE,
    -- ▼ 연결 대상 (멤버 = 보호 받는 사람)
    member_id            VARCHAR(128) NOT NULL REFERENCES tb_user(user_id),
    -- ▼ 가디언 (보호자) — NULL 허용: 전화번호만 입력한 미가입 가디언 초대 지원
    guardian_id          VARCHAR(128) REFERENCES tb_user(user_id) ON DELETE SET NULL,
    guardian_phone       VARCHAR(20),                     -- 초대 시 입력한 전화번호 (미가입 가디언은 필수)
    -- ▼ 링크 상태
    status               VARCHAR(20) DEFAULT 'pending'
        CHECK (status IN ('pending', 'accepted', 'rejected', 'cancelled')),
    -- ▼ 가디언 유형
    guardian_type        VARCHAR(20) DEFAULT 'personal'
        CHECK (guardian_type IN ('personal', 'group')),
    -- ▼ 결제 연동 (비즈니스 원칙 v5.1 §09.3: 무료 2명 초과 시 유료)
    is_paid              BOOLEAN DEFAULT FALSE,
    paid_at              TIMESTAMPTZ,
    payment_id           UUID,                            -- TB_PAYMENT FK (99-deferred-fk.sql)
    -- ▼ 권한 설정
    can_view_location    BOOLEAN DEFAULT TRUE,
    can_receive_sos      BOOLEAN DEFAULT TRUE,
    can_request_checkin  BOOLEAN DEFAULT TRUE,
    can_send_message     BOOLEAN DEFAULT TRUE,            -- 가디언 메시지 전송 가능
    -- ▼ 시스템
    invited_at           TIMESTAMPTZ DEFAULT NOW(),
    responded_at         TIMESTAMPTZ,
    created_at           TIMESTAMPTZ DEFAULT NOW(),
    updated_at           TIMESTAMPTZ
    -- ▼ v3.4: UNIQUE(trip_id, member_id, guardian_id) 제거 — guardian_id NULL 허용으로 NULL≠NULL 문제 발생
    -- 대신 아래 부분 인덱스 2개로 중복 방지
);

CREATE INDEX idx_guardian_link_trip     ON tb_guardian_link(trip_id);
CREATE INDEX idx_guardian_link_member   ON tb_guardian_link(member_id);
CREATE INDEX idx_guardian_link_guardian ON tb_guardian_link(guardian_id);
CREATE INDEX idx_guardian_link_status   ON tb_guardian_link(status);
-- ▼ v3.4: 부분 인덱스로 UNIQUE 보장 (guardian_id NULL 허용 환경에서 안전한 중복 방지)
CREATE UNIQUE INDEX idx_guardian_link_active
    ON tb_guardian_link(trip_id, member_id, guardian_id)
    WHERE guardian_id IS NOT NULL;
CREATE UNIQUE INDEX idx_guardian_link_pending
    ON tb_guardian_link(trip_id, member_id, guardian_phone)
    WHERE guardian_id IS NULL AND guardian_phone IS NOT NULL;

-- 4.11 TB_GUARDIAN_PAUSE (가디언 일시중지)
CREATE TABLE tb_guardian_pause (
    pause_id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    link_id           UUID NOT NULL REFERENCES tb_guardian_link(link_id),
    user_id           VARCHAR(128) NOT NULL REFERENCES tb_user(user_id),
    trip_id           UUID NOT NULL REFERENCES tb_trip(trip_id),
    -- ▼ v3.4: Appendix C 호환 컬럼 추가 (de-normalization intentional)
    group_id          UUID REFERENCES tb_group(group_id) ON DELETE CASCADE,
    guardian_user_id  VARCHAR(128) REFERENCES tb_user(user_id) ON DELETE SET NULL,
    paused_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    resume_at         TIMESTAMPTZ NOT NULL,          -- 자동 재개 시각
    is_active         BOOLEAN DEFAULT TRUE,
    pause_reason      VARCHAR(50),                   -- user_request | minor_blocked
    created_at        TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_guardian_pause_link ON tb_guardian_pause(link_id);
CREATE INDEX idx_guardian_pause_user ON tb_guardian_pause(user_id, trip_id);

-- 4.11a TB_GUARDIAN_LOCATION_REQUEST (가디언 긴급 위치 요청)
CREATE TABLE tb_guardian_location_request (
    request_id       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id         UUID NOT NULL REFERENCES tb_group(group_id),
    trip_id          UUID NOT NULL REFERENCES tb_trip(trip_id) ON DELETE CASCADE,
    -- ▼ 요청자: 가디언 (위치를 보고 싶은 쪽)
    guardian_user_id VARCHAR(128) NOT NULL REFERENCES tb_user(user_id),
    -- ▼ 피요청자: 여행자/크루 (위치 공유 요청을 받는 쪽)
    target_user_id   VARCHAR(128) NOT NULL REFERENCES tb_user(user_id),
    -- ▼ 요청 상태
    status           VARCHAR(20) DEFAULT 'pending'
        CHECK (status IN ('pending', 'approved', 'ignored', 'expired')),
    -- ▼ 타임스탬프
    requested_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    responded_at          TIMESTAMPTZ,                     -- 승인/무시 시각
    expires_at            TIMESTAMPTZ NOT NULL,            -- 기본 10분 후 자동 만료
    -- ▼ v3.4: 표준 등급 자동 응답 지원 (비즈니스 원칙 v5.1 §05.3)
    auto_responded        BOOLEAN DEFAULT FALSE,           -- 표준 등급에서 멤버 승인 없이 자동 응답
    auto_response_reason  VARCHAR(50),                     -- standard_grade_auto | sos_override
    created_at            TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_guardian_location_request_target
    ON tb_guardian_location_request(target_user_id, status);
CREATE INDEX idx_guardian_location_request_guardian
    ON tb_guardian_location_request(guardian_user_id, requested_at DESC);
CREATE INDEX idx_guardian_location_request_trip
    ON tb_guardian_location_request(trip_id);
-- ▼ v3.4: 시간당 3회 rate limiting 지원
CREATE INDEX idx_guardian_location_request_hourly
    ON tb_guardian_location_request(guardian_user_id, requested_at DESC);

-- 4.11b TB_GUARDIAN_SNAPSHOT (가디언 위치 스냅샷)
CREATE TABLE tb_guardian_snapshot (
    snapshot_id  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id     UUID NOT NULL REFERENCES tb_group(group_id),
    trip_id      UUID NOT NULL REFERENCES tb_trip(trip_id) ON DELETE CASCADE,
    -- ▼ 스냅샷 대상 (여행자/크루)
    user_id      VARCHAR(128) NOT NULL REFERENCES tb_user(user_id),
    latitude     DOUBLE PRECISION NOT NULL,
    longitude    DOUBLE PRECISION NOT NULL,
    captured_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_guardian_snapshot_user
    ON tb_guardian_snapshot(user_id, captured_at DESC);
CREATE INDEX idx_guardian_snapshot_group
    ON tb_guardian_snapshot(group_id, captured_at DESC);
CREATE INDEX idx_guardian_snapshot_trip
    ON tb_guardian_snapshot(trip_id, captured_at DESC);
