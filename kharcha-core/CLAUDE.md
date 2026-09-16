# kharcha-core Contract

Port of kharcha's deterministic core (Dart `lib/core/*` + `GenericUpiParser.kt` + `insertCaptured` dedupe) to Rust. References: `../kharcha`.

## Hard blocks

- NO AI/LLM in this crate. Rule maps and regex only.
- Money = i64 paise. No float storage, no float math on amounts.
- Parity with the Dart parser output on every corpus row. Deviating "improvements" are bugs — file them, don't ship them.
- No new deps without owner approval. Current: `fancy-regex` (Dart lookahead ports) + `uniffi` (Kotlin bridge, `ffi.rs` only).

## Standards

- File-per-source 1:1 with Dart names so ports are diffable.
- Type everything. Validate at trust boundaries (`parse()` returns `Option`, never panics on bad SMS).
- Pure functions: no I/O, no globals except compiled regex statics.
- Unit test per module + corpus rows in tests/parity.rs for behavior.

## Verify

```bash
cargo test
cargo clippy -- -D warnings
```

## Definition of done

- [ ] Matches contract + README + ponytail
- [ ] Parity row(s) added for the behavior
- [ ] `cargo test` green
- [ ] STATE.md updated