-- Align an existing database with the app-friendly schema (slug ids + fields/tags/metadata).
-- Run this before loading templates via populate_all_forms.sql

BEGIN;

-- Add missing columns to forms
ALTER TABLE forms
ADD COLUMN IF NOT EXISTS tags text[] NOT NULL DEFAULT '{}'::text[],
ADD COLUMN IF NOT EXISTS version text,
ADD COLUMN IF NOT EXISTS fields jsonb NOT NULL DEFAULT '[]'::jsonb,
ADD COLUMN IF NOT EXISTS metadata jsonb NOT NULL DEFAULT '{}'::jsonb;

-- Backfill nulls to satisfy NOT NULL defaults
UPDATE forms
SET
  tags = COALESCE(tags, '{}'::text[]),
  fields = COALESCE(fields, '[]'::jsonb),
  metadata = COALESCE(metadata, '{}'::jsonb);
ALTER TABLE forms
  ALTER COLUMN tags SET DEFAULT '{}'::text[],
  ALTER COLUMN fields SET DEFAULT '[]'::jsonb,
  ALTER COLUMN metadata SET DEFAULT '{}'::jsonb,
  ALTER COLUMN tags SET NOT NULL,
  ALTER COLUMN fields SET NOT NULL,
  ALTER COLUMN metadata SET NOT NULL;

-- Allow created_by to store system/user text identifiers
ALTER TABLE forms
DROP CONSTRAINT IF EXISTS forms_created_by_fkey,
ALTER COLUMN created_by TYPE text USING created_by::text,
ALTER COLUMN created_by DROP NOT NULL;

-- Drop foreign keys that point at forms.id so we can change its type
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_name = 'forms'
      AND column_name = 'id'
      AND data_type <> 'text'
  ) THEN
    ALTER TABLE form_versions DROP CONSTRAINT IF EXISTS form_versions_form_id_fkey;
    ALTER TABLE submissions DROP CONSTRAINT IF EXISTS submissions_form_id_fkey;

    -- Switch forms.id to text (supports slugs) and keep a generated default for new records
    ALTER TABLE forms
    DROP CONSTRAINT IF EXISTS forms_pkey CASCADE,
    ALTER COLUMN id TYPE text USING id::text,
    ALTER COLUMN id SET DEFAULT gen_random_uuid()::text,
    ADD CONSTRAINT forms_pkey PRIMARY KEY (id);

    -- Update child references to text
    ALTER TABLE form_versions
    ALTER COLUMN form_id TYPE text USING form_id::text;

    ALTER TABLE submissions
    ALTER COLUMN form_id TYPE text USING form_id::text;

    -- Recreate foreign keys with the new type
    ALTER TABLE form_versions
    ADD CONSTRAINT form_versions_form_id_fkey FOREIGN KEY (form_id) REFERENCES forms(id) ON DELETE CASCADE;

    ALTER TABLE submissions
    ADD CONSTRAINT submissions_form_id_fkey FOREIGN KEY (form_id) REFERENCES forms(id) ON DELETE CASCADE;

    -- Restore helpful indexes if they were dropped during type changes
    CREATE INDEX IF NOT EXISTS idx_form_versions_form ON form_versions(form_id);
    CREATE INDEX IF NOT EXISTS idx_submissions_form ON submissions(form_id);
  END IF;
END $$;

-- Keep submissions metadata aligned with the app shape
ALTER TABLE submissions
ADD COLUMN IF NOT EXISTS metadata jsonb NOT NULL DEFAULT '{}'::jsonb;
ALTER TABLE submissions
  ALTER COLUMN metadata SET DEFAULT '{}'::jsonb,
  ALTER COLUMN metadata SET NOT NULL;
UPDATE submissions SET metadata = '{}'::jsonb WHERE metadata IS NULL;

-- Allow audit_log.resource_id to store text ids
ALTER TABLE audit_log
ALTER COLUMN resource_id TYPE text USING resource_id::text;

-- Projects and updates
CREATE TABLE IF NOT EXISTS projects (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references orgs(id) on delete cascade,
  name text not null,
  description text,
  status text not null default 'active',
  labels text[] not null default '{}'::text[],
  cover_url text,
  share_token text,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb
);

CREATE TABLE IF NOT EXISTS project_updates (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references orgs(id) on delete cascade,
  project_id uuid not null references projects(id) on delete cascade,
  user_id uuid references auth.users(id),
  type text not null default 'photo',
  title text,
  body text,
  tags text[] not null default '{}'::text[],
  attachments jsonb not null default '[]'::jsonb,
  parent_id uuid references project_updates(id) on delete cascade,
  is_shared boolean not null default false,
  created_at timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb
);

