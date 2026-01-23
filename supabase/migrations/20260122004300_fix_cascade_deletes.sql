-- Migration: Fix cascade deletes for referential integrity
-- Ensures orphaned records are properly cleaned up when parent records are deleted

-- Check if active_sessions table exists before altering
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'active_sessions') THEN
    -- Drop existing constraint if it exists
    ALTER TABLE active_sessions
      DROP CONSTRAINT IF EXISTS active_sessions_org_id_fkey;

    -- Add cascade delete constraint
    ALTER TABLE active_sessions
      ADD CONSTRAINT active_sessions_org_id_fkey
        FOREIGN KEY (org_id) REFERENCES orgs(id) ON DELETE CASCADE;
  END IF;
END $$;

-- Fix subscriptions cascade on plan deletion (SET NULL instead of restrict)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'subscriptions') THEN
    ALTER TABLE subscriptions
      DROP CONSTRAINT IF EXISTS subscriptions_plan_id_fkey;

    -- When a plan is deleted, set plan_id to NULL (preserve subscription record)
    ALTER TABLE subscriptions
      ADD CONSTRAINT subscriptions_plan_id_fkey
        FOREIGN KEY (plan_id) REFERENCES subscription_plans(id) ON DELETE SET NULL;
  END IF;
END $$;

-- Fix billing_info cascade on org deletion
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'billing_info') THEN
    ALTER TABLE billing_info
      DROP CONSTRAINT IF EXISTS billing_info_org_id_fkey;

    ALTER TABLE billing_info
      ADD CONSTRAINT billing_info_org_id_fkey
        FOREIGN KEY (org_id) REFERENCES orgs(id) ON DELETE CASCADE;
  END IF;
END $$;

-- Fix user_invitations cascade on org deletion
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'user_invitations') THEN
    ALTER TABLE user_invitations
      DROP CONSTRAINT IF EXISTS user_invitations_org_id_fkey;

    ALTER TABLE user_invitations
      ADD CONSTRAINT user_invitations_org_id_fkey
        FOREIGN KEY (org_id) REFERENCES orgs(id) ON DELETE CASCADE;
  END IF;
END $$;

-- Fix employees cascade on org deletion
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'employees') THEN
    ALTER TABLE employees
      DROP CONSTRAINT IF EXISTS employees_org_id_fkey;

    ALTER TABLE employees
      ADD CONSTRAINT employees_org_id_fkey
        FOREIGN KEY (org_id) REFERENCES orgs(id) ON DELETE CASCADE;
  END IF;
END $$;

-- Fix forms cascade on org deletion
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'forms') THEN
    ALTER TABLE forms
      DROP CONSTRAINT IF EXISTS forms_org_id_fkey;

    ALTER TABLE forms
      ADD CONSTRAINT forms_org_id_fkey
        FOREIGN KEY (org_id) REFERENCES orgs(id) ON DELETE CASCADE;
  END IF;
END $$;

-- Fix submissions cascade on org deletion
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'submissions') THEN
    ALTER TABLE submissions
      DROP CONSTRAINT IF EXISTS submissions_org_id_fkey;

    ALTER TABLE submissions
      ADD CONSTRAINT submissions_org_id_fkey
        FOREIGN KEY (org_id) REFERENCES orgs(id) ON DELETE CASCADE;
  END IF;
END $$;

-- Fix projects cascade on org deletion
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'projects') THEN
    ALTER TABLE projects
      DROP CONSTRAINT IF EXISTS projects_org_id_fkey;

    ALTER TABLE projects
      ADD CONSTRAINT projects_org_id_fkey
        FOREIGN KEY (org_id) REFERENCES orgs(id) ON DELETE CASCADE;
  END IF;
END $$;

-- Fix teams cascade on org deletion
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'teams') THEN
    ALTER TABLE teams
      DROP CONSTRAINT IF EXISTS teams_org_id_fkey;

    ALTER TABLE teams
      ADD CONSTRAINT teams_org_id_fkey
        FOREIGN KEY (org_id) REFERENCES orgs(id) ON DELETE CASCADE;
  END IF;
END $$;

-- Note: profiles and org_members intentionally do NOT cascade delete
-- When an org is deleted (soft delete), we want to preserve user records
-- Users may be re-activated or moved to another org
