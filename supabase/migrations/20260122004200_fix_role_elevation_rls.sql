-- Migration: Prevent role self-elevation via RLS
-- Users should not be able to update their own role field directly
-- Only platform roles (developer) or org admins (via Edge Functions) can change roles

-- Helper function to check if the caller is a platform role
CREATE OR REPLACE FUNCTION is_platform_role()
RETURNS boolean AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid()
    AND role IN ('developer', 'techsupport')
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

-- Helper function to check if caller is an org admin for a given user
CREATE OR REPLACE FUNCTION is_org_admin_for_user(target_user_id uuid)
RETURNS boolean AS $$
DECLARE
  v_caller_org_id uuid;
  v_target_org_id uuid;
  v_caller_role text;
BEGIN
  -- Get caller's org membership
  SELECT org_id, role INTO v_caller_org_id, v_caller_role
  FROM org_members
  WHERE user_id = auth.uid();

  -- Get target user's org
  SELECT org_id INTO v_target_org_id
  FROM profiles
  WHERE id = target_user_id;

  -- Must be in same org and be owner/admin
  RETURN v_caller_org_id IS NOT NULL
    AND v_caller_org_id = v_target_org_id
    AND v_caller_role IN ('owner', 'admin');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

-- Drop existing update policy if it exists
DROP POLICY IF EXISTS "Users can update own profile" ON profiles;
DROP POLICY IF EXISTS "profiles_update_own" ON profiles;
DROP POLICY IF EXISTS "profiles_update_own_except_role" ON profiles;

-- New policy: Users can update their own profile EXCEPT the role field
-- Role changes must go through Edge Functions which use service_role
CREATE POLICY "profiles_update_own_except_role" ON profiles
FOR UPDATE
USING (auth.uid() = id)
WITH CHECK (
  auth.uid() = id
  AND (
    -- Role is unchanged (most common case)
    role IS NOT DISTINCT FROM (SELECT role FROM profiles WHERE id = auth.uid())
    -- OR caller is a platform admin (can change any role)
    OR is_platform_role()
    -- OR caller is an org admin for this user (admin panel role changes)
    OR is_org_admin_for_user(id)
  )
);

-- Ensure platform roles can update any profile (for admin operations)
DROP POLICY IF EXISTS "Platform roles can update any profile" ON profiles;
CREATE POLICY "Platform roles can update any profile" ON profiles
FOR UPDATE
USING (is_platform_role())
WITH CHECK (is_platform_role());

-- Ensure org admins can update profiles in their org
DROP POLICY IF EXISTS "Org admins can update org profiles" ON profiles;
CREATE POLICY "Org admins can update org profiles" ON profiles
FOR UPDATE
USING (is_org_admin_for_user(id))
WITH CHECK (is_org_admin_for_user(id));

-- Also protect org_members.role from self-elevation
DROP POLICY IF EXISTS "org_members_update_own" ON org_members;
DROP POLICY IF EXISTS "org_members_no_self_elevation" ON org_members;

-- Users cannot change their own org_members.role
CREATE POLICY "org_members_no_self_elevation" ON org_members
FOR UPDATE
USING (
  -- Can update if not the same user (admin updating another user)
  user_id != auth.uid()
  -- OR if role is unchanged
  OR role IS NOT DISTINCT FROM (SELECT role FROM org_members WHERE user_id = auth.uid() AND org_id = org_members.org_id)
  -- OR caller is platform role
  OR is_platform_role()
)
WITH CHECK (
  user_id != auth.uid()
  OR role IS NOT DISTINCT FROM (SELECT role FROM org_members WHERE user_id = auth.uid() AND org_id = org_members.org_id)
  OR is_platform_role()
);

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION is_platform_role() TO authenticated;
GRANT EXECUTE ON FUNCTION is_org_admin_for_user(uuid) TO authenticated;
