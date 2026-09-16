//! Parity harness: every case from kharcha `test/upi_parser_test.dart`,
//! asserted in paise. A port without a row here is not done.

use kharcha_core::{encode_inbox_line, parse_upi_notification, ParsedPayment};

fn parsed(text: &str) -> ParsedPayment {
    parse_upi_notification(text).unwrap_or_else(|| panic!("expected payment: {text}"))
}

#[test]
fn gpay_debit() {
    let p = parsed("₹450 paid to Swiggy using UPI UPI Ref 123456789012");
    assert_eq!(p.amount_paise, 45000);
    assert_eq!(p.merchant, "Swiggy");
    assert_eq!(p.upi_ref.as_deref(), Some("123456789012"));
}

#[test]
fn phonepe_debit() {
    let p = parsed("Rs 320.50 debited from a/c at Zomato. UTR 9876543210");
    assert_eq!(p.amount_paise, 32050);
    assert_eq!(p.merchant, "Zomato");
    assert_eq!(p.upi_ref.as_deref(), Some("9876543210"));
}

#[test]
fn money_received_is_income() {
    let p = parsed("₹5000 received from Akash. UPI Ref 123456789012");
    assert_eq!(p.amount_paise, 500000);
    assert!(p.is_income);
    assert_eq!(p.upi_ref.as_deref(), Some("123456789012"));
}

#[test]
fn paid_you_sent_you_is_income() {
    let paid = parsed("Akash paid you ₹500 via UPI");
    assert_eq!(paid.amount_paise, 50000);
    assert!(paid.is_income);
    let sent = parsed("Priya sent you ₹250");
    assert_eq!(sent.amount_paise, 25000);
    assert!(sent.is_income);
}

#[test]
fn casual_chat_and_missing_amount_are_null() {
    assert!(parse_upi_notification("Bhai ₹200 bhej de").is_none());
    assert!(parse_upi_notification("You have a new message from Swiggy").is_none());
}

#[test]
fn bank_debit_message() {
    let p = parsed("Rs. 2,500.00 debited from A/c XX1234 at Amazon on 09-Aug-26");
    assert_eq!(p.amount_paise, 250000);
    assert!(!p.is_income);
    assert_eq!(p.merchant, "Amazon");
}

#[test]
fn unknown_merchant_falls_back() {
    let p = parsed("₹100 debited. UTR 1111111111");
    assert_eq!(p.merchant, "Unknown");
    assert_eq!(p.upi_ref.as_deref(), Some("1111111111"));
}

#[test]
fn gpay_money_sent_format() {
    let p = parsed("Money sent · ₹200 · Swiggy · UPI Ref 987654321012");
    assert_eq!(p.amount_paise, 20000);
    assert_eq!(p.merchant, "Swiggy");
    assert_eq!(p.upi_ref.as_deref(), Some("987654321012"));
}

#[test]
fn phonepe_trans_id() {
    let p = parsed("Payment to Swiggy of ₹350.00 was successful. Trans ID: T240823123456");
    assert_eq!(p.amount_paise, 35000);
    assert_eq!(p.merchant, "Swiggy");
    assert_eq!(p.upi_ref.as_deref(), Some("T240823123456"));
}

#[test]
fn bank_narration_upi_dr() {
    let p = parsed("A/c *5678 debited for Rs. 1,450.00 on 23-08-2026. Info: UPI/DR/423523523523/AMAZON/Axis Bank");
    assert_eq!(p.amount_paise, 145000);
    assert_eq!(p.merchant, "AMAZON");
    assert_eq!(p.upi_ref.as_deref(), Some("423523523523"));
}

#[test]
fn cred_at_merchant() {
    let p = parsed("Paid ₹1,200 at Starbucks using CRED UPI. Ref 123456789012");
    assert_eq!(p.amount_paise, 120000);
    assert_eq!(p.merchant, "Starbucks");
    assert_eq!(p.upi_ref.as_deref(), Some("123456789012"));
}

#[test]
fn cashback_credited_is_income() {
    let p = parsed("Cashback of ₹50 credited to your account. Ref 999988887777");
    assert_eq!(p.amount_paise, 5000);
    assert!(p.is_income);
}

#[test]
fn vpa_handles_cleaned() {
    let p = parsed("Paid ₹150 to paytmqr281001@paytm using UPI. Ref 111122223333");
    assert_eq!(p.amount_paise, 15000);
    assert_eq!(p.merchant, "Paytm Merchant");
    let p2 = parsed("Paid ₹500 to swiggy.orders@icici. Ref 222233334444");
    assert_eq!(p2.merchant, "Swiggy");
}

