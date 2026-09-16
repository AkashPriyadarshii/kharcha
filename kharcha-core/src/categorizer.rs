//! Merchant string normalization + rule-based categorization.
//!
//! Rule-based only — no AI. Faithful port of `lib/core/categorizer.dart` with
//! two performance changes: `Rule` carries `RuleKind` instead of a stringly
//! typed `type`, and `Classifier` pre-compiles every pattern and sorts once at
//! construction (rules change rarely; transactions are frequent), so the
//! per-notification path is a single merchant normalization + N cheap
//! `is_match` calls.

use std::sync::LazyLock;

use regex::Regex;

static NON_ALNUM_RE: LazyLock<Regex> = LazyLock::new(|| Regex::new(r"[^a-z0-9]+").unwrap());

/// A categorization rule: keyword pattern → category.
#[derive(Clone, Debug, PartialEq, Eq, uniffi::Record)]
pub struct Rule {
    pub pattern: String,
    pub kind: RuleKind,
    pub category_id: i64,
}

/// `learned` rules (user corrections) beat `builtin` (seeded dictionary).
#[derive(Clone, Copy, Debug, PartialEq, Eq, uniffi::Enum)]
pub enum RuleKind {
    Builtin,
    Learned,
}

/// Lowercases and collapses non-alphanumeric runs to single spaces.
/// The same transform is applied to merchants and rule patterns before a
/// word-boundary substring match, which doubles as the fuzzy match:
/// "Zomato", "ZOMATO-UB", "zomato order" all hit pattern "zomato", but
/// "zomato" never matches inside "buzzomatic". Suffixes ("-UB", " PVT LTD")
/// need no strip list — the boundary match ignores them.
pub fn normalize_merchant(raw: &str) -> String {
    NON_ALNUM_RE
        .replace_all(&raw.to_lowercase(), " ")
        .trim()
        .to_string()
}

/// A rule paired with its pre-compiled match regex.
struct CompiledRule {
    rule: Rule,
    regex: Regex,
}

/// Pre-sorted, pre-compiled rule set.
///
/// Priority: learned rules beat builtin; within one kind, the longest pattern
/// first. So a user-learned "zomato → Shopping" overrides the builtin Food,
/// and "zomato ub" beats plain "zomato".
///
/// Rules change on user corrections — rebuild via [`Classifier::new`] then,
/// not on every transaction.
#[derive(uniffi::Object)]
pub struct Classifier {
    entries: Vec<CompiledRule>,
}

impl Classifier {
    pub fn new(rules: &[Rule]) -> Self {
        let mut order: Vec<usize> = (0..rules.len()).collect();
        order.sort_by(|&a, &b| {
            let kind_a = if rules[a].kind == RuleKind::Learned { 0 } else { 1 };
            let kind_b = if rules[b].kind == RuleKind::Learned { 0 } else { 1 };
            kind_a
                .cmp(&kind_b)
                .then(rules[b].pattern.len().cmp(&rules[a].pattern.len()))
        });

        let mut entries = Vec::with_capacity(order.len());
        for i in order {
            let pattern = normalize_merchant(&rules[i].pattern);
            if pattern.is_empty() {
                continue;
            }
            // patterns are [a-z0-9 ] after normalization — regex-safe, no escaping.
            entries.push(CompiledRule {
                rule: rules[i].clone(),
                regex: Regex::new(&format!(r"\b{pattern}\b")).unwrap(),
            });
        }
        Self { entries }
    }

    /// Returns the matching rule for a merchant, or `None`.
    pub fn categorize(&self, merchant: &str) -> Option<&Rule> {
        let normalized = normalize_merchant(merchant);
        if normalized.is_empty() {
            return None;
        }
        self.entries.iter().find_map(|e| {
            if e.regex.is_match(&normalized) {
                Some(&e.rule)
            } else {
                None
            }
        })
    }

    /// Categorizes a merchant into a category id (the field the app stores).
    pub fn category_of(&self, merchant: &str) -> Option<i64> {
        self.categorize(merchant).map(|r| r.category_id)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn rule(pattern: &str, kind: RuleKind, category_id: i64) -> Rule {
        Rule {
            pattern: pattern.to_string(),
            kind,
            category_id,
        }
    }

    #[test]
    fn normalize_lowercases_and_collapses_non_alnum() {
        assert_eq!(normalize_merchant("ZOMATO-UB"), "zomato ub");
        assert_eq!(normalize_merchant("  Swiggy   Instamart!! "), "swiggy instamart");
        assert_eq!(normalize_merchant("₹UPI-Pay"), "upi pay");
        assert_eq!(normalize_merchant(""), "");
    }

    #[test]
    fn variants_hit_and_unknown_misses() {
        let rules = vec![
            rule("zomato", RuleKind::Builtin, 1),
            rule("swiggy", RuleKind::Builtin, 1),
            rule("uber", RuleKind::Builtin, 2),
            rule("vi", RuleKind::Builtin, 3),
            rule("rent", RuleKind::Builtin, 4),
        ];
        let clf = Classifier::new(&rules);
        for m in ["Zomato", "ZOMATO-UB", "zomato order", " Swiggy "] {
            assert!(clf.categorize(m).is_some(), "{m}");
        }
        assert_eq!(clf.categorize("Ravi Kirana"), None);
        assert_eq!(clf.categorize("zzz"), None);
        assert_eq!(clf.categorize(""), None);
    }

    #[test]
    fn no_false_positives_inside_words() {
        let rules = vec![
            rule("vi", RuleKind::Builtin, 3),
            rule("rent", RuleKind::Builtin, 4),
        ];
        let clf = Classifier::new(&rules);
        assert_eq!(clf.categorize("service station"), None);
        assert_eq!(clf.categorize("parents gift"), None);
    }

    #[test]
    fn learned_beats_builtin_and_longer_beats_shorter() {
        let base = vec![
            rule("zomato", RuleKind::Builtin, 1),
            rule("uber", RuleKind::Builtin, 2),
        ];
        let mut with_learned = vec![rule("zomato", RuleKind::Learned, 9)];
        with_learned.extend(base.clone());
        assert_eq!(Classifier::new(&with_learned).category_of("zomato"), Some(9));

        let mut merged = vec![rule("zomato ub", RuleKind::Builtin, 7)];
        merged.extend(base);
        assert_eq!(Classifier::new(&merged).category_of("zomato ub"), Some(7));
    }
}