# Kharcha — Handoff Notes

> For when one dev hands work to the other, or the AI agent switches context. Append, don't rewrite.

## How to pick up work

1. Read `CLAUDE.md` (rules), `docs/state.md` (where we are), `docs/implementation-plan.md` (what's next).
2. Pick the next unstarted step. Branch `feat/<name>`.
3. Build to CLAUDE.md standards. Verify: analyze + test + device smoke.
4. PR, get the other dev's review, merge.
5. Update `docs/state.md`.

## Current handoff (as of 2026-08-06)

**To: whoever picks up next.** Phase 2 (core capture) code is done — manual entry (2.1), categorization (2.2), notification capture (2.3). `flutter analyze` clean on main branch `feat/manual-entry`. Test gate = GitHub Actions CI (Linux). Next: verify 2.3 on-device, then Phase 3 (Supabase sync + notifications). See `docs/state.md`.

## Known gotchas

- Supabase + Google OAuth needs a Supabase project + OAuth client configured. Create in Supabase console before Step 1.2. Owner holds console access.
- NotificationListenerService is Kotlin — requires Android project edit + platform channel. Not pure Dart.
- minSdk 32 enforced — check emulator/device is Android 12+.
- Attribution disabled — do not add Co-Authored-By trailers to commits.

## Log

- **2026-08-07** — **Phase 4 core + Phase 5 code (feat/phase4).** Tabbed shell (Home/Transactions/Budget). 4.1 Home dashboard (today/month/budget-left + by-category bars). 4.4 Budget tab (monthly limits, 50/80/100 alerts, add/edit/delete; local-only writes, not synced — pending Supabase budgets schema). 5.1 Export CSV/JSON. 5.2 AppLock (local_auth wrapper; toggle deferred to 4.5 Profile). Tests: budget + export. **Deferred:** 4.2 search/filter, 4.3 Reports, 4.5 Profile, on-device verify, 5.3 Play assets, 5.4/5.5 release. Analyze clean.
- **2026-08-07** — **Step 3.1 + 3.2 merged (feat/supabase-sync).** Sync: dirty/remoteId on transactions (schema v2), SyncEngine push/pull, LWW by updated_at, 23505 conflict recovery, triggers on auth login + inbox drain + manual adds. Notifications: 9PM daily + Sunday weekly Hinglish summaries, channel + permission + device tz, re-scheduled each app open. **Known simplification:** summary push body is as-of-last-app-open, not fire-time — a background fill needs a foreground service/headless task (add when 9PM accuracy matters, `ponytail:` noted in `lib/data/notifications.dart`). `flutter analyze` clean; sync + notification tests pass; full `flutter test` still blocked on Windows host (sqlite3 native-assets, `docs/troubleshooting.md`). Next: on-device verify (2.3 + 3.1), then Phase 4. (Akash)
- **2026-08-06** — Repo created, docs written. No code. (Akash)
- **2026-08-06** — Rule added: every commit updates necessary md files (state/prd/design/plan/handoff/changelog). Fresh sessions reload everything from md. (Akash)
- **2026-08-06** — Google OAuth set up: Android client `com.kharcha.app` SHA1 `81:C9:...:44:AE`, Web client `kharcha-web` (ID `820021611320-...3sd`), Google provider enabled in Supabase. Pending: redirect URI `.../auth/v1/callback` in Web client's Authorized redirect URIs. Steps 1.1-1.3 done (scaffold, auth code, drift schema + seed + migration). Next: 2.1 manual entry. (Akash)
- **2026-08-06** — **Notification policy decision (owner + co-dev):** pushes are value-only, never random. Hard cap **5/day max**. Targeted, user-opted-in messages only (9PM daily summary, Sunday weekly, budget alerts). Rationale: random/marketing push to a finance app violates Play policy and gets notification permission revoked → kills UPI auto-capture. Recorded in `docs/design.md` Principles. (Akash)
- **2026-08-06** — **Nudge style refined (owner):** the "value-only" pushes are Swiggy/Zomato-style **rule-based behavioral nudges** — deterministic local rules, zero AI. e.g. "Aaj kharcha add nahi kiya, bhai" (no expense by 9PM), "Swiggy ka order? Category add karo" (uncategorized). Always capped 5/day, user-opted-in, never random. Recorded `docs/design.md` scope item 10. (Akash)
- **2026-08-06** — **Transactions editable + notes** (owner): every transaction can be edited (amount, merchant, category, note, date, payment method) and carries an optional free-text note ("what I bought"), incl. auto-captured spends. Recorded `docs/design.md` scope 7b. (Akash)
- **2026-08-06** — **Windows test blocker:** local `flutter test` on Windows crashes on sqlite3 native-assets (docs/troubleshooting.md). CI was briefly added then **removed** (free-tier Actions unreliable) — test gate = local `flutter analyze` + `flutter test`. Code for 2.1–2.3 merged to main, analyze clean. (Akash)
- **2026-08-06** — **Session close.** Phase 2 (2.1 manual entry, 2.2 categorization, 2.3 UPI capture) merged to main (`c4a5935`). Docs updated (state/design/handoff/troubleshooting/CLAUDE.md). Next: 2.3 on-device verify, then Phase 3 sync. CI removed — do not re-add unless Actions reliability is confirmed. (Akash)
