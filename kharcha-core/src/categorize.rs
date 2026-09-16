/// Merchant normalization + rule-based categorization. Rule-based only — no AI.
/// Port of `lib/core/categorizer.dart`.
///
/// Match is a word-boundary substring on normalized strings, which doubles as
/// the fuzzy match: "Zomato", "ZOMATO-UB", "zomato order" all hit "zomato",
/// but never inside "buzzomatic".
/// Minimal rule row (callers map their storage rows onto this).
#[derive(Debug, Clone, uniffi::Record)]
pub struct Rule {
    pub pattern: String,
    /// "learned" beats "builtin".
    pub rule_type: String,
    pub category_id: Option<i64>,
}

impl Rule {
    pub fn new(pattern: &str, rule_type: &str, category_id: i64) -> Self {
        Self { pattern: pattern.to_string(), rule_type: rule_type.to_string(), category_id: Some(category_id) }
    }
}

pub fn normalize_merchant(raw: &str) -> String {
    // Mirrors `toLowerCase().replaceAll([^a-z0-9]+, ' ').trim()`:
    // Unicode lowercase (same mapping as Dart), ASCII alnum kept, runs of
    // anything else collapse to one space, ends trimmed. Single pass.
    let mut out = String::with_capacity(raw.len());
    let mut prev_space = true;
    for c in raw.chars().flat_map(|c| c.to_lowercase()) {
        if c.is_ascii_alphanumeric() {
            out.push(c);
            prev_space = false;
        } else if !prev_space {
            out.push(' ');
            prev_space = true;
        }
    }
    if prev_space {
        out.pop();
    }
    out
}

/// Returns the matching rule for a merchant, or None.
/// Priority: learned beats builtin; within one type, longest pattern first.
/// Stable sort — ties keep caller order (a strengthening; Dart documents
/// no stability guarantee, but all real rule sets order identically).
/// ponytail: length is bytes, Dart `length` is UTF-16 units — identical for
/// the ASCII patterns this engine actually stores; revisit if non-ASCII rule
/// patterns ever exist.
pub fn categorize<'a>(merchant: &str, rules: &'a [Rule]) -> Option<&'a Rule> {
    let normalized = normalize_merchant(merchant);
    if normalized.is_empty() {
        return None;
    }
    let mut ordered: Vec<&'a Rule> = rules.iter().collect();
    ordered.sort_by(|a, b| {
        let ta = i32::from(a.rule_type != "learned");
        let tb = i32::from(b.rule_type != "learned");
        ta.cmp(&tb).then(b.pattern.len().cmp(&a.pattern.len()))
    });
    ordered.into_iter().find(|r| {
        let pattern = normalize_merchant(&r.pattern);
        !pattern.is_empty() && word_match(&normalized, &pattern)
    })
}

/// ASCII `\bneedle\b` on normalized text. Both sides are `[a-z0-9 ]` after
/// normalization, so a boundary is exactly start/end-or-space — no regex
/// engine needed (ponytail rung 3: stdlib over dep).
fn word_match(haystack: &str, needle: &str) -> bool {
    let h = haystack.as_bytes();
    haystack.match_indices(needle).any(|(i, _)| {
        (i == 0 || h[i - 1] == b' ') && (i + needle.len() == h.len() || h[i + needle.len()] == b' ')
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn normalizes() {
        assert_eq!(normalize_merchant("ZOMATO-UB"), "zomato ub");
        assert_eq!(normalize_merchant("  Swiggy   Instamart!! "), "swiggy instamart");
        assert_eq!(normalize_merchant("₹UPI-Pay"), "upi pay");
    }

    fn rules() -> Vec<Rule> {
        vec![
            Rule::new("zomato", "builtin", 1),
            Rule::new("swiggy", "builtin", 1),
            Rule::new("uber", "builtin", 2),
            Rule::new("vi", "builtin", 3),
            Rule::new("rent", "builtin", 4),
        ]
    }

    #[test]
    fn variants_hit_no_false_positives() {
        let r = rules();
        for m in ["Zomato", "ZOMATO-UB", "zomato order", " Swiggy "] {
            assert!(categorize(m, &r).is_some(), "{m}");
        }
        assert!(categorize("Ravi Kirana", &r).is_none());
        assert!(categorize("zzz", &r).is_none());
        assert!(categorize("service station", &r).is_none()); // 'vi' not inside
        assert!(categorize("parents gift", &r).is_none()); // 'rent' not inside
    }

    #[test]
    fn learned_overrides_longest_wins() {
        let r = rules();
        let mut learned = vec![Rule::new("zomato", "learned", 9)];
        learned.extend(r.clone());
        assert_eq!(categorize("zomato", &learned).unwrap().category_id, Some(9));
        let mut with_long = vec![Rule::new("zomato ub", "builtin", 7)];
        with_long.extend(r);
        assert_eq!(categorize("zomato ub", &with_long).unwrap().category_id, Some(7));
    }
}
