import 'package:flutter_test/flutter_test.dart';
import 'package:kharcha/data/notifications.dart';

void main() {
  group('dailySummaryBody', () {
    test('zero total, no uncategorized', () {
      expect(
        dailySummaryBody(total: 0, uncategorized: 0),
        'Aaj ₹0 kharcha hue.',
      );
    });

    test('total with uncategorized nudge', () {
      expect(
        dailySummaryBody(total: 540.0, uncategorized: 3),
        'Aaj ₹540 kharcha hue. 3 transactions bina category ke. Add karo?',
      );
    });

    test('total, zero uncategorized — no nudge', () {
      expect(
        dailySummaryBody(total: 540.0, uncategorized: 0),
        'Aaj ₹540 kharcha hue.',
      );
    });
  });

  group('weeklySummaryBody', () {
    test('with top categories', () {
      expect(
        weeklySummaryBody(total: 3200.0, top: ['Food', 'Travel', 'Shopping']),
        'Is week ₹3,200 kharcha. Top: Food, Travel, Shopping.',
      );
    });

    test('no categorized spends — no top list', () {
      expect(
        weeklySummaryBody(total: 400.0, top: const []),
        'Is week ₹400 kharcha.',
      );
    });
  });
}
