# Kharcha — Project State

> Update after every merged PR. This is the single source of truth for where the project stands.

## Current status

**Phase: Phase 1 done, Phase 2 started.** 2.1 (manual entry) code merged. Test files written; `flutter test` blocked on Windows host by a Flutter tool bug (see `docs/troubleshooting.md`). Next: 2.2 rule-based categorization.

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

- [x] **Step 2.1** Manual entry + quick-add: full form (amount, merchant, category, note, payment method, date), quick-add dialog, transactions list + FAB, go_router wired. Tests written. `flutter analyze` clean. Test run blocked on Windows by tool bug (docs/troubleshooting.md #1).

## In progress

- **Step 2.2** Rule-based categorization + merchant normalization

## Next up

1. Step 2.2: `Categorizer` service — merchant string → normalize → rule match → category; learned rules override builtin
2. Step 2.3: NotificationListenerService (Kotlin capture)
