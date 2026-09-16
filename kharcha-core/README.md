# kharcha-core

Rust port of the deterministic core of [Kharcha](../kharcha) — India's UPI expense tracker.

Rule-based, zero AI: SMS/notification text in → structured payment out.

## Layout (mirrors the Dart/Kotlin sources 1:1)

```
src/
  lib.rs        — public API (see below)
  engine.rs     — parse(sms, sender, ts): THE entry point. Sender-aware dispatch
                  (generic backend today, bank backends plug in v1.x), batch API,
                  deterministic content_hash per capture
  money.rs      — parse_amount → i64 paise (port of lib/core/money.dart)
  parser.rs     — parse_upi_notification (port of lib/core/upi_parser.dart)
  non_transaction.rs — spam regex (folded from parser)
  categorize.rs
  split.rs
  filter.rs
  dedupe.rs     — triple-signal: ref gate + content-hash gate + 300s window
  ffi.rs        — uniffi surface (Kotlin first): parse_capture, check_capture,
                  categorize_merchant, apply_filter, split_bill, parse_amount,
                  is_spam, encode_inbox_line. Core stays FFI-agnostic.
tests/parity.rs — Dart-vs-Rust corpus parity harness (29 rows)
src/bin/demo.rs — smoke CLI: cargo run --bin demo -- "<sms text>" [sender]
docs/           — INTEGRATION.md (humans: consume this core), AGENT-INTEGRATION.md (agents: bind/evolve it)
```

## Why better than both parents

- **One engine, not three.** Kharcha parses the same SMS up to 3 ways (Dart
  generic, Kotlin generic, bank fleet) and reconciles with an if/else.
  Pennywise has one engine but no generic fallback ordering. Here:
  `engine::parse()` is the only door in.
- **Triple-signal dedupe.** kharcha: ref + window. pennywise: md5(body) —
  breaks when carriers append footers. Here: ref → content hash
  (sender|amount|direction|merchant|ref, footer-proof) → window.
- **Exact money.** Both parents float at the edge (`double` 2dp / BigDecimal).
  Here: i64 paise end to end.
- **Batch API.** `parse_batch()` drains 1000-SMS backlogs with compiled-once
  regexes. Neither parent has it.
- **Gate: `cargo test` + `cargo clippy -- -D warnings`.** No Windows-sqlite
  test curse, no Gradle.

## Run

```bash
cargo test            # full gate: unit + parity
cargo run --bin demo -- "Spent Rs 540 on Swiggy via UPI ref 123456789012"
```

## Rules

- i64 paise internally. Parse/format at the edge. No float money math, ever.
- `fancy-regex` only where Dart uses lookahead — patterns stay near-verbatim to the Dart source for parity diffing. Replace only if a benchmark proves a hot path.
- Regex ports are ASCII-classed mechanically (`\d`→`[0-9]`, `\s`→`[ \t\n\x0B\f\r]`; `fancy-regex 0.14` rejects `(?-u)`). Dart `\b` without `unicode:true` is ASCII but our `\b` stays Unicode — the one documented divergence, pinned by non-ASCII rows. Do not "improve" further — parity first.
- `ParsedPayment` field order and names follow `ParsedUpiPayment` / pennywise `ParsedTransaction`.
- Behavior corpus lives in tests/parity.rs (parser/dedupe pins); unit tests co-locate per module (money/split/categorize/filter/ffi). A behavior change without a test row is not done.
- ponytail: fewest files, one line if possible, deletion over addition. Mark known ceilings with `// ponytail:`.
- No repo init per owner. Local crate only — no publish, no git.
