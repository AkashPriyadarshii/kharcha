//! Unified capture engine — the single entry point that replaces kharcha's
//! three divergent parsers (Dart generic + Kotlin generic + the bank fleet,
//! which `capture_inbox.dart` reconciles with an if/else).
//!
//! v0.1: sender-aware dispatch SHAPE with the generic parser as the only
//! backend. v1.x plugs bank backends ahead of it without changing this
//! signature (legacy Kotlin parser `BankParserFactory` order: specific senders first,
//! generic fallback last).

use crate::parser::{parse_upi_notification, ParsedPayment};

/// A parsed capture with provenance. Mirrors the legacy Kotlin parser's `ParsedTransaction`:
/// sender + timestamp travel WITH the payment, not in a sidecar inbox line.
#[derive(Debug, Clone, PartialEq, uniffi::Record)]
pub struct ParsedTransaction {
    pub payment: ParsedPayment,
    /// Sender ID, trimmed + uppercased (sender IDs are case-noisy).
    pub sender: String,
    /// Capture timestamp, epoch millis (carrier or device clock).
    pub timestamp_ms: i64,
    /// Deterministic content key over amount|direction|merchant|ref.
    /// FNV-1a64, stable across restarts (unlike SipHash) — safe as a dedupe
    /// key. Sender is DELIBERATELY excluded (audit): an SMS sender
    /// (`HDFCBK`) and a push package (`com.gpay`) for one payment would
    /// otherwise never hash equal, killing the cross-channel gate. Refs are
    /// unique per payment, so same-body collisions across senders need an
    /// identical ref too. The dedupe hash gate is window-bound (dedupe.rs),
    /// so ref-less duplicates far apart in time survive as real payments.
    pub content_hash: u64,
}

/// Hard input cap. Real SMS/notifications are <2 KB; anything past 16 KB is a
/// paste-attack or a corrupt read — regexing megabytes burns CPU for nothing.
/// (Premortem: FFI callers pass arbitrary strings; the core must not spin.)
/// Single authority lives in parser.rs (`MAX_INPUT_BYTES`) so direct parser
/// callers are guarded too; this is the re-export the FFI surface reads.
pub const MAX_BODY_BYTES: usize = crate::parser::MAX_INPUT_BYTES;

/// Resolves the issuing bank name from TRAI DLT 6-character sender ID headers
/// (e.g. "AD-HDFCBK-T" -> "HDFC", "VM-ICICIB" -> "ICICI", "BZ-SBIINB-T" -> "SBI").
pub fn resolve_bank_from_sender(sender: &str) -> Option<&'static str> {
    let clean = sender.trim().to_uppercase();
    // Strip telecom circle prefix if present (e.g. "AD-HDFCBK" -> "HDFCBK")
    let core = if let Some(idx) = clean.find('-') {
        let remainder = &clean[idx + 1..];
        remainder.split('-').next().unwrap_or(remainder)
    } else {
        &clean
    };

    match core {
        s if s.contains("HDFC") => Some("HDFC"),
        s if s.contains("SBI") => Some("SBI"),
        s if s.contains("ICICI") => Some("ICICI"),
        s if s.contains("AXIS") => Some("Axis"),
        s if s.contains("KOTAK") || s.contains("KBANK") => Some("Kotak"),
        s if s.contains("PNB") => Some("PNB"),
        s if s.contains("BOB") => Some("BOB"),
        s if s.contains("CANARA") || s.contains("CANBNK") || s.contains("CANRAB") => Some("Canara Bank"),
        s if s.contains("UNIONB") || s.contains("UBI") => Some("Union Bank"),
        s if s.contains("IDFC") || s.contains("FIRSTB") => Some("IDFC"),
        s if s.contains("INDUS") || s.contains("INDSIN") => Some("IndusInd"),
        s if s.contains("FED") => Some("Federal Bank"),
        s if s.contains("YESB") => Some("Yes Bank"),
        s if s.contains("INDBNK") || s.contains("INDIAB") => Some("Indian Bank"),
        s if s.contains("BOIND") || s.contains("BOITXN") => Some("Bank of India"),
        s if s.contains("CBI") || s.contains("CENTBK") => Some("Central Bank of India"),
        s if s.contains("RBL") || s.contains("RATNAK") => Some("RBL"),
        s if s.contains("ONECRD") || s.contains("FPLONE") => Some("OneCard"),
        s if s.contains("SCAPIA") => Some("Scapia"),
        _ => None,
    }
}

