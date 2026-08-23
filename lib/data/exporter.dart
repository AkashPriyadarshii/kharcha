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
      ['date', 'amount', 'type', 'merchant', 'category', 'note', 'payment_method', 'upi_ref', 'source'],
      for (final (t, cat) in rows)
        [
          t.txnDate.toIso8601String(),
          t.amount.toString(),
          t.isIncome ? 'income' : 'expense',
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
          'type': t.isIncome ? 'income' : 'expense',
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

  /// Full workspace JSON backup: transactions, budgets, debts, recurring,
  /// objectives, wallets, and custom categories.
  Future<File> exportFullBackup(Directory dir, String fileName) async {
    final txns = await _repo.allTransactions();
    final budgets = await _repo.watchBudgets().first;
    final debts = await _repo.watchDebts().first;
    final recurring = await _repo.watchRecurring().first;
    final objectives = await _repo.watchObjectives().first;
    final wallets = await _repo.watchWallets().first;
    final categories = await _repo.watchCategories().first;

    final backup = {
      'app': 'Kharcha',
      'version': 1,
      'exported_at': DateTime.now().toIso8601String(),
      'transactions': [
        for (final (t, cat) in txns)
          {
            'date': t.txnDate.toIso8601String(),
            'amount': t.amount,
            'type': t.isIncome ? 'income' : 'expense',
            'merchant': t.merchant,
            'category': cat ?? '',
            'note': t.note ?? '',
            'payment_method': t.paymentMethod,
            'upi_ref': t.upiRef ?? '',
            'source': t.source,
          }
      ],
      'budgets': [
        for (final (b, cat) in budgets)
          {
            'category': cat.name,
            'amount': b.amount,
            'period': b.period,
          }
      ],
      'debts': [
        for (final d in debts)
          {
            'name': d.name,
            'amount': d.amount,
            'is_lent': d.isLent,
            'note': d.note ?? '',
            'settled': d.settled,
          }
      ],
      'recurring': [
        for (final r in recurring)
          {
            'merchant': r.merchant,
            'amount': r.amount,
            'period': r.period,
            'next_due': r.nextDue.toIso8601String(),
            'active': r.active,
          }
      ],
      'objectives': [
        for (final o in objectives)
          {
            'name': o.name,
            'target': o.target,
            'saved': o.saved,
            'deadline': o.deadline?.toIso8601String(),
          }
      ],
      'wallets': [
        for (final w in wallets)
          {
            'name': w.name,
            'currency': w.currency,
            'initial_balance': w.initialBalance,
          }
      ],
      'custom_categories': [
        for (final c in categories.where((c) => c.isCustom))
          {
            'name': c.name,
            'emoji': c.emoji,
            'color': c.color,
            'is_income': c.isIncome,
          }
      ],
    };

    final json = const JsonEncoder.withIndent('  ').convert(backup);
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(json, flush: true);
    return file;
  }
}
