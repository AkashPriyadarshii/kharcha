import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kharcha/data/database.dart';
import 'package:kharcha/data/importer.dart';
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

  Future<File> writeCsv(String content) async {
    final f = File('${Directory.systemTemp.path}/import_test_${DateTime.now().microsecondsSinceEpoch}.csv');
    await f.writeAsString(content);
    addTearDown(() => f.existsSync() ? f.deleteSync() : null);
    return f;
  }

  test('imports rows matching the exporter format', () async {
    final f = await writeCsv(
      'date,amount,merchant,category,note,payment_method,upi_ref,source\n'
      '2026-08-01T10:00:00.000,450,Zomato,Food,lunch,upi,REF1,manual\n'
      '2026-07-15T09:30:00.000,100,Rapido,Travel,,cash,,manual\n',
    );

    final result = await importCsv(f, repo);
    expect(result.added, 2);
    expect(result.errors, isEmpty);

    final rows = await db.select(db.transactions).get();
    expect(rows, hasLength(2));
    expect(rows.map((r) => r.merchant), containsAll(['Zomato', 'Rapido']));
    expect(rows.first.source, 'import');
  });

  test('dedupes duplicate upi_ref rows', () async {
    final f = await writeCsv(
      'date,amount,merchant,category,note,payment_method,upi_ref,source\n'
      '2026-08-01T10:00:00.000,450,Zomato,Food,,upi,REF1,manual\n'
      '2026-08-01T11:00:00.000,450,Zomato,Food,,upi,REF1,manual\n',
    );

    final result = await importCsv(f, repo);
    expect(result.added, 1);
    expect(result.skipped, 1);
    expect(result.errors.single, contains('duplicate'));
  });

  test('skips invalid rows without aborting', () async {
    final f = await writeCsv(
      'date,amount,merchant,category,note,payment_method,upi_ref,source\n'
      '2026-08-01T10:00:00.000,-5,Zomato,Food,,upi,,manual\n'
      '2026-08-01T10:00:00.000,abc,Zomato,Food,,upi,,manual\n'
      'not-a-date,100,Zomato,Food,,upi,,manual\n'
      '2026-08-01T10:00:00.000,100,,Food,,upi,,manual\n'
      '2026-08-01T10:00:00.000,50,Rapido,Travel,,cash,,manual\n',
    );

    final result = await importCsv(f, repo);
    expect(result.added, 1);
    expect(result.skipped, 4);
    expect((await db.select(db.transactions).get()), hasLength(1));
  });

  test('headerless file with known column count is imported positionally', () async {
    // Positional order matches _headers: date, amount, type, merchant, …
    final f = await writeCsv(
      '2026-08-01T10:00:00.000,100,expense,Rapido,Travel,,cash,,manual\n',
    );

    final result = await importCsv(f, repo);
    expect(result.added, 1);
    expect((await db.select(db.transactions).get()).single.merchant, 'Rapido');
  });

  test('type=income column imports as income', () async {
    final f = await writeCsv(
      'date,amount,type,merchant,category,note,payment_method,upi_ref,source\n'
      '2026-08-01T10:00:00.000,1000,income,Acme Corp,,,upi,,manual\n'
      '2026-08-01T10:00:00.000,450,expense,Zomato,Food,lunch,upi,REF1,manual\n',
    );

    final result = await importCsv(f, repo);
    expect(result.added, 2);

    final rows = await db.select(db.transactions).get();
    expect(rows.firstWhere((r) => r.merchant == 'Acme Corp').isIncome, true);
    expect(rows.firstWhere((r) => r.merchant == 'Zomato').isIncome, false);
  });

  test('empty file reports error, not crash', () async {
    final f = await writeCsv('');
    final result = await importCsv(f, repo);
    expect(result.added, 0);
    expect(result.errors, isNotEmpty);
  });

  test('imports Pennywise format with capitalized headers and dd/MM/yyyy date format', () async {
    final f = await writeCsv(
      'Date,Time,Merchant,Category,Type,Amount,Currency,Bank,Account,Balance After,Description\n'
      '15/08/2026,14:30:00,Swiggy,Food,Expense,350.00,INR,HDFC,1234,5000.00,Lunch with friends\n'
      '16/08/2026,10:00:00,Consulting Client,Other income,Income,15000,INR,HDFC,1234,20000.00,Project fee\n',
    );

    final result = await importCsv(f, repo);
    expect(result.added, 2);
    expect(result.skipped, 0);

    final rows = await db.select(db.transactions).get();
    expect(rows, hasLength(2));
    final swiggy = rows.firstWhere((r) => r.merchant == 'Swiggy');
    expect(swiggy.amount, 350.0);
    expect(swiggy.isIncome, isFalse);
    expect(swiggy.txnDate.year, 2026);
    expect(swiggy.txnDate.month, 8);
    expect(swiggy.txnDate.day, 15);

    final consulting = rows.firstWhere((r) => r.merchant == 'Consulting Client');
    expect(consulting.amount, 15000.0);
    expect(consulting.isIncome, isTrue);
  });

  test('importJson restores full backup JSON with transactions, budgets and debts', () async {
    final f = await writeCsv('''
{
  "app": "Kharcha",
  "version": 1,
  "transactions": [
    {
      "date": "2026-08-10T12:00:00.000",
      "amount": 750,
      "type": "expense",
      "merchant": "Amazon",
      "category": "Shopping",
      "payment_method": "card",
      "upi_ref": "REF_JSON_1"
    }
  ],
  "debts": [
    {
      "name": "Pooja",
      "amount": 500,
      "is_lent": true,
      "note": "Dinner split"
    }
  ],
  "budgets": [
    {
      "category": "Food",
      "amount": 6000
    }
  ]
}
''');

    final result = await importJson(f, repo);
    expect(result.added, 1);
    expect(result.skipped, 0);

    final txns = await db.select(db.transactions).get();
    expect(txns.any((t) => t.merchant == 'Amazon' && t.amount == 750), isTrue);

    final debts = await db.select(db.debts).get();
    expect(debts.any((d) => d.name == 'Pooja' && d.amount == 500), isTrue);

    final budgets = await db.select(db.budgets).get();
    expect(budgets.any((b) => b.amount == 6000), isTrue);
  });
}
