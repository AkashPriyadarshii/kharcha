/// Client-side filter for the transactions list. Immutable.
/// Port of `lib/core/transaction_filter.dart`. Pure: no DB, no clock.
/// Dates are epoch millis — comparisons only, so TZ never enters this file
/// (Dart compares `DateTime`s; the corpus fixes them to UTC millis).
/// Minimal transaction row (callers map their storage rows onto this).
#[derive(Debug, Clone, uniffi::Record)]
pub struct TxRow {
    pub id: i64,
    pub amount_paise: i64,
    pub merchant: String,
    pub category_id: Option<i64>,
    pub payment_method: String,
    pub is_income: bool,
    /// Epoch millis, inclusive bounds.
    pub txn_ms: i64,
    pub note: Option<String>,
    pub upi_ref: Option<String>,
}

#[derive(Debug, Clone, Default, uniffi::Record)]
pub struct TransactionFilter {
    /// Free-text, case-insensitive over merchant + note (+ upi ref + amount).
    pub query: String,
    pub category_id: Option<i64>,
    /// Exact merchant name (None = all).
    pub merchant: Option<String>,
    /// cash | upi | card | wallet (None = all).
    pub payment_method: Option<String>,
    pub is_income: Option<bool>,
    /// Earliest txn, inclusive (None = unbounded).
    pub from_ms: Option<i64>,
    /// Latest txn, inclusive (None = unbounded).
    pub to_ms: Option<i64>,
}

impl TransactionFilter {
    pub fn is_empty(&self) -> bool {
        self.query.is_empty()
            && self.category_id.is_none()
            && self.merchant.is_none()
            && self.payment_method.is_none()
            && self.is_income.is_none()
            && self.from_ms.is_none()
            && self.to_ms.is_none()
    }

    /// Rows matching every active criterion, keeping input order.
    pub fn apply<'a>(&self, all: &'a [TxRow]) -> Vec<&'a TxRow> {
        let tokens: Vec<String> = self.query.trim().to_lowercase().split_whitespace().map(str::to_string).collect();
        all.iter()
            .filter(|t| {
                (tokens.is_empty()
                    || tokens.iter().all(|tok| {
                        t.merchant.to_lowercase().contains(tok)
                            || t.note.as_deref().unwrap_or("").to_lowercase().contains(tok)
                            || t.upi_ref.as_deref().unwrap_or("").to_lowercase().contains(tok)
                            || dart_amount_string(t.amount_paise).contains(tok)
                    }))
                    && self.category_id.is_none_or(|c| t.category_id == Some(c))
                    && self.merchant.as_deref().is_none_or(|m: &str| t.merchant == m)
                    && self.payment_method.as_deref().is_none_or(|p: &str| t.payment_method == p)
                    && self.is_income.is_none_or(|i| t.is_income == i)
                    && self.from_ms.is_none_or(|f| t.txn_ms >= f)
                    && self.to_ms.is_none_or(|x| t.txn_ms <= x)
            })
            .collect()
    }
}

