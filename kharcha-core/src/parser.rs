//! UPI/bank payment parsing from notification/SMS text. Rule-based, no AI.
//! Port of `lib/core/upi_parser.dart` (`parseUpiNotification`, `_cleanMerchant`,
//! `encodeInboxLine`). Covers UPI apps, bank apps, and messaging apps
//! (amount + payment keyword).
//!
//! Regex notes: every pattern is verbatim from the Dart source wrapped in
//! `(?i:...)`, with mechanical `\d`→`[0-9]` / `\s`→`[ \t\n\x0B\f\r]`
//! (see `non_transaction.rs` for why).

use std::sync::LazyLock;

use fancy_regex::{Captures, Regex};

use crate::money::parse_amount_paise;
use crate::non_transaction::{is_non_transaction, ASCII_CI};

/// Hard input cap — the parser's own guard, so DIRECT callers (not just
/// `engine::parse`) can't regex-paste megabytes. Real SMS/notifications are
/// <2 KB; anything past 16 KB is a paste-attack or a corrupt read. (Audit #4:
/// the cap previously lived only in engine.rs; `parse_upi_notification` is
/// `pub` and callable on its own.)
pub const MAX_INPUT_BYTES: usize = 16 * 1024;

/// A UPI/bank payment parsed from a notification's text.
#[derive(Debug, Clone, PartialEq, uniffi::Record)]
pub struct ParsedPayment {
    /// Integer paise (Dart stores a 2dp double; same value, exact).
    pub amount_paise: i64,
    pub merchant: String,
    /// True when money came IN (received/credited). False for spending.
    pub is_income: bool,
    pub upi_ref: Option<String>,
    /// True bank balance extracted from the message, paise.
    pub balance_paise: Option<i64>,
    pub account_mask: Option<String>,
    pub bank_name: Option<String>,
    pub needs_review: bool,
}

macro_rules! static_re {
    ($name:ident, $pat:expr) => {
        static $name: LazyLock<Regex> =
            LazyLock::new(|| Regex::new(&format!("{ASCII_CI}{})", $pat)).expect("static pattern"));
    };
}

