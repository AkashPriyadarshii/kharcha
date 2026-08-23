# Kharcha — CLAUDE.md

> This file is context for every AI agent and every human dev working on this repo.
> It OVERRIDES default agent behavior. Read it before touching code.
>
> **Required method: the ponytail method.** Read `docs/ponytail.md` and follow it for every change — shortest path to done, smallest diff, no unrequested abstractions, stdlib/native/existing-dep first, deletion over addition, boring over clever, `ponytail:` comments on real shortcuts, code-first output. This is not optional.
>
> For non-Claude AI agents (Cursor/Copilot/Cline/Codex/etc.), read `agents.md` — the same contract, adapted.

## CodeGraph — use it first

This repo is indexed by CodeGraph (`.codegraph/` exists). **Before grep/find or reading files to locate code, use CodeGraph:**

- Shell: `codegraph explore "<symbol names or question>"` and `codegraph node <symbol-or-file>` print symbol source + callers.
- MCP tools (when available): `codegraph_explore`, `codegraph_node`.
- No `.codegraph/` → skip it; indexing is the owner's decision, don't run it yourself.

## What this is

Kharcha — India-first UPI expense tracker. Flutter app for Android 12+.
Every UPI payment auto-appears as an expense via notification capture. No manual entry needed. Offline-first, privacy-first, **rule-based automation, zero AI**.

## Team

- **Akash** (`AkashPriyadarshii`) — owner. Sole developer. Final call on scope, architecture, merges.

Work through branches + PRs. No pushes to `main` directly.

## Stack (pinned — do not change without approval)

| Concern | Choice |
|---|---|
| Framework | Flutter, Android minSdk 32 (Android 12+) |
| UI | Material 3 |
| State | Riverpod |
| Navigation | go_router |
| Local DB | Drift (SQLite) — source of truth, offline-first |
| Backend | Supabase — Google Auth + Postgres + background sync |
| Charts | fl_chart |
| Local notifications | flutter_local_notifications |
| App lock | local_auth |
| Capture | `NotificationListenerService` (Kotlin) |
| Export | CSV/JSON |

## Architecture

```
Flutter app
│
├── UI (Material 3, Riverpod, go_router)
├── Domain (transactions, categories, budgets, merchant rules)
├── Data
│   ├── Drift SQLite   ← source of truth (offline-first)
│   └── Supabase       ← Google auth + Postgres + sync
├── Capture
│   ├── NotificationListenerService → parse → dedupe → insert
│   └── Manual entry (fallback)
└── flutter_local_notifications (9PM daily, Sunday weekly)
```

**Source of truth is Drift local.** Supabase is a sync target. App must work with zero network.

## Run / verify

```bash
flutter pub get
flutter analyze        # MUST pass before any PR
flutter test           # MUST pass before any PR
flutter build apk      # sanity check before merge to main
```

**CI:** none (removed 2026-08-06 — free-tier Actions not reliable). Test gate = local `flutter analyze` + `flutter test`. **Do NOT run the full `flutter test` suite** — it crashes on Windows hosts via a sqlite3 native-assets Flutter tool bug (see `docs/troubleshooting.md`). Test individual files or a named batch instead, e.g. `flutter test test/update_checker_test.dart` or `flutter test test/money_test.dart test/update_checker_test.dart`.

## Data & privacy stance (product decision)

**Two-layered framing. Keep them separate. This matters.**

- **Public layer** (users, Play listing, privacy policy, onboarding copy): **privacy-first.** "Private, on-device, never sold, encrypted." This is the honest public contract and the marketing position. Never write "max tracking" anywhere a user sees it.
- **Internal layer** (engineering, analytics, sync, PRs, this repo): **track everything, Google-style.** The product's entire value is granular spend data — every UPI payment, merchant, category, date. Capture it all, store it, sync it, from day one. No artificial limits. Don't cripple the product chasing a privacy narrative.

**Hard boundary in both layers:** data is NEVER sold, NEVER shared, NEVER used for ad targeting. Monetization = premium subscription, not data.

