do $$
begin
  if not exists (select 1 from pg_policies where policyname = 'Org admins manage profiles') then
    create policy "Org admins manage profiles"
      on profiles for update
      using (exists (
        select 1 from org_members m
        where m.org_id = profiles.org_id
          and m.user_id = auth.uid()
          and m.role in ('owner', 'admin')
      ))
      with check (exists (
        select 1 from org_members m
        where m.org_id = profiles.org_id
          and m.user_id = auth.uid()
          and m.role in ('owner', 'admin')
      ));
  end if;
end $$;
