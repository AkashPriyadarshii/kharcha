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

  test('monthlyTrend covers last N months oldest-first, missing months as 0', () async {
    await repo.insertManual(amount: 100, merchant: 'A', paymentMethod: 'upi', txnDate: DateTime(2026, 8, 5));
    await repo.insertManual(amount: 250, merchant: 'B', paymentMethod: 'upi', txnDate: DateTime(2026, 7, 20));
    await repo.insertManual(amount: 50, merchant: 'C', paymentMethod: 'upi', txnDate: DateTime(2026, 8, 6));

    final trend = await repo.monthlyTrend(DateTime(2026, 8, 1), months: 3);
    expect(trend, hasLength(3));
    expect(trend.map((t) => t.$1).toList(), ['Jun 26', 'Jul 26', 'Aug 26']);
    expect(trend.map((t) => t.$2).toList(), [0, 250, 150]);
  });

  test('merchantRanking sums amounts and counts, largest spend first', () async {
    await repo.insertManual(amount: 300, merchant: 'Zomato', paymentMethod: 'upi', txnDate: DateTime(2026, 8, 1));
    await repo.insertManual(amount: 100, merchant: 'Zomato', paymentMethod: 'upi', txnDate: DateTime(2026, 8, 2));
    await repo.insertManual(amount: 250, merchant: 'Swiggy', paymentMethod: 'upi', txnDate: DateTime(2026, 8, 3));

    final ranking = await repo.merchantRanking(n: 10);
    expect(ranking, hasLength(2));
    expect(ranking[0], ('Zomato', 400.0, 2));
    expect(ranking[1], ('Swiggy', 250.0, 1));
  });

  test('monthSpendByCategory includes both categorized and uncategorized expenses', () async {
    final foodCat = await (db.select(db.categories)..where((c) => c.name.equals('Food'))).getSingle();
    await repo.insertManual(amount: 500, merchant: 'Restaurant', categoryId: foodCat.id, paymentMethod: 'upi', txnDate: DateTime(2026, 8, 1));
    await repo.insertManual(amount: 200, merchant: 'Unknown Shop', categoryId: null, paymentMethod: 'cash', txnDate: DateTime(2026, 8, 2));

    final list = await repo.monthSpendByCategory(DateTime(2026, 8, 1));
    expect(list, hasLength(2));
    expect(list.any((c) => c.$1.name == 'Food' && c.$2 == 500), isTrue);
    expect(list.any((c) => c.$1.name == 'Uncategorized' && c.$2 == 200), isTrue);
  });
}
