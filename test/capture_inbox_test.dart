import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kharcha/data/capture_inbox.dart';
import 'package:kharcha/data/database.dart';
import 'package:kharcha/data/notifications.dart';
import 'package:kharcha/data/transaction_repository.dart';

class _FakeNotifications extends Notifications {
  _FakeNotifications(TransactionRepository repo)
      : super(FlutterLocalNotificationsPlugin(), repo);

  final capturedAlerts = <(double, String, bool, String?)>[];
  final budgetAlerts = <(String, double, double, int)>[];

  @override
  Future<void> showTransactionCaptured({
    required double amount,
    required String merchant,
    required bool isIncome,
    String? categoryName,
  }) async {
    capturedAlerts.add((amount, merchant, isIncome, categoryName));
  }

  @override
  Future<void> showBudgetThresholdAlert({
    required String categoryName,
    required double spent,
    required double budget,
    required int pct,
  }) async {
    budgetAlerts.add((categoryName, spent, budget, pct));
  }
}

void main() {
  late AppDatabase db;
  late TransactionRepository repo;
  late Directory tempDir;
  late File inboxFile;
  late _FakeNotifications fakeNotifications;

  setUp(() async {
    db = AppDatabase(executor: NativeDatabase.memory());
    repo = TransactionRepository(db);
    fakeNotifications = _FakeNotifications(repo);
    tempDir = Directory.systemTemp.createTempSync('kharcha_test_');
    inboxFile = File('${tempDir.path}/upi_inbox.jsonl');
  });

  tearDown(() async {
    await db.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('drainCaptureInbox returns 0 when file does not exist', () async {
    final added = await drainCaptureInbox(
      inbox: inboxFile,
      repo: repo,
      notifications: fakeNotifications,
    );
    expect(added, 0);
  });

  test('drainCaptureInbox parses and inserts valid payments, truncates file', () async {
    inboxFile.writeAsStringSync([
      jsonEncode({'package': 'com.google.android.apps.nbu.paisa.user', 'text': 'Paid ₹450 to Swiggy using UPI. Ref 10001', 'seenAt': '2026-08-23T10:00:00Z'}),
      jsonEncode({'package': 'com.phonepe.app', 'text': '₹200 received from Client. UPI Ref 10002', 'seenAt': '2026-08-23T10:05:00Z'}),
    ].join('\n'));

    final added = await drainCaptureInbox(
      inbox: inboxFile,
      repo: repo,
      notifications: fakeNotifications,
    );

    expect(added, 2);
    expect(inboxFile.readAsStringSync(), '');

    final all = await db.select(db.transactions).get();
    expect(all.length, 2);

    expect(all[0].amount, 450);
    expect(all[0].merchant, 'Swiggy');
    expect(all[0].isIncome, isFalse);
    expect(all[0].categoryId, isNotNull); // auto-categorized to Food

    expect(all[1].amount, 200);
    expect(all[1].merchant, 'Client');
    expect(all[1].isIncome, isTrue);

    expect(fakeNotifications.capturedAlerts.length, 2);
    expect(fakeNotifications.capturedAlerts[0], (450.0, 'Swiggy', false, 'Food'));
    expect(fakeNotifications.capturedAlerts[1], (200.0, 'Client', true, 'Other income'));
  });

  test('drainCaptureInbox dedupes payments by upiRef', () async {
    inboxFile.writeAsStringSync([
      jsonEncode({'package': 'com.phonepe.app', 'text': 'Paid ₹300 to Zomato. Ref 99991111', 'seenAt': '2026-08-23T10:00:00Z'}),
      jsonEncode({'package': 'com.phonepe.app', 'text': 'Paid ₹300 to Zomato. Ref 99991111', 'seenAt': '2026-08-23T10:01:00Z'}),
    ].join('\n'));

    final added = await drainCaptureInbox(
      inbox: inboxFile,
      repo: repo,
      notifications: fakeNotifications,
    );

    expect(added, 1);
    final all = await db.select(db.transactions).get();
    expect(all.length, 1);
  });

  test('drainCaptureInbox triggers budget alert when threshold >= 80%', () async {
    // Set budget for Food (category 1) = ₹1,000
    final foodCat = (await db.select(db.categories).get()).firstWhere((c) => c.name == 'Food');
    await repo.upsertBudget(categoryId: foodCat.id, amount: 1000);

    inboxFile.writeAsStringSync(
      jsonEncode({'package': 'com.phonepe.app', 'text': 'Paid ₹850 to Zomato. Ref 88880001', 'seenAt': '2026-08-23T10:00:00Z'}),
    );

    await drainCaptureInbox(
      inbox: inboxFile,
      repo: repo,
      notifications: fakeNotifications,
    );

    expect(fakeNotifications.budgetAlerts.length, 1);
    expect(fakeNotifications.budgetAlerts.first.$1, 'Food');
    expect(fakeNotifications.budgetAlerts.first.$2, 850.0);
    expect(fakeNotifications.budgetAlerts.first.$3, 1000.0);
    expect(fakeNotifications.budgetAlerts.first.$4, 85);
  });

  test('drainCaptureInbox writes unrecognized financial messages to unrecognized inbox', () async {
    inboxFile.writeAsStringSync([
      jsonEncode({'package': 'com.random.app', 'text': 'Offer: get Rs. 500 off on your next flight booking!', 'seenAt': '2026-08-23T10:00:00Z'}),
      jsonEncode({'package': 'com.chat.app', 'text': 'Good morning!', 'seenAt': '2026-08-23T10:01:00Z'}),
    ].join('\n'));

    final added = await drainCaptureInbox(
      inbox: inboxFile,
      repo: repo,
      notifications: fakeNotifications,
    );

    expect(added, 0);

    final unrecFile = unrecognizedInboxFile(tempDir);
    expect(unrecFile.existsSync(), isTrue);

    final lines = unrecFile.readAsLinesSync().where((l) => l.trim().isNotEmpty).toList();
    expect(lines.length, 1);
    expect(lines.first, contains('500 off'));
  });
}
