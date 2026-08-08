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

  test('insertObjective + watch emits with defaults', () async {
    await repo.insertObjective(name: 'Trip to Goa', target: 20000);
    final goals = await repo.watchObjectives().first;
    expect(goals.single.name, 'Trip to Goa');
    expect(goals.single.saved, 0);
  });

  test('addToObjective accumulates saved amount', () async {
    final g = await repo.insertObjective(name: 'Trip', target: 20000);
    await repo.addToObjective(g.id, 5000);
    await repo.addToObjective(g.id, 3000);
    expect((await repo.watchObjectives().first).single.saved, 8000);
  });

  test('addToObjective ignores non-positive amounts', () async {
    final g = await repo.insertObjective(name: 'Trip', target: 20000);
    await repo.addToObjective(g.id, 0);
    expect((await repo.watchObjectives().first).single.saved, 0);
  });
}