/// Sender-aware parse. Today every sender routes to the generic backend.
pub fn parse(sms_body: &str, sender: &str, timestamp_ms: i64) -> Option<ParsedTransaction> {
    if sms_body.len() > MAX_BODY_BYTES {
        return None;
    }
    let mut payment = parse_upi_notification(sms_body)?;
    let sender_norm = sender.trim().to_uppercase();

    // Enrich missing bank_name from DLT sender header if body was anonymous
    if payment.bank_name.is_none() {
        if let Some(bank) = resolve_bank_from_sender(&sender_norm) {
            payment.bank_name = Some(bank.to_string());
        }
    }

    let content_hash = content_hash(&payment);
    Some(ParsedTransaction { payment, sender: sender_norm, timestamp_ms, content_hash })
}

/// Max batch size. Per-item bytes are already capped by MAX_BODY_BYTES; this
/// caps the count so a hostile 100k-item drain can't balloon RAM/CPU.
/// Real backlogs are hundreds — chunk larger drains caller-side; items past
/// the cap come back None (documented, not silent: caller sees the tail).
pub const MAX_BATCH_ITEMS: usize = 10_000;

/// Batch drain for SMS backlogs: one call, compiled-once regexes, order kept.
pub fn parse_batch(items: &[(&str, &str, i64)]) -> Vec<Option<ParsedTransaction>> {
    items
        .iter()
        .take(MAX_BATCH_ITEMS)
        .map(|(body, sender, ts)| parse(body, sender, *ts))
        .chain(items.iter().skip(MAX_BATCH_ITEMS).map(|_| None))
        .collect()
}

