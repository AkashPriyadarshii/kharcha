//! Unified UPI/bank payment parser.
//!
//! Single source of truth. Replaces BOTH `lib/core/upi_parser.dart` and the
//! Kotlin `GenericUpiParser.kt` (which drifted apart and carried divergent
//! fixes — the root of the historical "parse bug then patch it twice" churn).
//! Non-transaction rejection is the UNION of both implementations' spam
//! filters: if either considered a message non-transactional, so do we.
//! Rule-based only — no AI.

use std::sync::LazyLock;

use fancy_regex::Regex;

use crate::money::parse_amount;

/// A UPI/bank payment parsed from a notification's or SMS's text.
#[derive(Debug, Clone, PartialEq)]
pub struct ParsedPayment {
    pub amount: f64,
    pub merchant: String,
    /// True when money came IN (received/credited). False for spending.
    pub is_income: bool,
    pub upi_ref: Option<String>,
    /// The true bank balance extracted from the message (if available).
    pub balance: Option<f64>,
    pub account_mask: Option<String>,
    pub bank_name: Option<String>,
    /// True when extraction leaned on a heuristic (contextual amount or
    /// fallback merchant) — the UI flags these for a quick human confirm.
    pub needs_review: bool,
}

// Amount: ₹ / Rs. / INR, optional space, digits + optional decimals (supports Indian comma system).
static AMOUNT_RE: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"(?i)(?:₹|Rs\.?|INR)\s*([0-9,]+(?:\.[0-9]{1,2})?)").unwrap()
});
static AMOUNT_TRAILING_RE: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"(?i)([0-9,]+(?:\.[0-9]{1,2})?)\s*(?:₹|Rs\.?|INR)").unwrap()
});
// Fallback amount in contextual banking sentences: "debited by 500.00" or "credited with 1000".
static CONTEXTUAL_AMOUNT_RE: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"(?i)(?:debited (?:by|for)|credited (?:with|by)|spent|paid|amount of|txn of|transfer of)\s+(?:INR|Rs\.?|₹)?\s*([0-9,]+(?:\.[0-9]{1,2})?)").unwrap()
});
// Spend verbs (outgoing).
static SPEND_RE: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"(?i)\b(?:debited|paid|transferred|sent|spent|payment|txn|transaction|purchase|withdrawn|charged|deducted)\b").unwrap()
});
// Money-in verbs (incoming).
static RECEIVE_RE: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"(?i)\b(?:received|credited|added to your|added in your|added to|refund|refunded|cashback|paid you|sent you|(?:sent|paid|transferred|given|credited).{0,20}to you|deposited|credited with|money received|inward)\b").unwrap()
});
// UPI/DR or UPI/CR bank narration format: e.g. "Info: UPI/DR/123456789012/SWIGGY/HDFC".
static BANK_NARRATION_RE: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"(?i)UPI\/(?:DR|CR|P2A|P2M|P2P|REV)\/(\d+)\/([A-Za-z0-9 &.\-_]+)").unwrap()
});
// GPay bullet format: "Money sent · ₹200 · Swiggy".
static GPAY_MERCHANT_RE: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"(?i)·\s*([A-Za-z0-9][A-Za-z0-9 &.\-]{1,60}?)(?=\s*·|\s+UPI|\s+Ref|$)").unwrap()
});
// High-priority explicit recipient: "to X", "paid to X", "at X", "done at X".
static RECIPIENT_MERCHANT_RE: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"(?i)(?:spent on .*? at|(?:paid|payment|transferred|sent)\s+(?:(?:₹|rs\.?|inr)\s*[0-9,.]+\s+)?(?:to|at|on)|paid to|transferred to|sent to|payment to|sent .{0,12}to|done at|\bto\b|\bat\b)\s+(?!(?:you|rs\.?|inr|₹|\d)\b)([A-Za-z0-9][A-Za-z0-9 &.\-@]{1,60}?)(?=,|\.|$|:|\s+(?:of\s*(?:₹|Rs\.?|INR|\d)|upi|ref|utr|trans|txn|bal|balance|on\s+\d|on\s+[A-Za-z]|at\s+\d|via|bank|a/c|by|from|using|credited|debited|successful|is\s+successful|was\s+successful))").unwrap()
});
// Fallback purpose/source: "from X", "towards X", "for X", "debited from X".
static FALLBACK_MERCHANT_RE: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"(?i)(?:from|towards|for|debited (?:at|from))\s+(?!(?:you|rs\.?|inr|₹|\d)\b)([A-Za-z0-9][A-Za-z0-9 &.\-@]{1,60}?)(?=,|\.|$|:|\s+(?:of\s*(?:₹|Rs\.?|INR|\d)|upi|ref|utr|trans|txn|bal|balance|on\s+\d|on\s+[A-Za-z]|at\s+\d|via|bank|a/c|by|from|using|credited|debited|successful|is\s+successful|was\s+successful))").unwrap()
});
// UPI reference / UTR regexes.
static UPI_REF_RE: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"(?i)(?:upi\s*ref(?:erence)?(?:\s*no)?|\bupi\b|utr(?:\s*no)?|ref(?:erence)?\s*id|ref\s*id|ref(?:\s*no)?|trans(?:action)?\s*id|txn\s*id)\s*[:#-]?\s*([A-Za-z0-9]{8,})").unwrap()
});
static UPI_REF_BARE_RE: LazyLock<Regex> = LazyLock::new(|| Regex::new(r"\b(\d{12})\b").unwrap());
static ACCOUNT_MASK_RE: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"(?i)(?:a/c|acct|account)(?:\s*no\.?|\s*number)?(?:\s*ending\s*(?:in|with))?\s*(?:x|X|\*)*(\d{3,18})\b").unwrap()
});
static BANK_NAME_RE: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"(?i)\b(SBI|HDFC|ICICI|Axis|Kotak|PNB|BOB|IDFC|IndusInd|Yes Bank|Canara|Union Bank|Indian Bank|State Bank of India|Bank of Baroda|Paytm Payments Bank|Airtel Payments Bank|Jio Payments Bank|Federal Bank|South Indian Bank)\b").unwrap()
});
// Income disambiguation helpers.
static SENT_TO_YOU_RE: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"(?i)(?:sent|paid|transferred|given|credited).{0,20}to you").unwrap());
static CREDITED_TO_ACCOUNT_RE: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"(?i)(?:credited|deposited|added)\s+(?:to|in|into)\s+(?:your\s+)?(?:a\/c|acct|account|wallet|balance)").unwrap()
});
static PAYMENT_RECEIVED_FROM_RE: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"(?i)(?:payment|amount|money|\b)\s*received\s+(?:(?:(?:rs\.?|inr|₹)\s*[0-9,.]+|[0-9,.]+)\s+)?from\b").unwrap()
});
static RECEIVED_EXCLUDED_RE: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"(?i)received\s+(?:by|for|towards|at)\b").unwrap());
// Income sender at line start: "papa sent Rs 2400 to you".
static INCOME_SENDER_RE: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"(?i)^([A-Za-z0-9][A-Za-z0-9 &.\-@]{1,60}?)\s+(?:sent|paid|transferred|given|credited)").unwrap()
});
// Amount matchers must not treat a balance figure as the transaction amount.
static BALANCE_PREFIX_RE: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"(?i)\b(?:bal|balance|avl\s*bal|available\s*(?:bal|balance)|limit|credit\s*limit)[\s:=-]*$").unwrap()
});
static BAL_RE: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"(?i)(?:bal|balance|avl bal|available balance)[^0-9]*?(?:₹|Rs\.?|INR)?\s*([0-9,]+(?:\.[0-9]{1,2})?)").unwrap()
});
// Non-transaction rejection: recharge, bill due, OTP, marketing/loans,
// payment requests, pending/initiated, failed. UNION of the Dart and Kotlin
// implementations — if either app considered it spam, we reject it.
// Sections: 1 recharge/data-pack, 2 bill-due/statement, 3 OTP/codes,
// 4 promo/loan/invest, 5 request/mandate/pending, 6 failed/declined.
static NON_TRANSACTION_RE: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(
        concat!(
        r"(?i)\b(?:",
        r"recharge (?:of|for|plan|pack|offer|done|successful|processed|is|credited|with|now|soon|your|immediately)|",
        r"recharge.*(?:successful|done|processed|validity|number|mobile|prepaid)|",
        r"successful recharge|recharge successful|recharge done|",
        r"recharge ending|recharge will end|recharge expires|recharge expired|plan expires|plan expiring|",
        r"validity expires|validity expiring|validity ending|pack expires|pack expiring|pack will expire|",
        r"please recharge|plz recharge|to continue services|to enjoy unlimited|plan has expired|",
        r"data pack|daily data|talktime|unlimited 5g|prepaid account|",
        r"for your (?:jio|airtel|vi|vodafone|idea|bsnl)|",
        r"on (?:your )?(?:jio|airtel|vi|vodafone|idea|bsnl) (?:number|mobile)|",
        r"(?:jio|airtel|vi|vodafone|idea|bsnl) prepaid|",
        r"benefits:\s*\d|",
        r"is due|due date|due on|bill generated|bill due|overdue|payment reminder|reminder:|",
        r"bill of (?:rs|inr|₹)|bill amount of|pay before|pay your bill|outstanding bill|",
        r"outstanding amount|payable amount|amount payable|minimum amount due|total amount due|",
        r"statement for|statement generated|e-statement|",
        r"otp\b|one time password|verification code|security code|secret code|do not share|",
        r"is your code|auth code|use code \d|pin for txn|",
        r"pre-approved|pre approved|loan offer|apply for loan|instant loan|personal loan of|personal loan|",
        r"credit limit of|approved loan|get a loan|quick cash|instant cash|",
        r"win up to|stand a chance to win|congratulations you won|congratulations!|congratulations\b|claim your reward|",
        r"flat off|supercoins|free delivery|shop for|save extra|enjoy flat|use code|",
        r"scratch card|refer and earn|invite and earn|voucher of (?:rs|inr|₹)|",
        r"convert (?:your )?(?:txn|purchase|amount)\b|",
        r"invest in|invest rs|start investing|trade now|",
        r"requesting payment|requested payment|payment request|has requested|collect request|",
        r"approve request|autopay request|mandate request|request to pay|request of (?:rs|inr|₹)|",
        r"requested\b|standing instruction|mandate created|autopay scheduled|",
        r"\bpending\b|\binitiated\b|in progress|processing payment|\bprocessing\b|scheduled for|",
        r"will be debited|will be credited|",
        r"failed|declined|unsuccessful|cancelled|canceled|could not be processed|timed out|aborted|rejected|",
        r"could\s+not\s+be\s+processed)",
        r"\b",
    ))
    .unwrap()
});

