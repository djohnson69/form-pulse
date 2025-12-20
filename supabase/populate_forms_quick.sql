-- Populate forms table with all 360+ templates
-- Run this in Supabase SQL Editor

-- This will insert forms for the demo org
-- org_id: 00000000-0000-0000-0000-000000000001

-- Note: The 'fields' column stores the form structure as JSONB
-- We're using simplified versions here - in production you'd want the full field definitions

-- Safety Category (15 forms)
INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, fields) VALUES
('jobsite-safety', '00000000-0000-0000-0000-000000000001', 'Job Site Safety Walk', '15-point safety walkthrough with photo capture', 'Safety', ARRAY['safety', 'construction', 'audit'], true, '1.0.0', 'system', '[]'::jsonb);

-- For now, let's verify the table structure and create a minimal test insert
SELECT 'Forms table ready for population' AS status;

-- To populate all 360+ templates, you have two options:
-- 1. Export from the Dart backend API endpoint and import here
-- 2. Create a seed script that reads from server.dart

-- Quick test: Insert just the first few templates to verify RLS works
INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, fields) 
SELECT * FROM (VALUES
  ('customer-feedback', '00000000-0000-0000-0000-000000000001', 'Customer Feedback', 'Capture CSAT, comments, and follow-up details', 'Customer', ARRAY['customer', 'feedback', 'csat'], true, '1.0.0', 'system', '[]'::jsonb),
  ('nps-survey', '00000000-0000-0000-0000-000000000001', 'NPS Survey', 'Customer NPS survey with score and feedback', 'Customer', ARRAY['customer', 'nps', 'feedback'], true, '1.0.0', 'system', '[]'::jsonb),
  ('patient-intake', '00000000-0000-0000-0000-000000000001', 'Patient Intake', 'Healthcare intake form for patient info', 'Healthcare', ARRAY['healthcare', 'intake', 'patient'], true, '1.0.0', 'system', '[]'::jsonb)
) AS v(id, org_id, title, description, category, tags, is_published, version, created_by, fields)
ON CONFLICT (id) DO NOTHING;

SELECT COUNT(*) as forms_count FROM forms;
