-- Messaging enhancements: participants settings, reactions, deletions, message edits, notifications metadata

alter table message_participants
  add column if not exists last_read_at timestamptz,
  add column if not exists last_delivered_at timestamptz,
  add column if not exists notification_level text not null default 'all',
  add column if not exists mute_until timestamptz,
  add column if not exists is_archived boolean not null default false,
  add column if not exists is_active boolean not null default true,
  add column if not exists left_at timestamptz;

alter table profiles
  add column if not exists last_seen_at timestamptz;

alter table messages
  add column if not exists updated_at timestamptz not null default now(),
  add column if not exists edited_at timestamptz,
  add column if not exists deleted_at timestamptz,
  add column if not exists deleted_by uuid references auth.users(id),
  add column if not exists reply_to_message_id uuid references messages(id) on delete set null;

create table if not exists message_reactions (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references orgs(id) on delete cascade,
  thread_id uuid not null references message_threads(id) on delete cascade,
  message_id uuid not null references messages(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  emoji text not null,
  created_at timestamptz not null default now()
);

create table if not exists message_deletions (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references orgs(id) on delete cascade,
  thread_id uuid not null references message_threads(id) on delete cascade,
  message_id uuid not null references messages(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  deleted_at timestamptz not null default now()
);

create table if not exists message_typing (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references orgs(id) on delete cascade,
  thread_id uuid not null references message_threads(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  is_typing boolean not null default false,
  updated_at timestamptz not null default now(),
  unique (thread_id, user_id)
);

alter table notifications
  add column if not exists target_role text,
  add column if not exists data jsonb not null default '{}'::jsonb,
  add column if not exists metadata jsonb not null default '{}'::jsonb,
  add column if not exists action_url text,
  add column if not exists updated_at timestamptz not null default now();

create unique index if not exists idx_message_reactions_unique
  on message_reactions(message_id, user_id, emoji);
create index if not exists idx_message_reactions_thread
  on message_reactions(thread_id);
create index if not exists idx_message_reactions_user
  on message_reactions(user_id);

create unique index if not exists idx_message_deletions_unique
  on message_deletions(message_id, user_id);
create index if not exists idx_message_deletions_thread
  on message_deletions(thread_id);
create index if not exists idx_message_deletions_user
  on message_deletions(user_id);

create index if not exists idx_message_participants_thread
  on message_participants(thread_id);
create index if not exists idx_message_participants_user
  on message_participants(user_id);

create index if not exists idx_message_typing_thread
  on message_typing(thread_id);
create index if not exists idx_message_typing_user
  on message_typing(user_id);

alter table message_reactions enable row level security;
alter table message_deletions enable row level security;
alter table message_typing enable row level security;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE policyname = 'Org members update messages'
  ) THEN
    CREATE POLICY "Org members update messages"
      ON messages FOR UPDATE
      USING (
        EXISTS (
          SELECT 1 FROM org_members m
          WHERE m.org_id = messages.org_id AND m.user_id = auth.uid()
        )
      );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE policyname = 'Org members delete messages'
  ) THEN
    CREATE POLICY "Org members delete messages"
      ON messages FOR DELETE
      USING (
        EXISTS (
          SELECT 1 FROM org_members m
          WHERE m.org_id = messages.org_id AND m.user_id = auth.uid()
        )
      );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE policyname = 'Org members read message reactions'
  ) THEN
    CREATE POLICY "Org members read message reactions"
      ON message_reactions FOR SELECT
      USING (
        EXISTS (
          SELECT 1 FROM org_members m
          WHERE m.org_id = message_reactions.org_id AND m.user_id = auth.uid()
        )
      );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE policyname = 'Org members manage message reactions'
  ) THEN
    CREATE POLICY "Org members manage message reactions"
      ON message_reactions FOR ALL
      USING (
        EXISTS (
          SELECT 1 FROM org_members m
          WHERE m.org_id = message_reactions.org_id AND m.user_id = auth.uid()
        )
      );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE policyname = 'Org members read message deletions'
  ) THEN
    CREATE POLICY "Org members read message deletions"
      ON message_deletions FOR SELECT
      USING (
        EXISTS (
          SELECT 1 FROM org_members m
          WHERE m.org_id = message_deletions.org_id AND m.user_id = auth.uid()
        )
      );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE policyname = 'Org members manage message deletions'
  ) THEN
    CREATE POLICY "Org members manage message deletions"
      ON message_deletions FOR ALL
      USING (
        EXISTS (
          SELECT 1 FROM org_members m
          WHERE m.org_id = message_deletions.org_id AND m.user_id = auth.uid()
        )
      );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE policyname = 'Org members read message typing'
  ) THEN
    CREATE POLICY "Org members read message typing"
      ON message_typing FOR SELECT
      USING (
        EXISTS (
          SELECT 1 FROM org_members m
          WHERE m.org_id = message_typing.org_id AND m.user_id = auth.uid()
        )
      );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE policyname = 'Org members manage message typing'
  ) THEN
    CREATE POLICY "Org members manage message typing"
      ON message_typing FOR ALL
      USING (
        EXISTS (
          SELECT 1 FROM org_members m
          WHERE m.org_id = message_typing.org_id AND m.user_id = auth.uid()
        )
      );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE policyname = 'Org members insert notifications'
  ) THEN
    CREATE POLICY "Org members insert notifications"
      ON notifications FOR INSERT
      WITH CHECK (
        EXISTS (
          SELECT 1 FROM org_members m
          WHERE m.org_id = notifications.org_id AND m.user_id = auth.uid()
        )
      );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE policyname = 'Org members delete notifications'
  ) THEN
    CREATE POLICY "Org members delete notifications"
      ON notifications FOR DELETE
      USING (
        EXISTS (
          SELECT 1 FROM org_members m
          WHERE m.org_id = notifications.org_id AND m.user_id = auth.uid()
        )
      );
  END IF;
END $$;
