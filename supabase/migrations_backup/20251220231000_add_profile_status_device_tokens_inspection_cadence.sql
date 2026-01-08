alter table profiles
  add column if not exists is_active boolean not null default true;

alter table equipment
  add column if not exists inspection_cadence text;

alter table equipment
  add column if not exists last_inspection_at timestamptz;

alter table equipment
  add column if not exists next_inspection_at timestamptz;

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

create index if not exists device_tokens_user_id_idx on device_tokens(user_id);
create index if not exists device_tokens_org_id_idx on device_tokens(org_id);

alter table device_tokens enable row level security;

do $$
begin
  if not exists (select 1 from pg_policies where policyname = 'Users manage device tokens') then
    create policy "Users manage device tokens"
      on device_tokens for all
      using (user_id = auth.uid())
      with check (user_id = auth.uid());
  end if;
end $$;
