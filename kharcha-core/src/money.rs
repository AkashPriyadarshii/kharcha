/// Money parsing. Amounts are i64 paise everywhere — no float storage, ever.
/// Port of `lib/core/money.dart` `parseAmount`, with its documented `ponytail:`
/// tradeoff resolved: a fresh crate has no migration cost, so boundary rounding
/// is upgraded to exact paise at the parse edge.
///
/// Dart parity: identical f64 parse + `(v * 100).round()` ops (IEEE754, so
/// bit-identical incl. `2.345 → 235`); negative → None, unparseable → None.
/// Deliberate deviation: Dart `double.tryParse` admits `NaN`/`Infinity`
/// (`parseAmount('NaN')` returns NaN); an integer API cannot represent those,
/// so they are rejected as None. No corpus row depends on them.
pub fn parse_amount_paise(text: Option<&str>) -> Option<i64> {
    let v: f64 = text?.trim().parse().ok()?;
    if !v.is_finite() || v < 0.0 {
        return None;
    }
    let paise = (v * 100.0).round();
    // Audit: `i64::MAX as f64` rounds UP to 2^63, so `>` lets exactly-2^63
    // through and `as i64` saturates silently. `>=` rejects it.
    if !paise.is_finite() || paise >= i64::MAX as f64 {
        return None;
    }
    Some(paise as i64)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn rounds_to_paise_killing_float_drift() {
        // Mirrors money_test.dart, in paise.
        assert_eq!(parse_amount_paise(Some("0.1")), Some(10));
        assert_eq!(parse_amount_paise(Some("0.2")), Some(20));
        assert_eq!(parse_amount_paise(Some("2.345")), Some(235));
        assert_eq!(parse_amount_paise(Some("1.999")), Some(200));
        assert_eq!(parse_amount_paise(Some("0.1")).unwrap() + parse_amount_paise(Some("0.2")).unwrap(), 30);
    }

    #[test]
    fn accepts_whole_and_padded_rejects_garbage() {
        assert_eq!(parse_amount_paise(Some("  ₹1200 ")), None); // symbol not expected
        assert_eq!(parse_amount_paise(Some("1200")), Some(120000));
        assert_eq!(parse_amount_paise(Some("0")), Some(0));
        assert_eq!(parse_amount_paise(Some("")), None);
        assert_eq!(parse_amount_paise(None), None);
        assert_eq!(parse_amount_paise(Some("abc")), None);
        assert_eq!(parse_amount_paise(Some("-5")), None);
    }
}
