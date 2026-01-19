CREATE TABLE IF NOT EXISTS work_orders (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references orgs(id) on delete cascade,
  number text,
  title text not null,
  description text,
  status text not null default 'open',
  priority text not null default 'medium',
  type text not null default 'repair',
  asset_id uuid references equipment(id) on delete set null,
  asset_name text,
  asset_location text,
  asset_category text,
  requester text,
  assigned_to text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  due_date timestamptz,
  completed_at timestamptz,
  estimated_hours double precision not null default 0,
  actual_hours double precision,
  parts jsonb not null default '[]'::jsonb,
  notes jsonb not null default '[]'::jsonb,
  checklist jsonb not null default '[]'::jsonb,
  photos jsonb not null default '[]'::jsonb
);

ALTER TABLE work_orders ENABLE ROW LEVEL SECURITY;

CREATE INDEX IF NOT EXISTS idx_work_orders_org ON work_orders(org_id);
CREATE INDEX IF NOT EXISTS idx_work_orders_due_date ON work_orders(due_date);
CREATE INDEX IF NOT EXISTS idx_work_orders_created_at ON work_orders(created_at);
CREATE INDEX IF NOT EXISTS idx_work_orders_status ON work_orders(status);

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Org members read work orders') THEN
        CREATE POLICY "Org members read work orders"
            ON work_orders FOR SELECT
            USING (EXISTS (
                SELECT 1 FROM org_members m WHERE m.org_id = work_orders.org_id AND m.user_id = auth.uid()
            ));
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Org members manage work orders') THEN
        CREATE POLICY "Org members manage work orders"
            ON work_orders FOR ALL
            USING (EXISTS (
                SELECT 1 FROM org_members m WHERE m.org_id = work_orders.org_id AND m.user_id = auth.uid()
            ))
            WITH CHECK (EXISTS (
                SELECT 1 FROM org_members m WHERE m.org_id = work_orders.org_id AND m.user_id = auth.uid()
            ));
    END IF;
END $$;
