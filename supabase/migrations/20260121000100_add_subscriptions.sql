-- Subscriptions table for tracking org subscriptions
-- Links organizations to their subscription plans

CREATE TABLE IF NOT EXISTS subscriptions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id uuid NOT NULL REFERENCES orgs(id) ON DELETE CASCADE,
  plan_id uuid NOT NULL REFERENCES subscription_plans(id),

  -- Subscription status
  status text NOT NULL DEFAULT 'trialing',  -- trialing, active, past_due, canceled, unpaid

  -- Billing cycle
  billing_cycle text NOT NULL DEFAULT 'monthly',  -- monthly, yearly

  -- Trial period
  trial_start timestamptz,
  trial_end timestamptz,

  -- Subscription period
  current_period_start timestamptz,
  current_period_end timestamptz,

  -- Stripe integration
  stripe_customer_id text,
  stripe_subscription_id text,

  -- Cancellation
  cancel_at_period_end boolean NOT NULL DEFAULT false,
  canceled_at timestamptz,

  -- Metadata
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),

  -- Each org can only have one subscription
  UNIQUE (org_id)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_subscriptions_org_id ON subscriptions(org_id);
CREATE INDEX IF NOT EXISTS idx_subscriptions_status ON subscriptions(status);
CREATE INDEX IF NOT EXISTS idx_subscriptions_stripe_customer ON subscriptions(stripe_customer_id);
CREATE INDEX IF NOT EXISTS idx_subscriptions_stripe_subscription ON subscriptions(stripe_subscription_id);
CREATE INDEX IF NOT EXISTS idx_subscriptions_trial_end ON subscriptions(trial_end);

-- Enable RLS
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;

-- Users can view their org's subscription
CREATE POLICY "Users can view their org subscription"
  ON subscriptions FOR SELECT
  USING (
    org_id IN (
      SELECT om.org_id FROM org_members om WHERE om.user_id = auth.uid()
    )
  );

-- Only admins can update subscription (status changes come from Stripe webhooks via service role)
CREATE POLICY "Admins can update subscription"
  ON subscriptions FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM org_members om
      WHERE om.org_id = subscriptions.org_id
        AND om.user_id = auth.uid()
        AND om.role IN ('owner', 'admin')
    )
  );

-- Function to check if org is on active subscription or trial
CREATE OR REPLACE FUNCTION is_org_subscription_active(p_org_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM subscriptions s
    WHERE s.org_id = p_org_id
      AND (
        s.status IN ('active', 'trialing')
        OR (s.status = 'trialing' AND s.trial_end > now())
      )
  );
END;
$$;

-- Function to check remaining trial days
CREATE OR REPLACE FUNCTION get_trial_days_remaining(p_org_id uuid)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_trial_end timestamptz;
BEGIN
  SELECT trial_end INTO v_trial_end
  FROM subscriptions
  WHERE org_id = p_org_id AND status = 'trialing';

  IF v_trial_end IS NULL THEN
    RETURN 0;
  END IF;

  RETURN GREATEST(0, EXTRACT(DAY FROM (v_trial_end - now()))::integer);
END;
$$;
