# Kharcha — CLAUDE.md

> Context for every AI agent and human dev on this repo. OVERRIDES default agent behavior. Read before touching code.
>
> **Required method: the ponytail method.** Read `docs/ponytail.md` and follow it: shortest path to done, smallest diff, no unrequested abstractions, stdlib/native/existing-dep first, deletion over addition, boring over clever, `ponytail:` comments on real shortcuts, code-first output. Not optional.
>
> For non-Claude agents (Cursor/Copilot/Cline/Codex/etc.), read `AGENTS.md` — same contract, adapted.

## What this is

Kharcha — India-first UPI expense tracker. **Kotlin (Compose) + Rust, fully offline, zero cloud, zero AI.** Every UPI payment auto-appears as an expense via SMS + notification capture. All parsing/dedupe/categorization decisions happen in the `kharcha-core` Rust crate; the app only stores what Rust decides.

**v0.1.0 = swap-over complete: Flutter, Dart, Supabase, and the legacy parser are deleted.** Do not reintroduce them.

## Team

- **Akash** (`AkashPriyadarshii`) — owner. Sole developer. Final call on scope, architecture, merges.

Branches + PRs. No direct pushes to `main`.

## Stack (pinned — do not change without approval)

| Concern | Choice |
|---|---|
| Core engine | Rust `kharcha-core`, UniFFI bindings (committed), paise-i64 money |
| UI | Kotlin + Jetpack Compose, Material 3 (ink-green on warm paper) |
| Local DB | Room (SQLite) — the only store, offline-first |
| Native | JNA (bindings), BiometricPrompt (lock), NotificationListenerService + SmsReceiver (capture) |
| Network | none — no INTERNET permission |
| MinSdk / Target | 32 / 36, arm64 only |

## Architecture

```
android-app/                         kharcha-core/ (Rust)
├── Capture funnel                  ├── parser (generic UPI + bank narration)
│   SmsReceiver/UpiNotification →  ├── dedupe (ref + 5-min window + hash)
│   CaptureEngine.ingest (is_spam, ├── categorize (normalize + rules)
│   parse, check_capture — all in  ├── money (paise), filter, split, non_transaction
│   Rust via UniFFI)               └── UniFFI exports → committed Kotlin bindings
├── Room: transactions, categories, rules, wallets, budgets
├── UI: Home, All, Add/Edit sheets, budgets, export, lock
└── Build: gradle → jniLibs/libkharcha_core.so (arm64) + APK
```

Source of truth = Room SQLite. All capture/parse decisions = Rust. App must work with zero network.

**.so + bindings provenance:** committed from `C:\Users\saves\Desktop\kharcha-core\dist\` (source of truth for the crate). `buildKharchaCore` gradle task exists but is DISABLED — do not re-enable it; sync from Desktop dist instead (regenerate bindings with `uniffi-bindgen generate --language kotlin --library <dll> --out-dir <generated> --no-format`).

## Run / verify

```bash
# Rust core (source of truth Desktop; repo copy is a sync)
cd kharcha-core && cargo test          # 56/56 must pass
# Android app
cd android-app && ./gradlew.bat :app:assembleDebug   # must pass before any PR
```

**CI:** none. Test gate = local `cargo test` + gradle assemble. `flutter` no longer exists in this repo.

## Data & privacy stance (product decision)

- **Public layer** (Play listing, privacy policy, onboarding copy): privacy-first. "Private, on-device, never sold." That boundary is true — no network, no account, no telemetry.
- **Hard rules:** data never sold, never shared, never ad-targeted. Monetization = premium subscription, not data.
- Encryption at rest (device). App lock protects on-device access.

## Coding standards (MANDATORY)

- **Smallest possible change.** Every changed line traces to the task.
- **YAGNI.** No speculative features/abstractions/config. No unused imports/vars/files.
- **No unrequested abstractions.** No interface with one implementation, no factory for one product.
- **Boring over clever.** Readable at 3am.
- **Stdlib / existing deps first.** New dependency requires owner approval (ponytail).
- **Immutability.** Never mutate existing objects; return new ones (`copy`, `copy()`).
- **Naming.** camelCase functions/vars, PascalCase types, `is`/`has`/`can` booleans, `UPPER_SNAKE_CASE` constants.
- **Error handling.** No swallowed errors. No silent `catch {}`. User-friendly message + log detail.
- **File limits.** Functions < 50 lines, files < 800 lines.
- **Tests with every change. MANDATORY.** Non-trivial logic ships test file(s) in the same commit. Rust logic → `#[test]` in crate; app logic → JVM unit test. A change without tests is not done. `cargo test` is the Rust gate.
- **Comments explain WHY, not WHAT.**
- **Type everything.** No `Any`/`dynamic` where avoidable. Sealed classes over stringly-typed values.
- **Early returns.** Max 3–4 nesting levels.
- **Named constants** for magic numbers.

