import 'dart:io';

import 'package:csv/csv.dart';

import 'transaction_repository.dart';

/// Result of an import: how many rows landed and which ones were skipped.
class ImportResult {
  const ImportResult({required this.added, required this.skipped, required this.errors});

  final int added;
  final int skipped;
  final List<String> errors;
}

/// Columns, in the same order [Exporter] writes them (round-trips our own
/// exports; other tools may produce the same headers in any order).
const _headers = ['date', 'amount', 'merchant', 'category', 'note', 'payment_method', 'upi_ref', 'source'];

/// Parses [file] (CSV with a header row) and inserts each row via [repo].
/// Tolerant: a bad row is skipped and counted, never an abort. Returns the
/// added/skipped counts and the per-row error messages.
Future<ImportResult> importCsv(File file, TransactionRepository repo) async {
  final raw = await file.readAsString();
  if (raw.trim().isEmpty) {
    return const ImportResult(added: 0, skipped: 0, errors: ['File is empty']);
  }

  final rows = const CsvToListConverter(eol: '\n', shouldParseNumbers: false).convert(raw);

  // Locate the header row. Our own exports always start with one; a header
  // row is recognized by containing an 'amount' column.
  var dataStart = 0;
  Map<String, int> col = {};
  if (rows.isNotEmpty && rows.first.contains('amount')) {
    col = {for (var i = 0; i < rows.first.length; i++) rows.first[i].toString().trim(): i};
    dataStart = 1;
  } else if (rows.isNotEmpty && rows.first.length == _headers.length) {
    // Fall back to positional order when the header is missing entirely.
    col = {for (var i = 0; i < _headers.length; i++) _headers[i]: i};
  } else {
    return const ImportResult(added: 0, skipped: 0, errors: ['No amount column found']);
  }
  if (!col.containsKey('amount') || !col.containsKey('merchant')) {
    return const ImportResult(added: 0, skipped: 0, errors: ['Headers must include amount and merchant']);
  }

  String? cell(List<dynamic> row, String name) {
    final i = col[name];
    if (i == null || i >= row.length) return null;
    final v = row[i].toString().trim();
    return v.isEmpty ? null : v;
  }

  var added = 0;
  var skipped = 0;
  final errors = <String>[];

  for (var r = dataStart; r < rows.length; r++) {
    final row = rows[r];
    if (row.every((c) => c.toString().trim().isEmpty)) continue;

    final amountStr = cell(row, 'amount')?.replaceAll(',', '');
    final amount = double.tryParse(amountStr ?? '');
    final merchant = cell(row, 'merchant');
    final txnDate = DateTime.tryParse(cell(row, 'date') ?? '');

    if (amount == null || amount <= 0) {
      skipped++;
      errors.add('Row ${r + 1}: invalid amount');
      continue;
    }
    if (merchant == null) {
      skipped++;
      errors.add('Row ${r + 1}: missing merchant');
      continue;
    }
    if (txnDate == null) {
      skipped++;
      errors.add('Row ${r + 1}: invalid date');
      continue;
    }

    var method = cell(row, 'payment_method') ?? 'upi';
    if (!TransactionRepository.paymentMethods.contains(method)) method = 'upi';
    final categoryId = await repo.categoryIdByName(cell(row, 'category') ?? '');

    final inserted = await repo.insertImported(
      amount: amount,
      merchant: merchant,
      categoryId: categoryId,
      note: cell(row, 'note'),
      paymentMethod: method,
      txnDate: txnDate,
      upiRef: cell(row, 'upi_ref'),
    );
    if (inserted == null) {
      skipped++;
      errors.add('Row ${r + 1}: duplicate (UPI ref already present)');
    } else {
      added++;
    }
  }

  return ImportResult(added: added, skipped: skipped, errors: errors);
}
