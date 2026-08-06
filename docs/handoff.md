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

- **2026-08-06** — Repo created, docs written. No code. (Akash)
- **2026-08-06** — Rule added: every commit updates necessary md files (state/prd/design/plan/handoff/changelog). Fresh sessions reload everything from md. (Akash)
- **2026-08-06** — Google OAuth set up: Android client `com.kharcha.app` SHA1 `81:C9:...:44:AE`, Web client `kharcha-web` (ID `820021611320-...3sd`), Google provider enabled in Supabase. Pending: redirect URI `.../auth/v1/callback` in Web client's Authorized redirect URIs. Steps 1.1-1.3 done (scaffold, auth code, drift schema + seed + migration). Next: 2.1 manual entry. (Akash)
- **2026-08-06** — **Notification policy decision (owner + co-dev):** pushes are value-only, never random. Hard cap **5/day max**. Targeted, user-opted-in messages only (9PM daily summary, Sunday weekly, budget alerts). Rationale: random/marketing push to a finance app violates Play policy and gets notification permission revoked → kills UPI auto-capture. Recorded in `docs/design.md` Principles. (Akash)
- **2026-08-06** — **Nudge style refined (owner):** the "value-only" pushes are Swiggy/Zomato-style **rule-based behavioral nudges** — deterministic local rules, zero AI. e.g. "Aaj kharcha add nahi kiya, bhai" (no expense by 9PM), "Swiggy ka order? Category add karo" (uncategorized). Always capped 5/day, user-opted-in, never random. Recorded `docs/design.md` scope item 10. (Akash)
- **2026-08-06** — **Transactions editable + notes** (owner): every transaction can be edited (amount, merchant, category, note, date, payment method) and carries an optional free-text note ("what I bought"), incl. auto-captured spends. Recorded `docs/design.md` scope 7b. (Akash)
- **2026-08-06** — **Windows test blocker:** local `flutter test` on Windows crashes on sqlite3 native-assets (docs/troubleshooting.md). CI was briefly added then **removed** (free-tier Actions unreliable) — test gate = local `flutter analyze` + `flutter test`. Code for 2.1–2.3 merged to main, analyze clean. (Akash)
- **2026-08-06** — **Session close.** Phase 2 (2.1 manual entry, 2.2 categorization, 2.3 UPI capture) merged to main (`c4a5935`). Docs updated (state/design/handoff/troubleshooting/CLAUDE.md). Next: 2.3 on-device verify, then Phase 3 sync. CI removed — do not re-add unless Actions reliability is confirmed. (Akash)