#[test]
fn lakh_numbering() {
    let p = parsed("INR 1,25,000.00 debited for Rent to Landlord");
    assert_eq!(p.amount_paise, 12500000);
    assert_eq!(p.merchant, "Landlord");
}

#[test]
fn hdfc_sms_with_balance() {
    let p = parsed("Dear Customer, INR 340.00 debited from A/C **1234 on 23-AUG-26 to ZOMATO UPI:623829102812. Bal: INR 12,400.00");
    assert_eq!(p.amount_paise, 34000);
    assert_eq!(p.merchant, "ZOMATO");
    assert!(!p.is_income);
    assert_eq!(p.balance_paise, Some(1240000));
    assert_eq!(p.account_mask.as_deref(), Some("1234"));
}

#[test]
fn sbi_transfer() {
    let p = parsed("Your A/C ending 4321 debited by Rs 150.00 on 23Aug26 transfer to Chai Point Ref No 892019283019");
    assert_eq!(p.amount_paise, 15000);
    assert_eq!(p.merchant, "Chai Point");
    assert_eq!(p.upi_ref.as_deref(), Some("892019283019"));
    // "ending 4321" without in/with is not a mask in either engine — pinned.
    assert!(p.account_mask.is_none());
}

#[test]
fn axis_card_spend() {
    let p = parsed("Axis Bank: INR 750.00 spent on your Credit Card XX9900 at PVR CINEMAS on 23-Aug-26");
    assert_eq!(p.amount_paise, 75000);
    assert_eq!(p.merchant, "PVR CINEMAS");
    assert!(!p.is_income);
    assert_eq!(p.bank_name.as_deref(), Some("Axis")); // first alternative wins, same as Dart
}

#[test]
fn bharatpe_vpa() {
    let p = parsed("Paid Rs. 85.00 to bharatpe9102912@icici via BHIM. Ref No: 910291029102");
    assert_eq!(p.amount_paise, 8500);
    assert_eq!(p.merchant, "BharatPe Merchant");
    assert_eq!(p.upi_ref.as_deref(), Some("910291029102"));
}

#[test]
fn refund_is_income() {
    let p = parsed("INR 899.00 refunded to your A/c XX1234 from Amazon. UPI Ref: 102938475610");
    assert_eq!(p.amount_paise, 89900);
    assert!(p.is_income);
    assert_eq!(p.merchant, "Amazon");
    assert_eq!(p.upi_ref.as_deref(), Some("102938475610"));
}

#[test]
fn spam_rejections() {
    for s in [
        "Ur recharge is ending or will end plz recharge with 196rs",
        "Dear Customer, your Jio pack of Rs 239 will expire on 25-Aug. Recharge now with Rs 239 to continue services.",
        "Your Airtel plan expires tomorrow. Please recharge with Rs 199 to enjoy unlimited calls.",
        "Your Vi pack validity ending today. Plz recharge with 299 immediately.",
        "Reminder: Electricity bill of Rs 1,450 is due on 30-Aug. Pay now to avoid disconnection.",
        "Your Credit Card bill of INR 12,500.00 is generated. Due date: 15-SEP-26.",
        "Payment reminder: Rs 599 is due for your broadband account.",
        "OTP for transaction of INR 450.00 at Zomato is 928301. Do not share OTP with anyone.",
        "Your verification code for payment of Rs 1,000 is 445566.",
        "Congratulations! You are eligible for pre-approved loan of Rs 5,00,000. Apply now.",
        "Avail instant personal loan of Rs. 1,00,000 in 2 minutes.",
        "Swiggy is requesting payment of Rs 350 via UPI. Approve in GPay.",
        "Collect request of Rs 500 received from rahul@upi.",
        "Payment of Rs 500 to Uber failed due to bank server issue.",
        "Transaction of Rs 1,200 at Swiggy was declined due to insufficient funds.",
        "Recharge of Rs 299 is successful for your Jio number 9876543210. Transaction ID: 123456789. Your plan validity is 28 days.",
        "Recharge of Rs. 199 is successful for mobile 9876543210. Benefits: 1.5GB/day.",
        "Recharge Successful! Rs 299 credited to your Jio prepaid account. Validity: 28 days.",
        "Payment received of Rs 299 for recharge of Airtel mobile 9876543210.",
        "Recharge done for Rs 479 on Vi mobile 9876543210.",
        "Your recharge of Rs 666 for Jio number 9876543210 is processed.",
        "Akash has requested Rs 500 from you on PhonePe. Click here to approve.",
        "Payment request of Rs 1,200 received from Ramesh on Google Pay.",
        "Collect request of Rs 350 initiated by Zomato. Authorize in your UPI app.",
        "Request to pay INR 450 from merchant ABC. Approve to pay.",
        "Mandate created for Rs 199/month for Netflix.",
        "Autopay scheduled for Rs 499 on 15th.",
        "Payment of Rs 1,000 is pending.",
        "Transaction of Rs 500 initiated.",
        "Payment of Rs 800 in progress.",
        "Pre-approved personal loan of ₹5,00,000 at 10.5% interest. Apply now.",
        "Congratulations! You have won Rs 500 cashback voucher on PhonePe. Claim now.",
        "Win up to Rs 10,000 on Cred. Spin now.",
        "Your credit limit of Rs 75,000 is approved. Click to activate.",
        "Earn Rs 500 by referring your friends to the app.",
        "Invest Rs 500 in top mutual funds today.",
        "Your ICICI Credit Card statement for Dec has been generated. Total amount due: Rs 4,500.",
    ] {
        assert!(parse_upi_notification(s).is_none(), "{s}");
    }
}

