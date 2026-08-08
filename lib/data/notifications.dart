import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'transaction_repository.dart';

final _currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

/// Formats like ₹540 / ₹540.5 — no trailing zeros.
String _fmt(double amount) {
  final s = _currency.format(amount);
  return s.endsWith('.00') ? s.substring(0, s.length - 3) : s;
}

/// 9PM daily + Sunday weekly summary pushes (Hinglish, value-only).
class Notifications {
  Notifications(this._plugin, this._repo);

  final FlutterLocalNotificationsPlugin _plugin;
  final TransactionRepository _repo;

  static const _channelId = 'kharcha_summaries';
  static const _dailyId = 901;
  static const _weeklyId = 902;

  /// Channel + permission + timezone once. Must run before any schedule.
  Future<void> init() async {
    tz.initializeTimeZones();
    // Best-effort device tz; stays UTC when the lookup fails (rare).
    try {
      tz.setLocalLocation(tz.getLocation((await FlutterTimezone.getLocalTimezone()).identifier));
    } catch (_) {}
    await _plugin.initialize(const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ));
    final android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(const AndroidNotificationChannel(
      _channelId,
      'Kharcha summaries',
      description: 'Daily and weekly spending summaries',
      importance: Importance.high,
    ));
    // Notification permission is requested contextually in onboarding, not at
    // startup — a dialog on the auth screen would be spammy.
  }

  /// (Re)schedules the daily 21:00 push with today's numbers so far. Called
  /// each app start — the pending push carries the freshest data we have.
  /// ponytail: data is as-of-last-open, not fire-time; a background fill needs
  /// a foreground service / headless task — add when accuracy at 9PM matters.
  Future<void> scheduleDaily() async {
    final now = DateTime.now();
    final total = await _repo.dayTotal(now);
    final uncat = await _repo.dayUncategorizedCount(now);
    await _plugin.zonedSchedule(
      _dailyId,
      'Aaj ka kharcha',
      dailySummaryBody(total: total, uncategorized: uncat),
      _nextAt(hour: 21),
      _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// (Re)schedules the Sunday 21:00 recap with the last 7 days' numbers.
  /// Same as-of-last-open caveat as [scheduleDaily].
  Future<void> scheduleWeekly() async {
    final now = DateTime.now();
    final total = await _repo.weekTotal(now);
    final top = (await _repo.topCategories(now)).map((t) => t.$1).toList();
    await _plugin.zonedSchedule(
      _weeklyId,
      'Hafta recap',
      weeklySummaryBody(total: total, top: top),
      _nextSunday(),
      _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Next occurrence of [hour]:00 — today if still ahead, else tomorrow.
  tz.TZDateTime _nextAt({required int hour}) {
    final now = tz.TZDateTime.now(tz.local);
    var at = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour);
    if (!at.isAfter(now)) {
      at = at.add(const Duration(days: 1));
    }
    return at;
  }

  /// Next Sunday 21:00.
  tz.TZDateTime _nextSunday() {
    final now = tz.TZDateTime.now(tz.local);
    final daysToSunday = (DateTime.sunday - now.weekday) % 7;
    final sunday = now.add(Duration(days: daysToSunday));
    return tz.TZDateTime(tz.local, sunday.year, sunday.month, sunday.day, 21);
  }

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      'Kharcha summaries',
      channelDescription: 'Daily and weekly spending summaries',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );
}

/// Daily summary body. Pure — unit-testable.
String dailySummaryBody({required double total, required int uncategorized}) {
  final parts = <String>[
    'Aaj ${_fmt(total)} kharcha hue.',
    if (uncategorized > 0) '$uncategorized transactions bina category ke. Add karo?',
  ];
  return parts.join(' ');
}

/// Weekly summary body. Pure — unit-testable.
String weeklySummaryBody({required double total, required List<String> top}) {
  final parts = <String>[
    'Is week ${_fmt(total)} kharcha.',
    if (top.isNotEmpty) 'Top: ${top.join(', ')}.',
  ];
  return parts.join(' ');
}
