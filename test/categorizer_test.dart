import 'package:flutter_test/flutter_test.dart';
import 'package:kharcha/core/categorizer.dart';
import 'package:kharcha/data/database.dart';

/// Builds a fake Rule (id/type/categoryId/pattern) without a DB.
Rule rule(String pattern, String type, [int categoryId = 1]) {
  return Rule(
    id: 0,
    pattern: pattern,
    type: type,
    categoryId: categoryId,
  );
}

void main() {
  group('normalizeMerchant', () {
    test('lowercases and collapses non-alnum', () {
      expect(normalizeMerchant('ZOMATO-UB'), 'zomato ub');
      expect(normalizeMerchant('  Swiggy   Instamart!! '), 'swiggy instamart');
      expect(normalizeMerchant('₹UPI-Pay'), 'upi pay');
    });
  });

  group('categorize', () {
    final rules = [
      rule('zomato', 'builtin', 1),
      rule('swiggy', 'builtin', 1),
      rule('uber', 'builtin', 2),
      rule('vi', 'builtin', 3),
      rule('rent', 'builtin', 4),
    ];

    test('Zomato variants → Food', () {
      for (final m in ['Zomato', 'ZOMATO-UB', 'zomato order', ' Swiggy ']) {
        expect(categorize(merchant: m, rules: rules), isNotNull, reason: m);
      }
    });

    test('unknown merchant → null', () {
      expect(categorize(merchant: 'Ravi Kirana', rules: rules), isNull);
      expect(categorize(merchant: 'zzz', rules: rules), isNull);
    });

    test('no false positives inside words', () {
      // 'vi' must not match inside 'service'; 'rent' not in 'parents'.
      expect(categorize(merchant: 'service station', rules: rules), isNull);
      expect(categorize(merchant: 'parents gift', rules: rules), isNull);
    });

    test('learned rule overrides builtin', () {
      final learned = [rule('zomato', 'learned', 9), ...rules];
      expect(categorize(merchant: 'zomato', rules: learned)?.categoryId, 9);
    });

    test('longer pattern beats shorter within same type', () {
      final withLong = [rule('zomato ub', 'builtin', 7), ...rules];
      expect(categorize(merchant: 'zomato ub', rules: withLong)?.categoryId, 7);
    });
  });
}