/// Mirrors Dart double `.toString()`: 540.0 → "540.0", 320.5 → "320.5".
fn dart_amount_string(paise: i64) -> String {
    let (r, f) = (paise / 100, (paise % 100).abs());
    if f == 0 {
        format!("{r}.0")
    } else {
        format!("{r}.{f:02}").trim_end_matches('0').to_string()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    // 2026-08-01/05/10/11 + 2026-07-20 as UTC-millis (comparison logic is TZ-free).
    const D1: i64 = 1785542400000; // 2026-08-01
    const D5: i64 = 1785888000000; // 2026-08-05
    const D10: i64 = 1786320000000; // 2026-08-10
    const D11: i64 = 1786406400000; // 2026-08-11
    const D20J: i64 = 1784505600000; // 2026-07-20

    fn rows() -> Vec<TxRow> {
        let tx = |id, merchant: &str, category_id, txn_ms, note: Option<&str>, payment_method: &str, is_income| TxRow {
            id, amount_paise: 10000, merchant: merchant.into(), category_id,
            payment_method: payment_method.into(), is_income, txn_ms,
            note: note.map(str::to_string), upi_ref: None,
        };
        vec![
            tx(1, "Zomato", Some(1), D1, Some("lunch"), "upi", false),
            tx(2, "Swiggy", Some(1), D5, Some("dinner"), "upi", false),
            tx(3, "Metro", Some(2), D20J, None, "card", false),
            tx(4, "Ravi Kirana", Some(6), D10, None, "cash", false),
            tx(5, "Acme Corp", None, D11, None, "upi", true),
        ]
    }

    fn ids(ts: Vec<&TxRow>) -> Vec<i64> {
        ts.into_iter().map(|t| t.id).collect()
    }

    #[test]
    fn mirrors_dart_filter_tests() {
        let rows = rows();
        assert!(TransactionFilter::default().is_empty());
        assert_eq!(ids(TransactionFilter::default().apply(&rows)), vec![1, 2, 3, 4, 5]);
        let q = |query: &str| TransactionFilter { query: query.into(), ..Default::default() };
        assert_eq!(ids(q("zom").apply(&rows)), vec![1]);
        assert_eq!(ids(q("dinner").apply(&rows)), vec![2]);
        assert!(q("xyzzy").apply(&rows).is_empty());
        assert_eq!(ids(TransactionFilter { category_id: Some(2), ..Default::default() }.apply(&rows)), vec![3]);
        assert_eq!(ids(TransactionFilter { merchant: Some("Metro".into()), ..Default::default() }.apply(&rows)), vec![3]);
        assert!(TransactionFilter { merchant: Some("Met".into()), ..Default::default() }.apply(&rows).is_empty());
        assert_eq!(ids(TransactionFilter { payment_method: Some("cash".into()), ..Default::default() }.apply(&rows)), vec![4]);
        assert_eq!(ids(TransactionFilter { is_income: Some(true), ..Default::default() }.apply(&rows)), vec![5]);
        assert_eq!(ids(TransactionFilter { is_income: Some(false), ..Default::default() }.apply(&rows)), vec![1, 2, 3, 4]);
        assert_eq!(ids(TransactionFilter { from_ms: Some(D5), ..Default::default() }.apply(&rows)), vec![2, 4, 5]);
        assert_eq!(ids(TransactionFilter { to_ms: Some(D5), ..Default::default() }.apply(&rows)), vec![1, 2, 3]);
        assert_eq!(ids(TransactionFilter { query: "zom".into(), category_id: Some(1), payment_method: Some("upi".into()), from_ms: Some(D1), to_ms: Some(D1), ..Default::default() }.apply(&rows)), vec![1]);
        // Hashtag + multi-token search.
        let tagged = vec![
            TxRow { id: 10, merchant: "Swiggy".into(), note: Some("pizza #goa #food".into()), ..rows[0].clone() },
            TxRow { id: 11, merchant: "Uber".into(), note: Some("airport cab #goa".into()), ..rows[0].clone() },
            TxRow { id: 12, merchant: "Decathlon".into(), note: Some("shoes #sports".into()), ..rows[0].clone() },
        ];
        assert_eq!(ids(q("#goa").apply(&tagged)), vec![10, 11]);
        assert_eq!(ids(q("Swiggy #goa").apply(&tagged)), vec![10]);
    }

    #[test]
    fn amount_string_matches_dart_double_tostring() {
        assert_eq!(dart_amount_string(54000), "540.0");
        assert_eq!(dart_amount_string(32050), "320.5");
        assert_eq!(dart_amount_string(5), "0.05");
    }

    #[test]
    fn amount_token_search_and_no_exponential_divergence() {
        // Audit: Dart `double.toString()` goes exponential past ~1e21, but
        // 1e21 rupees is unrepresentable in i64 paise by construction — the
        // divergence class cannot occur. Plain amount tokens match.
        let rows = rows();
        let q = |query: &str| TransactionFilter { query: query.into(), ..Default::default() };
        assert_eq!(ids(q("100").apply(&rows)), vec![1, 2, 3, 4, 5]); // "100.0"
        assert_eq!(ids(q("100.0").apply(&rows)), vec![1, 2, 3, 4, 5]);
        assert!(q("100.00").apply(&rows).is_empty()); // Dart "100.0" has no "100.00" either
    }
}

