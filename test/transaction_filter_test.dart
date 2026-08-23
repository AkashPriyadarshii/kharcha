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
  bool isIncome = false,
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
      isIncome: isIncome,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      dirty: false,
      remoteId: null,
      isDeleted: false,
      needsReview: false,
    );

void main() {
  final rows = [
    _tx(id: 1, merchant: 'Zomato', note: 'lunch', categoryId: 1, txnDate: DateTime(2026, 8, 1)),
    _tx(id: 2, merchant: 'Swiggy', note: 'dinner', categoryId: 1, txnDate: DateTime(2026, 8, 5)),
    _tx(id: 3, merchant: 'Metro', categoryId: 2, txnDate: DateTime(2026, 7, 20), paymentMethod: 'card'),
    _tx(id: 4, merchant: 'Ravi Kirana', categoryId: 6, txnDate: DateTime(2026, 8, 10), paymentMethod: 'cash'),
    _tx(id: 5, merchant: 'Acme Corp', isIncome: true, txnDate: DateTime(2026, 8, 11)),
  ];

  List<int> ids(List<Transaction> ts) => [for (final t in ts) t.id];

  test('empty filter returns all rows in input order', () {
    const f = TransactionFilter();
    expect(f.isEmpty, isTrue);
    expect(ids(f.apply(rows)), [1, 2, 3, 4, 5]);
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

  test('income filter keeps only income rows', () {
    const f = TransactionFilter(isIncome: true);
    expect(ids(f.apply(rows)), [5]);
  });

  test('expense filter excludes income rows', () {
    const f = TransactionFilter(isIncome: false);
    expect(ids(f.apply(rows)), [1, 2, 3, 4]);
  });

  test('from bound is inclusive', () {
    final f = TransactionFilter(from: DateTime(2026, 8, 5));
    expect(ids(f.apply(rows)), [2, 4, 5]);
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

  test('multi-token query and hashtag searching in note', () {
    final rowsWithTags = [
      _tx(id: 10, merchant: 'Swiggy', note: 'pizza #goa #food'),
      _tx(id: 11, merchant: 'Uber', note: 'airport cab #goa'),
      _tx(id: 12, merchant: 'Decathlon', note: 'shoes #sports'),
    ];
    final fTag = const TransactionFilter(query: '#goa');
    expect(ids(fTag.apply(rowsWithTags)), [10, 11]);

    final fMulti = const TransactionFilter(query: 'Swiggy #goa');
    expect(ids(fMulti.apply(rowsWithTags)), [10]);
  });
}
