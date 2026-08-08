-- Kharcha v0.2.1: backup for feature tables (budgets was already there, now
-- user-scoped + synced; wallets, recurring_transactions, objectives, debts
-- added). All scoped by auth.uid(), RLS for authenticated users.

begin;

-- budgets: add updated_at for LWW sync (idempotent).
alter table if exists public.budgets add column if not exists updated_at timestamptz not null default now();

-- ----------------------------
-- Tables
-- ----------------------------

create table if not exists public.wallets (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  currency text not null default 'INR',
  initial_balance double precision not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists public.recurring_transactions (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  merchant text not null,
  amount double precision not null,
  category_id bigint references public.categories(id) on delete set null,
  period text not null default 'monthly',
  next_due timestamptz not null,
  active boolean not null default true
);

create table if not exists public.objectives (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  target double precision not null,
  saved double precision not null default 0,
  deadline timestamptz
);

create table if not exists public.debts (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  amount double precision not null,
  is_lent boolean not null default false,
  note text,
  settled boolean not null default false,
  created_at timestamptz not null default now()
);

-- ----------------------------
-- updated_at trigger for budgets (LWW clock)
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

drop trigger if exists trg_budgets_set_updated_at on public.budgets;
create trigger trg_budgets_set_updated_at
before update on public.budgets
for each row
execute function public.set_updated_at();

-- ----------------------------
-- RLS: enable
-- ----------------------------

alter table public.wallets enable row level security;
alter table public.recurring_transactions enable row level security;
alter table public.objectives enable row level security;
alter table public.debts enable row level security;

-- ----------------------------
-- RLS: policies (drop-first)
-- ----------------------------

drop policy if exists "users can manage own wallets" on public.wallets;
create policy "users can manage own wallets"
on public.wallets
for all
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

drop policy if exists "users can manage own recurring" on public.recurring_transactions;
create policy "users can manage own recurring"
on public.recurring_transactions
for all
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

drop policy if exists "users can manage own objectives" on public.objectives;
create policy "users can manage own objectives"
on public.objectives
for all
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

drop policy if exists "users can manage own debts" on public.debts;
create policy "users can manage own debts"
on public.debts
for all
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

drop policy if exists "users can manage own budgets" on public.budgets;
create policy "users can manage own budgets"
on public.budgets
for all
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

-- ----------------------------
-- Indexes
-- ----------------------------

create index if not exists idx_budgets_user_id on public.budgets(user_id);
create index if not exists idx_budgets_category_id on public.budgets(category_id);
create index if not exists idx_wallets_user_id on public.wallets(user_id);
create index if not exists idx_recurring_user_id on public.recurring_transactions(user_id);
create index if not exists idx_objectives_user_id on public.objectives(user_id);
create index if not exists idx_debts_user_id on public.debts(user_id);

commit;
