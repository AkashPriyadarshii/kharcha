-- Kharcha v0.2.1: custom-category sync. Custom categories are now per-user
-- rows on the server (user_id set); builtins stay shared reference data
-- (user_id null, seeded by 0003 with ids 1-14). Budgets/recurring reference
-- the server category id, so the app must push categories before features and
-- pull them after — both done on the client.

begin;

-- Per-user owner column. Null = shared builtin (seed rows).
alter table public.categories add column if not exists user_id uuid references auth.users(id) on delete cascade;

-- Bump the identity sequence past the seeded ids (1-14) so PostgREST inserts
-- of custom categories never collide with a builtin id.
select setval(pg_get_serial_sequence('public.categories', 'id'), greatest((select coalesce(max(id), 14) from public.categories), 14), true);

-- Dedupe: one custom category per name per user (23505 recovery in the engine).
create unique index if not exists categories_user_name_uniq
  on public.categories (user_id, name)
  where user_id is not null;

-- ----------------------------
-- RLS
-- ----------------------------

alter table public.categories enable row level security;

-- Existing read-all policy covers builtins + own customs.
-- (recreated here idempotently so this file can run standalone)
drop policy if exists "categories are readable" on public.categories;
create policy "categories are readable"
on public.categories
for select
to authenticated
using (true);

-- Users manage their own custom categories (builtins have user_id null → no
-- policy matches → untouched).
drop policy if exists "users can insert own categories" on public.categories;
create policy "users can insert own categories"
on public.categories
for insert
to authenticated
with check ((select auth.uid()) = user_id);

drop policy if exists "users can update own categories" on public.categories;
create policy "users can update own categories"
on public.categories
for update
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

drop policy if exists "users can delete own categories" on public.categories;
create policy "users can delete own categories"
on public.categories
for delete
to authenticated
using ((select auth.uid()) = user_id);

commit;
