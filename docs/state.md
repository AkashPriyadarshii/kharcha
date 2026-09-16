# Kharcha — Project State

> Update after every merge. Source of truth for where the project stands.

## Current status

**v0.1.0 — Kotlin + Rust only. Swap-over complete (2026-09-16).**

Kotlin Compose, Dart, Supabase, and the legacy Kotlin parser are gone from the repo.
`lib/`, `test/`, `android/` (incl. `parser-core`), `supabase/`, `pubspec.*` deleted.
Repository = `android-app/` (Kotlin Compose) + `kharcha-core/` (Rust) only.

- **`kharcha-core` v0.1** — deterministic UPI capture engine in Rust:
  `categorize`, `dedupe`, `engine`, `ffi`, `filter`, `money`, `non_transaction`,
  `parser`, `split`. 56/56 tests. paise-i64 amounts, batch API, dual-audit
  hardening (abs_diff timestamps, batch caps, panic-free slicing). UniFFI
  exports: `parse_capture(s)`, `check_capture` dedupe, `categorize_merchant`,
  `normalize_merchant_text`, `parse_amount`, `is_spam`, `split_bill`,
  `apply_filter`, `encode_inbox_line`, `max_body_bytes`, `max_batch_items`.
- **`android-app/`** — Kotlin Compose, AGP 8.11.1 / Gradle 8.14 / Kotlin 2.2.20,
  Compose BOM 2025.10, Material3 ink-green on warm paper. Room DB (categories
  1–12 + income, ~55 builtin rules, transactions, wallets, budgets).
  Capture: `SmsReceiver` + `UpiNotificationListener` → `CaptureEngine.ingest`
  (spam/parse/dedupe in Rust, app only stores). Screens: Home (month totals,
  wallets, budgets, recent), All transactions, Add sheet, Edit sheet
  (teach-category writes a learned rule), CSV export, app lock (biometric).
  `applicationId com.kharcha.app` — the live app, overwrites the old Kotlin Compose
  install in place (same signing identity, debug-signed).
- Bindings committed; `.so` (arm64) built from Desktop `kharcha-core` dist.
  `buildKharchaCore` gradle task disabled — dist/ is the source of truth.

**Prior state (historical):**

Phase 0–1 (kharcha-core crate + UniFFI) merged in PR #4. Phase 2 (Compose
rewrite) began on `feat/compose-rewrite`; parity features (wallets, budgets,
export, lock, edit/learn) landed; swap-over deletion folded into v0.1.0.

Compose app history below is retained for the changelog / release record only —
no longer part of the product. Next: device smoke test (sideload APK, SMS +
notification capture), then Release 1.

## Next up

1. Device smoke test — sideload `android-app/app/build/outputs/apk/debug/app-debug.apk`,
   grant SMS + notification access, verify capture/dedupe live.
2. Autopay/recurring engine (Rust-side pattern detect + due roll).
3. Release 1 — tagged release APK on GitHub.
4. Banks data-driven: `BankFormat` engine + HDFC/SBI/ICICI; remaining banks only
   when live captures demand.