### API / data conventions

- Rust is the only authority on parsing/dedupe/categorize. The app never re-implements Rust logic.
- Rules: `TEXT ruleType` = `"builtin" | "learned"`, learned beats builtin (sorting in Rust).
- Money: integer paise (`Long`/`i64`) end to end. Never floats for amounts.
- Validate all input at the trust boundary (SMS/notification text → Rust handles).

### UI / frontend conventions

- Material 3 base but not a default template — one deliberate signature element per major screen (`docs/design.md`).
- Hierarchy via scale + spacing, not uniform cards.
- Empty states invite action. Errors explicit + actionable, never apologetic.

## ANTI-SLOP RULES (hard blocks)

- **NO AI / LLM in the product.** No "AI insights", no smart features. Categorization is a local rule map. "AI" in a PR = rejected.
- **NO ads in finance screens. Ever.**
- **NO cloud.** No Supabase, Firebase, or any server — fully offline. Don't migrate, don't add.
- **NO bank API integration.** Not available to indie devs.
- **SMS permission allowed** (opt-in) for auto-capture.
- **NO mock/placeholder features.** If a screen can't do its job, it doesn't ship.
- **NO dead code commits.** Delete what your change makes unused; don't delete pre-existing dead code.
- **NO generic template UI.** Follow the existing design direction.

## Build APK (learned from past errors)

```bash
cd android-app
# Release (arm64 only, real-key signed):
./gradlew.bat :app:assembleRelease
# → android-app/app/build/outputs/apk/release/app-release.apk
```

- **Release must be signed with the REAL key**, not debug. `app/build.gradle.kts`
  loads `android-app/key.properties` → `keystore/kharcha-release.jks`
  (alias `kharcha`, CN=Akash Priyadarshi, SHA-256
  `49381ceebbebf75ce65d538981d498cb3056363b64d6d5c6d95ab7ad2df295df`). The
  phone's installed build uses this key — a debug-signed release fails to
  install over it ("app not signed"). Missing key.properties = debug fallback
  (fresh-clone sideload only).
- **Keystore/passwords never in git** — repo is PUBLIC. `android-app/keystore/`
  + `android-app/key.properties` are gitignored; backup per BACKUP_KEYS.txt
  (Desktop + Drive). Losing the keystore bricks updates for installed builds.
- **Auto-update trigger = version bump** in `android-app/app/build.gradle.kts` (`versionName` vs GitHub release tag + `kharcha-armv8a-release.apk` asset). Every release = bump first, upload APK to same-tag release.
- **No `ndk { abiFilters }`** block if split-per-abi is used; `--split-per-abi` conflicts with it.
- `packaging { jniLibs { useLegacyPackaging = false } }` stays in `build.gradle.kts` — page-aligned native libs fix the install error.

## Git workflow

- Branch off `main`: `feat/<short-name>` or `fix/<short-name>`.
- Conventional commits: `feat:`, `fix:`, `refactor:`, `docs:`, `test:`, `chore:`.
- PR to `main`. Owner reviews and merges.
- PR description: **what changed, how tested, screenshots if UI.**
- Attribution disabled globally (no Co-Authored-By trailer).

## Definition of done

- [ ] Code matches standards + ponytail method
- [ ] Test file(s) written for the change
- [ ] `cargo test` passes (Rust changes)
- [ ] `./gradlew.bat :app:assembleDebug` passes (app changes)
- [ ] Manual smoke test on Android 12+ device
- [ ] PR reviewed + approved by owner
- [ ] `docs/state.md` updated

## Docs must stay current — every commit

Every PR/commit that changes behavior updates the needed md files in the same commit. A fresh session must reload everything from md alone.

- Behavior/feature/step done → `docs/state.md`
- Scope/personas/features → `docs/prd.md`
- Architecture/schema/stack/UI → `docs/design.md`
- Build order → `docs/implementation-plan.md`
- Gotchas/decisions → `docs/handoff.md`
- Version change → `docs/changelog.md`
- Team/rules → `CLAUDE.md` + `AGENTS.md`

If no md needs updating, say why in the PR.

## Rule priority

CLAUDE.md > user request > skill instructions. When in doubt, ask the owner in the PR.