# Changelog

All notable changes to Kharcha. Format: `[Version] — Date — Summary`.

## [v0.2.9] — 2026-08-23

- **Accounts vs Wallets Auto-Management** — Split the Wallets screen into `Accounts (Auto-tracked)` and `Wallets (Manual)`. Upgraded the auto-capture engine: if an SMS arrives with an unrecognized bank account mask (e.g., HDFC 1234), Kharcha will now automatically create that account on the fly instead of dumping it into the default wallet.
- **Native Instant Background Notifications** — Added instant native Android push notifications (from Kotlin) the millisecond an SMS or push is captured. This gives users immediate feedback that Kharcha logged the transaction without needing to open the app or wait for the background parse.
- **Auto-Update Engine Overhaul** — Fixed a critical bug where the GitHub release asset name mismatch broke auto-updates globally. The update engine now properly identifies the APK, and pushes a persistent local notification if an update is found so the user can easily install it even if they dismiss the dialog.

## [v0.2.8] — 2026-08-23

- **AppLogger & Crash Reporting** — Replaced raw print statements with `AppLogger` Singleton and `app_errors` table for offline telemetry. System logs screen added to profile tab.
- **Pennywise Parity Integration** — Added True Balance Extraction & Wallet Balance Sync (captured SMS calculates delta to update initialBalance for ground truth).
- **Automation Upgrades** — Added Income Autopay / Subscription Automation. Added Smart Rules engine UI (manage learned and custom categorization rules).
- **Privacy-First Export** — Added PII-masked CSV export for transaction analysis. All new logic verified with unit tests.

## [v0.2.7] — 2026-08-23
- **Non-Transaction Spam & Reminder Rejection Filter** — `_nonTransactionRe` in `lib/core/upi_parser.dart` immediately returns `null` (step 0, before any amount extraction) for recharge expiry notices ("plz recharge with 196rs", "validity expires"), bill due/overdue alerts, OTP/verification codes, pre-approved loan promos, payment/collect requests, and failed/declined transactions. Non-spends are never stored as expenses.
- **Onboarding SMS step** — Step 1 ("Auto-capture UPI & Bank SMS") now shows an optional secondary action to enable SMS capture (`RECEIVE_SMS` + `READ_SMS`) alongside the existing notification listener path. Either path alone marks the step done so the user can proceed. `_PermissionStep` gains optional `secondaryActionLabel`/`secondaryDone`/`onSecondaryAction` params; `_stepDone` for step 1 is now `_capture || _sms`.
- **SMS runtime permission channel** — `MainActivity.kt` gains a `requestSmsPermission` method handler (requests both `RECEIVE_SMS` + `READ_SMS` at runtime) and `getCaptureStatus` now returns a `sms` boolean key alongside the existing `capture`/`notifications`/`battery` keys.
- **Full Notification & Background Automation Test Suite** — `test/capture_inbox_test.dart` added; `test/upi_parser_test.dart` & `test/transaction_filter_test.dart` expanded. Total: **187/187 tests passing**, 28 files, 0 analyzer warnings.
- **SMS & UPI Multi-Bank Parser Hardening** — robust regex cascade for HDFC Bank SMS balance formats, SBI transfer messages, Axis Bank credit card notifications, and refund messages with VPA cleaning.
- **Budget Threshold Alert Triggers** — automated push notifications when an auto-captured transaction pushes a category budget to ≥80% or >100%.
- **Diagnostic Unrecognized Queue** — unparsed financial messages stored into `unrecognized_inbox.jsonl` (circular buffer) for zero-data-loss diagnostics.
- **arm64 APK** — `app-arm64-v8a-release.apk` (28.3 MB) built debug-signed for sideloading. `pubspec.yaml` bumped to `0.2.7+9`. Auto-update trigger will prompt installed devices.

## [Site] — 2026-08-09

- **Mobile UI/UX pass (marketing site)** — the landing page (`site/index.html`, GitHub Pages) is now genuinely mobile-first:
  - **Mobile nav** — hamburger menu (≤820px) with slide-down panel, close on link tap / Esc, `aria-expanded`/`aria-controls`. Previously the 5-link nav + theme toggle overflowed a phone-width header.
  - **~99% lighter screenshots** — six 2048×3640 PNGs (~11.6 MB total) → responsive WebP (~10–30 KB each) with `srcset`/`sizes`. Hero `HOME` gets 480/900 w candidates, gallery uses 660 w.
  - **Readable on phones** — screenshot grid goes 2 columns at ≤820px and single column (max 280px) at ≤520px, so the screenshots are actually legible.
  - **Touch targets** — theme toggle 38→44px, nav toggle is 44px.
  - **Dark-mode consistency** — hero phone border now uses `--img-border` (was hard-coded white in dark mode).
  - **iOS Safari blur** — `-webkit-backdrop-filter` added for the sticky header + mobile nav.
  - **Social share** — new 1200×630 `site/social-card.jpg` (27 KB) replaces the 1.9 MB PNG for `og:image`/`twitter:image`.
  - **Reduced motion** — `prefers-reduced-motion` disables hover transforms + smooth scroll.
  - README screenshot table updated to WebP. Deploy unchanged (`.github/workflows/pages-deploy.yml` already stages `site/` + `screenshots/`).

