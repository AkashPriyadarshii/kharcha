//! Spam rejection. Port of `_nonTransactionRe` + `isNonTransaction` in
//! `lib/core/upi_parser.dart`: recharge/promo/OTP/request/failure texts
//! return None before parsing.
//!
//! Pattern notes (parity with Dart `RegExp`, `caseSensitive: false`, non-unicode):
//! - `fancy-regex 0.14` rejects `(?-u)` (`NonUnicodeUnsupported`), so ASCII
//!   parity is mechanical: every `\d`→`[0-9]`, every `\s`→`[ \t\n\x0B\f\r]`
//!   (Dart's ASCII whitespace set). `\b` stays Unicode-aware — the only
//!   divergence, and only when non-ASCII word chars touch ASCII keywords;
//!   the parity corpus is real-world SMS (ASCII) and proves the behavior.
//! - Otherwise patterns are verbatim from the Dart source so the two files
//!   stay diffable.

use std::sync::LazyLock;

use fancy_regex::Regex;

/// Case-insensitive prefix; single place to change.
pub(crate) const ASCII_CI: &str = "(?i:";

fn compiled() -> &'static Regex {
    static RE: LazyLock<Regex> = LazyLock::new(|| {
        Regex::new(concat!(
            "(?i:",
            r#"\b(?:"#,
            // 1. Telecom Recharge: confirmations, promos, plans, validity, data packs
            r#"recharge (?:of|for|plan|pack|offer|done|successful|processed|is|credited|with|now|soon|your|immediately)|"#,
            r#"recharge.*(?:successful|done|processed|validity|number|mobile|prepaid)|"#,
            r#"successful recharge|recharge successful|recharge done|"#,
            r#"recharge ending|recharge will end|recharge expires|recharge expired|plan expires|plan expiring|"#,
            r#"validity expires|validity expiring|validity ending|pack expires|pack expiring|pack will expire|"#,
            r#"please recharge|plz recharge|to continue services|to enjoy unlimited|plan has expired|"#,
            r#"data pack|daily data|talktime|unlimited 5g|prepaid account|"#,
            r#"for your (?:jio|airtel|vi|vodafone|idea|bsnl) (?:number|mobile)|"#,
            r#"on (?:your )?(?:jio|airtel|vi|vodafone|idea|bsnl) (?:number|mobile)|"#,
            r#"(?:jio|airtel|vi|bsnl) prepaid|"#,
            r#"benefits:[ \t\n\x0B\f\r]*[0-9]|"#,
            // 2. Bill due / Payment due reminders / Statements
            r#"is due|due date|due on|bill generated|bill due|overdue|payment reminder|reminder:|"#,
            r#"bill of (?:rs|inr|₹)|bill amount of|pay before|pay your bill|outstanding bill|"#,
            r#"outstanding amount|payable amount|amount payable|minimum amount due|total amount due|"#,
            r#"statement for|statement generated|e-statement|"#,
            // 3. OTP & Security verification codes
            r#"otp\b|one time password|verification code|security code|secret code|do not share|"#,
            r#"is your code|auth code|use code [0-9]|pin for txn|"#,
            // 4. Marketing promos, Loan offers, Lottery, Referral & Investment spam
            r#"pre-approved|pre approved|loan offer|apply for loan|instant loan|personal loan of|personal loan|"#,
            r#"eligible for .*?(?:loan|credit)|loan sanctioned|approved loan|get a loan|quick cash|instant cash|"#,
            r#"convert (?:your )?(?:recent )?spend|convert to emi|into (?:easy )?emis|into [0-9]+ (?:easy )?emis|"#,
            r#"credit limit of|limit (?:has been )?increased|limit enhancement|credit limit upgrade|increased to (?:rs|inr|₹)|"#,
            r#"win up to|stand a chance to win|congratulations you won|congratulations!|congratulations\b|claim your reward|"#,
            r#"flat off|supercoins|free delivery|shop for|save extra|enjoy flat|use code|"#,
            r#"scratch card|refer and earn|invite and earn|voucher of (?:rs|inr|₹)|"#,
            // Premortem: "received Rs 100 cashback voucher" promos carry receive
            // verbs but move no money. Plain "voucher" is NOT enough to void a
            // message (audit #6): "Paid ₹200 to Swiggy using voucher" and "INR
            // 500 debited for Amazon voucher purchase" are real spends. Only
            // voucher tied to promo context gets rejected.
            r#"received[ \t\n\x0B\f\r]*(?:a |the )?(?:rs\.?|inr|₹)?[ \t\n\x0B\f\r]*[0-9,.]*[ \t\n\x0B\f\r]*cashback[ \t\n\x0B\f\r]*voucher|(?:win|won|claim|earn|grab|get)[ \t\n\x0B\f\r]*.*voucher|voucher[ \t\n\x0B\f\r]*(?:of|worth|credited|added|received)|(?:credited|received|added)[ \t\n\x0B\f\r]*.*?voucher|"#,
            r#"invest in|invest rs|start investing|trade now|"#,
            r#"e-kyc|kyc update|kyc pending|kyc blocked|kyc suspended|account blocked|account suspended|"#,
            r#"electricity.*disconnected|disconnected tonight|power.*disconnected|"#,
            r#"fastag|toll.*due|challan|parivahan|"#,
            // 5. Payment requests & Collect requests & Pending/Initiated (not completed payments)
            r#"requesting payment|requested payment|payment request|has requested|collect request|"#,
            r#"approve request|autopay request|mandate request|request to pay|request of (?:rs|inr|₹)|"#,
            r#"requested\b|standing instruction|mandate created|autopay scheduled|autopay reminder|"#,
            r#"\bpending\b|\binitiated\b|in progress|processing payment|\bprocessing\b|scheduled for|"#,
            r#"will be debited|will be deducted|will be charged|will be credited|"#,
            // 6. Failed, Declined, Blocked & Attempted transactions
            r#"attempted (?:txn|transaction)|blocked by bank|was blocked|blocked due to|"#,
            r#"failed|declined|unsuccessful|cancelled|canceled|could not be processed|timed out|aborted|rejected"#,
            r#")\b)"#,
        ))
        .expect("static non-transaction pattern")
    });
    &RE
}

