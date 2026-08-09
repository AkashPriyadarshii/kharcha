# Changelog

All notable changes to Kharcha. Format: `[Version] — Date — Summary`.

## [v0.2.2] — 2026-08-09

- **Real release signing** — generated `kharcha-release.jks` keystore, wired via gitignored `android/key.properties`. Release builds sign with it (debug fallback only when key.properties absent). Fixes reinstall-over-upgrade failures; survives the Android 16 24h sideload wait.
- **Money precision audit** — every amount boundary routes through `parseAmount` (2dp rounding): add/quick-add expense, budget limit, wallet balance, savings goal target + add, debt amount, subscription amount, CSV import, and the UPI/bank notification parser (was raw `double.parse`, comma bug fixed). New `test/money_test.dart`.
- **Terms screen reachable pre-login** — router redirect whitelisted `/terms` so signed-out users aren't bounced to `/auth`.
- **Profile About section** — Akash Priyadarshi + GitHub profile/repo links (opens externally). `url_launcher` promoted to direct dep.
- **Android 16 prep** — SafeArea (bottom) on wallets/objectives/subscriptions pushed screens (gesture-nav bar can't clip the last item). AGP 8.11.1 / Gradle 8.14 / Kotlin 2.2.20 / Flutter 3.44.9 already satisfy the 16KB-page + targetSdk requirements.
- **Repo hygiene** — tracked `android/build/reports/*.html` artifact removed + `/android/build/` gitignored (was inflating GitHub language stats); README "For AI agents" quick-clone block removed.
- **Backup audit** — all user-entered tables sync (transactions, custom categories, budgets, wallets, recurring, objectives, debts). `rules`/`merchants`/`exchange_rates` + app-lock/onboarding flags stay local by design.

## [unreleased]

- **Live fixes (v0.2.3)** — (1) **UPI capture was dead: path mismatch.** Kotlin `UpiNotificationListener` wrote the inbox to `context.cacheDir` (`cache/`), Dart read `getApplicationCacheDirectory()` (`code_cache/`) — a different dir, so the inbox was never drained and every capture silently vanished. Dart now reads `getTemporaryDirectory()` (= `getCacheDir()`). (2) **Real-time capture** — inbox drained every 30s (was startup-only), so payments appear ~live while the app is open. (3) **Feature deletes now sync** — deleting a budget/wallet/recurring/objective/debt/custom category writes a tombstone (`deleted_features`, schema v11) that the SyncEngine drains as a remote DELETE + skips on pull; no more resurrection after reinstall. (4) **App lock fixed** — `MainActivity` is now `FlutterFragmentActivity` (local_auth requires it for the biometric prompt; `FlutterActivity` made `authenticate()` fail). (5) **Profile "Open source" → "Source"** — matches the all-rights-reserved LICENSE (view-only, no fork/copy/derivative/commercial).
- **Capture everything** — any app's notification with a ₹ amount is captured (UPI + bank + messaging); Dart parser gates on payment keywords so "bhej de ₹200" chats don't become expenses. Money IN captured too (income transactions). Schema v10, parser rework + tests.
- **Custom-category sync** — custom categories now push to Supabase (per-user rows, migration 0004), budgets/recurring translate category ids. Server `categories` seed (0003).
- **Android-only** — `windows/` scaffold removed permanently (single platform, README updated).
- **Full backup sync** — every feature table now syncs to Supabase (schema v9): budgets, wallets, recurring subscriptions, savings objectives, credit/debt ledger all get `dirty`/`remoteId` columns and push/pull with LWW. Server `categories` seed migration (0003) — budget push was failing FK 23503 because the server category table was never seeded. Budgets gain an `updated_at` LWW clock. Supabase migration 0002 adds the four new tables + RLS. SyncEngine pushes/pulls features after transactions; custom-category rows (no server mirror) stay local-only. Auto-backup timer in HomeShell — flushes dirty rows every 30s while the app is open, so a budget/edit reaches Supabase without waiting for a trigger.
- **UX audit pass** — categories grouped into expense/income sections; wallets tap no longer silently deletes (rename-only via edit); subscriptions gain delete-with-confirm + actionable empty state; debts/objectives deletes confirmed; transactions list shows income with a glyph badge (not color-only).
- **Vector Icons & App Launcher Redesign** — added `lucide_icons_flutter` (^3.1.15) for high-performance in-app category vector icons (`CategoryIcon` widget, fallback to emoji); redesigned launcher icon with an elite geometric **K+₹ Monogram Emblem** (3D chiseled off-white on `#0A6B4D` deep ink green) saved at `assets/icon/app_icon.png`. Authored by Antigravity AI Agent for Akash.
- **Release hardening** — Android-only (Windows scaffold removed); Gradle arm64 ABI filter + page-aligned native libs (`useLegacyPackaging=false`) → clean arm64 install (no "package invalid"). APK named `kharcha-armv8a-release.apk` on the v0.2.1 release. CI removed (on-demand build + release).
- **Cleanup** — removed Windows scaffold, `Platform.isAndroid` branches, Windows-only deps from lockfile; `.codegraph/` gitignored.
- **Onboarding redesign** — 4-step flow (value prop → capture → summaries → battery) with progress bar, one step at a time, live permission status from a new `getCaptureStatus` channel method (granted/denied visible, auto-advances), skip-all path. No more "Kharcha is set up" lie or fire-and-forget buttons.
- **Profile / reports / categories UX** — profile: edit-name inline dialog (persists to Supabase `user_metadata`); reports: pie total in center + trend tick out-of-range guard (crash fix); categories: expense/income segmented tabs + Lucide vector icons in tiles; terms screen: consent line + last-updated date; export always lands in Downloads; app lock supports PIN-only devices (`isDeviceSupported`).

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
