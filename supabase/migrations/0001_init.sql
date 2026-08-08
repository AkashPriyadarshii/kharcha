-- Kharcha init: tables mirror Drift schema, all scoped by auth.uid().
-- Includes:
-- - idempotent drops/recreates
-- - updated_at trigger
-- - explicit role-scoped RLS policies for clarity

begin;

-- Existing tables upgraded to income support (idempotent).
alter table if exists public.transactions add column if not exists is_income boolean not null default false;
alter table if exists public.categories add column if not exists is_income boolean not null default false;

-- ----------------------------
-- Tables
-- ----------------------------

create table if not exists public.categories (
  id bigint generated always as identity primary key,
  name text not null,
  emoji text not null default '📦',
  color text not null default '#8D99AE',
  is_custom boolean not null default false,
  sort_order integer not null default 0,
  is_income boolean not null default false
);

create table if not exists public.merchants (
  id bigint generated always as identity primary key,
  name text not null,
  category_id bigint references public.categories(id) on delete set null,
  icon text
);

create table if not exists public.rules (
  id bigint generated always as identity primary key,
  pattern text not null,
  category_id bigint not null references public.categories(id) on delete cascade,
  type text not null default 'builtin'
);

create table if not exists public.transactions (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  amount double precision not null,
  merchant text not null,
  category_id bigint references public.categories(id) on delete set null,
  txn_date timestamptz not null default now(),
  note text,
  payment_method text not null default 'upi',
  upi_ref text,
  source text not null default 'manual',
  is_income boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, upi_ref)
);

create table if not exists public.budgets (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  category_id bigint references public.categories(id) on delete cascade,
  amount double precision not null,
  period text not null default 'monthly',
  alert_pct_50 integer not null default 50,
  alert_pct_80 integer not null default 80,
  alert_pct_100 integer not null default 100
);

-- ----------------------------
-- updated_at trigger
-- ----------------------------

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists trg_transactions_set_updated_at on public.transactions;
create trigger trg_transactions_set_updated_at
before update on public.transactions
for each row
execute function public.set_updated_at();

-- ----------------------------
-- RLS: enable
-- ----------------------------

alter table public.transactions enable row level security;
alter table public.budgets enable row level security;

alter table public.categories enable row level security;
alter table public.merchants enable row level security;
alter table public.rules enable row level security;

-- ----------------------------
-- RLS: policies (drop-first)
-- ----------------------------

drop policy if exists "users can manage own transactions" on public.transactions;
drop policy if exists "users can manage own budgets" on public.budgets;

create policy "users can manage own transactions"
on public.transactions
for all
to authenticated
using (
  (select auth.uid()) = user_id
)
with check (
  (select auth.uid()) = user_id
);

create policy "users can manage own budgets"
on public.budgets
for all
to authenticated
using (
  (select auth.uid()) = user_id
)
with check (
  (select auth.uid()) = user_id
);

-- Shared reference data: read-only for authenticated users
-- (If you want writes to admins only, tell me and I’ll add the INSERT/UPDATE/DELETE policies.)
drop policy if exists "categories are readable" on public.categories;
drop policy if exists "merchants are readable" on public.merchants;
drop policy if exists "rules are readable" on public.rules;

create policy "categories are readable"
on public.categories
for select
to authenticated
using (true);

create policy "merchants are readable"
on public.merchants
for select
to authenticated
using (true);

create policy "rules are readable"
on public.rules
for select
to authenticated
using (true);

-- Optional helpful indexes (won't hurt; keeps policy + common filters fast)
create index if not exists idx_transactions_user_id on public.transactions(user_id);
create index if not exists idx_transactions_txn_date on public.transactions(txn_date);
create index if not exists idx_budgets_user_id on public.budgets(user_id);
create index if not exists idx_merchants_category_id on public.merchants(category_id);
create index if not exists idx_rules_category_id on public.rules(category_id);
create index if not exists idx_transactions_category_id on public.transactions(category_id);

commit;
