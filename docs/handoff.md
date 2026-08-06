# Kharcha — Handoff Notes

> For when one dev hands work to the other, or the AI agent switches context. Append, don't rewrite.

## How to pick up work

1. Read `CLAUDE.md` (rules), `docs/state.md` (where we are), `docs/implementation-plan.md` (what's next).
2. Pick the next unstarted step. Branch `feat/<name>`.
3. Build to CLAUDE.md standards. Verify: analyze + test + device smoke.
4. PR, get the other dev's review, merge.
5. Update `docs/state.md`.

## Current handoff (as of 2026-08-06)

**To: whoever starts Phase 1.** Scaffold the Flutter app. Everything in `docs/implementation-plan.md` Step 1.1. Decision needed: Flutter org/package name (`com.kharcha.app` suggested — confirm with owner before creating).

## Known gotchas

- Supabase + Google OAuth needs a Supabase project + OAuth client configured. Create in Supabase console before Step 1.2. Owner holds console access.
- NotificationListenerService is Kotlin — requires Android project edit + platform channel. Not pure Dart.
- minSdk 32 enforced — check emulator/device is Android 12+.
- Attribution disabled — do not add Co-Authored-By trailers to commits.

## Log

- **2026-08-06** — Repo created, docs written. No code. (Akash)
- **2026-08-06** — Rule added: every commit updates necessary md files (state/prd/design/plan/handoff/changelog). Fresh sessions reload everything from md. (Akash)
- **2026-08-06** — Google OAuth set up: Android client `com.kharcha.app` SHA1 `81:C9:...:44:AE`, Web client `kharcha-web` (ID `820021611320-...3sd`), Google provider enabled in Supabase. Pending: redirect URI `.../auth/v1/callback` in Web client's Authorized redirect URIs. Steps 1.1-1.3 done (scaffold, auth code, drift schema + seed + migration). Next: 2.1 manual entry. (Akash)
