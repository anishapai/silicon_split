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
  category text not null default 'Other' check (category in (
    'Rent', 'Utilities', 'Groceries', 'Dining', 'Transport',
    'Household', 'Entertainment', 'Other'
  )),
  created_at timestamptz not null default now()
);

-- If you already ran this file once before adding categories, run this
-- instead of the create table above (adding a column doesn't require
-- dropping existing data):
--
-- alter table expenses add column if not exists category text not null
--   default 'Other' check (category in (
--     'Rent', 'Utilities', 'Groceries', 'Dining', 'Transport',
--     'Household', 'Entertainment', 'Other'
--   ));

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

-- allowed_members: users need to be able to check their OWN row (not browse
-- the whole table) — without this, the policies above fail with
-- "permission denied for table allowed_members".
grant select on allowed_members to authenticated;

create policy "read own membership row" on allowed_members
  for select using (email = auth.jwt() ->> 'email');

-- 5. Table-level grants. RLS policies only narrow access — they don't grant
--    it in the first place. Without these, every query fails with
--    "permission denied for table X", even if the RLS policy would allow it.
grant select, update on settings to authenticated;
grant select, insert, delete on expenses to authenticated;
