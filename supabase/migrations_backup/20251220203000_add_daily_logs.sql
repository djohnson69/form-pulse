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

ALTER TABLE daily_logs ENABLE ROW LEVEL SECURITY;

CREATE INDEX IF NOT EXISTS idx_daily_logs_org ON daily_logs(org_id);
CREATE INDEX IF NOT EXISTS idx_daily_logs_project ON daily_logs(project_id);
CREATE INDEX IF NOT EXISTS idx_daily_logs_date ON daily_logs(log_date);

DO $$
BEGIN
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
END $$;
