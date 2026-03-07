-- ============================================================
-- SafeTrip DB Schema v3.6
-- 16: 안전가이드 도메인 (2 tables)
-- 기준 문서: DOC-T3-SFG-021 §7 — 안전가이드 DB 스키마
-- ============================================================

-- §7.1 TB_SAFETY_GUIDE_CACHE (MOFA API 응답 캐시)
CREATE TABLE IF NOT EXISTS tb_safety_guide_cache (
    id              BIGSERIAL PRIMARY KEY,
    country_code    VARCHAR(3)   NOT NULL,
    data_type       VARCHAR(30)  NOT NULL,
    content         JSONB        NOT NULL,
    fetched_at      TIMESTAMPTZ  NOT NULL DEFAULT now(),
    expires_at      TIMESTAMPTZ  NOT NULL,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT uq_cache_country_type UNIQUE (country_code, data_type)
);

CREATE INDEX IF NOT EXISTS idx_safety_cache_country ON tb_safety_guide_cache (country_code);
CREATE INDEX IF NOT EXISTS idx_safety_cache_expires ON tb_safety_guide_cache (expires_at);

-- §7.2 TB_COUNTRY_EMERGENCY_CONTACT (국가별 긴급연락처)
-- NOTE: 기존 tb_emergency_contact (01-schema, 도메인 A)는 사용자 개인 비상연락처.
--       이 테이블은 국가별 긴급 서비스 번호 (경찰·소방·영사관 등).
CREATE TABLE IF NOT EXISTS tb_country_emergency_contact (
    id              BIGSERIAL PRIMARY KEY,
    country_code    VARCHAR(3)   NOT NULL,
    contact_type    VARCHAR(20)  NOT NULL,
    phone_number    VARCHAR(30)  NOT NULL,
    description_ko  VARCHAR(100),
    is_24h          BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_country_emergency_contact_country ON tb_country_emergency_contact (country_code);

-- 고정 시드: 영사콜센터 (24시간)
INSERT INTO tb_country_emergency_contact (country_code, contact_type, phone_number, description_ko, is_24h)
VALUES ('ALL', 'consulate_call_center', '+82-2-3210-0404', '영사콜센터 (24시간)', TRUE)
ON CONFLICT DO NOTHING;
