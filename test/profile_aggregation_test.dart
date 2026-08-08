import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kharcha/data/database.dart';
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

  test('paymentMethodTotals sums per method, largest spend first', () async {
    await repo.insertManual(amount: 100, merchant: 'A', paymentMethod: 'upi', txnDate: DateTime(2026, 8, 1));
    await repo.insertManual(amount: 50, merchant: 'B', paymentMethod: 'cash', txnDate: DateTime(2026, 8, 2));
    await repo.insertManual(amount: 250, merchant: 'C', paymentMethod: 'upi', txnDate: DateTime(2026, 8, 3));

    final totals = await repo.paymentMethodTotals();
    expect(totals, hasLength(2));
    expect(totals[0], ('upi', 350.0, 2));
    expect(totals[1], ('cash', 50.0, 1));
  });

  test('syncStatus counts synced vs pending (dirty)', () async {
    final row = await repo.insertManual(amount: 100, merchant: 'A', paymentMethod: 'upi', txnDate: DateTime(2026, 8, 1));
    expect(await repo.syncStatus(), (0, 1)); // manual insert is dirty → pending.

    await repo.markSynced(row.id, 999); // dirty:false → synced.
    expect(await repo.syncStatus(), (1, 0));
  });
}