// ponytail: one static per pattern (compiled once, shared). A single combined
// pass if profiling ever says parse is hot — it is per-message, it won't be.
static_re!(AMOUNT_RE, r"(?:₹|Rs\.?|INR)[ \t\n\x0B\f\r]*([0-9,]+(?:\.[0-9]{1,2})?)");
static_re!(
    AMOUNT_TRAILING_RE,
    r"([0-9,]+(?:\.[0-9]{1,2})?)[ \t\n\x0B\f\r]*(?:₹|Rs\.?|INR)"
);
static_re!(
    CONTEXTUAL_AMOUNT_RE,
    r"(?:debited (?:by|for)|credited (?:with|by)|spent|paid|amount of|txn of|transfer of)[ \t\n\x0B\f\r]+(?:INR|Rs\.?|₹)?[ \t\n\x0B\f\r]*([0-9,]+(?:\.[0-9]{1,2})?)"
);
static_re!(
    SPEND_RE,
    r"\b(?:debited|paid|transferred|sent|spent|payment|txn|transaction|purchase|withdrawn|charged|deducted)\b"
);
static_re!(
    RECEIVE_RE,
    // Premortem: ATM/failed-txn reversals ("Rs 5000 reversed to your account")
    // are real money-in that Dart drops (no revers* verb). Deliberate
    // improvement — Kotlin's refund regex already treats them as income.
    r"\b(?:received|credited|added to your|added in your|added to|refund|refunded|reversed|reversal|cashback|paid you|sent you|(?:sent|paid|transferred|given|credited).{0,20}to you|deposited|credited with|money received|inward)\b"
);
static_re!(
    BANK_NARRATION_RE,
    r"UPI\/(?:DR|CR|P2A|P2M|P2P|REV)\/([0-9]+)\/([A-Za-z0-9 &.\-_]+)"
);
static_re!(
    GPAY_MERCHANT_RE,
    r"·[ \t\n\x0B\f\r]*([A-Za-z0-9][A-Za-z0-9 &.\-]{1,60}?)(?=[ \t\n\x0B\f\r]*·|[ \t\n\x0B\f\r]+UPI|[ \t\n\x0B\f\r]+Ref|$)"
);
// Deliberate improvement over Dart (owner-approved, 2026-09-16 research):
// Dart blocks ALL digit-start merchants (`\d` in the lookahead + `\d+` in
// GENERIC_NAME_RE), so numeric payees (UPI Number / mobile@handle — the most
// common P2P format) land on Unknown. Here 8–10 digit names are kept;
// 1–7 digit fragments and 11+ digit account/refs stay blocked.
static_re!(
    RECIPIENT_MERCHANT_RE,
    concat!(
        r"(?:spent on .*? at|(?:paid|payment|transferred|sent)[ \t\n\x0B\f\r]+(?:(?:₹|rs\.?|inr)[ \t\n\x0B\f\r]*[0-9,.]+[ \t\n\x0B\f\r]+)?(?:to|at|on)|paid to|transferred to|sent to|payment to|sent .{0,12}to|done at|\bto\b|\bat\b)[ \t\n\x0B\f\r]+",
        r"(?!(?:you|rs\.?|inr|₹)\b)(?![0-9]{1,7}\b|[0-9]{11,}\b)([A-Za-z0-9][A-Za-z0-9 &.\-@]{1,60}?)(?=,|\.|$|:|[ \t\n\x0B\f\r]+(?:of[ \t\n\x0B\f\r]*(?:₹|Rs\.?|INR|[0-9])|upi|ref|utr|trans|txn|bal|balance|on[ \t\n\x0B\f\r]+[0-9]|on[ \t\n\x0B\f\r]+[A-Za-z]|at[ \t\n\x0B\f\r]+[0-9]|via|bank|a/c|by|from|using|credited|debited|successful|is[ \t\n\x0B\f\r]+successful|was[ \t\n\x0B\f\r]+successful))",
    )
);
static_re!(
    FALLBACK_MERCHANT_RE,
    concat!(
        r"(?:from|towards|for|debited (?:at|from))[ \t\n\x0B\f\r]+",
        r"(?!(?:you|rs\.?|inr|₹)\b)(?![0-9]{1,7}\b|[0-9]{11,}\b)([A-Za-z0-9][A-Za-z0-9 &.\-@]{1,60}?)(?=,|\.|$|:|[ \t\n\x0B\f\r]+(?:of[ \t\n\x0B\f\r]*(?:₹|Rs\.?|INR|[0-9])|upi|ref|utr|trans|txn|bal|balance|on[ \t\n\x0B\f\r]+[0-9]|on[ \t\n\x0B\f\r]+[A-Za-z]|at[ \t\n\x0B\f\r]+[0-9]|via|bank|a/c|by|from|using|credited|debited|successful|is[ \t\n\x0B\f\r]+successful|was[ \t\n\x0B\f\r]+successful))",
    )
);
static_re!(
    UPI_REF_RE,
    r"(?:upi[ \t\n\x0B\f\r]*ref(?:erence)?(?:[ \t\n\x0B\f\r]*no)?|\bupi\b|utr(?:[ \t\n\x0B\f\r]*no)?|ref(?:erence)?[ \t\n\x0B\f\r]*id|ref[ \t\n\x0B\f\r]*id|ref(?:[ \t\n\x0B\f\r]*no)?|trans(?:action)?[ \t\n\x0B\f\r]*id|txn[ \t\n\x0B\f\r]*id)[ \t\n\x0B\f\r]*[:#-]?[ \t\n\x0B\f\r]*([A-Za-z0-9]{8,})"
);
static_re!(UPI_REF_BARE_RE, r"\b([0-9]{12})\b");
static_re!(
    ACCOUNT_MASK_RE,
    r"(?:a/c|acct|account)(?:[ \t\n\x0B\f\r]*no\.?|[ \t\n\x0B\f\r]*number)?(?:[ \t\n\x0B\f\r]*ending[ \t\n\x0B\f\r]*(?:in|with))?[ \t\n\x0B\f\r]*(?:x|X|\*)*([0-9]{3,18})\b"
);
static_re!(
    BANK_NAME_RE,
    r"\b(SBI|HDFC|ICICI|Axis|Kotak|PNB|BOB|IDFC|IndusInd|Yes Bank|Canara|Union Bank|Indian Bank|State Bank of India|Bank of Baroda|Paytm Payments Bank|Airtel Payments Bank|Jio Payments Bank|Federal Bank|South Indian Bank)\b"
);
static_re!(
    BALANCE_PREFIX_RE,
    r"\b(?:bal|balance|avl[ \t\n\x0B\f\r]*bal|available[ \t\n\x0B\f\r]*(?:bal|balance)|limit|credit[ \t\n\x0B\f\r]*limit)[ \t\n\x0B\f\r:=-]*$"
);
static_re!(
    ACCOUNT_PREFIX_RE,
    r"(?:a/c|acct|account|card)(?:[ \t\n\x0B\f\r]*no\.?|[ \t\n\x0B\f\r]*number)?(?:[ \t\n\x0B\f\r]*ending[ \t\n\x0B\f\r]*(?:in|with))?[ \t\n\x0B\f\r]*(?:x|X|\*)*[ \t\n\x0B\f\r]*$"
);
static_re!(
    BAL_RE,
    // Audit: single-space `avl bal` is verbatim from Dart (both miss double-space) — parity, not a fix.
    r"(?:bal|balance|avl bal|available balance)[^0-9]*?(?:₹|Rs\.?|INR)?[ \t\n\x0B\f\r]*([0-9,]+(?:\.[0-9]{1,2})?)"
);
static_re!(TRAILING_KEYWORD_RE, r"[ \t\n\x0B\f\r]+(?:via|using|on|through|in|UPI|Ref|UTR|Bank|A/c|Account|Pv|Pvt|Ltd|Limited|is|was|successful|successfully)$");
static_re!(TRAILING_PUNCT_RE, r"[ \t\n\x0B\f\r.,:;/\-]+$");
static_re!(
    GENERIC_NAME_RE,
    // Audit + UPI-Number research: all-digit names are rejected EXCEPT 8–10
    // digits (UPI Number / mobile payee — the most common P2P format). Shorter
    // is a fragment, longer is an account/ref.
    r"^(?:your|your a/c|your account|account|bank|upi|self|vpa|cashback|(?:[0-9]{1,7}|[0-9]{11,})|rs\.?.*|inr.*)$"
);
static_re!(
    CREDIT_TO_YOU_RE,
    r"(?:sent|paid|transferred|given|credited).{0,20}to you"
);
static_re!(
    CREDITED_TO_ACCT_RE,
    r"(?:credited|deposited|added)[ \t\n\x0B\f\r]+(?:to|in|into)[ \t\n\x0B\f\r]+(?:your[ \t\n\x0B\f\r]+)?(?:a\/c|acct|account|wallet|balance)"
);
static_re!(
    PAYMENT_RECEIVED_FROM_RE,
    r"(?:payment|amount|money|\b)[ \t\n\x0B\f\r]*received[ \t\n\x0B\f\r]+(?:(?:(?:rs\.?|inr|₹)[ \t\n\x0B\f\r]*[0-9,.]+|[0-9,.]+)[ \t\n\x0B\f\r]+)?from\b"
);
static_re!(RECEIVED_BY_RE, r"received[ \t\n\x0B\f\r]+(?:by|for|towards|at)\b");
static_re!(
    INCOME_SENDER_RE,
    r"^([A-Za-z0-9][A-Za-z0-9 &.\-@]{1,60}?)[ \t\n\x0B\f\r]+(?:sent|paid|transferred|given|credited)"
);