CREATE TABLE IF NOT EXISTS tasks (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references orgs(id) on delete cascade,
  title text not null,
  description text,
  instructions text,
  status text not null default 'todo',
  progress int not null default 0,
  due_date timestamptz,
  priority text default 'normal',
  assigned_to uuid references auth.users(id),
  assigned_to_name text,
  assigned_team text,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  completed_at timestamptz,
  metadata jsonb not null default '{}'::jsonb
);

CREATE TABLE IF NOT EXISTS clients (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references orgs(id) on delete cascade,
  company_name text not null,
  contact_name text,
  email text,
  phone_number text,
  address text,
  website text,
  assigned_job_sites text[] not null default '{}'::text[],
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb
);

CREATE TABLE IF NOT EXISTS vendors (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references orgs(id) on delete cascade,
  company_name text not null,
  contact_name text,
  email text,
  phone_number text,
  address text,
  website text,
  service_category text,
  certifications text[] not null default '{}'::text[],
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb
);

CREATE TABLE IF NOT EXISTS message_threads (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references orgs(id) on delete cascade,
  title text not null,
  type text not null default 'internal',
  client_id uuid references clients(id) on delete set null,
  vendor_id uuid references vendors(id) on delete set null,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb
);

CREATE TABLE IF NOT EXISTS message_participants (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references orgs(id) on delete cascade,
  thread_id uuid not null references message_threads(id) on delete cascade,
  user_id uuid references auth.users(id),
  client_id uuid references clients(id),
  vendor_id uuid references vendors(id),
  display_name text,
  role text,
  created_at timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb
);

CREATE TABLE IF NOT EXISTS messages (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references orgs(id) on delete cascade,
  thread_id uuid not null references message_threads(id) on delete cascade,
  sender_id uuid references auth.users(id),
  sender_name text,
  sender_role text,
  body text not null,
  attachments jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb
);

CREATE TABLE IF NOT EXISTS equipment (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references orgs(id) on delete cascade,
  name text not null,
  description text,
  category text,
  manufacturer text,
  model_number text,
  serial_number text,
  purchase_date timestamptz,
  assigned_to text,
  current_location text,
  gps_location jsonb,
  rfid_tag text,
  last_maintenance_date timestamptz,
  next_maintenance_date timestamptz,
  is_active boolean not null default true,
  company_id text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb
);

CREATE TABLE IF NOT EXISTS asset_inspections (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references orgs(id) on delete cascade,
  equipment_id uuid not null references equipment(id) on delete cascade,
  status text not null default 'pass',
  notes text,
  attachments jsonb not null default '[]'::jsonb,
  location jsonb,
  inspected_at timestamptz not null default now(),
  created_by uuid references auth.users(id),
  created_by_name text,
  created_at timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb
);

CREATE TABLE IF NOT EXISTS incident_reports (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references orgs(id) on delete cascade,
  equipment_id uuid references equipment(id) on delete set null,
  job_site_id uuid,
  title text not null,
  description text,
  status text not null default 'open',
  category text,
  severity text,
  occurred_at timestamptz not null default now(),
  submitted_by uuid references auth.users(id),
  submitted_by_name text,
  attachments jsonb not null default '[]'::jsonb,
  location jsonb,
  created_at timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb
);

CREATE TABLE IF NOT EXISTS employees (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references orgs(id) on delete cascade,
  user_id uuid references auth.users(id),
  first_name text not null,
  last_name text not null,
  email text,
  photo_url text,
  phone_number text,
  employee_number text,
  department text,
  position text,
  job_site_id uuid,
  job_site_name text,
  hire_date timestamptz,
  termination_date timestamptz,
  is_active boolean not null default true,
  certifications text[] not null default '{}'::text[],
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb
);

CREATE TABLE IF NOT EXISTS training_records (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references orgs(id) on delete cascade,
  employee_id uuid not null references employees(id) on delete cascade,
  training_name text not null,
  training_type text,
  status text not null default 'notStarted',
  completed_date timestamptz,
  expiration_date timestamptz,
  instructor_name text,
  score numeric,
  certificate_url text,
  next_recertification_date timestamptz,
  location text,
  ceu_credits numeric,
  materials text[] not null default '{}'::text[],
  documents jsonb not null default '[]'::jsonb,
  assigned_role text,
  assigned_job text,
  assigned_site text,
  assigned_tenure_days int,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb
);

CREATE TABLE IF NOT EXISTS documents (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references orgs(id) on delete cascade,
  project_id uuid references projects(id) on delete set null,
  title text not null,
  description text,
  category text,
  file_url text not null,
  filename text not null,
  mime_type text not null,
  file_size int not null,
  version text not null default 'v1',
  is_template boolean not null default false,
  is_published boolean not null default true,
  tags text[] not null default '{}'::text[],
  uploaded_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb
);

CREATE TABLE IF NOT EXISTS document_versions (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references orgs(id) on delete cascade,
  document_id uuid not null references documents(id) on delete cascade,
  version text not null,
  file_url text not null,
  filename text not null,
  mime_type text not null,
  file_size int not null,
  uploaded_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb
);

