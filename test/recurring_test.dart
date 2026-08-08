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

  test('nextDueAfter rolls forward by period', () {
    final monthly = RecurringTransaction(
      id: 1, merchant: 'Netflix', amount: 199, categoryId: null,
      period: 'monthly', nextDue: DateTime(2026, 8, 15), active: true,
    );
    expect(TransactionRepository.nextDueAfter(monthly, DateTime(2026, 8, 15)), DateTime(2026, 9, 15));
    // Paid late → rolls from the payment date, not the missed due date.
    expect(TransactionRepository.nextDueAfter(monthly, DateTime(2026, 8, 20)), DateTime(2026, 9, 20));

    final weekly = RecurringTransaction(
      id: 2, merchant: 'Zomato Gold', amount: 100, categoryId: null,
      period: 'weekly', nextDue: DateTime(2026, 8, 1), active: true,
    );
    expect(TransactionRepository.nextDueAfter(weekly, DateTime(2026, 8, 1)), DateTime(2026, 8, 8));
  });

  test('insertRecurring + watchRecurring emits', () async {
    await repo.insertRecurring(
      merchant: 'Netflix', amount: 199, period: 'monthly', nextDue: DateTime(2026, 8, 15));
    final all = await repo.watchRecurring().first;
    expect(all.single.merchant, 'Netflix');
    expect(all.single.active, isTrue);
  });

  test('payRecurring inserts a transaction and rolls next due forward', () async {
    final r = await repo.insertRecurring(
      merchant: 'Netflix', amount: 199, period: 'monthly', nextDue: DateTime(2026, 8, 1));
    await repo.payRecurring(r, on: DateTime(2026, 8, 1));

    final txn = await db.select(db.transactions).get();
    expect(txn.single.amount, 199);
    expect(txn.single.merchant, 'Netflix');

    final updated = (await repo.watchRecurring().first).single;
    expect(updated.nextDue, DateTime(2026, 9, 1));
  });

  test('setRecurringActive toggles active flag', () async {
    final r = await repo.insertRecurring(
      merchant: 'Netflix', amount: 199, period: 'monthly', nextDue: DateTime(2026, 8, 1));
    await repo.setRecurringActive(r.id, false);
    expect((await repo.watchRecurring().first).single.active, isFalse);
  });
}
