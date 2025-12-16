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

-- User profiles
create table if not exists profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  org_id uuid references orgs(id),
  email text,
  first_name text,
  last_name text,
  phone text,
  role text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Forms and versions
create table if not exists forms (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references orgs(id) on delete cascade,
  title text not null,
  description text,
  category text,
  is_published boolean not null default false,
  current_version text,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists form_versions (
  id uuid primary key default gen_random_uuid(),
  form_id uuid not null references forms(id) on delete cascade,
  version text not null,
  definition jsonb not null, -- full form JSON including fields
  metadata jsonb,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  unique (form_id, version)
);

-- Submissions and attachments
create table if not exists submissions (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references orgs(id) on delete cascade,
  form_id uuid not null references forms(id) on delete cascade,
  form_version_id uuid references form_versions(id),
  submitted_by uuid references auth.users(id),
  submitted_at timestamptz not null default now(),
  status text not null default 'submitted',
  data jsonb not null default '{}'::jsonb,
  attachments jsonb not null default '[]'::jsonb,
  location jsonb,
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
  resource_id uuid,
  action text not null,
  payload jsonb,
  created_at timestamptz not null default now()
);

-- RLS
alter table orgs enable row level security;
alter table org_members enable row level security;
alter table profiles enable row level security;
alter table forms enable row level security;
alter table form_versions enable row level security;
alter table submissions enable row level security;
alter table attachments enable row level security;
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
create index if not exists idx_notifications_user on notifications(user_id);
create index if not exists idx_audit_org on audit_log(org_id);
