import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kharcha/data/database.dart';
import 'package:kharcha/data/transaction_repository.dart';
import 'package:kharcha/screens/tabs/budget_tab.dart';

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

  group('budgetAlert', () {
    test('under 50% is ok', () => expect(budgetAlert(0.4), BudgetAlert.ok));
    test('50% warns', () => expect(budgetAlert(0.5), BudgetAlert.warn50));
    test('80% warns', () => expect(budgetAlert(0.8), BudgetAlert.warn80));
    test('100% is over', () => expect(budgetAlert(1.0), BudgetAlert.over));
    test('over 100% is over', () => expect(budgetAlert(1.4), BudgetAlert.over));
  });

  group('upsertBudget', () {
    test('creates then updates, no duplicate rows', () async {
      final food = await (db.select(db.categories)..where((c) => c.name.equals('Food'))).getSingle();

      await repo.upsertBudget(categoryId: food.id, amount: 5000);
      await repo.upsertBudget(categoryId: food.id, amount: 8000);

      final rows = await db.select(db.budgets).get();
      expect(rows, hasLength(1));
      expect(rows.single.amount, 8000);
      expect(rows.single.period, 'monthly');
    });

    test('deleteBudget removes the row', () async {
      final food = await (db.select(db.categories)..where((c) => c.name.equals('Food'))).getSingle();
      await repo.upsertBudget(categoryId: food.id, amount: 5000);
      final budget = (await db.select(db.budgets).get()).single;

      await repo.deleteBudget(budget.id);

      expect(await db.select(db.budgets).get(), isEmpty);
    });
  });
}
