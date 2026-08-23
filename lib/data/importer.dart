import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';

import '../core/money.dart';
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
const _headers = ['date', 'amount', 'type', 'merchant', 'category', 'note', 'payment_method', 'upi_ref', 'source'];

DateTime? _parseFlexibleDate(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  final text = raw.trim();
  final iso = DateTime.tryParse(text);
  if (iso != null) return iso;

  // Match dd/MM/yyyy or dd-MM-yyyy with optional time
  final dmy = RegExp(r'^(\d{1,2})[/\-](\d{1,2})[/\-](\d{2,4})(?:\s+(\d{1,2}):(\d{2})(?::(\d{2}))?)?').firstMatch(text);
  if (dmy != null) {
    final day = int.parse(dmy.group(1)!);
    final month = int.parse(dmy.group(2)!);
    var year = int.parse(dmy.group(3)!);
    if (year < 100) year += 2000;
    final hour = dmy.group(4) != null ? int.parse(dmy.group(4)!) : 0;
    final minute = dmy.group(5) != null ? int.parse(dmy.group(5)!) : 0;
    final second = dmy.group(6) != null ? int.parse(dmy.group(6)!) : 0;
    try {
      return DateTime(year, month, day, hour, minute, second);
    } catch (_) {
      return null;
    }
  }
  return null;
}

