import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kharcha/data/database.dart';
import 'package:kharcha/data/transaction_repository.dart';

void main() {
  late AppDatabase db;
  late TransactionRepository repo;

  setUp(() async {
    db = AppDatabase(executor: NativeDatabase.memory());
    repo = TransactionRepository(db);
  });

  tearDown(() => db.close());

  test('insertCategory appends after builtins with custom flag', () async {
    final id = await repo.insertCategory(name: 'Coffee', emoji: '☕', color: '#543310');
    final row = await (db.select(db.categories)..where((c) => c.id.equals(id))).getSingle();
    expect(row.id, id);
    expect(row.isCustom, isTrue);
    expect(row.sortOrder, greaterThan(0));
  });

  test('updateCategory edits name/emoji/color', () async {
    final id = await repo.insertCategory(name: 'Coffee', emoji: '☕', color: '#543310');
    await repo.updateCategory(id, name: 'Chai', emoji: '🫖', color: '#123456');
    final row = await (db.select(db.categories)..where((c) => c.id.equals(id))).getSingle();
    expect(row.name, 'Chai');
    expect(row.emoji, '🫖');
    expect(row.color, '#123456');
  });

  test('deleteCategory detaches transactions', () async {
    final id = await repo.insertCategory(name: 'Coffee', emoji: '☕', color: '#543310');
    await repo.insertManual(
      amount: 120,
      merchant: 'Cafe',
      paymentMethod: 'upi',
      txnDate: DateTime.now(),
      categoryId: id,
    );
    await repo.deleteCategory(id);

    final deleted = await (db.select(db.categories)..where((c) => c.id.equals(id))).getSingleOrNull();
    final txns = await db.select(db.transactions).get();
    expect(deleted, isNull);
    expect(txns.single.categoryId, isNull);
  });

  test('categoryIdByName is case-insensitive', () async {
    final id = await repo.insertCategory(name: 'Coffee', emoji: '☕', color: '#543310');
    expect(await repo.categoryIdByName('coffee'), id);
    expect(await repo.categoryIdByName('  COFFEE  '), id);
    expect(await repo.categoryIdByName('Tea'), isNull);
  });
}