/// True if `text` is a non-transaction message. Engine errors fail open
/// (false = keep parsing); static patterns are covered by tests below.
pub fn is_non_transaction(text: &str) -> bool {
    let t = text.trim();
    let lc = t.to_lowercase();
    if lc.contains("mandate created")
        && (lc.contains("debited") || lc.contains("credited") || lc.contains("deducted") || lc.contains("charged"))
    {
        return false;
    }
    compiled().is_match(t).unwrap_or(false)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn rejects_recharge_prompts() {
        for s in [
            "Ur recharge is ending or will end plz recharge with 196rs",
            "Dear Customer, your Jio pack of Rs 239 will expire on 25-Aug. Recharge now with Rs 239 to continue services.",
            "Your Airtel plan expires tomorrow. Please recharge with Rs 199 to enjoy unlimited calls.",
            "Your Vi pack validity ending today. Plz recharge with 299 immediately.",
            "Recharge of Rs 299 is successful for your Jio number 9876543210. Transaction ID: 123456789. Your plan validity is 28 days.",
            "Recharge of Rs. 199 is successful for mobile 9876543210. Benefits: 1.5GB/day.",
            "Recharge Successful! Rs 299 credited to your Jio prepaid account. Validity: 28 days.",
            "Payment received of Rs 299 for recharge of Airtel mobile 9876543210.",
            "Recharge done for Rs 479 on Vi mobile 9876543210.",
            "Your recharge of Rs 666 for Jio number 9876543210 is processed.",
        ] {
            assert!(is_non_transaction(s), "{s}");
        }
    }

    #[test]
    fn rejects_bills_otps_loans_requests_failures() {
        for s in [
            "Reminder: Electricity bill of Rs 1,450 is due on 30-Aug. Pay now to avoid disconnection.",
            "Your Credit Card bill of INR 12,500.00 is generated. Due date: 15-SEP-26.",
            "Payment reminder: Rs 599 is due for your broadband account.",
            "OTP for transaction of INR 450.00 at Zomato is 928301. Do not share OTP with anyone.",
            "Your verification code for payment of Rs 1,000 is 445566.",
            "Congratulations! You are eligible for pre-approved loan of Rs 5,00,000. Apply now.",
            "Avail instant personal loan of Rs. 1,00,000 in 2 minutes.",
            "Convert your recent spend of INR 4,500.00 on Card XX8812 into 6 easy EMIs of Rs 799. SMS EMI to 56767.",
            "Great news! Your credit limit on Card ending 4410 has been increased to Rs 2,50,000. Click to confirm.",
            "Alert! Attempted txn of Rs 15,000.00 on Card XX1098 was blocked by bank security. Call 18001080.",
            "Swiggy is requesting payment of Rs 350 via UPI. Approve in GPay.",
            "Collect request of Rs 500 received from rahul@upi.",
            "Payment of Rs 500 to Uber failed due to bank server issue.",
            "Transaction of Rs 1,200 at Swiggy was declined due to insufficient funds.",
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
            // Promos that mention voucher WITHOUT payment context.
            "Congratulations! You have won Rs 500 cashback voucher on PhonePe. Claim now.",
            "Received Rs 100 cashback voucher from Paytm. Use code VOUCH10.",
            "You have won Rs 500 cashback voucher. Claim now.",
            "Win up to Rs 10,000 on Cred. Spin now.",
            "Your credit limit of Rs 75,000 is approved. Click to activate.",
            // "Earn Rs 500 by referring..." carries no spam keyword — Dart nulls
            // it at the payment-verb gate, not here. Covered in tests/parity.rs.
            "Invest Rs 500 in top mutual funds today.",
            "Your ICICI Credit Card statement for Dec has been generated. Total amount due: Rs 4,500.",
        ] {
            assert!(is_non_transaction(s), "{s}");
        }
    }

    #[test]
    fn keeps_real_payments() {
        for s in [
            "₹450 paid to Swiggy using UPI UPI Ref 123456789012",
            "₹5000 received from Akash. UPI Ref 123456789012",
            "Paid Rs 150 on Swiggy. Earn up to Rs 20 cashback on next order.",
            // Audit #6: a voucher mention in a REAL payment is not spam.
            "Paid Rs 200 to Swiggy using voucher. UPI Ref 123456789012",
            "INR 500.00 debited for Amazon voucher purchase. UPI Ref 987654321012",
            "INR 899.00 refunded to your A/c XX1234 from Amazon. UPI Ref: 102938475610",
        ] {
            assert!(!is_non_transaction(s), "{s}");
        }
    }
}

