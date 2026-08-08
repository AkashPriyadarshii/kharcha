import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kharcha/data/database.dart';
import 'package:kharcha/data/remote_transaction.dart';
import 'package:kharcha/data/transaction_repository.dart';

void main() {
  late AppDatabase db;
  late TransactionRepository repo;

  setUp(() {
    db = AppDatabase(executor: NativeDatabase.memory());
    repo = TransactionRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('localToRemoteJson', () {
    test('maps to snake_case Supabase payload with utc timestamps', () async {
      final t = await repo.insertManual(
        amount: 150,
        merchant: 'Swiggy',
        note: 'lunch',
        paymentMethod: 'upi',
        txnDate: DateTime(2026, 8, 6, 12, 0, 0),
      );
      final json = localToRemoteJson(t, 'user-1');

      expect(json['user_id'], 'user-1');
      expect(json['amount'], 150);
      expect(json['merchant'], 'Swiggy');
      expect(json['note'], 'lunch');
      expect(json['payment_method'], 'upi');
      expect(json['source'], 'manual');
      expect(json['is_income'], false);
      expect(json['upi_ref'], isNull);
      expect(json.containsKey('id'), isFalse);
      // Times are converted to UTC (the machine TZ makes the local→UTC shift
      // TZ-dependent, so assert against the same conversion).
      expect(json['txn_date'], t.txnDate.toUtc().toIso8601String());
      expect(json['updated_at'], t.updatedAt.toUtc().toIso8601String());
    });

    test('income row pushes is_income true', () async {
      final t = await repo.insertManual(
        amount: 5000,
        merchant: 'Acme Corp',
        paymentMethod: 'upi',
        txnDate: DateTime(2026, 8, 6),
        isIncome: true,
      );
      final json = localToRemoteJson(t, 'user-1');
      expect(json['is_income'], true);
    });
  });

  group('localWins (LWW)', () {
    test('local wins on tie', () {
      final t = DateTime(2026, 8, 7, 10);
      expect(localWins(t, t), isTrue);
    });

    test('local wins when newer', () {
      expect(
        localWins(DateTime(2026, 8, 7, 11), DateTime(2026, 8, 7, 10)),
        isTrue,
      );
    });

    test('remote wins when newer', () {
      expect(
        localWins(DateTime(2026, 8, 7, 10), DateTime(2026, 8, 7, 11)),
        isFalse,
      );
    });
  });

  group('applyRemote', () {
    RemoteTransaction remote({
      int id = 99,
      double amount = 100,
      String merchant = 'Zepto',
      String? upiRef,
      DateTime? updatedAt,
      bool isIncome = false,
    }) {
      return RemoteTransaction(
        id: id,
        amount: amount,
        merchant: merchant,
        txnDate: DateTime(2026, 8, 5),
        note: null,
        paymentMethod: 'upi',
        upiRef: upiRef,
        source: 'notification',
        isIncome: isIncome,
        updatedAt: updatedAt ?? DateTime(2026, 8, 7, 9),
      );
    }

    test('unknown remote row is inserted and synced clean', () async {
      await repo.applyRemote(remote());

      final rows = await db.select(db.transactions).get();
      expect(rows, hasLength(1));
      expect(rows.single.merchant, 'Zepto');
      expect(rows.single.remoteId, 99);
      expect(rows.single.dirty, isFalse);
    });

    test('remote income row keeps isIncome', () async {
      await repo.applyRemote(remote(merchant: 'Acme', isIncome: true));
      expect((await db.select(db.transactions).get()).single.isIncome, true);
    });

    test('remote newer overwrites local income flag', () async {
      final local = await repo.insertManual(
        amount: 100,
        merchant: 'Acme',
        paymentMethod: 'upi',
        txnDate: DateTime(2026, 8, 5),
        isIncome: true,
      );
      await repo.markSynced(local.id, 99);

      await repo.applyRemote(remote(
        merchant: 'Acme',
        isIncome: false,
        updatedAt: local.updatedAt.add(const Duration(minutes: 1)),
      ));

      final row = (await db.select(db.transactions).get()).single;
      expect(row.isIncome, false);
    });

    test('remote newer by id overwrites local and clears dirty', () async {
      // Simulate a previously-pushed row: local holds the remote id.
      final local = await repo.insertManual(
        amount: 50,
        merchant: 'Old name',
        paymentMethod: 'upi',
        txnDate: DateTime(2026, 8, 5),
      );
      await repo.markSynced(local.id, 99);

      await repo.applyRemote(remote(
        amount: 200,
        merchant: 'New name',
        updatedAt: local.updatedAt.add(const Duration(minutes: 1)),
      ));

      final row = (await db.select(db.transactions).get()).single;
      expect(row.merchant, 'New name');
      expect(row.amount, 200);
      expect(row.remoteId, 99);
      expect(row.dirty, isFalse);
      expect(row.id, local.id); // same local row, overwritten
    });

    test('local newer by id stays and stays dirty for next push', () async {
      final local = await repo.insertManual(
        amount: 50,
        merchant: 'Local',
        paymentMethod: 'upi',
        txnDate: DateTime(2026, 8, 5),
      );
      await repo.markSynced(local.id, 99);

      await repo.applyRemote(
        remote(updatedAt: local.updatedAt.subtract(const Duration(minutes: 1))),
      );

      final row = (await db.select(db.transactions).get()).single;
      expect(row.merchant, 'Local');
      expect(row.remoteId, 99); // claimed, so no dup on next pull
      expect(row.dirty, isTrue); // still pending push
      expect(row.id, local.id);
    });

    test('same upi_ref from remote merges instead of inserting a dup', () async {
      final local = await repo.insertCaptured(
        amount: 250,
        merchant: 'Swiggy',
        upiRef: 'REF123',
        txnDate: DateTime(2026, 8, 5),
      );

      // Remote copy of the same payment, slightly newer.
      await repo.applyRemote(remote(id: 77, amount: 250, merchant: 'Swiggy',
          upiRef: 'REF123',
          updatedAt: local!.updatedAt.add(const Duration(minutes: 1))));

      final rows = await db.select(db.transactions).get();
      expect(rows, hasLength(1));
      expect(rows.single.remoteId, 77);
      expect(rows.single.dirty, isFalse);
    });
  });
}
