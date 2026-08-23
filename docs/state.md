# Kharcha — Project State

> Update after every merged PR. This is the single source of truth for where the project stands.

## Current status

**v0.2.9 released (2026-08-23).** UI, Sync, and Automation updates. 
- **Automation & UX:** Split Wallets UI into explicitly separated `Accounts (Auto-tracked)` and `Wallets (Manual)`. Engine now natively auto-creates accounts on the fly when an unrecognized bank mask is detected in a captured SMS. Added native instant Android background push notifications (Kotlin-level) for captured expenses so users get instant feedback. Auto-update mechanism fixed (asset name mismatch resolved) and now pushes a persistent local notification when an update is found.
- **Data & Sync:** Added `accountMask`, `bankName`, and `latestSmsBalance` to `Wallets`, and `needsReview`, `isDeleted`, `accountMask`, and `emoji` to `Transactions` and `Rules` in Drift (schema v12). Updated UI: wallets screen takes account mask/bank name and flags drift; transactions list highlights `needsReview` (pale yellow) with a confirm checkmark and displays rule-based emojis instead of category icons. Sync engine adapted: pushing local deletes now sets `is_deleted = true` remotely instead of hard-deleting, and pulling `is_deleted = true` physically deletes locally.

**Pennywise Feature Parity implemented (unreleased).** Added True Balance Extraction & Wallet Balance Sync (captured SMS calculates delta to update initialBalance for ground truth). Added Income Autopay / Subscription Automation (processAutopay executes due recurring transactions on startup and advances dates). Added Privacy-First Export (PII-masked CSV for transaction analysis). Added Smart Rules engine UI (manage learned and custom categorization rules). All new logic verified with unit tests.

**v0.2.8 released (2026-08-23).** Auto-report fatal crashes to Supabase (`app_errors`) using `AppLogger` and local caching; system logs screen added to profile tab. AppLogger operates with zero third-party telemetry dependencies (no Firebase/Sentry). Added migration `0006_app_errors.sql`. Includes all Pennywise parity features (ground truth wallet sync, income autopay, privacy export, smart rules UI).