fn group(caps: &Captures<'_>, i: usize) -> Option<String> {
    caps.get(i).map(|m| m.as_str().to_string())
}

/// Engine hiccups fail closed to None (not-a-payment); static patterns are
/// covered by the parity suite, so a live Err means pathological input.
fn is_match(re: &Regex, text: &str) -> bool {
    re.is_match(text).unwrap_or(false)
}
fn captures<'a>(re: &Regex, text: &'a str) -> Option<Captures<'a>> {
    re.captures(text).unwrap_or(None)
}
fn find_all<'a>(re: &Regex, text: &'a str) -> Vec<fancy_regex::Match<'a>> {
    re.find_iter(text).filter_map(|r| r.ok()).collect()
}
fn replace_all(re: &Regex, text: &str, rep: &str) -> String {
    re.replace_all(text, rep).into_owned()
}

/// Byte-slicing with a total guard. Match offsets into multibyte text can
/// land on non-char-boundaries (Unicode `\b` handling) — `s[..i]` would
/// panic across FFI. Fail-open to "" (prefix checks then simply don't match).
fn prefix_of(s: &str, end: usize) -> &str {
    s.get(..end).unwrap_or("")
}
fn span_of(s: &str, from: usize, to: usize) -> &str {
    s.get(from..to).unwrap_or("")
}

fn capitalize_first(lower: &str) -> String {
    let mut chars = lower.chars();
    match chars.next() {
        None => String::new(),
        Some(c) => c.to_uppercase().collect::<String>() + chars.as_str(),
    }
}

