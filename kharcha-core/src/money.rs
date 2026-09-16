//! Money parsing for user input. Amounts are stored as f64 (SQLite REAL),
//! so every boundary parse rounds to 2 decimal places to kill float drift
//! (0.1 + 0.2 != 0.3). Returns `None` for garbage/negative input.
//!
//! Faithful port of `lib/core/money.dart` `parseAmount`.
//!
//! ponytail: true integer-paise storage (i64 + divide by 100) would be exact,
//! but touches every table + screen. Boundary rounding covers all real drift
//! sources for a tenth of the diff — revisit if accounting-grade precision
//! is ever required.

/// Parses an input string to a 2-dp-rounded amount.
pub fn parse_amount(text: &str) -> Option<f64> {
    let trimmed = text.trim();
    let v: f64 = trimmed.parse().ok()?;
    if v < 0.0 {
        return None;
    }
    Some((v * 100.0).round() / 100.0)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn rounds_to_2dp_killing_float_drift() {
        assert_eq!(parse_amount("0.1"), Some(0.1));
        assert_eq!(parse_amount("0.2"), Some(0.2));
        // Dart `.round()` is half-away-from-zero; IEEE math is identical here.
        assert_eq!(parse_amount("2.345"), Some(2.35));
        assert_eq!(parse_amount("1.999"), Some(2.0));
        let sum = parse_amount("0.1").unwrap() + parse_amount("0.2").unwrap();
        assert!((sum - 0.3).abs() < 1e-12, "0.1+0.2 drifted: {sum}");
    }

    #[test]
    fn accepts_whole_amounts_rejects_garbage() {
        assert_eq!(parse_amount("1200"), Some(1200.0));
        assert_eq!(parse_amount("0"), Some(0.0));
        assert_eq!(parse_amount(""), None);
        assert_eq!(parse_amount("   "), None);
        assert_eq!(parse_amount("abc"), None);
        assert_eq!(parse_amount("-5"), None);
        // Symbol is not expected here — screens strip it upstream.
        assert_eq!(parse_amount("  ₹1200 "), None);
    }

    #[test]
    fn round_trips_a_value_grid() {
        for s in ["0.01", "0.99", "54", "1234.44", "99999.99", "0.005"] {
            let v = parse_amount(s).unwrap();
            assert_eq!(parse_amount(&format!("{v}")).unwrap(), v, "{s} -> {v}");
        }
    }
}