# kharcha-core — State

> Update after every merged change. Single source of truth for where this crate stands.
>
> PUBLIC: https://github.com/AkashPriyadarshii/kharcha-core (MIT, `main`).

## Current status

**v0.1 done (2026-09-16).** 49 tests green (20 unit + 29 parity), clippy zero
warnings, one dep (`fancy-regex` — Dart lookahead ports verbatim; 0.14 rejects
`(?-u)` so `\d`→`[0-9]` / `\s`→`[ \t\n\x0B\f\r]` is mechanical, `\b` stays
Unicode — documented in non_transaction.rs).

Better-than-parents bets shipped:
- `engine::parse(sms, sender, ts)` — single entry, sender-aware dispatch shape
  (generic backend today), `parse_batch()` for backlog drains
- triple-signal dedupe: ref gate → content-hash gate (FNV-1a64, footer-proof,
  unlike the legacy app md5(body)) → 300s window with ref backfill
- i64 paise end to end (both parents float at the edge)

## Completed

- [x] md skeleton (AGENTS/CLAUDE/STATE/CHANGELOG/README)
- [x] money, split, categorize, filter (Dart parity, incl. `2.345→235`)
- [x] non_transaction + parser (full upi_parser.dart port)
- [x] dedupe (insertCaptured rules + hash signal)
- [x] parity corpus (29 rows, all green) + demo CLI
- [x] clippy clean

## Next up (needs "go" per slice)

1. **FFI bindings done (2026-09-16).** `ffi.rs` + scaffolding + `cdylib`;
   `bindings/kotlin/uniffi/kharcha_core/kharcha_core.kt` (74 KB) generated
   with uniffi-bindgen 0.32.1 — all 10 fns + 7 records + 1 enum verified.
   Regen: `uniffi-bindgen generate --library ./target/debug/kharcha_core.dll --language kotlin --out-dir ./bindings/kotlin` (run from crate dir).
2. v1.x: bank backends behind `engine::parse` (the legacy app factory order as reference)
3. Corpus growth: harvest harder SMS samples from kharcha test dir + the legacy app bank tests

Direction locked (owner): Kotlin/Rust is being removed. Consumers are
Kotlin (uniffi/JNI) + Rust only. `docs/INTEGRATION.md` (human) +
`docs/AGENT-INTEGRATION.md` (agent) define how to apply this core.

## Independent audit (2026-09-16) — all 16 fixed

Subagent audit found 5 critical / 7 major / 4 minor; all fixed, 54 tests green:
- split count clamp (10k, FFI OOM), punct-class `[[` typo, money 2^63 `>=`,
  VPA UTF-16 units, dedupe truncated-seconds drift
- sender dropped from content hash (cross-channel gate now real), ref lowercased
- parity rows added: balance/mask/bank/review, Dart-quirk pins, non-ASCII pins
- wallet/category enrichment documented as caller-owned; ffi nesting proven by test
- CLAUDE/README synced (uniffi dep, `(?i:)`+mechanical classes, corpus policy)

## Web research (2026-09-16) — Miss 1 fixed

UPI Number / mobile@handle is the dominant P2P format and Dart sends it to
Unknown. Fixed (owner-approved deliberate improvement over Dart): 8–10 digit
merchant names kept, 1–7 / 11+ still blocked — in both the recipient/fallback
lookahead and GENERIC_NAME_RE. 55 tests green, no regressions.
Watchlist (no code): Tap & Pay vocab (verbless formats unseen — collect samples
first). v1.x: multi-currency amounts (AED/SGD…), UPI Lite top-up transfer-type.

## Premortem (2026-09-16) — 3 fixes + accepted risks

- `voucher` voids a message (cashback-voucher promos faked income) — fixed + rows
- `reversed|reversal` are money-in (ATM reversals were dropped) — fixed + row
- 16 KB input cap in `engine::parse` (FFI paste-attack spins regex) — fixed + row
- Accepted: dual-SIM sender prefixes (v1.x sender normalization), salary→Unknown
  merchant (income still correct), multi-txn SMS takes first amount, holds
  ("blocked Rs 500") skipped until the debit SMS, fraud detection out of scope,
  transliterated merchants → Unknown (pinned). Pure functions — thread-safe.