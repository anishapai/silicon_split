-- Run this once in Supabase: Dashboard → SQL Editor → New query → paste → Run

-- 1. Who's allowed in. Edit these two emails before running,
--    or add them later from the Table Editor.
create table if not exists allowed_members (
  email text primary key
);

insert into allowed_members (email) values
  ('you@example.com'),
  ('housemate@example.com')
on conflict do nothing;

-- 2. Shared settings (names + default split). Always exactly one row.
create table if not exists settings (
  id int primary key default 1,
  name_a text not null default 'Person A',
  name_b text not null default 'Person B',
  split_a int not null default 60,
  constraint singleton check (id = 1)
);

insert into settings (id) values (1) on conflict do nothing;

-- 3. Expenses
create table if not exists expenses (
  id uuid primary key default gen_random_uuid(),
  description text not null,
  amount numeric not null check (amount > 0),
  paid_by text not null check (paid_by in ('A', 'B')),
  split_a int not null check (split_a between 0 and 100),
  created_at timestamptz not null default now()
);

-- 4. Lock everything down: only the two allowed emails can read or write.
alter table allowed_members enable row level security;
alter table settings enable row level security;
alter table expenses enable row level security;

create policy "members only - settings select" on settings
  for select using (
    exists (select 1 from allowed_members where email = auth.jwt() ->> 'email')
  );

create policy "members only - settings update" on settings
  for update using (
    exists (select 1 from allowed_members where email = auth.jwt() ->> 'email')
  );

create policy "members only - expenses all" on expenses
  for all using (
    exists (select 1 from allowed_members where email = auth.jwt() ->> 'email')
  ) with check (
    exists (select 1 from allowed_members where email = auth.jwt() ->> 'email')
  );

-- allowed_members itself: no client access needed, so no select policy —
-- it's only ever read by the policies above (which run as the database, not the client).
