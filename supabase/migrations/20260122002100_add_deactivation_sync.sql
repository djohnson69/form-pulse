-- Migration: Add deactivation synchronization across profiles, org_members, and employees
-- Handles:
-- 1. Adding is_active, deactivated_at, deactivated_by columns to org_members
-- 2. Syncing is_active changes from profiles to org_members and employees
-- 3. Maintaining audit trail of who deactivated and when

-- Add deactivation tracking columns to org_members
ALTER TABLE org_members ADD COLUMN IF NOT EXISTS is_active boolean NOT NULL DEFAULT true;
ALTER TABLE org_members ADD COLUMN IF NOT EXISTS deactivated_at timestamptz;
ALTER TABLE org_members ADD COLUMN IF NOT EXISTS deactivated_by uuid REFERENCES auth.users(id);

-- Create index for active member lookups (partial index for performance)
CREATE INDEX IF NOT EXISTS idx_org_members_active
  ON org_members(org_id, is_active)
  WHERE is_active = true;

-- Trigger to sync profile deactivation to org_members and employees
CREATE OR REPLACE FUNCTION sync_user_deactivation()
RETURNS TRIGGER AS $$
BEGIN
  -- When is_active changes
  IF OLD.is_active IS DISTINCT FROM NEW.is_active THEN
    -- Update org_members
    UPDATE org_members
    SET
      is_active = NEW.is_active,
      deactivated_at = CASE WHEN NEW.is_active = false THEN NOW() ELSE NULL END,
      deactivated_by = CASE WHEN NEW.is_active = false THEN auth.uid() ELSE NULL END
    WHERE user_id = NEW.id AND org_id = NEW.org_id;

    -- Update employees (if record exists - only for internal roles)
    UPDATE employees
    SET
      is_active = NEW.is_active,
      metadata = CASE
        WHEN NEW.is_active = false THEN
          COALESCE(metadata, '{}'::jsonb) || jsonb_build_object(
            'deactivatedAt', NOW(),
            'deactivatedBy', COALESCE(auth.uid()::text, 'system'),
            'deactivatedReason', 'user_deactivated'
          )
        ELSE
          -- Remove deactivation metadata when reactivating
          COALESCE(metadata, '{}'::jsonb) - 'deactivatedAt' - 'deactivatedBy' - 'deactivatedReason'
            || jsonb_build_object('reactivatedAt', NOW())
      END,
      updated_at = NOW()
    WHERE user_id = NEW.id AND org_id = NEW.org_id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for is_active changes on profiles
DROP TRIGGER IF EXISTS sync_user_deactivation_trigger ON profiles;
CREATE TRIGGER sync_user_deactivation_trigger
  AFTER UPDATE OF is_active ON profiles
  FOR EACH ROW
  EXECUTE FUNCTION sync_user_deactivation();

-- Backfill org_members.is_active from profiles for existing records
UPDATE org_members om
SET is_active = p.is_active
FROM profiles p
WHERE om.user_id = p.id
  AND om.org_id = p.org_id
  AND om.is_active IS DISTINCT FROM p.is_active;
