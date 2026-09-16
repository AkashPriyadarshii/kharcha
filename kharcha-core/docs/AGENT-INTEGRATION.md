# Agent integration guide (read before binding or evolving this core)

You are a lazy senior developer. Shortest path, smallest diff, no
unrequested abstractions. Mark real shortcuts with `// ponytail:`.

## Binding a new consumer (Kotlin done, Swift/Python/Ruby open)

1. The `ffi.rs` surface is the ONLY surface. Core modules stay FFI-agnostic
   (lifetimes, slices, `&str` never cross the boundary — owned types only).
2. New API? Add a wrapper in `ffi.rs` + `#[uniffi::export]`, derive
   `uniffi::Record`/`uniffi::Enum` on any new shape. Never annotate core
   function signatures for FFI — wrap them.
3. Regenerate bindings (see INTEGRATION.md) and commit them in the same change.
4. Never hand-edit `bindings/`. Never add a second hand-rolled JNI layer
   beside uniffi — one bridge or none.
5. Record/enum fields are append-only in practice: renaming or retyping a
   field breaks every consumer silently (no schema check). Treat it as a
   breaking change: flag it, don't sneak it.

## Evolving behavior (parser, dedupe, categorize)

1. **Corpus row first.** Reproduce in `tests/parity.rs`, watch red, then fix.
   A behavior edit without a row is rejected.
2. **Port 1:1, don't improve.** Regexes stay verbatim to the Dart source
   (mechanical `\d`→`[0-9]`, `\s`→`[ \t\n\x0B\f\r]`; `\b` stays Unicode —
   see `non_transaction.rs`). Clever rewrites of hardened patterns are bugs.
3. **Dedupe order is load-bearing:** ref gate → hash gate → window.
   Don't reorder; each gate's test names the attack it stops.
4. **Money stays i64 paise.** No float, no decimal crate, no exceptions.
5. **No new deps without owner approval.** Current: `fancy-regex`, `uniffi`.

## Adding a v1.x bank backend

Shape is reserved in `engine::parse`: specific-sender backends go AHEAD of
the generic parser, first non-None wins (the legacy app factory order is the
reference: `../pennywiseai-tracker/parser-core/.../BankParserFactory.kt`).
One backend = one module + its sender gate + corpus rows from the upstream
bank tests. Never reorder existing backends without stating why.

## Verification gate (every change)

```bash
cargo test                                  # 50+ tests, incl. 29 parity rows
cargo clippy --all-targets -- -D warnings   # zero warnings, no allows
cargo build                                 # cdylib still links
```

Update `STATE.md` in the same change. If no doc needs updating, say why.