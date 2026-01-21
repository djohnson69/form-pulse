do $$
declare
  tbl text;
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'orgs'
      and policyname = 'Platform roles read orgs'
  ) then
    create policy "Platform roles read orgs"
      on orgs for select
      using (exists (
        select 1
        from profiles p
        where p.id = auth.uid()
          and replace(replace(lower(coalesce(p.role, '')), '_', ''), '-', '')
              in ('developer', 'techsupport')
      ));
  end if;

  for tbl in
    select c.table_name
    from information_schema.columns c
    where c.table_schema = 'public'
      and c.column_name = 'org_id'
  loop
    if not exists (
      select 1
      from pg_policies
      where schemaname = 'public'
        and tablename = tbl
        and policyname = 'Platform roles read org data'
    ) then
      execute format(
        'create policy "Platform roles read org data" on %I for select using (exists (select 1 from profiles p where p.id = auth.uid() and replace(replace(lower(coalesce(p.role, '''')), ''_'', ''''), ''-'', '''') in (''developer'', ''techsupport'')))',
        tbl
      );
    end if;
  end loop;
end $$;
