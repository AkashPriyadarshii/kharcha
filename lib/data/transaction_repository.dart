import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/categorizer.dart';
import 'database.dart';

/// Provider for the single shared [AppDatabase].
final databaseProvider = Provider<AppDatabase>((ref) => AppDatabase());

/// Provider for the repository backed by the shared database.
final transactionRepositoryProvider = Provider<TransactionRepository>(
  (ref) => TransactionRepository(ref.watch(databaseProvider)),
);

/// All transactions, newest first. Async because the first read hits the DB.
final transactionsProvider = StreamProvider<List<Transaction>>(
  (ref) => ref.watch(transactionRepositoryProvider).watchAll(),
);

/// Seeded + user categories for the picker.
final categoriesProvider = StreamProvider<List<Category>>(
  (ref) => ref.watch(transactionRepositoryProvider).watchCategories(),
);

/// Throws when a manual transaction is invalid. Message is user-facing.
class TransactionValidationException implements Exception {
  TransactionValidationException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Reads/writes [Transactions] rows. No duplicate models — Drift's generated
/// [Transaction] is the type everywhere.
class TransactionRepository {
  TransactionRepository(this._db);

  final AppDatabase _db;

  /// Watches all transactions, newest first.
  Stream<List<Transaction>> watchAll() {
    return (_db.select(_db.transactions)
          ..orderBy([(t) => OrderingTerm.desc(t.txnDate), (t) => OrderingTerm.desc(t.id)]))
        .watch();
  }

  /// Watches seeded categories (the default set the DB seeds on create).
  Stream<List<Category>> watchCategories() => _db.select(_db.categories).watch();

  /// Validates and inserts a manual transaction. Returns the stored row.
  ///
  /// Rules: amount > 0, merchant non-empty, paymentMethod in
  /// {cash, upi, card, wallet}, source = manual. categoryId optional.
  Future<Transaction> insertManual({
    required double amount,
    required String merchant,
    int? categoryId,
    String note = '',
    required String paymentMethod,
    required DateTime txnDate,
  }) async {
    final validation = validateManualTransaction(
      amount: amount,
      merchant: merchant,
      paymentMethod: paymentMethod,
    );
    if (validation != null) throw TransactionValidationException(validation);

    // Auto-categorize when the caller left it blank: known merchant → rule.
    var resolvedCategory = categoryId;
    resolvedCategory ??= categorize(
      merchant: merchant,
      rules: await _db.select(_db.rules).get(),
    );

    final id = await _db.into(_db.transactions).insert(
          TransactionsCompanion.insert(
            amount: amount,
            merchant: merchant.trim(),
            categoryId: Value(resolvedCategory),
            note: Value(note.trim().isEmpty ? null : note.trim()),
            paymentMethod: paymentMethod,
            upiRef: const Value(null),
            source: 'manual',
            txnDate: txnDate,
          ),
        );
    final row = await (_db.select(_db.transactions)..where((t) => t.id.equals(id))).getSingle();
    return row;
  }

  /// Returns true when a row already exists for [upiRef]. UPI refs are unique
  /// per payment — the dedupe that keeps notification + manual (and later SMS)
  /// from double-adding.
  Future<bool> existsUpiRef(String upiRef) async {
    final row = await (_db.select(_db.transactions)..where((t) => t.upiRef.equals(upiRef)))
        .getSingleOrNull();
    return row != null;
  }

  /// Inserts a notification-captured payment (source = notification).
  /// Skips when [upiRef] is already stored — dedupe. Returns null when skipped.
  Future<Transaction?> insertCaptured({
    required double amount,
    required String merchant,
    String? upiRef,
    required DateTime txnDate,
  }) async {
    final trimmedRef = upiRef?.trim();
    if (trimmedRef != null && trimmedRef.isNotEmpty && await existsUpiRef(trimmedRef)) {
      return null;
    }

    var categoryId = categorize(
      merchant: merchant,
      rules: await _db.select(_db.rules).get(),
    );

    final id = await _db.into(_db.transactions).insert(
          TransactionsCompanion.insert(
            amount: amount,
            merchant: merchant.trim(),
            categoryId: Value(categoryId),
            note: const Value(null),
            paymentMethod: 'upi',
            upiRef: Value(trimmedRef),
            source: 'notification',
            txnDate: txnDate,
          ),
        );
    final row = await (_db.select(_db.transactions)..where((t) => t.id.equals(id))).getSingle();
    return row;
  }

  static const paymentMethods = ['cash', 'upi', 'card', 'wallet'];
}

/// Pure validation for the manual form. Returns a user-facing error message,
/// or null when valid. Pure function = unit-testable without a widget tree.
String? validateManualTransaction({
  required double amount,
  required String merchant,
  required String paymentMethod,
}) {
  if (amount <= 0) return 'Enter an amount greater than zero.';
  if (merchant.trim().isEmpty) return 'Enter the merchant name.';
  if (!TransactionRepository.paymentMethods.contains(paymentMethod)) {
    return 'Pick a payment method.';
  }
  return null;
}
