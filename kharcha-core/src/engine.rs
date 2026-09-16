//! Unified capture engine — the single entry point that replaces kharcha's
//! three divergent parsers (Dart generic + Kotlin generic + the bank fleet,
//! which `capture_inbox.dart` reconciles with an if/else).
//!
//! v0.1: sender-aware dispatch SHAPE with the generic parser as the only
//! backend. v1.x plugs bank backends ahead of it without changing this
//! signature (pennywise `BankParserFactory` order: specific senders first,
//! generic fallback last).

use crate::parser::{parse_upi_notification, ParsedPayment};

/// A parsed capture with provenance. Mirrors pennywise `ParsedTransaction`:
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
    /// identical ref too — except ref-less duplicates far apart in time,
    /// which merge (accepted, documented).
    pub content_hash: u64,
}

/// Hard input cap. Real SMS/notifications are <2 KB; anything past 16 KB is a
/// paste-attack or a corrupt read — regexing megabytes burns CPU for nothing.
/// (Premortem: FFI callers pass arbitrary strings; the core must not spin.)
pub const MAX_BODY_BYTES: usize = 16 * 1024;

/// Sender-aware parse. Today every sender routes to the generic backend.
pub fn parse(sms_body: &str, sender: &str, timestamp_ms: i64) -> Option<ParsedTransaction> {
    if sms_body.len() > MAX_BODY_BYTES {
        return None;
    }
    let payment = parse_upi_notification(sms_body)?;
    let sender_norm = sender.trim().to_uppercase();
    let content_hash = content_hash(&payment);
    Some(ParsedTransaction { payment, sender: sender_norm, timestamp_ms, content_hash })
}

/// Batch drain for SMS backlogs: one call, compiled-once regexes, order kept.
pub fn parse_batch(items: &[(&str, &str, i64)]) -> Vec<Option<ParsedTransaction>> {
    items.iter().map(|(body, sender, ts)| parse(body, sender, *ts)).collect()
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
    fn batch_keeps_order_and_nones() {
        let out = parse_batch(&[
            ("₹450 paid to Swiggy using UPI", "gpay", 1),
            ("hello there", "friend", 2),
        ]);
        assert_eq!(out.len(), 2);
        assert!(out[0].is_some());
        assert!(out[1].is_none());
    }
}
