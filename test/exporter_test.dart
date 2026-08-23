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
    expect(lines.first, 'date,amount,type,merchant,category,note,payment_method,upi_ref,source');
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
    expect(json, contains('"type": "expense"'));
  });

  test('income row exports type=income in csv + json', () async {
    await repo.insertManual(
      amount: 1000, merchant: 'Acme Corp', paymentMethod: 'upi',
      txnDate: DateTime(2026, 8, 6), isIncome: true,
    );

    final csv = await Exporter(repo).exportCsv(dir, 'inc.csv');
    expect(await csv.readAsString(), contains('income'));

    final json = await Exporter(repo).exportJson(dir, 'inc.json');
    expect(await json.readAsString(), contains('"type": "income"'));
  });

  test('exportFullBackup exports all tables in structured JSON', () async {
    final food = await (db.select(db.categories)..where((c) => c.name.equals('Food'))).getSingle();
    await repo.insertManual(amount: 450, merchant: 'Zomato', categoryId: food.id, paymentMethod: 'upi', txnDate: DateTime(2026, 8, 6));
    await repo.upsertBudget(categoryId: food.id, amount: 5000);
    await repo.insertDebt(name: 'Rahul', amount: 1500, isLent: true);
    await repo.insertObjective(name: 'MacBook', target: 120000);

    final file = await Exporter(repo).exportFullBackup(dir, 'kharcha_backup.json');
    final content = await file.readAsString();

    expect(content, contains('"app": "Kharcha"'));
    expect(content, contains('"transactions":'));
    expect(content, contains('"budgets":'));
    expect(content, contains('"debts":'));
    expect(content, contains('"objectives":'));
    expect(content, contains('Rahul'));
    expect(content, contains('MacBook'));
  });
}