- Public docs/copy: privacy-first language only.
- Internal tools/PRs/docs: full-tracking assumptions, granular capture.
- Encryption in transit + at rest. App lock protects on-device access.
- Privacy policy says "private, on-device, never sold" — and that boundary is true.

## Coding standards (MANDATORY)

Apply to every line of code. These exist because this repo has a 2-person team and drift is expensive. Sourced from `coding-standards` + `api-design` skills.

- **Smallest possible change.** No refactoring adjacent code. Every changed line must trace to the task.
- **YAGNI.** No feature, abstraction, or config for something we don't need now. No "flexibility for later." No unused imports, variables, or files.
- **No unrequested abstractions.** No interface with one implementation. No factory for one product. No config for a value that never changes.
- **Boring over clever.** The simplest thing that works. Code must be readable at 3am.
- **Stdlib / existing deps first.** Do NOT add a new package for something a few lines can do. Any new dependency requires owner approval.
- **Immutability.** Don't mutate existing objects; return new ones.
- **Naming.** camelCase functions/vars, PascalCase types/widgets, `is`/`has`/`can` for booleans, `UPPER_SNAKE_CASE` constants. Match surrounding code.
- **Error handling.** No swallowed errors. No silent `catch {}`. Show a user-friendly message; log detail.
- **File limits.** Functions < 50 lines, files < 800 lines. Split if exceeded.
- **Tests with every change. MANDATORY.** Every feature, bug fix, or non-trivial logic change ships test file(s) in the same commit. No exceptions, no "tested manually." A change without tests is not done. `flutter test` is the gate.
- **Readability first.** Descriptive names, self-documenting code over comments. Comments explain WHY, not WHAT.
- **Immutability.** Never mutate existing objects/arrays — spread/copy then update. In Dart this means `copyWith` patterns, immutable models.
- **No `any` / dynamic where avoidable.** Type everything. Prefer sealed classes / unions over stringly-typed values.
- **Early returns** over deep nesting. Max 3-4 nesting levels.
- **Named constants** for magic numbers (retry limits, timeouts, threshold percents).

### API / Supabase conventions

- RESTful plural resources in Postgres tables: `transactions`, `categories`, `merchants`, `rules`, `budgets`.
- Response envelope: `{ data, error, meta }`. Errors use proper HTTP codes (400/401/403/404/409/422/429/500), never 200-for-everything.
- RLS everywhere — every row scoped by `user_id = auth.uid()`.
- Pagination on list endpoints (`limit`/`offset`).
- Validate all input at the boundary (client + server). No trusting the other side.
- Never log raw amounts with PII unnecessarily; never expose Supabase keys to the client repo (use env).

### UI / frontend design conventions

- Material 3 is the base — but the UI must NOT look like a default template. One deliberate signature element per major screen (see `docs/design.md` design direction).
- Intentional hierarchy through scale + spacing, not uniform cards everywhere.
- Every meaningful surface needs designed hover/focus/active states.
- State via Riverpod. Navigation via go_router. No context-drilling.
- Empty states are invitations to act, never dead ends. Errors are explicit + actionable, never apologetic.

## ANTI-SLOP RULES (hard blocks — do not violate)

These are explicit product decisions. Do not "improve" them, do not "help" by adding them:

- **NO AI / LLM anywhere.** No Gemini, no OpenAI, no "intelligent" features. Categorization is a local rule map. "AI insights" is banned. The word "AI" in a PR = rejected PR.
- **NO ads in finance screens. Ever.**
- **NO bank API integration.** Not available to indie devs; don't build a fake version.
- **SMS permission allowed.** Notification capture is the primary path, but SMS is now officially permitted for auto-capture.
- **NO Firebase.** Supabase is chosen. Don't migrate.
- **NO mock/placeholder features.** If a screen can't do its job, it doesn't ship.
- **NO golden-gate UI experiments.** Follow the app's existing Material 3 pattern; don't rebuild a screen in a different style because you like it.
- **NO dead code commits.** If your change makes something unused, delete it — but don't delete pre-existing dead code either.

## Build APK (learned from past errors)

Proven recipe — do NOT deviate:

