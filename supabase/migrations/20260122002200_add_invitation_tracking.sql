-- Migration: Add invitation acceptance tracking
-- Handles:
-- 1. Updating user_invitations.status to 'accepted' when user confirms email
-- 2. Setting accepted_at timestamp
-- 3. Providing function to expire old invitations (for cron job)

-- Trigger to detect invitation acceptance when user confirms email
-- Now also checks if the invitation has expired
CREATE OR REPLACE FUNCTION track_invitation_acceptance()
RETURNS TRIGGER AS $$
BEGIN
  -- When email_confirmed_at is set (user confirmed their email)
  IF NEW.email_confirmed_at IS NOT NULL AND (OLD.email_confirmed_at IS NULL OR OLD.email_confirmed_at IS DISTINCT FROM NEW.email_confirmed_at) THEN
    -- Mark non-expired pending invitations as accepted
    UPDATE user_invitations
    SET
      status = 'accepted',
      accepted_at = NOW()
    WHERE email = NEW.email
      AND status = 'pending'
      AND (expires_at IS NULL OR expires_at > NOW());

    -- Mark expired pending invitations as expired
    UPDATE user_invitations
    SET
      status = 'expired'
    WHERE email = NEW.email
      AND status = 'pending'
      AND expires_at IS NOT NULL
      AND expires_at <= NOW();
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop existing trigger if it exists (to handle re-running migration)
DROP TRIGGER IF EXISTS track_invitation_acceptance_trigger ON auth.users;

-- Create trigger for email confirmation updates
CREATE TRIGGER track_invitation_acceptance_trigger
  AFTER UPDATE OF email_confirmed_at ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION track_invitation_acceptance();

-- Also track when a new user signs up with confirmed email
-- (for users who were invited and confirm during signup)
-- Now also checks if the invitation has expired
CREATE OR REPLACE FUNCTION track_invitation_on_signup()
RETURNS TRIGGER AS $$
BEGIN
  -- Mark non-expired pending invitations as accepted
  IF NEW.email_confirmed_at IS NOT NULL THEN
    UPDATE user_invitations
    SET
      status = 'accepted',
      accepted_at = COALESCE(NEW.email_confirmed_at, NOW())
    WHERE email = NEW.email
      AND status = 'pending'
      AND (expires_at IS NULL OR expires_at > NOW());

    -- Mark expired pending invitations as expired
    UPDATE user_invitations
    SET
      status = 'expired'
    WHERE email = NEW.email
      AND status = 'pending'
      AND expires_at IS NOT NULL
      AND expires_at <= NOW();
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS track_invitation_on_signup_trigger ON auth.users;

-- Create trigger for new user signups
CREATE TRIGGER track_invitation_on_signup_trigger
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION track_invitation_on_signup();

-- Function to expire old invitations (call via pg_cron or scheduled job)
-- Returns the number of invitations that were expired
CREATE OR REPLACE FUNCTION expire_old_invitations()
RETURNS integer AS $$
DECLARE
  expired_count integer;
BEGIN
  UPDATE user_invitations
  SET status = 'expired'
  WHERE status = 'pending'
    AND expires_at < NOW();

  GET DIAGNOSTICS expired_count = ROW_COUNT;
  RETURN expired_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission to authenticated users (for manual expiration calls)
-- Note: In production, this would typically be called by a cron job
GRANT EXECUTE ON FUNCTION expire_old_invitations() TO authenticated;

-- Backfill: Mark any already-accepted invitations where the user has confirmed their email
UPDATE user_invitations ui
SET
  status = 'accepted',
  accepted_at = u.email_confirmed_at
FROM auth.users u
WHERE ui.email = u.email
  AND ui.status = 'pending'
  AND u.email_confirmed_at IS NOT NULL;

-- Backfill: Mark any expired invitations
SELECT expire_old_invitations();
