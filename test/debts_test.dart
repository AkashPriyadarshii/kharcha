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

  test('insert and list debts', () async {
    await repo.insertDebt(name: 'Ravi', amount: 500, isLent: true);
    await repo.insertDebt(name: 'Priya', amount: 200, isLent: false, note: 'dinner');
    final debts = await repo.watchDebts().first;
    expect(debts, hasLength(2));
    expect(debts.first.name, 'Ravi');
    expect(debts.first.isLent, isTrue);
    expect(debts.first.note, isNull);
    expect(debts[1].isLent, isFalse);
    expect(debts[1].note, 'dinner');
  });

  test('mark settled toggles', () async {
    await repo.insertDebt(name: 'Ravi', amount: 500, isLent: true);
    final id = (await repo.watchDebts().first).single.id;
    await repo.setDebtSettled(id, true);
    expect((await repo.watchDebts().first).single.settled, isTrue);
    await repo.setDebtSettled(id, false);
    expect((await repo.watchDebts().first).single.settled, isFalse);
  });

  test('delete debt removes it', () async {
    await repo.insertDebt(name: 'Ravi', amount: 500, isLent: true);
    final id = (await repo.watchDebts().first).single.id;
    await repo.deleteDebt(id);
    expect(await repo.watchDebts().first, isEmpty);
  });
}