fn clean_merchant(raw: &str) -> String {
    let mut name = raw.trim().to_string();

    // 1. VPA handles, e.g. name@bank.
    // (Dart uses `^paytmqr`-style regexes; `starts_with` on the lowered user
    // is the same match with no engine — ponytail rung 3.)
    if name.contains('@') {
        let vpa_user = name.split('@').next().unwrap_or("").trim().to_string();
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
            let raw_handle = vpa_user.split(['.', '_', '-']).next().unwrap_or("");
            let cleaned = raw_handle.trim_end_matches(|c: char| c.is_ascii_digit());
            // Audit: Dart `length` is UTF-16 units, Rust `len()` is bytes —
            // non-ASCII VPAs took the wrong branch. Match Dart exactly.
            if cleaned.encode_utf16().count() >= 3 {
                name = capitalize_first(&cleaned.to_lowercase());
            } else {
                name = vpa_user;
            }
        }
    }

    // 2. Strip trailing keywords often captured in loose boundary matches.
    name = replace_all(&TRAILING_KEYWORD_RE, &name, "");
    // Strip trailing punctuation.
    name = replace_all(&TRAILING_PUNCT_RE, &name, "").trim().to_string();
    // Filter generic invalid names.
    if is_match(&GENERIC_NAME_RE, &name) {
        return "Unknown".to_string();
    }
    if !name.is_empty() && name == name.to_lowercase() {
        name = capitalize_first(&name);
    }
    if name.is_empty() {
        "Unknown".to_string()
    } else {
        name
    }
}

