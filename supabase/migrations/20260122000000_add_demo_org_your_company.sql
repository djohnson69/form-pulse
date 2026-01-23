-- Migration: Add demo organization "Your Company" with 21 test users
-- For local development only - creates auth.users directly
-- All users have password: password123

-- ============================================================================
-- 1. CREATE THE ORGANIZATION
-- ============================================================================

INSERT INTO orgs (
  id,
  name,
  display_name,
  industry,
  company_size,
  website,
  phone,
  address_line1,
  city,
  state,
  postal_code,
  country,
  onboarding_completed,
  onboarding_step,
  created_at,
  updated_at
) VALUES (
  '11111111-1111-1111-1111-111111111111',
  'Your Company',
  'Your Company Inc.',
  'technology',
  '51-200',
  'https://yourcompany.test',
  '+1-555-000-0000',
  '123 Demo Street',
  'San Francisco',
  'CA',
  '94102',
  'US',
  true,
  6,
  NOW(),
  NOW()
) ON CONFLICT (id) DO NOTHING;

-- ============================================================================
-- 2. CREATE AUTH USERS (21 total)
-- ============================================================================

-- Helper function to create users with proper password hashing
DO $$
DECLARE
  demo_users JSONB := '[
    {"id": "22222222-2222-2222-2222-222222222201", "email": "owner@yourcompany.test", "first_name": "Alex", "last_name": "Owner", "role": "super_admin", "org_role": "owner"},
    {"id": "22222222-2222-2222-2222-222222222202", "email": "admin@yourcompany.test", "first_name": "Jordan", "last_name": "Admin", "role": "admin", "org_role": "admin"},
    {"id": "22222222-2222-2222-2222-222222222203", "email": "manager1@yourcompany.test", "first_name": "Sam", "last_name": "Manager", "role": "manager", "org_role": "admin"},
    {"id": "22222222-2222-2222-2222-222222222204", "email": "manager2@yourcompany.test", "first_name": "Pat", "last_name": "Director", "role": "manager", "org_role": "admin"},
    {"id": "22222222-2222-2222-2222-222222222205", "email": "supervisor1@yourcompany.test", "first_name": "Taylor", "last_name": "Supervisor", "role": "supervisor", "org_role": "member"},
    {"id": "22222222-2222-2222-2222-222222222206", "email": "supervisor2@yourcompany.test", "first_name": "Robin", "last_name": "Lead", "role": "supervisor", "org_role": "member"},
    {"id": "22222222-2222-2222-2222-222222222207", "email": "supervisor3@yourcompany.test", "first_name": "Drew", "last_name": "Foreman", "role": "supervisor", "org_role": "member"},
    {"id": "22222222-2222-2222-2222-222222222208", "email": "employee1@yourcompany.test", "first_name": "Casey", "last_name": "Worker", "role": "employee", "org_role": "member"},
    {"id": "22222222-2222-2222-2222-222222222209", "email": "employee2@yourcompany.test", "first_name": "Avery", "last_name": "Smith", "role": "employee", "org_role": "member"},
    {"id": "22222222-2222-2222-2222-222222222210", "email": "employee3@yourcompany.test", "first_name": "Blake", "last_name": "Johnson", "role": "employee", "org_role": "member"},
    {"id": "22222222-2222-2222-2222-222222222211", "email": "employee4@yourcompany.test", "first_name": "Charlie", "last_name": "Williams", "role": "employee", "org_role": "member"},
    {"id": "22222222-2222-2222-2222-222222222212", "email": "employee5@yourcompany.test", "first_name": "Dakota", "last_name": "Brown", "role": "employee", "org_role": "member"},
    {"id": "22222222-2222-2222-2222-222222222213", "email": "employee6@yourcompany.test", "first_name": "Emery", "last_name": "Davis", "role": "employee", "org_role": "member"},
    {"id": "22222222-2222-2222-2222-222222222214", "email": "employee7@yourcompany.test", "first_name": "Finley", "last_name": "Miller", "role": "employee", "org_role": "member"},
    {"id": "22222222-2222-2222-2222-222222222215", "email": "employee8@yourcompany.test", "first_name": "Gray", "last_name": "Wilson", "role": "employee", "org_role": "member"},
    {"id": "22222222-2222-2222-2222-222222222216", "email": "maintenance1@yourcompany.test", "first_name": "Morgan", "last_name": "Tech", "role": "maintenance", "org_role": "member"},
    {"id": "22222222-2222-2222-2222-222222222217", "email": "maintenance2@yourcompany.test", "first_name": "Reese", "last_name": "Mechanic", "role": "maintenance", "org_role": "member"},
    {"id": "22222222-2222-2222-2222-222222222218", "email": "client1@yourcompany.test", "first_name": "Riley", "last_name": "Client", "role": "client", "org_role": "member"},
    {"id": "22222222-2222-2222-2222-222222222219", "email": "client2@yourcompany.test", "first_name": "Sage", "last_name": "Customer", "role": "client", "org_role": "member"},
    {"id": "22222222-2222-2222-2222-222222222220", "email": "vendor1@yourcompany.test", "first_name": "Quinn", "last_name": "Supplier", "role": "vendor", "org_role": "member"},
    {"id": "22222222-2222-2222-2222-222222222221", "email": "vendor2@yourcompany.test", "first_name": "Parker", "last_name": "Contractor", "role": "vendor", "org_role": "member"}
  ]';
  rec JSONB;
  v_id UUID;
  v_email TEXT;
  v_first_name TEXT;
  v_last_name TEXT;
  v_role TEXT;
  v_org_role TEXT;
  v_encrypted_pw TEXT;
