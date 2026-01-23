-- Migration: Add query performance indexes
-- These indexes improve performance for common queries in the automation function and elsewhere

-- Index for recent submissions query (automation function)
CREATE INDEX IF NOT EXISTS idx_submissions_org_created
  ON submissions(org_id, created_at DESC);

-- Index for due tasks query (automation function)
CREATE INDEX IF NOT EXISTS idx_tasks_org_due
  ON tasks(org_id, due_date)
  WHERE status != 'completed';

-- Index for equipment maintenance query (automation function)
CREATE INDEX IF NOT EXISTS idx_equipment_org_maintenance
  ON equipment(org_id, next_maintenance_date)
  WHERE is_active = true;

-- Index for training records expiry query (automation function)
CREATE INDEX IF NOT EXISTS idx_training_records_org_expiry
  ON training_records(org_id, expiration_date)
  WHERE status = 'completed';

-- Index for inspection due dates (automation function)
CREATE INDEX IF NOT EXISTS idx_equipment_org_inspection
  ON equipment(org_id, next_inspection_date)
  WHERE is_active = true;

-- Index for SOP acknowledgements query (automation function)
CREATE INDEX IF NOT EXISTS idx_sop_versions_org_active
  ON sop_versions(org_id, is_active)
  WHERE is_active = true;

-- Index for form submissions by form (common query pattern)
CREATE INDEX IF NOT EXISTS idx_submissions_form_created
  ON submissions(form_id, created_at DESC);

-- Index for project updates by project (common query pattern)
CREATE INDEX IF NOT EXISTS idx_project_updates_project_created
  ON project_updates(project_id, created_at DESC);

-- Index for active device tokens (push notifications)
CREATE INDEX IF NOT EXISTS idx_device_tokens_org_active
  ON device_tokens(org_id, is_active)
  WHERE is_active = true;

-- Index for payment requests by org and status
CREATE INDEX IF NOT EXISTS idx_payment_requests_org_status
  ON payment_requests(org_id, status);
