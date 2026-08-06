# Kharcha — CLAUDE.md

> This file is context for every AI agent and every human dev working on this repo.
> It OVERRIDES default agent behavior. Read it before touching code.
>
> **Required method: the ponytail method.** Read `docs/ponytail.md` and follow it for every change — shortest path to done, smallest diff, no unrequested abstractions, stdlib/native/existing-dep first, deletion over addition, boring over clever, `ponytail:` comments on real shortcuts, code-first output. This is not optional.
>
> For non-Claude AI agents (Cursor/Copilot/Cline/Codex/etc.), read `agents.md` — the same contract, adapted.

## What this is

Kharcha — India-first UPI expense tracker. Flutter app for Android 12+.
Every UPI payment auto-appears as an expense via notification capture. No manual entry needed. Offline-first, privacy-first, **rule-based automation, zero AI**.

## Team

- **Akash** (`AkashPriyadarshii`) — owner. Final call on scope, architecture, merges.
- **Priyaranjan** (`priyaranjan122002`) — co-dev, UI/feature work.

Both work through branches + PRs. No one pushes to `main` directly.

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
- **Stdlib / existing deps first.** Do NOT add a new package for something a few lines can do. Any new dependency requires the other dev's approval.
- **Immutability.** Don't mutate existing objects; return new ones.
- **Naming.** camelCase functions/vars, PascalCase types/widgets, `is`/`has`/`can` for booleans, `UPPER_SNAKE_CASE` constants. Match surrounding code.
- **Error handling.** No swallowed errors. No silent `catch {}`. Show a user-friendly message; log detail.
- **File limits.** Functions < 50 lines, files < 800 lines. Split if exceeded.
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
- **NO SMS permission in v0.1.0.** Notification capture is the path. SMS is P2, opt-in, only with Play declaration.
- **NO Firebase.** Supabase is chosen. Don't migrate.
- **NO mock/placeholder features.** If a screen can't do its job, it doesn't ship.
- **NO golden-gate UI experiments.** Follow the app's existing Material 3 pattern; don't rebuild a screen in a different style because you like it.
- **NO dead code commits.** If your change makes something unused, delete it — but don't delete pre-existing dead code either.

## Git workflow

- Branch off `main`: `feat/<short-name>` or `fix/<short-name>`.
- Conventional commits: `feat:`, `fix:`, `refactor:`, `docs:`, `test:`, `chore:`.
- PR to `main`. Other dev reviews and approves. Owner merges.
- PR description must say: **what changed, how tested, screenshots if UI.**
- Attribution disabled globally (no Co-Authored-By trailer).

## Definition of done

- [ ] Code matches the standards + ponytail method above
- [ ] `flutter analyze` passes
- [ ] `flutter test` passes
- [ ] Manual smoke test on Android device/emulator
- [ ] PR reviewed and approved by the other dev
- [ ] `docs/state.md` updated

## Rule priority

CLAUDE.md > user request > skill instructions. If a skill or agent says something different, this file wins. When in doubt, ask the other dev in the PR.
