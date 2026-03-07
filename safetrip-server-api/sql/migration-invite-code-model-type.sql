-- Migration: Add model_type column to tb_invite_code + b2b_batch_id index
-- Date: 2026-03-07
-- Related: Invite Code System Tasks 1-3

ALTER TABLE tb_invite_code
  ADD COLUMN IF NOT EXISTS model_type VARCHAR(20) DEFAULT 'direct';

CREATE INDEX IF NOT EXISTS idx_invite_code_batch
  ON tb_invite_code(b2b_batch_id) WHERE b2b_batch_id IS NOT NULL;
