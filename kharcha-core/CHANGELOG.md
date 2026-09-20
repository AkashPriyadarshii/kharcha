# Changelog

Discipline: dated section per tag BEFORE tagging. The release workflow fails
the build when `Cargo.toml` version and tag disagree.

## v0.1.2 — 2026-09-20

Deterministic fixes + max-best regex follow-up (76 tests, filter/mandate/corpus + docs sync).

## v0.1.1 — 2026-09-20

Deterministic fixes + max-best regex (76 tests):

- BigBasket WhatsApp promo guard: `engine::parse` sender-aware (WhatsApp/Telegram + credited+wallet without anchor → null), no merchant hardcode.
- Money: exact i64 paise (no f64), filter hoist + lazy amount, hash no-alloc, `replace_all` guard.
- Regex: BAL_RE + bank list + UTR RRN, mandate scoping, bare-ref char-boundary window, 5 P1 parity rows.

## v0.1.1 — 2026-09-20 (notifications)

UPI app push-notification parsing (the other half of India's payment text):

- Parser: `credited by <name>` income payees, VPA handles with underscores
  (`jio_recharge@ybl`), wallet-brand merchants ("credited to your Paytm wallet"
  → Paytm), refund lookahead extended for "processed/completed" tails.
- Corpus: `tests/notifications.rs` — 40 rows across GPay, PhonePe, Paytm,
  Amazon Pay UPI, BHIM, CRED; wallet-balance extraction, ref capture,
  promo/order-tracking rejection.
- Dedupe: cross-channel contract tests (push+SMS same ref → one record;
  ref-less redelivery → hash gate).

## v0.1.0 — 2026-09-16 (first public release, MIT)

Robustness hardening (audit backports from kharcha app tree):

- Dedupe: case-insensitive ref gate, window-bound content-hash gate with ref
  backfill (far-apart ref-less repeats stay real payments).
- Spam: voucher voids only in promo context; real voucher spends parse.
- Parser: `MAX_INPUT_BYTES` (16 KB) guards direct callers, not just engine.
- FFI: `parse_captures` routes via `engine::parse_batch` (single cap authority).

- Unified engine: `parse(sms, sender, ts)` + `parse_batch` + deterministic
  content hash (sender-excluded, footer-proof).
- Full Dart-core port: UPI parser, spam rejection, categorizer, filter,
  money (i64 paise), bill splitter.
- Triple-signal dedupe: ref gate → hash gate → 300s window with ref backfill.
- uniffi Kotlin bridge (`ffi.rs`): 10 fns, 7 records, 1 enum + generated `.kt`.
- Deliberate improvements over Dart: numeric payees kept, voucher promos
  voided, reversals as income, 16 KB input cap, 10k batch/split guards.
- 59 tests green, clippy `-D warnings` clean, two independent audits fixed.
- Published to crates.io (`cargo add kharcha-core`) alongside the GitHub release.
