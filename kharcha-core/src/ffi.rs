//! FFI surface (uniffi → Kotlin/JVM first, Swift/Python later).
//! Core modules stay FFI-agnostic (lifetimes, slices, &str); every exported
//! fn takes/returns owned types only. New API? Wrap it here, never in core.

use crate::{
    categorize::categorize as categorize_core, dedupe::decide_capture as decide_capture_core,
    engine, filter::TransactionFilter, money::parse_amount_paise,
    non_transaction::is_non_transaction, categorize::normalize_merchant,
    parser::encode_inbox_line as encode_inbox_line_core, split::split_bill_paisa,
    CaptureDecision, ExistingRow, ParsedTransaction, Rule, TxRow,
};

/// One batch-drain item (uniffi has no tuples).
#[derive(Debug, Clone, uniffi::Record)]
pub struct CaptureInput {
    pub body: String,
    pub sender: String,
    pub timestamp_ms: i64,
}

#[uniffi::export]
pub fn parse_capture(sms_body: String, sender: String, timestamp_ms: i64) -> Option<ParsedTransaction> {
    engine::parse(&sms_body, &sender, timestamp_ms)
}

#[uniffi::export]
pub fn parse_captures(items: Vec<CaptureInput>) -> Vec<Option<ParsedTransaction>> {
    items.iter().map(|i| engine::parse(&i.body, &i.sender, i.timestamp_ms)).collect()
}

#[uniffi::export]
pub fn check_capture(
    candidate_ref: Option<String>,
    amount_paise: i64,
    is_income: bool,
    txn_ms: i64,
    candidate_hash: Option<u64>,
    existing: Vec<ExistingRow>,
) -> CaptureDecision {
    decide_capture_core(
        candidate_ref.as_deref(),
        amount_paise,
        is_income,
        txn_ms,
        candidate_hash,
        &existing,
    )
}

#[uniffi::export]
pub fn categorize_merchant(merchant: String, rules: Vec<Rule>) -> Option<Rule> {
    categorize_core(&merchant, &rules).cloned()
}

#[uniffi::export]
pub fn normalize_merchant_text(raw: String) -> String {
    normalize_merchant(&raw)
}

#[uniffi::export]
pub fn split_bill(total_paise: i64, count: u64) -> Vec<i64> {
    split_bill_paisa(total_paise, count.min(usize::MAX as u64) as usize)
}

#[uniffi::export]
pub fn parse_amount(text: Option<String>) -> Option<i64> {
    parse_amount_paise(text.as_deref())
}

#[uniffi::export]
pub fn is_spam(text: String) -> bool {
    is_non_transaction(&text)
}

#[uniffi::export]
pub fn apply_filter(f: TransactionFilter, rows: Vec<TxRow>) -> Vec<TxRow> {
    f.apply(&rows).into_iter().cloned().collect()
}

#[uniffi::export]
pub fn encode_inbox_line(package: String, text: String, seen_at: String) -> String {
    encode_inbox_line_core(&package, &text, &seen_at)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn ffi_round_trips() {
        let t = parse_capture("₹450 paid to Swiggy using UPI UPI Ref 123456789012".into(), "hdfcbk".into(), 1).unwrap();
        assert_eq!(t.payment.merchant, "Swiggy");
        assert_eq!(t.sender, "HDFCBK");
        assert_eq!(parse_captures(vec![]).len(), 0);
        // Audit: prove uniffi nesting support, not just delegation.
        let mixed = parse_captures(vec![
            CaptureInput { body: "₹450 paid to Swiggy".into(), sender: "gpay".into(), timestamp_ms: 1 },
            CaptureInput { body: "just saying hi".into(), sender: "friend".into(), timestamp_ms: 2 },
        ]);
        assert_eq!(mixed.len(), 2);
        assert!(mixed[0].is_some() && mixed[1].is_none()); // Vec<Option<Record>>
        assert_eq!(split_bill(100, 3), vec![34, 33, 33]);
        assert_eq!(parse_amount(Some("2.345".into())), Some(235));
        assert!(is_spam("OTP is 123456. Do not share with anyone.".into()));
        assert!(!is_spam("₹450 paid to Swiggy".into()));
        let rules = vec![Rule::new("swiggy", "builtin", 1)];
        assert_eq!(categorize_merchant("Swiggy dinner".into(), rules.clone()).unwrap().category_id, Some(1));
        assert!(categorize_merchant("zzz".into(), rules).is_none()); // Option<Record> None-case
        assert_eq!(normalize_merchant_text("ZOMATO-UB".into()), "zomato ub");
        assert!(encode_inbox_line("p".into(), "t".into(), "s".into()).contains("\"package\":\"p\""));
        let rows = vec![TxRow {
            id: 1, amount_paise: 10000, merchant: "Zomato".into(), category_id: Some(1),
            payment_method: "upi".into(), is_income: false, txn_ms: 5, note: None, upi_ref: None,
        }];
        let f = TransactionFilter { query: "zom".into(), ..Default::default() };
        assert_eq!(apply_filter(f, rows).len(), 1);
        assert_eq!(
            check_capture(Some("ABC12345".into()), 45000, false, 2000, Some(7), vec![]),
            CaptureDecision::Insert
        );
        // Enum-with-fields variant across the boundary.
        let live = vec![ExistingRow {
            upi_ref: Some("ABC12345".into()), amount_paise: 45000, is_income: false,
            txn_ms: 1000, is_deleted: false, content_hash: None,
        }];
        assert_eq!(
            check_capture(Some("ABC12345".into()), 45000, false, 2000, Some(7), live),
            CaptureDecision::Skip { backfill_ref: false }
        );
    }
}

