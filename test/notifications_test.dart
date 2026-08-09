import 'package:flutter_test/flutter_test.dart';
import 'package:kharcha/data/notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

void main() {
  tzdata.initializeTimeZones();
  final kolkata = tz.getLocation('Asia/Kolkata');

  group('nextDailyAt', () {
    test('before 21:00 → today 21:00', () {
      final now = tz.TZDateTime(kolkata, 2026, 8, 9, 14, 30); // 2:30pm Sunday
      expect(nextDailyAt(now, hour: 21), tz.TZDateTime(kolkata, 2026, 8, 9, 21));
    });

    test('after 21:00 → tomorrow 21:00', () {
      final now = tz.TZDateTime(kolkata, 2026, 8, 9, 22, 5); // 10:05pm
      expect(nextDailyAt(now, hour: 21), tz.TZDateTime(kolkata, 2026, 8, 10, 21));
    });
  });

  group('nextSundayAt', () {
    test('non-Sunday → coming Sunday 21:00', () {
      final now = tz.TZDateTime(kolkata, 2026, 8, 10, 10); // Monday
      expect(nextSundayAt(now), tz.TZDateTime(kolkata, 2026, 8, 16, 21));
    });

    test('Sunday before 21:00 → today 21:00', () {
      final now = tz.TZDateTime(kolkata, 2026, 8, 9, 12); // Sunday noon
      expect(nextSundayAt(now), tz.TZDateTime(kolkata, 2026, 8, 9, 21));
    });

    test('Sunday after 21:00 → next Sunday 21:00 (no past-time throw)', () {
      final now = tz.TZDateTime(kolkata, 2026, 8, 9, 22); // Sunday 10pm
      final at = nextSundayAt(now);
      expect(at.isAfter(now), isTrue);
      expect(at.weekday, DateTime.sunday);
      expect(at.hour, 21);
      expect(at.day, 16); // 2026-08-16, a full week later
    });
  });

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
