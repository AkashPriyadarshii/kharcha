# Kharcha — Project State

> Update after every merged PR. This is the single source of truth for where the project stands.

## Current status

**Phase: v0.2.1 — shipped.** Transactions edit/delete + tombstone sync, UX audit, arm64 release APK (`kharcha-armv8a-release.apk`) live on the v0.2.1 GitHub release. Android-only (Windows platform scaffold removed). Gradle now arm64-only ABI-filtered + page-aligned native libs — builds clean, installs clean (no "package invalid"). CI removed (on-demand build + release). `flutter analyze` clean. Full `flutter test` still blocked on this Windows host (sqlite3 native-assets, `docs/troubleshooting.md`). Next: on-device verify.

**Phase: v0.2.0 — income support shipped.** Income is live end-to-end: per-transaction + per-category `is_income` (schema v7, Supabase mirrored), income/expense toggle on both add forms, built-in income categories, home hero income/spend split (green income, red spend), transactions tab income filter, spend aggregates exclude income, sync round-trip, CSV/JSON export `type` column + import. Permissions pass: full manifest set, onboarding asks notification + battery exemption in-app (no manual settings). Manifest now declares INTERNET/ACCESS_NETWORK_STATE (release builds need it for Supabase sync — debug got it injected). `flutter analyze` clean. Full `flutter test` still blocked on Windows host (sqlite3 native-assets, `docs/troubleshooting.md`). CI removed (on-demand release). Next: on-device verify + publish.

## Completed

- [x] Repo `AkashPriyadarshii/kharcha` (private, collaborators: priyaranjan122002)
- [x] Design approved (`docs/design.md`)
- [x] PRD (`docs/prd.md`)
- [x] Implementation plan (`docs/implementation-plan.md`)
- [x] Team docs: contributors, state, handoff, changelog, ponytail, agents.md
- [x] CLAUDE.md (contract + anti-slop + ponytail required)
- [x] **Step 1.1** Flutter scaffold: `com.kharcha.app`, minSdk 32, deps installed, analyze clean
- [x] **Step 1.2** Google sign-in via Supabase Auth: auth flow, session persistence, Auth/Home switch on session
- [x] **Step 1.3** Drift local schema: transactions, categories, merchants, rules, budgets; onCreate seed (10 categories + ~40 builtin merchant rules); `supabase/migrations` schema mirror

## Completed

