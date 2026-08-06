-- Kharcha init: tables mirror Drift schema, all scoped by auth.uid().

create table if not exists public.categories (
  id bigint generated always as identity primary key,
  name text not null,
  emoji text not null default '📦',
  color text not null default '#8D99AE',
  is_custom boolean not null default false,
  sort_order integer not null default 0
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

-- RLS: every table scoped to auth.uid()
alter table public.transactions enable row level security;
alter table public.budgets enable row level security;

create policy "users can manage own transactions" on public.transactions
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "users can manage own budgets" on public.budgets
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- Reference data (categories/merchants/rules) is shared read, no user scope.
alter table public.categories enable row level security;
alter table public.merchants enable row level security;
alter table public.rules enable row level security;

create policy "categories are readable" on public.categories for select using (true);
create policy "merchants are readable" on public.merchants for select using (true);
create policy "rules are readable" on public.rules for select using (true);
