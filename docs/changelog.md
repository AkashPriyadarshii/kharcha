# Changelog

All notable changes to Kharcha. Format: `[Version] — Date — Summary`.

## [unreleased]

- **Transactions edit/delete (v0.2.1)** — every transaction now has edit (reuses the add form, prefilled) and delete (confirm dialog) via the transactions tab. Deletes are sync-correct: a new `deleted_transactions` tombstone table (schema v8) records remote rows for deletion, pushed as a DELETE before pulls, so a deleted expense never resurrects from Supabase. Update marks the row dirty and overwrites on push.
- **UX audit pass** — categories grouped into expense/income sections; wallets tap no longer silently deletes (rename-only via edit); subscriptions gain delete-with-confirm + actionable empty state; debts/objectives deletes confirmed; transactions list shows income with a glyph badge (not color-only).
- **Release hardening** — Android-only (Windows scaffold removed); Gradle arm64 ABI filter + page-aligned native libs (`useLegacyPackaging=false`) → clean arm64 install (no "package invalid"). APK named `kharcha-armv8a-release.apk` on the v0.2.1 release. CI removed (on-demand build + release).
- **Cleanup** — removed Windows scaffold, `Platform.isAndroid` branches, Windows-only deps from lockfile; `.codegraph/` gitignored.

## [v0.2.0] — 2026-08-08

- **Income support** (Cashew port) — transactions + categories carry `is_income`; income/expense toggle on quick-add + full add forms (green income, red expense); built-in income categories (Salary, Bonus, Gift, Other income); home hero shows green "Income this month" + red spend, recent tiles colored; transactions tab income/expense filter; spend/budget/trend aggregates exclude income; sync + export (`type` column) + import round-trip. Schema v6 → v7, Supabase `is_income` columns.
- **Permissions** — full manifest set (INTERNET/ACCESS_NETWORK_STATE, USE_BIOMETRIC, POST_NOTIFICATIONS, VIBRATE, storage legacy+modern, BIND_NOTIFICATION_LISTENER_SERVICE, WAKE_LOCK, REQUEST_IGNORE_BATTERY_OPTIMIZATIONS). Onboarding now asks in-app: notification permission dialog + battery exemption prompt (no manual settings digging); startup notification prompt removed.
- **Release** — arm64 release APK.

## [v0.1.1] — in build

- **UPI capture fixes** — dedupe by identical text (60s window), amount scan on title+text, crash-guarded handler
- **CSV import** — kharcha export format, tolerant parse, upi_ref dedupe
- **Wallets + multi-currency** — wallet per transaction, per-wallet balance, add/edit/delete, 6 currencies + exchange rates
- **Recurring subscriptions** — due list, pay-one-tap with roll-forward, pause/resume
- **Savings objectives** — goal cards + progress, add saved amount
- **Bill splitter** — exact-sum integer paise split, one expense per person
- **Categories editor** — add/edit/delete custom categories (emoji + color), builtins read-only
- **Credit/Debt ledger** — lend/borrow with settle toggle, net-owed strip
- **Design pass** — ink-green on warm paper theme, display-numeral money, hero month count-up, caps section labels
- **Guest mode** — continue without Google (pre-release)
- Schema v2 → v6 (wallets/exchange_rates, recurring_transactions, objectives, debts)
- Arm64-only release build (debug-signed)

## [v0.1.0] — released

- Repo `AkashPriyadarshii/kharcha` created (private)
- Design, PRD, implementation plan, team docs, CLAUDE.md written
- Scope locked: 16 features (see `docs/prd.md` §7)
- Full app code (2026-08-08): Google sign-in, Drift local DB + seed, manual entry + quick-add, rule-based categorization, UPI notification capture (Kotlin), Supabase sync, daily/weekly Hinglish notifications, 5-tab shell (Home / Transactions / Budget / Reports / Profile) with search + filters, charts, export CSV/JSON, app lock

---

## Planned future versions

- **v0.2.0** — SMS import (opt-in), recurring/subscription detection, savings goals, PDF export
- **v0.3.0** — family budget, financial health score, tax tags, multi-language, widgets
- **v1.0.0** — Play Store launch, premium tier
