# Kharcha — Project State

> Update after every merge. Source of truth for where the project stands.

## Current status

**v0.1.1 — Pan-Indian parser + P2P contact resolution. Released 2026-09-20.**

`kharcha-v0.1.1-arm64-v8a.apk` (33.4 MB, versionCode 2) published to [GitHub Releases](https://github.com/AkashPriyadarshii/kharcha/releases/tag/v0.1.1).

**What shipped in v0.1.1:**
- `kharcha-core` now covers all major Indian banks (SBI, HDFC, ICICI, Axis, Kotak, PNB, BOB, Canara, Union, IDFC FIRST, IndusInd, Federal, Yes Bank) + all UPI apps (PhonePe, GPay, Paytm, CRED, BHIM, Navi, Tata Neu). ATM withdrawal, UPI Lite, Rupay Credit on UPI, NACH mandate formats added. Non-transaction filter hardened to reject loan offers, EMI promos, bill reminders, pre-approved credit alerts. 60/60 tests passing.
- P2P contact resolution: `CaptureEngine.resolveMerchantName` resolves phone-number VPAs to device contact names via `ContactsContract.PhoneLookup`, 100% offline.
- Onboarding step 1 adds "P2P Contact Names (Optional)" permission card. Settings capture section shows contact resolution status row.

Kotlin Compose, Dart, Supabase, and the legacy Kotlin parser are gone from the repo.
`lib/`, `test/`, `android/` (incl. `parser-core`), `supabase/`, `pubspec.*` deleted.
Repository = `android-app/` (Kotlin Compose) + `kharcha-core/` (Rust) only.

- **Dedicated Budgets & Goals Screens:** Shipped `BudgetsScreen` (category limits, rollover, segmented meters, cap removal) and `GoalsScreen` (milestone progress, `+ Save` deposit dialog, delete goal). Clutter removed from `HomeScreen`.
- **Home Feed Customization:** Top-right `Customize` toggle in header opening `CustomizeHomeDialog` for persistent section visibility toggling (Budgets, Goals, Subscriptions, Daily Burn).
- **Atomic Interaction Logging:** `CrashLog` buffer expanded to 1000 lines with atomic action logs across all user mutations, navigation changes, and engine processes.
- **Brutalist Design & Polish:** 1dp `outlineVariant` card borders, 8dp corner radius, discrete 10-block `SegmentedMeter` telemetry, tabular numerals (`tnum, zero`), two-tone hero numbers, and tactile press micro-interactions.

- **`kharcha-core` v0.1** — deterministic UPI capture engine in Rust:
  `categorize`, `dedupe`, `engine`, `ffi`, `filter`, `money`, `non_transaction`,
  `parser`, `split`. 59/59 tests (24 unit + 35 parity). paise-i64 amounts, batch API, dual-audit
  hardening (abs_diff timestamps, batch caps, panic-free slicing). UniFFI
  exports: `parse_capture(s)`, `check_capture` dedupe, `categorize_merchant`,
  `normalize_merchant_text`, `parse_amount`, `is_spam`, `split_bill`,
  `apply_filter`, `encode_inbox_line`, `max_body_bytes`, `max_batch_items`.
- **`android-app/`** — Kotlin Compose, AGP 8.11.1 / Gradle 8.14 / Kotlin 2.2.20,
  Compose BOM 2025.10, Material3 ink-green on warm paper. Room DB (categories
  1–12 + income, ~55 builtin rules, transactions, wallets, budgets).
  Capture: `SmsReceiver` + `UpiNotificationListener` → `CaptureEngine.ingest`
  (spam/parse/dedupe in Rust, app only stores). Listener allowlisted to UPI
  apps + banks (GPay/PhonePe/BHIM/CRED/Paytm/Amazon Pay) — no arbitrary-app
  parsing; `isOngoing` gate removed (GPay posts confirmations as sticky).
  Screens: Home (month totals, wallets, budgets, recent), All transactions,
  Add sheet, Edit sheet (teach-category writes a learned rule), CSV export,
  app lock (biometric OR device PIN — `BIOMETRIC_STRONG |
  DEVICE_CREDENTIAL` so fingerprint-less phones can't be locked out).
  FAB = quick-add (amount only, IME Done saves); empty-state/transactions =
  full add sheet. `applicationId com.akash.kharcha.app` — fresh install identity
  (changed from `com.kharcha.app` so release sideloads land as a brand-new app
  — no signature-clash with prior installs).
- **Resilience.** Uncaught-exception handler + capture-channel failures append
  to `filesDir/kharcha.log`; Settings → "Share debug log" exports via
  FileProvider. SmsReceiver/Listener coroutine scopes have
  `CoroutineExceptionHandler` (offer/spam SMS can't crash the app).
  `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` permission; listener watchdog in
  `MainActivity.onResume` toggles ComponentName to re-bind a killed
  NotificationListenerService (gated on user opt-in via `UserPrefs.listenerWanted`).
- **Security, Reliability & Interaction Hardening (Audited 2026-09-17).**
  - **Startup Crash Squash:** Corrected Kotlin property initialization order in `AppViewModel.kt` so `selectedMonth`, `budgetSpends`, `budgetCarry`, and `totals` initialize before the `init` block executes.
  - **Onboarding Dark Mode Contrast:** Wrapped `OnboardingScreen` in `Surface(color = background, contentColor = onBackground)` and set explicit high-contrast colors on all headers to prevent dark text on dark `#12120E` surfaces.
  - **Navigation State Preservation:** Configured `saveState`/`restoreState` and `launchSingleTop` across bottom bar tabs in `MainActivity.kt`.
  - **CrashLog Thread Safety:** Added `diskLock` synchronization on `CrashLog.kt` disk writes.
  - **Streaming CSV Export:** Switched `ExportButton.kt` to direct `bufferedWriter` streaming into SAF `OutputStream`, eliminating in-memory `StringBuilder` OOM risks.
  - **Monet Theme Dark Clamping:** Clamped `KharchaTheme` dynamic dark theme surfaces and borders to ink-green/warm paper palette.
  - **Secured `SmsReceiver`:** Added `android.permission.BROADCAST_SMS` to prevent 3rd-party intent injection attacks; removed debug action.
  - **Ingestion Concurrency:** Added `Mutex` in `CaptureEngine.ingest` to eliminate race condition duplicate inserts between SMS and notification listeners.
  - **UI Bug Fix:** Removed duplicate note field in `AddSheet`.
  - **Ergonomics:** Added `imePadding()`, `verticalScroll()`, and numeric keypad options to `BudgetSheet` and `GoalSheet`.
  - **Theming:** Completed `LightColors` surface and outline tokens (`surfaceVariant`, `outlineVariant`, `outline`) for full ink-green/warm paper compliance.
  - Cleaned dead pre-Q storage branches in `ExportButton` (minSdk 32 guarantee).
- Bindings committed; `.so` (arm64) built from Desktop `kharcha-core` dist.
  `buildKharchaCore` gradle task disabled — dist/ is the source of truth.
- **DB safety (merged).** Throttled VACUUM on open (30d);
  full-file backup/restore (`.kharchabackup` via `VACUUM INTO` + SAF, validated
  before swap, restart on import); soft deletes (`isDeleted`, DB v5 via 4→5
  rebase) with Trash screen (restore per row, purge with confirm). SQLCipher
  deferred: new dep + key-management design need owner approval.
- **Budget pack (merged).** Overall monthly ceiling via
  budgets sentinel id 0 (seed ids start at 1); daily burn rate under the hero
  when the cap is set on the live month; one-month unspent rollover computed
  at read time (overspend never carries); savings goals = new `goals` table
  (DB v4) with manual log-savings sheet. No auto-detect, no compounding.
- **Settings pack (merged).** Rules/Categories/Accounts
  manager screens; theme mode + Monet toggle; lock grace + FLAG_SECURE;
  daily summary worker (inexact alarm, boot re-arm, time picker); wipe +
  direct log export. Category hide + wallet archive leave pickers (DB v6 via 5→6 migration).
- **Feed filters (merged).** AllTransactions gains five
  in-memory rows, no migration: category chips, method chips (UPI/Cash/Card/
  Wallet), amount presets (500/2k/10k), wallet chips (doubles as the wallet
  browser — wallets have no other UI), date presets (7D, Month, Cycle 25–24
  for statements, Custom via date pickers). Method filter only matches manual
  entries until capture tags paymentMethod.
- **Backlog import (merged).** `BacklogScan` runs once
  after onboarding (flag `backlog_scanned`): last-90-days inbox, Rs/INR/₹ SQL
  prefilter, 500 cap, every message through `CaptureEngine.ingest(quiet=true)`
  so per-insert buzz stays silent; Toast reports the count. Skips without SMS
  permission, never repeats on intro re-run.
- **Catchup (merged).** Ingest-time
  budget alerts (50/80/100, prefs-deduped); transfer/refund auto-pairing +
  manual link via note + on-demand Transfers category (no migration, no new
  FFI — NDK absent so the .so can't grow exports); autopay suspects card;
  quick-add merchant + type; rescan inbox button (re-uses BacklogScan);
  wallet balance set; new categories; bulk select/delete/categorize/link; split-bill UI on splitBill.
- **Stack Integration & Release.** All 6 stacked PRs (#8 backlog, #11 filters, #9 budgets, #10 db-safety, #12 settings, #13 catchup) merged into main. Room schema linear migrations v1→v6 verified. Release APK built cleanly via `./gradlew.bat :app:assembleRelease`.

**Prior state (historical):**

Phase 0–1 (kharcha-core crate + UniFFI) merged in PR #4. Phase 2 (Compose
rewrite) began on `feat/compose-rewrite`; parity features (wallets, budgets,
export, lock, edit/learn) landed; swap-over deletion folded into v0.1.0.

**Dedupe semantics (since audit-hardening, PR #6):** content-hash gate is
window-bound (±5 min, same as the amount window) — same content hours apart
is a genuine repeat order, captured; ref gate compares case-insensitively
(`t2408…` SMS vs `T2408…` push = one payment); a skip that would backfill a
ref now needs hash equality or both-sides-ref-less legacy evidence, so
back-to-back same-amount taps insert. Voucher spam kill narrowed to promo
context — "Paid Rs 200 using voucher" and "debited for voucher purchase"
parse as spends. Input cap 16 KB enforced in the parser itself; batch
calls clamp at `MAX_BATCH_ITEMS`. `uniffiEnsureInitialized` failure degrades
to a logged error (no boot loop on a corrupt .so).

Compose app history below is retained for the changelog / release record only —
no longer part of the product. Next: device smoke test (sideload APK, SMS +
notification capture), then Release 1.

## Next up

1. Device smoke test — sideload `kharcha-v0.1.1-arm64-v8a.apk`, grant SMS + notification + contacts access, verify P2P name resolution on a real UPI transaction.
2. Autopay/recurring engine — Rust-side pattern detect + due roll.
3. Reports upgrade — category trend, income vs spend breakdown.
4. v0.1.2 — ongoing bank coverage gaps from live captures.