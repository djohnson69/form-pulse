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

alter table teams enable row level security;
alter table team_members enable row level security;

do $$
begin
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
end $$;
