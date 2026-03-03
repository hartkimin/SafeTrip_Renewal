-- ============================================================
-- SafeTrip DB Schema v3.4.1
-- 10: [K] 결제/과금 + [L] B2B 도메인 (8 tables)
-- 기준 문서: 07_T2_DB_설계_및_관계_v3_4.md §4.39~4.46
-- ============================================================

-- ====== [K] 결제/과금 도메인 ======

-- 4.39 TB_SUBSCRIPTION (구독/플랜) ⭐ 신규
CREATE TABLE tb_subscription (
    subscription_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         VARCHAR(128) NOT NULL REFERENCES tb_user(user_id),
    -- ▼ v3.4: Appendix C 기준으로 plan_type 확장
    plan_type       VARCHAR(30) NOT NULL
        CHECK (plan_type IN (
            'free',             -- 무료 (기본)
            'trip_base',        -- 여행 기본 이용 (유료 여행)
            'addon_movement',   -- 움직임 세션 애드온
            'addon_ai_plus',    -- AI Plus 애드온
            'addon_ai_pro',     -- AI Pro 애드온
            'addon_guardian',   -- 추가 가디언 슬롯
            'b2b_school',       -- B2B 학교 계약
            'b2b_corporate'     -- B2B 기업 계약
        )),
    status          VARCHAR(20) DEFAULT 'active',  -- active | cancelled | expired | suspended
    trip_id         UUID REFERENCES tb_trip(trip_id),   -- 여행 단위 구독인 경우
    started_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at      TIMESTAMPTZ,                   -- NULL = 여행 종료 시 자동 만료
    auto_renew      BOOLEAN DEFAULT FALSE,
    cancelled_at    TIMESTAMPTZ,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ
);

CREATE INDEX idx_subscription_user   ON tb_subscription(user_id);
CREATE INDEX idx_subscription_status ON tb_subscription(status);

-- 4.40 TB_PAYMENT (결제 내역)
CREATE TABLE tb_payment (
    payment_id       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id          VARCHAR(128) NOT NULL REFERENCES tb_user(user_id),
    subscription_id  UUID REFERENCES tb_subscription(subscription_id),
    -- ▼ v3.4: Appendix C 기준으로 payment_type 전면 교체
    payment_type     VARCHAR(30) NOT NULL
        CHECK (payment_type IN (
            'trip_base',        -- 여행 기본 이용료 (6인~ 유료, 비즈니스 원칙 §09.1)
            'addon_movement',   -- 움직임 세션 애드온 (2,900원/세션)
            'addon_ai_plus',    -- AI Plus 애드온 (4,900원/월 or 2,900원/여행)
            'addon_ai_pro',     -- AI Pro 애드온 (9,900원/월 or 5,900원/여행)
            'addon_guardian',   -- 추가 가디언 슬롯 (1,900원/여행, 3번째 이상)
            'b2b_contract'      -- B2B 계약 일괄 과금
        )),
    -- ▼ v3.4: trip_id 추가 (Appendix C 기준 — 여행 단위 결제 직접 연결)
    trip_id          UUID REFERENCES tb_trip(trip_id) ON DELETE SET NULL,
    amount           DECIMAL(10, 2) NOT NULL,
    currency         VARCHAR(3) DEFAULT 'KRW',
    status           VARCHAR(20) DEFAULT 'pending',
        -- pending | completed | failed | refunded | cancelled
    pg_provider      VARCHAR(30),                  -- toss | kakao | inicis | stripe
    pg_payment_key   VARCHAR(200),                 -- PG사 고유 결제키
    pg_order_id      VARCHAR(100),
    pg_receipt_url   TEXT,
    paid_at          TIMESTAMPTZ,
    failed_at        TIMESTAMPTZ,
    failure_reason   TEXT,
    metadata         JSONB,                        -- 추가 컨텍스트 (guardian_link_id 등)
    created_at       TIMESTAMPTZ DEFAULT NOW(),
    updated_at       TIMESTAMPTZ
);

CREATE INDEX idx_payment_user   ON tb_payment(user_id);
CREATE INDEX idx_payment_status ON tb_payment(status);
CREATE INDEX idx_payment_pg_key ON tb_payment(pg_payment_key);

-- 4.41 TB_BILLING_ITEM (결제 항목 명세)
CREATE TABLE tb_billing_item (
    item_id       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    payment_id    UUID NOT NULL REFERENCES tb_payment(payment_id),
    -- ▼ v3.4: Appendix C 기준으로 item_type 확장
    item_type     VARCHAR(30) NOT NULL
        CHECK (item_type IN (
            'trip_base',        -- 여행 기본 이용료
            'addon_movement',   -- 움직임 애드온 (세션 단위)
            'addon_ai_plus',    -- AI Plus 애드온
            'addon_ai_pro',     -- AI Pro 애드온
            'addon_guardian',   -- 추가 가디언 슬롯
            'b2b_seat',         -- B2B 좌석
            'movement_session'  -- 개별 이동 세션 과금
        )),
    item_name     VARCHAR(100) NOT NULL,
    quantity      INTEGER DEFAULT 1,
    unit_price    DECIMAL(10, 2) NOT NULL,
    total_price   DECIMAL(10, 2) NOT NULL,
    reference_id  VARCHAR(128),                    -- guardian_link_id, trip_id 등
    created_at    TIMESTAMPTZ DEFAULT NOW()
);

