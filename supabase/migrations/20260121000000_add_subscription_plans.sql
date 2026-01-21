-- Subscription plans table (Starter, Pro, Enterprise)
-- Used for Stripe billing integration

CREATE TABLE IF NOT EXISTS subscription_plans (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL UNIQUE,                    -- 'starter', 'pro', 'enterprise'
  display_name text NOT NULL,                   -- 'Starter', 'Professional', 'Enterprise'
  description text,

  -- Pricing (in USD cents)
  price_monthly integer NOT NULL DEFAULT 0,
  price_yearly integer NOT NULL DEFAULT 0,

  -- Stripe integration
  stripe_price_id_monthly text,
  stripe_price_id_yearly text,
  stripe_product_id text,

  -- Feature limits
  max_users integer NOT NULL DEFAULT 5,
  max_storage_gb integer NOT NULL DEFAULT 10,
  max_forms integer NOT NULL DEFAULT 10,
  max_submissions_per_month integer NOT NULL DEFAULT 1000,

  -- Feature flags
  features jsonb NOT NULL DEFAULT '{}'::jsonb,

  -- Metadata
  is_active boolean NOT NULL DEFAULT true,
  sort_order integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- Insert default plans
-- Pricing: ~$30/user effective, flat monthly with user tiers
INSERT INTO subscription_plans (name, display_name, description, price_monthly, price_yearly, max_users, max_storage_gb, max_forms, max_submissions_per_month, features, sort_order)
VALUES
  (
    'starter',
    'Starter',
    'Perfect for small teams getting started',
    29900,   -- $299/month
    299000,  -- $2,990/year (2 months free)
    10,      -- 10 users included (~$30/user)
    25,
    25,
    5000,
    '{"analytics": false, "custom_branding": false, "api_access": false, "priority_support": false, "sso": false, "audit_logs": false, "advanced_permissions": false}'::jsonb,
    1
  ),
  (
    'pro',
    'Professional',
    'For growing teams that need more power',
    59900,   -- $599/month
    599000,  -- $5,990/year (2 months free)
    25,      -- 25 users included (~$24/user)
    100,
    100,
    25000,
    '{"analytics": true, "custom_branding": true, "api_access": true, "priority_support": false, "sso": false, "audit_logs": true, "advanced_permissions": true}'::jsonb,
    2
  ),
  (
    'enterprise',
    'Enterprise',
    'For large organizations with advanced needs',
    119900,  -- $1,199/month
    1199000, -- $11,990/year (2 months free)
    50,      -- 50 users included (~$24/user)
    500,
    -1,      -- Unlimited forms
    -1,      -- Unlimited submissions
    '{"analytics": true, "custom_branding": true, "api_access": true, "priority_support": true, "sso": true, "audit_logs": true, "advanced_permissions": true}'::jsonb,
    3
  )
ON CONFLICT (name) DO UPDATE SET
  price_monthly = EXCLUDED.price_monthly,
  price_yearly = EXCLUDED.price_yearly,
  max_users = EXCLUDED.max_users,
  max_storage_gb = EXCLUDED.max_storage_gb,
  max_forms = EXCLUDED.max_forms,
  max_submissions_per_month = EXCLUDED.max_submissions_per_month,
  features = EXCLUDED.features;

-- Index for faster lookups
CREATE INDEX IF NOT EXISTS idx_subscription_plans_name ON subscription_plans(name);
CREATE INDEX IF NOT EXISTS idx_subscription_plans_active ON subscription_plans(is_active);

-- Enable RLS
ALTER TABLE subscription_plans ENABLE ROW LEVEL SECURITY;

-- Everyone can view active plans (for pricing page)
CREATE POLICY "Anyone can view active plans"
  ON subscription_plans FOR SELECT
  USING (is_active = true);
