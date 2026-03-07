-- 초대코드 아키텍처 원칙 정합성 수정 (#2, #6)
-- 기준 문서: 23_T3_초대코드_원칙 v1.1 §13.1

-- #2: 컬럼명 변경 used_count → current_uses (§13.1 정합)
ALTER TABLE tb_invite_code RENAME COLUMN used_count TO current_uses;

-- #6: NOT NULL 제약 추가 (§13.1: code, target_role, expires_at 모두 NOT NULL)
-- 기존 데이터에 NULL이 있을 수 있으므로 안전 처리
UPDATE tb_invite_code SET code = 'INVALID' WHERE code IS NULL;
UPDATE tb_invite_code SET target_role = 'crew' WHERE target_role IS NULL;
UPDATE tb_invite_code SET expires_at = NOW() WHERE expires_at IS NULL;

ALTER TABLE tb_invite_code ALTER COLUMN code SET NOT NULL;
ALTER TABLE tb_invite_code ALTER COLUMN target_role SET NOT NULL;
ALTER TABLE tb_invite_code ALTER COLUMN expires_at SET NOT NULL;
