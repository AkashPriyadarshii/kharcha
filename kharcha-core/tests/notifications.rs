//! UPI *app* push notification corpus. Bank SMS lives in `parity.rs`; these
//! are the in-app notification strings GPay / PhonePe / Paytm / Amazon Pay /
//! BHIM / CRED show on Android, asserted in paise. 2026-09-20 snapshot of
//! live formats; notification text differs from bank SMS (no sender
//! shortcode, no account mask, wallet balance lines instead of avail-bal).

use kharcha_core::{parse_upi_notification, ParsedPayment};

fn parsed(text: &str) -> ParsedPayment {
    parse_upi_notification(text).unwrap_or_else(|| panic!("expected payment: {text}"))
}

// ---------------------------------------------------------------------------
// Google Pay (GPay)
// ---------------------------------------------------------------------------

#[test]
fn gpay_sent_notification() {
    for (text, amount, merchant) in [
        ("Sent! ₹200.00 to Swiggy", 20000, "Swiggy"),
        ("Money sent · ₹150 · Zomato · UPI Ref 123456789012", 15000, "Zomato"),
        ("You sent ₹350 to Uber via UPI", 35000, "Uber"),
        ("₹200.00 sent to Aakash Gupta", 20000, "Aakash Gupta"),
        ("Sent! ₹84 to BigBasket", 8400, "BigBasket"),
    ] {
        let p = parsed(text);
        assert_eq!(p.amount_paise, amount, "amount: {text}");
        assert_eq!(p.merchant, merchant, "merchant: {text}");
        assert!(!p.is_income, "not income: {text}");
    }
}

#[test]
fn gpay_received_notification() {
    for (text, amount, merchant) in [
        ("Received! ₹500.00 from Akash", 50000, "Akash"),
        ("Money received · ₹250 · Priya · UPI Ref 987654321012", 25000, "Priya"),
        ("You received ₹400 from Ramesh Kumar", 40000, "Ramesh Kumar"),
        ("Received! ₹35 from Pooja", 3500, "Pooja"),
    ] {
        let p = parsed(text);
        assert_eq!(p.amount_paise, amount, "amount: {text}");
        assert_eq!(p.merchant, merchant, "merchant: {text}");
        assert!(p.is_income, "income: {text}");
    }
}

// ---------------------------------------------------------------------------
// PhonePe
// ---------------------------------------------------------------------------

#[test]
fn phonepe_debit_notification() {
    for (text, amount, merchant) in [
        (
            "Debited ₹1,250.00 from your bank account for PhonePe payment to Swiggy",
            125000,
            "Swiggy",
        ),
        ("Payment of ₹450 to BigBazaar Successful", 45000, "BigBazaar"),
        ("₹200 sent to Swiggy. Your PhonePe balance is now ₹800.00", 20000, "Swiggy"),
        ("Money debited: ₹320 to Zomato", 32000, "Zomato"),
        ("Paid ₹150 to jio_recharge@ybl using PhonePe", 15000, "Jio"),
    ] {
        let p = parsed(text);
        assert_eq!(p.amount_paise, amount, "amount: {text}");
        assert_eq!(p.merchant, merchant, "merchant: {text}");
        assert!(!p.is_income, "not income: {text}");
    }
}

#[test]
fn phonepe_credit_notification() {
    for (text, amount, merchant) in [
        ("You've received ₹500 from Suresh", 50000, "Suresh"),
        ("₹650 credited by Kiran to your account", 65000, "Kiran"),
        ("Refund of ₹250 received from Flipkart", 25000, "Flipkart"),
    ] {
        let p = parsed(text);
        assert_eq!(p.amount_paise, amount, "amount: {text}");
        assert_eq!(p.merchant, merchant, "merchant: {text}");
        assert!(p.is_income, "income: {text}");
    }
}

#[test]
fn phonepe_wallet_balance_extracted() {
    let p = parsed("You've received ₹500 from Akash. Your PhonePe balance is now ₹1,000");
    assert_eq!(p.amount_paise, 50000);
    assert_eq!(p.merchant, "Akash");
    assert_eq!(p.balance_paise, Some(100000));
}

// ---------------------------------------------------------------------------
// Paytm
// ---------------------------------------------------------------------------

#[test]
fn paytm_debit_notification() {
    for (text, amount, merchant) in [
        (
            "Payment of ₹350 to Swiggy is successful. Ref No. 123456789012",
            35000,
            "Swiggy",
        ),
        (
            "Your Paytm payment of ₹250 to Uber was successful. Txn ID 1234567890123456",
            25000,
            "Uber",
        ),
        ("₹1,200 paid to Starbucks. Ref No. 111122223333", 120000, "Starbucks"),
        ("Payment of ₹89 to Indian Oil successful. UTR 987654321012", 8900, "Indian Oil"),
    ] {
        let p = parsed(text);
        assert_eq!(p.amount_paise, amount, "amount: {text}");
        assert_eq!(p.merchant, merchant, "merchant: {text}");
        assert!(!p.is_income, "not income: {text}");
    }
}