BEGIN
  -- Generate encrypted password once (same for all users)
  -- Use extensions.crypt for production Supabase, fallback to public.crypt for local
  v_encrypted_pw := extensions.crypt('password123', extensions.gen_salt('bf'));

  FOR rec IN SELECT * FROM jsonb_array_elements(demo_users)
  LOOP
    v_id := (rec->>'id')::UUID;
    v_email := rec->>'email';
    v_first_name := rec->>'first_name';
    v_last_name := rec->>'last_name';
    v_role := rec->>'role';
    v_org_role := rec->>'org_role';

    -- Insert into auth.users
    INSERT INTO auth.users (
      id,
      instance_id,
      aud,
      role,
      email,
      encrypted_password,
      email_confirmed_at,
      raw_app_meta_data,
      raw_user_meta_data,
      created_at,
      updated_at,
      confirmation_token,
      email_change,
      email_change_token_new,
      recovery_token
    ) VALUES (
      v_id,
      '00000000-0000-0000-0000-000000000000',
      'authenticated',
      'authenticated',
      v_email,
      v_encrypted_pw,
      NOW(),
      '{"provider":"email","providers":["email"]}',
      jsonb_build_object('first_name', v_first_name, 'last_name', v_last_name),
      NOW(),
      NOW(),
      '',
      '',
      '',
      ''
    ) ON CONFLICT (id) DO NOTHING;

    -- Insert into auth.identities (REQUIRED for login to work)
    INSERT INTO auth.identities (
      id,
      user_id,
      identity_data,
      provider,
      provider_id,
      last_sign_in_at,
      created_at,
      updated_at
    ) VALUES (
      v_id,
      v_id,
      jsonb_build_object('sub', v_id::TEXT, 'email', v_email),
      'email',
      v_id::TEXT,
      NOW(),
      NOW(),
      NOW()
    ) ON CONFLICT (id) DO NOTHING;

    -- Insert into profiles
    INSERT INTO profiles (
      id,
      org_id,
      email,
      first_name,
      last_name,
      role,
      is_active,
      created_at,
      updated_at
    ) VALUES (
      v_id,
      '11111111-1111-1111-1111-111111111111',
      v_email,
      v_first_name,
      v_last_name,
      v_role,
      true,
      NOW(),
      NOW()
    ) ON CONFLICT (id) DO NOTHING;

    -- Insert into org_members
    INSERT INTO org_members (
      org_id,
      user_id,
      role,
      created_at
    ) VALUES (
      '11111111-1111-1111-1111-111111111111',
      v_id,
      v_org_role,
      NOW()
    ) ON CONFLICT (org_id, user_id) DO NOTHING;

  END LOOP;
END $$;

-- ============================================================================
-- 3. CREATE SUBSCRIPTION (14-day trial on Starter plan)
-- ============================================================================

INSERT INTO subscriptions (
  id,
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
)
SELECT
  gen_random_uuid(),
  '11111111-1111-1111-1111-111111111111',
  sp.id,
  'trialing',
  'monthly',
  NOW(),
  NOW() + INTERVAL '14 days',
  NOW(),
  NOW() + INTERVAL '14 days',
  NOW(),
  NOW()
FROM subscription_plans sp
WHERE sp.name = 'starter'
ON CONFLICT (org_id) DO NOTHING;

