-- After signing up in the app, run this to add your user to the demo org
-- Replace YOUR_USER_ID with the actual UUID from Supabase Dashboard > Authentication > Users

-- Step 1: Add user to demo organization
INSERT INTO org_members (org_id, user_id, role, created_at)
VALUES (
  '00000000-0000-0000-0000-000000000001',  -- Demo org ID
  'YOUR_USER_ID_HERE',                     -- Replace with your user UUID
  'admin',
  NOW()
)
ON CONFLICT (org_id, user_id) DO NOTHING;

-- Step 2: Create user profile
INSERT INTO profiles (id, org_id, email, first_name, last_name, role, created_at, updated_at)
VALUES (
  'YOUR_USER_ID_HERE',                     -- Replace with your user UUID
  '00000000-0000-0000-0000-000000000001',  -- Demo org ID
  'YOUR_EMAIL@example.com',                -- Replace with your email
  'Demo',
  'User',
  'admin',
  NOW(),
  NOW()
)
ON CONFLICT (id) DO UPDATE SET
  org_id = EXCLUDED.org_id,
  email = EXCLUDED.email,
  updated_at = NOW();

-- Verify setup
SELECT 'User successfully added to organization' as result;

SELECT 
  om.org_id,
  om.user_id,
  om.role,
  p.email,
  p.first_name,
  p.last_name
FROM org_members om
LEFT JOIN profiles p ON p.id = om.user_id
WHERE om.user_id = 'YOUR_USER_ID_HERE';
