import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kharcha/data/database.dart';
import 'package:kharcha/data/exporter.dart';
import 'package:kharcha/data/transaction_repository.dart';

void main() {
  late AppDatabase db;
  late TransactionRepository repo;
  late Directory dir;

  setUp(() {
    db = AppDatabase(executor: NativeDatabase.memory());
    repo = TransactionRepository(db);
    dir = Directory.systemTemp.createTempSync('kharcha_export');
  });

  tearDown(() async {
    await db.close();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  test('exportCsv writes headers + rows with category name', () async {
    final food = await (db.select(db.categories)..where((c) => c.name.equals('Food'))).getSingle();
    await repo.insertManual(
      amount: 450, merchant: 'Zomato', categoryId: food.id,
      paymentMethod: 'upi', txnDate: DateTime(2026, 8, 6),
    );

    final file = await Exporter(repo).exportCsv(dir, 'kharcha.csv');

    final lines = await file.readAsLines();
    expect(lines.first, 'date,amount,merchant,category,note,payment_method,upi_ref,source');
    expect(lines, hasLength(2));
    expect(lines.last, contains('Zomato'));
    expect(lines.last, contains('Food'));
  });

  test('exportJson writes an array with category name', () async {
    final food = await (db.select(db.categories)..where((c) => c.name.equals('Food'))).getSingle();
    await repo.insertManual(
      amount: 450, merchant: 'Zomato', categoryId: food.id,
      paymentMethod: 'upi', txnDate: DateTime(2026, 8, 6),
    );

    final file = await Exporter(repo).exportJson(dir, 'kharcha.json');
    final json = await file.readAsString();
    expect(json, contains('"merchant": "Zomato"'));
    expect(json, contains('"category": "Food"'));
    expect(json, contains('"amount": 450.0'));
  });
}
