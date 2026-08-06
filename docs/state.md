# Kharcha — Project State

> Update after every merged PR. This is the single source of truth for where the project stands.

## Current status

**Phase: Phase 2 almost done.** 2.1 manual entry + 2.2 categorization + 2.3 notification capture code merged. `flutter analyze` clean; `flutter test` gated by CI (Linux) — blocked on Windows host by Flutter tool bug (see `docs/troubleshooting.md`). Next: 2.3 verify on device, then Phase 3 sync.

## Completed

- [x] Repo `AkashPriyadarshii/kharcha` (private, collaborators: priyaranjan122002)
- [x] Design approved (`docs/design.md`)
- [x] PRD (`docs/prd.md`)
- [x] Implementation plan (`docs/implementation-plan.md`)
- [x] Team docs: contributors, state, handoff, changelog, ponytail, agents.md
- [x] CLAUDE.md (contract + anti-slop + ponytail required)
- [x] **Step 1.1** Flutter scaffold: `com.kharcha.app`, minSdk 32, deps installed, analyze clean
- [x] **Step 1.2** Google sign-in via Supabase Auth: auth flow, session persistence, Auth/Home switch on session
- [x] **Step 1.3** Drift local schema: transactions, categories, merchants, rules, budgets; onCreate seed (10 categories + ~40 builtin merchant rules); `supabase/migrations` schema mirror

## Completed

- [x] **Step 2.1** Manual entry + quick-add: full form (amount, merchant, category, note, payment method, date), quick-add dialog, transactions list + FAB, go_router wired.
- [x] **Step 2.2** Rule-based categorization: `Categorizer` (normalize + fuzzy word-boundary match, learned > builtin), auto-categorize on insert. Pure Dart, tested.
- [x] **Step 2.3** Notification capture: Kotlin `UpiNotificationListener` → JSONL inbox, Dart parser + dedupe by upi_ref, drain on startup, disclosure screen. Tests written.
- [x] Notification policy + edit/notes scope recorded in design.md.

## In progress

- **Step 2.3** on-device verify (adb fake UPI notification → auto-add once; dup not re-added)

## Next up

1. Step 3.1: Supabase sync (dirty-row queue, background upsert, pull on login, LWW by updated_at)
2. Step 3.2: 9PM daily + Sunday weekly Hinglish notifications