#[test]
fn generic_incoming() {
    let p = parsed("papa sent Rs 2400 to you");
    assert_eq!(p.amount_paise, 240000);
    assert!(p.is_income);
    assert_eq!(p.merchant, "Papa");
    let p2 = parsed("friend paid 500 to you");
    assert_eq!(p2.amount_paise, 50000);
    assert!(p2.is_income);
}

#[test]
fn payment_received_phrasing() {
    let p = parsed("Payment received Rs 500 from John Doe. UPI Ref 123456789012");
    assert_eq!(p.amount_paise, 50000);
    assert!(p.is_income);
    assert_eq!(p.merchant, "John Doe");
    assert_eq!(p.upi_ref.as_deref(), Some("123456789012"));
}

#[test]
fn merchant_lookahead_stops_at_timestamp() {
    let p = parsed("Paid Rs.500 to Swiggy at 14:32 IST. UPI Ref 123456789012");
    assert_eq!(p.amount_paise, 50000);
    assert_eq!(p.merchant, "Swiggy");
    assert!(!p.is_income);
    let p2 = parsed("Rs. 300 debited from Uber at 09:15. Ref 987654321012");
    assert_eq!(p2.amount_paise, 30000);
    assert_eq!(p2.merchant, "Uber");
}

#[test]
fn bare_account_number_is_not_a_ref() {
    let p = parsed("Rs 500 debited from A/c 123456789012 at Starbucks");
    assert_eq!(p.amount_paise, 50000);
    assert_eq!(p.merchant, "Starbucks");
    assert!(p.upi_ref.is_none());
    assert_eq!(p.account_mask.as_deref(), Some("123456789012"));
}

#[test]
fn spend_with_cashback_footnote_stays_expense() {
    let p = parsed("Paid Rs 150 on Swiggy. Earn up to Rs 20 cashback on next order.");
    assert_eq!(p.amount_paise, 15000);
    assert_eq!(p.merchant, "Swiggy");
    assert!(!p.is_income);
}

#[test]
fn payment_received_by_merchant_is_not_income() {
    let p = parsed("Paid ₹450 to Swiggy. Payment received by merchant. Ref 112233445566");
    assert_eq!(p.amount_paise, 45000);
    assert!(!p.is_income);
}

#[test]
fn balance_prefix_does_not_corrupt_amount() {
    let p = parsed("Avail Bal: Rs 45,000. Your A/c debited for Rs 150 at Swiggy. UPI Ref 123456789012");
    assert_eq!(p.amount_paise, 15000);
    assert_eq!(p.merchant, "Swiggy");
    assert!(!p.is_income);
}

#[test]
fn p2p_narration() {
    let p = parsed("Your A/c debited for Rs 850. Info: UPI/P2P/123456789012/Rahul Sharma/HDFC");
    assert_eq!(p.amount_paise, 85000);
    assert_eq!(p.upi_ref.as_deref(), Some("123456789012"));
    assert_eq!(p.merchant, "Rahul Sharma");
    assert!(!p.is_income);
}

#[test]
fn needs_review_flags_weak_signals() {
    // Contextual amount ("debited by 500" with no currency symbol).
    let p = parsed("Your account debited by 500.00 at Swiggy on 23-Aug-26. Ref 123456789012");
    assert_eq!(p.amount_paise, 50000);
    assert_eq!(p.merchant, "Swiggy");
    assert!(p.needs_review);
    // Fallback merchant ("for Metro" — no paid/to/at verb ahead of it).
    let p2 = parsed("Rs 250 debited for Metro via UPI. Ref 123456789012");
    assert_eq!(p2.amount_paise, 25000);
    assert_eq!(p2.merchant, "Metro");
    assert!(p2.needs_review);
    // Strong signals stay clean.
    let p3 = parsed("₹450 paid to Swiggy using UPI UPI Ref 123456789012");
    assert!(!p3.needs_review);
}

