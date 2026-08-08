# Kharcha — Project State

> Update after every merged PR. This is the single source of truth for where the project stands.

## Current status

**Phase: v0.1.0 feature-complete, on-device verify + fixes in flight.** 4.1-4.5 shipped (tabbed shell). 5.1 export + 5.2 app lock landed. **Post-verify fixes landed:** stale-aggregate bug fixed (aggregate providers now derive from the transactions stream — budget/home/reports refresh on every insert instead of staying stale until app restart), Home tab shows recent transactions, first-launch onboarding (capture + battery + summaries), battery-optimization ignore + POST_NOTIFICATIONS manifest entries. `flutter analyze` clean; targeted suites pass. Next: rebuild+install on device, finish on-device verify, 5.4/5.5 release (deferred until Akash tests).

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

## Next up

1. **On-device verify (Akash)** — sideload `build\app\outputs\flutter-apk\app-debug.apk` on Android 12+ phone (USB): 2.3 capture, 3.1 sync, 4.1-4.5 screens, 5.1 export, 5.2 app lock. No device connected on dev machine.
2. Step 5.4/5.5: Final regression + release v0.1.0 (deferred until Akash tests)

## In progress

- **Step 3.1/3.2** on-device verify (add offline → sync when online; daily 9PM + Sunday weekly push)

## Next up

1. Step 2.3 verify on device (adb fake UPI notification → auto-add once; dup not re-added)
2. Step 4.1: Home dashboard — today ₹, this month ₹, budget left, category bars
3. Step 4.2: Transactions tab — list, search, filters
