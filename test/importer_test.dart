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
}
