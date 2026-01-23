-- Migration: Add performance indexes for common queries
-- These indexes improve query performance for RLS policies and common lookups

-- profiles indexes for RLS and lookups
CREATE INDEX IF NOT EXISTS idx_profiles_org_role ON profiles(org_id, role);
CREATE INDEX IF NOT EXISTS idx_profiles_email ON profiles(email);
CREATE INDEX IF NOT EXISTS idx_profiles_is_active ON profiles(is_active) WHERE is_active = true;

-- org_members indexes
CREATE INDEX IF NOT EXISTS idx_org_members_user_id ON org_members(user_id);
CREATE INDEX IF NOT EXISTS idx_org_members_org_user ON org_members(org_id, user_id);

-- user_invitations indexes
CREATE INDEX IF NOT EXISTS idx_user_invitations_org_email ON user_invitations(org_id, email);
CREATE INDEX IF NOT EXISTS idx_user_invitations_status_expires ON user_invitations(status, expires_at)
  WHERE status = 'pending';
CREATE INDEX IF NOT EXISTS idx_user_invitations_email ON user_invitations(email);

-- employees indexes
CREATE INDEX IF NOT EXISTS idx_employees_org_active ON employees(org_id, is_active)
  WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_employees_user_id ON employees(user_id);

-- Stripe webhook events table for idempotency (prevents duplicate processing)
CREATE TABLE IF NOT EXISTS stripe_webhook_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id text UNIQUE NOT NULL,
  event_type text NOT NULL,
  processed_at timestamptz DEFAULT NOW(),
  metadata jsonb DEFAULT '{}'::jsonb
);

CREATE INDEX IF NOT EXISTS idx_stripe_events_event_id ON stripe_webhook_events(event_id);
CREATE INDEX IF NOT EXISTS idx_stripe_events_processed_at ON stripe_webhook_events(processed_at);

-- Enable RLS on stripe_webhook_events (service role only)
ALTER TABLE stripe_webhook_events ENABLE ROW LEVEL SECURITY;

-- Only service role can access stripe webhook events
CREATE POLICY "Service role only for stripe_webhook_events"
  ON stripe_webhook_events
  FOR ALL
  USING (false)
  WITH CHECK (false);

-- Grant service role access
GRANT ALL ON stripe_webhook_events TO service_role;

COMMENT ON TABLE stripe_webhook_events IS 'Tracks processed Stripe webhook events to prevent duplicate processing';
COMMENT ON INDEX idx_stripe_events_event_id IS 'Fast lookup for idempotency check';
