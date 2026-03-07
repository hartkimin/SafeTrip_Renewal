-- 11-migration-profile-columns.sql
-- Profile Screen P0~P2: Add profile columns to tb_user (DOC-T3-PRF-027 §11)

-- New columns
ALTER TABLE tb_user ADD COLUMN IF NOT EXISTS avatar_id VARCHAR(30);
ALTER TABLE tb_user ADD COLUMN IF NOT EXISTS privacy_level VARCHAR(20) DEFAULT 'standard';
ALTER TABLE tb_user ADD COLUMN IF NOT EXISTS image_review_status VARCHAR(20) DEFAULT 'none';
ALTER TABLE tb_user ADD COLUMN IF NOT EXISTS onboarding_completed BOOLEAN DEFAULT FALSE;
ALTER TABLE tb_user ADD COLUMN IF NOT EXISTS deletion_reason TEXT;

-- Migrate existing location_sharing_mode → privacy_level
UPDATE tb_user SET privacy_level = CASE
  WHEN location_sharing_mode = 'always' THEN 'safety_first'
  WHEN location_sharing_mode = 'in_trip' THEN 'standard'
  WHEN location_sharing_mode = 'off' THEN 'privacy_first'
  ELSE 'standard'
END WHERE privacy_level IS NULL OR privacy_level = 'standard';

-- Sync onboarding_completed from is_onboarding_complete
UPDATE tb_user SET onboarding_completed = COALESCE(is_onboarding_complete, FALSE);

-- Nickname uniqueness (display_name used as nickname, §3.1)
CREATE UNIQUE INDEX IF NOT EXISTS idx_user_nickname_unique
  ON tb_user(display_name) WHERE deleted_at IS NULL AND display_name IS NOT NULL AND display_name != '';
