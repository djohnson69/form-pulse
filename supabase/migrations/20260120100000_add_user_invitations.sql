-- Track user invitations for org onboarding
-- Allows admins to view pending invitations, resend, or revoke

CREATE TABLE IF NOT EXISTS user_invitations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id uuid NOT NULL REFERENCES orgs(id) ON DELETE CASCADE,
  email text NOT NULL,
  role text NOT NULL,
  first_name text,
  last_name text,
  invited_by uuid REFERENCES auth.users(id),
  invited_at timestamptz NOT NULL DEFAULT now(),
  status text NOT NULL DEFAULT 'pending',  -- pending, accepted, expired, revoked
  accepted_at timestamptz,
  expires_at timestamptz DEFAULT (now() + interval '7 days'),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  UNIQUE (org_id, email)
);

-- Index for faster lookups
CREATE INDEX IF NOT EXISTS idx_user_invitations_org_status ON user_invitations(org_id, status);
CREATE INDEX IF NOT EXISTS idx_user_invitations_email ON user_invitations(email);

-- Enable RLS
ALTER TABLE user_invitations ENABLE ROW LEVEL SECURITY;

-- Users can view invitations in their organization
CREATE POLICY "Users can view invitations in their org"
  ON user_invitations FOR SELECT
  USING (
    org_id IN (
      SELECT om.org_id FROM org_members om WHERE om.user_id = auth.uid()
    )
  );

-- Admins can insert new invitations
CREATE POLICY "Admins can insert invitations"
  ON user_invitations FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM org_members om
      WHERE om.org_id = user_invitations.org_id
        AND om.user_id = auth.uid()
        AND om.role IN ('owner', 'admin')
    )
  );

-- Admins can update invitations (for resend/revoke)
CREATE POLICY "Admins can update invitations"
  ON user_invitations FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM org_members om
      WHERE om.org_id = user_invitations.org_id
        AND om.user_id = auth.uid()
        AND om.role IN ('owner', 'admin')
    )
  );

-- Admins can delete invitations
CREATE POLICY "Admins can delete invitations"
  ON user_invitations FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM org_members om
      WHERE om.org_id = user_invitations.org_id
        AND om.user_id = auth.uid()
        AND om.role IN ('owner', 'admin')
    )
  );