/// Parses `text` into a payment, or None if it isn't a payment notification
/// (spam, no amount, or no payment verb — e.g. a casual "send me ₹200" chat).
pub fn parse_upi_notification(text: &str) -> Option<ParsedPayment> {
    if text.len() > MAX_INPUT_BYTES {
        return None;
    }
    let clean = text.trim();
    if clean.is_empty() {
        return None;
    }

    // 0. Explicit rejection of non-transaction messages.
    if is_non_transaction(clean) {
        return None;
    }

    // 1. Amount extraction.
    // First non-balance-prefixed amount wins; if every amount looks like a
    // balance ("Avail Bal: Rs 45,000. ... Rs 150"), fall back to the first —
    // same as Dart's `??= allAmountMatches.firstOrNull`.
    let mut used_contextual_amount = false;
    let group1 = |re: &Regex, text: &str| captures(re, text).and_then(|c| group(&c, 1));

    let first_group_in_span = |re: &Regex, span: (usize, usize)| {
        captures(re, span_of(clean, span.0, span.1)).and_then(|c| group(&c, 1))
    };
    let mut raw: Option<String> = None;
    for m in find_all(&AMOUNT_RE, clean) {
        if !is_match(&BALANCE_PREFIX_RE, prefix_of(clean, m.start())) {
            raw = first_group_in_span(&AMOUNT_RE, (m.start(), m.end()));
            break;
        }
    }
    if raw.is_none() {
        raw = group1(&AMOUNT_RE, clean);
    }
    if raw.as_deref().is_none_or(|s: &str| s.is_empty()) {
        for m in find_all(&AMOUNT_TRAILING_RE, clean) {
            if !is_match(&BALANCE_PREFIX_RE, prefix_of(clean, m.start())) {
                raw = first_group_in_span(&AMOUNT_TRAILING_RE, (m.start(), m.end()));
                break;
            }
        }
        if raw.is_none() {
            raw = group1(&AMOUNT_TRAILING_RE, clean);
        }
    }
    if raw.as_deref().is_none_or(|s: &str| s.is_empty()) {
        raw = group1(&CONTEXTUAL_AMOUNT_RE, clean);
        if raw.as_deref().is_some_and(|s: &str| !s.is_empty()) {
            used_contextual_amount = true;
        }
    }
    let raw = raw.filter(|s| !s.is_empty())?;
    let amount_paise = parse_amount_paise(Some(&raw.replace(',', "")))?;
    if amount_paise == 0 {
        return None;
    }

    // 2. Transaction direction (income vs spend).
    let lower = clean.to_lowercase();
    let has_receive = is_match(&RECEIVE_RE, clean);
    let has_spend = is_match(&SPEND_RE, clean);

    // Neither verb → casual chat or unrelated notification.
    if !has_receive && !has_spend {
        return None;
    }

    // Disambiguation: "debited" / "paid to" / "spent" takes priority over
    // cashback/refund mentions unless explicitly incoming.
    let is_income = has_receive
        && (!has_spend
            || lower.contains("paid you")
            || lower.contains("sent you")
            || is_match(&CREDIT_TO_YOU_RE, clean)
            || is_match(&CREDITED_TO_ACCT_RE, clean)
            || lower.contains("credited with")
            || lower.contains("refund")
            || is_match(&PAYMENT_RECEIVED_FROM_RE, clean)
            || (lower.contains("received")
                && !is_match(&RECEIVED_BY_RE, clean)
                && !lower.contains("debited")
                && !lower.contains("spent")
                && !lower.contains("paid to")));

    // 3. Merchant extraction.
    let mut merchant: Option<String> = None;
    let mut upi_ref: Option<String> = None;

    // Bank narration first: "UPI/DR/123456789012/SWIGGY".
    if let Some(caps) = captures(&BANK_NARRATION_RE, clean) {
        upi_ref = group(&caps, 1);
        if let Some(bm) = group(&caps, 2) {
            if !bm.is_empty() {
                merchant = Some(clean_merchant(&bm));
            }
        }
    }

    if merchant.as_deref().is_none_or(|m: &str| m == "Unknown") {
        if let Some(cand) = group1(&GPAY_MERCHANT_RE, clean).map(|g| clean_merchant(&g)) {
            if cand != "Unknown" {
                merchant = Some(cand);
            }
        }
    }

    if merchant.as_deref().is_none_or(|m: &str| m == "Unknown") {
        if let Some(cand) = group1(&RECIPIENT_MERCHANT_RE, clean).map(|g| clean_merchant(&g)) {
            if cand != "Unknown" {
                merchant = Some(cand);
            }
        }
    }

    let mut used_fallback_merchant = false;
    if merchant.as_deref().is_none_or(|m: &str| m == "Unknown") {
        if let Some(cand) = group1(&FALLBACK_MERCHANT_RE, clean).map(|g| clean_merchant(&g)) {
            if cand != "Unknown" {
                merchant = Some(cand);
                used_fallback_merchant = true;
            }
        }
    }

    if merchant.as_deref().is_none_or(|m: &str| m == "Unknown") && is_income {
        if let Some(sender) = group1(&INCOME_SENDER_RE, clean) {
            let cand = clean_merchant(&sender);
            if cand.to_lowercase() != "you" && cand.to_lowercase() != "i" {
                merchant = Some(cand);
            }
        }
    }
    let merchant = merchant.unwrap_or_else(|| "Unknown".to_string());

    // 4. UPI Ref / UTR extraction.
    if upi_ref.is_none() {
        upi_ref = group1(&UPI_REF_RE, clean);
    }
    if upi_ref.is_none() && (has_spend || has_receive) {
        for m in find_all(&UPI_REF_BARE_RE, clean) {
            let prefix = prefix_of(clean, m.start());
            // Exclude 12-digit numbers preceded by account/card identifiers.
            if is_match(&ACCOUNT_PREFIX_RE, prefix) {
                continue;
            }
            upi_ref = Some(m.as_str().to_string());
            break;
        }
    }

    // 5. Balance extraction (e.g. "Avail Bal: Rs 10000").
    let balance_paise = group1(&BAL_RE, clean)
        .filter(|s| !s.is_empty())
        .and_then(|raw_bal| parse_amount_paise(Some(&raw_bal.replace(',', ""))));

    // 6. Account mask and bank name.
    let account_mask = group1(&ACCOUNT_MASK_RE, clean);
    let bank_name = group1(&BANK_NAME_RE, clean);

    Some(ParsedPayment {
        amount_paise,
        merchant,
        is_income,
        upi_ref,
        balance_paise,
        account_mask,
        bank_name,
        needs_review: used_contextual_amount || used_fallback_merchant,
    })
}

/// Encodes a raw capture line for the inbox JSONL file.
pub fn encode_inbox_line(package: &str, text: &str, seen_at: &str) -> String {
    format!(
        "{{\"package\":\"{}\",\"text\":\"{}\",\"seenAt\":\"{}\"}}",
        esc(package),
        esc(text),
        esc(seen_at)
    )
}

fn esc(s: &str) -> String {
    let mut o = String::with_capacity(s.len());
    for c in s.chars() {
        match c {
            '"' => o.push_str("\\\""),
            '\\' => o.push_str("\\\\"),
            '\n' => o.push_str("\\n"),
            '\r' => o.push_str("\\r"),
            '\t' => o.push_str("\\t"),
            '\u{08}' => o.push_str("\\b"),
            '\u{0C}' => o.push_str("\\f"),
            c if (c as u32) < 0x20 => o.push_str(&format!("\\u{:04x}", c as u32)),
            c => o.push(c),
        }
    }
    o
}




