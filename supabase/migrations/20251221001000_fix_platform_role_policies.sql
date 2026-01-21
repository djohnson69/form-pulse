create or replace function public.is_platform_role()
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists (
    select 1
    from profiles p
    where p.id = auth.uid()
      and replace(replace(lower(coalesce(p.role, '')), '_', ''), '-', '')
          in ('developer', 'techsupport')
  );
$$;

grant execute on function public.is_platform_role() to authenticated, anon;

do $$
declare
  tbl text;
begin
  if exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'orgs'
      and policyname = 'Platform roles read orgs'
  ) then
    execute 'alter policy "Platform roles read orgs" on orgs using (public.is_platform_role())';
  end if;

  for tbl in
    select tablename
    from pg_policies
    where schemaname = 'public'
      and policyname = 'Platform roles read org data'
  loop
    execute format(
      'alter policy "Platform roles read org data" on %I using (public.is_platform_role())',
      tbl
    );
  end loop;
end $$;
