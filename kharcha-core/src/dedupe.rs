//! Capture dedupe rules. Port of the `insertCaptured` dedupe in
//! `lib/data/transaction_repository.dart` (DB access stripped out — this file
//! is the pure decision; the caller owns storage).
//!
//! Rules, in order:
//! 1. Same non-empty `upi_ref` on a live row → duplicate (soft-deleted rows
//!    are excluded, so a re-sent notification after deletion re-captures).
//! 2. Same `content_hash` on a live row → exact redelivery (other channel,
//!    other clock, no ref) → duplicate. Beats pennywise's md5(body): the hash
//!    covers amount|direction|merchant|ref (sender excluded so SMS-vs-push
//!    match), so carrier-added footers ("Bal: ...") don't break it the way
//!    raw-body hashing does.
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

    // 1. Exact-ref gate.
    if let Some(c) = cand {
        if existing.iter().any(|r| live(r) && valid_ref(r.upi_ref.as_deref()) == Some(c)) {
            return CaptureDecision::Skip { backfill_ref: false };
        }
    }

    // 2. Content-hash gate: exact redelivery, any clock, no ref needed.
    if let Some(h) = candidate_hash {
        if existing.iter().any(|r| live(r) && r.content_hash == Some(h)) {
            return CaptureDecision::Skip { backfill_ref: false };
        }
    }

    // 3. Cross-channel window: same amount + direction, ±5 min.
    // Audit: `abs_diff` — plain `-`/`.abs()` panics on i64::MIN from FFI.
    if let Some(dup) = existing.iter().filter(|r| live(r)).find(|r| {
        r.amount_paise == amount_paise
            && r.is_income == is_income
            && r.txn_ms.abs_diff(txn_ms) <= WINDOW_MS as u64
    }) {
        let distinct_refs = match (cand, valid_ref(dup.upi_ref.as_deref())) {
            (Some(a), Some(b)) => a != b,
            _ => false,
        };
        if !distinct_refs && dup.txn_ms.abs_diff(txn_ms) / 1000 <= DRIFT_SECS as u64 {
            let backfill_ref = cand.is_some() && valid_ref(dup.upi_ref.as_deref()).is_none();
            return CaptureDecision::Skip { backfill_ref };
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
    fn same_ref_skips() {
        let ex = vec![row(Some("ABC12345"), 45000, false, 1000)];
        assert_eq!(decide_capture(Some("ABC12345"), 45000, false, 2000, Some(7), &ex), CaptureDecision::Skip { backfill_ref: false });
        // Deleted rows don't block: re-capture after deletion inserts.
        let mut del = ex.clone();
        del[0].is_deleted = true;
        assert_eq!(decide_capture(Some("ABC12345"), 45000, false, 2000, Some(7), &del), CaptureDecision::Insert);
    }

    #[test]
    fn window_duplicate_skips_and_backfills() {
        let ex = vec![row(None, 45000, false, 100_000)];
        // Same amount, 60 s apart, row lacks ref → skip + backfill.
        assert_eq!(
            decide_capture(Some("NEWREF12"), 45000, false, 160_000, None, &ex),
            CaptureDecision::Skip { backfill_ref: true }
        );
        // Neither side has a ref → plain skip.
        assert_eq!(
            decide_capture(None, 45000, false, 160_000, None, &ex),
            CaptureDecision::Skip { backfill_ref: false }
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
    fn hash_catches_redelivery_outside_window() {
        // Same payment re-delivered an hour later, no ref anywhere.
        let mut redelivered = row(None, 45000, false, 100_000);
        redelivered.content_hash = Some(99);
        let ex = vec![redelivered];
        assert_eq!(
            decide_capture(None, 45000, false, 100_000 + 3_600_000, Some(99), &ex),
            CaptureDecision::Skip { backfill_ref: false }
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
