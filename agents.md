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
- **NO SMS permission in v0.1.0.** Notification capture is the path. SMS is P2 opt-in with Play declaration.
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
- Team/rules changed → `CLAUDE.md` + `agents.md`

If no md needs updating, say why in the PR. The md files are the source of truth for the next session.

## Stack (don't change without approval)

Flutter · Riverpod · go_router · Drift (SQLite) · Supabase (Google Auth + Postgres) · fl_chart · flutter_local_notifications · local_auth · csv · intl

## Ask when unsure

Don't invent features. If scope is unclear, ask in the PR. The owner would rather answer a question than review a wrong implementation.