## [v0.2.6] — 2026-08-09

- **Dark theme + theme mode** — full dark theme (warm near-black surfaces, same ₹-green identity) plus a Theme picker in Profile → Settings (Follow system / Light / Dark). Choice persists per-device in a JSON file (`theme_mode.json`, same pattern as app lock); startup loads it, `MaterialApp` wires `darkTheme` + `themeMode`. `lib/core/theme.dart` gains `kharchaDarkTheme()`; hardcoded whites replaced with scheme containers so both themes read correctly. `test/theme_mode_test.dart`.
- **In-app bug reporting** — Profile → Settings → **Report a bug**. Two channels: **Email** (recommended — prefilled `mailto:` to the owner with device/OS/version context, no account needed) or **In-app** (signed-in user writes the new `bug_reports` table on Supabase, migration 0005; owner reads in the dashboard Table Editor). No GitHub account required for reporters. `lib/data/bug_reporter.dart` + `test/bug_reporter_test.dart`.

## [v0.2.4] — 2026-08-09

- **Home redesign** (Cashew-inspired) — greeting header with your name ("Good evening, Akash"); Income this month + Spent today as sibling colored cards (mint income / red expense); compact 6-month spend trend card under the hero. Hero keeps the count-up ₹ panel, now with amber over-budget state.
- **Reports upgrade** — Income / Spent / Net summary strip at top (Net colors by sign); category pie slices show bold white percentage labels; month total in the pie center. Same data, read at a glance.

## [v0.2.3] — 2026-08-09

- **Auto-update** — app checks GitHub releases once per app open (throttled to **once/day auto + 3/hr manual** from Profile); prompts to download + install when a newer release with a real `kharcha-armv8a-release.apk` asset exists. `REQUEST_INSTALL_PACKAGES` + FileProvider in AndroidManifest, `installApk` + `getVersion` channel in MainActivity, `update_checker.dart` (semver compare, asset-size verify, silent-fail on 429/offline). `test/update_checker_test.dart` covers version comparison. Trigger = pubspec version bump; no bump = no prompt. Rate caps keep 1000 devices under GitHub's per-IP limit.
- **Name fix** — display name now reads `name` OR `full_name` from Supabase user metadata (Google OAuth stores `full_name`; the in-app edit writes `name`). Previously always fell back to "Kharcha user".
- **App lock fix** — returning from the biometric prompt no longer re-locks the screen; the lifecycle observer distinguishes the auth prompt's own background from a real user background (`_wasLockedAtPause`).
- **Home UX pass** — removed the misleading bell icon (it opened capture *settings*, not notifications); new pencil icon in the AppBar opens a manage sheet (categories, wallets, subscriptions, goals, credit/debt, split) without digging through Profile; Profile gains an **Auto-capture setup** tile that re-runs onboarding (capture/notifications/battery) anytime; sign-out now asks for confirmation before leaving.

## [v0.2.2] — 2026-08-09

