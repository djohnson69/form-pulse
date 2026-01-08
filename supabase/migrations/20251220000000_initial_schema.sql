-- Supabase schema for FormBridge
-- Apply via Supabase SQL editor or CLI.

create extension if not exists "pgcrypto";
create extension if not exists "uuid-ossp";

-- Organizations
create table if not exists orgs (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  created_at timestamptz not null default now()
);

create table if not exists org_members (
  org_id uuid not null references orgs(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'member',
  created_at timestamptz not null default now(),
  primary key (org_id, user_id)
);

create table if not exists teams (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references orgs(id) on delete cascade,
  name text not null,
  description text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (org_id, name)
);

create table if not exists team_members (
  team_id uuid not null references teams(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (team_id, user_id)
);

-- User profiles
create table if not exists profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  org_id uuid references orgs(id),
  email text,
  first_name text,
  last_name text,
  phone text,
  role text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Forms and versions
create table if not exists forms (
  id text primary key default gen_random_uuid()::text,
  org_id uuid not null references orgs(id) on delete cascade,
  title text not null,
  description text,
  category text,
  tags text[] not null default '{}'::text[],
  fields jsonb not null default '[]'::jsonb,
  metadata jsonb not null default '{}'::jsonb,
  is_published boolean not null default false,
  version text,
  current_version text,
  created_by text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists form_versions (
  id uuid primary key default gen_random_uuid(),
  form_id text not null references forms(id) on delete cascade,
  version text not null,
  definition jsonb not null, -- full form JSON including fields
  metadata jsonb,
  created_by text,
  created_at timestamptz not null default now(),
  unique (form_id, version)
);

-- Submissions and attachments
create table if not exists submissions (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references orgs(id) on delete cascade,
  form_id text not null references forms(id) on delete cascade,
  form_version_id uuid references form_versions(id),
  submitted_by uuid references auth.users(id),
  submitted_at timestamptz not null default now(),
  status text not null default 'submitted',
  data jsonb not null default '{}'::jsonb,
  attachments jsonb not null default '[]'::jsonb,
  location jsonb,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists attachments (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references orgs(id) on delete cascade,
  submission_id uuid not null references submissions(id) on delete cascade,
  user_id uuid references auth.users(id),
  url text not null,
  filename text,
  type text,
  hash text,
  metadata jsonb,
  created_at timestamptz not null default now()
);

-- Projects and updates
create table if not exists projects (
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

create table if not exists project_updates (
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

-- Tasks
create table if not exists tasks (
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

-- Assets and inspections
create table if not exists equipment (
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
  inspection_cadence text,
  last_inspection_at timestamptz,
  next_inspection_at timestamptz,
  is_active boolean not null default true,
  company_id text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb
);

create table if not exists device_tokens (
  id uuid primary key default gen_random_uuid(),
  org_id uuid references orgs(id) on delete cascade,
  user_id uuid references auth.users(id) on delete cascade,
  token text not null,
  platform text,
  is_active boolean not null default true,
  last_seen_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb,
  unique (token)
);

create table if not exists asset_inspections (
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

create table if not exists incident_reports (
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

-- Clients and vendors
create table if not exists clients (
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

create table if not exists vendors (
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

-- Messaging
create table if not exists message_threads (
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

create table if not exists message_participants (
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

create table if not exists messages (
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

-- Employees and training records
create table if not exists employees (
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

create table if not exists training_records (
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

-- Documents and versions
create table if not exists documents (
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

create table if not exists document_versions (
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

-- SOPs and templates
create table if not exists sop_documents (
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

create table if not exists sop_versions (
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

create table if not exists sop_approvals (
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

create table if not exists sop_acknowledgements (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references orgs(id) on delete cascade,
  sop_id uuid not null references sop_documents(id) on delete cascade,
  version_id uuid references sop_versions(id) on delete set null,
  user_id uuid references auth.users(id),
  acknowledged_at timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb,
  unique (sop_id, version_id, user_id)
);

create table if not exists app_templates (
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
create table if not exists news_posts (
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

create table if not exists notification_rules (
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

create table if not exists notification_events (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references orgs(id) on delete cascade,
  rule_id uuid references notification_rules(id) on delete set null,
  status text not null default 'queued',
  fired_at timestamptz not null default now(),
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb
);

create table if not exists notebook_pages (
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

create table if not exists notebook_reports (
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

create table if not exists signature_requests (
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

create table if not exists project_photos (
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

create table if not exists photo_comments (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references orgs(id) on delete cascade,
  photo_id uuid not null references project_photos(id) on delete cascade,
  author_id uuid references auth.users(id),
  body text not null,
  created_at timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb
);

create table if not exists webhook_endpoints (
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

create table if not exists integrations (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references orgs(id) on delete cascade,
  provider text not null,
  status text not null default 'inactive',
  config jsonb not null default '{}'::jsonb,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (org_id, provider)
);

create table if not exists export_jobs (
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

create table if not exists ai_jobs (
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

create table if not exists daily_logs (
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

create table if not exists guest_invites (
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

create table if not exists payment_requests (
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

create table if not exists reviews (
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

create table if not exists portfolio_items (
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

-- Notifications
create table if not exists notifications (
  id uuid primary key default gen_random_uuid(),
  org_id uuid references orgs(id) on delete cascade,
  user_id uuid references auth.users(id),
  title text not null,
  body text not null,
  type text,
  is_read boolean not null default false,
  created_at timestamptz not null default now(),
  read_at timestamptz
);

-- Audit log
create table if not exists audit_log (
  id bigserial primary key,
  org_id uuid references orgs(id) on delete cascade,
  actor_id uuid references auth.users(id),
  resource_type text not null,
  resource_id text,
  action text not null,
  payload jsonb,
  created_at timestamptz not null default now()
);

-- RLS
alter table orgs enable row level security;
alter table org_members enable row level security;
alter table profiles enable row level security;
alter table teams enable row level security;
alter table team_members enable row level security;
alter table device_tokens enable row level security;
alter table forms enable row level security;
alter table form_versions enable row level security;
alter table submissions enable row level security;
alter table attachments enable row level security;
alter table projects enable row level security;
alter table project_updates enable row level security;
alter table tasks enable row level security;
alter table equipment enable row level security;
alter table asset_inspections enable row level security;
alter table incident_reports enable row level security;
alter table news_posts enable row level security;
alter table notification_rules enable row level security;
alter table notification_events enable row level security;
alter table notebook_pages enable row level security;
alter table notebook_reports enable row level security;
alter table signature_requests enable row level security;
alter table project_photos enable row level security;
alter table photo_comments enable row level security;
alter table webhook_endpoints enable row level security;
alter table integrations enable row level security;
alter table export_jobs enable row level security;
alter table ai_jobs enable row level security;
alter table daily_logs enable row level security;
alter table guest_invites enable row level security;
alter table payment_requests enable row level security;
alter table reviews enable row level security;
alter table portfolio_items enable row level security;
alter table clients enable row level security;
alter table vendors enable row level security;
alter table message_threads enable row level security;
alter table message_participants enable row level security;
alter table messages enable row level security;
alter table employees enable row level security;
alter table training_records enable row level security;
alter table documents enable row level security;
alter table document_versions enable row level security;
alter table sop_documents enable row level security;
alter table sop_versions enable row level security;
alter table sop_approvals enable row level security;
alter table sop_acknowledgements enable row level security;
alter table app_templates enable row level security;
alter table notifications enable row level security;
alter table audit_log enable row level security;

-- Helper policies: org membership (safe create if missing)
do $$
begin
  if not exists (select 1 from pg_policies where policyname = 'Org members can read orgs') then
    create policy "Org members can read orgs"
      on orgs for select
      using (exists (
        select 1 from org_members m where m.org_id = orgs.id and m.user_id = auth.uid()
      ));
  end if;

  if not exists (select 1 from pg_policies where policyname = 'Org members manage membership') then
    create policy "Org members manage membership"
      on org_members for all
      using (user_id = auth.uid());
  end if;

  if not exists (select 1 from pg_policies where policyname = 'Org members manage teams') then
    create policy "Org members manage teams"
      on teams for all
      using (exists (
        select 1 from org_members m where m.org_id = teams.org_id and m.user_id = auth.uid()
      ));
  end if;

  if not exists (select 1 from pg_policies where policyname = 'Org members manage team members') then
    create policy "Org members manage team members"
      on team_members for all
      using (exists (
        select 1 from teams t
        join org_members m on m.org_id = t.org_id and m.user_id = auth.uid()
        where t.id = team_members.team_id
      ));
  end if;

  if not exists (select 1 from pg_policies where policyname = 'Org members read profiles') then
    create policy "Org members read profiles"
      on profiles for select
      using (exists (
        select 1 from org_members m where m.org_id = profiles.org_id and m.user_id = auth.uid()
      ));
  end if;

  if not exists (select 1 from pg_policies where policyname = 'Org members manage own profile') then
    create policy "Org members manage own profile"
      on profiles for all
      using (id = auth.uid());
  end if;

  if not exists (select 1 from pg_policies where policyname = 'Org admins manage profiles') then
    create policy "Org admins manage profiles"
      on profiles for update
      using (exists (
        select 1 from org_members m
        where m.org_id = profiles.org_id
          and m.user_id = auth.uid()
          and m.role in ('owner', 'admin')
      ))
      with check (exists (
        select 1 from org_members m
        where m.org_id = profiles.org_id
          and m.user_id = auth.uid()
          and m.role in ('owner', 'admin')
      ));
  end if;

  if not exists (select 1 from pg_policies where policyname = 'Users manage device tokens') then
    create policy "Users manage device tokens"
      on device_tokens for all
      using (user_id = auth.uid())
      with check (user_id = auth.uid());
  end if;

  if not exists (select 1 from pg_policies where policyname = 'Org members read forms') then
    create policy "Org members read forms"
      on forms for select
      using (exists (
        select 1 from org_members m where m.org_id = forms.org_id and m.user_id = auth.uid()
      ));
  end if;

  if not exists (select 1 from pg_policies where policyname = 'Org members manage forms') then
    create policy "Org members manage forms"
      on forms for all
      using (exists (
        select 1 from org_members m where m.org_id = forms.org_id and m.user_id = auth.uid()
      ));
  end if;

  if not exists (select 1 from pg_policies where policyname = 'Org members read form versions') then
    create policy "Org members read form versions"
      on form_versions for select
      using (exists (
        select 1 from forms f
        join org_members m on m.org_id = f.org_id and m.user_id = auth.uid()
        where f.id = form_versions.form_id
      ));
  end if;

  if not exists (select 1 from pg_policies where policyname = 'Org members manage form versions') then
    create policy "Org members manage form versions"
      on form_versions for all
      using (exists (
        select 1 from forms f
        join org_members m on m.org_id = f.org_id and m.user_id = auth.uid()
        where f.id = form_versions.form_id
      ));
  end if;

  if not exists (select 1 from pg_policies where policyname = 'Org members read submissions') then
    create policy "Org members read submissions"
      on submissions for select
      using (exists (
        select 1 from org_members m where m.org_id = submissions.org_id and m.user_id = auth.uid()
      ));
  end if;

  if not exists (select 1 from pg_policies where policyname = 'Org members insert submissions') then
    create policy "Org members insert submissions"
      on submissions for insert
      with check (exists (
        select 1 from org_members m where m.org_id = submissions.org_id and m.user_id = auth.uid()
      ));
  end if;

  if not exists (select 1 from pg_policies where policyname = 'Org members update submissions') then
    create policy "Org members update submissions"
      on submissions for update
      using (exists (
        select 1 from org_members m where m.org_id = submissions.org_id and m.user_id = auth.uid()
      ))
      with check (exists (
        select 1 from org_members m where m.org_id = submissions.org_id and m.user_id = auth.uid()
      ));
  end if;

  if not exists (select 1 from pg_policies where policyname = 'Org members read attachments') then
    create policy "Org members read attachments"
      on attachments for select
      using (exists (
        select 1 from org_members m where m.org_id = attachments.org_id and m.user_id = auth.uid()
      ));
  end if;

  if not exists (select 1 from pg_policies where policyname = 'Org members insert attachments') then
    create policy "Org members insert attachments"
      on attachments for insert
      with check (exists (
        select 1 from org_members m where m.org_id = attachments.org_id and m.user_id = auth.uid()
      ));
  end if;

  if not exists (select 1 from pg_policies where policyname = 'Org members read projects') then
    create policy "Org members read projects"
      on projects for select
      using (exists (
        select 1 from org_members m where m.org_id = projects.org_id and m.user_id = auth.uid()
      ));
  end if;

  if not exists (select 1 from pg_policies where policyname = 'Org members manage projects') then
    create policy "Org members manage projects"
      on projects for all
      using (exists (
        select 1 from org_members m where m.org_id = projects.org_id and m.user_id = auth.uid()
      ));
  end if;

  if not exists (select 1 from pg_policies where policyname = 'Org members read project updates') then
    create policy "Org members read project updates"
      on project_updates for select
      using (exists (
        select 1 from org_members m where m.org_id = project_updates.org_id and m.user_id = auth.uid()
      ));
  end if;

  if not exists (select 1 from pg_policies where policyname = 'Org members manage project updates') then
    create policy "Org members manage project updates"
      on project_updates for all
      using (exists (
        select 1 from org_members m where m.org_id = project_updates.org_id and m.user_id = auth.uid()
      ));
  end if;

  if not exists (select 1 from pg_policies where policyname = 'Org members read tasks') then
    create policy "Org members read tasks"
      on tasks for select
      using (exists (
        select 1 from org_members m where m.org_id = tasks.org_id and m.user_id = auth.uid()
      ));
  end if;

  if not exists (select 1 from pg_policies where policyname = 'Org members manage tasks') then
    create policy "Org members manage tasks"
      on tasks for all
      using (exists (
        select 1 from org_members m where m.org_id = tasks.org_id and m.user_id = auth.uid()
      ));
  end if;

  if not exists (select 1 from pg_policies where policyname = 'Org members read equipment') then
    create policy "Org members read equipment"
      on equipment for select
      using (exists (
        select 1 from org_members m where m.org_id = equipment.org_id and m.user_id = auth.uid()
      ));
  end if;

  if not exists (select 1 from pg_policies where policyname = 'Org members manage equipment') then
    create policy "Org members manage equipment"
      on equipment for all
      using (exists (
        select 1 from org_members m where m.org_id = equipment.org_id and m.user_id = auth.uid()
      ));
  end if;

  if not exists (select 1 from pg_policies where policyname = 'Org members read asset inspections') then
    create policy "Org members read asset inspections"
      on asset_inspections for select
      using (exists (
        select 1 from org_members m where m.org_id = asset_inspections.org_id and m.user_id = auth.uid()
      ));
  end if;

  if not exists (select 1 from pg_policies where policyname = 'Org members manage asset inspections') then
    create policy "Org members manage asset inspections"
      on asset_inspections for all
      using (exists (
        select 1 from org_members m where m.org_id = asset_inspections.org_id and m.user_id = auth.uid()
      ));
  end if;

  if not exists (select 1 from pg_policies where policyname = 'Org members read incident reports') then
    create policy "Org members read incident reports"
      on incident_reports for select
      using (exists (
        select 1 from org_members m where m.org_id = incident_reports.org_id and m.user_id = auth.uid()
      ));
  end if;

  if not exists (select 1 from pg_policies where policyname = 'Org members manage incident reports') then
    create policy "Org members manage incident reports"
      on incident_reports for all
      using (exists (
        select 1 from org_members m where m.org_id = incident_reports.org_id and m.user_id = auth.uid()
      ));
  end if;

  if not exists (select 1 from pg_policies where policyname = 'Org members read news posts') then
    create policy "Org members read news posts"
      on news_posts for select
      using (exists (
        select 1 from org_members m where m.org_id = news_posts.org_id and m.user_id = auth.uid()
      ));
  end if;

  if not exists (select 1 from pg_policies where policyname = 'Org members manage news posts') then
    create policy "Org members manage news posts"
      on news_posts for all
      using (exists (
        select 1 from org_members m where m.org_id = news_posts.org_id and m.user_id = auth.uid()
      ));
  end if;

  if not exists (select 1 from pg_policies where policyname = 'Org members read notification rules') then
    create policy "Org members read notification rules"
      on notification_rules for select
      using (exists (
        select 1 from org_members m where m.org_id = notification_rules.org_id and m.user_id = auth.uid()
      ));
  end if;

  if not exists (select 1 from pg_policies where policyname = 'Org members manage notification rules') then
    create policy "Org members manage notification rules"
      on notification_rules for all
      using (exists (
        select 1 from org_members m where m.org_id = notification_rules.org_id and m.user_id = auth.uid()
      ));
  end if;

  if not exists (select 1 from pg_policies where policyname = 'Org members read notification events') then
    create policy "Org members read notification events"
      on notification_events for select
      using (exists (
        select 1 from org_members m where m.org_id = notification_events.org_id and m.user_id = auth.uid()
      ));
  end if;

  if not exists (select 1 from pg_policies where policyname = 'Org members manage notification events') then
    create policy "Org members manage notification events"
      on notification_events for all
      using (exists (
        select 1 from org_members m where m.org_id = notification_events.org_id and m.user_id = auth.uid()
      ));
  end if;

  if not exists (select 1 from pg_policies where policyname = 'Org members read notebook pages') then
    create policy "Org members read notebook pages"
      on notebook_pages for select
      using (exists (
        select 1 from org_members m where m.org_id = notebook_pages.org_id and m.user_id = auth.uid()
      ));
  end if;

  if not exists (select 1 from pg_policies where policyname = 'Org members manage notebook pages') then
    create policy "Org members manage notebook pages"
      on notebook_pages for all
      using (exists (
        select 1 from org_members m where m.org_id = notebook_pages.org_id and m.user_id = auth.uid()
      ));
  end if;

  if not exists (select 1 from pg_policies where policyname = 'Org members read notebook reports') then
    create policy "Org members read notebook reports"
      on notebook_reports for select
      using (exists (
        select 1 from org_members m where m.org_id = notebook_reports.org_id and m.user_id = auth.uid()
      ));
  end if;

  if not exists (select 1 from pg_policies where policyname = 'Org members manage notebook reports') then
    create policy "Org members manage notebook reports"
      on notebook_reports for all
      using (exists (
        select 1 from org_members m where m.org_id = notebook_reports.org_id and m.user_id = auth.uid()
      ));
  end if;

  if not exists (select 1 from pg_policies where policyname = 'Org members read signature requests') then
    create policy "Org members read signature requests"
      on signature_requests for select
      using (exists (
        select 1 from org_members m where m.org_id = signature_requests.org_id and m.user_id = auth.uid()
      ));
  end if;

  if not exists (select 1 from pg_policies where policyname = 'Org members manage signature requests') then
    create policy "Org members manage signature requests"
      on signature_requests for all
      using (exists (
        select 1 from org_members m where m.org_id = signature_requests.org_id and m.user_id = auth.uid()
      ));
  end if;

  if not exists (select 1 from pg_policies where policyname = 'Org members read project photos') then
    create policy "Org members read project photos"
      on project_photos for select
      using (exists (
        select 1 from org_members m where m.org_id = project_photos.org_id and m.user_id = auth.uid()
      ));
  end if;

  if not exists (select 1 from pg_policies where policyname = 'Org members manage project photos') then
    create policy "Org members manage project photos"
      on project_photos for all
      using (exists (
        select 1 from org_members m where m.org_id = project_photos.org_id and m.user_id = auth.uid()
      ));
  end if;

  if not exists (select 1 from pg_policies where policyname = 'Org members read photo comments') then
    create policy "Org members read photo comments"
      on photo_comments for select
      using (exists (
        select 1 from org_members m where m.org_id = photo_comments.org_id and m.user_id = auth.uid()
      ));
  end if;

  if not exists (select 1 from pg_policies where policyname = 'Org members manage photo comments') then
    create policy "Org members manage photo comments"
      on photo_comments for all
      using (exists (
        select 1 from org_members m where m.org_id = photo_comments.org_id and m.user_id = auth.uid()
      ));
  end if;

  if not exists (select 1 from pg_policies where policyname = 'Org members read webhook endpoints') then
    create policy "Org members read webhook endpoints"
      on webhook_endpoints for select
      using (exists (
        select 1 from org_members m where m.org_id = webhook_endpoints.org_id and m.user_id = auth.uid()
      ));
  end if;

  if not exists (select 1 from pg_policies where policyname = 'Org members manage webhook endpoints') then
    create policy "Org members manage webhook endpoints"
      on webhook_endpoints for all
      using (exists (
        select 1 from org_members m where m.org_id = webhook_endpoints.org_id and m.user_id = auth.uid()
      ));
  end if;

  if not exists (select 1 from pg_policies where policyname = 'Org members read integrations') then
    create policy "Org members read integrations"
      on integrations for select
      using (exists (
        select 1 from org_members m where m.org_id = integrations.org_id and m.user_id = auth.uid()
      ));
  end if;

  if not exists (select 1 from pg_policies where policyname = 'Org members manage integrations') then
    create policy "Org members manage integrations"
      on integrations for all
      using (exists (
        select 1 from org_members m where m.org_id = integrations.org_id and m.user_id = auth.uid()
      ));
  end if;

  if not exists (select 1 from pg_policies where policyname = 'Org members read export jobs') then
    create policy "Org members read export jobs"
      on export_jobs for select
      using (exists (
        select 1 from org_members m where m.org_id = export_jobs.org_id and m.user_id = auth.uid()
      ));
  end if;

  if not exists (select 1 from pg_policies where policyname = 'Org members manage export jobs') then
    create policy "Org members manage export jobs"
      on export_jobs for all
      using (exists (
        select 1 from org_members m where m.org_id = export_jobs.org_id and m.user_id = auth.uid()
      ));
  end if;

  if not exists (select 1 from pg_policies where policyname = 'Org members read ai jobs') then
    create policy "Org members read ai jobs"
      on ai_jobs for select
      using (exists (
        select 1 from org_members m where m.org_id = ai_jobs.org_id and m.user_id = auth.uid()
      ));
  end if;

  if not exists (select 1 from pg_policies where policyname = 'Org members manage ai jobs') then
    create policy "Org members manage ai jobs"
      on ai_jobs for all
      using (exists (
        select 1 from org_members m where m.org_id = ai_jobs.org_id and m.user_id = auth.uid()
      ));
  end if;

  if not exists (select 1 from pg_policies where policyname = 'Org members read daily logs') then
    create policy "Org members read daily logs"
      on daily_logs for select
      using (exists (
        select 1 from org_members m where m.org_id = daily_logs.org_id and m.user_id = auth.uid()
      ));
  end if;

  if not exists (select 1 from pg_policies where policyname = 'Org members manage daily logs') then
    create policy "Org members manage daily logs"
      on daily_logs for all
      using (exists (
        select 1 from org_members m where m.org_id = daily_logs.org_id and m.user_id = auth.uid()
      ));
  end if;

  if not exists (select 1 from pg_policies where policyname = 'Org members read guest invites') then
    create policy "Org members read guest invites"
      on guest_invites for select
      using (exists (
        select 1 from org_members m where m.org_id = guest_invites.org_id and m.user_id = auth.uid()
      ));
  end if;

  if not exists (select 1 from pg_policies where policyname = 'Org members manage guest invites') then
    create policy "Org members manage guest invites"
      on guest_invites for all
      using (exists (
        select 1 from org_members m where m.org_id = guest_invites.org_id and m.user_id = auth.uid()
      ));
  end if;

  if not exists (select 1 from pg_policies where policyname = 'Org members read payment requests') then
    create policy "Org members read payment requests"
      on payment_requests for select
      using (exists (
        select 1 from org_members m where m.org_id = payment_requests.org_id and m.user_id = auth.uid()
      ));
  end if;

  if not exists (select 1 from pg_policies where policyname = 'Org members manage payment requests') then
    create policy "Org members manage payment requests"
      on payment_requests for all
      using (exists (
        select 1 from org_members m where m.org_id = payment_requests.org_id and m.user_id = auth.uid()
      ));
  end if;

  if not exists (select 1 from pg_policies where policyname = 'Org members read reviews') then
    create policy "Org members read reviews"
      on reviews for select
      using (exists (
        select 1 from org_members m where m.org_id = reviews.org_id and m.user_id = auth.uid()
      ));
  end if;

  if not exists (select 1 from pg_policies where policyname = 'Org members manage reviews') then
    create policy "Org members manage reviews"
      on reviews for all
      using (exists (
        select 1 from org_members m where m.org_id = reviews.org_id and m.user_id = auth.uid()
      ));
  end if;

  if not exists (select 1 from pg_policies where policyname = 'Org members read portfolio items') then
    create policy "Org members read portfolio items"
      on portfolio_items for select
      using (exists (
        select 1 from org_members m where m.org_id = portfolio_items.org_id and m.user_id = auth.uid()
      ));
  end if;

  if not exists (select 1 from pg_policies where policyname = 'Org members manage portfolio items') then
    create policy "Org members manage portfolio items"
      on portfolio_items for all
      using (exists (
        select 1 from org_members m where m.org_id = portfolio_items.org_id and m.user_id = auth.uid()
      ));
  end if;

  if not exists (select 1 from pg_policies where policyname = 'Org members read clients') then
    create policy "Org members read clients"
      on clients for select
      using (exists (
        select 1 from org_members m where m.org_id = clients.org_id and m.user_id = auth.uid()
      ));
  end if;

  if not exists (select 1 from pg_policies where policyname = 'Org members manage clients') then
    create policy "Org members manage clients"
      on clients for all
      using (exists (
        select 1 from org_members m where m.org_id = clients.org_id and m.user_id = auth.uid()
      ));
  end if;

  if not exists (select 1 from pg_policies where policyname = 'Org members read vendors') then
    create policy "Org members read vendors"
      on vendors for select
      using (exists (
        select 1 from org_members m where m.org_id = vendors.org_id and m.user_id = auth.uid()
      ));
  end if;

  if not exists (select 1 from pg_policies where policyname = 'Org members manage vendors') then
    create policy "Org members manage vendors"
      on vendors for all
      using (exists (
        select 1 from org_members m where m.org_id = vendors.org_id and m.user_id = auth.uid()
      ));
  end if;

  if not exists (select 1 from pg_policies where policyname = 'Org members read message threads') then
    create policy "Org members read message threads"
      on message_threads for select
      using (exists (
        select 1 from org_members m where m.org_id = message_threads.org_id and m.user_id = auth.uid()
      ));
  end if;

  if not exists (select 1 from pg_policies where policyname = 'Org members manage message threads') then
    create policy "Org members manage message threads"
      on message_threads for all
      using (exists (
        select 1 from org_members m where m.org_id = message_threads.org_id and m.user_id = auth.uid()
      ));
  end if;

  if not exists (select 1 from pg_policies where policyname = 'Org members read message participants') then
    create policy "Org members read message participants"
      on message_participants for select
      using (exists (
        select 1 from org_members m where m.org_id = message_participants.org_id and m.user_id = auth.uid()
      ));
  end if;

  if not exists (select 1 from pg_policies where policyname = 'Org members manage message participants') then
    create policy "Org members manage message participants"
      on message_participants for all
      using (exists (
        select 1 from org_members m where m.org_id = message_participants.org_id and m.user_id = auth.uid()
      ));
  end if;

  if not exists (select 1 from pg_policies where policyname = 'Org members read messages') then
    create policy "Org members read messages"
      on messages for select
      using (exists (
        select 1 from org_members m where m.org_id = messages.org_id and m.user_id = auth.uid()
      ));
  end if;

  if not exists (select 1 from pg_policies where policyname = 'Org members insert messages') then
    create policy "Org members insert messages"
      on messages for insert
      with check (exists (
        select 1 from org_members m where m.org_id = messages.org_id and m.user_id = auth.uid()
      ));
  end if;

  if not exists (select 1 from pg_policies where policyname = 'Org members read employees') then
    create policy "Org members read employees"
      on employees for select
      using (exists (
        select 1 from org_members m where m.org_id = employees.org_id and m.user_id = auth.uid()
      ));
  end if;

  if not exists (select 1 from pg_policies where policyname = 'Org members manage employees') then
    create policy "Org members manage employees"
      on employees for all
      using (exists (
        select 1 from org_members m where m.org_id = employees.org_id and m.user_id = auth.uid()
      ));
  end if;

  if not exists (select 1 from pg_policies where policyname = 'Org members read training records') then
    create policy "Org members read training records"
      on training_records for select
      using (exists (
        select 1 from org_members m where m.org_id = training_records.org_id and m.user_id = auth.uid()
      ));
  end if;

  if not exists (select 1 from pg_policies where policyname = 'Org members manage training records') then
    create policy "Org members manage training records"
      on training_records for all
      using (exists (
        select 1 from org_members m where m.org_id = training_records.org_id and m.user_id = auth.uid()
      ));
  end if;

  if not exists (select 1 from pg_policies where policyname = 'Org members read documents') then
    create policy "Org members read documents"
      on documents for select
      using (exists (
        select 1 from org_members m where m.org_id = documents.org_id and m.user_id = auth.uid()
      ));
  end if;

  if not exists (select 1 from pg_policies where policyname = 'Org members manage documents') then
    create policy "Org members manage documents"
      on documents for all
      using (exists (
        select 1 from org_members m where m.org_id = documents.org_id and m.user_id = auth.uid()
      ));
  end if;

  if not exists (select 1 from pg_policies where policyname = 'Org members read document versions') then
    create policy "Org members read document versions"
      on document_versions for select
      using (exists (
        select 1 from org_members m where m.org_id = document_versions.org_id and m.user_id = auth.uid()
      ));
  end if;

  if not exists (select 1 from pg_policies where policyname = 'Org members manage document versions') then
    create policy "Org members manage document versions"
      on document_versions for all
      using (exists (
        select 1 from org_members m where m.org_id = document_versions.org_id and m.user_id = auth.uid()
      ));
  end if;

  if not exists (select 1 from pg_policies where policyname = 'Org members read SOPs') then
    create policy "Org members read SOPs"
      on sop_documents for select
      using (exists (
        select 1 from org_members m where m.org_id = sop_documents.org_id and m.user_id = auth.uid()
      ));
  end if;

  if not exists (select 1 from pg_policies where policyname = 'Org members manage SOPs') then
    create policy "Org members manage SOPs"
      on sop_documents for all
      using (exists (
        select 1 from org_members m where m.org_id = sop_documents.org_id and m.user_id = auth.uid()
      ));
  end if;

  if not exists (select 1 from pg_policies where policyname = 'Org members read SOP versions') then
    create policy "Org members read SOP versions"
      on sop_versions for select
      using (exists (
        select 1 from org_members m where m.org_id = sop_versions.org_id and m.user_id = auth.uid()
      ));
  end if;

  if not exists (select 1 from pg_policies where policyname = 'Org members manage SOP versions') then
    create policy "Org members manage SOP versions"
      on sop_versions for all
      using (exists (
        select 1 from org_members m where m.org_id = sop_versions.org_id and m.user_id = auth.uid()
      ));
  end if;

  if not exists (select 1 from pg_policies where policyname = 'Org members read SOP approvals') then
    create policy "Org members read SOP approvals"
      on sop_approvals for select
      using (exists (
        select 1 from org_members m where m.org_id = sop_approvals.org_id and m.user_id = auth.uid()
      ));
  end if;

  if not exists (select 1 from pg_policies where policyname = 'Org members manage SOP approvals') then
    create policy "Org members manage SOP approvals"
      on sop_approvals for all
      using (exists (
        select 1 from org_members m where m.org_id = sop_approvals.org_id and m.user_id = auth.uid()
      ));
  end if;

  if not exists (select 1 from pg_policies where policyname = 'Org members read SOP acknowledgements') then
    create policy "Org members read SOP acknowledgements"
      on sop_acknowledgements for select
      using (exists (
        select 1 from org_members m where m.org_id = sop_acknowledgements.org_id and m.user_id = auth.uid()
      ));
  end if;

  if not exists (select 1 from pg_policies where policyname = 'Org members manage SOP acknowledgements') then
    create policy "Org members manage SOP acknowledgements"
      on sop_acknowledgements for all
      using (exists (
        select 1 from org_members m where m.org_id = sop_acknowledgements.org_id and m.user_id = auth.uid()
      ));
  end if;

  if not exists (select 1 from pg_policies where policyname = 'Org members read app templates') then
    create policy "Org members read app templates"
      on app_templates for select
      using (exists (
        select 1 from org_members m where m.org_id = app_templates.org_id and m.user_id = auth.uid()
      ));
  end if;

  if not exists (select 1 from pg_policies where policyname = 'Org members manage app templates') then
    create policy "Org members manage app templates"
      on app_templates for all
      using (exists (
        select 1 from org_members m where m.org_id = app_templates.org_id and m.user_id = auth.uid()
      ));
  end if;
end $$;

-- Storage policies: per-org prefixes (org-{orgId}/...)
-- Assumes bucket name is 'formbridge-attachments'
do $$
begin
  perform storage.set_policy(
    bucket_name => 'formbridge-attachments',
    policy_name => 'Org members can upload in their prefix',
    definition => $policy$
      auth.role() = 'authenticated'
      and exists (
        select 1
        from org_members m
        where m.user_id = auth.uid()
          and storage.foldername(objects.name) ilike ('org-' || m.org_id::text || '/%')
      )
    $policy$,
    action => 'insert'
  );
  perform storage.set_policy(
    bucket_name => 'formbridge-attachments',
    policy_name => 'Org members can read their prefix',
    definition => $policy$
      auth.role() = 'authenticated'
      and exists (
        select 1
        from org_members m
        where m.user_id = auth.uid()
          and storage.foldername(objects.name) ilike ('org-' || m.org_id::text || '/%')
      )
    $policy$,
    action => 'select'
  );
  perform storage.set_policy(
    bucket_name => 'formbridge-attachments',
    policy_name => 'Org members can delete their prefix',
    definition => $policy$
      auth.role() = 'authenticated'
      and exists (
        select 1
        from org_members m
        where m.user_id = auth.uid()
          and storage.foldername(objects.name) ilike ('org-' || m.org_id::text || '/%')
      )
    $policy$,
    action => 'delete'
  );
exception
  when others then null;
end $$;

do $$
begin
  if not exists (select 1 from pg_policies where policyname = 'Org members read notifications') then
    create policy "Org members read notifications"
      on notifications for select
      using (user_id = auth.uid());
  end if;

  if not exists (select 1 from pg_policies where policyname = 'Org members update notifications') then
    create policy "Org members update notifications"
      on notifications for update
      using (user_id = auth.uid());
  end if;

  if not exists (select 1 from pg_policies where policyname = 'Org members read audit') then
    create policy "Org members read audit"
      on audit_log for select
      using (exists (
        select 1 from org_members m where m.org_id = audit_log.org_id and m.user_id = auth.uid()
      ));
  end if;
end $$;

-- Utility indexes
create index if not exists idx_forms_org on forms(org_id);
create index if not exists idx_form_versions_form on form_versions(form_id);
create index if not exists idx_submissions_form on submissions(form_id);
create index if not exists idx_submissions_org on submissions(org_id);
create index if not exists idx_attachments_submission on attachments(submission_id);
create index if not exists idx_projects_org on projects(org_id);
create index if not exists idx_project_updates_project on project_updates(project_id);
create index if not exists idx_project_updates_org on project_updates(org_id);
create index if not exists idx_tasks_org on tasks(org_id);
create index if not exists idx_tasks_assignee on tasks(assigned_to);
create index if not exists idx_tasks_status on tasks(status);
create index if not exists idx_news_org on news_posts(org_id);
create index if not exists idx_news_published on news_posts(published_at);
create index if not exists idx_notification_rules_org on notification_rules(org_id);
create index if not exists idx_notification_events_org on notification_events(org_id);
create index if not exists idx_notification_events_rule on notification_events(rule_id);
create index if not exists idx_notebook_pages_org on notebook_pages(org_id);
create index if not exists idx_notebook_pages_project on notebook_pages(project_id);
create index if not exists idx_notebook_reports_org on notebook_reports(org_id);
create index if not exists idx_signature_requests_org on signature_requests(org_id);
create index if not exists idx_signature_requests_status on signature_requests(status);
create index if not exists idx_project_photos_org on project_photos(org_id);
create index if not exists idx_project_photos_project on project_photos(project_id);
create index if not exists idx_photo_comments_photo on photo_comments(photo_id);
create index if not exists idx_webhook_endpoints_org on webhook_endpoints(org_id);
create index if not exists idx_integrations_org on integrations(org_id);
create index if not exists idx_integrations_provider on integrations(provider);
create index if not exists idx_export_jobs_org on export_jobs(org_id);
create index if not exists idx_export_jobs_status on export_jobs(status);
create index if not exists idx_ai_jobs_org on ai_jobs(org_id);
create index if not exists idx_ai_jobs_status on ai_jobs(status);
create index if not exists idx_daily_logs_org on daily_logs(org_id);
create index if not exists idx_daily_logs_project on daily_logs(project_id);
create index if not exists idx_daily_logs_date on daily_logs(log_date);
create index if not exists idx_guest_invites_org on guest_invites(org_id);
create index if not exists idx_guest_invites_status on guest_invites(status);
create index if not exists idx_payment_requests_org on payment_requests(org_id);
create index if not exists idx_payment_requests_status on payment_requests(status);
create index if not exists idx_reviews_org on reviews(org_id);
create index if not exists idx_portfolio_items_org on portfolio_items(org_id);
create index if not exists idx_portfolio_items_project on portfolio_items(project_id);
create index if not exists idx_clients_org on clients(org_id);
create index if not exists idx_vendors_org on vendors(org_id);
create index if not exists idx_threads_org on message_threads(org_id);
create index if not exists idx_messages_thread on messages(thread_id);
create index if not exists idx_messages_org on messages(org_id);
create index if not exists idx_employees_org on employees(org_id);
create index if not exists idx_employees_user on employees(user_id);
create index if not exists idx_training_employee on training_records(employee_id);
create index if not exists idx_training_status on training_records(status);
create index if not exists idx_training_expiration on training_records(expiration_date);
create index if not exists idx_documents_org on documents(org_id);
create index if not exists idx_documents_project on documents(project_id);
create index if not exists idx_document_versions_doc on document_versions(document_id);
create index if not exists idx_notifications_user on notifications(user_id);
create index if not exists idx_audit_org on audit_log(org_id);