**v0.2.7 released (2026-08-23).** Non-transaction spam filter (`_nonTransactionRe` — recharge expiry, OTP, bill-due, failed payment, loan promos all return `null` before parsing), onboarding Step 1 gains an optional SMS capture secondary action (`RECEIVE_SMS` + `READ_SMS`, MainActivity channel updated), GitHub API update checker rate limited (max 1/hr network hit) to prevent 429 exhaustion, data layer Drift SQL aggregation (count, groupBy) replacing OOM-prone memory loops. Includes Pennywise-style cross-channel deduplication (±2-min window) for SMS + Push, `seenAt` offline capture stability, and **GitHub-Style Spending Heatmap** in the Reports tab. Full notification/automation test suite (187/187 tests, 28 files, 0 analyzer warnings). APK `kharcha-armv8a-release.apk` (28.3 MB, debug-signed, arm64) on [release v0.2.7](https://github.com/AkashPriyadarshii/kharcha/releases/tag/v0.2.7). On top of v0.2.6 (dark theme + theme-mode picker, in-app bug reporting) and v0.2.4 (home redesign + reports upgrade). Next: on-device verify v0.2.7 capture filter (sideload + send a recharge SMS to confirm it's not captured); editable home sections (Cashew-style reorder). See changelog.

**Post-v0.2.2 polish (unreleased).** Display-name fix (Google `full_name` vs in-app `name`); app-lock re-lock race fixed (`_wasLockedAtPause`); home UX pass — bell removed, pencil manage sheet added, Profile re-onboarding tile, sign-out confirm. See changelog.

**Phase: v0.2.2 — live-bug fixes.** UPI capture un-broken (path mismatch `cache/` vs `code_cache/`), now real-time (30s drain); feature deletes sync via `deleted_features` tombstones (schema v11); app lock fixed (`FlutterFragmentActivity`); Profile "Source" not "Open source". See changelog.

**Phase: v0.2.2 — finalize pass shipped.** Everything from v0.2.1 plus the sleep-for-a-month hardening: **real release signing keystore** (kharcha-release.jks, gitignored key.properties, debug fallback on fresh clone) — upgrades no longer need uninstall; **money precision** — all amount inputs (add/quick-add/budget/wallet/goal/debt/subscription/import/UPI parser) route through `parseAmount` (2dp boundary rounding kills float drift), `money_test.dart` added; **terms screen** reachable pre-login (was bounced to /auth by router redirect); **profile attribution** — About section with Akash Priyadarshi + GitHub profile/repo links (url_launcher); **Android 16 prep** — SafeArea (top:false) on wallets/objectives/subscriptions pushed screens so gesture-nav bar can't clip the last item (AGP 8.11.1 / Gradle 8.14 / Kotlin 2.2.20 / Flutter 3.44.9 already ≥ 16KB-page requirements); **SMS & UPI Auto-Capture Alerts** — Pennywise-style SMS reading (`READ_SMS`/`RECEIVE_SMS`, `SmsReceiver.kt`) with instant push alert notifications on newly captured payments. **Full Backup & Enhanced CSV Import** — full database JSON export/import for all tables; multi-format CSV importer supporting flexible dates (`dd/MM/yyyy`, `dd-MM-yyyy`, ISO) and case-insensitive header aliases; expanded Indian merchant rule dictionary (80+ merchants). **Pennywise-parity Automation** — VPA handle cleaning, real-time budget threshold warnings ($\ge 80\%$), multi-token & `#hashtag` search, and unrecognized message diagnostic queue. **Backup audit** — every user-entered table syncs (transactions, custom categories, budgets, wallets, recurring, objectives, debts); `rules` (learned auto-categorization) + `merchants` (presentation) + `exchange_rates` (cache) + app-lock/onboarding flags stay local by design (see handoff). `flutter analyze` clean, full 26-file test suite passing (166/166 tests passed). Next: on-device verify v0.2.2.

**Phase: v0.2.0 — income support shipped.** Income is live end-to-end: per-transaction + per-category `is_income` (schema v7, Supabase mirrored), income/expense toggle on both add forms, built-in income categories, home hero income/spend split (green income, red spend), transactions tab income filter, spend aggregates exclude income, sync round-trip, CSV/JSON export `type` column + import. Permissions pass: full manifest set, onboarding asks notification + battery exemption in-app (no manual settings). Manifest now declares INTERNET/ACCESS_NETWORK_STATE (release builds need it for Supabase sync — debug got it injected). `flutter analyze` clean. Full `flutter test` still blocked on Windows host (sqlite3 native-assets, `docs/troubleshooting.md`). CI removed (on-demand release). Next: on-device verify + publish.

## Completed

- [x] Repo `AkashPriyadarshii/kharcha` (private, owner-only)
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
- [x] **Vector Icons & App Launcher Redesign** — `lucide_icons_flutter` (^3.1.15) added for in-app category vector icons (`lib/widgets/category_icon.dart` `CategoryIcon` widget); redesigned launcher icon with geometric K+₹ Monogram emblem on deep ink green (`assets/icon/app_icon.png`). Authored by Antigravity AI Agent for Akash. `flutter analyze` clean.
- [x] **Impeccable Design & Shell UX Pass (P0–P3)** — Home tab, AppBar, and theme overhaul:
  - **Interactive Recent Transactions (P0)**: Tapping a recent tile navigates directly to edit (`/add` with extra); category avatar badges, relative timestamps (`formatTxnTime`), `moneyStyle` amounts, chevron cues, and header "View all" shortcut to Transactions tab.
  - **Metric Consolidation (P1)**: Removed redundant `_IncomeExpenseRow`; consolidated `_HeroPanel` with animated count-up spend anchor, integrated budget indicator, and compact Income / Net metrics row.
  - **Interactive Sparkline Tooltips & Semantics (P2)**: `_TrendCard` fl_chart line touch tooltips show exact month & ₹ spend; `_CategoryBar` computes percentage of total spend with screen-reader `Semantics` and quick "Budgets" button.
  - **Shell Cleanup & Safe Sign-out (P0/P3)**: Removed destructive sign-out from top AppBar, replacing with shortcuts menu; relocated Sign Out to Profile tab under Account with confirmation dialog and auth state cleanup. Over-budget warning alert colors tuned to rich ink-amber `Color(0xFF331E05)` and `Color(0xFFF59E0B)`.
  - **Pull-to-refresh & Recovery**: Wrapped Home dashboard in `RefreshIndicator` and user-friendly error recovery card with Retry.
  - **Test Suite**: Added `test/home_tab_test.dart` covering `HomeSummary`, `formatTxnTime`, `categoryColor`, and full widget interactions. Full test suite: 28 test files, 181/181 tests passing.
- [x] **Pennywise Feature Parity**:
  - **Ground Truth Wallet Sync**: SMS captures update wallet `initialBalance` to align exactly with bank-reported balance without destroying local ledgers.
  - **Income Autopay**: `RecurringTransactions` are processed automatically on app boot.
  - **Privacy-First Export**: Data export feature hashing merchant PII and stripping notes for safe analysis.
  - **Smart Rules UI**: Added `/rules` screen so users can view and define regex rules that get executed in `categorizer.dart`.

## Next up

1. On-device verify v0.2.7 — sideload `kharcha-armv8a-release.apk` (28.3 MB) from v0.2.7 release. Key checks: send a "recharge ending plz recharge with 196rs" SMS → confirm it does NOT appear as an expense; send a real UPI debit SMS → confirm it DOES capture; onboarding Step 1 shows both notification listener and SMS optional paths.
2. Apply migration 0005 in Supabase SQL Editor if not yet done (needed for `bug_reports` table — in-app bug reporting).
3. Editable home sections (Cashew-style reorder — user can rearrange the dashboard tiles).
