# Integrating kharcha-core (human guide)

kharcha-core is a plain Rust library + generated FFI bindings. It does
deterministic money work (parse → categorize → dedupe); it owns **no
storage, no clock, no network, no UI**. You bring those.

## Pick your consumer

| Consumer | How |
|---|---|
| Kotlin/JVM/Android | Generated bindings in `bindings/kotlin/` + the compiled lib (`.so`/`.dll`/`.dylib`). See below. |
| Rust (service, CLI, tests) | `cargo add kharcha-core` (crates.io) or `kharcha-core = { path = "../kharcha-core" }`, then call `engine::parse` etc. directly. |
| Swift/Python/Ruby | `uniffi-bindgen generate --library <lib> --language <swift\|python\|ruby>` — same `.so`, new glue. No Rust changes needed. |

## Kotlin quickstart

1. Build the lib: `cargo build --release` → `target/release/kharcha_core.so`
   (`.dll` on Windows, `.dylib` on macOS; Android needs the NDK targets —
   see your app's Gradle NDK setup).
2. Copy `bindings/kotlin/uniffi/kharcha_core/kharcha_core.kt`
   (package `uniffi.kharcha_core`) into your source set.
3. Load the lib once (`System.loadLibrary("kharcha_core")` / JNA), then:

```kotlin
val hit = parseCapture(smsBody, sender, timestampMs) ?: return // null = spam/casual/oversize, see below
when (val d = checkCapture(hit.payment.upiRef, hit.payment.amountPaise,
                           hit.payment.isIncome, timestampMs, hit.contentHash, liveRows)) {
    is CaptureDecision.Insert -> insert(hit)
    is CaptureDecision.Skip -> if (d.backfillRef) row.updateRef(hit.payment.upiRef)
}
```

`liveRows: List<ExistingRow>` is **your** query: non-deleted rows near
`timestampMs` (±5 min is enough), **recency-ordered** — the first window match
decides, so wrong order means the backfill lands on the wrong row. The core
decides; you store.

## Contracts you must not reinterpret

- **Money is i64 paise.** `45000` = ₹450.00. Format at your edge, never float-math it.
- **Timestamps are epoch millis.** Comparisons only — the core has no TZ logic.
- **Senders are normalized** (trimmed, uppercased) inside `parse_capture`. Store what it returns.
- **`content_hash`** identifies an exact capture across channels/clocks
  (over amount|direction|merchant|ref — sender excluded so SMS vs push match).
  Persist it on your row at insert — it powers the hash dedupe gate.
  Residual edge: identical ref-less captures from different senders far apart
  in time merge. Accept it or add a sender check in your query.
- **Post-decision enrichment is yours**, same as the Dart side: income→your
  income category, wallet match/auto-create from `accountMask`/`bankName`.
  The core answers insert-or-skip only.
- **`needs_review`** = weak signal (contextual amount or fallback merchant). Surface it, don't drop it.
- **`Option` = absence, not error.** `parse_capture`/`parse_captures` return
   null for spam/casual text — and for bodies past 16 KB (`max_body_bytes()`);
   read the limit caller-side if the distinction matters.
- **Batch drains are capped** at `max_batch_items()` (10,000): the exported
  `parse_captures` keeps the input length and the tail comes back null. Chunk
  bigger backlogs caller-side.
- **`needs_review`** = exactly one of: contextual amount (amount without a
  currency symbol) or fallback-merchant extraction. Surface it, don't drop it.
- **`split_bill` returns `[]`** for count 0 and for absurd counts (>10,000) alike — validate count yourself if the distinction matters.
- **Threading.** Everything is pure: no globals beyond compiled regexes, no locks, no I/O. Call from any thread, including a background SMS-drain worker. Same input → same output, always.

## API map

| Call | Replaces |
|---|---|
| `parse_capture` / `parse_captures` | Dart `parseUpiNotification`, Kotlin `GenericUpiParser.parse` |
| `check_capture` | `insertCaptured` dedupe (ref → hash → 300s window) |
| `categorize_merchant` + `normalize_merchant_text` | `Categorizer` |
| `apply_filter` | `TransactionFilter.apply` |
| `split_bill`, `parse_amount`, `is_spam`, `encode_inbox_line` | Same-named Dart helpers |

## Pin a release (FOSS consumers + kharcha shell)

Tags are the only channel. Each tag ships `kharcha_core-<abi>.so` (arm64-v8a
for devices, x86_64 for emulator) + the matching `kharcha_core.kt` — always
as a pair, never mix versions across tags.

```bash
TAG=v0.1.2
curl -sSL -o kharcha_core-arm64-v8a.so https://github.com/AkashPriyadarshii/kharcha-core/releases/download/$TAG/kharcha_core-arm64-v8a.so
curl -sSL -o kharcha_core.kt https://github.com/AkashPriyadarshii/kharcha-core/releases/download/$TAG/kharcha_core.kt
```

```bash
# .so → app/src/main/jniLibs/<abi>/, .kt → source set, then:
System.loadLibrary("kharcha_core")
```

Bump = re-download at the new tag. The kharcha shell wraps this in
`scripts/sync-core.sh <tag>` (curl pair + stamp version into BuildConfig).

## Regenerating bindings

After any `ffi.rs` / record change:

```bash
cargo build
uniffi-bindgen generate --library target/debug/kharcha_core.dll --language kotlin --out-dir bindings/kotlin/uniffi/kharcha_core  # .so on Linux, .dylib on macOS; pin bindgen to uniffi version in Cargo.toml (0.32.1)
```

Commit the regenerated `.kt` in the same change. Never hand-edit `bindings/`.

## Behavior changes

Parity is the contract: `tests/parity.rs` encodes the battle-hardened SMS
edges. A behavior change without a corpus row is a regression by definition —
add the row first, watch it fail, then change the code.
