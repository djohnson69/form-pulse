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

-- Sample form (optional)
INSERT INTO forms (id, org_id, title, description, category, is_published, current_version, created_at, updated_at)
VALUES (
  '10000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000001',
  'Daily Safety Inspection',
  'Record daily workplace safety observations',
  'Safety',
  true,
  '1.0.0',
  NOW(),
  NOW()
)
ON CONFLICT (id) DO NOTHING;

-- Sample form version
INSERT INTO form_versions (id, form_id, version, definition, created_at)
VALUES (
  '20000000-0000-0000-0000-000000000001',
  '10000000-0000-0000-0000-000000000001',
  '1.0.0',
  '{
    "fields": [
      {
        "id": "location",
        "label": "Location",
        "type": "text",
        "order": 1,
        "isRequired": true
      },
      {
        "id": "inspector",
        "label": "Inspector Name",
        "type": "text",
        "order": 2,
        "isRequired": true
      },
      {
        "id": "hazards",
        "label": "Hazards Identified",
        "type": "textarea",
        "order": 3
      },
      {
        "id": "photos",
        "label": "Photos",
        "type": "photo",
        "order": 4
      }
    ]
  }'::jsonb,
  NOW()
)
ON CONFLICT (id) DO NOTHING;

-- Note: Storage bucket 'formbridge-attachments' should be created manually in Supabase Dashboard
-- Go to Storage > Create bucket > Name: formbridge-attachments, Public: OFF