#[test]
fn paytm_credit_notification() {
    for (text, amount, merchant) in [
        ("₹500 received from Akash. Ref No. 987654321012", 50000, "Akash"),
        ("Cashback of ₹50 credited to your Paytm wallet", 5000, "Paytm"),
        ("Refund of ₹1,450 from Amazon processed to your bank", 145000, "Amazon"),
    ] {
        let p = parsed(text);
        assert_eq!(p.amount_paise, amount, "amount: {text}");
        assert_eq!(p.merchant, merchant, "merchant: {text}");
        assert!(p.is_income, "income: {text}");
    }
}

#[test]
fn paytm_ref_number_captured() {
    let p = parsed("Payment of ₹350 to Swiggy is successful. Ref No. 123456789012");
    assert_eq!(p.upi_ref.as_deref(), Some("123456789012"));
}

// ---------------------------------------------------------------------------
// Amazon Pay UPI
// ---------------------------------------------------------------------------

#[test]
fn amazon_pay_notifications() {
    for (text, amount, merchant) in [
        (
            "You've sent ₹200 to Swiggy via Amazon Pay UPI. UPI Ref: 123456789012",
            20000,
            "Swiggy",
        ),
        (
            "Received ₹400 from Ramesh via Amazon Pay UPI. UPI Ref: 987654321012",
            40000,
            "Ramesh",
        ),
        (
            "Your order payment of ₹499 to Amazon was successful",
            49900,
            "Amazon",
        ),
        ("₹75 sent to Metro Bazaar via Amazon Pay UPI", 7500, "Metro Bazaar"),
    ] {
        let p = parsed(text);
        assert_eq!(p.amount_paise, amount, "amount: {text}");
        assert_eq!(p.merchant, merchant, "merchant: {text}");
        let income = matches!(text, s if s.contains("Received") || s.contains("received"));
        assert_eq!(p.is_income, income, "direction: {text}");
        if text.contains("UPI Ref") {
            assert!(p.upi_ref.is_some(), "ref: {text}");
        }
    }
}

// ---------------------------------------------------------------------------
// BHIM
// ---------------------------------------------------------------------------

#[test]
fn bhim_notifications() {
    for (text, amount, merchant) in [
        (
            "₹300 paid to Swiggy successfully. UPI Ref 123456789012",
            30000,
            "Swiggy",
        ),
        ("You have paid ₹600 to Kiran. UPI Ref 456789012345", 60000, "Kiran"),
        ("₹150 sent to Rajesh Yadav via BHIM UPI", 15000, "Rajesh Yadav"),
        (
            "Received ₹2,000 from Mohan. UPI Ref 654321098765",
            200000,
            "Mohan",
        ),
    ] {
        let p = parsed(text);
        assert_eq!(p.amount_paise, amount, "amount: {text}");
        assert_eq!(p.merchant, merchant, "merchant: {text}");
        assert_eq!(p.is_income, text.contains("Received"), "direction: {text}");
    }
}

// ---------------------------------------------------------------------------
// CRED
// ---------------------------------------------------------------------------

#[test]
fn cred_notifications() {
    for (text, amount, merchant) in [
        (
            "CRED UPI: Payment of ₹1,200 at Starbucks successful. Ref 123456789012",
            120000,
            "Starbucks",
        ),
        ("₹1,200 paid to Starbucks via CRED UPI", 120000, "Starbucks"),
        (
            "Your CRED payment of ₹450 to Zepto was successful.",
            45000,
            "Zepto",
        ),
    ] {
        let p = parsed(text);
        assert_eq!(p.amount_paise, amount, "amount: {text}");
        assert_eq!(p.merchant, merchant, "merchant: {text}");
        assert!(!p.is_income, "not income: {text}");
    }
}

// ---------------------------------------------------------------------------
// Cross-app invariants
// ---------------------------------------------------------------------------

#[test]
fn notification_has_no_account_mask_or_bank() {
    for text in [
        "Sent! ₹200.00 to Swiggy",
        "You've received ₹500 from Suresh",
        "₹1,200 paid to Starbucks via CRED UPI",
    ] {
        let p = parsed(text);
        assert!(p.account_mask.is_none(), "mask: {text}");
        assert!(p.bank_name.is_none(), "bank: {text}");
    }
}

#[test]
fn promoting_and_unrelated_notifications_are_null() {
    for text in [
        "Celebrate! Flat 50% off on your next Swiggy order",
        "Your order is out for delivery from Blinkit",
        "Netflix: New season of your favourite show is here",
        "Loan offer: Get instant personal loan of Rs 5,00,000",
    ] {
        assert!(parse_upi_notification(text).is_none(), "{text}");
    }
}