static TRAILING_KEYWORD_RE: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(
        r"(?i)\s+(?:via|using|on|through|in|UPI|Ref|UTR|Bank|A/c|Account|Pv|Pvt|Ltd|Limited|is|was|successful|successfully)$",
    )
    .unwrap()
});
static TRAILING_PUNCT_RE: LazyLock<Regex> = LazyLock::new(|| Regex::new(r"[\s.,:;/\-]+$").unwrap());
static INVALID_MERCHANT_RE: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(
        r"(?i)^(?:your|your a/c|your account|account|bank|upi|self|vpa|cashback|\d+|rs\.?.*|inr.*)$",
    )
    .unwrap()
});

/// True if [text] is a non-transaction message (recharge alert, bill due,
/// promo, request, or failure).
pub fn is_non_transaction(text: &str) -> bool {
    NON_TRANSACTION_RE.is_match(text.trim()).unwrap_or(false)
}

fn clean_merchant(raw: &str) -> String {
    let mut name = raw.trim().to_string();

    // 1. Handle VPA handles e.g. name@bank. Allocation-free prefix checks.
    if let Some(at) = name.find('@') {
        let vpa_user = name[..at].trim();
        let lower_user = vpa_user.to_lowercase();
        if lower_user.starts_with("paytmqr") {
            name = "Paytm Merchant".to_string();
        } else if lower_user.starts_with("bharatpe") {
            name = "BharatPe Merchant".to_string();
        } else if lower_user.starts_with("gpay") || lower_user.starts_with("googlepay") {
            name = "Google Pay Merchant".to_string();
        } else if lower_user.starts_with("phonepe") {
            name = "PhonePe Merchant".to_string();
        } else {
            let raw_handle = vpa_user
                .split(|c: char| c == '.' || c == '_' || c == '-')
                .next()
                .unwrap_or("");
            if raw_handle.chars().all(|c| c.is_ascii_digit()) && raw_handle.len() >= 8 {
                // Numeric VPA (mobile number as handle): mask the last 4 digits.
                let (_, tail) = raw_handle.split_at(raw_handle.len() - 4);
                name = format!("UPI User ({tail})");
            } else {
                let cleaned = raw_handle.trim_end_matches(|c: char| c.is_ascii_digit());
                if cleaned.chars().count() >= 3 {
                    let mut chars = cleaned.chars();
                    let first = chars.next().unwrap_or(' ');
                    name = first.to_uppercase().collect::<String>() + &chars.as_str().to_lowercase();
                } else {
                    name = vpa_user.to_string();
                }
            }
        }
    }

    // 2. Strip trailing keywords often captured in loose boundary matches.
    name = TRAILING_KEYWORD_RE.replace_all(&name, "").to_string();
    // 3. Strip trailing punctuation.
    name = TRAILING_PUNCT_RE.replace_all(&name, "").to_string();
    name = name.trim().to_string();

    // 4. Filter generic invalid names.
    if INVALID_MERCHANT_RE.is_match(&name).unwrap_or(false) {
        return "Unknown".to_string();
    }
    // 5. Title-case names that arrived fully lowercase.
    if !name.is_empty() && name == name.to_lowercase() {
        if let Some(first) = name.chars().next() {
            let rest = &name[first.len_utf8()..];
            name = first.to_uppercase().collect::<String>() + rest;
        }
    }
    if name.is_empty() {
        return "Unknown".to_string();
    }
    name
}

