import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  test('insertManual persists a valid row with manual source', () async {
    final row = await repo.insertManual(
      amount: 450,
      merchant: 'Zomato',
      paymentMethod: 'upi',
      txnDate: DateTime(2026, 8, 6),
    );

    expect(row.amount, 450);
    expect(row.merchant, 'Zomato');
    expect(row.source, 'manual');
    expect(row.paymentMethod, 'upi');
    expect(row.txnDate, DateTime(2026, 8, 6));
    // Zomato matches a seeded rule → auto-categorized (categorization has its
    // own test below; this one just records the row is not left null).
    expect(row.categoryId, isNotNull);

    final stored = await (db.select(db.transactions)).get();
    expect(stored, hasLength(1));
  });

  test('insertManual trims merchant and blank note stores null', () async {
    final row = await repo.insertManual(
      amount: 100,
      merchant: '  Rapido  ',
      note: '   ',
      paymentMethod: 'cash',
      txnDate: DateTime.now(),
    );

    expect(row.merchant, 'Rapido');
    expect(row.note, isNull);
  });

  test('insertManual rejects amount <= 0', () async {
    await expectLater(
      repo.insertManual(amount: 0, merchant: 'X', paymentMethod: 'upi', txnDate: DateTime.now()),
      throwsA(isA<TransactionValidationException>()),
    );
  });

  test('insertManual rejects empty merchant', () async {
    await expectLater(
      repo.insertManual(amount: 50, merchant: '  ', paymentMethod: 'upi', txnDate: DateTime.now()),
      throwsA(isA<TransactionValidationException>()),
    );
  });

  test('insertManual rejects unknown payment method', () async {
    await expectLater(
      repo.insertManual(amount: 50, merchant: 'X', paymentMethod: 'cheque', txnDate: DateTime.now()),
      throwsA(isA<TransactionValidationException>()),
    );
  });

  test('insertManual auto-categorizes known merchant from seeded rules', () async {
    // Seed includes 'zomato' → Food; fetch that category's id.
    final food = await (db.select(db.categories)..where((c) => c.name.equals('Food'))).getSingle();

    final row = await repo.insertManual(
      amount: 300,
      merchant: 'ZOMATO-UB',
      paymentMethod: 'upi',
      txnDate: DateTime.now(),
    );

    expect(row.categoryId, food.id);
  });

  test('insertManual leaves unknown merchant uncategorized', () async {
    final row = await repo.insertManual(
      amount: 40,
      merchant: 'Ravi Kirana Store',
      paymentMethod: 'cash',
      txnDate: DateTime.now(),
    );

    expect(row.categoryId, isNull);
  });

  test('explicit categoryId beats auto-categorize', () async {
    final travel = await (db.select(db.categories)..where((c) => c.name.equals('Travel'))).getSingle();

    final row = await repo.insertManual(
      amount: 200,
      merchant: 'Zomato',
      categoryId: travel.id,
      paymentMethod: 'upi',
      txnDate: DateTime.now(),
    );

    expect(row.categoryId, travel.id);
  });

  test('insertCaptured dedupes by upiRef', () async {
    final first = await repo.insertCaptured(
      amount: 250, merchant: 'Swiggy', upiRef: 'REF123', txnDate: DateTime.now());
    expect(first, isNotNull);

    final dup = await repo.insertCaptured(
      amount: 250, merchant: 'Swiggy', upiRef: 'REF123', txnDate: DateTime.now());
    expect(dup, isNull);

    expect(await db.select(db.transactions).get(), hasLength(1));
  });

  test('insertCaptured auto-categorizes from seeded rules', () async {
    final food = await (db.select(db.categories)..where((c) => c.name.equals('Food'))).getSingle();
    final row = await repo.insertCaptured(
      amount: 150, merchant: 'Zomato', upiRef: 'REF456', txnDate: DateTime.now());
    expect(row!.categoryId, food.id);
  });

  test('watchAll emits inserted rows newest-first', () async {
    await repo.insertManual(amount: 100, merchant: 'A', paymentMethod: 'upi', txnDate: DateTime(2026, 8, 1));
    await repo.insertManual(amount: 200, merchant: 'B', paymentMethod: 'upi', txnDate: DateTime(2026, 8, 2));

    final rows = await repo.watchAll().first;
    expect(rows.map((r) => r.merchant).toList(), ['B', 'A']);
  });

  testWidgets('monthSpendProvider recomputes after a new transaction', (tester) async {
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        transactionRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);

    // Watch like a widget does; collect the aggregate values over time.
    final values = <List<(Category, double)>>[];
    final sub = container.listen(monthSpendProvider, (_, next) {
      final v = next.value;
      if (v != null) values.add(v);
    });
    addTearDown(sub.close);
    await tester.pumpAndSettle();
    expect(values, [isEmpty]);

    await repo.insertManual(
      amount: 450, merchant: 'Zomato', paymentMethod: 'upi', txnDate: DateTime(2026, 8, 6));
    await tester.pumpAndSettle();

    // The stream-derived aggregate must have re-emitted with the new row.
    expect(values.last, hasLength(1));
    expect(values.last.single.$2, 450);
  });

  test('income categories are seeded', () async {
    final cats = await (db.select(db.categories)..where((c) => c.isIncome.equals(true))).get();
    expect(cats.map((c) => c.name), containsAll(['Salary', 'Bonus', 'Gift', 'Other income']));
  });

  test('insertManual income persists isIncome and skips auto-categorize', () async {
    final row = await repo.insertManual(
      amount: 50000,
      merchant: 'Acme Corp',
      paymentMethod: 'upi',
      txnDate: DateTime(2026, 8, 6),
      isIncome: true,
    );

    expect(row.isIncome, true);
    expect(row.categoryId, isNull); // income never matches expense rules
  });

  test('monthTotal excludes income but monthIncome counts it', () async {
    await repo.insertManual(amount: 100, merchant: 'A', paymentMethod: 'upi', txnDate: DateTime(2026, 8, 1));
    await repo.insertManual(
      amount: 1000, merchant: 'Acme', paymentMethod: 'upi', txnDate: DateTime(2026, 8, 2), isIncome: true);

    final month = DateTime(2026, 8);
    expect(await repo.monthTotal(month), 100);
    expect(await repo.monthIncome(month), 1000);
  });

  test('dayTotal excludes income but dayIncome counts it', () async {
    await repo.insertManual(amount: 50, merchant: 'A', paymentMethod: 'upi', txnDate: DateTime(2026, 8, 6));
    await repo.insertManual(
      amount: 200, merchant: 'Acme', paymentMethod: 'upi', txnDate: DateTime(2026, 8, 6), isIncome: true);

    final day = DateTime(2026, 8, 6);
    expect(await repo.dayTotal(day), 50);
    expect(await repo.dayIncome(day), 200);
  });

  test('imported income round-trips through insertImported', () async {
    final row = await repo.insertImported(
      amount: 500,
      merchant: 'Client Payment',
      paymentMethod: 'upi',
      txnDate: DateTime(2026, 8, 6),
      isIncome: true,
    );
    expect(row!.isIncome, true);
  });

  group('edit/delete', () {
    test('updateTransaction edits fields and marks dirty', () async {
      final t = await repo.insertManual(
        amount: 100,
        merchant: 'Swiggy',
        paymentMethod: 'upi',
        txnDate: DateTime(2026, 8, 6),
      );
      await repo.markSynced(t.id, 42); // simulate already pushed
      await repo.updateTransaction(
        id: t.id,
        amount: 120,
        merchant: 'Zomato',
        paymentMethod: 'upi',
        txnDate: DateTime(2026, 8, 7),
      );
      final rows = await repo.allTransactions();
      expect(rows.single.$1.amount, 120);
      expect(rows.single.$1.merchant, 'Zomato');
      expect(rows.single.$1.dirty, isTrue);
    });

    test('deleteTransaction on a synced row writes a tombstone', () async {
      final t = await repo.insertManual(
        amount: 100,
        merchant: 'Swiggy',
        paymentMethod: 'upi',
        txnDate: DateTime(2026, 8, 6),
      );
      await repo.markSynced(t.id, 42);
      await repo.deleteTransaction(t.id);

      expect(await repo.allTransactions(), isEmpty);
      expect(await repo.deletedRemoteIds(), [42]);
    });

    test('deleteTransaction on an unsynced row leaves no tombstone', () async {
      final t = await repo.insertManual(
        amount: 100,
        merchant: 'Swiggy',
        paymentMethod: 'upi',
        txnDate: DateTime(2026, 8, 6),
      );
      await repo.deleteTransaction(t.id);

      expect(await repo.allTransactions(), isEmpty);
      expect(await repo.deletedRemoteIds(), isEmpty);
    });

    test('clearDeletedRow removes the tombstone after remote delete', () async {
      final t = await repo.insertManual(
        amount: 100,
        merchant: 'Swiggy',
        paymentMethod: 'upi',
        txnDate: DateTime(2026, 8, 6),
      );
      await repo.markSynced(t.id, 42);
      await repo.deleteTransaction(t.id);
      expect(await repo.deletedRemoteIds(), [42]);

      await repo.clearDeletedRow(42);
      expect(await repo.deletedRemoteIds(), isEmpty);
    });
  });
}
