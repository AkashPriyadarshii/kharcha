//! Capture dedupe rules. Port of the `insertCaptured` dedupe in
//! `lib/data/transaction_repository.dart` (DB access stripped out — this file
//! is the pure decision; the caller owns storage).
//!
//! Rules, in order:
//! 1. Same non-empty `upi_ref` on a live row (compared case-insensitively —
//!    `T2408…` from one channel vs `t2408…` from another is one payment) →
//!    duplicate (soft-deleted rows are excluded, so a re-sent notification
//!    after deletion re-captures).
//! 2. Same `content_hash` on a live row *within the window* → exact
//!    redelivery (other channel, other clock, no ref) → duplicate. The window
//!    bound is deliberate (audit): two genuine ref-less ₹150 Swiggy orders
//!    hours apart share amount+merchant but are NOT one payment — an unbounded
//!    hash gate silently drops the second; a dup is better than a lost real
//!    spend. Beats legacy Kotlin parser's md5(body): the hash covers
//!    amount|direction|merchant|ref (sender excluded so SMS-vs-push match),
//!    so carrier-added footers ("Bal: ...") don't break it the way raw-body
//!    hashing does.
//! 3. Cross-channel window: same amount + direction within ±5 min on a live
//!    row. Two rows with valid but DISTINCT refs are genuine back-to-back
//!    payments → insert. Otherwise, if the clocks drift ≤ 300 s → skip; if we
//!    carry a ref the stored row lacks, backfill it onto that row.
//!    (Window is 5 min, not 2, because SMS catch-up uses the carrier clock
//!    while notifications use device time.)

/// A stored transaction row, as far as dedupe cares.
#[derive(Debug, Clone, uniffi::Record)]
pub struct ExistingRow {
    pub upi_ref: Option<String>,
    pub amount_paise: i64,
    pub is_income: bool,
    /// Epoch millis.
    pub txn_ms: i64,
    pub is_deleted: bool,
    /// `engine::content_hash` at insert time. Legacy rows carry None —
    /// the hash signal skips them (ref + window still apply).
    pub content_hash: Option<u64>,
}

/// Caller applies the storage side-effect (insert row / write ref onto row id).
#[derive(Debug, Clone, PartialEq, uniffi::Enum)]
pub enum CaptureDecision {
    Insert,
    Skip {
        /// Write the candidate ref onto the matched row (it had none).
        backfill_ref: bool,
    },
}

/// ±5 min cross-channel window, millis. Matches the Kotlin background window.
pub const WINDOW_MS: i64 = 5 * 60 * 1000;
/// Max clock drift inside the window to still count as duplicate, seconds.
/// Compared in TRUNCATED seconds to mirror Dart `.inSeconds.abs() <= 300`
/// (audit: millis `<= 300_000` diverges on the 300.001–300.999 s sliver).
pub const DRIFT_SECS: i64 = 300;

fn valid_ref(r: Option<&str>) -> Option<&str> {
    r.map(str::trim).filter(|s| !s.is_empty())
}

/// Lowercased compare key. Refs are case-noisy across channels (`T2408…` vs
/// `t2408…`) — content_hash already lowercases; the ref gate must match (audit).
fn ref_matches(a: Option<&str>, b: Option<&str>) -> bool {
    matches!((valid_ref(a), valid_ref(b)), (Some(x), Some(y)) if x.eq_ignore_ascii_case(y))
}

