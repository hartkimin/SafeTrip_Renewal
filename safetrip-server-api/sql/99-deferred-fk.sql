-- ============================================================
-- SafeTrip DB Schema v3.4.1
-- 99: 후행 FK / 순환 참조 해소
-- 기준 문서: 07_T2_DB_설계_및_관계_v3_4.md
-- ============================================================
-- ⚠ 이 파일은 모든 테이블 생성 이후 마지막에 실행해야 합니다.

-- ──────────────────────────────────────────────
-- 1) tb_user.guardian_consent_id → tb_minor_consent.consent_id
--    (01-schema → 08-schema)
-- ──────────────────────────────────────────────
ALTER TABLE tb_user
    ADD CONSTRAINT fk_user_guardian_consent
    FOREIGN KEY (guardian_consent_id)
    REFERENCES tb_minor_consent(consent_id)
    ON DELETE SET NULL;

-- ──────────────────────────────────────────────
-- 2) tb_trip.b2b_contract_id → tb_b2b_contract.contract_id
--    (01-schema → 10-schema)
-- ──────────────────────────────────────────────
ALTER TABLE tb_trip
    ADD CONSTRAINT fk_trip_b2b_contract
    FOREIGN KEY (b2b_contract_id)
    REFERENCES tb_b2b_contract(contract_id)
    ON DELETE SET NULL;

-- ──────────────────────────────────────────────
-- 3) tb_guardian.payment_id → tb_payment.payment_id
--    (02-schema → 10-schema)
-- ──────────────────────────────────────────────
ALTER TABLE tb_guardian
    ADD CONSTRAINT fk_guardian_payment
    FOREIGN KEY (payment_id)
    REFERENCES tb_payment(payment_id)
    ON DELETE SET NULL;

-- ──────────────────────────────────────────────
-- 4) tb_guardian_link.payment_id → tb_payment.payment_id
--    (02-schema → 10-schema)
-- ──────────────────────────────────────────────
ALTER TABLE tb_guardian_link
    ADD CONSTRAINT fk_guardian_link_payment
    FOREIGN KEY (payment_id)
    REFERENCES tb_payment(payment_id)
    ON DELETE SET NULL;

-- ──────────────────────────────────────────────
-- 5) tb_invite_code.b2b_batch_id → tb_b2b_invite_batch.batch_id
--    (01-schema → 10-schema)
-- ──────────────────────────────────────────────
ALTER TABLE tb_invite_code
    ADD CONSTRAINT fk_invite_code_b2b_batch
    FOREIGN KEY (b2b_batch_id)
    REFERENCES tb_b2b_invite_batch(batch_id)
    ON DELETE SET NULL;

-- ──────────────────────────────────────────────
-- 6) tb_minor_consent.b2b_contract_id → tb_b2b_contract.contract_id
--    (08-schema → 10-schema)
-- ──────────────────────────────────────────────
ALTER TABLE tb_minor_consent
    ADD CONSTRAINT fk_minor_consent_b2b_contract
    FOREIGN KEY (b2b_contract_id)
    REFERENCES tb_b2b_contract(contract_id)
    ON DELETE SET NULL;
