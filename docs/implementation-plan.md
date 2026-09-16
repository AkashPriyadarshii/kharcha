# Kharcha — Implementation Plan (v0.1.0)

Rust + Kotlin, fully offline, zero Supabase. The Kotlin Compose track is deleted — the
historical plan below that is retained only in the changelog.

## Status: v0.1.0 shipped (repo = Kotlin + Rust only)

**Phase 0 — `kharcha-core` crate** ✅
- 9 modules: `categorize`, `dedupe`, `engine`, `ffi`, `filter`, `money`,
  `non_transaction`, `parser`, `split`. 56/56 tests.
- Deterministic: parse → dedupe → categorize, all in Rust.

**Phase 0.5 — India bank formats** ⏳ post-Release 1 (data-driven)
- Split into a schema-driven sub-track after Release 1.

**Phase 1 — UniFFI** ✅
- `parse_capture`, `parse_captures`, `check_capture`, `categorize_merchant`,
  `normalize_merchant_text`, `parse_amount` (paise i64), `is_spam`,
  `split_bill`, `apply_filter`, `encode_inbox_line`, `max_body_bytes`,
  `max_batch_items`. Kotlin bindings committed; `.so` (arm64) in `jniLibs`.

**Phase 2 — Kotlin Compose rewrite** ✅ (swap-over complete)
- `android-app/`: captures wired (SmsReceiver + UpiNotificationListener →
  `CaptureEngine.ingest` — decisions in Rust), Room DB, Home/All/Add/Edit
  sheets, wallets (auto from bank messages), budgets, CSV export, biometric
  lock, category-learn.
- Kotlin Compose/Supabase deletion folded in: `lib/`, `test/`, `android/`,
  `supabase/`, `pubspec.*` gone.

## Forward plan

1. **Device smoke test** — sideload debug APK; SMS + notification access; verify
   capture, dedupe, skip, backfill live.
2. **Autopay / recurring** — Rust side: detect cadence by merchant+amount,
   roll due; app: due list + pay-one-tap.
3. **Release 1** — version bump, `flutter build apk` equivalent
   (`./gradlew assembleRelease`? no — `build apk --release --split-per-abi`
   recipe from AGENTS), tagged release + asset.
4. **Banks data-driven** — `BankFormat` engine (narration regex table +
   direction keywords) with HDFC/SBI/ICICI; remaining banks only when live
   captures show them.
5. **v0.1.x hardening** — whatever the smoke test finds.

## Definition of done per step

- Ponytail + standards (see CLAUDE.md / AGENTS.md)
- Test file(s) for non-trivial logic
- `flutter analyze` (legacy) replaced by: `cargo test` in `kharcha-core` +
  `./gradlew :app:assembleDebug` in `android-app`
- Smoke test on Android 12+ device
- `docs/state.md` updated
- PR to `main`, owner reviews + merges