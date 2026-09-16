# Integrating kharcha-core (human guide)

kharcha-core is a plain Rust library + generated FFI bindings. It does
deterministic money work (parse → categorize → dedupe); it owns **no
storage, no clock, no network, no UI**. You bring those.

## Pick your consumer

| Consumer | How |
|---|---|
| Kotlin/JVM/Android | Generated bindings in `bindings/kotlin/` + the compiled lib (`.so`/`.dll`/`.dylib`). See below. |
| Rust (service, CLI, tests) | `kharcha-core = { path = "../kharcha-core" }`, call `engine::parse` etc. directly. |
| Swift/Python/Ruby | `uniffi-bindgen generate --library <lib> --language <swift\|python\|ruby>` — same `.so`, new glue. No Rust changes needed. |

## Kotlin quickstart

1. Build the lib: `cargo build --release` → `target/release/kharcha_core.so`
   (`.dll` on Windows, `.dylib` on macOS; Android needs the NDK targets —
   see your app's Gradle NDK setup, the core is `no_std`-clean platform code).
2. Copy `bindings/kotlin/uniffi/kharcha_core/kharcha_core.kt`
   (package `uniffi.kharcha_core`) into your source set.
3. Load the lib once (`System.loadLibrary("kharcha_core")` / JNA), then:

```kotlin
val hit = parseCapture(smsBody, sender, timestampMillis) ?: return
when (checkCapture(hit.payment.upiRef, hit.payment.amountPaise,
                   hit.payment.isIncome, ts, hit.contentHash, liveRows)) {
    is CaptureDecision.Insert -> insert(hit)
    is CaptureDecision.Skip -> if (it.backfillRef) row.updateRef(hit.payment.upiRef)
}
```

`liveRows: List<ExistingRow>` is **your** query: non-deleted rows near `ts`
(±5 min is enough) mapped onto `ExistingRow`. The core decides; you store.

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
- **`Option` = absence, not error.** `parse_capture` returns null for spam/casual text. That is the design.

## API map

| Call | Replaces |
|---|---|
| `parse_capture` / `parse_captures` | Dart `parseUpiNotification`, Kotlin `GenericUpiParser.parse` |
| `check_capture` | `insertCaptured` dedupe (ref → hash → 300s window) |
| `categorize_merchant` + `normalize_merchant_text` | `Categorizer` |
| `apply_filter` | `TransactionFilter.apply` |
| `split_bill`, `parse_amount`, `is_spam`, `encode_inbox_line` | Same-named Dart helpers |

## Threading

Everything is pure: no globals beyond compiled regexes, no locks, no I/O.
Call `parse_capture`/`check_capture` from any thread, including a background
SMS-drain worker. Same input → same output, always.

## Regenerating bindings

After any `ffi.rs` / record change:

```bash
cargo build
uniffi-bindgen generate --library target/debug/kharcha_core.dll --language kotlin --out-dir bindings/kotlin
```

Commit the regenerated `.kt` in the same change. Never hand-edit `bindings/`.

## Behavior changes

Parity is the contract: `tests/parity.rs` encodes the battle-hardened SMS
edges. A behavior change without a corpus row is a regression by definition —
add the row first, watch it fail, then change the code.
