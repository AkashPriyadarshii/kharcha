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
    let s = text?.trim();
    if s.is_empty() || s.starts_with('-') {
        return None;
    }
    // Reject NaN/Inf explicitly — no f64 parse.
    let lower = s.to_ascii_lowercase();
    if lower == "nan" || lower == "inf" || lower == "infinity" || lower == "+inf" || lower == "+infinity" {
        return None;
    }
    // Exact i64 paise parse: integer.fraction with rounding, no f64.
    // Keeps Dart parity: "2.345" -> 235 (round half away), "1.999" -> 200.
    let (int_part, frac_part) = match s.split_once('.') {
        Some((a, b)) => (a, Some(b)),
        None => (s, None),
    };
    if !int_part.chars().all(|c| c.is_ascii_digit()) {
        return None;
    }
    let int_val: i64 = if int_part.is_empty() {
        frac_part.as_ref()?;
        0
    } else {
        int_part.parse().ok()?
    };
    let (paise_frac, round_up) = match frac_part {
        None => (0, false),
        Some("") => (0, false),
        Some(f) if !f.chars().all(|c| c.is_ascii_digit()) => return None,
        Some(f) => {
            let p1 = f.chars().next().map(|c| (c as i64) - ('0' as i64)).unwrap_or(0);
            let p2 = f.chars().nth(1).map(|c| (c as i64) - ('0' as i64)).unwrap_or(0);
            let third = f.chars().nth(2).map(|c| (c as i64) - ('0' as i64));
            let r = third.is_some_and(|d| d >= 5);
            (p1 * 10 + p2, r)
        }
    };
    let base = int_val.checked_mul(100)?.checked_add(paise_frac)?;
    let paise = if round_up { base.checked_add(1)? } else { base };
    Some(paise)
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
