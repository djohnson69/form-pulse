-- Migration: Backfill employees from existing profiles
-- Only backfills INTERNAL roles (superadmin, admin, manager, supervisor, employee, maintenance, techsupport)
-- External roles (client, vendor, viewer) are excluded

INSERT INTO employees (
  org_id,
  user_id,
  first_name,
  last_name,
  email,
  position,
  department,
  hire_date,
  is_active,
  metadata
)
SELECT
  p.org_id,
  p.id AS user_id,
  p.first_name,
  p.last_name,
  p.email,
  CASE p.role
    WHEN 'superadmin' THEN 'Owner / Executive'
    WHEN 'admin' THEN 'Administrator'
    WHEN 'manager' THEN 'Manager'
    WHEN 'supervisor' THEN 'Supervisor'
    WHEN 'maintenance' THEN 'Maintenance Technician'
    WHEN 'techsupport' THEN 'Technical Support'
    ELSE 'Team Member'
  END AS position,
  CASE p.role
    WHEN 'superadmin' THEN 'Executive'
    WHEN 'admin' THEN 'Administration'
    WHEN 'manager' THEN 'Management'
    WHEN 'maintenance' THEN 'Maintenance'
    WHEN 'techsupport' THEN 'IT Support'
    ELSE 'Operations'
  END AS department,
  COALESCE(p.created_at, NOW()) AS hire_date,
  COALESCE(p.is_active, true) AS is_active,
  jsonb_build_object(
    'role', p.role,
    'backfilled', true,
    'backfilledAt', NOW(),
    'isSupervisor', p.role IN ('superadmin', 'admin', 'manager', 'supervisor'),
    'isManager', p.role IN ('superadmin', 'admin', 'manager')
  ) AS metadata
FROM profiles p
WHERE p.org_id IS NOT NULL
  -- Only backfill INTERNAL roles
  AND p.role IN ('superadmin', 'admin', 'manager', 'supervisor', 'employee', 'maintenance', 'techsupport')
  -- Skip if employee record already exists
  AND NOT EXISTS (
    SELECT 1 FROM employees e
    WHERE e.org_id = p.org_id AND e.user_id = p.id
  );
