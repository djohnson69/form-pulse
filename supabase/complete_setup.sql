-- Align schema with the Flutter app (slug/text form ids + fields/tags/metadata) before loading templates.

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

-- Clients, vendors, and messaging tables
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

-- Assets and inspections
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
  contact_name text,
  contact_email text,
  contact_phone text,
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

CREATE TABLE IF NOT EXISTS sop_documents (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references orgs(id) on delete cascade,
  title text not null,
  summary text,
  category text,
  tags text[] not null default '{}'::text[],
  status text not null default 'draft',
  current_version text,
  current_version_id uuid,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb
);

CREATE TABLE IF NOT EXISTS sop_versions (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references orgs(id) on delete cascade,
  sop_id uuid not null references sop_documents(id) on delete cascade,
  version text not null,
  body text,
  attachments jsonb not null default '[]'::jsonb,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb,
  unique (sop_id, version)
);

CREATE TABLE IF NOT EXISTS sop_approvals (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references orgs(id) on delete cascade,
  sop_id uuid not null references sop_documents(id) on delete cascade,
  version_id uuid references sop_versions(id) on delete set null,
  status text not null default 'pending',
  requested_by uuid references auth.users(id),
  requested_at timestamptz not null default now(),
  approved_by uuid references auth.users(id),
  approved_at timestamptz,
  notes text,
  metadata jsonb not null default '{}'::jsonb
);

CREATE TABLE IF NOT EXISTS sop_acknowledgements (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references orgs(id) on delete cascade,
  sop_id uuid not null references sop_documents(id) on delete cascade,
  version_id uuid references sop_versions(id) on delete set null,
  user_id uuid references auth.users(id),
  acknowledged_at timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb,
  unique (sop_id, version_id, user_id)
);

CREATE TABLE IF NOT EXISTS app_templates (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references orgs(id) on delete cascade,
  type text not null,
  name text not null,
  description text,
  payload jsonb not null default '{}'::jsonb,
  assigned_user_ids uuid[] not null default '{}'::uuid[],
  assigned_roles text[] not null default '{}'::text[],
  is_active boolean not null default true,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb
);

-- News, automation, and collaboration extensions
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

