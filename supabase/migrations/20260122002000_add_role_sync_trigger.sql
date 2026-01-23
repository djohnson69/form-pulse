-- Migration: Add trigger to sync role changes across profiles, org_members, and employees
-- Handles:
-- 1. Syncing profiles.role -> org_members.role mapping
-- 2. Updating employees.metadata (isSupervisor, isManager) when role changes
-- 3. Creating employee for external->internal role change
-- 4. Deactivating employee for internal->external role change

CREATE OR REPLACE FUNCTION sync_role_changes()
RETURNS TRIGGER AS $$
DECLARE
  v_is_internal_old boolean;
  v_is_internal_new boolean;
BEGIN
  -- Determine if old and new roles are internal
  v_is_internal_old := OLD.role IN ('superadmin', 'admin', 'manager', 'supervisor', 'employee', 'maintenance', 'techsupport');
  v_is_internal_new := NEW.role IN ('superadmin', 'admin', 'manager', 'supervisor', 'employee', 'maintenance', 'techsupport');

  -- Update org_members role mapping
  UPDATE org_members
  SET role = CASE NEW.role
    WHEN 'superadmin' THEN 'owner'
    WHEN 'admin' THEN 'admin'
    ELSE 'member'
  END
  WHERE user_id = NEW.id AND org_id = NEW.org_id;

  -- Handle employee record based on role type transition
  IF v_is_internal_new THEN
    -- Internal role: upsert employee record
    INSERT INTO employees (
      org_id, user_id, first_name, last_name, email,
      position, department, hire_date, is_active, metadata
    )
    VALUES (
      NEW.org_id, NEW.id, NEW.first_name, NEW.last_name, NEW.email,
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
        'isSupervisor', NEW.role IN ('superadmin', 'admin', 'manager', 'supervisor'),
        'isManager', NEW.role IN ('superadmin', 'admin', 'manager'),
        'roleChangedAt', NOW(),
        'previousRole', OLD.role
      )
    )
    ON CONFLICT (org_id, user_id) DO UPDATE SET
      position = EXCLUDED.position,
      department = EXCLUDED.department,
      is_active = true,
      metadata = employees.metadata || jsonb_build_object(
        'role', NEW.role,
        'isSupervisor', NEW.role IN ('superadmin', 'admin', 'manager', 'supervisor'),
        'isManager', NEW.role IN ('superadmin', 'admin', 'manager'),
        'roleChangedAt', NOW(),
        'previousRole', OLD.role
      ),
      updated_at = NOW();
  ELSIF v_is_internal_old AND NOT v_is_internal_new THEN
    -- Transitioning from internal to external: deactivate employee record
    -- Don't delete - keep for historical records
    UPDATE employees
    SET is_active = false,
        metadata = metadata || jsonb_build_object(
          'deactivatedReason', 'role_changed_to_external',
          'deactivatedAt', NOW(),
          'previousRole', OLD.role,
          'newRole', NEW.role
        ),
        updated_at = NOW()
    WHERE org_id = NEW.org_id AND user_id = NEW.id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for role changes on profiles
DROP TRIGGER IF EXISTS sync_role_changes_trigger ON profiles;
CREATE TRIGGER sync_role_changes_trigger
  AFTER UPDATE OF role ON profiles
  FOR EACH ROW
  WHEN (OLD.role IS DISTINCT FROM NEW.role)
  EXECUTE FUNCTION sync_role_changes();
