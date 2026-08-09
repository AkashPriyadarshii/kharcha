-- Kharcha v0.2.6: in-app bug reporting. Signed-in users can file a report
-- from Settings → Report a bug; it lands here and the owner reads it in the
-- dashboard Table Editor. No GitHub account needed, no email infra.

begin;

create table if not exists public.bug_reports (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  message text not null check (char_length(message) <= 2000),
  app_version text,
  os text,
  created_at timestamptz not null default now()
);

-- Fast sort in the dashboard; user_id so we can reach the reporter.
create index if not exists bug_reports_created_idx
  on public.bug_reports (created_at desc);

alter table public.bug_reports enable row level security;

-- Authenticated insert only. user_id is taken from the JWT, so a reporter
-- can't file on someone else's behalf. No select policy — the owner reads
-- via the dashboard (service-role), users never read each other's reports.
drop policy if exists "users can report bugs" on public.bug_reports;
create policy "users can report bugs"
on public.bug_reports
for insert
to authenticated
with check ((select auth.uid()) = user_id);

commit;