CREATE TABLE IF NOT EXISTS news_posts (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references orgs(id) on delete cascade,
  title text not null,
  body text,
  scope text not null default 'company',
  site_id uuid,
  tags text[] not null default '{}'::text[],
  is_published boolean not null default true,
  published_at timestamptz not null default now(),
  attachments jsonb not null default '[]'::jsonb,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb
);

CREATE TABLE IF NOT EXISTS notification_rules (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references orgs(id) on delete cascade,
  name text not null,
  trigger_type text not null,
  target_type text not null default 'org',
  target_ids text[] not null default '{}'::text[],
  channels text[] not null default '{in_app}'::text[],
  schedule text,
  is_active boolean not null default true,
  message_template text,
  payload jsonb not null default '{}'::jsonb,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb
);

CREATE TABLE IF NOT EXISTS notification_events (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references orgs(id) on delete cascade,
  rule_id uuid references notification_rules(id) on delete set null,
  status text not null default 'queued',
  fired_at timestamptz not null default now(),
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb
);

CREATE TABLE IF NOT EXISTS notebook_pages (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references orgs(id) on delete cascade,
  project_id uuid references projects(id) on delete set null,
  title text not null,
  body text,
  tags text[] not null default '{}'::text[],
  attachments jsonb not null default '[]'::jsonb,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb
);

CREATE TABLE IF NOT EXISTS notebook_reports (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references orgs(id) on delete cascade,
  project_id uuid references projects(id) on delete set null,
  title text not null,
  page_ids uuid[] not null default '{}'::uuid[],
  file_url text,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb
);

CREATE TABLE IF NOT EXISTS signature_requests (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references orgs(id) on delete cascade,
  document_id uuid references documents(id) on delete set null,
  request_name text,
  signer_name text,
  signer_email text,
  status text not null default 'pending',
  token text,
  requested_by uuid references auth.users(id),
  requested_at timestamptz not null default now(),
  signed_at timestamptz,
  signature_data jsonb,
  file_url text,
  metadata jsonb not null default '{}'::jsonb
);

CREATE TABLE IF NOT EXISTS project_photos (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references orgs(id) on delete cascade,
  project_id uuid references projects(id) on delete set null,
  title text,
  description text,
  tags text[] not null default '{}'::text[],
  attachments jsonb not null default '[]'::jsonb,
  is_featured boolean not null default false,
  is_shared boolean not null default false,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb
);

CREATE TABLE IF NOT EXISTS photo_comments (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references orgs(id) on delete cascade,
  photo_id uuid not null references project_photos(id) on delete cascade,
  author_id uuid references auth.users(id),
  body text not null,
  created_at timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb
);

CREATE TABLE IF NOT EXISTS webhook_endpoints (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references orgs(id) on delete cascade,
  name text not null,
  url text not null,
  secret text,
  events text[] not null default '{}'::text[],
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb
);

CREATE TABLE IF NOT EXISTS export_jobs (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references orgs(id) on delete cascade,
  type text not null,
  format text not null default 'csv',
  status text not null default 'queued',
  requested_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  completed_at timestamptz,
  file_url text,
  metadata jsonb not null default '{}'::jsonb
);

CREATE TABLE IF NOT EXISTS ai_jobs (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references orgs(id) on delete cascade,
  type text not null,
  status text not null default 'pending',
  input_text text,
  input_media jsonb,
  output_text text,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  completed_at timestamptz,
  metadata jsonb not null default '{}'::jsonb
);

CREATE TABLE IF NOT EXISTS guest_invites (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references orgs(id) on delete cascade,
  email text not null,
  role text,
  status text not null default 'invited',
  token text,
  expires_at timestamptz,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb
);

CREATE TABLE IF NOT EXISTS payment_requests (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references orgs(id) on delete cascade,
  project_id uuid references projects(id) on delete set null,
  amount numeric not null,
  currency text not null default 'USD',
  status text not null default 'requested',
  description text,
  requested_by uuid references auth.users(id),
  requested_at timestamptz not null default now(),
  paid_at timestamptz,
  metadata jsonb not null default '{}'::jsonb
);

CREATE TABLE IF NOT EXISTS reviews (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references orgs(id) on delete cascade,
  project_id uuid references projects(id) on delete set null,
  rating int,
  comment text,
  source text,
  status text not null default 'requested',
  requested_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb
);

CREATE TABLE IF NOT EXISTS portfolio_items (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references orgs(id) on delete cascade,
  project_id uuid references projects(id) on delete set null,
  title text not null,
  description text,
  cover_url text,
  gallery_urls text[] not null default '{}'::text[],
  is_published boolean not null default false,
  share_token text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb
);

