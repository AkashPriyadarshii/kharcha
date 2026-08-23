# Agents.md — For AI coding agents

> This file is for AI coding agents (Cursor, Copilot, Cline, Codex, Windsurf, whatever you use).
> If you're an AI agent, read this before touching any code. These rules OVERRIDE your defaults.

## Project

**Kharcha** — India-first UPI expense tracker. Flutter, Android 12+ (minSdk 32), offline-first, rule-based automation (no AI in the product), Supabase sync.

One human: Akash (owner). All code via AI agents working under his direction.

## Mandatory: read these before ANY task

- `CLAUDE.md` — the full contract (standards, anti-slop rules, git workflow, privacy framing)
- `docs/ponytail.md` — the coding philosophy (ponytail method). Required reading.
- `docs/design.md` — architecture + data model + design direction
- `docs/state.md` — where the project is

If you're invoked for a specific task, read `CLAUDE.md` + `docs/ponytail.md` at minimum. They override your built-in style.

## The ponytail method (short version)

You are a lazy senior developer. Lazy = efficient, not careless. The best code is the code never written.

1. **YAGNI** — does this need to exist at all? If speculative, skip it.
2. **Reuse** — already in this codebase? Use it before writing new.
3. **Stdlib / platform** — built-in feature covers it? Use it.
4. **Existing deps** — already-installed dependency solves it? Use it. NEVER add a new dependency for a few lines. New deps need the owner's approval.
5. **One line if possible.**
6. **Minimum code that works.**

Rules: no unrequested abstractions, no boilerplate, no scaffolding "for later", deletion over addition, boring over clever, smallest change that traces to the task, bug fixes at root cause not symptom, mark shortcuts with `ponytail:` comments.

## HARD anti-slop blocks (never violate)

- **NO AI/LLM in the product.** No Gemini, OpenAI, "AI insights," "smart features." Categorization is a local rule map. The word "AI" in your PR = rejected.
- **NO ads in finance screens.**
- **NO Firebase.** Supabase is chosen. Don't migrate.
- **SMS permission allowed.** Notification capture is still an option, but SMS parsing is permitted as opt-in.
- **NO mock/placeholder features.** A screen that can't do its job doesn't ship.
- **NO generic template UI.** Material 3 base but opinionated. No default card grids, no stock hero + gradient blob, no safe-gray flat. See `docs/design.md` design direction.
- **NO dead code.** Delete what your change makes unused. Don't delete pre-existing dead code.

## Standards

- Immutability (never mutate existing objects, use `copyWith`).
- Descriptive names, self-documenting code, comments explain WHY not WHAT.
- Type everything. No `dynamic` where avoidable.
- Early returns over deep nesting.
- Named constants for magic numbers.
- Functions < 50 lines, files < 800 lines.
- Errors handled explicitly, never swallowed.
- Input validated at every trust boundary.
- **Tests with every change. MANDATORY.** Every feature, bug fix, or non-trivial logic change ships test file(s) in the same commit. No exceptions. A change without tests is not done. `flutter test` is the gate.

## Run / verify

```bash
flutter pub get
flutter analyze        # MUST pass before any PR
flutter test           # MUST pass before any PR
flutter build apk      # sanity check before merge to main
```

**CI:** none (removed 2026-08-06 — free-tier Actions not reliable). Test gate = local `flutter analyze` + `flutter test`. **Do NOT run the full `flutter test` suite** — it crashes on Windows hosts via a sqlite3 native-assets Flutter tool bug (see `docs/troubleshooting.md`). Test individual files or a named batch instead, e.g. `flutter test test/update_checker_test.dart` or `flutter test test/money_test.dart test/update_checker_test.dart`.


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
- PR to `main`. Owner reviews + merges.
- PR description: what changed, how tested, screenshots if UI.
- No direct pushes to `main`. No `--force`. No Co-Authored-By trailer (attribution disabled).

## Definition of done

- [ ] Matches ponytail + standards + anti-slop
- [ ] Test file(s) written for the change, covering the new logic
- [ ] `flutter analyze` passes
- [ ] `flutter test` passes
- [ ] Smoke test on Android 12+ device/emulator
- [ ] `docs/state.md` updated

## Docs must stay current — every commit

**Every PR/commit that changes behavior updates the necessary md files in the same commit.** If an agent runs out of context, a fresh session reloads everything from the md files alone. Never skip doc updates for "small changes."

- Behavior/feature/step done → `docs/state.md`
- Scope/personas/features changed → `docs/prd.md`
- Architecture/schema/stack/UI changed → `docs/design.md`
- Build order changed → `docs/implementation-plan.md`
- Gotchas/decisions → `docs/handoff.md`
- Version change → `docs/changelog.md`
- Team/rules changed → `CLAUDE.md` + `AGENTS.md`

If no md needs updating, say why in the PR. The md files are the source of truth for the next session.

## Stack (don't change without approval)

Flutter · Riverpod · go_router · Drift (SQLite) · Supabase (Google Auth + Postgres) · fl_chart · flutter_local_notifications · local_auth · csv · intl

## Ask when unsure

Don't invent features. If scope is unclear, ask in the PR. The owner would rather answer a question than review a wrong implementation.
