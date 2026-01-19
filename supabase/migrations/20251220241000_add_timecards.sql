CREATE TABLE IF NOT EXISTS timecards (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references orgs(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  date date not null,
  clock_in text,
  clock_out text,
  hours_worked double precision not null default 0,
  project text,
  status text not null default 'pending',
  approved_by text,
  notes text,
  location_address text,
  location_lat double precision,
  location_lng double precision,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

ALTER TABLE timecards ENABLE ROW LEVEL SECURITY;

CREATE INDEX IF NOT EXISTS idx_timecards_org ON timecards(org_id);
CREATE INDEX IF NOT EXISTS idx_timecards_user ON timecards(user_id);
CREATE INDEX IF NOT EXISTS idx_timecards_date ON timecards(date);

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Org members read timecards') THEN
        CREATE POLICY "Org members read timecards"
            ON timecards FOR SELECT
            USING (
                user_id = auth.uid()
                OR EXISTS (
                    SELECT 1 FROM org_members m
                    WHERE m.org_id = timecards.org_id AND m.user_id = auth.uid()
                )
            );
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Org members manage timecards') THEN
        CREATE POLICY "Org members manage timecards"
            ON timecards FOR ALL
            USING (
                user_id = auth.uid()
                OR EXISTS (
                    SELECT 1 FROM org_members m
                    WHERE m.org_id = timecards.org_id AND m.user_id = auth.uid()
                )
            )
            WITH CHECK (
                user_id = auth.uid()
                OR EXISTS (
                    SELECT 1 FROM org_members m
                    WHERE m.org_id = timecards.org_id AND m.user_id = auth.uid()
                )
            );
    END IF;
END $$;