CREATE TABLE IF NOT EXISTS daily_logs (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references orgs(id) on delete cascade,
  project_id uuid references projects(id) on delete set null,
  log_date date not null default current_date,
  title text,
  content text,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
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

ALTER TABLE clients ENABLE ROW LEVEL SECURITY;
ALTER TABLE vendors ENABLE ROW LEVEL SECURITY;
ALTER TABLE message_threads ENABLE ROW LEVEL SECURITY;
ALTER TABLE message_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
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
ALTER TABLE daily_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE guest_invites ENABLE ROW LEVEL SECURITY;
ALTER TABLE payment_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE portfolio_items ENABLE ROW LEVEL SECURITY;

CREATE INDEX IF NOT EXISTS idx_clients_org ON clients(org_id);
CREATE INDEX IF NOT EXISTS idx_vendors_org ON vendors(org_id);
CREATE INDEX IF NOT EXISTS idx_threads_org ON message_threads(org_id);
CREATE INDEX IF NOT EXISTS idx_messages_thread ON messages(thread_id);
CREATE INDEX IF NOT EXISTS idx_messages_org ON messages(org_id);
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
CREATE INDEX IF NOT EXISTS idx_daily_logs_org ON daily_logs(org_id);
CREATE INDEX IF NOT EXISTS idx_daily_logs_project ON daily_logs(project_id);
CREATE INDEX IF NOT EXISTS idx_daily_logs_date ON daily_logs(log_date);
CREATE INDEX IF NOT EXISTS idx_guest_invites_org ON guest_invites(org_id);
CREATE INDEX IF NOT EXISTS idx_guest_invites_status ON guest_invites(status);
CREATE INDEX IF NOT EXISTS idx_payment_requests_org ON payment_requests(org_id);
CREATE INDEX IF NOT EXISTS idx_payment_requests_status ON payment_requests(status);
CREATE INDEX IF NOT EXISTS idx_reviews_org ON reviews(org_id);
CREATE INDEX IF NOT EXISTS idx_portfolio_items_org ON portfolio_items(org_id);
CREATE INDEX IF NOT EXISTS idx_portfolio_items_project ON portfolio_items(project_id);

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

-- Policies for clients, vendors, and messaging
DO $$
BEGIN
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

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Org members read daily logs') THEN
        CREATE POLICY "Org members read daily logs"
            ON daily_logs FOR SELECT
            USING (EXISTS (
                SELECT 1 FROM org_members m WHERE m.org_id = daily_logs.org_id AND m.user_id = auth.uid()
            ));
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Org members manage daily logs') THEN
        CREATE POLICY "Org members manage daily logs"
            ON daily_logs FOR ALL
            USING (EXISTS (
                SELECT 1 FROM org_members m WHERE m.org_id = daily_logs.org_id AND m.user_id = auth.uid()
            ))
            WITH CHECK (EXISTS (
                SELECT 1 FROM org_members m WHERE m.org_id = daily_logs.org_id AND m.user_id = auth.uid()
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

-- Verify the changes
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'forms' 
ORDER BY ordinal_position;

-- Form Templates for Supabase
-- Auto-generated from backend server
-- Total forms: 186
-- Run this in Supabase SQL Editor

BEGIN;

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'jobsite-safety',
  '00000000-0000-0000-0000-000000000001',
  'Job Site Safety Walk',
  '15-point safety walkthrough with photo capture',
  'Safety',
  ARRAY['safety', 'construction', 'audit'],
  true,
  '1.0.0',
  'system',
  '2025-12-14T16:07:24.108026',
  '[{"id":"siteName","label":"Site name","type":"text","placeholder":"South Plant 7","isRequired":true,"order":1},{"id":"inspector","label":"Inspector","type":"text","placeholder":"Your name","isRequired":true,"order":2},{"id":"ppe","label":"PPE compliance","type":"checkbox","options":["Hard hat","Vest","Gloves","Eye protection"],"isRequired":true,"order":3},{"id":"hazards","label":"Hazards observed","type":"textarea","order":4},{"id":"photos","label":"Attach photos","type":"photo","order":5},{"id":"location","label":"GPS location","type":"location","order":6},{"id":"signature","label":"Supervisor signature","type":"signature","order":7}]'::jsonb,
  '{"riskLevel":"medium"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'equipment-checkout',
  '00000000-0000-0000-0000-000000000001',
  'Equipment Checkout',
  'Log equipment issue/return with QR scan',
  'Operations',
  ARRAY['inventory', 'logistics', 'assets'],
  true,
  '1.1.0',
  'system',
  '2025-12-11T16:07:24.108980',
  '[{"id":"assetTag","label":"Asset tag / QR","type":"barcode","order":1,"isRequired":true},{"id":"condition","label":"Condition","type":"radio","options":["Excellent","Good","Fair","Damaged"],"order":2,"isRequired":true},{"id":"notes","label":"Notes","type":"textarea","order":3},{"id":"photos","label":"Proof of condition","type":"photo","order":4}]'::jsonb,
  '{"requiresSupervisor":true}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'visitor-log',
  '00000000-0000-0000-0000-000000000001',
  'Visitor Log',
  'Quick intake with badge printing flag',
  'Security',
  ARRAY['security', 'front-desk'],
  true,
  '0.9.0',
  'system',
  '2025-12-15T16:07:24.109026',
  '[{"id":"fullName","label":"Full name","type":"text","order":1,"isRequired":true},{"id":"company","label":"Company","type":"text","order":2},{"id":"host","label":"Host","type":"text","order":3},{"id":"purpose","label":"Purpose","type":"dropdown","options":["Delivery","Interview","Maintenance","Audit","Other"],"order":4},{"id":"arrivedAt","label":"Arrival time","type":"datetime","order":5},{"id":"badge","label":"Badge required","type":"toggle","order":6}]'::jsonb,
  '{}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'bar-inventory',
  '00000000-0000-0000-0000-000000000001',
  'Bar Inventory Count',
  'Fast bar/restaurant inventory with barcode scans and par levels',
  'Hospitality',
  ARRAY['hospitality', 'inventory', 'bar'],
  true,
  '1.0.0',
  'demo',
  '2025-12-12T16:07:24.109096',
  '[{"id":"location","label":"Bar location","type":"dropdown","options":["Main bar","Patio bar","Banquet bar"],"order":1,"isRequired":true},{"id":"bottles","label":"Bottle counts","type":"repeater","order":2,"children":[{"id":"sku","label":"SKU / Barcode","type":"barcode","order":1,"isRequired":true},{"id":"name","label":"Item name","type":"text","order":2,"isRequired":true},{"id":"par","label":"Par level (bottles)","type":"number","order":3},{"id":"onHand","label":"On-hand (bottles)","type":"number","order":4},{"id":"variance","label":"Variance","type":"computed","order":5,"calculations":{"expression":"onHand - par"}}]},{"id":"photos","label":"Shelf photos","type":"photo","order":3},{"id":"notes","label":"Notes","type":"textarea","order":4}]'::jsonb,
  '{"template":"hospitality-inventory"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'incident-report',
  '00000000-0000-0000-0000-000000000001',
  'Security Incident Report',
  'Capture security incidents with photos, severity, and signatures',
  'Security',
  ARRAY['security', 'incident', 'safety'],
  true,
  '1.0.0',
  'demo',
  '2025-12-15T16:07:24.109128',
  '[{"id":"incidentType","label":"Incident type","type":"dropdown","options":["Theft","Vandalism","Injury","Suspicious activity","Other"],"order":1,"isRequired":true},{"id":"severity","label":"Severity","type":"radio","options":["Low","Medium","High","Critical"],"order":2,"isRequired":true},{"id":"description","label":"Description","type":"textarea","order":3,"isRequired":true},{"id":"attachments","label":"Photo/video evidence","type":"photo","order":4},{"id":"witnesses","label":"Witnesses","type":"repeater","order":5,"children":[{"id":"name","label":"Name","type":"text","order":1},{"id":"contact","label":"Contact","type":"phone","order":2},{"id":"statement","label":"Statement","type":"textarea","order":3}]},{"id":"location","label":"GPS location","type":"location","order":6},{"id":"signature","label":"Reporting officer signature","type":"signature","order":7}]'::jsonb,
  '{"template":"security-incident"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'maintenance-check',
  '00000000-0000-0000-0000-000000000001',
  'Maintenance & Equipment Check',
  'Routine maintenance checklist with parts used and approvals',
  'Operations',
  ARRAY['maintenance', 'operations', 'equipment'],
  true,
  '1.0.0',
  'demo',
  '2025-12-13T16:07:24.109156',
  '[{"id":"asset","label":"Asset scanned","type":"barcode","order":1,"isRequired":true},{"id":"tasks","label":"Tasks performed","type":"checkbox","options":["Inspection","Lubrication","Calibration","Repair","Replacement"],"order":2},{"id":"parts","label":"Parts used","type":"table","order":3,"children":[{"id":"part","label":"Part #","type":"text","order":1},{"id":"qty","label":"Qty","type":"number","order":2}]},{"id":"photos","label":"Before/after photos","type":"photo","order":4},{"id":"notes","label":"Notes","type":"textarea","order":5},{"id":"approval","label":"Supervisor signature","type":"signature","order":6}]'::jsonb,
  '{"template":"maintenance"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'audit-checklist',
  '00000000-0000-0000-0000-000000000001',
  'Internal Audit Checklist',
  'ISO-style audit checklist with scoring and evidence',
  'Audit',
  ARRAY['audit', 'compliance', 'iso'],
  true,
  '1.0.0',
  'demo',
  '2025-12-14T16:07:24.109180',
  '[{"id":"area","label":"Area audited","type":"dropdown","options":["Warehouse","Production","Office","IT"],"order":1,"isRequired":true},{"id":"sections","label":"Audit items","type":"repeater","order":2,"children":[{"id":"clause","label":"Clause","type":"text","order":1},{"id":"score","label":"Score (0-5)","type":"number","order":2},{"id":"evidence","label":"Evidence","type":"photo","order":3}]},{"id":"overall","label":"Overall score","type":"computed","order":3,"calculations":{"expression":"score / 1"}},{"id":"actions","label":"Follow-up actions","type":"textarea","order":4}]'::jsonb,
  '{"template":"audit"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'food-safety-log',
  '00000000-0000-0000-0000-000000000001',
  'Food Safety & Temp Log',
  'HACCP-style log for temperatures, sanitizer, and corrective actions',
  'Food Safety',
  ARRAY['hospitality', 'food', 'safety'],
  true,
  '1.0.0',
  'demo',
  '2025-12-15T16:07:24.109204',
  '[{"id":"station","label":"Station","type":"dropdown","options":["Prep","Line","Walk-in","Dish"],"order":1},{"id":"readings","label":"Temperature readings","type":"table","order":2,"children":[{"id":"item","label":"Item","type":"text","order":1},{"id":"temp","label":"Temp (°F)","type":"number","order":2},{"id":"corrective","label":"Corrective action","type":"textarea","order":3}]},{"id":"sanitizer","label":"Sanitizer PPM","type":"number","order":3},{"id":"signature","label":"Supervisor signature","type":"signature","order":4}]'::jsonb,
  '{"template":"food-safety"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'hr-onboarding',
  '00000000-0000-0000-0000-000000000001',
  'HR Onboarding Checklist',
  'Collect documents, equipment, and training acknowledgements',
  'HR',
  ARRAY['hr', 'onboarding', 'people'],
  true,
  '1.0.0',
  'demo',
  '2025-12-10T16:07:24.109226',
  '[{"id":"employee","label":"Employee name","type":"text","order":1,"isRequired":true},{"id":"role","label":"Role","type":"text","order":2},{"id":"equipment","label":"Equipment issued","type":"checkbox","order":3,"options":["Laptop","Badge","PPE","Phone"]},{"id":"documents","label":"Documents collected","type":"files","order":4},{"id":"training","label":"Training acknowledgements","type":"repeater","order":5,"children":[{"id":"course","label":"Course","type":"text","order":1},{"id":"status","label":"Status","type":"dropdown","options":["Pending","Completed"],"order":2}]},{"id":"signature","label":"Manager signature","type":"signature","order":6}]'::jsonb,
  '{"template":"hr-onboarding"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'osha-incident',
  '00000000-0000-0000-0000-000000000001',
  'OSHA Recordable Incident',
  'Capture OSHA reportable incidents with severity, treatment, and root cause',
  'Safety',
  ARRAY['osha', 'safety', 'incident'],
  true,
  '1.0.0',
  'demo',
  '2025-12-09T16:07:24.109251',
  '[{"id":"incidentDate","label":"Incident date/time","type":"datetime","order":1,"isRequired":true},{"id":"classification","label":"Classification","type":"dropdown","options":["Recordable","First aid","Near miss"],"order":2,"isRequired":true},{"id":"injuryType","label":"Injury type","type":"checkbox","options":["Laceration","Sprain","Fracture","Burn","Other"],"order":3},{"id":"treatment","label":"Treatment","type":"textarea","order":4},{"id":"attachments","label":"Photos","type":"photo","order":5},{"id":"rootCause","label":"Root cause","type":"textarea","order":6},{"id":"signature","label":"Safety officer signature","type":"signature","order":7}]'::jsonb,
  '{"template":"osha"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'vehicle-inspection',
  '00000000-0000-0000-0000-000000000001',
  'Vehicle / DVIR Inspection',
  'Daily vehicle inspection with defects and sign-off',
  'Fleet',
  ARRAY['fleet', 'dvir', 'transport'],
  true,
  '1.0.0',
  'demo',
  '2025-12-14T16:07:24.109275',
  '[{"id":"vehicleId","label":"Vehicle ID","type":"text","order":1,"isRequired":true},{"id":"odometer","label":"Odometer","type":"number","order":2},{"id":"checks","label":"Inspection items","type":"checkbox","options":["Lights","Brakes","Tires","Fluids","Wipers","Horn"],"order":3},{"id":"defects","label":"Defects noted","type":"repeater","order":4,"children":[{"id":"component","label":"Component","type":"text","order":1},{"id":"severity","label":"Severity","type":"dropdown","options":["Low","Med","High"],"order":2}]},{"id":"photos","label":"Photos","type":"photo","order":5},{"id":"signature","label":"Driver signature","type":"signature","order":6}]'::jsonb,
  '{"template":"dvir"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'retail-audit',
  '00000000-0000-0000-0000-000000000001',
  'Retail Store Audit',
  'Merchandising, pricing, cleanliness, and compliance audit',
  'Retail',
  ARRAY['retail', 'audit', 'merchandising'],
  true,
  '1.0.0',
  'demo',
  '2025-12-13T16:07:24.109299',
  '[{"id":"store","label":"Store ID","type":"text","order":1},{"id":"pricing","label":"Pricing accuracy","type":"radio","options":["Excellent","Good","Fair","Poor"],"order":2},{"id":"displays","label":"Display compliance","type":"checkbox","options":["Endcaps set","Promo signage","Planogram alignment"],"order":3},{"id":"photos","label":"Shelf photos","type":"photo","order":4},{"id":"issues","label":"Issues","type":"textarea","order":5}]'::jsonb,
  '{"template":"retail-audit"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'patient-rounding',
  '00000000-0000-0000-0000-000000000001',
  'Patient Rounding Checklist',
  'Nurse rounding checklist with vitals and comfort checks',
  'Healthcare',
  ARRAY['healthcare', 'rounding', 'hospital'],
  true,
  '1.0.0',
  'demo',
  '2025-12-15T16:07:24.109320',
  '[{"id":"patient","label":"Patient name","type":"text","order":1},{"id":"room","label":"Room","type":"text","order":2},{"id":"vitals","label":"Vitals OK","type":"toggle","order":3},{"id":"comfort","label":"Comfort checks","type":"checkbox","options":["Pain","Position","Potty","Periphery","Personal items"],"order":4},{"id":"notes","label":"Notes","type":"textarea","order":5},{"id":"signature","label":"Nurse signature","type":"signature","order":6}]'::jsonb,
  '{"template":"patient-rounding"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'insurance-claim',
  '00000000-0000-0000-0000-000000000001',
  'Insurance Claim Intake',
  'Capture incident details, parties involved, and evidence',
  'Insurance',
  ARRAY['insurance', 'claims', 'intake'],
  true,
  '1.0.0',
  'demo',
  '2025-12-12T16:07:24.109339',
  '[{"id":"claimant","label":"Claimant name","type":"text","order":1,"isRequired":true},{"id":"policy","label":"Policy #","type":"text","order":2},{"id":"lossDate","label":"Loss date","type":"date","order":3},{"id":"lossType","label":"Loss type","type":"dropdown","options":["Auto","Property","Injury"],"order":4},{"id":"description","label":"Description","type":"textarea","order":5},{"id":"attachments","label":"Evidence","type":"photo","order":6},{"id":"signature","label":"Adjuster signature","type":"signature","order":7}]'::jsonb,
  '{"template":"insurance-claim"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'facility-work-order',
  '00000000-0000-0000-0000-000000000001',
  'Facility Work Order',
  'Log facility issues, priority, and completion proof',
  'Facilities',
  ARRAY['facilities', 'maintenance', 'work-order'],
  true,
  '1.0.0',
  'demo',
  '2025-12-14T16:07:24.109361',
  '[{"id":"location","label":"Location","type":"text","order":1,"isRequired":true},{"id":"priority","label":"Priority","type":"dropdown","options":["Low","Medium","High"],"order":2},{"id":"issue","label":"Issue description","type":"textarea","order":3},{"id":"photos","label":"Photos","type":"photo","order":4},{"id":"completed","label":"Completed","type":"toggle","order":5},{"id":"signature","label":"Supervisor sign-off","type":"signature","order":6}]'::jsonb,
  '{"template":"facility-work-order"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'daily-report',
  '00000000-0000-0000-0000-000000000001',
  'Construction Daily Report',
  'Weather, manpower, equipment, delays, and photos',
  'Construction',
  ARRAY['construction', 'daily', 'report'],
  true,
  '1.0.0',
  'demo',
  '2025-12-15T16:07:24.109381',
  '[{"id":"weather","label":"Weather","type":"dropdown","options":["Clear","Cloudy","Rain","Snow"],"order":1},{"id":"crew","label":"Crew on site","type":"number","order":2},{"id":"equipment","label":"Key equipment in use","type":"checkbox","options":["Crane","Loader","Lift","Compactor"],"order":3},{"id":"delays","label":"Delays/Issues","type":"textarea","order":4},{"id":"photos","label":"Site photos","type":"photo","order":5}]'::jsonb,
  '{"template":"daily-report"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'quality-inspection',
  '00000000-0000-0000-0000-000000000001',
  'Quality Inspection',
  'Punchlist/quality inspection with defects and photos',
  'Quality',
  ARRAY['quality', 'inspection', 'punchlist'],
  true,
  '1.0.0',
  'demo',
  '2025-12-14T16:07:24.109406',
  '[{"id":"area","label":"Area/Room","type":"text","order":1},{"id":"items","label":"Items inspected","type":"table","order":2,"children":[{"id":"item","label":"Item","type":"text","order":1},{"id":"status","label":"Status","type":"dropdown","options":["Pass","Fail"],"order":2}]},{"id":"photos","label":"Photos","type":"photo","order":3},{"id":"signature","label":"Inspector signature","type":"signature","order":4}]'::jsonb,
  '{"template":"quality-inspection"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'environmental-audit',
  '00000000-0000-0000-0000-000000000001',
  'Environmental Audit',
  'Spill kits, waste, emissions, and observations',
  'Environmental',
  ARRAY['environmental', 'audit', 'compliance'],
  true,
  '1.0.0',
  'demo',
  '2025-12-11T16:07:24.109429',
  '[{"id":"spillKits","label":"Spill kits stocked","type":"toggle","order":1},{"id":"waste","label":"Waste storage","type":"dropdown","options":["Compliant","Needs attention"],"order":2},{"id":"observations","label":"Observations","type":"textarea","order":3},{"id":"photos","label":"Photos","type":"photo","order":4},{"id":"signature","label":"Auditor signature","type":"signature","order":5}]'::jsonb,
  '{"template":"environmental-audit"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'customer-feedback',
  '00000000-0000-0000-0000-000000000001',
  'Customer Feedback',
  'Capture CSAT, comments, and follow-up details',
  'Customer',
  ARRAY['customer', 'feedback', 'csat'],
  true,
  '1.0.0',
  'demo',
  '2025-12-13T16:07:24.109446',
  '[{"id":"name","label":"Name","type":"text","order":1},{"id":"rating","label":"Satisfaction (1-5)","type":"number","order":2},{"id":"comments","label":"Comments","type":"textarea","order":3},{"id":"followup","label":"Need follow-up","type":"toggle","order":4}]'::jsonb,
  '{"template":"customer-feedback"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'it-ticket',
  '00000000-0000-0000-0000-000000000001',
  'IT Ticket',
  'Issue category, device, severity, attachments, and sign-off',
  'IT',
  ARRAY['it', 'ticket', 'support'],
  true,
  '1.0.0',
  'demo',
  '2025-12-12T16:07:24.109462',
  '[{"id":"user","label":"User","type":"text","order":1},{"id":"device","label":"Device","type":"text","order":2},{"id":"category","label":"Category","type":"dropdown","options":["Access","Hardware","Software","Network"],"order":3},{"id":"severity","label":"Severity","type":"dropdown","options":["Low","Medium","High"],"order":4},{"id":"description","label":"Description","type":"textarea","order":5},{"id":"attachments","label":"Attachments","type":"photo","order":6},{"id":"signature","label":"Technician signature","type":"signature","order":7}]'::jsonb,
  '{"template":"it-ticket"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'safety-observation',
  '00000000-0000-0000-0000-000000000001',
  'Safety Observation',
  'Positive/negative safety observations with photos and categories',
  'Safety',
  ARRAY['safety', 'observation', 'behavior'],
  true,
  '1.0.0',
  'demo',
  '2025-12-14T16:07:24.109482',
  '[{"id":"type","label":"Type","type":"dropdown","options":["Safe act","At risk"],"order":1,"isRequired":true},{"id":"location","label":"Location","type":"text","order":2},{"id":"details","label":"Details","type":"textarea","order":3},{"id":"photos","label":"Photos","type":"photo","order":4}]'::jsonb,
  '{"template":"safety-observation"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'ppe-compliance',
  '00000000-0000-0000-0000-000000000001',
  'PPE Compliance Check',
  'Verify PPE usage by zone and trade',
  'Safety',
  ARRAY['safety', 'ppe', 'compliance'],
  true,
  '1.0.0',
  'demo',
  '2025-12-13T16:07:24.109503',
  '[{"id":"zone","label":"Zone","type":"text","order":1},{"id":"trade","label":"Trade","type":"text","order":2},{"id":"ppe","label":"PPE present","type":"checkbox","options":["Hard hat","Gloves","Eye protection","Hi-Vis"],"order":3},{"id":"notes","label":"Notes","type":"textarea","order":4}]'::jsonb,
  '{"template":"ppe-compliance"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'inventory-replenishment',
  '00000000-0000-0000-0000-000000000001',
  'Inventory Replenishment',
  'Scan SKUs, record counts, request replenishment',
  'Operations',
  ARRAY['operations', 'inventory', 'logistics'],
  true,
  '1.0.0',
  'demo',
  '2025-12-15T16:07:24.109531',
  '[{"id":"location","label":"Location","type":"text","order":1},{"id":"items","label":"Items","type":"table","order":2,"children":[{"id":"sku","label":"SKU","type":"barcode","order":1},{"id":"onHand","label":"On-hand","type":"number","order":2},{"id":"par","label":"Par","type":"number","order":3}]},{"id":"notes","label":"Notes","type":"textarea","order":3}]'::jsonb,
  '{"template":"inventory-replenishment"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'shift-handover',
  '00000000-0000-0000-0000-000000000001',
  'Shift Handover',
  'Operations shift handover with issues, priorities, and approvals',
  'Operations',
  ARRAY['operations', 'handover', 'shift'],
  true,
  '1.0.0',
  'demo',
  '2025-12-14T16:07:24.109550',
  '[{"id":"outgoing","label":"Outgoing supervisor","type":"text","order":1},{"id":"incoming","label":"Incoming supervisor","type":"text","order":2},{"id":"issues","label":"Issues","type":"textarea","order":3},{"id":"priority","label":"Priority tasks","type":"textarea","order":4},{"id":"signature","label":"Sign-off","type":"signature","order":5}]'::jsonb,
  '{"template":"shift-handover"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'performance-review',
  '00000000-0000-0000-0000-000000000001',
  'Performance Review',
  'HR performance review with ratings and comments',
  'HR',
  ARRAY['hr', 'review', 'performance'],
  true,
  '1.0.0',
  'demo',
  '2025-12-11T16:07:24.109568',
  '[{"id":"employee","label":"Employee","type":"text","order":1,"isRequired":true},{"id":"role","label":"Role","type":"text","order":2},{"id":"rating","label":"Overall rating (1-5)","type":"number","order":3},{"id":"strengths","label":"Strengths","type":"textarea","order":4},{"id":"improvements","label":"Improvements","type":"textarea","order":5},{"id":"signature","label":"Manager signature","type":"signature","order":6}]'::jsonb,
  '{"template":"performance-review"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'fuel-log',
  '00000000-0000-0000-0000-000000000001',
  'Fuel Log',
  'Track fuel fills for fleet vehicles with odometer and receipts',
  'Fleet',
  ARRAY['fleet', 'fuel', 'log'],
  true,
  '1.0.0',
  'demo',
  '2025-12-15T16:07:24.109587',
  '[{"id":"vehicleId","label":"Vehicle ID","type":"text","order":1},{"id":"odometer","label":"Odometer","type":"number","order":2},{"id":"gallons","label":"Gallons/Liters","type":"number","order":3},{"id":"cost","label":"Cost","type":"number","order":4},{"id":"receipt","label":"Receipt photo","type":"photo","order":5}]'::jsonb,
  '{"template":"fuel-log"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'mystery-shopper',
  '00000000-0000-0000-0000-000000000001',
  'Mystery Shopper',
  'Retail mystery shop checklist with scores and notes',
  'Retail',
  ARRAY['retail', 'mystery', 'shopper'],
  true,
  '1.0.0',
  'demo',
  '2025-12-14T16:07:24.109615',
  '[{"id":"store","label":"Store","type":"text","order":1},{"id":"greeting","label":"Greeting","type":"radio","options":["Yes","No"],"order":2},{"id":"cleanliness","label":"Cleanliness score (1-5)","type":"number","order":3},{"id":"service","label":"Service score (1-5)","type":"number","order":4},{"id":"notes","label":"Notes","type":"textarea","order":5}]'::jsonb,
  '{"template":"mystery-shopper"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'patient-intake',
  '00000000-0000-0000-0000-000000000001',
  'Patient Intake',
  'Healthcare intake form for patient info, symptoms, and consent',
  'Healthcare',
  ARRAY['healthcare', 'intake', 'patient'],
  true,
  '1.0.0',
  'demo',
  '2025-12-13T16:07:24.109633',
  '[{"id":"name","label":"Patient name","type":"text","order":1},{"id":"dob","label":"Date of birth","type":"date","order":2},{"id":"symptoms","label":"Symptoms","type":"textarea","order":3},{"id":"consent","label":"Consent signed","type":"toggle","order":4},{"id":"signature","label":"Patient signature","type":"signature","order":5}]'::jsonb,
  '{"template":"patient-intake"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'risk-assessment',
  '00000000-0000-0000-0000-000000000001',
  'Insurance Risk Assessment',
  'On-site insurance risk assessment with hazards and scoring',
  'Insurance',
  ARRAY['insurance', 'risk', 'assessment'],
  true,
  '1.0.0',
  'demo',
  '2025-12-15T16:07:24.109649',
  '[{"id":"site","label":"Site","type":"text","order":1},{"id":"hazards","label":"Hazards","type":"textarea","order":2},{"id":"score","label":"Risk score (1-5)","type":"number","order":3},{"id":"photos","label":"Photos","type":"photo","order":4}]'::jsonb,
  '{"template":"risk-assessment"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'cleaning-checklist',
  '00000000-0000-0000-0000-000000000001',
  'Cleaning Checklist',
  'Facilities cleaning checklist with rooms and completion status',
  'Facilities',
  ARRAY['facilities', 'cleaning', 'janitorial'],
  true,
  '1.0.0',
  'demo',
  '2025-12-14T16:07:24.109729',
  '[{"id":"area","label":"Area","type":"text","order":1},{"id":"tasks","label":"Tasks","type":"table","order":2,"children":[{"id":"task","label":"Task","type":"text","order":1},{"id":"status","label":"Status","type":"dropdown","options":["Pending","Done"],"order":2}]},{"id":"signature","label":"Supervisor signature","type":"signature","order":3}]'::jsonb,
  '{"template":"cleaning-checklist"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'toolbox-talk',
  '00000000-0000-0000-0000-000000000001',
  'Toolbox Talk',
  'Construction safety briefing with attendees and topics',
  'Construction',
  ARRAY['construction', 'safety', 'talk'],
  true,
  '1.0.0',
  'demo',
  '2025-12-15T16:07:24.109799',
  '[{"id":"topic","label":"Topic","type":"text","order":1},{"id":"attendees","label":"Attendees","type":"repeater","order":2,"children":[{"id":"name","label":"Name","type":"text","order":1},{"id":"company","label":"Company","type":"text","order":2}]},{"id":"notes","label":"Notes","type":"textarea","order":3},{"id":"signature","label":"Supervisor signature","type":"signature","order":4}]'::jsonb,
  '{"template":"toolbox-talk"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'ncr',
  '00000000-0000-0000-0000-000000000001',
  'Nonconformance Report',
  'Quality NCR with defect type, location, and disposition',
  'Quality',
  ARRAY['quality', 'ncr', 'defect'],
  true,
  '1.0.0',
  'demo',
  '2025-12-13T16:07:24.109837',
  '[{"id":"defect","label":"Defect","type":"text","order":1},{"id":"location","label":"Location","type":"text","order":2},{"id":"disposition","label":"Disposition","type":"dropdown","options":["Rework","Scrap","Use-as-is"],"order":3},{"id":"photos","label":"Photos","type":"photo","order":4},{"id":"signature","label":"Quality signature","type":"signature","order":5}]'::jsonb,
  '{"template":"ncr"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'waste-manifest',
  '00000000-0000-0000-0000-000000000001',
  'Waste Manifest',
  'Track waste type, quantity, container, and pickup details',
  'Environmental',
  ARRAY['environmental', 'waste', 'manifest'],
  true,
  '1.0.0',
  'demo',
  '2025-12-14T16:07:24.109864',
  '[{"id":"wasteType","label":"Waste type","type":"text","order":1},{"id":"quantity","label":"Quantity","type":"number","order":2},{"id":"container","label":"Container","type":"dropdown","options":["Drum","Tote","Box"],"order":3},{"id":"pickup","label":"Pickup date","type":"date","order":4},{"id":"signature","label":"Handler signature","type":"signature","order":5}]'::jsonb,
  '{"template":"waste-manifest"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'nps-survey',
  '00000000-0000-0000-0000-000000000001',
  'NPS Survey',
  'Customer NPS survey with score and feedback',
  'Customer',
  ARRAY['customer', 'nps', 'feedback'],
  true,
  '1.0.0',
  'demo',
  '2025-12-15T16:07:24.109899',
  '[{"id":"name","label":"Name","type":"text","order":1},{"id":"score","label":"Score (0-10)","type":"number","order":2},{"id":"feedback","label":"Feedback","type":"textarea","order":3}]'::jsonb,
  '{"template":"nps-survey"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'change-request',
  '00000000-0000-0000-0000-000000000001',
  'IT Change Request',
  'IT change request with risk, rollout plan, and approvals',
  'IT',
  ARRAY['it', 'change', 'request'],
  true,
  '1.0.0',
  'demo',
  '2025-12-14T16:07:24.109939',
  '[{"id":"title","label":"Change title","type":"text","order":1},{"id":"risk","label":"Risk level","type":"dropdown","options":["Low","Medium","High"],"order":2},{"id":"plan","label":"Rollout plan","type":"textarea","order":3},{"id":"backout","label":"Backout plan","type":"textarea","order":4},{"id":"signature","label":"Approver signature","type":"signature","order":5}]'::jsonb,
  '{"template":"change-request"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'fai',
  '00000000-0000-0000-0000-000000000001',
  'First Article Inspection',
  'Manufacturing FAI with dimensions, tolerances, and dispositions',
  'Quality',
  ARRAY['quality', 'manufacturing', 'fai'],
  true,
  '1.0.0',
  'demo',
  '2025-12-15T16:07:24.109982',
  '[{"id":"partNumber","label":"Part number","type":"text","order":1,"isRequired":true},{"id":"revision","label":"Revision","type":"text","order":2},{"id":"characteristics","label":"Characteristics","type":"table","order":3,"children":[{"id":"char","label":"Characteristic","type":"text","order":1},{"id":"nominal","label":"Nominal","type":"text","order":2},{"id":"actual","label":"Actual","type":"text","order":3},{"id":"result","label":"Result","type":"dropdown","options":["Pass","Fail"],"order":4}]},{"id":"photos","label":"Photos","type":"photo","order":4},{"id":"signature","label":"Inspector signature","type":"signature","order":5}]'::jsonb,
  '{"template":"fai"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'pod',
  '00000000-0000-0000-0000-000000000001',
  'Proof of Delivery',
  'Logistics POD with recipient, condition, and photos',
  'Operations',
  ARRAY['logistics', 'delivery', 'pod'],
  true,
  '1.0.0',
  'demo',
  '2025-12-15T16:07:24.110049',
  '[{"id":"shipment","label":"Shipment ID","type":"text","order":1,"isRequired":true},{"id":"recipient","label":"Recipient name","type":"text","order":2},{"id":"condition","label":"Package condition","type":"dropdown","options":["Intact","Damaged"],"order":3},{"id":"photos","label":"Delivery photos","type":"photo","order":4},{"id":"signature","label":"Recipient signature","type":"signature","order":5}]'::jsonb,
  '{"template":"pod"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'housekeeping',
  '00000000-0000-0000-0000-000000000001',
  'Housekeeping Checklist',
  'Hospitality housekeeping checks with room readiness and defects',
  'Operations',
  ARRAY['hospitality', 'housekeeping', 'room'],
  true,
  '1.0.0',
  'demo',
  '2025-12-14T16:07:24.110084',
  '[{"id":"room","label":"Room #","type":"text","order":1},{"id":"status","label":"Status","type":"dropdown","options":["Clean","Needs attention"],"order":2},{"id":"amenities","label":"Amenities stocked","type":"checkbox","options":["Towels","Toiletries","Water","Coffee"],"order":3},{"id":"issues","label":"Issues","type":"textarea","order":4},{"id":"photos","label":"Photos","type":"photo","order":5}]'::jsonb,
  '{"template":"housekeeping"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'guard-tour',
  '00000000-0000-0000-0000-000000000001',
  'Security Guard Tour',
  'Guard tour checkpoints with scan, notes, and incidents',
  'Security',
  ARRAY['security', 'tour', 'guard'],
  true,
  '1.0.0',
  'demo',
  '2025-12-15T16:07:24.110115',
  '[{"id":"route","label":"Route","type":"text","order":1},{"id":"checkpoints","label":"Checkpoints","type":"repeater","order":2,"children":[{"id":"tag","label":"Checkpoint tag","type":"barcode","order":1},{"id":"status","label":"Status","type":"dropdown","options":["Clear","Issue"],"order":2},{"id":"notes","label":"Notes","type":"textarea","order":3}]},{"id":"photos","label":"Photos","type":"photo","order":3},{"id":"signature","label":"Guard signature","type":"signature","order":4}]'::jsonb,
  '{"template":"guard-tour"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'drill-report',
  '00000000-0000-0000-0000-000000000001',
  'Safety Drill Report',
  'Education/safety drill with participants, timing, and issues',
  'Safety',
  ARRAY['safety', 'drill', 'education'],
  true,
  '1.0.0',
  'demo',
  '2025-12-12T16:07:24.110153',
  '[{"id":"type","label":"Drill type","type":"dropdown","options":["Fire","Earthquake","Lockdown"],"order":1},{"id":"duration","label":"Duration (min)","type":"number","order":2},{"id":"participants","label":"Participants","type":"number","order":3},{"id":"issues","label":"Issues observed","type":"textarea","order":4}]'::jsonb,
  '{"template":"drill-report"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'batch-record',
  '00000000-0000-0000-0000-000000000001',
  'Pharma Batch Record',
  'Pharmaceutical batch record with lot, steps, and sign-offs',
  'Quality',
  ARRAY['pharma', 'batch', 'quality'],
  true,
  '1.0.0',
  'demo',
  '2025-12-13T16:07:24.110190',
  '[{"id":"lot","label":"Lot #","type":"text","order":1,"isRequired":true},{"id":"product","label":"Product","type":"text","order":2},{"id":"steps","label":"Steps","type":"repeater","order":3,"children":[{"id":"step","label":"Step","type":"text","order":1},{"id":"time","label":"Time","type":"time","order":2},{"id":"operator","label":"Operator","type":"text","order":3}]},{"id":"signature","label":"QA signature","type":"signature","order":4}]'::jsonb,
  '{"template":"batch-record"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'confined-space-entry',
  '00000000-0000-0000-0000-000000000001',
  'Confined Space Entry Permit',
  'Pre-entry checklist, atmospheric testing, and rescue plan',
  'Safety',
  ARRAY['safety', 'permit', 'confined-space'],
  true,
  '1.0.0',
  'system',
  '2025-12-11T16:07:24.110228',
  '[{"id":"location","label":"Space location","type":"text","order":1,"isRequired":true},{"id":"o2Level","label":"O2 level (%)","type":"number","order":2},{"id":"lel","label":"LEL (%)","type":"number","order":3},{"id":"h2s","label":"H2S (ppm)","type":"number","order":4},{"id":"rescuePlan","label":"Rescue plan","type":"textarea","order":5},{"id":"signature","label":"Supervisor signature","type":"signature","order":6}]'::jsonb,
  '{"template":"confined-space"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'hot-work-permit',
  '00000000-0000-0000-0000-000000000001',
  'Hot Work Permit',
  'Welding, cutting, grinding safety authorization',
  'Safety',
  ARRAY['safety', 'permit', 'hot-work'],
  true,
  '1.0.0',
  'system',
  '2025-12-10T16:07:24.110250',
  '[{"id":"workType","label":"Work type","type":"dropdown","options":["Welding","Cutting","Grinding","Other"],"order":1},{"id":"fireWatch","label":"Fire watch assigned","type":"toggle","order":2},{"id":"extinguisher","label":"Fire extinguisher present","type":"toggle","order":3},{"id":"flammables","label":"Flammables removed","type":"toggle","order":4},{"id":"photos","label":"Area photos","type":"photo","order":5}]'::jsonb,
  '{"template":"hot-work"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'lockout-tagout',
  '00000000-0000-0000-0000-000000000001',
  'Lockout/Tagout (LOTO)',
  'Energy isolation procedure verification',
  'Safety',
  ARRAY['safety', 'loto', 'maintenance'],
  true,
  '1.0.0',
  'system',
  '2025-12-09T16:07:24.110270',
  '[{"id":"equipment","label":"Equipment","type":"text","order":1,"isRequired":true},{"id":"energySources","label":"Energy sources","type":"checkbox","options":["Electrical","Hydraulic","Pneumatic","Thermal"],"order":2},{"id":"locks","label":"Lock numbers","type":"text","order":3},{"id":"verified","label":"Zero energy verified","type":"toggle","order":4}]'::jsonb,
  '{"template":"loto"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'fire-extinguisher-inspection',
  '00000000-0000-0000-0000-000000000001',
  'Fire Extinguisher Inspection',
  'Monthly fire extinguisher check',
  'Safety',
  ARRAY['safety', 'fire', 'inspection'],
  true,
  '1.0.0',
  'system',
  '2025-12-08T16:07:24.110299',
  '[{"id":"location","label":"Location","type":"text","order":1},{"id":"unitId","label":"Unit ID","type":"text","order":2},{"id":"pressure","label":"Pressure OK","type":"toggle","order":3},{"id":"seal","label":"Seal intact","type":"toggle","order":4},{"id":"photos","label":"Photos","type":"photo","order":5}]'::jsonb,
  '{"template":"fire-extinguisher"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'fall-protection-inspection',
  '00000000-0000-0000-0000-000000000001',
  'Fall Protection Equipment Inspection',
  'Harness, lanyard, and anchor point check',
  'Safety',
  ARRAY['safety', 'fall-protection', 'ppe'],
  true,
  '1.0.0',
  'system',
  '2025-12-07T16:07:24.110322',
  '[{"id":"equipmentId","label":"Equipment ID","type":"text","order":1},{"id":"type","label":"Type","type":"dropdown","options":["Harness","Lanyard","Anchor","SRL"],"order":2},{"id":"condition","label":"Condition","type":"dropdown","options":["Good","Fair","Replace"],"order":3},{"id":"defects","label":"Defects noted","type":"textarea","order":4}]'::jsonb,
  '{"template":"fall-protection"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'ergonomic-assessment',
  '00000000-0000-0000-0000-000000000001',
  'Workstation Ergonomic Assessment',
  'Desk, chair, monitor positioning evaluation',
  'Safety',
  ARRAY['safety', 'ergonomics', 'health'],
  true,
  '1.0.0',
  'system',
  '2025-12-06T16:07:24.110352',
  '[{"id":"employee","label":"Employee name","type":"text","order":1},{"id":"chairHeight","label":"Chair height OK","type":"toggle","order":2},{"id":"monitorHeight","label":"Monitor at eye level","type":"toggle","order":3},{"id":"recommendations","label":"Recommendations","type":"textarea","order":4}]'::jsonb,
  '{"template":"ergonomic"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'ladder-inspection',
  '00000000-0000-0000-0000-000000000001',
  'Ladder Safety Inspection',
  'Pre-use ladder condition check',
  'Safety',
  ARRAY['safety', 'ladder', 'equipment'],
  true,
  '1.0.0',
  'system',
  '2025-12-05T16:07:24.110370',
  '[{"id":"ladderType","label":"Type","type":"dropdown","options":["Step","Extension","Platform"],"order":1},{"id":"rungsOk","label":"Rungs intact","type":"toggle","order":2},{"id":"feetOk","label":"Feet secure","type":"toggle","order":3},{"id":"passed","label":"Passed inspection","type":"toggle","order":4}]'::jsonb,
  '{"template":"ladder"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'toolbox-talk',
  '00000000-0000-0000-0000-000000000001',
  'Toolbox Talk Record',
  'Safety meeting topics and attendance',
  'Safety',
  ARRAY['safety', 'training', 'meeting'],
  true,
  '1.0.0',
  'system',
  '2025-12-04T16:07:24.110397',
  '[{"id":"topic","label":"Topic","type":"text","order":1},{"id":"presenter","label":"Presenter","type":"text","order":2},{"id":"attendees","label":"Attendees","type":"textarea","order":3},{"id":"duration","label":"Duration (min)","type":"number","order":4}]'::jsonb,
  '{"template":"toolbox-talk"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'chemical-spill-response',
  '00000000-0000-0000-0000-000000000001',
  'Chemical Spill Response Log',
  'Spill containment and cleanup documentation',
  'Safety',
  ARRAY['safety', 'chemical', 'emergency'],
  true,
  '1.0.0',
  'system',
  '2025-12-03T16:07:24.110419',
  '[{"id":"chemical","label":"Chemical name","type":"text","order":1},{"id":"quantity","label":"Quantity spilled","type":"text","order":2},{"id":"containment","label":"Containment method","type":"textarea","order":3},{"id":"disposal","label":"Disposal method","type":"textarea","order":4},{"id":"photos","label":"Photos","type":"photo","order":5}]'::jsonb,
  '{"template":"chemical-spill"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'emergency-evacuation-drill',
  '00000000-0000-0000-0000-000000000001',
  'Emergency Evacuation Drill',
  'Evacuation timing, issues, and attendance',
  'Safety',
  ARRAY['safety', 'emergency', 'drill'],
  true,
  '1.0.0',
  'system',
  '2025-12-02T16:07:24.110442',
  '[{"id":"type","label":"Drill type","type":"dropdown","options":["Fire","Severe Weather","Active Threat"],"order":1},{"id":"evacuationTime","label":"Evacuation time (min)","type":"number","order":2},{"id":"headcount","label":"Headcount complete","type":"toggle","order":3},{"id":"issues","label":"Issues noted","type":"textarea","order":4}]'::jsonb,
  '{"template":"evacuation-drill"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'equipment-startup',
  '00000000-0000-0000-0000-000000000001',
  'Equipment Startup Checklist',
  'Pre-operation checks and systems verification',
  'Operations',
  ARRAY['operations', 'equipment', 'startup'],
  true,
  '1.0.0',
  'system',
  '2025-12-01T16:07:24.110472',
  '[{"id":"equipment","label":"Equipment name","type":"text","order":1},{"id":"oilLevel","label":"Oil level OK","type":"toggle","order":2},{"id":"coolantLevel","label":"Coolant level OK","type":"toggle","order":3},{"id":"gauges","label":"All gauges functional","type":"toggle","order":4},{"id":"notes","label":"Notes","type":"textarea","order":5}]'::jsonb,
  '{"template":"equipment-startup"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'shift-handover',
  '00000000-0000-0000-0000-000000000001',
  'Shift Handover Report',
  'Production status and issues for next shift',
  'Operations',
  ARRAY['operations', 'shift', 'handover'],
  true,
  '1.0.0',
  'system',
  '2025-11-30T16:07:24.110498',
  '[{"id":"shift","label":"Shift","type":"dropdown","options":["Day","Evening","Night"],"order":1},{"id":"production","label":"Units produced","type":"number","order":2},{"id":"issues","label":"Issues","type":"textarea","order":3},{"id":"nextShift","label":"Notes for next shift","type":"textarea","order":4}]'::jsonb,
  '{"template":"shift-handover"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'production-downtime',
  '00000000-0000-0000-0000-000000000001',
  'Production Downtime Log',
  'Equipment stoppage cause and duration',
  'Operations',
  ARRAY['operations', 'downtime', 'production'],
  true,
  '1.0.0',
  'system',
  '2025-11-29T16:07:24.110525',
  '[{"id":"equipment","label":"Equipment","type":"text","order":1},{"id":"startTime","label":"Start time","type":"time","order":2},{"id":"endTime","label":"End time","type":"time","order":3},{"id":"cause","label":"Cause","type":"dropdown","options":["Mechanical","Electrical","Material","Other"],"order":4},{"id":"resolution","label":"Resolution","type":"textarea","order":5}]'::jsonb,
  '{"template":"downtime"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'quality-control-check',
  '00000000-0000-0000-0000-000000000001',
  'In-Process Quality Check',
  'Real-time product inspection during production',
  'Operations',
  ARRAY['operations', 'quality', 'inspection'],
  true,
  '1.0.0',
  'system',
  '2025-11-28T16:07:24.110550',
  '[{"id":"product","label":"Product","type":"text","order":1},{"id":"batchNumber","label":"Batch number","type":"text","order":2},{"id":"passed","label":"Passed QC","type":"toggle","order":3},{"id":"defects","label":"Defects","type":"textarea","order":4},{"id":"photos","label":"Photos","type":"photo","order":5}]'::jsonb,
  '{"template":"qc-check"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'material-receiving',
  '00000000-0000-0000-0000-000000000001',
  'Material Receiving Inspection',
  'Incoming material verification and acceptance',
  'Operations',
  ARRAY['operations', 'receiving', 'inspection'],
  true,
  '1.0.0',
  'system',
  '2025-11-27T16:07:24.110574',
  '[{"id":"poNumber","label":"PO number","type":"text","order":1},{"id":"supplier","label":"Supplier","type":"text","order":2},{"id":"quantity","label":"Quantity received","type":"number","order":3},{"id":"condition","label":"Condition","type":"dropdown","options":["Acceptable","Damaged","Rejected"],"order":4},{"id":"notes","label":"Notes","type":"textarea","order":5}]'::jsonb,
  '{"template":"material-receiving"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'warehouse-cycle-count',
  '00000000-0000-0000-0000-000000000001',
  'Warehouse Cycle Count',
  'Inventory verification by location',
  'Operations',
  ARRAY['operations', 'warehouse', 'inventory'],
  true,
  '1.0.0',
  'system',
  '2025-11-26T16:07:24.110604',
  '[{"id":"location","label":"Location","type":"text","order":1},{"id":"sku","label":"SKU","type":"text","order":2},{"id":"systemQty","label":"System quantity","type":"number","order":3},{"id":"actualQty","label":"Actual quantity","type":"number","order":4},{"id":"variance","label":"Variance","type":"number","order":5}]'::jsonb,
  '{"template":"cycle-count"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'loading-checklist',
  '00000000-0000-0000-0000-000000000001',
  'Loading Dock Checklist',
  'Truck loading verification and seal documentation',
  'Operations',
  ARRAY['operations', 'shipping', 'loading'],
  true,
  '1.0.0',
  'system',
  '2025-11-25T16:07:24.110634',
  '[{"id":"truckNumber","label":"Truck number","type":"text","order":1},{"id":"driver","label":"Driver name","type":"text","order":2},{"id":"palletCount","label":"Pallet count","type":"number","order":3},{"id":"sealNumber","label":"Seal number","type":"text","order":4},{"id":"photos","label":"Photos","type":"photo","order":5}]'::jsonb,
  '{"template":"loading"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'preventive-maintenance',
  '00000000-0000-0000-0000-000000000001',
  'Preventive Maintenance Record',
  'Scheduled maintenance tasks and completion',
  'Operations',
  ARRAY['operations', 'maintenance', 'preventive'],
  true,
  '1.0.0',
  'system',
  '2025-11-24T16:07:24.110718',
  '[{"id":"equipment","label":"Equipment","type":"text","order":1},{"id":"tasks","label":"Tasks completed","type":"checkbox","options":["Lubrication","Filter change","Belt tension","Calibration"],"order":2},{"id":"nextDue","label":"Next service due","type":"date","order":3},{"id":"technician","label":"Technician","type":"text","order":4}]'::jsonb,
  '{"template":"pm"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'energy-meter-reading',
  '00000000-0000-0000-0000-000000000001',
  'Energy Meter Reading',
  'Utility consumption tracking',
  'Operations',
  ARRAY['operations', 'energy', 'utilities'],
  true,
  '1.0.0',
  'system',
  '2025-11-23T16:07:24.110740',
  '[{"id":"meterType","label":"Meter type","type":"dropdown","options":["Electric","Gas","Water"],"order":1},{"id":"meterId","label":"Meter ID","type":"text","order":2},{"id":"reading","label":"Reading","type":"number","order":3},{"id":"photos","label":"Photos","type":"photo","order":4}]'::jsonb,
  '{"template":"meter-reading"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'equipment-calibration',
  '00000000-0000-0000-0000-000000000001',
  'Equipment Calibration Log',
  'Calibration verification and certificate tracking',
  'Operations',
  ARRAY['operations', 'calibration', 'quality'],
  true,
  '1.0.0',
  'system',
  '2025-11-22T16:07:24.110763',
  '[{"id":"equipment","label":"Equipment","type":"text","order":1},{"id":"standard","label":"Standard used","type":"text","order":2},{"id":"passed","label":"Passed calibration","type":"toggle","order":3},{"id":"nextDue","label":"Next calibration","type":"date","order":4},{"id":"certificate","label":"Certificate","type":"document","order":5}]'::jsonb,
  '{"template":"calibration"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'concrete-pour',
  '00000000-0000-0000-0000-000000000001',
  'Concrete Pour Report',
  'Mix design, weather, and curing documentation',
  'Construction',
  ARRAY['construction', 'concrete', 'pour'],
  true,
  '1.0.0',
  'system',
  '2025-11-21T16:07:24.110781',
  '[{"id":"location","label":"Pour location","type":"text","order":1},{"id":"yardage","label":"Yardage","type":"number","order":2},{"id":"mixDesign","label":"Mix design","type":"text","order":3},{"id":"slump","label":"Slump (inches)","type":"number","order":4},{"id":"temperature","label":"Temperature (°F)","type":"number","order":5},{"id":"photos","label":"Photos","type":"photo","order":6}]'::jsonb,
  '{"template":"concrete-pour"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'excavation-permit',
  '00000000-0000-0000-0000-000000000001',
  'Excavation Permit',
  'Underground utility clearance and cave-in prevention',
  'Construction',
  ARRAY['construction', 'excavation', 'permit'],
  true,
  '1.0.0',
  'system',
  '2025-11-20T16:07:24.110807',
  '[{"id":"location","label":"Location","type":"text","order":1},{"id":"depth","label":"Depth (feet)","type":"number","order":2},{"id":"utilitiesMarked","label":"Utilities marked","type":"toggle","order":3},{"id":"shoring","label":"Shoring required","type":"toggle","order":4},{"id":"competentPerson","label":"Competent person","type":"text","order":5}]'::jsonb,
  '{"template":"excavation"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'scaffold-inspection',
  '00000000-0000-0000-0000-000000000001',
  'Scaffold Inspection',
  'Pre-use scaffold safety check',
  'Construction',
  ARRAY['construction', 'scaffold', 'safety'],
  true,
  '1.0.0',
  'system',
  '2025-11-19T16:07:24.110826',
  '[{"id":"location","label":"Location","type":"text","order":1},{"id":"height","label":"Height (feet)","type":"number","order":2},{"id":"guardrails","label":"Guardrails intact","type":"toggle","order":3},{"id":"planking","label":"Planking secure","type":"toggle","order":4},{"id":"passed","label":"Passed inspection","type":"toggle","order":5}]'::jsonb,
  '{"template":"scaffold"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'material-delivery',
  '00000000-0000-0000-0000-000000000001',
  'Material Delivery Log',
  'Construction material receiving and verification',
  'Construction',
  ARRAY['construction', 'materials', 'delivery'],
  true,
  '1.0.0',
  'system',
  '2025-11-18T16:07:24.110852',
  '[{"id":"material","label":"Material","type":"text","order":1},{"id":"quantity","label":"Quantity","type":"number","order":2},{"id":"supplier","label":"Supplier","type":"text","order":3},{"id":"condition","label":"Condition","type":"dropdown","options":["Good","Damaged","Incorrect"],"order":4},{"id":"photos","label":"Photos","type":"photo","order":5}]'::jsonb,
  '{"template":"material-delivery"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'crane-inspection',
  '00000000-0000-0000-0000-000000000001',
  'Mobile Crane Inspection',
  'Daily crane safety and operations check',
  'Construction',
  ARRAY['construction', 'crane', 'equipment'],
  true,
  '1.0.0',
  'system',
  '2025-11-17T16:07:24.110871',
  '[{"id":"craneId","label":"Crane ID","type":"text","order":1},{"id":"operator","label":"Operator","type":"text","order":2},{"id":"cables","label":"Cables OK","type":"toggle","order":3},{"id":"hooks","label":"Hooks OK","type":"toggle","order":4},{"id":"loadChart","label":"Load chart present","type":"toggle","order":5}]'::jsonb,
  '{"template":"crane"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'site-condition-report',
  '00000000-0000-0000-0000-000000000001',
  'Daily Site Condition Report',
  'Weather, progress, and manpower documentation',
  'Construction',
  ARRAY['construction', 'daily', 'report'],
  true,
  '1.0.0',
  'system',
  '2025-11-16T16:07:24.110894',
  '[{"id":"weather","label":"Weather","type":"text","order":1},{"id":"temperature","label":"Temperature","type":"number","order":2},{"id":"workers","label":"Workers on site","type":"number","order":3},{"id":"progress","label":"Progress notes","type":"textarea","order":4},{"id":"photos","label":"Photos","type":"photo","order":5}]'::jsonb,
  '{"template":"site-condition"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'punch-list',
  '00000000-0000-0000-0000-000000000001',
  'Construction Punch List',
  'Final inspection deficiency tracking',
  'Construction',
  ARRAY['construction', 'punch-list', 'closeout'],
  true,
  '1.0.0',
  'system',
  '2025-11-15T16:07:24.110912',
  '[{"id":"area","label":"Area","type":"text","order":1},{"id":"deficiency","label":"Deficiency","type":"textarea","order":2},{"id":"responsible","label":"Responsible party","type":"text","order":3},{"id":"status","label":"Status","type":"dropdown","options":["Open","In Progress","Closed"],"order":4},{"id":"photos","label":"Photos","type":"photo","order":5}]'::jsonb,
  '{"template":"punch-list"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'grading-inspection',
  '00000000-0000-0000-0000-000000000001',
  'Grading & Drainage Inspection',
  'Site grading verification and drainage flow',
  'Construction',
  ARRAY['construction', 'grading', 'civil'],
  true,
  '1.0.0',
  'system',
  '2025-11-14T16:07:24.110965',
  '[{"id":"location","label":"Location","type":"text","order":1},{"id":"slope","label":"Slope (%)","type":"number","order":2},{"id":"drainage","label":"Drainage adequate","type":"toggle","order":3},{"id":"notes","label":"Notes","type":"textarea","order":4},{"id":"photos","label":"Photos","type":"photo","order":5}]'::jsonb,
  '{"template":"grading"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'framing-inspection',
  '00000000-0000-0000-0000-000000000001',
  'Framing Inspection Report',
  'Structural framing verification',
  'Construction',
  ARRAY['construction', 'framing', 'structural'],
  true,
  '1.0.0',
  'system',
  '2025-11-13T16:07:24.110998',
  '[{"id":"unit","label":"Unit/Area","type":"text","order":1},{"id":"spacing","label":"Stud spacing correct","type":"toggle","order":2},{"id":"headers","label":"Headers installed","type":"toggle","order":3},{"id":"blocking","label":"Blocking complete","type":"toggle","order":4},{"id":"photos","label":"Photos","type":"photo","order":5}]'::jsonb,
  '{"template":"framing"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'electrical-rough-in',
  '00000000-0000-0000-0000-000000000001',
  'Electrical Rough-In Inspection',
  'Conduit, boxes, and wire installation check',
  'Construction',
  ARRAY['construction', 'electrical', 'inspection'],
  true,
  '1.0.0',
  'system',
  '2025-11-12T16:07:24.111027',
  '[{"id":"area","label":"Area","type":"text","order":1},{"id":"boxes","label":"Boxes secured","type":"toggle","order":2},{"id":"grounding","label":"Grounding complete","type":"toggle","order":3},{"id":"wire","label":"Wire sized correctly","type":"toggle","order":4},{"id":"photos","label":"Photos","type":"photo","order":5}]'::jsonb,
  '{"template":"electrical-rough"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'plumbing-rough-in',
  '00000000-0000-0000-0000-000000000001',
  'Plumbing Rough-In Inspection',
  'Pipe installation and pressure test',
  'Construction',
  ARRAY['construction', 'plumbing', 'inspection'],
  true,
  '1.0.0',
  'system',
  '2025-11-11T16:07:24.111063',
  '[{"id":"area","label":"Area","type":"text","order":1},{"id":"pressureTest","label":"Pressure test (PSI)","type":"number","order":2},{"id":"passed","label":"Passed test","type":"toggle","order":3},{"id":"leaks","label":"Leaks found","type":"textarea","order":4},{"id":"photos","label":"Photos","type":"photo","order":5}]'::jsonb,
  '{"template":"plumbing-rough"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'roofing-inspection',
  '00000000-0000-0000-0000-000000000001',
  'Roofing Installation Inspection',
  'Roof material and flashing verification',
  'Construction',
  ARRAY['construction', 'roofing', 'inspection'],
  true,
  '1.0.0',
  'system',
  '2025-11-10T16:07:24.111091',
  '[{"id":"roofType","label":"Roof type","type":"dropdown","options":["Shingle","TPO","Metal","Tile"],"order":1},{"id":"underlayment","label":"Underlayment OK","type":"toggle","order":2},{"id":"flashing","label":"Flashing installed","type":"toggle","order":3},{"id":"ventilation","label":"Ventilation adequate","type":"toggle","order":4},{"id":"photos","label":"Photos","type":"photo","order":5}]'::jsonb,
  '{"template":"roofing"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'drywall-inspection',
  '00000000-0000-0000-0000-000000000001',
  'Drywall Installation Inspection',
  'Drywall hanging, taping, and finishing check',
  'Construction',
  ARRAY['construction', 'drywall', 'finish'],
  true,
  '1.0.0',
  'system',
  '2025-11-09T16:07:24.111121',
  '[{"id":"area","label":"Area","type":"text","order":1},{"id":"taping","label":"Taping complete","type":"toggle","order":2},{"id":"texture","label":"Texture applied","type":"toggle","order":3},{"id":"defects","label":"Defects noted","type":"textarea","order":4},{"id":"photos","label":"Photos","type":"photo","order":5}]'::jsonb,
  '{"template":"drywall"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'first-article-inspection',
  '00000000-0000-0000-0000-000000000001',
  'First Article Inspection (FAI)',
  'Initial production run dimensional verification',
  'Quality',
  ARRAY['quality', 'fai', 'inspection'],
  true,
  '1.0.0',
  'system',
  '2025-11-08T16:07:24.111139',
  '[{"id":"partNumber","label":"Part number","type":"text","order":1},{"id":"revision","label":"Revision","type":"text","order":2},{"id":"dimensions","label":"All dimensions OK","type":"toggle","order":3},{"id":"material","label":"Material verified","type":"toggle","order":4},{"id":"photos","label":"Photos","type":"photo","order":5}]'::jsonb,
  '{"template":"fai"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'gage-rr-study',
  '00000000-0000-0000-0000-000000000001',
  'Gage R&R Study',
  'Measurement system analysis',
  'Quality',
  ARRAY['quality', 'gage', 'measurement'],
  true,
  '1.0.0',
  'system',
  '2025-11-07T16:07:24.111156',
  '[{"id":"gage","label":"Gage ID","type":"text","order":1},{"id":"operators","label":"Operators","type":"text","order":2},{"id":"trials","label":"Number of trials","type":"number","order":3},{"id":"passed","label":"Passed study","type":"toggle","order":4}]'::jsonb,
  '{"template":"gage-rr"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'process-capability',
  '00000000-0000-0000-0000-000000000001',
  'Process Capability Study (Cpk)',
  'Statistical process control analysis',
  'Quality',
  ARRAY['quality', 'cpk', 'spc'],
  true,
  '1.0.0',
  'system',
  '2025-11-06T16:07:24.111173',
  '[{"id":"process","label":"Process","type":"text","order":1},{"id":"characteristic","label":"Characteristic","type":"text","order":2},{"id":"sampleSize","label":"Sample size","type":"number","order":3},{"id":"cpkValue","label":"Cpk value","type":"number","order":4},{"id":"capable","label":"Process capable","type":"toggle","order":5}]'::jsonb,
  '{"template":"cpk"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'customer-complaint',
  '00000000-0000-0000-0000-000000000001',
  'Customer Complaint Investigation',
  '8D problem solving methodology',
  'Quality',
  ARRAY['quality', '8d', 'complaint'],
  true,
  '1.0.0',
  'system',
  '2025-11-05T16:07:24.111189',
  '[{"id":"complaintNumber","label":"Complaint #","type":"text","order":1},{"id":"customer","label":"Customer","type":"text","order":2},{"id":"description","label":"Description","type":"textarea","order":3},{"id":"rootCause","label":"Root cause","type":"textarea","order":4},{"id":"corrective","label":"Corrective action","type":"textarea","order":5}]'::jsonb,
  '{"template":"complaint"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'supplier-audit',
  '00000000-0000-0000-0000-000000000001',
  'Supplier Quality Audit',
  'Vendor capability and quality assessment',
  'Quality',
  ARRAY['quality', 'supplier', 'audit'],
  true,
  '1.0.0',
  'system',
  '2025-11-04T16:07:24.111215',
  '[{"id":"supplier","label":"Supplier name","type":"text","order":1},{"id":"auditor","label":"Auditor","type":"text","order":2},{"id":"score","label":"Score","type":"number","order":3},{"id":"findings","label":"Findings","type":"textarea","order":4},{"id":"approved","label":"Approved supplier","type":"toggle","order":5}]'::jsonb,
  '{"template":"supplier-audit"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'layered-process-audit',
  '00000000-0000-0000-0000-000000000001',
  'Layered Process Audit (LPA)',
  'Daily process verification by leadership',
  'Quality',
  ARRAY['quality', 'lpa', 'audit'],
  true,
  '1.0.0',
  'system',
  '2025-11-03T16:07:24.111231',
  '[{"id":"area","label":"Area","type":"text","order":1},{"id":"auditor","label":"Auditor","type":"text","order":2},{"id":"questions","label":"Questions passed","type":"number","order":3},{"id":"totalQuestions","label":"Total questions","type":"number","order":4},{"id":"issues","label":"Issues","type":"textarea","order":5}]'::jsonb,
  '{"template":"lpa"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'product-recall',
  '00000000-0000-0000-0000-000000000001',
  'Product Recall Notification',
  'Recall scope, lot tracking, and customer notification',
  'Quality',
  ARRAY['quality', 'recall', 'traceability'],
  true,
  '1.0.0',
  'system',
  '2025-11-02T16:07:24.111246',
  '[{"id":"product","label":"Product","type":"text","order":1},{"id":"lotNumbers","label":"Lot numbers","type":"textarea","order":2},{"id":"reason","label":"Recall reason","type":"textarea","order":3},{"id":"customersNotified","label":"Customers notified","type":"toggle","order":4}]'::jsonb,
  '{"template":"recall"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'capa-form',
  '00000000-0000-0000-0000-000000000001',
  'Corrective & Preventive Action (CAPA)',
  'Issue tracking and resolution verification',
  'Quality',
  ARRAY['quality', 'capa', 'corrective'],
  true,
  '1.0.0',
  'system',
  '2025-11-01T17:07:24.111260',
  '[{"id":"capaNumber","label":"CAPA #","type":"text","order":1},{"id":"issue","label":"Issue description","type":"textarea","order":2},{"id":"corrective","label":"Corrective action","type":"textarea","order":3},{"id":"preventive","label":"Preventive action","type":"textarea","order":4},{"id":"verified","label":"Effectiveness verified","type":"toggle","order":5}]'::jsonb,
  '{"template":"capa"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'incoming-inspection',
  '00000000-0000-0000-0000-000000000001',
  'Incoming Material Inspection',
  'Raw material and components acceptance',
  'Quality',
  ARRAY['quality', 'incoming', 'inspection'],
  true,
  '1.0.0',
  'system',
  '2025-10-31T17:07:24.111276',
  '[{"id":"material","label":"Material","type":"text","order":1},{"id":"poNumber","label":"PO number","type":"text","order":2},{"id":"quantity","label":"Quantity","type":"number","order":3},{"id":"passed","label":"Passed inspection","type":"toggle","order":4},{"id":"photos","label":"Photos","type":"photo","order":5}]'::jsonb,
  '{"template":"incoming-inspection"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'lot-traceability',
  '00000000-0000-0000-0000-000000000001',
  'Lot Traceability Record',
  'Material genealogy and lot tracking',
  'Quality',
  ARRAY['quality', 'traceability', 'lot'],
  true,
  '1.0.0',
  'system',
  '2025-10-30T17:07:24.111309',
  '[{"id":"finishedLot","label":"Finished lot #","type":"text","order":1},{"id":"rawMaterialLots","label":"Raw material lots","type":"textarea","order":2},{"id":"productionDate","label":"Production date","type":"date","order":3},{"id":"operator","label":"Operator","type":"text","order":4}]'::jsonb,
  '{"template":"traceability"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'final-inspection',
  '00000000-0000-0000-0000-000000000001',
  'Final Product Inspection',
  'Pre-shipment quality verification',
  'Quality',
  ARRAY['quality', 'final', 'inspection'],
  true,
  '1.0.0',
  'system',
  '2025-10-29T17:07:24.111337',
  '[{"id":"product","label":"Product","type":"text","order":1},{"id":"lot","label":"Lot #","type":"text","order":2},{"id":"visualOk","label":"Visual OK","type":"toggle","order":3},{"id":"dimensionalOk","label":"Dimensional OK","type":"toggle","order":4},{"id":"passed","label":"Released for shipment","type":"toggle","order":5}]'::jsonb,
  '{"template":"final-inspection"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'store-opening-checklist',
  '00000000-0000-0000-0000-000000000001',
  'Store Opening Checklist',
  'Daily opening procedures and cash register setup',
  'Retail',
  ARRAY['retail', 'opening', 'daily'],
  true,
  '1.0.0',
  'system',
  '2025-10-28T17:07:24.111353',
  '[{"id":"opener","label":"Opener name","type":"text","order":1},{"id":"lights","label":"Lights on","type":"toggle","order":2},{"id":"registers","label":"Registers counted","type":"toggle","order":3},{"id":"music","label":"Music playing","type":"toggle","order":4},{"id":"notes","label":"Notes","type":"textarea","order":5}]'::jsonb,
  '{"template":"store-opening"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'store-closing',
  '00000000-0000-0000-0000-000000000001',
  'Store Closing Checklist',
  'End of day procedures and deposit preparation',
  'Retail',
  ARRAY['retail', 'closing', 'daily'],
  true,
  '1.0.0',
  'system',
  '2025-10-27T17:07:24.111369',
  '[{"id":"closer","label":"Closer name","type":"text","order":1},{"id":"salesTotal","label":"Sales total","type":"number","order":2},{"id":"deposit","label":"Deposit amount","type":"number","order":3},{"id":"alarmed","label":"Alarm set","type":"toggle","order":4}]'::jsonb,
  '{"template":"store-closing"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'cash-register-audit',
  '00000000-0000-0000-0000-000000000001',
  'Cash Register Audit',
  'Cash drawer count and reconciliation',
  'Retail',
  ARRAY['retail', 'cash', 'audit'],
  true,
  '1.0.0',
  'system',
  '2025-10-26T17:07:24.111384',
  '[{"id":"register","label":"Register #","type":"text","order":1},{"id":"expected","label":"Expected amount","type":"number","order":2},{"id":"actual","label":"Actual count","type":"number","order":3},{"id":"variance","label":"Variance","type":"number","order":4}]'::jsonb,
  '{"template":"cash-audit"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'planogram-compliance',
  '00000000-0000-0000-0000-000000000001',
  'Planogram Compliance Check',
  'Shelf layout and product placement verification',
  'Retail',
  ARRAY['retail', 'planogram', 'merchandising'],
  true,
  '1.0.0',
  'system',
  '2025-10-25T17:07:24.111400',
  '[{"id":"aisle","label":"Aisle","type":"text","order":1},{"id":"compliant","label":"Planogram compliant","type":"toggle","order":2},{"id":"outOfStocks","label":"Out of stocks","type":"textarea","order":3},{"id":"photos","label":"Photos","type":"photo","order":4}]'::jsonb,
  '{"template":"planogram"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'price-verification',
  '00000000-0000-0000-0000-000000000001',
  'Price Verification Audit',
  'Shelf tag and scanner price accuracy',
  'Retail',
  ARRAY['retail', 'pricing', 'audit'],
  true,
  '1.0.0',
  'system',
  '2025-10-24T17:07:24.111506',
  '[{"id":"sku","label":"SKU","type":"text","order":1},{"id":"shelfPrice","label":"Shelf price","type":"number","order":2},{"id":"scannerPrice","label":"Scanner price","type":"number","order":3},{"id":"match","label":"Prices match","type":"toggle","order":4}]'::jsonb,
  '{"template":"price-verification"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'visual-merchandising',
  '00000000-0000-0000-0000-000000000001',
  'Visual Merchandising Standards',
  'Display quality and brand presentation',
  'Retail',
  ARRAY['retail', 'merchandising', 'display'],
  true,
  '1.0.0',
  'system',
  '2025-10-23T17:07:24.111528',
  '[{"id":"display","label":"Display location","type":"text","order":1},{"id":"clean","label":"Clean and organized","type":"toggle","order":2},{"id":"signage","label":"Signage correct","type":"toggle","order":3},{"id":"photos","label":"Photos","type":"photo","order":4}]'::jsonb,
  '{"template":"visual-merchandising"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'shrink-investigation',
  '00000000-0000-0000-0000-000000000001',
  'Shrink Investigation Report',
  'Inventory loss documentation and analysis',
  'Retail',
  ARRAY['retail', 'shrink', 'loss-prevention'],
  true,
  '1.0.0',
  'system',
  '2025-10-22T17:07:24.111571',
  '[{"id":"sku","label":"SKU","type":"text","order":1},{"id":"quantityLost","label":"Quantity lost","type":"number","order":2},{"id":"value","label":"Value","type":"number","order":3},{"id":"cause","label":"Probable cause","type":"dropdown","options":["Theft","Damage","Administrative"],"order":4}]'::jsonb,
  '{"template":"shrink"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'customer-service-log',
  '00000000-0000-0000-0000-000000000001',
  'Customer Service Log',
  'Customer interactions and resolution tracking',
  'Retail',
  ARRAY['retail', 'customer-service', 'support'],
  true,
  '1.0.0',
  'system',
  '2025-10-21T17:07:24.111587',
  '[{"id":"customer","label":"Customer name","type":"text","order":1},{"id":"issue","label":"Issue","type":"textarea","order":2},{"id":"resolution","label":"Resolution","type":"textarea","order":3},{"id":"satisfied","label":"Customer satisfied","type":"toggle","order":4}]'::jsonb,
  '{"template":"customer-service"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'stockroom-organization',
  '00000000-0000-0000-0000-000000000001',
  'Stockroom Organization Check',
  'Backroom cleanliness and organization',
  'Retail',
  ARRAY['retail', 'stockroom', 'organization'],
  true,
  '1.0.0',
  'system',
  '2025-10-20T17:07:24.111604',
  '[{"id":"aislesClear","label":"Aisles clear","type":"toggle","order":1},{"id":"labeled","label":"Products labeled","type":"toggle","order":2},{"id":"organized","label":"Organized by category","type":"toggle","order":3},{"id":"photos","label":"Photos","type":"photo","order":4}]'::jsonb,
  '{"template":"stockroom"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'return-exchange',
  '00000000-0000-0000-0000-000000000001',
  'Return & Exchange Log',
  'Product return processing and restocking',
  'Retail',
  ARRAY['retail', 'returns', 'exchange'],
  true,
  '1.0.0',
  'system',
  '2025-10-19T17:07:24.111624',
  '[{"id":"receiptNumber","label":"Receipt #","type":"text","order":1},{"id":"item","label":"Item","type":"text","order":2},{"id":"reason","label":"Return reason","type":"dropdown","options":["Defective","Wrong item","Changed mind"],"order":3},{"id":"refundAmount","label":"Refund amount","type":"number","order":4}]'::jsonb,
  '{"template":"return"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'vehicle-pre-trip',
  '00000000-0000-0000-0000-000000000001',
  'Vehicle Pre-Trip Inspection',
  'DOT-compliant pre-trip inspection checklist',
  'Fleet',
  ARRAY['fleet', 'vehicle', 'inspection'],
  true,
  '1.0.0',
  'system',
  '2025-10-18T17:07:24.111698',
  '[{"id":"vehicleNumber","label":"Vehicle #","type":"text","order":1},{"id":"tires","label":"Tires OK","type":"toggle","order":2},{"id":"brakes","label":"Brakes OK","type":"toggle","order":3},{"id":"lights","label":"Lights functional","type":"toggle","order":4},{"id":"fluids","label":"Fluids OK","type":"toggle","order":5},{"id":"defects","label":"Defects","type":"textarea","order":6}]'::jsonb,
  '{"template":"pre-trip"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'fuel-log',
  '00000000-0000-0000-0000-000000000001',
  'Fleet Fuel Log',
  'Fuel purchases and mileage tracking',
  'Fleet',
  ARRAY['fleet', 'fuel', 'tracking'],
  true,
  '1.0.0',
  'system',
  '2025-10-17T17:07:24.111744',
  '[{"id":"vehicleNumber","label":"Vehicle #","type":"text","order":1},{"id":"odometer","label":"Odometer","type":"number","order":2},{"id":"gallons","label":"Gallons","type":"number","order":3},{"id":"cost","label":"Cost","type":"number","order":4}]'::jsonb,
  '{"template":"fuel-log"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'fleet-maintenance',
  '00000000-0000-0000-0000-000000000001',
  'Fleet Maintenance Record',
  'Service performed and parts replaced',
  'Fleet',
  ARRAY['fleet', 'maintenance', 'service'],
  true,
  '1.0.0',
  'system',
  '2025-10-16T17:07:24.111773',
  '[{"id":"vehicleNumber","label":"Vehicle #","type":"text","order":1},{"id":"serviceType","label":"Service type","type":"dropdown","options":["Oil change","Brake service","Tire rotation","Other"],"order":2},{"id":"partsUsed","label":"Parts used","type":"textarea","order":3},{"id":"cost","label":"Cost","type":"number","order":4},{"id":"nextService","label":"Next service due","type":"date","order":5}]'::jsonb,
  '{"template":"fleet-maintenance"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'vehicle-accident',
  '00000000-0000-0000-0000-000000000001',
  'Vehicle Accident Report',
  'Collision documentation and insurance claim',
  'Fleet',
  ARRAY['fleet', 'accident', 'incident'],
  true,
  '1.0.0',
  'system',
  '2025-10-15T17:07:24.111789',
  '[{"id":"vehicleNumber","label":"Vehicle #","type":"text","order":1},{"id":"driver","label":"Driver","type":"text","order":2},{"id":"location","label":"Location","type":"text","order":3},{"id":"description","label":"Description","type":"textarea","order":4},{"id":"injuries","label":"Injuries","type":"toggle","order":5},{"id":"photos","label":"Photos","type":"photo","order":6}]'::jsonb,
  '{"template":"accident"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'delivery-log',
  '00000000-0000-0000-0000-000000000001',
  'Delivery Log',
  'Delivery stops and customer signatures',
  'Fleet',
  ARRAY['fleet', 'delivery', 'logistics'],
  true,
  '1.0.0',
  'system',
  '2025-10-14T17:07:24.111803',
  '[{"id":"driver","label":"Driver","type":"text","order":1},{"id":"stops","label":"Number of stops","type":"number","order":2},{"id":"packagesDelivered","label":"Packages delivered","type":"number","order":3},{"id":"mileage","label":"Total mileage","type":"number","order":4}]'::jsonb,
  '{"template":"delivery"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'dot-hours-of-service',
  '00000000-0000-0000-0000-000000000001',
  'DOT Hours of Service Log',
  'Driver duty status and hours tracking',
  'Fleet',
  ARRAY['fleet', 'dot', 'compliance'],
  true,
  '1.0.0',
  'system',
  '2025-10-13T17:07:24.111821',
  '[{"id":"driver","label":"Driver","type":"text","order":1},{"id":"drivingHours","label":"Driving hours","type":"number","order":2},{"id":"onDutyHours","label":"On-duty hours","type":"number","order":3},{"id":"offDutyHours","label":"Off-duty hours","type":"number","order":4}]'::jsonb,
  '{"template":"hos"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'trailer-inspection',
  '00000000-0000-0000-0000-000000000001',
  'Trailer Inspection',
  'Trailer condition and load security check',
  'Fleet',
  ARRAY['fleet', 'trailer', 'inspection'],
  true,
  '1.0.0',
  'system',
  '2025-10-12T17:07:24.111831',
  '[{"id":"trailerNumber","label":"Trailer #","type":"text","order":1},{"id":"doors","label":"Doors functional","type":"toggle","order":2},{"id":"floor","label":"Floor intact","type":"toggle","order":3},{"id":"loadSecure","label":"Load secured","type":"toggle","order":4}]'::jsonb,
  '{"template":"trailer"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'vehicle-cleaning',
  '00000000-0000-0000-0000-000000000001',
  'Fleet Vehicle Cleaning',
  'Interior and exterior cleaning checklist',
  'Fleet',
  ARRAY['fleet', 'cleaning', 'maintenance'],
  true,
  '1.0.0',
  'system',
  '2025-10-11T17:07:24.111846',
  '[{"id":"vehicleNumber","label":"Vehicle #","type":"text","order":1},{"id":"interior","label":"Interior cleaned","type":"toggle","order":2},{"id":"exterior","label":"Exterior washed","type":"toggle","order":3},{"id":"windows","label":"Windows cleaned","type":"toggle","order":4}]'::jsonb,
  '{"template":"vehicle-cleaning"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'tire-inspection',
  '00000000-0000-0000-0000-000000000001',
  'Fleet Tire Inspection',
  'Tire tread depth and condition check',
  'Fleet',
  ARRAY['fleet', 'tire', 'inspection'],
  true,
  '1.0.0',
  'system',
  '2025-10-10T17:07:24.111884',
  '[{"id":"vehicleNumber","label":"Vehicle #","type":"text","order":1},{"id":"frontLeft","label":"Front left (32nds)","type":"number","order":2},{"id":"frontRight","label":"Front right (32nds)","type":"number","order":3},{"id":"rearLeft","label":"Rear left (32nds)","type":"number","order":4},{"id":"rearRight","label":"Rear right (32nds)","type":"number","order":5},{"id":"passed","label":"Passed inspection","type":"toggle","order":6}]'::jsonb,
  '{"template":"tire-inspection"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'route-planning',
  '00000000-0000-0000-0000-000000000001',
  'Route Planning Form',
  'Delivery route optimization and timing',
  'Fleet',
  ARRAY['fleet', 'routing', 'logistics'],
  true,
  '1.0.0',
  'system',
  '2025-10-09T17:07:24.111926',
  '[{"id":"driver","label":"Driver","type":"text","order":1},{"id":"stops","label":"Planned stops","type":"number","order":2},{"id":"estimatedMiles","label":"Estimated miles","type":"number","order":3},{"id":"estimatedTime","label":"Estimated time (hrs)","type":"number","order":4}]'::jsonb,
  '{"template":"route-planning"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'patient-intake',
  '00000000-0000-0000-0000-000000000001',
  'Patient Intake Form',
  'New patient registration and medical history',
  'Healthcare',
  ARRAY['healthcare', 'patient', 'intake'],
  true,
  '1.0.0',
  'system',
  '2025-10-08T17:07:24.111948',
  '[{"id":"patientName","label":"Patient name","type":"text","order":1},{"id":"dob","label":"Date of birth","type":"date","order":2},{"id":"allergies","label":"Allergies","type":"textarea","order":3},{"id":"medications","label":"Current medications","type":"textarea","order":4},{"id":"emergencyContact","label":"Emergency contact","type":"text","order":5}]'::jsonb,
  '{"template":"patient-intake"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'nursing-rounds',
  '00000000-0000-0000-0000-000000000001',
  'Nursing Rounds',
  'Patient check and vital signs documentation',
  'Healthcare',
  ARRAY['healthcare', 'nursing', 'rounds'],
  true,
  '1.0.0',
  'system',
  '2025-10-07T17:07:24.111968',
  '[{"id":"patientRoom","label":"Room #","type":"text","order":1},{"id":"bloodPressure","label":"Blood pressure","type":"text","order":2},{"id":"temperature","label":"Temperature","type":"number","order":3},{"id":"pulse","label":"Pulse","type":"number","order":4},{"id":"notes","label":"Notes","type":"textarea","order":5}]'::jsonb,
  '{"template":"nursing-rounds"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'medication-administration',
  '00000000-0000-0000-0000-000000000001',
  'Medication Administration Record',
  'MAR documentation and dosage tracking',
  'Healthcare',
  ARRAY['healthcare', 'medication', 'mar'],
  true,
  '1.0.0',
  'system',
  '2025-10-06T17:07:24.111983',
  '[{"id":"patientName","label":"Patient name","type":"text","order":1},{"id":"medication","label":"Medication","type":"text","order":2},{"id":"dosage","label":"Dosage","type":"text","order":3},{"id":"route","label":"Route","type":"dropdown","options":["Oral","IV","IM","Topical"],"order":4},{"id":"nurse","label":"Administering nurse","type":"text","order":5}]'::jsonb,
  '{"template":"mar"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'fall-risk-assessment',
  '00000000-0000-0000-0000-000000000001',
  'Fall Risk Assessment',
  'Patient fall risk evaluation and prevention',
  'Healthcare',
  ARRAY['healthcare', 'safety', 'assessment'],
  true,
  '1.0.0',
  'system',
  '2025-10-05T17:07:24.111994',
  '[{"id":"patientName","label":"Patient name","type":"text","order":1},{"id":"mobilityAids","label":"Uses mobility aids","type":"toggle","order":2},{"id":"historyOfFalls","label":"History of falls","type":"toggle","order":3},{"id":"medications","label":"On sedatives","type":"toggle","order":4},{"id":"riskLevel","label":"Risk level","type":"dropdown","options":["Low","Medium","High"],"order":5}]'::jsonb,
  '{"template":"fall-risk"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'equipment-sterilization',
  '00000000-0000-0000-0000-000000000001',
  'Equipment Sterilization Log',
  'Autoclave cycle and instrument tracking',
  'Healthcare',
  ARRAY['healthcare', 'sterilization', 'equipment'],
  true,
  '1.0.0',
  'system',
  '2025-10-04T17:07:24.112005',
  '[{"id":"loadNumber","label":"Load #","type":"text","order":1},{"id":"temperature","label":"Temperature (F)","type":"number","order":2},{"id":"pressure","label":"Pressure (psi)","type":"number","order":3},{"id":"cycleTime","label":"Cycle time (min)","type":"number","order":4},{"id":"passed","label":"Passed","type":"toggle","order":5}]'::jsonb,
  '{"template":"sterilization"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'discharge-checklist',
  '00000000-0000-0000-0000-000000000001',
  'Patient Discharge Checklist',
  'Discharge planning and instructions',
  'Healthcare',
  ARRAY['healthcare', 'discharge', 'patient'],
  true,
  '1.0.0',
  'system',
  '2025-10-03T17:07:24.112024',
  '[{"id":"patientName","label":"Patient name","type":"text","order":1},{"id":"medications","label":"Prescriptions given","type":"toggle","order":2},{"id":"followUp","label":"Follow-up scheduled","type":"toggle","order":3},{"id":"instructions","label":"Instructions provided","type":"toggle","order":4},{"id":"transportation","label":"Transportation arranged","type":"toggle","order":5}]'::jsonb,
  '{"template":"discharge"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'wound-care',
  '00000000-0000-0000-0000-000000000001',
  'Wound Care Assessment',
  'Wound documentation and treatment plan',
  'Healthcare',
  ARRAY['healthcare', 'wound', 'treatment'],
  true,
  '1.0.0',
  'system',
  '2025-10-02T17:07:24.112035',
  '[{"id":"patientName","label":"Patient name","type":"text","order":1},{"id":"location","label":"Wound location","type":"text","order":2},{"id":"size","label":"Size (cm)","type":"text","order":3},{"id":"appearance","label":"Appearance","type":"textarea","order":4},{"id":"treatment","label":"Treatment applied","type":"textarea","order":5},{"id":"photo","label":"Photo","type":"photo","order":6}]'::jsonb,
  '{"template":"wound-care"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'iv-site-check',
  '00000000-0000-0000-0000-000000000001',
  'IV Site Check',
  'Intravenous site assessment and monitoring',
  'Healthcare',
  ARRAY['healthcare', 'iv', 'monitoring'],
  true,
  '1.0.0',
  'system',
  '2025-10-01T17:07:24.112049',
  '[{"id":"patientName","label":"Patient name","type":"text","order":1},{"id":"site","label":"IV site","type":"text","order":2},{"id":"patent","label":"Patent","type":"toggle","order":3},{"id":"redness","label":"Redness present","type":"toggle","order":4},{"id":"swelling","label":"Swelling present","type":"toggle","order":5}]'::jsonb,
  '{"template":"iv-check"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'pain-assessment',
  '00000000-0000-0000-0000-000000000001',
  'Pain Assessment',
  'Patient pain level and characteristics',
  'Healthcare',
  ARRAY['healthcare', 'pain', 'assessment'],
  true,
  '1.0.0',
  'system',
  '2025-09-30T17:07:24.112059',
  '[{"id":"patientName","label":"Patient name","type":"text","order":1},{"id":"painLevel","label":"Pain level (0-10)","type":"number","order":2},{"id":"location","label":"Location","type":"text","order":3},{"id":"characteristics","label":"Pain characteristics","type":"dropdown","options":["Sharp","Dull","Burning","Aching"],"order":4},{"id":"intervention","label":"Intervention provided","type":"textarea","order":5}]'::jsonb,
  '{"template":"pain-assessment"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'infection-control',
  '00000000-0000-0000-0000-000000000001',
  'Infection Control Assessment',
  'Infection surveillance and prevention protocols',
  'Healthcare',
  ARRAY['healthcare', 'infection', 'control'],
  true,
  '1.0.0',
  'system',
  '2025-09-29T17:07:24.112072',
  '[{"id":"area","label":"Area","type":"text","order":1},{"id":"handHygiene","label":"Hand hygiene compliant","type":"toggle","order":2},{"id":"ppe","label":"PPE used correctly","type":"toggle","order":3},{"id":"isolation","label":"Isolation precautions","type":"toggle","order":4},{"id":"notes","label":"Notes","type":"textarea","order":5}]'::jsonb,
  '{"template":"infection-control"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'blood-glucose',
  '00000000-0000-0000-0000-000000000001',
  'Blood Glucose Monitoring',
  'Diabetic patient glucose level tracking',
  'Healthcare',
  ARRAY['healthcare', 'diabetes', 'monitoring'],
  true,
  '1.0.0',
  'system',
  '2025-09-28T17:07:24.112087',
  '[{"id":"patientName","label":"Patient name","type":"text","order":1},{"id":"glucoseLevel","label":"Glucose level (mg/dL)","type":"number","order":2},{"id":"mealRelation","label":"Meal relation","type":"dropdown","options":["Fasting","Before meal","After meal","Bedtime"],"order":3},{"id":"insulinGiven","label":"Insulin given","type":"toggle","order":4},{"id":"dose","label":"Insulin dose (units)","type":"number","order":5}]'::jsonb,
  '{"template":"glucose"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'patient-transport',
  '00000000-0000-0000-0000-000000000001',
  'Patient Transport Form',
  'Safe patient transfer documentation',
  'Healthcare',
  ARRAY['healthcare', 'transport', 'safety'],
  true,
  '1.0.0',
  'system',
  '2025-09-27T17:07:24.112101',
  '[{"id":"patientName","label":"Patient name","type":"text","order":1},{"id":"from","label":"From","type":"text","order":2},{"id":"to","label":"To","type":"text","order":3},{"id":"method","label":"Transport method","type":"dropdown","options":["Wheelchair","Stretcher","Ambulatory","Bed"],"order":4},{"id":"oxygen","label":"On oxygen","type":"toggle","order":5}]'::jsonb,
  '{"template":"transport"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'dietary-assessment',
  '00000000-0000-0000-0000-000000000001',
  'Dietary Assessment',
  'Nutritional intake and dietary restrictions',
  'Healthcare',
  ARRAY['healthcare', 'nutrition', 'dietary'],
  true,
  '1.0.0',
  'system',
  '2025-09-26T17:07:24.112116',
  '[{"id":"patientName","label":"Patient name","type":"text","order":1},{"id":"restrictions","label":"Dietary restrictions","type":"textarea","order":2},{"id":"intakePercentage","label":"Meal intake %","type":"number","order":3},{"id":"supplements","label":"Supplements needed","type":"toggle","order":4}]'::jsonb,
  '{"template":"dietary"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'respiratory-therapy',
  '00000000-0000-0000-0000-000000000001',
  'Respiratory Therapy Assessment',
  'Breathing treatment and oxygen therapy log',
  'Healthcare',
  ARRAY['healthcare', 'respiratory', 'therapy'],
  true,
  '1.0.0',
  'system',
  '2025-09-25T17:07:24.112135',
  '[{"id":"patientName","label":"Patient name","type":"text","order":1},{"id":"oxygenSat","label":"O2 saturation %","type":"number","order":2},{"id":"respiratoryRate","label":"Respiratory rate","type":"number","order":3},{"id":"treatment","label":"Treatment type","type":"dropdown","options":["Nebulizer","Inhaler","Oxygen therapy","Chest PT"],"order":4},{"id":"response","label":"Patient response","type":"textarea","order":5}]'::jsonb,
  '{"template":"respiratory"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'performance-review',
  '00000000-0000-0000-0000-000000000001',
  'Employee Performance Review',
  'Annual or quarterly performance evaluation',
  'HR',
  ARRAY['hr', 'performance', 'review'],
  true,
  '1.0.0',
  'system',
  '2025-09-24T17:07:24.112147',
  '[{"id":"employeeName","label":"Employee name","type":"text","order":1},{"id":"reviewPeriod","label":"Review period","type":"text","order":2},{"id":"performance","label":"Overall rating","type":"dropdown","options":["Exceeds","Meets","Needs improvement"],"order":3},{"id":"strengths","label":"Strengths","type":"textarea","order":4},{"id":"development","label":"Development areas","type":"textarea","order":5}]'::jsonb,
  '{"template":"performance-review"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'time-off-request',
  '00000000-0000-0000-0000-000000000001',
  'Time Off Request',
  'PTO, vacation, and leave requests',
  'HR',
  ARRAY['hr', 'pto', 'leave'],
  true,
  '1.0.0',
  'system',
  '2025-09-23T17:07:24.112161',
  '[{"id":"employeeName","label":"Employee name","type":"text","order":1},{"id":"startDate","label":"Start date","type":"date","order":2},{"id":"endDate","label":"End date","type":"date","order":3},{"id":"type","label":"Leave type","type":"dropdown","options":["Vacation","Sick","Personal","FMLA"],"order":4},{"id":"approved","label":"Approved","type":"toggle","order":5}]'::jsonb,
  '{"template":"pto"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'training-record',
  '00000000-0000-0000-0000-000000000001',
  'Employee Training Record',
  'Training completion and certification tracking',
  'HR',
  ARRAY['hr', 'training', 'compliance'],
  true,
  '1.0.0',
  'system',
  '2025-09-22T17:07:24.112172',
  '[{"id":"employeeName","label":"Employee name","type":"text","order":1},{"id":"trainingName","label":"Training name","type":"text","order":2},{"id":"completionDate","label":"Completion date","type":"date","order":3},{"id":"expirationDate","label":"Expiration date","type":"date","order":4},{"id":"score","label":"Test score %","type":"number","order":5}]'::jsonb,
  '{"template":"training"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'exit-interview',
  '00000000-0000-0000-0000-000000000001',
  'Exit Interview',
  'Departing employee feedback and offboarding',
  'HR',
  ARRAY['hr', 'exit', 'offboarding'],
  true,
  '1.0.0',
  'system',
  '2025-09-21T17:07:24.112186',
  '[{"id":"employeeName","label":"Employee name","type":"text","order":1},{"id":"lastDay","label":"Last day","type":"date","order":2},{"id":"reasonForLeaving","label":"Reason for leaving","type":"textarea","order":3},{"id":"feedback","label":"Feedback","type":"textarea","order":4},{"id":"rehire","label":"Eligible for rehire","type":"toggle","order":5}]'::jsonb,
  '{"template":"exit-interview"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'disciplinary-action',
  '00000000-0000-0000-0000-000000000001',
  'Disciplinary Action Form',
  'Employee discipline documentation',
  'HR',
  ARRAY['hr', 'discipline', 'corrective'],
  true,
  '1.0.0',
  'system',
  '2025-09-20T17:07:24.112198',
  '[{"id":"employeeName","label":"Employee name","type":"text","order":1},{"id":"actionType","label":"Action type","type":"dropdown","options":["Verbal warning","Written warning","Suspension","Termination"],"order":2},{"id":"incident","label":"Incident description","type":"textarea","order":3},{"id":"expectations","label":"Expectations","type":"textarea","order":4},{"id":"employeeSignature","label":"Employee signature","type":"signature","order":5}]'::jsonb,
  '{"template":"disciplinary"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'job-requisition',
  '00000000-0000-0000-0000-000000000001',
  'Job Requisition Form',
  'New position approval and hiring request',
  'HR',
  ARRAY['hr', 'recruiting', 'hiring'],
  true,
  '1.0.0',
  'system',
  '2025-09-19T17:07:24.112210',
  '[{"id":"positionTitle","label":"Position title","type":"text","order":1},{"id":"department","label":"Department","type":"text","order":2},{"id":"salary","label":"Salary range","type":"text","order":3},{"id":"justification","label":"Business justification","type":"textarea","order":4},{"id":"approved","label":"Approved","type":"toggle","order":5}]'::jsonb,
  '{"template":"requisition"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'compensation-change',
  '00000000-0000-0000-0000-000000000001',
  'Compensation Change Form',
  'Salary adjustment and promotion documentation',
  'HR',
  ARRAY['hr', 'compensation', 'salary'],
  true,
  '1.0.0',
  'system',
  '2025-09-18T17:07:24.112223',
  '[{"id":"employeeName","label":"Employee name","type":"text","order":1},{"id":"currentSalary","label":"Current salary","type":"number","order":2},{"id":"newSalary","label":"New salary","type":"number","order":3},{"id":"effectiveDate","label":"Effective date","type":"date","order":4},{"id":"reason","label":"Reason","type":"textarea","order":5}]'::jsonb,
  '{"template":"compensation"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'benefits-enrollment',
  '00000000-0000-0000-0000-000000000001',
  'Benefits Enrollment',
  'Employee benefits selection and enrollment',
  'HR',
  ARRAY['hr', 'benefits', 'enrollment'],
  true,
  '1.0.0',
  'system',
  '2025-09-17T17:07:24.112277',
  '[{"id":"employeeName","label":"Employee name","type":"text","order":1},{"id":"healthInsurance","label":"Health insurance","type":"toggle","order":2},{"id":"dental","label":"Dental","type":"toggle","order":3},{"id":"vision","label":"Vision","type":"toggle","order":4},{"id":"401k","label":"401k %","type":"number","order":5}]'::jsonb,
  '{"template":"benefits"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'accommodation-request',
  '00000000-0000-0000-0000-000000000001',
  'Accommodation Request',
  'ADA and disability accommodation requests',
  'HR',
  ARRAY['hr', 'ada', 'accommodation'],
  true,
  '1.0.0',
  'system',
  '2025-09-16T17:07:24.112302',
  '[{"id":"employeeName","label":"Employee name","type":"text","order":1},{"id":"accommodation","label":"Accommodation requested","type":"textarea","order":2},{"id":"medical","label":"Medical documentation","type":"toggle","order":3},{"id":"approved","label":"Approved","type":"toggle","order":4}]'::jsonb,
  '{"template":"accommodation"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'reference-check',
  '00000000-0000-0000-0000-000000000001',
  'Reference Check Form',
  'Employment reference verification',
  'HR',
  ARRAY['hr', 'recruiting', 'reference'],
  true,
  '1.0.0',
  'system',
  '2025-09-15T17:07:24.112381',
  '[{"id":"candidateName","label":"Candidate name","type":"text","order":1},{"id":"referenceName","label":"Reference name","type":"text","order":2},{"id":"relationship","label":"Relationship","type":"text","order":3},{"id":"recommend","label":"Would recommend","type":"toggle","order":4},{"id":"notes","label":"Notes","type":"textarea","order":5}]'::jsonb,
  '{"template":"reference-check"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'workplace-complaint',
  '00000000-0000-0000-0000-000000000001',
  'Workplace Complaint Form',
  'Employee grievance and complaint documentation',
  'HR',
  ARRAY['hr', 'complaint', 'investigation'],
  true,
  '1.0.0',
  'system',
  '2025-09-14T17:07:24.112396',
  '[{"id":"complainant","label":"Complainant","type":"text","order":1},{"id":"subject","label":"Subject of complaint","type":"text","order":2},{"id":"incident","label":"Incident description","type":"textarea","order":3},{"id":"witnesses","label":"Witnesses","type":"textarea","order":4},{"id":"anonymous","label":"Anonymous","type":"toggle","order":5}]'::jsonb,
  '{"template":"complaint"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'i9-verification',
  '00000000-0000-0000-0000-000000000001',
  'I-9 Employment Verification',
  'Federal employment eligibility verification',
  'HR',
  ARRAY['hr', 'compliance', 'i9'],
  true,
  '1.0.0',
  'system',
  '2025-09-13T17:07:24.112411',
  '[{"id":"employeeName","label":"Employee name","type":"text","order":1},{"id":"citizenship","label":"Citizenship status","type":"dropdown","options":["US Citizen","Permanent Resident","Authorized Alien"],"order":2},{"id":"documentType","label":"Document type","type":"text","order":3},{"id":"documentNumber","label":"Document #","type":"text","order":4},{"id":"verified","label":"Verified","type":"toggle","order":5}]'::jsonb,
  '{"template":"i9"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'remote-work-agreement',
  '00000000-0000-0000-0000-000000000001',
  'Remote Work Agreement',
  'Telecommuting policy and expectations',
  'HR',
  ARRAY['hr', 'remote', 'telecommute'],
  true,
  '1.0.0',
  'system',
  '2025-09-12T17:07:24.112428',
  '[{"id":"employeeName","label":"Employee name","type":"text","order":1},{"id":"schedule","label":"Remote schedule","type":"text","order":2},{"id":"equipment","label":"Company equipment","type":"textarea","order":3},{"id":"acknowledgement","label":"Policy acknowledged","type":"toggle","order":4},{"id":"signature","label":"Signature","type":"signature","order":5}]'::jsonb,
  '{"template":"remote-work"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'property-inspection',
  '00000000-0000-0000-0000-000000000001',
  'Property Insurance Inspection',
  'Property condition assessment for underwriting',
  'Insurance',
  ARRAY['insurance', 'property', 'inspection'],
  true,
  '1.0.0',
  'system',
  '2025-09-11T17:07:24.112439',
  '[{"id":"propertyAddress","label":"Property address","type":"text","order":1},{"id":"roofCondition","label":"Roof condition","type":"dropdown","options":["Excellent","Good","Fair","Poor"],"order":2},{"id":"foundation","label":"Foundation condition","type":"dropdown","options":["Excellent","Good","Fair","Poor"],"order":3},{"id":"hazards","label":"Hazards identified","type":"textarea","order":4},{"id":"photos","label":"Photos","type":"photo","order":5}]'::jsonb,
  '{"template":"property-inspection"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'auto-claim',
  '00000000-0000-0000-0000-000000000001',
  'Auto Insurance Claim',
  'Vehicle accident claim documentation',
  'Insurance',
  ARRAY['insurance', 'auto', 'claim'],
  true,
  '1.0.0',
  'system',
  '2025-09-10T17:07:24.112450',
  '[{"id":"claimNumber","label":"Claim #","type":"text","order":1},{"id":"insuredVehicle","label":"Insured vehicle","type":"text","order":2},{"id":"damageDescription","label":"Damage description","type":"textarea","order":3},{"id":"estimatedCost","label":"Estimated repair cost","type":"number","order":4},{"id":"policeReport","label":"Police report filed","type":"toggle","order":5},{"id":"photos","label":"Damage photos","type":"photo","order":6}]'::jsonb,
  '{"template":"auto-claim"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'liability-report',
  '00000000-0000-0000-0000-000000000001',
  'Liability Incident Report',
  'General liability claim investigation',
  'Insurance',
  ARRAY['insurance', 'liability', 'claim'],
  true,
  '1.0.0',
  'system',
  '2025-09-09T17:07:24.112461',
  '[{"id":"claimant","label":"Claimant name","type":"text","order":1},{"id":"incidentDate","label":"Incident date","type":"date","order":2},{"id":"description","label":"Incident description","type":"textarea","order":3},{"id":"injuries","label":"Injuries reported","type":"textarea","order":4},{"id":"witnesses","label":"Witnesses","type":"textarea","order":5}]'::jsonb,
  '{"template":"liability"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'workers-comp-investigation',
  '00000000-0000-0000-0000-000000000001',
  'Workers Comp Investigation',
  'Workplace injury claim investigation',
  'Insurance',
  ARRAY['insurance', 'workers-comp', 'investigation'],
  true,
  '1.0.0',
  'system',
  '2025-09-08T17:07:24.112475',
  '[{"id":"employee","label":"Employee name","type":"text","order":1},{"id":"injury","label":"Injury description","type":"textarea","order":2},{"id":"workRelated","label":"Work-related","type":"toggle","order":3},{"id":"medicalTreatment","label":"Medical treatment","type":"textarea","order":4},{"id":"lostTime","label":"Days of lost time","type":"number","order":5}]'::jsonb,
  '{"template":"wc-investigation"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'risk-assessment',
  '00000000-0000-0000-0000-000000000001',
  'Insurance Risk Assessment',
  'Underwriting risk evaluation',
  'Insurance',
  ARRAY['insurance', 'risk', 'underwriting'],
  true,
  '1.0.0',
  'system',
  '2025-09-07T17:07:24.112485',
  '[{"id":"client","label":"Client name","type":"text","order":1},{"id":"businessType","label":"Business type","type":"text","order":2},{"id":"riskFactors","label":"Risk factors","type":"textarea","order":3},{"id":"riskLevel","label":"Risk level","type":"dropdown","options":["Low","Medium","High"],"order":4},{"id":"recommendations","label":"Recommendations","type":"textarea","order":5}]'::jsonb,
  '{"template":"risk-assessment"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'loss-control-visit',
  '00000000-0000-0000-0000-000000000001',
  'Loss Control Site Visit',
  'Safety and loss prevention inspection',
  'Insurance',
  ARRAY['insurance', 'loss-control', 'safety'],
  true,
  '1.0.0',
  'system',
  '2025-09-06T17:07:24.112497',
  '[{"id":"insured","label":"Insured name","type":"text","order":1},{"id":"safetyProgram","label":"Safety program in place","type":"toggle","order":2},{"id":"hazards","label":"Hazards identified","type":"textarea","order":3},{"id":"recommendations","label":"Recommendations","type":"textarea","order":4}]'::jsonb,
  '{"template":"loss-control"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'subrogation',
  '00000000-0000-0000-0000-000000000001',
  'Subrogation Investigation',
  'Recovery investigation for paid claims',
  'Insurance',
  ARRAY['insurance', 'subrogation', 'recovery'],
  true,
  '1.0.0',
  'system',
  '2025-09-05T17:07:24.112506',
  '[{"id":"claimNumber","label":"Claim #","type":"text","order":1},{"id":"amountPaid","label":"Amount paid","type":"number","order":2},{"id":"responsibleParty","label":"Responsible party","type":"text","order":3},{"id":"liability","label":"Liability %","type":"number","order":4},{"id":"recoveryPotential","label":"Recovery potential","type":"dropdown","options":["High","Medium","Low"],"order":5}]'::jsonb,
  '{"template":"subrogation"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'fraud-investigation',
  '00000000-0000-0000-0000-000000000001',
  'Insurance Fraud Investigation',
  'Suspected fraudulent claim investigation',
  'Insurance',
  ARRAY['insurance', 'fraud', 'investigation'],
  true,
  '1.0.0',
  'system',
  '2025-09-04T17:07:24.112518',
  '[{"id":"claimNumber","label":"Claim #","type":"text","order":1},{"id":"redFlags","label":"Red flags","type":"textarea","order":2},{"id":"statement","label":"Claimant statement","type":"textarea","order":3},{"id":"evidence","label":"Evidence collected","type":"textarea","order":4},{"id":"recommendation","label":"Recommendation","type":"dropdown","options":["Pay","Deny","Further investigation"],"order":5}]'::jsonb,
  '{"template":"fraud"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'policy-renewal',
  '00000000-0000-0000-0000-000000000001',
  'Policy Renewal Inspection',
  'Renewal underwriting inspection',
  'Insurance',
  ARRAY['insurance', 'renewal', 'underwriting'],
  true,
  '1.0.0',
  'system',
  '2025-09-03T17:07:24.112536',
  '[{"id":"policyNumber","label":"Policy #","type":"text","order":1},{"id":"changesInRisk","label":"Changes in risk","type":"textarea","order":2},{"id":"claimsHistory","label":"Claims since inception","type":"number","order":3},{"id":"renewalRecommendation","label":"Renewal recommendation","type":"dropdown","options":["Renew","Non-renew","Renew with conditions"],"order":4}]'::jsonb,
  '{"template":"renewal"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'commercial-property-loss',
  '00000000-0000-0000-0000-000000000001',
  'Commercial Property Loss',
  'Commercial property damage assessment',
  'Insurance',
  ARRAY['insurance', 'property', 'commercial'],
  true,
  '1.0.0',
  'system',
  '2025-09-02T17:07:24.112547',
  '[{"id":"propertyAddress","label":"Property address","type":"text","order":1},{"id":"causeOfLoss","label":"Cause of loss","type":"dropdown","options":["Fire","Water","Wind","Theft","Vandalism"],"order":2},{"id":"damagedAreas","label":"Damaged areas","type":"textarea","order":3},{"id":"businessInterruption","label":"Business interruption","type":"toggle","order":4},{"id":"estimatedLoss","label":"Estimated loss","type":"number","order":5}]'::jsonb,
  '{"template":"commercial-loss"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'cyber-incident',
  '00000000-0000-0000-0000-000000000001',
  'Cyber Insurance Incident',
  'Data breach and cyber attack claim',
  'Insurance',
  ARRAY['insurance', 'cyber', 'data-breach'],
  true,
  '1.0.0',
  'system',
  '2025-09-01T17:07:24.112557',
  '[{"id":"insured","label":"Insured name","type":"text","order":1},{"id":"incidentType","label":"Incident type","type":"dropdown","options":["Ransomware","Data breach","Phishing","DDoS"],"order":2},{"id":"recordsAffected","label":"Records affected","type":"number","order":3},{"id":"forensics","label":"Forensics engaged","type":"toggle","order":4},{"id":"estimatedCost","label":"Estimated cost","type":"number","order":5}]'::jsonb,
  '{"template":"cyber"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'umbrella-claim',
  '00000000-0000-0000-0000-000000000001',
  'Umbrella/Excess Claim',
  'Excess liability claim documentation',
  'Insurance',
  ARRAY['insurance', 'umbrella', 'excess'],
  true,
  '1.0.0',
  'system',
  '2025-08-31T17:07:24.112569',
  '[{"id":"underlyingPolicy","label":"Underlying policy #","type":"text","order":1},{"id":"excessAmount","label":"Excess amount","type":"number","order":2},{"id":"underlyingLimits","label":"Underlying limits exhausted","type":"toggle","order":3},{"id":"claimDetails","label":"Claim details","type":"textarea","order":4}]'::jsonb,
  '{"template":"umbrella"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'bond-claim',
  '00000000-0000-0000-0000-000000000001',
  'Surety Bond Claim',
  'Performance or payment bond claim',
  'Insurance',
  ARRAY['insurance', 'surety', 'bond'],
  true,
  '1.0.0',
  'system',
  '2025-08-30T17:07:24.112579',
  '[{"id":"bondNumber","label":"Bond #","type":"text","order":1},{"id":"principal","label":"Principal name","type":"text","order":2},{"id":"claimAmount","label":"Claim amount","type":"number","order":3},{"id":"breach","label":"Breach description","type":"textarea","order":4},{"id":"valid","label":"Valid claim","type":"toggle","order":5}]'::jsonb,
  '{"template":"bond"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'hvac-maintenance',
  '00000000-0000-0000-0000-000000000001',
  'HVAC System Maintenance',
  'Heating and cooling system inspection',
  'Facilities',
  ARRAY['facilities', 'hvac', 'maintenance'],
  true,
  '1.0.0',
  'system',
  '2025-08-29T17:07:24.112595',
  '[{"id":"unitNumber","label":"Unit #","type":"text","order":1},{"id":"filterChanged","label":"Filter changed","type":"toggle","order":2},{"id":"refrigerantLevel","label":"Refrigerant level OK","type":"toggle","order":3},{"id":"airflow","label":"Airflow adequate","type":"toggle","order":4},{"id":"notes","label":"Notes","type":"textarea","order":5}]'::jsonb,
  '{"template":"hvac"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'lighting-inspection',
  '00000000-0000-0000-0000-000000000001',
  'Lighting Inspection',
  'Building lighting and fixture check',
  'Facilities',
  ARRAY['facilities', 'lighting', 'electrical'],
  true,
  '1.0.0',
  'system',
  '2025-08-28T17:07:24.112605',
  '[{"id":"area","label":"Area","type":"text","order":1},{"id":"fixturesWorking","label":"Fixtures working","type":"number","order":2},{"id":"fixturesBroken","label":"Fixtures broken","type":"number","order":3},{"id":"bulbsReplaced","label":"Bulbs replaced","type":"number","order":4}]'::jsonb,
  '{"template":"lighting"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'plumbing-repair',
  '00000000-0000-0000-0000-000000000001',
  'Plumbing Repair Log',
  'Plumbing maintenance and leak repairs',
  'Facilities',
  ARRAY['facilities', 'plumbing', 'maintenance'],
  true,
  '1.0.0',
  'system',
  '2025-08-27T17:07:24.112614',
  '[{"id":"location","label":"Location","type":"text","order":1},{"id":"issueType","label":"Issue type","type":"dropdown","options":["Leak","Clog","Low pressure","Other"],"order":2},{"id":"repairDescription","label":"Repair description","type":"textarea","order":3},{"id":"partsUsed","label":"Parts used","type":"text","order":4},{"id":"resolved","label":"Resolved","type":"toggle","order":5}]'::jsonb,
  '{"template":"plumbing"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'grounds-maintenance',
  '00000000-0000-0000-0000-000000000001',
  'Grounds Maintenance',
  'Landscaping and exterior grounds upkeep',
  'Facilities',
  ARRAY['facilities', 'grounds', 'landscaping'],
  true,
  '1.0.0',
  'system',
  '2025-08-26T17:07:24.112629',
  '[{"id":"mowingCompleted","label":"Mowing completed","type":"toggle","order":1},{"id":"trimming","label":"Trimming done","type":"toggle","order":2},{"id":"irrigation","label":"Irrigation checked","type":"toggle","order":3},{"id":"debrisRemoved","label":"Debris removed","type":"toggle","order":4}]'::jsonb,
  '{"template":"grounds"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'elevator-inspection',
  '00000000-0000-0000-0000-000000000001',
  'Elevator Inspection',
  'Monthly elevator safety and operation check',
  'Facilities',
  ARRAY['facilities', 'elevator', 'safety'],
  true,
  '1.0.0',
  'system',
  '2025-08-25T17:07:24.112638',
  '[{"id":"elevatorNumber","label":"Elevator #","type":"text","order":1},{"id":"doorsOperating","label":"Doors operating properly","type":"toggle","order":2},{"id":"emergencyPhone","label":"Emergency phone functional","type":"toggle","order":3},{"id":"lighting","label":"Lighting OK","type":"toggle","order":4},{"id":"smoothRide","label":"Smooth ride","type":"toggle","order":5}]'::jsonb,
  '{"template":"elevator"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'building-security-check',
  '00000000-0000-0000-0000-000000000001',
  'Building Security Check',
  'Access control and security system verification',
  'Facilities',
  ARRAY['facilities', 'security', 'access'],
  true,
  '1.0.0',
  'system',
  '2025-08-24T17:07:24.112653',
  '[{"id":"locksChecked","label":"Locks checked","type":"toggle","order":1},{"id":"alarmsWorking","label":"Alarms working","type":"toggle","order":2},{"id":"camerasOperational","label":"Cameras operational","type":"toggle","order":3},{"id":"accessCardSystem","label":"Access card system OK","type":"toggle","order":4}]'::jsonb,
  '{"template":"security-check"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'roof-inspection',
  '00000000-0000-0000-0000-000000000001',
  'Roof Inspection',
  'Roof condition and leak prevention check',
  'Facilities',
  ARRAY['facilities', 'roof', 'inspection'],
  true,
  '1.0.0',
  'system',
  '2025-08-23T17:07:24.112662',
  '[{"id":"section","label":"Roof section","type":"text","order":1},{"id":"leaks","label":"Leaks detected","type":"toggle","order":2},{"id":"drainage","label":"Drainage clear","type":"toggle","order":3},{"id":"damage","label":"Damage description","type":"textarea","order":4},{"id":"photos","label":"Photos","type":"photo","order":5}]'::jsonb,
  '{"template":"roof"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'restroom-cleaning',
  '00000000-0000-0000-0000-000000000001',
  'Restroom Cleaning Checklist',
  'Restroom sanitation and supply check',
  'Facilities',
  ARRAY['facilities', 'cleaning', 'restroom'],
  true,
  '1.0.0',
  'system',
  '2025-08-22T17:07:24.112673',
  '[{"id":"restroomNumber","label":"Restroom #","type":"text","order":1},{"id":"cleaned","label":"Cleaned","type":"toggle","order":2},{"id":"suppliesRestocked","label":"Supplies restocked","type":"toggle","order":3},{"id":"fixturesWorking","label":"Fixtures working","type":"toggle","order":4}]'::jsonb,
  '{"template":"restroom"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'fire-system-test',
  '00000000-0000-0000-0000-000000000001',
  'Fire System Test',
  'Fire alarm and suppression system test',
  'Facilities',
  ARRAY['facilities', 'fire', 'safety'],
  true,
  '1.0.0',
  'system',
  '2025-08-21T17:07:24.112682',
  '[{"id":"panelNumber","label":"Panel #","type":"text","order":1},{"id":"alarmsTested","label":"Alarms tested","type":"number","order":2},{"id":"detectorsWorking","label":"Detectors working","type":"toggle","order":3},{"id":"sprinklersChecked","label":"Sprinklers checked","type":"toggle","order":4},{"id":"passed","label":"Passed inspection","type":"toggle","order":5}]'::jsonb,
  '{"template":"fire-system"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'parking-lot-maintenance',
  '00000000-0000-0000-0000-000000000001',
  'Parking Lot Maintenance',
  'Parking lot surface and striping inspection',
  'Facilities',
  ARRAY['facilities', 'parking', 'maintenance'],
  true,
  '1.0.0',
  'system',
  '2025-08-20T17:07:24.112692',
  '[{"id":"area","label":"Area","type":"text","order":1},{"id":"potholes","label":"Potholes present","type":"toggle","order":2},{"id":"stripingNeeded","label":"Striping needed","type":"toggle","order":3},{"id":"lightingWorking","label":"Lighting working","type":"toggle","order":4},{"id":"sweeping","label":"Sweeping needed","type":"toggle","order":5}]'::jsonb,
  '{"template":"parking"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'generator-test',
  '00000000-0000-0000-0000-000000000001',
  'Emergency Generator Test',
  'Backup power system test and maintenance',
  'Facilities',
  ARRAY['facilities', 'generator', 'emergency'],
  true,
  '1.0.0',
  'system',
  '2025-08-19T17:07:24.112701',
  '[{"id":"generatorId","label":"Generator ID","type":"text","order":1},{"id":"startedSuccessfully","label":"Started successfully","type":"toggle","order":2},{"id":"voltage","label":"Voltage","type":"number","order":3},{"id":"fuelLevel","label":"Fuel level %","type":"number","order":4},{"id":"runtime","label":"Runtime (minutes)","type":"number","order":5}]'::jsonb,
  '{"template":"generator"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'water-heater-maintenance',
  '00000000-0000-0000-0000-000000000001',
  'Water Heater Maintenance',
  'Hot water system inspection and maintenance',
  'Facilities',
  ARRAY['facilities', 'water-heater', 'maintenance'],
  true,
  '1.0.0',
  'system',
  '2025-08-18T17:07:24.112714',
  '[{"id":"unitNumber","label":"Unit #","type":"text","order":1},{"id":"temperature","label":"Temperature (F)","type":"number","order":2},{"id":"pressureRelief","label":"Pressure relief valve tested","type":"toggle","order":3},{"id":"sedimentFlushed","label":"Sediment flushed","type":"toggle","order":4},{"id":"leaks","label":"Leaks detected","type":"toggle","order":5}]'::jsonb,
  '{"template":"water-heater"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'pest-control',
  '00000000-0000-0000-0000-000000000001',
  'Pest Control Inspection',
  'Pest monitoring and treatment log',
  'Facilities',
  ARRAY['facilities', 'pest', 'inspection'],
  true,
  '1.0.0',
  'system',
  '2025-08-17T17:07:24.112724',
  '[{"id":"area","label":"Area","type":"text","order":1},{"id":"pestsDetected","label":"Pests detected","type":"toggle","order":2},{"id":"pestType","label":"Pest type","type":"text","order":3},{"id":"treatmentApplied","label":"Treatment applied","type":"textarea","order":4},{"id":"followUpNeeded","label":"Follow-up needed","type":"toggle","order":5}]'::jsonb,
  '{"template":"pest-control"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'air-quality-monitoring',
  '00000000-0000-0000-0000-000000000001',
  'Air Quality Monitoring',
  'Ambient air quality measurement and testing',
  'Environmental',
  ARRAY['environmental', 'air', 'monitoring'],
  true,
  '1.0.0',
  'system',
  '2025-08-16T17:07:24.112766',
  '[{"id":"location","label":"Location","type":"text","order":1},{"id":"pm25","label":"PM2.5 (μg/m³)","type":"number","order":2},{"id":"pm10","label":"PM10 (μg/m³)","type":"number","order":3},{"id":"temperature","label":"Temperature","type":"number","order":4},{"id":"humidity","label":"Humidity %","type":"number","order":5}]'::jsonb,
  '{"template":"air-quality"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'water-quality-test',
  '00000000-0000-0000-0000-000000000001',
  'Water Quality Test',
  'Water sample analysis and contamination check',
  'Environmental',
  ARRAY['environmental', 'water', 'testing'],
  true,
  '1.0.0',
  'system',
  '2025-08-15T17:07:24.112811',
  '[{"id":"sampleLocation","label":"Sample location","type":"text","order":1},{"id":"ph","label":"pH level","type":"number","order":2},{"id":"turbidity","label":"Turbidity (NTU)","type":"number","order":3},{"id":"coliform","label":"Coliform present","type":"toggle","order":4},{"id":"chlorine","label":"Chlorine (mg/L)","type":"number","order":5}]'::jsonb,
  '{"template":"water-quality"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'waste-tracking',
  '00000000-0000-0000-0000-000000000001',
  'Waste Tracking Log',
  'Hazardous and non-hazardous waste disposal',
  'Environmental',
  ARRAY['environmental', 'waste', 'disposal'],
  true,
  '1.0.0',
  'system',
  '2025-08-14T17:07:24.112827',
  '[{"id":"wasteType","label":"Waste type","type":"dropdown","options":["Hazardous","Non-hazardous","Recyclable","E-waste"],"order":1},{"id":"quantity","label":"Quantity (kg)","type":"number","order":2},{"id":"disposalMethod","label":"Disposal method","type":"text","order":3},{"id":"manifestNumber","label":"Manifest #","type":"text","order":4}]'::jsonb,
  '{"template":"waste-tracking"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'classroom-observation',
  '00000000-0000-0000-0000-000000000001',
  'Classroom Observation Form',
  'Teacher evaluation and instructional quality assessment',
  'Education',
  ARRAY['education', 'teaching', 'evaluation'],
  true,
  '1.0.0',
  'system',
  '2025-08-13T17:07:24.112841',
  '[{"id":"teacher","label":"Teacher name","type":"text","order":1},{"id":"subject","label":"Subject","type":"text","order":2},{"id":"grade","label":"Grade level","type":"text","order":3},{"id":"engagement","label":"Student engagement (1-5)","type":"number","order":4},{"id":"instructionQuality","label":"Instruction quality (1-5)","type":"number","order":5},{"id":"classroomManagement","label":"Classroom management (1-5)","type":"number","order":6},{"id":"notes","label":"Observation notes","type":"textarea","order":7}]'::jsonb,
  '{"template":"classroom-observation"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'student-incident',
  '00000000-0000-0000-0000-000000000001',
  'Student Incident Report',
  'Behavioral incident documentation',
  'Education',
  ARRAY['education', 'behavior', 'incident'],
  true,
  '1.0.0',
  'system',
  '2025-08-12T17:07:24.112851',
  '[{"id":"studentName","label":"Student name","type":"text","order":1},{"id":"grade","label":"Grade","type":"text","order":2},{"id":"date","label":"Incident date","type":"date","order":3},{"id":"location","label":"Location","type":"text","order":4},{"id":"type","label":"Incident type","type":"dropdown","options":["Behavioral","Bullying","Physical altercation","Vandalism","Other"],"order":5},{"id":"description","label":"Description","type":"textarea","order":6},{"id":"witnesses","label":"Witnesses","type":"textarea","order":7},{"id":"action","label":"Action taken","type":"textarea","order":8}]'::jsonb,
  '{"template":"student-incident"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'field-trip',
  '00000000-0000-0000-0000-000000000001',
  'Field Trip Permission & Checklist',
  'Field trip planning and parent consent',
  'Education',
  ARRAY['education', 'field-trip', 'permission'],
  true,
  '1.0.0',
  'system',
  '2025-08-11T17:07:24.112920',
  '[{"id":"destination","label":"Destination","type":"text","order":1},{"id":"date","label":"Date","type":"date","order":2},{"id":"grade","label":"Grade level","type":"text","order":3},{"id":"chaperones","label":"Number of chaperones","type":"number","order":4},{"id":"busCount","label":"Buses needed","type":"number","order":5},{"id":"permissionReceived","label":"All permissions received","type":"toggle","order":6},{"id":"emergencyPlan","label":"Emergency plan confirmed","type":"toggle","order":7}]'::jsonb,
  '{"template":"field-trip"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'iep-meeting',
  '00000000-0000-0000-0000-000000000001',
  'IEP Meeting Notes',
  'Individualized Education Program meeting documentation',
  'Education',
  ARRAY['education', 'iep', 'special-education'],
  true,
  '1.0.0',
  'system',
  '2025-08-10T17:07:24.112935',
  '[{"id":"studentName","label":"Student name","type":"text","order":1},{"id":"meetingDate","label":"Meeting date","type":"date","order":2},{"id":"attendees","label":"Attendees","type":"textarea","order":3},{"id":"goals","label":"Goals discussed","type":"textarea","order":4},{"id":"accommodations","label":"Accommodations","type":"textarea","order":5},{"id":"parentConsent","label":"Parent consent obtained","type":"toggle","order":6}]'::jsonb,
  '{"template":"iep-meeting"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'line-check',
  '00000000-0000-0000-0000-000000000001',
  'Kitchen Line Check',
  'Pre-service kitchen station readiness',
  'Food Service',
  ARRAY['restaurant', 'kitchen', 'prep'],
  true,
  '1.0.0',
  'system',
  '2025-08-09T17:07:24.112946',
  '[{"id":"station","label":"Station","type":"dropdown","options":["Grill","Fry","Saute","Salad","Dessert","Expo"],"order":1},{"id":"stocked","label":"Fully stocked","type":"toggle","order":2},{"id":"clean","label":"Clean and sanitized","type":"toggle","order":3},{"id":"equipmentWorking","label":"Equipment operational","type":"toggle","order":4},{"id":"notes","label":"Notes","type":"textarea","order":5}]'::jsonb,
  '{"template":"line-check"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'menu-tasting',
  '00000000-0000-0000-0000-000000000001',
  'Menu Tasting Evaluation',
  'New dish evaluation and feedback',
  'Food Service',
  ARRAY['restaurant', 'culinary', 'menu'],
  true,
  '1.0.0',
  'system',
  '2025-08-08T17:07:24.112955',
  '[{"id":"dishName","label":"Dish name","type":"text","order":1},{"id":"chef","label":"Chef","type":"text","order":2},{"id":"presentation","label":"Presentation (1-5)","type":"number","order":3},{"id":"taste","label":"Taste (1-5)","type":"number","order":4},{"id":"portionSize","label":"Portion size (1-5)","type":"number","order":5},{"id":"costFeasibility","label":"Cost feasibility (1-5)","type":"number","order":6},{"id":"feedback","label":"Detailed feedback","type":"textarea","order":7},{"id":"approved","label":"Approved for menu","type":"toggle","order":8}]'::jsonb,
  '{"template":"menu-tasting"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'server-checklist',
  '00000000-0000-0000-0000-000000000001',
  'Server Pre-Shift Checklist',
  'FOH readiness and table assignments',
  'Food Service',
  ARRAY['restaurant', 'server', 'foh'],
  true,
  '1.0.0',
  'system',
  '2025-08-07T17:07:24.112965',
  '[{"id":"server","label":"Server name","type":"text","order":1},{"id":"section","label":"Section","type":"text","order":2},{"id":"uniformCheck","label":"Uniform inspection passed","type":"toggle","order":3},{"id":"tablesSet","label":"All tables set","type":"toggle","order":4},{"id":"menuKnowledge","label":"Reviewed specials","type":"toggle","order":5},{"id":"posReady","label":"POS system ready","type":"toggle","order":6}]'::jsonb,
  '{"template":"server-checklist"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'personal-training',
  '00000000-0000-0000-0000-000000000001',
  'Personal Training Session Log',
  'Client workout tracking and progress',
  'Fitness',
  ARRAY['fitness', 'training', 'workout'],
  true,
  '1.0.0',
  'system',
  '2025-08-06T17:07:24.112975',
  '[{"id":"client","label":"Client name","type":"text","order":1},{"id":"trainer","label":"Trainer","type":"text","order":2},{"id":"sessionDate","label":"Session date","type":"date","order":3},{"id":"focusArea","label":"Focus area","type":"dropdown","options":["Strength","Cardio","Flexibility","Mobility","Sports specific"],"order":4},{"id":"exercises","label":"Exercises performed","type":"textarea","order":5},{"id":"sets","label":"Sets/Reps","type":"textarea","order":6},{"id":"clientFeedback","label":"Client feedback","type":"textarea","order":7},{"id":"nextSessionGoals","label":"Next session goals","type":"textarea","order":8}]'::jsonb,
  '{"template":"personal-training"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'equipment-maintenance-gym',
  '00000000-0000-0000-0000-000000000001',
  'Gym Equipment Maintenance',
  'Fitness equipment inspection and repair log',
  'Fitness',
  ARRAY['fitness', 'equipment', 'maintenance'],
  true,
  '1.0.0',
  'system',
  '2025-08-05T17:07:24.112988',
  '[{"id":"equipmentName","label":"Equipment","type":"text","order":1},{"id":"serialNumber","label":"Serial #","type":"text","order":2},{"id":"issue","label":"Issue description","type":"textarea","order":3},{"id":"severity","label":"Severity","type":"dropdown","options":["Minor","Moderate","Critical - Out of service"],"order":4},{"id":"repairAction","label":"Repair action taken","type":"textarea","order":5},{"id":"partsReplaced","label":"Parts replaced","type":"text","order":6},{"id":"backInService","label":"Back in service","type":"toggle","order":7}]'::jsonb,
  '{"template":"equipment-maintenance-gym"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'member-onboarding',
  '00000000-0000-0000-0000-000000000001',
  'New Member Onboarding',
  'Gym tour, orientation, and goal setting',
  'Fitness',
  ARRAY['fitness', 'membership', 'onboarding'],
  true,
  '1.0.0',
  'system',
  '2025-08-04T17:07:24.112998',
  '[{"id":"memberName","label":"Member name","type":"text","order":1},{"id":"membershipType","label":"Membership type","type":"dropdown","options":["Basic","Premium","VIP"],"order":2},{"id":"tourCompleted","label":"Facility tour completed","type":"toggle","order":3},{"id":"equipmentDemo","label":"Equipment demo given","type":"toggle","order":4},{"id":"goals","label":"Fitness goals","type":"textarea","order":5},{"id":"medicalClearance","label":"Medical clearance on file","type":"toggle","order":6}]'::jsonb,
  '{"template":"member-onboarding"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'client-intake-legal',
  '00000000-0000-0000-0000-000000000001',
  'Legal Client Intake Form',
  'New client information and case details',
  'Legal',
  ARRAY['legal', 'intake', 'client'],
  true,
  '1.0.0',
  'system',
  '2025-08-03T17:07:24.113011',
  '[{"id":"clientName","label":"Client name","type":"text","order":1},{"id":"contactInfo","label":"Contact information","type":"textarea","order":2},{"id":"caseType","label":"Case type","type":"dropdown","options":["Civil litigation","Criminal defense","Family law","Real estate","Estate planning","Corporate"],"order":3},{"id":"caseDescription","label":"Case description","type":"textarea","order":4},{"id":"conflictCheck","label":"Conflict check completed","type":"toggle","order":5},{"id":"retainerSigned","label":"Retainer agreement signed","type":"toggle","order":6}]'::jsonb,
  '{"template":"client-intake-legal"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'court-appearance',
  '00000000-0000-0000-0000-000000000001',
  'Court Appearance Report',
  'Hearing documentation and outcomes',
  'Legal',
  ARRAY['legal', 'court', 'hearing'],
  true,
  '1.0.0',
  'system',
  '2025-08-02T17:07:24.113021',
  '[{"id":"caseNumber","label":"Case number","type":"text","order":1},{"id":"courtName","label":"Court name","type":"text","order":2},{"id":"judge","label":"Judge","type":"text","order":3},{"id":"hearingType","label":"Hearing type","type":"text","order":4},{"id":"date","label":"Date","type":"date","order":5},{"id":"outcome","label":"Outcome","type":"textarea","order":6},{"id":"nextSteps","label":"Next steps","type":"textarea","order":7}]'::jsonb,
  '{"template":"court-appearance"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'deposition-prep',
  '00000000-0000-0000-0000-000000000001',
  'Deposition Preparation Checklist',
  'Pre-deposition planning and witness prep',
  'Legal',
  ARRAY['legal', 'deposition', 'litigation'],
  true,
  '1.0.0',
  'system',
  '2025-08-01T17:07:24.113065',
  '[{"id":"witness","label":"Witness name","type":"text","order":1},{"id":"depositionDate","label":"Deposition date","type":"date","order":2},{"id":"location","label":"Location","type":"text","order":3},{"id":"documentsReviewed","label":"Documents reviewed with witness","type":"toggle","order":4},{"id":"witnessPrepared","label":"Witness prep session completed","type":"toggle","order":5},{"id":"exhibits","label":"Exhibits prepared","type":"toggle","order":6},{"id":"notes","label":"Notes","type":"textarea","order":7}]'::jsonb,
  '{"template":"deposition-prep"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'property-showing',
  '00000000-0000-0000-0000-000000000001',
  'Property Showing Report',
  'Buyer feedback and showing details',
  'Real Estate',
  ARRAY['real-estate', 'showing', 'property'],
  true,
  '1.0.0',
  'system',
  '2025-07-31T17:07:24.113079',
  '[{"id":"propertyAddress","label":"Property address","type":"text","order":1},{"id":"buyerName","label":"Buyer name","type":"text","order":2},{"id":"agent","label":"Agent","type":"text","order":3},{"id":"showingDate","label":"Showing date","type":"date","order":4},{"id":"buyerInterest","label":"Buyer interest level (1-5)","type":"number","order":5},{"id":"feedback","label":"Buyer feedback","type":"textarea","order":6},{"id":"followUpNeeded","label":"Follow-up needed","type":"toggle","order":7}]'::jsonb,
  '{"template":"property-showing"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'open-house',
  '00000000-0000-0000-0000-000000000001',
  'Open House Sign-In',
  'Visitor tracking and interest capture',
  'Real Estate',
  ARRAY['real-estate', 'open-house', 'marketing'],
  true,
  '1.0.0',
  'system',
  '2025-07-30T17:07:24.113093',
  '[{"id":"visitorName","label":"Visitor name","type":"text","order":1},{"id":"email","label":"Email","type":"text","order":2},{"id":"phone","label":"Phone","type":"phone","order":3},{"id":"currentlyWorking","label":"Working with an agent","type":"toggle","order":4},{"id":"preApproved","label":"Pre-approved","type":"toggle","order":5},{"id":"timeframe","label":"Buying timeframe","type":"dropdown","options":["Immediately","1-3 months","3-6 months","6+ months","Just looking"],"order":6},{"id":"notes","label":"Notes","type":"textarea","order":7}]'::jsonb,
  '{"template":"open-house"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'home-inspection',
  '00000000-0000-0000-0000-000000000001',
  'Home Inspection Report',
  'Structural and systems inspection findings',
  'Real Estate',
  ARRAY['real-estate', 'inspection', 'property'],
  true,
  '1.0.0',
  'system',
  '2025-07-29T17:07:24.113107',
  '[{"id":"propertyAddress","label":"Property address","type":"text","order":1},{"id":"inspector","label":"Inspector","type":"text","order":2},{"id":"inspectionDate","label":"Inspection date","type":"date","order":3},{"id":"roofCondition","label":"Roof condition","type":"dropdown","options":["Excellent","Good","Fair","Poor"],"order":4},{"id":"foundationCondition","label":"Foundation condition","type":"dropdown","options":["Excellent","Good","Fair","Poor"],"order":5},{"id":"plumbingCondition","label":"Plumbing condition","type":"dropdown","options":["Excellent","Good","Fair","Poor"],"order":6},{"id":"electricalCondition","label":"Electrical condition","type":"dropdown","options":["Excellent","Good","Fair","Poor"],"order":7},{"id":"majorIssues","label":"Major issues found","type":"textarea","order":8},{"id":"photos","label":"Photos","type":"photo","order":9}]'::jsonb,
  '{"template":"home-inspection"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'crop-scouting',
  '00000000-0000-0000-0000-000000000001',
  'Crop Scouting Report',
  'Field inspection for pests, disease, and growth',
  'Agriculture',
  ARRAY['agriculture', 'farming', 'crops'],
  true,
  '1.0.0',
  'system',
  '2025-07-28T17:07:24.113268',
  '[{"id":"fieldNumber","label":"Field number","type":"text","order":1},{"id":"cropType","label":"Crop type","type":"text","order":2},{"id":"scoutDate","label":"Scout date","type":"date","order":3},{"id":"growthStage","label":"Growth stage","type":"text","order":4},{"id":"pestsPres ent","label":"Pests present","type":"textarea","order":5},{"id":"diseaseObserved","label":"Disease observed","type":"textarea","order":6},{"id":"weedPressure","label":"Weed pressure (1-5)","type":"number","order":7},{"id":"actionNeeded","label":"Action needed","type":"textarea","order":8},{"id":"photos","label":"Photos","type":"photo","order":9}]'::jsonb,
  '{"template":"crop-scouting"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'livestock-health',
  '00000000-0000-0000-0000-000000000001',
  'Livestock Health Check',
  'Animal health monitoring and treatment log',
  'Agriculture',
  ARRAY['agriculture', 'livestock', 'health'],
  true,
  '1.0.0',
  'system',
  '2025-07-27T17:07:24.113293',
  '[{"id":"animalId","label":"Animal ID","type":"text","order":1},{"id":"species","label":"Species","type":"dropdown","options":["Cattle","Swine","Sheep","Goats","Poultry","Other"],"order":2},{"id":"checkDate","label":"Check date","type":"date","order":3},{"id":"temperature","label":"Temperature (°F)","type":"number","order":4},{"id":"appetite","label":"Appetite","type":"dropdown","options":["Normal","Reduced","None"],"order":5},{"id":"symptoms","label":"Symptoms","type":"textarea","order":6},{"id":"treatmentGiven","label":"Treatment given","type":"textarea","order":7},{"id":"vetConsult","label":"Veterinarian consulted","type":"toggle","order":8}]'::jsonb,
  '{"template":"livestock-health"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'irrigation-log',
  '00000000-0000-0000-0000-000000000001',
  'Irrigation System Log',
  'Water management and system operation',
  'Agriculture',
  ARRAY['agriculture', 'irrigation', 'water'],
  true,
  '1.0.0',
  'system',
  '2025-07-26T17:07:24.113303',
  '[{"id":"fieldNumber","label":"Field number","type":"text","order":1},{"id":"date","label":"Date","type":"date","order":2},{"id":"startTime","label":"Start time","type":"text","order":3},{"id":"endTime","label":"End time","type":"text","order":4},{"id":"waterVolume","label":"Water volume (gallons)","type":"number","order":5},{"id":"systemPressure","label":"System pressure (PSI)","type":"number","order":6},{"id":"issuesObserved","label":"Issues observed","type":"textarea","order":7}]'::jsonb,
  '{"template":"irrigation-log"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'pre-flight',
  '00000000-0000-0000-0000-000000000001',
  'Pre-Flight Inspection',
  'Aircraft safety check before flight',
  'Aviation',
  ARRAY['aviation', 'aircraft', 'safety'],
  true,
  '1.0.0',
  'system',
  '2025-07-25T17:07:24.113311',
  '[{"id":"aircraftRegistration","label":"Aircraft registration","type":"text","order":1},{"id":"pilot","label":"Pilot in command","type":"text","order":2},{"id":"date","label":"Date","type":"date","order":3},{"id":"fuelLevel","label":"Fuel level","type":"text","order":4},{"id":"externalInspection","label":"External inspection complete","type":"toggle","order":5},{"id":"engineCheck","label":"Engine check complete","type":"toggle","order":6},{"id":"instrumentsCheck","label":"Instruments operational","type":"toggle","order":7},{"id":"defects","label":"Defects noted","type":"textarea","order":8},{"id":"safeForFlight","label":"Safe for flight","type":"toggle","order":9}]'::jsonb,
  '{"template":"pre-flight"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'maintenance-release',
  '00000000-0000-0000-0000-000000000001',
  'Aircraft Maintenance Release',
  'Return to service after maintenance',
  'Aviation',
  ARRAY['aviation', 'maintenance', 'aircraft'],
  true,
  '1.0.0',
  'system',
  '2025-07-24T17:07:24.113323',
  '[{"id":"aircraftRegistration","label":"Aircraft registration","type":"text","order":1},{"id":"workOrder","label":"Work order #","type":"text","order":2},{"id":"maintenancePerformed","label":"Maintenance performed","type":"textarea","order":3},{"id":"partsReplaced","label":"Parts replaced","type":"textarea","order":4},{"id":"testFlight","label":"Test flight completed","type":"toggle","order":5},{"id":"certifyingMechanic","label":"Certifying mechanic","type":"text","order":6},{"id":"licenseNumber","label":"License #","type":"text","order":7},{"id":"signature","label":"Signature","type":"signature","order":8}]'::jsonb,
  '{"template":"maintenance-release"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'event-setup',
  '00000000-0000-0000-0000-000000000001',
  'Event Setup Checklist',
  'Pre-event venue and equipment preparation',
  'Events',
  ARRAY['events', 'setup', 'venue'],
  true,
  '1.0.0',
  'system',
  '2025-07-23T17:07:24.113330',
  '[{"id":"eventName","label":"Event name","type":"text","order":1},{"id":"venue","label":"Venue","type":"text","order":2},{"id":"setupDate","label":"Setup date","type":"date","order":3},{"id":"seatingArranged","label":"Seating arranged","type":"toggle","order":4},{"id":"avEquipmentTested","label":"AV equipment tested","type":"toggle","order":5},{"id":"signagePosted","label":"Signage posted","type":"toggle","order":6},{"id":"cateringReady","label":"Catering ready","type":"toggle","order":7},{"id":"notes","label":"Notes","type":"textarea","order":8}]'::jsonb,
  '{"template":"event-setup"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'post-event',
  '00000000-0000-0000-0000-000000000001',
  'Post-Event Report',
  'Event wrap-up and feedback',
  'Events',
  ARRAY['events', 'feedback', 'report'],
  true,
  '1.0.0',
  'system',
  '2025-07-22T17:07:24.113337',
  '[{"id":"eventName","label":"Event name","type":"text","order":1},{"id":"eventDate","label":"Event date","type":"date","order":2},{"id":"attendance","label":"Attendance","type":"number","order":3},{"id":"overallSuccess","label":"Overall success (1-5)","type":"number","order":4},{"id":"highlights","label":"Highlights","type":"textarea","order":5},{"id":"challenges","label":"Challenges","type":"textarea","order":6},{"id":"lessonsLearned","label":"Lessons learned","type":"textarea","order":7},{"id":"photos","label":"Event photos","type":"photo","order":8}]'::jsonb,
  '{"template":"post-event"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'pet-boarding-intake',
  '00000000-0000-0000-0000-000000000001',
  'Pet Boarding Intake Form',
  'Pet information and care instructions',
  'Pet Care',
  ARRAY['pets', 'boarding', 'veterinary'],
  true,
  '1.0.0',
  'system',
  '2025-07-21T17:07:24.113346',
  '[{"id":"petName","label":"Pet name","type":"text","order":1},{"id":"species","label":"Species","type":"dropdown","options":["Dog","Cat","Bird","Other"],"order":2},{"id":"breed","label":"Breed","type":"text","order":3},{"id":"ownerName","label":"Owner name","type":"text","order":4},{"id":"emergencyContact","label":"Emergency contact","type":"phone","order":5},{"id":"feedingInstructions","label":"Feeding instructions","type":"textarea","order":6},{"id":"medications","label":"Medications","type":"textarea","order":7},{"id":"specialNeeds","label":"Special needs","type":"textarea","order":8},{"id":"vaccinationsCurrent","label":"Vaccinations current","type":"toggle","order":9}]'::jsonb,
  '{"template":"pet-boarding-intake"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  'vet-exam',
  '00000000-0000-0000-0000-000000000001',
  'Veterinary Exam Report',
  'Physical examination findings and diagnosis',
  'Pet Care',
  ARRAY['veterinary', 'exam', 'health'],
  true,
  '1.0.0',
  'system',
  '2025-07-20T17:07:24.113363',
  '[{"id":"petName","label":"Pet name","type":"text","order":1},{"id":"examDate","label":"Exam date","type":"date","order":2},{"id":"veterinarian","label":"Veterinarian","type":"text","order":3},{"id":"weight","label":"Weight (lbs)","type":"number","order":4},{"id":"temperature","label":"Temperature (°F)","type":"number","order":5},{"id":"chiefComplaint","label":"Chief complaint","type":"textarea","order":6},{"id":"findings","label":"Exam findings","type":"textarea","order":7},{"id":"diagnosis","label":"Diagnosis","type":"textarea","order":8},{"id":"treatment","label":"Treatment plan","type":"textarea","order":9}]'::jsonb,
  '{"template":"vet-exam"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();


COMMIT;

-- Verify insertion
SELECT category, COUNT(*) as count 
FROM forms 
WHERE org_id = '00000000-0000-0000-0000-000000000001'
GROUP BY category 
ORDER BY category;

SELECT 'Successfully inserted ' || COUNT(*)::text || ' forms' as result
FROM forms
WHERE org_id = '00000000-0000-0000-0000-000000000001';