```bash
# 1. Clear the Windows native-assets lock first (a leftover sqlite3.dll blocks
#    the build tool from cleaning — "Flutter failed to delete ... sqlite3.dll").
rm -rf build/native_assets/windows .dart_tool/hooks_runner
# 2. Build split-per-abi (NOT --target-platform android-arm64).
flutter build apk --release --split-per-abi
# 3. Arm64 APK → build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

- **Auto-update trigger = version bump.** The in-app update checker compares
  installed `versionName` to the latest GitHub release tag and only prompts when
  a newer release with a `kharcha-armv8a-release.apk` asset exists. If you push
  a fix without bumping `version` in `pubspec.yaml`, users never update. Every
  release = bump `version:` first, upload the APK to the same-tag release.
- **Rate caps (in-app): 1 auto-check/day + 3 manual checks/hour** per device.
  GitHub's unauthenticated limit is 60 req/hr per IP, so 1000 devices never
  flag the account; 429 fails silent. Do not raise these.
- **Always `--split-per-abi`.** `--target-platform android-arm64` produced a
  broken universal APK ("package is invalid" on install).
- **`packaging { jniLibs { useLegacyPackaging = false } }`** in
  `android/app/build.gradle.kts` is REQUIRED — page-aligned (uncompressed)
  native libs are the real fix for the install error. Keep it.
- **Do NOT add an `ndk { abiFilters }` block** — it conflicts with
  `--split-per-abi` ("Conflicting configuration: 'arm64-v8a' in ndk abiFilters
  cannot be present when splits abi filters are set").
- Release upload: replace `kharcha-armv8a-release.apk` on the latest GitHub
  release (delete-asset + upload --clobber). Size sanity: ~24-26MB.
- **Signing — MUST stay debug-signed for sideload.** `buildTypes.release` falls
  back to debug signing when `android/key.properties` is absent. This is
  REQUIRED: the debug key signed every released APK since v0.2.1, and Android
  refuses to install over an app signed with a different key. A release keystore
  was generated (2026-08-09) but is PARKED at `android/key.properties.release` —
  do NOT restore `key.properties` while sideloading or every device hits
  "package conflicts with existing package" until uninstall. Re-enable it only
  when publishing to Play Store (which requires real signing), and accept the
  one-time uninstall across devices. Keystore + password in `android/BACKUP_KEYS.txt`
  (gitignored).

## Git workflow

- Branch off `main`: `feat/<short-name>` or `fix/<short-name>`.
- Conventional commits: `feat:`, `fix:`, `refactor:`, `docs:`, `test:`, `chore:`.
- PR to `main`. Owner reviews and merges.
- PR description must say: **what changed, how tested, screenshots if UI.**
- Attribution disabled globally (no Co-Authored-By trailer).

## Definition of done

- [ ] Code matches the standards + ponytail method above
- [ ] Test file(s) written for the change, covering the new logic
- [ ] `flutter analyze` passes
- [ ] `flutter test` passes
- [ ] Manual smoke test on Android device/emulator
- [ ] PR reviewed and approved by the owner
- [ ] `docs/state.md` updated

## Docs must stay current — every commit

**Rule: every PR/commit that changes behavior updates the necessary md files in the same commit.** If an agent or dev gets context-exhausted mid-task, a fresh session must be able to reload everything from the md files alone.

Required md updates per change:
- **Behavior/feature/step complete** → `docs/state.md` (status, completed, next up)
- **Scope, personas, features change** → `docs/prd.md`
- **Architecture, schema, stack, UI direction change** → `docs/design.md`
- **Build order / steps change** → `docs/implementation-plan.md`
- **Handover context, gotchas, decisions** → `docs/handoff.md`
- **Version-level change** → `docs/changelog.md`
- **Team/roles/rules change** → `CLAUDE.md` + `agents.md`
- **Any decision the next session must know** → `docs/handoff.md` log

If a commit changes code but none of these md files need an update, say why in the PR description. Do not skip doc updates "because it's a small change." Small changes accumulate and the md files are the source of truth for the next session.

## Rule priority

CLAUDE.md > user request > skill instructions. If a skill or agent says something different, this file wins. When in doubt, ask the owner in the PR.