#[test]
fn pins_dart_wins_quirks() {
    // Refund mention flips the WHOLE message to income (Dart cascade) —
    // amount taken is the first (₹500), not the refund (₹50). Quirk, pinned.
    let p = parsed("Paid ₹500 to Swiggy. Refund of ₹50 credited to your account");
    assert_eq!(p.amount_paise, 50000);
    assert!(p.is_income);
    // "Paid to you" → income with Unknown merchant (recipient blocks "you",
    // income-sender needs a leading name). Kotlin lands identical here.
    let p2 = parsed("Paid ₹100 to you. Ref 123456789012");
    assert!(p2.is_income);
    assert_eq!(p2.merchant, "Unknown");
}

#[test]
fn non_ascii_pins_parity() {
    // Accent inside merchant: ASCII-only classes stop at "Caf", lookahead
    // fails on "é" — both engines land on Unknown. Pinned, not fixed.
    let p = parsed("Paid ₹500 to Café Mocha. Ref 123456789012");
    assert_eq!(p.merchant, "Unknown");
    // Accent-glued verb: Dart ASCII \b matches "debited" after "é", Rust
    // Unicode \b does not → Rust sees no verb and nulls. Bank SMS are ASCII
    // English; transliterated text only. Pinned, revisit on real samples.
    assert!(parse_upi_notification("édebited Rs 100 at Swiggy. Ref 123456789012").is_none());
}

#[test]
fn numeric_payees_keep_their_number() {
    // UPI Number / mobile@handle — most common P2P format. Dart says Unknown;
    // this core keeps the number (deliberate, owner-approved improvement).
    let p = parsed("Paid ₹500 to 9876543210@ybl via UPI. Ref 111122223333");
    assert_eq!(p.amount_paise, 50000);
    assert_eq!(p.merchant, "9876543210");
    assert_eq!(p.upi_ref.as_deref(), Some("111122223333"));
    // Income side, bare number (no handle).
    let p2 = parsed("₹2,000 received from 9876543210. UPI Ref 123456789012");
    assert_eq!(p2.amount_paise, 200000);
    assert!(p2.is_income);
    assert_eq!(p2.merchant, "9876543210");
    // Boundaries hold: 7-digit fragments and 12-digit accounts stay Unknown.
    let p3 = parsed("Paid ₹100 to 123456789012. Ref ABC12345");
    assert_eq!(p3.merchant, "Unknown");
    let p4 = parsed("Paid ₹100 to 1234567. Ref ABC12345");
    assert_eq!(p4.merchant, "Unknown");
}

#[test]
fn premortem_real_life_rows() {
    // Cashback-VOUCHER promo: receive verbs but no money moves. Must die.
    // (Legit "Cashback of ₹50 credited" has no "voucher" — still income.)
    assert!(parse_upi_notification("You have received Rs 100 cashback voucher. Claim now.").is_none());
    assert!(parse_upi_notification("Rs 200 gift voucher credited to your wallet. Shop now.").is_none());
    let legit = parsed("Cashback of ₹50 credited to your account. Ref 999988887777");
    assert!(legit.is_income);
    // ATM reversal: real money-in Dart drops. Now income (Kotlin agrees).
    let p = parsed("Rs 5000 reversed to your account. Ref 123456789012");
    assert_eq!(p.amount_paise, 500000);
    assert!(p.is_income);
    // Oversize input (paste-attack / corrupt read): refused, no regex spin.
    let big = "₹100 paid to Swiggy. ".repeat(2000);
    assert!(big.len() > 16 * 1024);
    assert!(kharcha_core::engine::parse(&big, "s", 0).is_none());
}

#[test]
fn inbox_line_round_trips() {
    let line = encode_inbox_line("com.phonepe.app", "₹450 paid", "t");
    assert!(line.contains("\"package\":\"com.phonepe.app\""));
    assert!(line.contains("\"text\":\"₹450 paid\""));
    assert!(line.contains("\"seenAt\":\"t\""));
    let quoted = encode_inbox_line("p", "say \"hi\"\nbye", "t");
    assert!(quoted.contains("\"text\":\"say \\\"hi\\\"\\nbye\""));
}