- **Real release signing** — generated `kharcha-release.jks` keystore, wired via gitignored `android/key.properties`. Release builds sign with it (debug fallback only when key.properties absent). Fixes reinstall-over-upgrade failures; survives the Android 16 24h sideload wait.
- **Money precision audit** — every amount boundary routes through `parseAmount` (2dp rounding): add/quick-add expense, budget limit, wallet balance, savings goal target + add, debt amount, subscription amount, CSV import, and the UPI/bank notification parser (was raw `double.parse`, comma bug fixed). New `test/money_test.dart`.
- **Terms screen reachable pre-login** — router redirect whitelisted `/terms` so signed-out users aren't bounced to `/auth`.
- **Profile About section** — Akash Priyadarshi + GitHub profile/repo links (opens externally). `url_launcher` promoted to direct dep.
- **Android 16 prep** — SafeArea (bottom) on wallets/objectives/subscriptions pushed screens (gesture-nav bar can't clip the last item). AGP 8.11.1 / Gradle 8.14 / Kotlin 2.2.20 / Flutter 3.44.9 already satisfy the 16KB-page + targetSdk requirements.
- **Repo hygiene** — tracked `android/build/reports/*.html` artifact removed + `/android/build/` gitignored (was inflating GitHub language stats); README "For AI agents" quick-clone block removed.
- **Backup audit** — all user-entered tables sync (transactions, custom categories, budgets, wallets, recurring, objectives, debts). `rules`/`merchants`/`exchange_rates` + app-lock/onboarding flags stay local by design.

## [unreleased]

- **Pennywise Architecture Parity & Deep Upgrades** —
  1. *Full Backup JSON Export/Import*: Added `exportFullBackup` and `importJson` across [`lib/data/exporter.dart`](file:///C:/Users/saves/Desktop/kharcha/lib/data/exporter.dart) and [`lib/data/importer.dart`](file:///C:/Users/saves/Desktop/kharcha/lib/data/importer.dart) supporting full database snapshots (transactions, budgets, debts, recurring, goals, wallets, custom categories, and metadata) with automatic table restoration.
  2. *Flexible Multi-Source CSV Importer*: Enhanced `importCsv` to support case-insensitive headers, column aliases (`Merchant`, `Payee`, `Vendor`, `Amount`, `Total`, `Date`, `Description`, `Bank`, `UPI Ref`), and flexible date schemes (`dd/MM/yyyy`, `dd-MM-yyyy`, ISO).
  3. *Comprehensive Indian Merchant Categorizer*: Expanded `ruleMap` in [`lib/data/database.dart`](file:///C:/Users/saves/Desktop/kharcha/lib/data/database.dart) with over 80+ top Indian merchants and services (KFC, Starbucks, Namma Yatri, Fastag, Fuel/Petrol pumps, Ajio, Nykaa, Blinkit, Instamart, Netmeds, Tata 1mg, Tata Power, Indane Gas, etc.).
  4. *Raw UPI VPA & Merchant Name Normalization*: Upgraded `_cleanMerchant()` in [`lib/core/upi_parser.dart`](file:///C:/Users/saves/Desktop/kharcha/lib/core/upi_parser.dart) to automatically normalize ugly raw VPA handles (`paytmqr281001@paytm` $\rightarrow$ `Paytm Merchant`, `swiggy.orders@icici` $\rightarrow$ `Swiggy`).
  5. *Proactive Real-Time Budget Threshold Alerts*: Added `showBudgetThresholdAlert()` in [`lib/data/notifications.dart`](file:///C:/Users/saves/Desktop/kharcha/lib/data/notifications.dart) and category budget checker in `TransactionRepository`; auto-triggers high-priority push warnings when spending reaches $\ge 80\%$ or exceeds $100\%$ limit.
  6. *Multi-Token & Hashtag Search Engine*: Enhanced [`lib/core/transaction_filter.dart`](file:///C:/Users/saves/Desktop/kharcha/lib/core/transaction_filter.dart) to support multi-token queries and `#tag` searching in notes (e.g. `Swiggy #lunch`, `#goa2026`).
  7. *Unrecognized Message Diagnostic Queue*: Added `unrecognized_inbox.jsonl` queue in [`lib/data/capture_inbox.dart`](file:///C:/Users/saves/Desktop/kharcha/lib/data/capture_inbox.dart) capturing skipped financial messages for diagnostics.
  8. *Subscriptions Monthly Commitment Hero*: Added a live recurring commitment summary (`₹/mo committed`, active count, and due count) in [`lib/screens/subscriptions_screen.dart`](file:///C:/Users/saves/Desktop/kharcha/lib/screens/subscriptions_screen.dart).
  9. *Credit/Debt Ledger Filters & Settle UX*: Added pending/all filter toggle and strikethrough styling for settled records in [`lib/screens/debts_screen.dart`](file:///C:/Users/saves/Desktop/kharcha/lib/screens/debts_screen.dart).
- **Audit & Test Suite Hardening** — Full 26-file test suite passing (166/166 tests) with zero analyzer issues.
- **Live fixes (v0.2.2)** — (1) **UPI capture was dead: path mismatch.** Kotlin `UpiNotificationListener` wrote the inbox to `context.cacheDir` (`cache/`), Dart read `getApplicationCacheDirectory()` (`code_cache/`) — a different dir, so the inbox was never drained and every capture silently vanished. Dart now reads `getTemporaryDirectory()` (= `getCacheDir()`). (2) **Real-time capture** — inbox drained every 30s (was startup-only), so payments appear ~live while the app is open. (3) **Feature deletes now sync** — deleting a budget/wallet/recurring/objective/debt/custom category writes a tombstone (`deleted_features`, schema v11) that the SyncEngine drains as a remote DELETE + skips on pull; no more resurrection after reinstall. (4) **App lock fixed** — `MainActivity` is now `FlutterFragmentActivity` (local_auth requires it for the biometric prompt; `FlutterActivity` made `authenticate()` fail). (5) **Profile "Open source" → "Source"** — matches the all-rights-reserved LICENSE (view-only, no fork/copy/derivative/commercial).
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