ALTER TABLE projects ENABLE ROW LEVEL SECURITY;
ALTER TABLE project_updates ENABLE ROW LEVEL SECURITY;
ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE equipment ENABLE ROW LEVEL SECURITY;
ALTER TABLE asset_inspections ENABLE ROW LEVEL SECURITY;
ALTER TABLE incident_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE news_posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE notification_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE notification_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE notebook_pages ENABLE ROW LEVEL SECURITY;
ALTER TABLE notebook_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE signature_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE project_photos ENABLE ROW LEVEL SECURITY;
ALTER TABLE photo_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE webhook_endpoints ENABLE ROW LEVEL SECURITY;
ALTER TABLE export_jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE guest_invites ENABLE ROW LEVEL SECURITY;
ALTER TABLE payment_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE portfolio_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE clients ENABLE ROW LEVEL SECURITY;
ALTER TABLE vendors ENABLE ROW LEVEL SECURITY;
ALTER TABLE message_threads ENABLE ROW LEVEL SECURITY;
ALTER TABLE message_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE employees ENABLE ROW LEVEL SECURITY;
ALTER TABLE training_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE document_versions ENABLE ROW LEVEL SECURITY;

CREATE INDEX IF NOT EXISTS idx_projects_org ON projects(org_id);
CREATE INDEX IF NOT EXISTS idx_project_updates_project ON project_updates(project_id);
CREATE INDEX IF NOT EXISTS idx_project_updates_org ON project_updates(org_id);
CREATE INDEX IF NOT EXISTS idx_tasks_org ON tasks(org_id);
CREATE INDEX IF NOT EXISTS idx_tasks_assignee ON tasks(assigned_to);
CREATE INDEX IF NOT EXISTS idx_tasks_status ON tasks(status);
CREATE INDEX IF NOT EXISTS idx_equipment_org ON equipment(org_id);
CREATE INDEX IF NOT EXISTS idx_equipment_active ON equipment(is_active);
CREATE INDEX IF NOT EXISTS idx_inspections_org ON asset_inspections(org_id);
CREATE INDEX IF NOT EXISTS idx_inspections_equipment ON asset_inspections(equipment_id);
CREATE INDEX IF NOT EXISTS idx_incidents_org ON incident_reports(org_id);
CREATE INDEX IF NOT EXISTS idx_incidents_equipment ON incident_reports(equipment_id);
CREATE INDEX IF NOT EXISTS idx_incidents_status ON incident_reports(status);
CREATE INDEX IF NOT EXISTS idx_news_org ON news_posts(org_id);
CREATE INDEX IF NOT EXISTS idx_news_published ON news_posts(published_at);
CREATE INDEX IF NOT EXISTS idx_notification_rules_org ON notification_rules(org_id);
CREATE INDEX IF NOT EXISTS idx_notification_events_org ON notification_events(org_id);
CREATE INDEX IF NOT EXISTS idx_notification_events_rule ON notification_events(rule_id);
CREATE INDEX IF NOT EXISTS idx_notebook_pages_org ON notebook_pages(org_id);
CREATE INDEX IF NOT EXISTS idx_notebook_pages_project ON notebook_pages(project_id);
CREATE INDEX IF NOT EXISTS idx_notebook_reports_org ON notebook_reports(org_id);
CREATE INDEX IF NOT EXISTS idx_signature_requests_org ON signature_requests(org_id);
CREATE INDEX IF NOT EXISTS idx_signature_requests_status ON signature_requests(status);
CREATE INDEX IF NOT EXISTS idx_project_photos_org ON project_photos(org_id);
CREATE INDEX IF NOT EXISTS idx_project_photos_project ON project_photos(project_id);
CREATE INDEX IF NOT EXISTS idx_photo_comments_photo ON photo_comments(photo_id);
CREATE INDEX IF NOT EXISTS idx_webhook_endpoints_org ON webhook_endpoints(org_id);
CREATE INDEX IF NOT EXISTS idx_export_jobs_org ON export_jobs(org_id);
CREATE INDEX IF NOT EXISTS idx_export_jobs_status ON export_jobs(status);
CREATE INDEX IF NOT EXISTS idx_ai_jobs_org ON ai_jobs(org_id);
CREATE INDEX IF NOT EXISTS idx_ai_jobs_status ON ai_jobs(status);
CREATE INDEX IF NOT EXISTS idx_guest_invites_org ON guest_invites(org_id);
CREATE INDEX IF NOT EXISTS idx_guest_invites_status ON guest_invites(status);
CREATE INDEX IF NOT EXISTS idx_payment_requests_org ON payment_requests(org_id);
CREATE INDEX IF NOT EXISTS idx_payment_requests_status ON payment_requests(status);
CREATE INDEX IF NOT EXISTS idx_reviews_org ON reviews(org_id);
CREATE INDEX IF NOT EXISTS idx_portfolio_items_org ON portfolio_items(org_id);
CREATE INDEX IF NOT EXISTS idx_portfolio_items_project ON portfolio_items(project_id);
CREATE INDEX IF NOT EXISTS idx_clients_org ON clients(org_id);
CREATE INDEX IF NOT EXISTS idx_vendors_org ON vendors(org_id);
CREATE INDEX IF NOT EXISTS idx_threads_org ON message_threads(org_id);
CREATE INDEX IF NOT EXISTS idx_messages_thread ON messages(thread_id);
CREATE INDEX IF NOT EXISTS idx_messages_org ON messages(org_id);
CREATE INDEX IF NOT EXISTS idx_employees_org ON employees(org_id);
CREATE INDEX IF NOT EXISTS idx_employees_user ON employees(user_id);
CREATE INDEX IF NOT EXISTS idx_training_employee ON training_records(employee_id);
CREATE INDEX IF NOT EXISTS idx_training_status ON training_records(status);
CREATE INDEX IF NOT EXISTS idx_training_expiration ON training_records(expiration_date);
CREATE INDEX IF NOT EXISTS idx_documents_org ON documents(org_id);
CREATE INDEX IF NOT EXISTS idx_documents_project ON documents(project_id);
CREATE INDEX IF NOT EXISTS idx_document_versions_doc ON document_versions(document_id);

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Org members read projects') THEN
        CREATE POLICY "Org members read projects"
            ON projects FOR SELECT
            USING (EXISTS (
                SELECT 1 FROM org_members m WHERE m.org_id = projects.org_id AND m.user_id = auth.uid()
            ));
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Org members manage projects') THEN
        CREATE POLICY "Org members manage projects"
            ON projects FOR ALL
            USING (EXISTS (
                SELECT 1 FROM org_members m WHERE m.org_id = projects.org_id AND m.user_id = auth.uid()
            ));
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Org members read project updates') THEN
        CREATE POLICY "Org members read project updates"
            ON project_updates FOR SELECT
            USING (EXISTS (
                SELECT 1 FROM org_members m WHERE m.org_id = project_updates.org_id AND m.user_id = auth.uid()
            ));
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Org members manage project updates') THEN
        CREATE POLICY "Org members manage project updates"
            ON project_updates FOR ALL
            USING (EXISTS (
                SELECT 1 FROM org_members m WHERE m.org_id = project_updates.org_id AND m.user_id = auth.uid()
            ));
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Org members read tasks') THEN
        CREATE POLICY "Org members read tasks"
            ON tasks FOR SELECT
            USING (EXISTS (
                SELECT 1 FROM org_members m WHERE m.org_id = tasks.org_id AND m.user_id = auth.uid()
            ));
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Org members manage tasks') THEN
        CREATE POLICY "Org members manage tasks"
            ON tasks FOR ALL
            USING (EXISTS (
                SELECT 1 FROM org_members m WHERE m.org_id = tasks.org_id AND m.user_id = auth.uid()
            ));
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Org members read equipment') THEN
        CREATE POLICY "Org members read equipment"
            ON equipment FOR SELECT
            USING (EXISTS (
                SELECT 1 FROM org_members m WHERE m.org_id = equipment.org_id AND m.user_id = auth.uid()
            ));
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Org members manage equipment') THEN
        CREATE POLICY "Org members manage equipment"
            ON equipment FOR ALL
            USING (EXISTS (
                SELECT 1 FROM org_members m WHERE m.org_id = equipment.org_id AND m.user_id = auth.uid()
            ));
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Org members read asset inspections') THEN
        CREATE POLICY "Org members read asset inspections"
            ON asset_inspections FOR SELECT
            USING (EXISTS (
                SELECT 1 FROM org_members m WHERE m.org_id = asset_inspections.org_id AND m.user_id = auth.uid()
            ));
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Org members manage asset inspections') THEN
        CREATE POLICY "Org members manage asset inspections"
            ON asset_inspections FOR ALL
            USING (EXISTS (
                SELECT 1 FROM org_members m WHERE m.org_id = asset_inspections.org_id AND m.user_id = auth.uid()
            ));
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Org members read incident reports') THEN
        CREATE POLICY "Org members read incident reports"
            ON incident_reports FOR SELECT
            USING (EXISTS (
                SELECT 1 FROM org_members m WHERE m.org_id = incident_reports.org_id AND m.user_id = auth.uid()
            ));
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Org members manage incident reports') THEN
        CREATE POLICY "Org members manage incident reports"
            ON incident_reports FOR ALL
            USING (EXISTS (
                SELECT 1 FROM org_members m WHERE m.org_id = incident_reports.org_id AND m.user_id = auth.uid()
            ));
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Org members read news posts') THEN
        CREATE POLICY "Org members read news posts"
            ON news_posts FOR SELECT
            USING (EXISTS (
                SELECT 1 FROM org_members m WHERE m.org_id = news_posts.org_id AND m.user_id = auth.uid()
            ));
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Org members manage news posts') THEN
        CREATE POLICY "Org members manage news posts"
            ON news_posts FOR ALL
            USING (EXISTS (
                SELECT 1 FROM org_members m WHERE m.org_id = news_posts.org_id AND m.user_id = auth.uid()
            ));
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Org members read notification rules') THEN
        CREATE POLICY "Org members read notification rules"
            ON notification_rules FOR SELECT
            USING (EXISTS (
                SELECT 1 FROM org_members m WHERE m.org_id = notification_rules.org_id AND m.user_id = auth.uid()
            ));
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Org members manage notification rules') THEN
        CREATE POLICY "Org members manage notification rules"
            ON notification_rules FOR ALL
            USING (EXISTS (
                SELECT 1 FROM org_members m WHERE m.org_id = notification_rules.org_id AND m.user_id = auth.uid()
            ));
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Org members read notification events') THEN
        CREATE POLICY "Org members read notification events"
            ON notification_events FOR SELECT
            USING (EXISTS (
                SELECT 1 FROM org_members m WHERE m.org_id = notification_events.org_id AND m.user_id = auth.uid()
            ));
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Org members manage notification events') THEN
        CREATE POLICY "Org members manage notification events"
            ON notification_events FOR ALL
            USING (EXISTS (
                SELECT 1 FROM org_members m WHERE m.org_id = notification_events.org_id AND m.user_id = auth.uid()
            ));
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Org members read notebook pages') THEN
        CREATE POLICY "Org members read notebook pages"
            ON notebook_pages FOR SELECT
            USING (EXISTS (
                SELECT 1 FROM org_members m WHERE m.org_id = notebook_pages.org_id AND m.user_id = auth.uid()
            ));
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Org members manage notebook pages') THEN
        CREATE POLICY "Org members manage notebook pages"
            ON notebook_pages FOR ALL
            USING (EXISTS (
                SELECT 1 FROM org_members m WHERE m.org_id = notebook_pages.org_id AND m.user_id = auth.uid()
            ));
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Org members read notebook reports') THEN
        CREATE POLICY "Org members read notebook reports"
            ON notebook_reports FOR SELECT
            USING (EXISTS (
                SELECT 1 FROM org_members m WHERE m.org_id = notebook_reports.org_id AND m.user_id = auth.uid()
            ));
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Org members manage notebook reports') THEN
        CREATE POLICY "Org members manage notebook reports"
            ON notebook_reports FOR ALL
            USING (EXISTS (
                SELECT 1 FROM org_members m WHERE m.org_id = notebook_reports.org_id AND m.user_id = auth.uid()
            ));
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Org members read signature requests') THEN
        CREATE POLICY "Org members read signature requests"
            ON signature_requests FOR SELECT
            USING (EXISTS (
                SELECT 1 FROM org_members m WHERE m.org_id = signature_requests.org_id AND m.user_id = auth.uid()
            ));
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Org members manage signature requests') THEN
        CREATE POLICY "Org members manage signature requests"
            ON signature_requests FOR ALL
            USING (EXISTS (
                SELECT 1 FROM org_members m WHERE m.org_id = signature_requests.org_id AND m.user_id = auth.uid()
            ));
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Org members read project photos') THEN
        CREATE POLICY "Org members read project photos"
            ON project_photos FOR SELECT
            USING (EXISTS (
                SELECT 1 FROM org_members m WHERE m.org_id = project_photos.org_id AND m.user_id = auth.uid()
            ));
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Org members manage project photos') THEN
        CREATE POLICY "Org members manage project photos"
            ON project_photos FOR ALL
            USING (EXISTS (
                SELECT 1 FROM org_members m WHERE m.org_id = project_photos.org_id AND m.user_id = auth.uid()
            ));
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Org members read photo comments') THEN
        CREATE POLICY "Org members read photo comments"
            ON photo_comments FOR SELECT
            USING (EXISTS (
                SELECT 1 FROM org_members m WHERE m.org_id = photo_comments.org_id AND m.user_id = auth.uid()
            ));
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Org members manage photo comments') THEN
        CREATE POLICY "Org members manage photo comments"
            ON photo_comments FOR ALL
            USING (EXISTS (
                SELECT 1 FROM org_members m WHERE m.org_id = photo_comments.org_id AND m.user_id = auth.uid()
            ));
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Org members read webhook endpoints') THEN
        CREATE POLICY "Org members read webhook endpoints"
            ON webhook_endpoints FOR SELECT
            USING (EXISTS (
                SELECT 1 FROM org_members m WHERE m.org_id = webhook_endpoints.org_id AND m.user_id = auth.uid()
            ));
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Org members manage webhook endpoints') THEN
        CREATE POLICY "Org members manage webhook endpoints"
            ON webhook_endpoints FOR ALL
            USING (EXISTS (
                SELECT 1 FROM org_members m WHERE m.org_id = webhook_endpoints.org_id AND m.user_id = auth.uid()
            ));
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Org members read export jobs') THEN
        CREATE POLICY "Org members read export jobs"
            ON export_jobs FOR SELECT
            USING (EXISTS (
                SELECT 1 FROM org_members m WHERE m.org_id = export_jobs.org_id AND m.user_id = auth.uid()
            ));
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Org members manage export jobs') THEN
        CREATE POLICY "Org members manage export jobs"
            ON export_jobs FOR ALL
            USING (EXISTS (
                SELECT 1 FROM org_members m WHERE m.org_id = export_jobs.org_id AND m.user_id = auth.uid()
            ));
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Org members read ai jobs') THEN
        CREATE POLICY "Org members read ai jobs"
            ON ai_jobs FOR SELECT
            USING (EXISTS (
                SELECT 1 FROM org_members m WHERE m.org_id = ai_jobs.org_id AND m.user_id = auth.uid()
            ));
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Org members manage ai jobs') THEN
        CREATE POLICY "Org members manage ai jobs"
            ON ai_jobs FOR ALL
            USING (EXISTS (
                SELECT 1 FROM org_members m WHERE m.org_id = ai_jobs.org_id AND m.user_id = auth.uid()
            ));
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Org members read guest invites') THEN
        CREATE POLICY "Org members read guest invites"
            ON guest_invites FOR SELECT
            USING (EXISTS (
                SELECT 1 FROM org_members m WHERE m.org_id = guest_invites.org_id AND m.user_id = auth.uid()
            ));
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Org members manage guest invites') THEN
        CREATE POLICY "Org members manage guest invites"
            ON guest_invites FOR ALL
            USING (EXISTS (
                SELECT 1 FROM org_members m WHERE m.org_id = guest_invites.org_id AND m.user_id = auth.uid()
            ));
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Org members read payment requests') THEN
        CREATE POLICY "Org members read payment requests"
            ON payment_requests FOR SELECT
            USING (EXISTS (
                SELECT 1 FROM org_members m WHERE m.org_id = payment_requests.org_id AND m.user_id = auth.uid()
            ));
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Org members manage payment requests') THEN
        CREATE POLICY "Org members manage payment requests"
            ON payment_requests FOR ALL
            USING (EXISTS (
                SELECT 1 FROM org_members m WHERE m.org_id = payment_requests.org_id AND m.user_id = auth.uid()
            ));
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Org members read reviews') THEN
        CREATE POLICY "Org members read reviews"
            ON reviews FOR SELECT
            USING (EXISTS (
                SELECT 1 FROM org_members m WHERE m.org_id = reviews.org_id AND m.user_id = auth.uid()
            ));
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Org members manage reviews') THEN
        CREATE POLICY "Org members manage reviews"
            ON reviews FOR ALL
            USING (EXISTS (
                SELECT 1 FROM org_members m WHERE m.org_id = reviews.org_id AND m.user_id = auth.uid()
            ));
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Org members read portfolio items') THEN
        CREATE POLICY "Org members read portfolio items"
            ON portfolio_items FOR SELECT
            USING (EXISTS (
                SELECT 1 FROM org_members m WHERE m.org_id = portfolio_items.org_id AND m.user_id = auth.uid()
            ));
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Org members manage portfolio items') THEN
        CREATE POLICY "Org members manage portfolio items"
            ON portfolio_items FOR ALL
            USING (EXISTS (
                SELECT 1 FROM org_members m WHERE m.org_id = portfolio_items.org_id AND m.user_id = auth.uid()
            ));
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Org members read clients') THEN
        CREATE POLICY "Org members read clients"
            ON clients FOR SELECT
            USING (EXISTS (
                SELECT 1 FROM org_members m WHERE m.org_id = clients.org_id AND m.user_id = auth.uid()
            ));
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Org members manage clients') THEN
        CREATE POLICY "Org members manage clients"
            ON clients FOR ALL
            USING (EXISTS (
                SELECT 1 FROM org_members m WHERE m.org_id = clients.org_id AND m.user_id = auth.uid()
            ));
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Org members read vendors') THEN
        CREATE POLICY "Org members read vendors"
            ON vendors FOR SELECT
            USING (EXISTS (
                SELECT 1 FROM org_members m WHERE m.org_id = vendors.org_id AND m.user_id = auth.uid()
            ));
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Org members manage vendors') THEN
        CREATE POLICY "Org members manage vendors"
            ON vendors FOR ALL
            USING (EXISTS (
                SELECT 1 FROM org_members m WHERE m.org_id = vendors.org_id AND m.user_id = auth.uid()
            ));
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Org members read message threads') THEN
        CREATE POLICY "Org members read message threads"
            ON message_threads FOR SELECT
            USING (EXISTS (
                SELECT 1 FROM org_members m WHERE m.org_id = message_threads.org_id AND m.user_id = auth.uid()
            ));
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Org members manage message threads') THEN
        CREATE POLICY "Org members manage message threads"
            ON message_threads FOR ALL
            USING (EXISTS (
                SELECT 1 FROM org_members m WHERE m.org_id = message_threads.org_id AND m.user_id = auth.uid()
            ));
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Org members read message participants') THEN
        CREATE POLICY "Org members read message participants"
            ON message_participants FOR SELECT
            USING (EXISTS (
                SELECT 1 FROM org_members m WHERE m.org_id = message_participants.org_id AND m.user_id = auth.uid()
            ));
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Org members manage message participants') THEN
        CREATE POLICY "Org members manage message participants"
            ON message_participants FOR ALL
            USING (EXISTS (
                SELECT 1 FROM org_members m WHERE m.org_id = message_participants.org_id AND m.user_id = auth.uid()
            ));
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Org members read messages') THEN
        CREATE POLICY "Org members read messages"
            ON messages FOR SELECT
            USING (EXISTS (
                SELECT 1 FROM org_members m WHERE m.org_id = messages.org_id AND m.user_id = auth.uid()
            ));
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Org members insert messages') THEN
        CREATE POLICY "Org members insert messages"
            ON messages FOR INSERT
            WITH CHECK (EXISTS (
                SELECT 1 FROM org_members m WHERE m.org_id = messages.org_id AND m.user_id = auth.uid()
            ));
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Org members read employees') THEN
        CREATE POLICY "Org members read employees"
            ON employees FOR SELECT
            USING (EXISTS (
                SELECT 1 FROM org_members m WHERE m.org_id = employees.org_id AND m.user_id = auth.uid()
            ));
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Org members manage employees') THEN
        CREATE POLICY "Org members manage employees"
            ON employees FOR ALL
            USING (EXISTS (
                SELECT 1 FROM org_members m WHERE m.org_id = employees.org_id AND m.user_id = auth.uid()
            ));
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Org members read training records') THEN
        CREATE POLICY "Org members read training records"
            ON training_records FOR SELECT
            USING (EXISTS (
                SELECT 1 FROM org_members m WHERE m.org_id = training_records.org_id AND m.user_id = auth.uid()
            ));
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Org members manage training records') THEN
        CREATE POLICY "Org members manage training records"
            ON training_records FOR ALL
            USING (EXISTS (
                SELECT 1 FROM org_members m WHERE m.org_id = training_records.org_id AND m.user_id = auth.uid()
            ));
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Org members read documents') THEN
        CREATE POLICY "Org members read documents"
            ON documents FOR SELECT
            USING (EXISTS (
                SELECT 1 FROM org_members m WHERE m.org_id = documents.org_id AND m.user_id = auth.uid()
            ));
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Org members manage documents') THEN
        CREATE POLICY "Org members manage documents"
            ON documents FOR ALL
            USING (EXISTS (
                SELECT 1 FROM org_members m WHERE m.org_id = documents.org_id AND m.user_id = auth.uid()
            ));
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Org members read document versions') THEN
        CREATE POLICY "Org members read document versions"
            ON document_versions FOR SELECT
            USING (EXISTS (
                SELECT 1 FROM org_members m WHERE m.org_id = document_versions.org_id AND m.user_id = auth.uid()
            ));
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Org members manage document versions') THEN
        CREATE POLICY "Org members manage document versions"
            ON document_versions FOR ALL
            USING (EXISTS (
                SELECT 1 FROM org_members m WHERE m.org_id = document_versions.org_id AND m.user_id = auth.uid()
            ));
    END IF;
