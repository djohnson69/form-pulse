-- Fix infinite recursion in profiles RLS policy
-- The "Platform roles read org data" policy was incorrectly applied to the profiles table,
-- causing infinite recursion when checking if a user can read profiles.

-- Step 1: Drop the problematic recursive policy on profiles
drop policy if exists "Platform roles read org data" on profiles;

-- Step 2: Create a security definer function to get current user's role without RLS recursion
-- This MUST be created BEFORE the policy that uses it
create or replace function get_current_user_role()
returns table(role text)
language sql
security definer
set search_path = public
as $$
  select role from profiles where id = auth.uid();
$$;

-- Step 3: Ensure users can always read their own profile (no recursion)
drop policy if exists "Users read own profile" on profiles;
create policy "Users read own profile"
  on profiles for select
  using (id = auth.uid());

-- Step 4: Allow developer/techsupport to read ALL profiles
drop policy if exists "Platform roles read all profiles" on profiles;
create policy "Platform roles read all profiles"
  on profiles for select
  using (
    exists (
      select 1 from get_current_user_role() as r
      where r.role in ('developer', 'techsupport')
    )
  );
