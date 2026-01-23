-- Migration: Add transaction wrapper for org onboarding
-- This ensures all critical org creation operations succeed or fail atomically
-- Prevents orphaned data from partial failures

-- Create the transaction wrapper function
CREATE OR REPLACE FUNCTION create_org_with_owner(
  p_org_name text,
  p_display_name text,
  p_industry text,
  p_company_size text,
  p_website text,
  p_phone text,
  p_address_line1 text,
  p_address_line2 text,
  p_city text,
  p_state text,
  p_postal_code text,
  p_country text,
  p_tax_id text,
  p_user_id uuid,
  p_user_email text,
  p_first_name text,
  p_last_name text,
  p_user_phone text,
  p_plan_name text,
  p_billing_cycle text,
  p_trial_days int DEFAULT 14
) RETURNS jsonb AS $$
DECLARE
  v_org_id uuid;
  v_plan_id uuid;
  v_trial_start timestamptz;
  v_trial_end timestamptz;
  v_now timestamptz;
BEGIN
  v_now := NOW();
  v_trial_start := v_now;
  v_trial_end := v_now + (p_trial_days || ' days')::interval;

  -- 1. Create organization
  INSERT INTO orgs (
    name,
    display_name,
    industry,
    company_size,
    website,
    phone,
    address_line1,
    address_line2,
    city,
    state,
    postal_code,
    country,
    tax_id,
    onboarding_completed,
    onboarding_step,
    settings,
    metadata,
    is_active,
    updated_at
  ) VALUES (
    p_org_name,
    p_display_name,
    p_industry,
    p_company_size,
    p_website,
    p_phone,
    p_address_line1,
    p_address_line2,
    p_city,
    p_state,
    p_postal_code,
    COALESCE(p_country, 'US'),
    p_tax_id,
    true,
    6,
    '{}',
    '{}',
    true,
    v_now
  ) RETURNING id INTO v_org_id;

  -- 2. Create org membership for owner
  INSERT INTO org_members (org_id, user_id, role, is_active)
  VALUES (v_org_id, p_user_id, 'owner', true);

  -- 3. Create/update profile for owner
  INSERT INTO profiles (
    id,
    org_id,
    email,
    first_name,
    last_name,
    phone,
    role,
    is_active,
    updated_at
  ) VALUES (
    p_user_id,
    v_org_id,
    p_user_email,
    NULLIF(p_first_name, ''),
    NULLIF(p_last_name, ''),
    NULLIF(p_user_phone, ''),
    'superadmin',
    true,
    v_now
  )
  ON CONFLICT (id) DO UPDATE SET
    org_id = v_org_id,
    role = 'superadmin',
    is_active = true,
    updated_at = v_now;

  -- 4. Create employee record for owner
  INSERT INTO employees (
    org_id,
    user_id,
    first_name,
    last_name,
    email,
    position,
    department,
    hire_date,
    is_active,
    metadata
  ) VALUES (
    v_org_id,
    p_user_id,
    NULLIF(p_first_name, ''),
    NULLIF(p_last_name, ''),
    p_user_email,
    'Owner / CEO',
    'Executive',
    v_now,
    true,
    jsonb_build_object(
      'role', 'superadmin',
      'isFounder', true,
      'isManager', true,
      'isSupervisor', true
    )
  )
  ON CONFLICT (org_id, user_id) DO UPDATE SET
    first_name = COALESCE(EXCLUDED.first_name, employees.first_name),
    last_name = COALESCE(EXCLUDED.last_name, employees.last_name),
    updated_at = v_now;

  -- 5. Get plan ID if exists
  SELECT id INTO v_plan_id
  FROM subscription_plans
  WHERE name = p_plan_name AND is_active = true
  LIMIT 1;

  -- 6. Create subscription with trial
  INSERT INTO subscriptions (
    org_id,
    plan_id,
    status,
    billing_cycle,
    trial_start,
    trial_end,
    current_period_start,
    current_period_end,
    created_at,
    updated_at
  ) VALUES (
    v_org_id,
    v_plan_id,
    'trialing',
    COALESCE(p_billing_cycle, 'monthly'),
    v_trial_start,
    v_trial_end,
    v_trial_start,
    v_trial_end,
    v_now,
    v_now
  );

  -- Return success with org details
  RETURN jsonb_build_object(
    'success', true,
    'org_id', v_org_id,
    'plan_id', v_plan_id,
    'trial_start', v_trial_start,
    'trial_end', v_trial_end
  );

EXCEPTION WHEN OTHERS THEN
  -- Transaction will automatically rollback
  RAISE EXCEPTION 'Org creation failed: %', SQLERRM;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute to authenticated users (they need to call this during signup)
GRANT EXECUTE ON FUNCTION create_org_with_owner(
  text, text, text, text, text, text, text, text, text, text, text, text, text,
  uuid, text, text, text, text, text, text, int
) TO authenticated;

-- Also create a function for adding billing info (can fail independently)
CREATE OR REPLACE FUNCTION add_org_billing_info(
  p_org_id uuid,
  p_billing_email text,
  p_billing_name text,
  p_address_line1 text,
  p_address_line2 text,
  p_city text,
  p_state text,
  p_postal_code text,
  p_country text,
  p_tax_id text,
  p_po_required boolean,
  p_stripe_customer_id text,
  p_stripe_payment_method_id text
) RETURNS jsonb AS $$
BEGIN
  INSERT INTO billing_info (
    org_id,
    billing_email,
    billing_name,
    address_line1,
    address_line2,
    city,
    state,
    postal_code,
    country,
    tax_id,
    po_required,
    stripe_customer_id,
    stripe_payment_method_id,
    created_at,
    updated_at
  ) VALUES (
    p_org_id,
    p_billing_email,
    p_billing_name,
    p_address_line1,
    p_address_line2,
    p_city,
    p_state,
    p_postal_code,
    COALESCE(p_country, 'US'),
    p_tax_id,
    COALESCE(p_po_required, false),
    p_stripe_customer_id,
    p_stripe_payment_method_id,
    NOW(),
    NOW()
  )
  ON CONFLICT (org_id) DO UPDATE SET
    billing_email = EXCLUDED.billing_email,
    billing_name = EXCLUDED.billing_name,
    stripe_customer_id = COALESCE(EXCLUDED.stripe_customer_id, billing_info.stripe_customer_id),
    stripe_payment_method_id = COALESCE(EXCLUDED.stripe_payment_method_id, billing_info.stripe_payment_method_id),
    updated_at = NOW();

  RETURN jsonb_build_object('success', true);
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION add_org_billing_info(
  uuid, text, text, text, text, text, text, text, text, text, boolean, text, text
) TO authenticated;