-- 4.42 TB_REFUND_LOG (환불 기록) ⭐ 신규
CREATE TABLE tb_refund_log (
    refund_id       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    payment_id      UUID NOT NULL REFERENCES tb_payment(payment_id),
    -- ▼ v3.4: FK 추가 + NOT NULL 제거 (사용자 삭제 후에도 환불 기록 보존용)
    user_id         VARCHAR(128) REFERENCES tb_user(user_id) ON DELETE SET NULL,
    refund_amount   DECIMAL(10, 2) NOT NULL,
    refund_reason   VARCHAR(100),
        -- user_request | service_error | admin_override | duplicate_payment
    -- ▼ v3.4.1: 적용된 환불 정책 추적 (비즈니스 원칙 v5.1 §09.7)
    refund_policy   VARCHAR(30),
        -- planning_full       : planning 상태에서 전액 환불 (100%)
        -- active_24h_half     : active 상태 + 여행 시작 24시간 이내 50% 환불
        -- active_no_refund    : active 상태 + 여행 시작 24시간 이후 환불 불가 (0%)
        -- completed_no_refund : completed 상태 환불 불가 (0%)
        -- admin_override      : 관리자 수동 환불
    refund_status   VARCHAR(20) DEFAULT 'pending',
        -- pending | completed | rejected
    pg_refund_key   VARCHAR(200),
    requested_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at    TIMESTAMPTZ,
    rejected_at     TIMESTAMPTZ,
    rejection_reason TEXT,
    processed_by    VARCHAR(128),                  -- admin user_id 또는 'system'
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_refund_payment ON tb_refund_log(payment_id);
CREATE INDEX idx_refund_user    ON tb_refund_log(user_id);

-- ====== [L] B2B 도메인 ======

-- 4.44 TB_B2B_SCHOOL (학교 정보)
CREATE TABLE tb_b2b_school (
    school_id       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_name     VARCHAR(200) NOT NULL,
    school_code     VARCHAR(50),                   -- 학교 코드 (교육부 기준)
    region          VARCHAR(100),                  -- 시/도
    district        VARCHAR(100),                  -- 시/군/구
    school_type     VARCHAR(20),                   -- elementary | middle | high | university
    contact_teacher VARCHAR(100),
    contact_phone   VARCHAR(20),
    contact_email   VARCHAR(255),
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ
);

-- 4.43 TB_B2B_CONTRACT (B2B 계약)
CREATE TABLE tb_b2b_contract (
    contract_id      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    contract_code    VARCHAR(20) UNIQUE NOT NULL,  -- 계약 식별 코드
    contract_type    VARCHAR(20) NOT NULL,
        -- school | corporate | travel_agency | insurance
    company_name     VARCHAR(200) NOT NULL,
    contact_name     VARCHAR(100),
    contact_email    VARCHAR(255),
    contact_phone    VARCHAR(20),
    -- ▼ 계약 조건
    max_groups       INTEGER DEFAULT 1,            -- 동시 생성 가능한 그룹 수
    max_members_per_group INTEGER DEFAULT 50,      -- 그룹당 최대 멤버 수
    -- ▼ v3.4: Appendix C 호환 컬럼 추가
    max_trips        INTEGER DEFAULT NULL,         -- NULL이면 max_groups로 대체
    guardian_model   VARCHAR(20) DEFAULT 'A',      -- A (개별 동의) | B (일괄 등록)
    sla_level        VARCHAR(20) DEFAULT 'standard', -- standard | premium | enterprise
    -- ▼ 계약 기간
    started_at       DATE NOT NULL,
    expires_at       DATE,
    -- ▼ 상태
    status           VARCHAR(20) DEFAULT 'active',  -- active | suspended | expired
    -- ▼ 참조 (학교 계약 시)
    school_id        UUID REFERENCES tb_b2b_school(school_id) ON DELETE SET NULL,
    -- ▼ 시스템
    created_at       TIMESTAMPTZ DEFAULT NOW(),
    updated_at       TIMESTAMPTZ
);

CREATE INDEX idx_b2b_contract_type   ON tb_b2b_contract(contract_type);
CREATE INDEX idx_b2b_contract_status ON tb_b2b_contract(status);



-- 4.45 TB_B2B_INVITE_BATCH (B2B 일괄 초대)
CREATE TABLE tb_b2b_invite_batch (
    batch_id      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    contract_id   UUID NOT NULL REFERENCES tb_b2b_contract(contract_id),
    group_id      UUID REFERENCES tb_group(group_id),
    batch_name    VARCHAR(200),                    -- "2026 수학여행 3학년 2반"
    target_role   VARCHAR(30) NOT NULL,            -- crew | guardian
    total_count   INTEGER NOT NULL,
    used_count    INTEGER DEFAULT 0,
    csv_file_url  TEXT,                            -- 업로드된 CSV 파일
    status        VARCHAR(20) DEFAULT 'active',    -- active | expired | cancelled
    created_by    VARCHAR(128) REFERENCES tb_user(user_id),
    expires_at    TIMESTAMPTZ,
    created_at    TIMESTAMPTZ DEFAULT NOW(),
    updated_at    TIMESTAMPTZ
);

CREATE INDEX idx_b2b_invite_batch_contract ON tb_b2b_invite_batch(contract_id);

-- 4.46 TB_B2B_MEMBER_LOG (B2B 멤버 참여 기록) ⭐ 신규
CREATE TABLE tb_b2b_member_log (
    log_id        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    batch_id      UUID NOT NULL REFERENCES tb_b2b_invite_batch(batch_id),
    user_id       VARCHAR(128) REFERENCES tb_user(user_id),
    invite_code   VARCHAR(7),
    joined_at     TIMESTAMPTZ,
    member_role   VARCHAR(30),
    -- ▼ 미성년자 동의 연동 (§13)
    minor_consent_id UUID REFERENCES tb_minor_consent(consent_id),
    notes         TEXT,
    created_at    TIMESTAMPTZ DEFAULT NOW()
);