/// Decide a capture against live rows. `existing` should be recency-ordered;
/// the first window match decides (mirrors Dart's `limit(1)`, which itself
/// has no ORDER BY — recency order is a caller convention, not a guarantee).
///
/// Audit note — NOT ported (caller owns post-decision enrichment, same as the
/// Dart side owns it post-`insertCaptured`): income→"Other income" category
/// assignment and wallet match/auto-create. This file answers only
/// insert-or-skip (+ref backfill).
pub fn decide_capture(
    candidate_ref: Option<&str>,
    amount_paise: i64,
    is_income: bool,
    txn_ms: i64,
    candidate_hash: Option<u64>,
    existing: &[ExistingRow],
) -> CaptureDecision {
    let cand = valid_ref(candidate_ref);
    let live = |r: &ExistingRow| !r.is_deleted;

    // 1. Exact-ref gate (case-insensitive).
    if let Some(c) = cand {
        if existing.iter().any(|r| live(r) && ref_matches(r.upi_ref.as_deref(), Some(c))) {
            return CaptureDecision::Skip { backfill_ref: false };
        }
    }

    // 2. Content-hash gate: exact redelivery WITHIN the window, no ref needed.
    // Window-bound (audit): same content far apart in time is a genuine repeat
    // payment, not a redelivery — don't drop real spends. A carried ref is
    // backfilled onto the un-ref'd stored row (same content = same payment).
    if let Some(h) = candidate_hash {
        if let Some(r) = existing.iter().find(|r| {
            live(r) && r.content_hash == Some(h) && r.txn_ms.abs_diff(txn_ms) <= WINDOW_MS as u64
        }) {
            let backfill_ref = cand.is_some() && valid_ref(r.upi_ref.as_deref()).is_none();
            return CaptureDecision::Skip { backfill_ref };
        }
    }

    // 3. Cross-channel window: same amount + direction, ±5 min.
    // Audit: `abs_diff` — plain `-`/`.abs()` panics on i64::MIN from FFI.
    if let Some(dup) = existing.iter().filter(|r| live(r)).find(|r| {
        r.amount_paise == amount_paise
            && r.is_income == is_income
            && r.txn_ms.abs_diff(txn_ms) <= WINDOW_MS as u64
    }) {
        let distinct_refs = !ref_matches(cand, dup.upi_ref.as_deref())
            && cand.is_some()
            && valid_ref(dup.upi_ref.as_deref()).is_some();
        if !distinct_refs && dup.txn_ms.abs_diff(txn_ms) / 1000 <= DRIFT_SECS as u64 {
            // Evidence of ONE payment before skipping (audit #7): matching
            // content hash, or both sides ref-less and unhashed (legacy rows).
            // A ref-less stored row + a ref'd candidate with a DIFFERENT hash
            // is a genuine back-to-back same-amount tap → insert, don't eat it.
            let same_content = candidate_hash.is_some()
                && dup.content_hash.is_some()
                && candidate_hash == dup.content_hash;
            let both_ref_less_unhashed =
                cand.is_none() && valid_ref(dup.upi_ref.as_deref()).is_none();
            if same_content || both_ref_less_unhashed {
                let backfill_ref = cand.is_some() && valid_ref(dup.upi_ref.as_deref()).is_none();
                return CaptureDecision::Skip { backfill_ref };
            }
        }
    }

    CaptureDecision::Insert
}

#[cfg(test)]
mod tests {
    use super::*;

    fn row(upi_ref: Option<&str>, amount_paise: i64, is_income: bool, txn_ms: i64) -> ExistingRow {
        ExistingRow { upi_ref: upi_ref.map(str::to_string), amount_paise, is_income, txn_ms, is_deleted: false, content_hash: None }
    }

    #[test]
    fn same_ref_skips_case_insensitive() {
        let ex = vec![row(Some("T2408123456"), 45000, false, 1000)];
        // Case-noise is one ref (audit #3): `t2408…` SMS vs `T2408…` push.
        assert_eq!(decide_capture(Some("t2408123456"), 45000, false, 2000, Some(7), &ex), CaptureDecision::Skip { backfill_ref: false });
        // A different ref is a different payment → insert.
        assert_eq!(decide_capture(Some("ABC12345"), 45000, false, 2000, Some(7), &ex), CaptureDecision::Insert);
        // Deleted rows don't block: re-capture after deletion inserts.
        let mut del = ex.clone();
        del[0].is_deleted = true;
        assert_eq!(decide_capture(Some("t2408123456"), 45000, false, 2000, Some(7), &del), CaptureDecision::Insert);
    }