/// Parses [file] (CSV with a header row) and inserts each row via [repo].
/// Tolerant: a bad row is skipped and counted, never an abort. Returns the
/// added/skipped counts and the per-row error messages.
Future<ImportResult> importCsv(File file, TransactionRepository repo) async {
  final raw = await file.readAsString();
  if (raw.trim().isEmpty) {
    return const ImportResult(added: 0, skipped: 0, errors: ['File is empty']);
  }

  final rows = const CsvToListConverter(eol: '\n', shouldParseNumbers: false).convert(raw);
  if (rows.isEmpty) {
    return const ImportResult(added: 0, skipped: 0, errors: ['File is empty']);
  }

  // Locate the header row.
  var dataStart = 0;
  final col = <String, int>{};

  final firstRow = rows.first.map((c) => c.toString().trim().toLowerCase()).toList();
  final hasAmountHeader = firstRow.any((h) => h.contains('amount') || h.contains('total') || h == 'cost');

  if (hasAmountHeader) {
    for (var i = 0; i < rows.first.length; i++) {
      col[rows.first[i].toString().trim().toLowerCase()] = i;
    }
    dataStart = 1;
  } else if (rows.first.length == _headers.length) {
    // Fall back to positional order when the header is missing entirely.
    for (var i = 0; i < _headers.length; i++) {
      col[_headers[i]] = i;
    }
  } else {
    return const ImportResult(added: 0, skipped: 0, errors: ['No amount column found']);
  }

  int? findCol(List<String> aliases) {
    for (final a in aliases) {
      if (col.containsKey(a.toLowerCase())) return col[a.toLowerCase()];
    }
    return null;
  }

  final dateIdx = findCol(['date', 'txn_date', 'timestamp', 'time']);
  final amountIdx = findCol(['amount', 'total', 'cost', 'value']);
  final merchantIdx = findCol(['merchant', 'payee', 'vendor', 'name', 'description']);
  final categoryIdx = findCol(['category', 'category_name']);
  final typeIdx = findCol(['type', 'transaction_type', 'direction']);
  final noteIdx = findCol(['note', 'notes', 'remarks', 'description']);
  final methodIdx = findCol(['payment_method', 'method', 'account', 'bank', 'wallet']);
  final refIdx = findCol(['upi_ref', 'ref', 'reference', 'utr', 'txn_id']);

  if (amountIdx == null || merchantIdx == null) {
    return const ImportResult(added: 0, skipped: 0, errors: ['Headers must include amount and merchant']);
  }

  String? cell(List<dynamic> row, int? index) {
    if (index == null || index >= row.length) return null;
    final v = row[index].toString().trim();
    return v.isEmpty ? null : v;
  }

  var added = 0;
  var skipped = 0;
  final errors = <String>[];

  for (var r = dataStart; r < rows.length; r++) {
    final row = rows[r];
    if (row.every((c) => c.toString().trim().isEmpty)) continue;

    final amountStr = cell(row, amountIdx)?.replaceAll(',', '');
    final amount = parseAmount(amountStr);
    final merchant = cell(row, merchantIdx);
    final rawDate = cell(row, dateIdx);
    final txnDate = _parseFlexibleDate(rawDate);

    if (amount == null || amount <= 0) {
      skipped++;
      errors.add('Row ${r + 1}: invalid amount');
      continue;
    }
    if (merchant == null || merchant.isEmpty) {
      skipped++;
      errors.add('Row ${r + 1}: missing merchant');
      continue;
    }
    if (txnDate == null) {
      skipped++;
      errors.add('Row ${r + 1}: invalid date');
      continue;
    }

    var method = cell(row, methodIdx)?.toLowerCase() ?? 'upi';
    if (!TransactionRepository.paymentMethods.contains(method)) method = 'upi';
    final categoryName = cell(row, categoryIdx);
    final categoryId = categoryName != null ? await repo.categoryIdByName(categoryName) : null;
    final rawType = cell(row, typeIdx)?.toLowerCase();
    final isIncome = rawType == 'income' || rawType == 'credit';

    final inserted = await repo.insertImported(
      amount: amount,
      merchant: merchant,
      categoryId: categoryId,
      note: cell(row, noteIdx),
      paymentMethod: method,
      txnDate: txnDate,
      upiRef: cell(row, refIdx),
      isIncome: isIncome,
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

/// Parses [file] containing either a JSON array of transaction objects or a
/// full Kharcha backup object, restoring records into [repo].
Future<ImportResult> importJson(File file, TransactionRepository repo) async {
  final raw = await file.readAsString();
  if (raw.trim().isEmpty) {
    return const ImportResult(added: 0, skipped: 0, errors: ['File is empty']);
  }

  dynamic decoded;
  try {
    decoded = json.decode(raw);
  } catch (e) {
    return ImportResult(added: 0, skipped: 0, errors: ['Invalid JSON: $e']);
  }

  List<dynamic> txList;
  if (decoded is List) {
    txList = decoded;
  } else if (decoded is Map<String, dynamic>) {
    // Restore custom categories first so category foreign keys resolve
    if (decoded['custom_categories'] is List) {
      for (final cat in decoded['custom_categories']) {
        if (cat is Map) {
          final name = cat['name']?.toString() ?? '';
          final emoji = cat['emoji']?.toString() ?? '🏷️';
          final color = cat['color']?.toString() ?? '#8D99AE';
          final isIncome = cat['is_income'] == true;
          if (name.isNotEmpty) {
            await repo.insertCategory(name: name, emoji: emoji, color: color, isIncome: isIncome);
          }
        }
      }
    }
    if (decoded['budgets'] is List) {
      for (final b in decoded['budgets']) {
        if (b is Map) {
          final catName = b['category']?.toString() ?? '';
          final amount = (b['amount'] as num?)?.toDouble();
          final catId = await repo.categoryIdByName(catName);
          if (catId != null && amount != null && amount > 0) {
            await repo.upsertBudget(categoryId: catId, amount: amount);
          }
        }
      }
    }
    if (decoded['debts'] is List) {
      for (final d in decoded['debts']) {
        if (d is Map) {
          final name = d['name']?.toString() ?? '';
          final amount = (d['amount'] as num?)?.toDouble() ?? 0.0;
          final isLent = d['is_lent'] == true;
          final note = d['note']?.toString();
          if (name.isNotEmpty && amount > 0) {
            await repo.insertDebt(name: name, amount: amount, isLent: isLent, note: note);
          }
        }
      }
    }
    if (decoded['recurring'] is List) {
      for (final r in decoded['recurring']) {
        if (r is Map) {
          final merchant = r['merchant']?.toString() ?? '';
          final amount = (r['amount'] as num?)?.toDouble() ?? 0.0;
          final period = r['period']?.toString() ?? 'monthly';
          final nextDue = DateTime.tryParse(r['next_due']?.toString() ?? '') ?? DateTime.now();
          final catName = r['category']?.toString() ?? '';
          final catId = catName.isNotEmpty ? await repo.categoryIdByName(catName) : null;
          if (merchant.isNotEmpty && amount > 0) {
            await repo.insertRecurring(
              merchant: merchant,
              amount: amount,
              period: period,
              nextDue: nextDue,
              categoryId: catId,
            );
          }
        }
      }
    }
    if (decoded['objectives'] is List) {
      for (final o in decoded['objectives']) {
        if (o is Map) {
          final name = o['name']?.toString() ?? '';
          final target = (o['target'] as num?)?.toDouble() ?? 0.0;
          final saved = (o['saved'] as num?)?.toDouble() ?? 0.0;
          final deadline = DateTime.tryParse(o['deadline']?.toString() ?? '');
          if (name.isNotEmpty && target > 0) {
            final obj = await repo.insertObjective(name: name, target: target, deadline: deadline);
            if (saved > 0) {
              await repo.addToObjective(obj.id, saved);
            }
          }
        }
      }
    }
    if (decoded['wallets'] is List) {
      for (final w in decoded['wallets']) {
        if (w is Map) {
          final name = w['name']?.toString() ?? '';
          final currency = w['currency']?.toString() ?? 'INR';
          final initial = (w['initial_balance'] as num?)?.toDouble() ?? 0.0;
          if (name.isNotEmpty) {
            await repo.insertWallet(name: name, currency: currency, initialBalance: initial);
          }
        }
      }
    }
    txList = (decoded['transactions'] as List?) ?? [];
  } else {
    return const ImportResult(added: 0, skipped: 0, errors: ['JSON root must be an array or backup object']);
  }

  var added = 0;
  var skipped = 0;
  final errors = <String>[];

  for (var i = 0; i < txList.length; i++) {
    final item = txList[i];
    if (item is! Map) {
      skipped++;
      errors.add('Item ${i + 1}: not an object');
      continue;
    }

    final amountStr = item['amount']?.toString().replaceAll(',', '');
    final amount = parseAmount(amountStr);
    final merchant = item['merchant']?.toString().trim();
    final dateStr = item['date']?.toString();
    final txnDate = _parseFlexibleDate(dateStr);

    if (amount == null || amount <= 0) {
      skipped++;
      errors.add('Item ${i + 1}: invalid amount');
      continue;
    }
    if (merchant == null || merchant.isEmpty) {
      skipped++;
      errors.add('Item ${i + 1}: missing merchant');
      continue;
    }
    if (txnDate == null) {
      skipped++;
      errors.add('Item ${i + 1}: invalid date');
      continue;
    }

    var method = item['payment_method']?.toString().toLowerCase() ?? 'upi';
    if (!TransactionRepository.paymentMethods.contains(method)) method = 'upi';
    final categoryName = item['category']?.toString();
    final categoryId = (categoryName != null && categoryName.isNotEmpty)
        ? await repo.categoryIdByName(categoryName)
        : null;
    final typeStr = item['type']?.toString().toLowerCase();
    final isIncome = typeStr == 'income' || typeStr == 'credit' || item['is_income'] == true;

    final inserted = await repo.insertImported(
      amount: amount,
      merchant: merchant,
      categoryId: categoryId,
      note: item['note']?.toString(),
      paymentMethod: method,
      txnDate: txnDate,
      upiRef: item['upi_ref']?.toString(),
      isIncome: isIncome,
    );
    if (inserted == null) {
      skipped++;
      errors.add('Item ${i + 1}: duplicate (UPI ref already present)');
    } else {
      added++;
    }
  }

  return ImportResult(added: added, skipped: skipped, errors: errors);
}
