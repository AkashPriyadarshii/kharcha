import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';

import 'transaction_repository.dart';

/// Exports transactions to CSV or JSON at [dir]/[fileName].
class Exporter {
  Exporter(this._repo);

  final TransactionRepository _repo;

  /// CSV with headers, newest first.
  Future<File> exportCsv(Directory dir, String fileName) async {
    final rows = await _repo.allTransactions();
    final csv = const ListToCsvConverter().convert([
      ['date', 'amount', 'merchant', 'category', 'note', 'payment_method', 'upi_ref', 'source'],
      for (final (t, cat) in rows)
        [
          t.txnDate.toIso8601String(),
          t.amount.toString(),
          t.merchant,
          cat ?? '',
          t.note ?? '',
          t.paymentMethod,
          t.upiRef ?? '',
          t.source,
        ],
    ]);
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(csv, flush: true);
    return file;
  }

  /// JSON array, newest first.
  Future<File> exportJson(Directory dir, String fileName) async {
    final rows = await _repo.allTransactions();
    final json = JsonEncoder.withIndent('  ').convert([
      for (final (t, cat) in rows)
        {
          'date': t.txnDate.toIso8601String(),
          'amount': t.amount,
          'merchant': t.merchant,
          'category': cat ?? '',
          'note': t.note ?? '',
          'payment_method': t.paymentMethod,
          'upi_ref': t.upiRef ?? '',
          'source': t.source,
        },
    ]);
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(json, flush: true);
    return file;
  }
}