    #[test]
    fn window_duplicate_skips_and_backfills_on_hash_evidence() {
        // Ref-less redelivery caught by matching hash WITHIN the window → skip + backfill.
        let mut hashed = row(None, 45000, false, 100_000);
        hashed.content_hash = Some(9);
        let ex = vec![hashed];
        assert_eq!(
            decide_capture(Some("NEWREF12"), 45000, false, 160_000, Some(9), &ex),
            CaptureDecision::Skip { backfill_ref: true }
        );
        // Neither side has a ref, no hash (legacy rows) → plain skip.
        let ex_legacy = vec![row(None, 45000, false, 100_000)];
        assert_eq!(
            decide_capture(None, 45000, false, 160_000, None, &ex_legacy),
            CaptureDecision::Skip { backfill_ref: false }
        );
        // Ref-less stored row, ref'd candidate, hash MISSING on stored row →
        // evidence of one payment is absent → insert (never backfill-eat a
        // genuine back-to-back same-amount tap, audit #1/#7).
        assert_eq!(
            decide_capture(Some("BBBB2222"), 45000, false, 160_000, Some(88), &ex_legacy),
            CaptureDecision::Insert
        );
    }

    #[test]
    fn distinct_refs_are_back_to_back_inserts() {
        let ex = vec![row(Some("AAAA1111"), 45000, false, 100_000)];
        assert_eq!(decide_capture(Some("BBBB2222"), 45000, false, 160_000, None, &ex), CaptureDecision::Insert);
    }

    #[test]
    fn outside_window_or_different_side_inserts() {
        let ex = vec![row(None, 45000, false, 100_000)];
        assert_eq!(decide_capture(None, 45000, false, 100_000 + WINDOW_MS + 1, None, &ex), CaptureDecision::Insert);
        assert_eq!(decide_capture(None, 46000, false, 160_000, None, &ex), CaptureDecision::Insert);
        assert_eq!(decide_capture(None, 45000, true, 160_000, None, &ex), CaptureDecision::Insert);
    }

    #[test]
    fn hostile_timestamps_cant_panic() {
        // Audit: (txn_ms - i64::MIN).abs() panics. abs_diff never does.
        let ex = vec![row(None, 45000, false, 0)];
        assert_eq!(
            decide_capture(None, 45000, false, i64::MIN, None, &ex),
            CaptureDecision::Insert
        );
        assert_eq!(
            decide_capture(None, 45000, false, i64::MAX, None, &ex),
            CaptureDecision::Insert
        );
    }

    #[test]
    fn hash_gate_is_window_bound() {
        // Same payment redelivered within the window, no ref → skip.
        let mut redelivered = row(None, 45000, false, 100_000);
        redelivered.content_hash = Some(99);
        let ex = vec![redelivered];
        assert_eq!(
            decide_capture(None, 45000, false, 100_000 + 60_000, Some(99), &ex),
            CaptureDecision::Skip { backfill_ref: false }
        );
        // Same content an HOUR later is a genuine repeat order (audit #1):
        // never drop a real ₹150 Swiggy on the hash gate.
        assert_eq!(
            decide_capture(None, 45000, false, 100_000 + 3_600_000, Some(99), &ex),
            CaptureDecision::Insert
        );
        // Legacy row without a hash → hash signal skips it, window expired → insert.
        let ex_legacy = vec![row(None, 45000, false, 100_000)];
        assert_eq!(
            decide_capture(None, 45000, false, 100_000 + 3_600_000, Some(99), &ex_legacy),
            CaptureDecision::Insert
        );
        // Same hash on a soft-deleted row → re-captures.
        let mut del = ex.clone();
        del[0].is_deleted = true;
        assert_eq!(
            decide_capture(None, 45000, false, 100_000 + 3_600_000, Some(99), &del),
            CaptureDecision::Insert
        );
    }
}
