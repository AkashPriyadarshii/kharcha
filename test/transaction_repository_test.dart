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
    expect(row.categoryId, isNull);

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
}
