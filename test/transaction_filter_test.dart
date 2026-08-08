import 'package:flutter_test/flutter_test.dart';
import 'package:kharcha/core/transaction_filter.dart';
import 'package:kharcha/data/database.dart';

Transaction _tx({
  required int id,
  required String merchant,
  int? categoryId,
  DateTime? txnDate,
  String? note,
  String paymentMethod = 'upi',
}) =>
    Transaction(
      id: id,
      amount: 100,
      merchant: merchant,
      categoryId: categoryId,
      txnDate: txnDate ?? DateTime(2026, 8, 1),
      note: note,
      paymentMethod: paymentMethod,
      source: 'manual',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      dirty: false,
      remoteId: null,
    );

void main() {
  final rows = [
    _tx(id: 1, merchant: 'Zomato', note: 'lunch', categoryId: 1, txnDate: DateTime(2026, 8, 1)),
    _tx(id: 2, merchant: 'Swiggy', note: 'dinner', categoryId: 1, txnDate: DateTime(2026, 8, 5)),
    _tx(id: 3, merchant: 'Metro', categoryId: 2, txnDate: DateTime(2026, 7, 20), paymentMethod: 'card'),
    _tx(id: 4, merchant: 'Ravi Kirana', categoryId: 6, txnDate: DateTime(2026, 8, 10), paymentMethod: 'cash'),
  ];

  List<int> ids(List<Transaction> ts) => [for (final t in ts) t.id];

  test('empty filter returns all rows in input order', () {
    const f = TransactionFilter();
    expect(f.isEmpty, isTrue);
    expect(ids(f.apply(rows)), [1, 2, 3, 4]);
  });

  test('query matches merchant case-insensitively', () {
    const f = TransactionFilter(query: 'zom');
    expect(ids(f.apply(rows)), [1]);
  });

  test('query matches note', () {
    const f = TransactionFilter(query: 'dinner');
    expect(ids(f.apply(rows)), [2]);
  });

  test('query with no match returns empty', () {
    const f = TransactionFilter(query: 'xyzzy');
    expect(f.apply(rows), isEmpty);
  });

  test('category filter keeps only that category', () {
    const f = TransactionFilter(categoryId: 2);
    expect(ids(f.apply(rows)), [3]);
  });

  test('merchant filter is an exact match, not substring', () {
    const f = TransactionFilter(merchant: 'Metro');
    expect(ids(f.apply(rows)), [3]);
    const partial = TransactionFilter(merchant: 'Met');
    expect(f.apply(rows), isNotEmpty);
    expect(partial.apply(rows), isEmpty);
  });

  test('payment method filter', () {
    const f = TransactionFilter(paymentMethod: 'cash');
    expect(ids(f.apply(rows)), [4]);
  });

  test('from bound is inclusive', () {
    final f = TransactionFilter(from: DateTime(2026, 8, 5));
    expect(ids(f.apply(rows)), [2, 4]);
  });

  test('to bound is inclusive', () {
    final f = TransactionFilter(to: DateTime(2026, 8, 5));
    expect(ids(f.apply(rows)), [1, 2, 3]);
  });

  test('combined criteria intersect', () {
    final f = TransactionFilter(
      query: 'zom',
      categoryId: 1,
      paymentMethod: 'upi',
      from: DateTime(2026, 8, 1),
      to: DateTime(2026, 8, 1),
    );
    expect(ids(f.apply(rows)), [1]);
  });
}