- [x] **Step 2.1** Manual entry + quick-add: full form (amount, merchant, category, note, payment method, date), quick-add dialog, transactions list + FAB, go_router wired.
- [x] **Step 2.2** Rule-based categorization: `Categorizer` (normalize + fuzzy word-boundary match, learned > builtin), auto-categorize on insert. Pure Dart, tested.
- [x] **Step 2.3** Notification capture: Kotlin `UpiNotificationListener` → JSONL inbox, Dart parser + dedupe by upi_ref, drain on startup, disclosure screen. Tests written.
- [x] Notification policy + edit/notes scope recorded in design.md.
- [x] **Step 3.1** Supabase sync: `dirty` + `remoteId` columns (schema v2), SyncEngine (push dirty → upsert, pull on login, LWW by updated_at), 23505 upi_ref conflict handling, triggers on auth + drain + manual adds. Tests.
- [x] **Step 3.2** Daily 9PM + Sunday weekly Hinglish summaries: `Notifications` service, channel + permission + tz, re-scheduled each app open with as-of-last-open data (see `docs/handoff.md`). Tests.
- [x] **Step 4.1** Home dashboard: today/month/budget-left stats + this-month-by-category bars. Tabbed shell (Home/Transactions/Budget).
- [x] **Step 4.2** Transactions tab: search (merchant/note) + filters (category/merchant/payment method/date preset incl. custom range), clear-filters, empty-state. Pure client-side filter over the watched list.
- [x] **Step 4.3** Reports tab: category pie, monthly trend line, top merchants (fl_chart). Repository: `monthlyTrend()`, `merchantRanking()` + tests.
- [x] **Step 4.4** Budget tab: per-category monthly limits, progress bars, 50/80/100 alerts, add/edit/delete.
- [x] **Step 4.5** Profile tab: account, payment methods, export CSV/JSON UI, backup status, app lock toggle.
- [x] **Step 5.1** Export: CSV + JSON (category names, newest first).
- [x] **Step 5.2** App lock: real now — `AppLockStore` (JSON file) + `AppLockController` provider, toggle in Profile, `LockGate` overlays + re-locks on resume. Tests.
- [x] **Step 5.3** Privacy policy (`docs/privacy-policy.md`) + Play listing copy + data-safety mapping (`docs/play-listing.md`) + Terms screen (in-app `/terms`). Launcher icon + screenshots pending device.
- [x] **Build fixes** — debug APK now builds: core library desugaring (flutter_local_notifications) + Kotlin `const val Set` → `val` in `UpiNotificationListener.kt`.
- [x] **Stale-aggregate fix** — `monthSpendProvider`/`monthlyTrendProvider`/`merchantRankingProvider`/`paymentMethodTotalsProvider`/`homeSummaryProvider` were FutureProviders over one-shot DB reads → budget/home/reports stayed stale until app restart. Converted to stream-derived (`watchAll().asyncMap`). Tests updated.
- [x] **Home recent transactions** — Home tab now lists the 5 newest expenses under the category bars.
- [x] **Onboarding** — first-launch flow after login: capture disclosure → battery settings → summaries; skippable, persisted flag, gated via router redirect. `OnboardingStore` + tests.
- [x] **Battery + notifications** — `POST_NOTIFICATIONS` manifest entry (Android 13+); `MainActivity` MethodChannel `openBatteryOptimizationSettings`.
- [x] **UPI capture fixes** — `UpiNotificationListener.kt`: dedupe by identical text within 60s window (no tombstone set), amount regex on both `android.title` + `android.text`, whole handler try/catch. Kotlin append → Dart parse/dedupe by upi_ref.
- [x] **CSV import** — `importer.dart`: kharcha export format (`date,amount,merchant,category,note,payment_method,upi_ref,source`), tolerant rows, upi_ref dedupe, result summary. Import UI in Profile.
- [x] **Wallets + multi-currency** — `Wallets` + `ExchangeRates` tables (schema v3), `walletId` on transactions, wallet dropdown in add-expense, live per-wallet balance, add/edit/delete wallet, INR/USD/EUR/GBP/AED/SGD.
- [x] **Recurring subscriptions** — `RecurringTransactions` table (schema v4), due list + "N due now" header, pay-one-tap (rolls next due), pause/resume.
- [x] **Savings objectives** — `Objectives` table (schema v5), goal cards with progress, add saved amount, delete.
- [x] **Bill splitter** — `splitBillPaisa` (integer paise, exact-sum), split screen inserts one expense per person (`Split i/N` note).
- [x] **Categories editor** — list seeded+custom, add name/emoji/color, edit, delete (detaches transactions → uncategorized). Builtins read-only.
- [x] **Credit/Debt ledger** — `Debts` table (schema v6), lend/borrow with settle toggle, net-owed strip, delete.
- [x] **Design pass** — `lib/core/theme.dart`: ink-green on warm paper, `moneyStyle` (display + tabular figures), `SectionTitle` caps labels, hero month panel (count-up, over-budget amber), themed charts/budget/tabs.
- [x] **Guest mode** — "Continue as guest" on auth (no Supabase session, local-only, sync no-ops). Pre-release — not publishing yet.
- [x] **Android-only cleanup** — `windows/` platform scaffold removed (was debug-only); Windows-specific code (`dart:io` `Platform.isAndroid` branches) stripped; `local_auth_windows`/`path_provider_windows` gone from lockfile. Android is the only target.

## Next up

1. On-device verify (Akash) — sideload `kharcha-armv8a-release.apk` from v0.2.1 release: new screens (wallets/subscriptions/objectives/split/categories), UPI capture re-check.
2. Supabase schema mirror for new tables (wallets, recurring, objectives) — currently local-only.
