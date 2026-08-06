import '../data/database.dart';

/// Merchant string normalization + rule-based categorization.
///
/// Pure Dart (no DB) so it's unit-testable. Rule-based only — no AI.
final _nonAlnum = RegExp(r'[^a-z0-9]+');

/// Match is a word-boundary substring on normalized strings, which doubles as
/// the fuzzy match: "Zomato", "ZOMATO-UB", "zomato order" all hit pattern
/// "zomato", but "zomato" never matches inside "buzzomatic". Suffixes
/// ("-UB", " PVT LTD") need no strip list — the boundary match ignores them.
String normalizeMerchant(String raw) {
  return raw.toLowerCase().replaceAll(_nonAlnum, ' ').trim();
}

/// Returns the matching rule's [Rule.categoryId] for a merchant, or null.
///
/// Priority: learned rules beat builtin; within one type, the longest pattern
/// first. So a user-learned "zomato → Shopping" overrides the builtin Food.
int? categorize({required String merchant, required List<Rule> rules}) {
  final normalized = normalizeMerchant(merchant);
  if (normalized.isEmpty) return null;

  final ordered = [...rules]..sort((a, b) {
      final typeCmp = (a.type == 'learned' ? 0 : 1) - (b.type == 'learned' ? 0 : 1);
      if (typeCmp != 0) return typeCmp;
      return b.pattern.length - a.pattern.length;
    });

  for (final rule in ordered) {
    final pattern = normalizeMerchant(rule.pattern);
    if (pattern.isEmpty) continue;
    // patterns are [a-z0-9 ] after normalization — regex-safe, no escaping.
    if (RegExp('\\b$pattern\\b').hasMatch(normalized)) return rule.categoryId;
  }
  return null;
}