-- ============================================================================
-- 4. CREATE SAMPLE FORMS
-- ============================================================================

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, fields, metadata, created_at, updated_at)
VALUES
  (
    'yc-safety-checklist',
    '11111111-1111-1111-1111-111111111111',
    'Daily Safety Checklist',
    'Morning safety walk-through for all team leads',
    'Safety',
    ARRAY['safety', 'daily', 'checklist'],
    true,
    '1.0.0',
    '22222222-2222-2222-2222-222222222201',
    '[{"id":"date","label":"Date","type":"date","isRequired":true,"order":1},{"id":"shift","label":"Shift","type":"radio","options":["Morning","Afternoon","Night"],"isRequired":true,"order":2},{"id":"areaInspected","label":"Area inspected","type":"text","isRequired":true,"order":3},{"id":"hazardsFound","label":"Hazards found","type":"textarea","order":4},{"id":"ppeCompliance","label":"PPE compliance check","type":"checkbox","options":["Hard hats","Safety vests","Steel-toe boots","Eye protection","Gloves"],"order":5},{"id":"photos","label":"Photo documentation","type":"photo","order":6},{"id":"signature","label":"Inspector signature","type":"signature","isRequired":true,"order":7}]'::jsonb,
    '{"riskLevel":"medium"}'::jsonb,
    NOW(),
    NOW()
  ),
  (
    'yc-incident-report',
    '11111111-1111-1111-1111-111111111111',
    'Incident Report Form',
    'Document workplace incidents and near-misses',
    'Safety',
    ARRAY['safety', 'incident', 'report'],
    true,
    '1.0.0',
    '22222222-2222-2222-2222-222222222201',
    '[{"id":"incidentDate","label":"Date of incident","type":"datetime","isRequired":true,"order":1},{"id":"incidentType","label":"Incident type","type":"dropdown","options":["Injury","Near-miss","Property damage","Environmental","Other"],"isRequired":true,"order":2},{"id":"location","label":"Location","type":"location","isRequired":true,"order":3},{"id":"description","label":"Description of incident","type":"textarea","isRequired":true,"order":4},{"id":"witnesses","label":"Witnesses","type":"text","order":5},{"id":"immediateActions","label":"Immediate actions taken","type":"textarea","order":6},{"id":"photos","label":"Photos","type":"photo","order":7},{"id":"reporterSignature","label":"Reporter signature","type":"signature","isRequired":true,"order":8}]'::jsonb,
    '{"requiresReview":true}'::jsonb,
    NOW(),
    NOW()
  ),
  (
    'yc-equipment-inspection',
    '11111111-1111-1111-1111-111111111111',
    'Equipment Inspection',
    'Pre-use equipment inspection checklist',
    'Operations',
    ARRAY['equipment', 'inspection', 'maintenance'],
    true,
    '1.0.0',
    '22222222-2222-2222-2222-222222222201',
    '[{"id":"equipmentId","label":"Equipment ID / Barcode","type":"barcode","isRequired":true,"order":1},{"id":"equipmentType","label":"Equipment type","type":"dropdown","options":["Forklift","Crane","Loader","Truck","Power tools","Other"],"isRequired":true,"order":2},{"id":"condition","label":"Overall condition","type":"radio","options":["Excellent","Good","Fair","Needs repair","Out of service"],"isRequired":true,"order":3},{"id":"checklistItems","label":"Inspection checklist","type":"checkbox","options":["Fluid levels OK","No leaks","Safety features working","Tires/tracks OK","Lights working","Horn working","Seat belt functional"],"order":4},{"id":"issues","label":"Issues found","type":"textarea","order":5},{"id":"photos","label":"Condition photos","type":"photo","order":6},{"id":"operatorSignature","label":"Operator signature","type":"signature","isRequired":true,"order":7}]'::jsonb,
    '{}'::jsonb,
    NOW(),
    NOW()
  ),
  (
    'yc-timesheet',
    '11111111-1111-1111-1111-111111111111',
    'Weekly Timesheet',
    'Employee weekly time tracking',
    'HR',
    ARRAY['hr', 'timesheet', 'payroll'],
    true,
    '1.0.0',
    '22222222-2222-2222-2222-222222222201',
    '[{"id":"weekEnding","label":"Week ending date","type":"date","isRequired":true,"order":1},{"id":"employeeName","label":"Employee name","type":"text","isRequired":true,"order":2},{"id":"department","label":"Department","type":"dropdown","options":["Operations","Maintenance","Safety","Admin","Management"],"isRequired":true,"order":3},{"id":"mondayHours","label":"Monday hours","type":"number","order":4},{"id":"tuesdayHours","label":"Tuesday hours","type":"number","order":5},{"id":"wednesdayHours","label":"Wednesday hours","type":"number","order":6},{"id":"thursdayHours","label":"Thursday hours","type":"number","order":7},{"id":"fridayHours","label":"Friday hours","type":"number","order":8},{"id":"saturdayHours","label":"Saturday hours","type":"number","order":9},{"id":"sundayHours","label":"Sunday hours","type":"number","order":10},{"id":"notes","label":"Notes","type":"textarea","order":11},{"id":"employeeSignature","label":"Employee signature","type":"signature","isRequired":true,"order":12}]'::jsonb,
    '{"requiresSupervisor":true}'::jsonb,
    NOW(),
    NOW()
  )
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  fields = EXCLUDED.fields,
  metadata = EXCLUDED.metadata,
  updated_at = NOW();
