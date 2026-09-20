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
    // Audit #4: the cap guards DIRECT parser callers too, not just engine.
    assert!(kharcha_core::parser::parse_upi_notification(&big).is_none());
    // Under the cap still parses.
    assert!(kharcha_core::parser::parse_upi_notification("₹450 paid to Swiggy using UPI Ref 123456789012").is_some());
}

#[test]
fn multibyte_text_cant_panic_slicing() {
    // Audit: regex offsets into emoji-adjacent text can split char
    // boundaries — slicing guards fail open, never panic. Parses fine.
    let p = parsed("Paid ₹500 to Swiggy🎉. Ref 123456789012");
    assert_eq!(p.amount_paise, 50000);
    assert_eq!(p.upi_ref.as_deref(), Some("123456789012"));
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

#[test]
fn modern_indian_banks_benchmark_corpus() {
    // 1. HDFC Bank UPI Debit with unspaced UPI:ref
    let hdfc_debit = parsed("Alert! INR 340.00 debited from A/C **1234 on 23-AUG-26 to ZOMATO UPI:623829102812. Bal: INR 12,400.00. Not you? Call 18002586161.");
    assert_eq!(hdfc_debit.amount_paise, 34000);
    assert_eq!(hdfc_debit.merchant, "ZOMATO");
    assert!(!hdfc_debit.is_income);
    assert_eq!(hdfc_debit.upi_ref.as_deref(), Some("623829102812"));
    assert_eq!(hdfc_debit.account_mask.as_deref(), Some("1234"));
    assert_eq!(hdfc_debit.balance_paise, Some(1240000));

    // 2. HDFC Bank Card Spend
    let hdfc_card = parsed("Alert: INR 1,850.00 spent on HDFC Bank Card ending in 8812 at RELIANCE RETAIL on 14-SEP-26. Avl limit: INR 85,200.00.");
    assert_eq!(hdfc_card.amount_paise, 185000);
    assert_eq!(hdfc_card.merchant, "RELIANCE RETAIL");
    assert!(!hdfc_card.is_income);
    assert_eq!(hdfc_card.account_mask.as_deref(), Some("8812"));

    // 3. ICICI Card Spend with "Info: Swiggy" pattern
    let icici_card = parsed("Dear Customer, INR 7,689.62 is debited on ICICI Bank Credit Card XX5533 on 12-Sep-26. Info: Swiggy. Available Limit: INR 62,762.76.");
    assert_eq!(icici_card.amount_paise, 768962);
    assert_eq!(icici_card.merchant, "Swiggy");
    assert!(!icici_card.is_income);
    assert_eq!(icici_card.account_mask.as_deref(), Some("5533"));

    // 4. ICICI UPI Debit with Info: UPI/Ref/Merchant
    let icici_upi = parsed("Dear Customer, your A/c XX402 has been debited with INR 520.00 on 12-Sep-26. Info: UPI/425510294812/Swiggy. Avail Bal: INR 45,210.50.");
    assert_eq!(icici_upi.amount_paise, 52000);
    assert_eq!(icici_upi.merchant, "Swiggy");
    assert_eq!(icici_upi.upi_ref.as_deref(), Some("425510294812"));
    assert_eq!(icici_upi.account_mask.as_deref(), Some("402"));
    assert_eq!(icici_upi.balance_paise, Some(4521050));

    // 5. SBI Inward Remittance with mid-sentence remitter
    let sbi_income = parsed("Dear SBI UPI User, ur A/cX1690 credited by Rs1000.00 on 17Jan26 by RAMESH PATEL (Ref no 320125212325). Bal: Rs8500.50.");
    assert_eq!(sbi_income.amount_paise, 100000);
    assert!(sbi_income.is_income);
    assert_eq!(sbi_income.merchant, "RAMESH PATEL");
    assert_eq!(sbi_income.upi_ref.as_deref(), Some("320125212325"));
    assert_eq!(sbi_income.account_mask.as_deref(), Some("1690"));
    assert_eq!(sbi_income.balance_paise, Some(850050));

    // 6. Axis Bank Avail Lmt Spend
    let axis_spend = parsed("Axis Bank: INR 1,450.00 spent on your Credit Card XX9900 at PVR CINEMAS on 19-Sep-26. Avail Lmt: INR 1,12,300.00.");
    assert_eq!(axis_spend.amount_paise, 145000);
    assert_eq!(axis_spend.merchant, "PVR CINEMAS");
    assert_eq!(axis_spend.account_mask.as_deref(), Some("9900"));

    // 7. Axis Bank Card Refund
    let axis_refund = parsed("Axis Bank: INR 450.00 credited to Credit Card XX9900 on 20-Sep-26 towards refund from SWIGGY. Avail Lmt: INR 1,12,750.00.");
    assert_eq!(axis_refund.amount_paise, 45000);
    assert!(axis_refund.is_income);
    assert_eq!(axis_refund.merchant, "SWIGGY");
    assert_eq!(axis_refund.account_mask.as_deref(), Some("9900"));

    // 8. Canara Bank Clr Bal UPI Debit
    let canara = parsed("Your A/C XX3211 is debited for INR 1,500.00 on 18-Sep-26 towards UPI txn to PETROL PUMP UTR:426102938491. Clr Bal is INR 28,900.50. -Canara Bank");
    assert_eq!(canara.amount_paise, 150000);
    assert_eq!(canara.merchant, "PETROL PUMP");
    assert_eq!(canara.upi_ref.as_deref(), Some("426102938491"));
    assert_eq!(canara.account_mask.as_deref(), Some("3211"));
    assert_eq!(canara.balance_paise, Some(2890050));

    // 9. OneCard Credit Card Spend
    let onecard = parsed("Rs. 4,200.00 spent on your OneCard ending in 5621 at ZARA on 18-Sep-26. Available limit: Rs. 95,800.00.");
    assert_eq!(onecard.amount_paise, 420000);
    assert_eq!(onecard.merchant, "ZARA");
    assert_eq!(onecard.account_mask.as_deref(), Some("5621"));

    // 10. Executed e-Mandate / NACH Auto-Debit
    let mandate = parsed("Dear Customer, Rs.499.00 has been debited from your A/c XX1234 on 20-Sep-26 via NACH/Autopay mandate for NETFLIX. Ref No: MN202609201928. -HDFC Bank");
    assert_eq!(mandate.amount_paise, 49900);
    assert_eq!(mandate.merchant, "NETFLIX");
    assert_eq!(mandate.upi_ref.as_deref(), Some("MN202609201928"));
    assert_eq!(mandate.account_mask.as_deref(), Some("1234"));

    // 11. DLT Sender Header Bank Enrichment via engine::parse
    let tx = kharcha_core::engine::parse(
        "Alert! INR 500.00 debited for Zomato. UPI Ref 426190283012",
        "AD-HDFCBK-T",
        1000
    ).unwrap();
    assert_eq!(tx.payment.bank_name.as_deref(), Some("HDFC"));
    assert_eq!(tx.payment.merchant, "Zomato");

    // 12. Kotak Mahindra Bank Outbound UPI
    let kotak = parsed("Sent Rs.250.00 from Kotak Bank A/c XX4312 to Chaayos on 19-Sep-26. UPI Ref: 426210928301. Bal: Rs.18,920.40.");
    assert_eq!(kotak.amount_paise, 25000);
    assert_eq!(kotak.merchant, "Chaayos");
    assert_eq!(kotak.upi_ref.as_deref(), Some("426210928301"));
    assert_eq!(kotak.account_mask.as_deref(), Some("4312"));
    assert_eq!(kotak.balance_paise, Some(1892040));

    // 13. IDFC FIRST Bank UPI Debit
    let idfc = parsed("Paid! INR 1,200.00 debited from IDFC FIRST Bank A/c XX5567 to Apollo Pharmacy on 18-Sep-26. UPI Ref: 426102938475. Updated Bal: INR 52,190.22.");
    assert_eq!(idfc.amount_paise, 120000);
    assert_eq!(idfc.merchant, "Apollo Pharmacy");
    assert_eq!(idfc.upi_ref.as_deref(), Some("426102938475"));
    assert_eq!(idfc.account_mask.as_deref(), Some("5567"));
    assert_eq!(idfc.balance_paise, Some(5219022));

    // 14. IndusInd Bank UPI Debit (Info: format)
    let indus = parsed("Your IndusInd Bank A/c XX9921 has been debited by Rs 420.00 on 18-Sep-26. UPI Ref no 426190283910. Info: BLINKIT. Avail Bal: Rs 14,800.00.");
    assert_eq!(indus.amount_paise, 42000);
    assert_eq!(indus.merchant, "BLINKIT");
    assert_eq!(indus.upi_ref.as_deref(), Some("426190283910"));
    assert_eq!(indus.account_mask.as_deref(), Some("9921"));
    assert_eq!(indus.balance_paise, Some(1480000));

    // 15. Federal Bank UPI Debit
    let fed = parsed("Rs 350.00 debited from Federal Bank A/c ending in 1122 on 19-Sep-26 for UPI txn to Swiggy Instamart. UPI Ref: 426210928391. Avl Bal: Rs 9,450.00.");
    assert_eq!(fed.amount_paise, 35000);
    assert_eq!(fed.merchant, "Swiggy Instamart");
    assert_eq!(fed.upi_ref.as_deref(), Some("426210928391"));
    assert_eq!(fed.account_mask.as_deref(), Some("1122"));
    assert_eq!(fed.balance_paise, Some(945000));

    // 16. Punjab National Bank (PNB) UPI Debit
    let pnb = parsed("Dear Customer, A/c **4589 debited for Rs.750.00 on 18-Sep-26 thru UPI: 426189201928 to BIGBASKET. Avl Bal Rs.32,150.80. PNB");
    assert_eq!(pnb.amount_paise, 75000);
    assert_eq!(pnb.merchant, "BIGBASKET");
    assert_eq!(pnb.upi_ref.as_deref(), Some("426189201928"));
    assert_eq!(pnb.account_mask.as_deref(), Some("4589"));
    assert_eq!(pnb.balance_paise, Some(3215080));

    // 17. Bank of Baroda UPI Debit
    let bob = parsed("A/c XX7821 debited for INR 430.00 on 18-Sep-26 by UPI/426190283719/ZEPTO. Bal: INR 19,400.00. Helpline 18002584455.");
    assert_eq!(bob.amount_paise, 43000);
    assert_eq!(bob.merchant, "ZEPTO");
    assert_eq!(bob.upi_ref.as_deref(), Some("426190283719"));
    assert_eq!(bob.account_mask.as_deref(), Some("7821"));
    assert_eq!(bob.balance_paise, Some(1940000));

    // 18. Union Bank UPI Debit
    let union = parsed("Union Bank Alert: A/C ending in 9012 debited for Rs 850.00 on 19-Sep-26. Info: UPI/426210928391/BOOKMYSHOW. Avl Bal: Rs 15,420.00.");
    assert_eq!(union.amount_paise, 85000);
    assert_eq!(union.merchant, "BOOKMYSHOW");
    assert_eq!(union.upi_ref.as_deref(), Some("426210928391"));
    assert_eq!(union.account_mask.as_deref(), Some("9012"));
    assert_eq!(union.balance_paise, Some(1542000));

    // 19. Contactless Tap & Pay POS
    let pos = parsed("Contactless transaction of INR 1,450.00 done on ICICI Bank Debit Card XX4019 at CAFE COFFEE DAY on 19-Sep-26. Avl Bal: INR 22,100.00.");
    assert_eq!(pos.amount_paise, 145000);
    assert_eq!(pos.merchant, "CAFE COFFEE DAY");
    assert_eq!(pos.account_mask.as_deref(), Some("4019"));
    assert_eq!(pos.balance_paise, Some(2210000));

    // 20. Modern Neobank & UPI App Push Notifications
    let navi = parsed("₹200 sent to Blinkit successfully. UPI Ref: 426190283011");
    assert_eq!(navi.amount_paise, 20000);
    assert_eq!(navi.merchant, "Blinkit");
    assert_eq!(navi.upi_ref.as_deref(), Some("426190283011"));

    let slice = parsed("Paid ₹899 to Myntra using Slice account.");
    assert_eq!(slice.amount_paise, 89900);
    assert_eq!(slice.merchant, "Myntra");

    let cred = parsed("Paid ₹1,850 at Blue Tokai using CRED UPI. Ref 426190283910");
    assert_eq!(cred.amount_paise, 185000);
    assert_eq!(cred.merchant, "Blue Tokai");
    assert_eq!(cred.upi_ref.as_deref(), Some("426190283910"));

    // 21. ATM Cash Withdrawal
    let atm = parsed("A/c XXXXXX5715 debited for Rs 2000; ATM WDL. A/c Bal (sub to chq realisatn) Rs 13,286.23 on 24APR 21:19hr.");
    assert_eq!(atm.amount_paise, 200000);
    assert_eq!(atm.merchant, "ATM Cash Withdrawal");
    assert_eq!(atm.account_mask.as_deref(), Some("5715"));
    assert_eq!(atm.balance_paise, Some(1328623));

    // 22. Direct Payee Without Prepositions
    let direct = parsed("Transferred INR 500.00 Ramesh Kumar Ref: 123456789012");
    assert_eq!(direct.amount_paise, 50000);
    assert_eq!(direct.merchant, "Ramesh Kumar");
    assert_eq!(direct.upi_ref.as_deref(), Some("123456789012"));

    // 23. Country-Coded Indian Mobile Number VPA Normalization
    let p_plus91 = parsed("Paid ₹500 to +919876543210@ybl via UPI. Ref 111122223333");
    assert_eq!(p_plus91.merchant, "9876543210");
    let p_91 = parsed("Paid ₹350 to 919876543210@paytm using UPI. Ref 222233334444");
    assert_eq!(p_91.merchant, "9876543210");
}

#[test]
fn mandate_autopay_debit_is_real_payment() {
    let p = parsed("Rs 1,999 debited for mandate towards Netflix via autopay. UPI Ref 123456789012");
    assert_eq!(p.amount_paise, 199900);
    assert_eq!(p.merchant, "Netflix");
    assert!(!p.is_income);
}

#[test]
fn corpus_growth_p1_rows() {
    // IMPS/NEFT via existing patterns, Yes Bank, UPI handle, POS city suffix
    let imps = parsed("INR 5,000 credited to A/c XX1234 via IMPS from SALARY. UPI Ref 123456789012");
    assert!(imps.is_income);
    let yes = parsed("Yes Bank: Rs 900 debited from A/c XX2211 towards UPI to DUNZO. Ref 426190283911");
    assert_eq!(yes.merchant, "DUNZO");
    let wa = parsed("You paid ₹250 to Chaayos via UPI. UPI Ref 123456789013");
    assert_eq!(wa.merchant, "Chaayos");
}

#[test]
fn whatsapp_bigbasket_promo_is_null_via_engine() {
    // Generic promo: "50 credited to wallet" via WhatsApp without banking anchor → null.
    // No merchant hardcode; paytm wallet cashback via bank sender still parses (see notifications.rs).
    use kharcha_core::engine::parse;
    assert!(parse("Rs 50 credited to your wallet from bigbasket", "whatsapp", 0).is_none());
    assert!(parse("Rs 50 credited to your wallet", "WHATSAPP", 0).is_none());
    // Same text via bank sender is not suppressed (engine only gates messaging senders)
    assert!(kharcha_core::parse_upi_notification("Cashback of ₹50 credited to your Paytm wallet").is_some());
}
