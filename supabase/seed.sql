-- Seed data for FormBridge Supabase instance
-- Run this after schema.sql to populate initial org, profiles, and demo data

-- Create a demo organization
INSERT INTO orgs (id, name, created_at)
VALUES ('00000000-0000-0000-0000-000000000001', 'Demo Organization', NOW())
ON CONFLICT (id) DO NOTHING;

-- Instructions for populating org_members and profiles:
-- 1. Sign up a user through the app or Supabase Auth UI
-- 2. Get the user's auth.users.id (UUID) from the Supabase Dashboard > Authentication > Users
-- 3. Run the following queries with the actual user_id:

-- Example: Add user to org_members (replace USER_UUID with actual user ID)
-- INSERT INTO org_members (org_id, user_id, role, created_at)
-- VALUES (
--   '00000000-0000-0000-0000-000000000001',
--   'USER_UUID',
--   'admin',
--   NOW()
-- );

-- Example: Create profile for the user (replace USER_UUID and email)
-- INSERT INTO profiles (id, org_id, email, first_name, last_name, role, created_at, updated_at)
-- VALUES (
--   'USER_UUID',
--   '00000000-0000-0000-0000-000000000001',
--   'user@example.com',
--   'Demo',
--   'User',
--   'admin',
--   NOW(),
--   NOW()
-- );

-- Sample forms that match the Flutter app models (slug ids + inline fields)
INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, fields, metadata, created_at, updated_at)
VALUES
  (
    'jobsite-safety',
    '00000000-0000-0000-0000-000000000001',
    'Job Site Safety Walk',
    '15-point safety walkthrough with photo capture',
    'Safety',
    ARRAY['safety', 'construction', 'audit'],
    true,
    '1.0.0',
    'system',
    '[{"id":"siteName","label":"Site name","type":"text","placeholder":"South Plant 7","isRequired":true,"order":1},{"id":"inspector","label":"Inspector","type":"text","placeholder":"Your name","isRequired":true,"order":2},{"id":"ppe","label":"PPE compliance","type":"checkbox","options":["Hard hat","Vest","Gloves","Eye protection"],"isRequired":true,"order":3},{"id":"hazards","label":"Hazards observed","type":"textarea","order":4},{"id":"photos","label":"Attach photos","type":"photo","order":5},{"id":"location","label":"GPS location","type":"location","order":6},{"id":"signature","label":"Supervisor signature","type":"signature","order":7}]'::jsonb,
    '{"riskLevel":"medium"}'::jsonb,
    NOW(),
    NOW()
  ),
  (
    'equipment-checkout',
    '00000000-0000-0000-0000-000000000001',
    'Equipment Checkout',
    'Log equipment issue/return with QR scan',
    'Operations',
    ARRAY['inventory', 'logistics', 'assets'],
    true,
    '1.1.0',
    'system',
    '[{"id":"assetTag","label":"Asset tag / QR","type":"barcode","order":1,"isRequired":true},{"id":"condition","label":"Condition","type":"radio","options":["Excellent","Good","Fair","Damaged"],"order":2,"isRequired":true},{"id":"notes","label":"Notes","type":"textarea","order":3},{"id":"photos","label":"Proof of condition","type":"photo","order":4}]'::jsonb,
    '{"requiresSupervisor":true}'::jsonb,
    NOW(),
    NOW()
  ),
  (
    'visitor-log',
    '00000000-0000-0000-0000-000000000001',
    'Visitor Log',
    'Quick intake with badge printing flag',
    'Security',
    ARRAY['security', 'front-desk'],
    true,
    '0.9.0',
    'system',
    '[{"id":"fullName","label":"Full name","type":"text","order":1,"isRequired":true},{"id":"company","label":"Company","type":"text","order":2},{"id":"host","label":"Host","type":"text","order":3},{"id":"purpose","label":"Purpose","type":"dropdown","options":["Delivery","Interview","Maintenance","Audit","Other"],"order":4},{"id":"arrivedAt","label":"Arrival time","type":"datetime","order":5},{"id":"badge","label":"Badge required","type":"toggle","order":6}]'::jsonb,
    '{}'::jsonb,
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

-- Optional: seed a matching form version for the first template
INSERT INTO form_versions (id, form_id, version, definition, created_at)
VALUES (
  gen_random_uuid(),
  'jobsite-safety',
  '1.0.0',
  '{"fields":[{"id":"siteName","label":"Site name","type":"text","placeholder":"South Plant 7","isRequired":true,"order":1},{"id":"inspector","label":"Inspector","type":"text","placeholder":"Your name","isRequired":true,"order":2},{"id":"ppe","label":"PPE compliance","type":"checkbox","options":["Hard hat","Vest","Gloves","Eye protection"],"isRequired":true,"order":3},{"id":"hazards","label":"Hazards observed","type":"textarea","order":4},{"id":"photos","label":"Attach photos","type":"photo","order":5},{"id":"location","label":"GPS location","type":"location","order":6},{"id":"signature","label":"Supervisor signature","type":"signature","order":7}]}'::jsonb,
  NOW()
)
ON CONFLICT (form_id, version) DO NOTHING;

-- Note: Storage bucket 'formbridge-attachments' should be created manually in Supabase Dashboard
-- Go to Storage > Create bucket > Name: formbridge-attachments, Public: OFF
