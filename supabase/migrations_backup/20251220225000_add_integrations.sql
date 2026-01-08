BEGIN;

CREATE TABLE IF NOT EXISTS integrations (
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

ALTER TABLE integrations ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (select 1 from pg_policies where policyname = 'Org members read integrations') THEN
    CREATE POLICY "Org members read integrations"
      ON integrations FOR SELECT
      USING (
        exists (
          select 1 from org_members m
          where m.org_id = integrations.org_id and m.user_id = auth.uid()
        )
      );
  END IF;

  IF NOT EXISTS (select 1 from pg_policies where policyname = 'Org members insert integrations') THEN
    CREATE POLICY "Org members insert integrations"
      ON integrations FOR INSERT
      WITH CHECK (
        exists (
          select 1 from org_members m
          where m.org_id = integrations.org_id and m.user_id = auth.uid()
        )
      );
  END IF;

  IF NOT EXISTS (select 1 from pg_policies where policyname = 'Org members update integrations') THEN
    CREATE POLICY "Org members update integrations"
      ON integrations FOR UPDATE
      USING (
        exists (
          select 1 from org_members m
          where m.org_id = integrations.org_id and m.user_id = auth.uid()
        )
      )
      WITH CHECK (
        exists (
          select 1 from org_members m
          where m.org_id = integrations.org_id and m.user_id = auth.uid()
        )
      );
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_integrations_org on integrations(org_id);
CREATE INDEX IF NOT EXISTS idx_integrations_provider on integrations(provider);

COMMIT;
