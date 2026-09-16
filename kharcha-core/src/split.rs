/// Splits `total_paisa` across `count` people so the parts sum EXACTLY to total.
/// Port of `lib/core/bill_splitter.dart` `splitBillPaisa`.
/// `div_euclid`/`rem_euclid` match Dart `~/`/`%` on non-negative totals;
/// on negatives Rust keeps the exact sum where Dart drifts (improvement,
/// real inputs are non-negative). Counts past 10k return empty (FFI OOM guard).
pub fn split_bill_paisa(total_paisa: i64, count: usize) -> Vec<i64> {
    // Audit: unclamped count is an OOM vector via FFI (`split_bill(u64::MAX)`).
    // 10k people is absurd for a bill; refuse beyond it.
    if count == 0 || count > 10_000 {
        return vec![];
    }
    if count == 1 {
        return vec![total_paisa];
    }
    let n = count as i64;
    let base = total_paisa.div_euclid(n);
    let rem = total_paisa.rem_euclid(n);
    (0..n).map(|i| base + i64::from(i < rem)).collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn splits_evenly() {
        assert_eq!(split_bill_paisa(3000, 3), vec![1000, 1000, 1000]);
    }

    #[test]
    fn remainder_spread_to_first_people() {
        assert_eq!(split_bill_paisa(100, 3), vec![34, 33, 33]);
        assert_eq!(split_bill_paisa(1, 2), vec![1, 0]);
    }

    #[test]
    fn parts_always_sum_exactly() {
        for (total, count) in [(12345, 7), (999, 2), (5000, 1), (1, 20)] {
            let parts = split_bill_paisa(total, count);
            assert_eq!(parts.iter().sum::<i64>(), total);
        }
    }
}