END $$;

-- Allow org members to update submissions (approvals, status changes)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Org members update submissions') THEN
        CREATE POLICY "Org members update submissions"
            ON submissions FOR UPDATE
            USING (EXISTS (
                SELECT 1 FROM org_members m WHERE m.org_id = submissions.org_id AND m.user_id = auth.uid()
            ))
            WITH CHECK (EXISTS (
                SELECT 1 FROM org_members m WHERE m.org_id = submissions.org_id AND m.user_id = auth.uid()
            ));
    END IF;
END $$;

-- Ensure policies on form_versions continue to enforce org membership
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Org members read form versions') THEN
        CREATE POLICY "Org members read form versions"
            ON form_versions FOR SELECT
            USING (EXISTS (
                SELECT 1 FROM forms f
                JOIN org_members m ON m.org_id = f.org_id AND m.user_id = auth.uid()
                WHERE f.id = form_versions.form_id
            ));
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Org members manage form versions') THEN
        CREATE POLICY "Org members manage form versions"
            ON form_versions FOR ALL
            USING (EXISTS (
                SELECT 1 FROM forms f
                JOIN org_members m ON m.org_id = f.org_id AND m.user_id = auth.uid()
                WHERE f.id = form_versions.form_id
            ));
    END IF;
END $$;

COMMIT;

-- Quick verification
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'forms'
ORDER BY ordinal_position;