fn content_hash(p: &ParsedPayment) -> u64 {
    // FNV-1a 64: deterministic, no dep (ponytail rung 3 — no md5 crate for one hash).
    // Merchant AND ref are lowercased: "Swiggy" (push) vs "SWIGGY" (SMS),
    // `T2408…` vs `t2408…`, is one payment (audit).
    let mut h: u64 = 0xcbf29ce484222325;
    for b in p
        .amount_paise
        .to_le_bytes()
        .into_iter()
        .chain([b'|', u8::from(p.is_income)])
        .chain([b'|'])
        .chain(p.merchant.to_lowercase().bytes())
        .chain([b'|'])
        .chain(p.upi_ref.as_deref().unwrap_or("").to_lowercase().bytes())
    {
        h ^= u64::from(b);
        h = h.wrapping_mul(0x100000001b3);
    }
    h
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn attaches_provenance_and_stable_hash() {
        let body = "₹450 paid to Swiggy using UPI UPI Ref 123456789012";
        let a = parse(body, "hdfcbk", 1000).unwrap();
        assert_eq!(a.sender, "HDFCBK");
        assert_eq!(a.timestamp_ms, 1000);
        assert_eq!(a.payment.merchant, "Swiggy");
        // Same payment, other channel's casing AND sender, later clock → same hash.
        let b = parse("INR 450.00 debited for SWIGGY. UPI Ref 123456789012", "HDFCBK", 999999).unwrap();
        assert_eq!(a.content_hash, b.content_hash);
        let sms_side = parse("INR 450.00 debited for SWIGGY. UPI Ref 123456789012", "VD-HDFCBK", 5).unwrap();
        let push_side = parse("₹450 paid to Swiggy using UPI UPI Ref 123456789012", "com.google.android.apps.nbu.paisa.user", 9000).unwrap();
        assert_eq!(sms_side.content_hash, push_side.content_hash);
        // Different amount → different hash.
        let c = parse(body.replace("450", "451").as_str(), "hdfcbk", 1000).unwrap();
        assert_ne!(a.content_hash, c.content_hash);
        // Spam → None, same as the bare parser.
        assert!(parse("OTP is 123456. Do not share.", "hdfcbk", 1000).is_none());
    }

    #[test]
    fn batch_caps_hostile_drains() {
        // Audit: unbounded batch × 16KB items = RAM/CPU DoS. Tail past
        // MAX_BATCH_ITEMS comes back None (documented), head still parses.
        let mut items = vec![("₹450 paid to Swiggy", "gpay", 1)];
        items.extend(vec![("hello", "x", 2); super::MAX_BATCH_ITEMS]);
        let out = parse_batch(&items);
        assert_eq!(out.len(), items.len());
        assert!(out[0].is_some());
        assert!(out.iter().skip(1).all(|o| o.is_none()));
    }

    #[test]
    fn sms_and_push_same_payment_dedupe_contract() {
        use crate::dedupe::{decide_capture, CaptureDecision, ExistingRow};
        let ts = 1_000_000_000_000i64;
        let row = |t: &crate::engine::ParsedTransaction, deleted: bool| ExistingRow {
            upi_ref: t.payment.upi_ref.clone(),
            amount_paise: t.payment.amount_paise,
            is_income: t.payment.is_income,
            txn_ms: t.timestamp_ms,
            is_deleted: deleted,
            content_hash: Some(t.content_hash),
        };
        // 1. Both channels carry the ref → one record (gate 1, case-insensitive).
        let push = parse(
            "Sent! ₹200.00 to Swiggy. UPI Ref 123456789012",
            "com.google.android.apps.nbu.paisa.user",
            ts,
        )
        .unwrap();
        let sms = parse(
            "INR 200.00 debited for SWIGGY via UPI. UPI Ref 123456789012",
            "VD-HDFCBK",
            ts + 45_000,
        )
        .unwrap();
        assert_eq!(
            decide_capture(
                sms.payment.upi_ref.as_deref(),
                sms.payment.amount_paise,
                sms.payment.is_income,
                sms.timestamp_ms,
                Some(sms.content_hash),
                &[row(&push, false)]
            ),
            CaptureDecision::Skip { backfill_ref: false }
        );
        // 2. Ref-less redelivery within the window → same content hash catches it.
        let push_noref = parse("Sent! ₹200.00 to Swiggy", "com.google.android.apps.nbu.paisa.user", ts).unwrap();
        let redelivery = parse("Sent! ₹200.00 to Swiggy", "com.google.android.apps.nbu.paisa.user", ts + 60_000).unwrap();
        assert_eq!(push_noref.content_hash, redelivery.content_hash);
        assert_eq!(
            decide_capture(
                None,
                redelivery.payment.amount_paise,
                redelivery.payment.is_income,
                redelivery.timestamp_ms,
                Some(redelivery.content_hash),
                &[row(&push_noref, false)]
            ),
            CaptureDecision::Skip { backfill_ref: false }
        );
        // 3. ponytail: ref-less push (GPay banner drops the ref) then ref'd SMS
        // 45s later → insert. The ref lives inside the hash, so hashes differ
        // and gate 3 refuses to merge two ref-less/ref'd same-amount events —
        // same protection that keeps two genuine back-to-back ₹200 taps from
        // collapsing. Trade-off is a rare double-count when the push omits the
        // ref; a false merge eats real spend. Fix when GPay ships refs in all
        // banners: hash on amount|direction|merchant only, ref moves to gate 1.
        let pw_noref = parse("Sent! ₹200.00 to Swiggy", "com.google.android.apps.nbu.paisa.user", ts).unwrap();
        let sms_ref = parse(
            "INR 200.00 debited for SWIGGY via UPI. UPI Ref 123456789013",
            "VD-HDFCBK",
            ts + 45_000,
        )
        .unwrap();
        assert_eq!(
            decide_capture(
                sms_ref.payment.upi_ref.as_deref(),
                sms_ref.payment.amount_paise,
                sms_ref.payment.is_income,
                sms_ref.timestamp_ms,
                Some(sms_ref.content_hash),
                &[row(&pw_noref, false)]
            ),
            CaptureDecision::Insert
        );
    }
}