/// Parses [text] into a payment, or `None` if it isn't a payment notification
/// (no amount, no payment verb, or a rejected non-transaction message).
pub fn parse_payment(text: &str) -> Option<ParsedPayment> {
    let clean = text.trim();
    if clean.is_empty() {
        return None;
    }

    // 0. Explicit rejection of non-transaction messages.
    if is_non_transaction(clean) {
        return None;
    }

    // 1. Amount extraction.
    let mut used_contextual_amount = false;

    let all_amount: Vec<fancy_regex::Captures> = AMOUNT_RE.captures_iter(clean).flatten().collect();
    let mut amount_caps: Option<&fancy_regex::Captures> = None;
    for c in &all_amount {
        let start = c.get(0).unwrap().start();
        if !BALANCE_PREFIX_RE.is_match(&clean[..start]).unwrap_or(false) {
            amount_caps = Some(c);
            break;
        }
    }
    amount_caps = amount_caps.or_else(|| all_amount.first());

    let mut raw_amount: Option<&str> = amount_caps.and_then(|c| c.get(1)).map(|m| m.as_str());
    if raw_amount.is_none() || raw_amount == Some("") {
        let all_trailing: Vec<fancy_regex::Captures> = AMOUNT_TRAILING_RE.captures_iter(clean).flatten().collect();
        let mut trailing_caps: Option<&fancy_regex::Captures> = None;
        for c in &all_trailing {
            let start = c.get(0).unwrap().start();
            if !BALANCE_PREFIX_RE.is_match(&clean[..start]).unwrap_or(false) {
                trailing_caps = Some(c);
                break;
            }
        }
        trailing_caps = trailing_caps.or_else(|| all_trailing.first());
        raw_amount = trailing_caps.and_then(|c| c.get(1)).map(|m| m.as_str());
    }
    if raw_amount.is_none() || raw_amount == Some("") {
        let ctx = CONTEXTUAL_AMOUNT_RE.captures(clean).ok().flatten();
        raw_amount = ctx.and_then(|c| c.get(1)).map(|m| m.as_str());
        if raw_amount.is_some() && raw_amount != Some("") {
            used_contextual_amount = true;
        }
    }
    let raw_amount = raw_amount?;
    if raw_amount.is_empty() {
        return None;
    }

    let amount = parse_amount(&raw_amount.replace(',', ""))?;
    if amount <= 0.0 {
        return None;
    }

    // 2. Transaction direction (income vs spend).
    let has_receive = RECEIVE_RE.is_match(clean).unwrap_or(false);
    let has_spend = SPEND_RE.is_match(clean).unwrap_or(false);
    if !has_receive && !has_spend {
        return None; // casual chat or unrelated notification
    }

    let lower = clean.to_lowercase();
    let is_income = has_receive
        && (!has_spend
            || lower.contains("paid you")
            || lower.contains("sent you")
            || SENT_TO_YOU_RE.is_match(clean).unwrap_or(false)
            || CREDITED_TO_ACCOUNT_RE.is_match(clean).unwrap_or(false)
            || lower.contains("credited with")
            || lower.contains("refund")
            || PAYMENT_RECEIVED_FROM_RE.is_match(clean).unwrap_or(false)
            || (lower.contains("received")
                && !RECEIVED_EXCLUDED_RE.is_match(clean).unwrap_or(false)
                && !lower.contains("debited")
                && !lower.contains("spent")
                && !lower.contains("paid to")));

    // 3. Merchant extraction.
    let mut merchant: Option<String> = None;
    let mut ref_val: Option<String> = None;

    // Bank narration first: "Info: UPI/DR/123456789012/SWIGGY/HDFC".
    if let Some(caps) = BANK_NARRATION_RE.captures(clean).ok().flatten() {
        if let Some(r) = caps.get(1) {
            ref_val = Some(r.as_str().to_string());
        }
        if let Some(m) = caps.get(2) {
            let cand = clean_merchant(m.as_str());
            if !cand.is_empty() {
                merchant = Some(cand);
            }
        }
    }

    if merchant.as_deref().is_none_or(|m| m == "Unknown") {
        if let Some(caps) = GPAY_MERCHANT_RE.captures(clean).ok().flatten() {
            if let Some(m) = caps.get(1) {
                let cand = clean_merchant(m.as_str());
                if cand != "Unknown" {
                    merchant = Some(cand);
                }
            }
        }
    }

    if merchant.as_deref().is_none_or(|m| m == "Unknown") {
        if let Some(caps) = RECIPIENT_MERCHANT_RE.captures(clean).ok().flatten() {
            if let Some(m) = caps.get(1) {
                let cand = clean_merchant(m.as_str());
                if cand != "Unknown" {
                    merchant = Some(cand);
                }
            }
        }
    }

    let mut used_fallback_merchant = false;
    if merchant.as_deref().is_none_or(|m| m == "Unknown") {
        if let Some(caps) = FALLBACK_MERCHANT_RE.captures(clean).ok().flatten() {
            if let Some(m) = caps.get(1) {
                let cand = clean_merchant(m.as_str());
                if cand != "Unknown" {
                    merchant = Some(cand);
                    used_fallback_merchant = true;
                }
            }
        }
    }

    if merchant.as_deref().is_none_or(|m| m == "Unknown") && is_income {
        if let Some(caps) = INCOME_SENDER_RE.captures(clean).ok().flatten() {
            if let Some(m) = caps.get(1) {
                let cand = clean_merchant(m.as_str());
                if !cand.eq_ignore_ascii_case("you") && !cand.eq_ignore_ascii_case("i") {
                    merchant = Some(cand);
                }
            }
        }
    }
    let merchant = merchant.unwrap_or_else(|| "Unknown".to_string());

    // 4. UPI Ref / UTR extraction.
    if ref_val.is_none() {
        ref_val = UPI_REF_RE
            .captures(clean)
            .ok()
            .flatten()
            .and_then(|c| c.get(1))
            .map(|m| m.as_str().to_string());
    }
    if ref_val.is_none() && (has_spend || has_receive) {
        for m in UPI_REF_BARE_RE.find_iter(clean).flatten() {
            let cand = m.as_str();
            let prefix = &clean[..m.start()];
            // Exclude 12-digit numbers preceded by account/card identifiers.
            let acct = Regex::new(
                r"(?i)(?:a/c|acct|account|card)(?:\s*no\.?|\s*number)?(?:\s*ending\s*(?:in|with))?\s*(?:x|X|\*)*\s*$",
            )
            .unwrap();
            if acct.is_match(prefix).unwrap_or(false) {
                continue;
            }
            ref_val = Some(cand.to_string());
            break;
        }
    }

    // 5. Balance extraction ("Avail Bal: Rs 10000").
    let balance = BAL_RE
        .captures(clean)
        .ok()
        .flatten()
        .and_then(|c| c.get(1))
        .and_then(|m| parse_amount(&m.as_str().replace(',', "")));

    // 6. Account mask and bank name.
    let account_mask = ACCOUNT_MASK_RE
        .captures(clean)
        .ok()
        .flatten()
        .and_then(|c| c.get(1))
        .map(|m| m.as_str().to_string());
    let bank_name = BANK_NAME_RE
        .captures(clean)
        .ok()
        .flatten()
        .map(|c| c.get(1).unwrap().as_str().to_string());

    let needs_review = used_contextual_amount || used_fallback_merchant;

    Some(ParsedPayment {
        amount,
        merchant,
        is_income,
        upi_ref: ref_val,
        balance,
        account_mask,
        bank_name,
        needs_review,
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    fn pp(text: &str) -> ParsedPayment {
        parse_payment(text).unwrap_or_else(|| panic!("expected parse of: {text}"))
    }

    fn merchant(text: &str) -> String {
        pp(text).merchant
    }

    #[test]
    fn rejects_non_transaction_and_garbage() {
        assert_eq!(parse_payment(""), None);
        assert_eq!(parse_payment("   "), None);
        assert_eq!(parse_payment("You have a new message from Swiggy"), None);
        assert_eq!(parse_payment("Bhai ₹200 bhej de"), None);
        // Recharge expiry/validity prompts
        assert_eq!(parse_payment("Ur recharge is ending or will end plz recharge with 196rs"), None);
        assert_eq!(parse_payment("Dear Customer, your Jio pack of Rs 239 will expire on 25-Aug. Recharge now with Rs 239 to continue services."), None);
        assert_eq!(parse_payment("Your Airtel plan expires tomorrow. Please recharge with Rs 199 to enjoy unlimited calls."), None);
        assert_eq!(parse_payment("Your Vi pack validity ending today. Plz recharge with 299 immediately."), None);
        assert_eq!(parse_payment("Recharge of Rs 299 is successful for your Jio number 9876543210. Transaction ID: 123456789. Your plan validity is 28 days."), None);
        assert_eq!(parse_payment("Recharge of Rs. 199 is successful for mobile 9876543210. Benefits: 1.5GB/day."), None);
        assert_eq!(parse_payment("Recharge Successful! Rs 299 credited to your Jio prepaid account. Validity: 28 days."), None);
        assert_eq!(parse_payment("Payment received of Rs 299 for recharge of Airtel mobile 9876543210."), None);
        assert_eq!(parse_payment("Recharge done for Rs 479 on Vi mobile 9876543210."), None);
        assert_eq!(parse_payment("Your recharge of Rs 666 for Jio number 9876543210 is processed."), None);
        // Bill due reminders
        assert_eq!(parse_payment("Reminder: Electricity bill of Rs 1,450 is due on 30-Aug. Pay now to avoid disconnection."), None);
        assert_eq!(parse_payment("Your Credit Card bill of INR 12,500.00 is generated. Due date: 15-SEP-26."), None);
        assert_eq!(parse_payment("Payment reminder: Rs 599 is due for your broadband account."), None);
        assert_eq!(parse_payment("Your ICICI Credit Card statement for Dec has been generated. Total amount due: Rs 4,500."), None);
        // OTP / verification codes
        assert_eq!(parse_payment("OTP for transaction of INR 450.00 at Zomato is 928301. Do not share OTP with anyone."), None);
        assert_eq!(parse_payment("Your verification code for payment of Rs 1,000 is 445566."), None);
        // Marketing / loan promos
        assert_eq!(parse_payment("Congratulations! You are eligible for pre-approved loan of Rs 5,00,000. Apply now."), None);
        assert_eq!(parse_payment("Avail instant personal loan of Rs. 1,00,000 in 2 minutes."), None);
        assert_eq!(parse_payment("Pre-approved personal loan of ₹5,00,000 at 10.5% interest. Apply now."), None);
        assert_eq!(parse_payment("Congratulations! You have won Rs 500 cashback voucher on PhonePe. Claim now."), None);
        assert_eq!(parse_payment("Win up to Rs 10,000 on Cred. Spin now."), None);
        assert_eq!(parse_payment("Your credit limit of Rs 75,000 is approved. Click to activate."), None);
        assert_eq!(parse_payment("Earn Rs 500 by referring your friends to the app."), None);
        assert_eq!(parse_payment("Invest Rs 500 in top mutual funds today."), None);
        // Payment / collect requests, pending, initiated
        assert_eq!(parse_payment("Swiggy is requesting payment of Rs 350 via UPI. Approve in GPay."), None);
        assert_eq!(parse_payment("Collect request of Rs 500 received from rahul@upi."), None);
        assert_eq!(parse_payment("Akash has requested Rs 500 from you on PhonePe. Click here to approve."), None);
        assert_eq!(parse_payment("Payment request of Rs 1,200 received from Ramesh on Google Pay."), None);
        assert_eq!(parse_payment("Collect request of Rs 350 initiated by Zomato. Authorize in your UPI app."), None);
        assert_eq!(parse_payment("Request to pay INR 450 from merchant ABC. Approve to pay."), None);
        assert_eq!(parse_payment("Mandate created for Rs 199/month for Netflix."), None);
        assert_eq!(parse_payment("Autopay scheduled for Rs 499 on 15th."), None);
        assert_eq!(parse_payment("Payment of Rs 1,000 is pending."), None);
        assert_eq!(parse_payment("Transaction of Rs 500 initiated."), None);
        assert_eq!(parse_payment("Payment of Rs 800 in progress."), None);
        // EMI conversion promo — mimics a debit, but it is a marketing follow-up
        assert_eq!(parse_payment("Convert your txn of Rs 4,500 at CROMA on card XX1234 into easy EMIs."), None);
        assert_eq!(parse_payment("Convert your purchase of Rs 2,000 at Amazon into EMIs. Tap to know more."), None);
        // Failed / declined
        assert_eq!(parse_payment("Payment of Rs 500 to Uber failed due to bank server issue."), None);
        assert_eq!(parse_payment("Transaction of Rs 1,200 at Swiggy was declined due to insufficient funds."), None);
        // UPI Lite: auto top-ups are wallet funding, not expenses; daily Lite spends parse as normal debits
        assert_eq!(parse_payment("Auto top-up of INR 500 to UPI Lite wallet. Bal: INR 200"), None);
        let p = pp("Debited Rs 80 from UPI Lite balance for Chai Point");
        assert_eq!(p.amount, 80.0);
        assert!(!p.is_income);
    }

    #[test]
    fn captures_real_payments() {
        // Google Pay debit
        let p = pp("₹450 paid to Swiggy using UPI UPI Ref 123456789012");
        assert_eq!(p.amount, 450.0);
        assert_eq!(p.merchant, "Swiggy");
        assert_eq!(p.upi_ref.as_deref(), Some("123456789012"));
        assert!(!p.is_income);

        // PhonePe debit
        let p = pp("Rs 320.50 debited from a/c at Zomato. UTR 9876543210");
        assert_eq!(p.amount, 320.5);
        assert_eq!(p.merchant, "Zomato");
        assert_eq!(p.upi_ref.as_deref(), Some("9876543210"));

        // Money received → income
        let p = pp("₹5000 received from Akash. UPI Ref 123456789012");
        assert_eq!(p.amount, 5000.0);
        assert!(p.is_income);
        assert_eq!(p.upi_ref.as_deref(), Some("123456789012"));

        // "paid you" / "sent you" → income, not spend
        assert!(pp("Akash paid you ₹500 via UPI").is_income);
        assert!(pp("Priya sent you ₹250").is_income);

        // Bank debit message
        let p = pp("Rs. 2,500.00 debited from A/c XX1234 at Amazon on 09-Aug-26");
        assert_eq!(p.amount, 2500.0);
        assert!(!p.is_income);
        assert_eq!(p.merchant, "Amazon");

        // Unknown merchant falls back to Unknown
        let p = pp("₹100 debited. UTR 1111111111");
        assert_eq!(p.merchant, "Unknown");
        assert_eq!(p.upi_ref.as_deref(), Some("1111111111"));
    }

    #[test]
    fn format_variants() {
        // GPay money-sent bullet format
        let p = pp("Money sent · ₹200 · Swiggy · UPI Ref 987654321012");
        assert_eq!(p.amount, 200.0);
        assert_eq!(p.merchant, "Swiggy");
        assert_eq!(p.upi_ref.as_deref(), Some("987654321012"));

        // PhonePe payment to merchant with trans ID
        let p = pp("Payment to Swiggy of ₹350.00 was successful. Trans ID: T240823123456");
        assert_eq!(p.amount, 350.0);
        assert_eq!(p.merchant, "Swiggy");
        assert_eq!(p.upi_ref.as_deref(), Some("T240823123456"));

        // Bank narration UPI/DR format
        let p = pp("A/c *5678 debited for Rs. 1,450.00 on 23-08-2026. Info: UPI/DR/423523523523/AMAZON/Axis Bank");
        assert_eq!(p.amount, 1450.0);
        assert_eq!(p.merchant, "AMAZON");
        assert_eq!(p.upi_ref.as_deref(), Some("423523523523"));

        // CRED payment at merchant
        let p = pp("Paid ₹1,200 at Starbucks using CRED UPI. Ref 123456789012");
        assert_eq!(p.amount, 1200.0);
        assert_eq!(p.merchant, "Starbucks");
        assert_eq!(p.upi_ref.as_deref(), Some("123456789012"));

        // Cashback credited as income
        let p = pp("Cashback of ₹50 credited to your account. Ref 999988887777");
        assert_eq!(p.amount, 50.0);
        assert!(p.is_income);

        // VPA handle cleaning
        assert_eq!(merchant("Paid ₹150 to paytmqr281001@paytm using UPI. Ref 111122223333"), "Paytm Merchant");
        assert_eq!(merchant("Paid ₹500 to swiggy.orders@icici. Ref 222233334444"), "Swiggy");
        assert_eq!(merchant("Paid Rs. 85.00 to bharatpe9102912@icici via BHIM. Ref No: 910291029102"), "BharatPe Merchant");
        // Numeric (mobile-number) VPA handle → masked "UPI User" name
        assert_eq!(merchant("Paid ₹100 to 9876543210@upi. Ref 444455556666"), "UPI User (3210)");

        // Lakh Indian numbering format amount
        let p = pp("INR 1,25,000.00 debited for Rent to Landlord");
        assert_eq!(p.amount, 125000.0);
        assert_eq!(p.merchant, "Landlord");
    }

    #[test]
    fn bank_sms_formats() {
        // HDFC format with balance
        let p = pp("Dear Customer, INR 340.00 debited from A/C **1234 on 23-AUG-26 to ZOMATO UPI:623829102812. Bal: INR 12,400.00");
        assert_eq!(p.amount, 340.0);
        assert_eq!(p.merchant, "ZOMATO");
        assert!(!p.is_income);
        assert_eq!(p.balance, Some(12400.0));

        // SBI transfer format
        let p = pp("Your A/C ending 4321 debited by Rs 150.00 on 23Aug26 transfer to Chai Point Ref No 892019283019");
        assert_eq!(p.amount, 150.0);
        assert_eq!(p.merchant, "Chai Point");
        assert_eq!(p.upi_ref.as_deref(), Some("892019283019"));

        // Axis credit card spend
        let p = pp("Axis Bank: INR 750.00 spent on your Credit Card XX9900 at PVR CINEMAS on 23-Aug-26");
        assert_eq!(p.amount, 750.0);
        assert_eq!(p.merchant, "PVR CINEMAS");
        assert!(!p.is_income);

        // Refund credited from merchant
        let p = pp("INR 899.00 refunded to your A/c XX1234 from Amazon. UPI Ref: 102938475610");
        assert_eq!(p.amount, 899.0);
        assert!(p.is_income);
        assert_eq!(p.merchant, "Amazon");
        assert_eq!(p.upi_ref.as_deref(), Some("102938475610"));

        // P2P bank narration
        let p = pp("Your A/c debited for Rs 850. Info: UPI/P2P/123456789012/Rahul Sharma/HDFC");
        assert_eq!(p.amount, 850.0);
        assert_eq!(p.upi_ref.as_deref(), Some("123456789012"));
        assert_eq!(p.merchant, "Rahul Sharma");
        assert!(!p.is_income);
    }

    #[test]
    fn incoming_transfer_phrasings() {
        let p = pp("papa sent Rs 2400 to you");
        assert_eq!(p.amount, 2400.0);
        assert!(p.is_income);
        assert_eq!(p.merchant, "Papa");

        assert!(pp("friend paid 500 to you").is_income);

        let p = pp("Payment received Rs 500 from John Doe. UPI Ref 123456789012");
        assert_eq!(p.amount, 500.0);
        assert!(p.is_income);
        assert_eq!(p.merchant, "John Doe");
        assert_eq!(p.upi_ref.as_deref(), Some("123456789012"));
    }

    #[test]
    fn lookahead_terminates_at_timestamps() {
        let p = pp("Paid Rs.500 to Swiggy at 14:32 IST. UPI Ref 123456789012");
        assert_eq!(p.amount, 500.0);
        assert_eq!(p.merchant, "Swiggy");
        assert!(!p.is_income);

        let p = pp("Rs. 300 debited from Uber at 09:15. Ref 987654321012");
        assert_eq!(p.amount, 300.0);
        assert_eq!(p.merchant, "Uber");
        assert!(!p.is_income);
    }

    #[test]
    fn account_numbers_are_not_upi_refs() {
        let p = pp("Rs 500 debited from A/c 123456789012 at Starbucks");
        assert_eq!(p.amount, 500.0);
        assert_eq!(p.merchant, "Starbucks");
        assert_eq!(p.upi_ref, None);
        assert_eq!(p.account_mask.as_deref(), Some("123456789012"));
    }

    #[test]
    fn spend_sms_with_cashback_footnote_stays_expense() {
        let p = pp("Paid Rs 150 on Swiggy. Earn up to Rs 20 cashback on next order.");
        assert_eq!(p.amount, 150.0);
        assert_eq!(p.merchant, "Swiggy");
        assert!(!p.is_income);
    }

    #[test]
    fn payment_received_by_merchant_is_not_income() {
        let p = pp("Paid ₹450 to Swiggy. Payment received by merchant. Ref 112233445566");
        assert_eq!(p.amount, 450.0);
        assert!(!p.is_income);
    }

    #[test]
    fn balance_prefix_does_not_corrupt_transaction_amount() {
        let p = pp("Avail Bal: Rs 45,000. Your A/c debited for Rs 150 at Swiggy. UPI Ref 123456789012");
        assert_eq!(p.amount, 150.0);
        assert_eq!(p.merchant, "Swiggy");
        assert!(!p.is_income);
    }
}