-- Migration: Add trigger to sync profiles to employees for internal roles
-- This ensures employee records are created when profiles are inserted/updated
-- External roles (client, vendor, viewer) do NOT get employee records

-- Add unique constraint on employees for upsert operations
-- Use IF NOT EXISTS pattern to avoid errors if constraint already exists
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'employees_org_user_unique'
  ) THEN
    ALTER TABLE employees ADD CONSTRAINT employees_org_user_unique
      UNIQUE (org_id, user_id);
  END IF;
END $$;

-- Trigger function to sync profiles to employees (INTERNAL ROLES ONLY)
CREATE OR REPLACE FUNCTION sync_profile_to_employee()
RETURNS TRIGGER AS $$
BEGIN
  -- Only create employee if:
  -- 1. org_id is set (user is in an org)
  -- 2. Role is an INTERNAL role (not client/vendor/viewer)
  IF NEW.org_id IS NOT NULL AND NEW.role IN (
    'superadmin', 'admin', 'manager', 'supervisor',
    'employee', 'maintenance', 'techsupport'
  ) THEN
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
    VALUES (
      NEW.org_id,
      NEW.id,
      NEW.first_name,
      NEW.last_name,
      NEW.email,
      CASE NEW.role
        WHEN 'superadmin' THEN 'Owner / Executive'
        WHEN 'admin' THEN 'Administrator'
        WHEN 'manager' THEN 'Manager'
        WHEN 'supervisor' THEN 'Supervisor'
        WHEN 'maintenance' THEN 'Maintenance Technician'
        WHEN 'techsupport' THEN 'Technical Support'
        ELSE 'Team Member'
      END,
      CASE NEW.role
        WHEN 'superadmin' THEN 'Executive'
        WHEN 'admin' THEN 'Administration'
        WHEN 'manager' THEN 'Management'
        WHEN 'maintenance' THEN 'Maintenance'
        WHEN 'techsupport' THEN 'IT Support'
        ELSE 'Operations'
      END,
      COALESCE(NEW.created_at, NOW()),
      true,
      jsonb_build_object(
        'role', NEW.role,
        'syncedFromProfile', true,
        'isSupervisor', NEW.role IN ('superadmin', 'admin', 'manager', 'supervisor'),
        'isManager', NEW.role IN ('superadmin', 'admin', 'manager')
      )
    )
    ON CONFLICT (org_id, user_id) DO UPDATE SET
      first_name = COALESCE(EXCLUDED.first_name, employees.first_name),
      last_name = COALESCE(EXCLUDED.last_name, employees.last_name),
      email = COALESCE(EXCLUDED.email, employees.email),
      updated_at = NOW();
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger on profiles table for INSERT and UPDATE
DROP TRIGGER IF EXISTS sync_profile_to_employee_trigger ON profiles;
CREATE TRIGGER sync_profile_to_employee_trigger
  AFTER INSERT OR UPDATE OF org_id, first_name, last_name, email, role
  ON profiles
  FOR EACH ROW
  EXECUTE FUNCTION sync_profile_to_employee();
