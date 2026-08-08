import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/categorizer.dart';
import 'database.dart';
import 'remote_transaction.dart';

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

/// An aggregate derived from the live transactions stream.
///
/// Recomputes the DB query on every insert/delete — the FutureProvider
/// versions computed once and stayed stale for the app's lifetime (the
/// "budget/home/reports don't refresh" bug). Each aggregate subscribes to its
/// own watchAll() stream; Drift keeps them cheap. ponytail: if profiles show
/// N+1 watch streams, merge onto a single shared stream + map.
Stream<T> _aggregate<T>(Ref ref, Future<T> Function(TransactionRepository) query) {
  final repo = ref.watch(transactionRepositoryProvider);
  return repo.watchAll().asyncMap((_) => query(repo));
}

/// This month's spend per category, largest first.
final monthSpendProvider = StreamProvider<List<(Category, double)>>(
  (ref) => _aggregate(ref, (repo) => repo.monthSpendByCategory(DateTime.now())),
);

/// Budgets joined with their categories.
final budgetsProvider = StreamProvider<List<(Budget, Category)>>(
  (ref) => ref.watch(transactionRepositoryProvider).watchBudgets(),
);

/// Monthly spend trend for the reports chart.
final monthlyTrendProvider = StreamProvider<List<(String, double)>>(
  (ref) => _aggregate(ref, (repo) => repo.monthlyTrend(DateTime.now())),
);

/// Merchant ranking for the reports list.
final merchantRankingProvider = StreamProvider<List<(String, double, int)>>(
  (ref) => _aggregate(ref, (repo) => repo.merchantRanking()),
);

/// Spend per payment method, for the profile tab.
final paymentMethodTotalsProvider = StreamProvider<List<(String, double, int)>>(
  (ref) => _aggregate(ref, (repo) => repo.paymentMethodTotals()),
);

/// Backup status: (on Supabase, pending push), for the profile tab.
final syncStatusProvider = FutureProvider<(int, int)>(
  (ref) => ref.watch(transactionRepositoryProvider).syncStatus(),
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

  /// Total spent on [day] (local calendar day). 0 when none.
  Future<double> dayTotal(DateTime day) {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    final sum = _db.transactions.amount.sum();
    final query = _db.selectOnly(_db.transactions)
      ..addColumns([sum])
      ..where(_db.transactions.txnDate.isBiggerOrEqualValue(start) &
          _db.transactions.txnDate.isSmallerThanValue(end));
    return query.getSingle().then((row) => row.read(sum) ?? 0);
  }

  /// Number of uncategorized transactions on [day].
  Future<int> dayUncategorizedCount(DateTime day) async {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    final rows = await (_db.select(_db.transactions)
          ..where((t) =>
              t.txnDate.isBiggerOrEqualValue(start) &
              t.txnDate.isSmallerThanValue(end) &
              t.categoryId.isNull()))
        .get();
    return rows.length;
  }

  /// Total spent in the 7 days up to and including [end]. 0 when none.
  Future<double> weekTotal(DateTime end) {
    final start = DateTime(end.year, end.month, end.day).subtract(const Duration(days: 6));
    final endExclusive = start.add(const Duration(days: 7));
    final sum = _db.transactions.amount.sum();
    final query = _db.selectOnly(_db.transactions)
      ..addColumns([sum])
      ..where(_db.transactions.txnDate.isBiggerOrEqualValue(start) &
          _db.transactions.txnDate.isSmallerThanValue(endExclusive));
    return query.getSingle().then((row) => row.read(sum) ?? 0);
  }

  /// Top [n] categories by spend in the 7 days up to and including [end].
  /// Uncategorized transactions are excluded (no category to name).
  Future<List<(String name, double amount)>> topCategories(DateTime end, {int n = 3}) async {
    final start = DateTime(end.year, end.month, end.day).subtract(const Duration(days: 6));
    final endExclusive = start.add(const Duration(days: 7));
    final rows = _db.select(_db.transactions).join([
      innerJoin(_db.categories, _db.categories.id.equalsExp(_db.transactions.categoryId)),
    ])
      ..where(_db.transactions.txnDate.isBiggerOrEqualValue(start) &
          _db.transactions.txnDate.isSmallerThanValue(endExclusive));
    final perCategory = <String, double>{};
    for (final r in await rows.get()) {
      final name = r.readTable(_db.categories).name;
      perCategory[name] = (perCategory[name] ?? 0) + r.readTable(_db.transactions).amount;
    }
    final ranked = perCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return ranked.take(n).map((e) => (e.key, e.value)).toList();
  }

  /// Total spent in [month] (local).
  Future<double> monthTotal(DateTime month) {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);
    final sum = _db.transactions.amount.sum();
    final q = _db.selectOnly(_db.transactions)
      ..addColumns([sum])
      ..where(_db.transactions.txnDate.isBiggerOrEqualValue(start) &
          _db.transactions.txnDate.isSmallerThanValue(end));
    return q.getSingle().then((row) => row.read(sum) ?? 0);
  }

  /// Spend per category in [month], largest first. Uncategorized excluded.
  Future<List<(Category, double)>> monthSpendByCategory(DateTime month) async {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);
    final rows = _db.select(_db.transactions).join([
      innerJoin(_db.categories, _db.categories.id.equalsExp(_db.transactions.categoryId)),
    ])
      ..where(_db.transactions.txnDate.isBiggerOrEqualValue(start) &
          _db.transactions.txnDate.isSmallerThanValue(end));
    final per = <int, (Category, double)>{};
    for (final r in await rows.get()) {
      final cat = r.readTable(_db.categories);
      final amount = r.readTable(_db.transactions).amount;
      per.update(cat.id, (v) => (v.$1, v.$2 + amount), ifAbsent: () => (cat, amount));
    }
    final list = per.values.toList()..sort((a, b) => b.$2.compareTo(a.$2));
    return list;
  }

  /// Spend per calendar month over the last [months] months ending at
  /// [end], oldest first. Returns (monthLabel, total) — for the trend chart.
  Future<List<(String, double)>> monthlyTrend(DateTime end, {int months = 6}) async {
    // Scan newest-first, stop once we've covered [months] distinct months.
    final rows = await (_db.select(_db.transactions)..orderBy([(t) => OrderingTerm.desc(t.txnDate)]))
        .get();
    final per = <DateTime, double>{};
    for (final t in rows) {
      final m = DateTime(t.txnDate.year, t.txnDate.month);
      per[m] = (per[m] ?? 0) + t.amount;
    }
    final out = <(String, double)>[];
    var cur = DateTime(end.year, end.month);
    for (var i = 0; i < months; i++) {
      out.add((DateFormat('MMM yy').format(cur), per[cur] ?? 0));
      cur = DateTime(cur.year, cur.month - 1);
    }
    return out.reversed.toList();
  }

  /// Top [n] merchants by spend, newest-first order from [allTransactions].
  Future<List<(String, double, int)>> merchantRanking({int n = 10}) async {
    final per = <String, (double, int)>{};
    for (final (t, _) in await allTransactions()) {
      final v = per[t.merchant] ?? (0, 0);
      per[t.merchant] = (v.$1 + t.amount, v.$2 + 1);
    }
    final ranked = per.entries.toList()..sort((a, b) => b.value.$1.compareTo(a.value.$1));
    return ranked.take(n).map((e) => (e.key, e.value.$1, e.value.$2)).toList();
  }

  /// Total spent per payment method, largest first.
  Future<List<(String, double, int)>> paymentMethodTotals() async {
    final per = <String, (double, int)>{};
    for (final (t, _) in await allTransactions()) {
      final v = per[t.paymentMethod] ?? (0, 0);
      per[t.paymentMethod] = (v.$1 + t.amount, v.$2 + 1);
    }
    final ranked = per.entries.toList()..sort((a, b) => b.value.$1.compareTo(a.value.$1));
    return ranked.map((e) => (e.key, e.value.$1, e.value.$2)).toList();
  }

  /// (rows pushed to Supabase, rows pending push).
  Future<(int, int)> syncStatus() async {
    final all = await _db.select(_db.transactions).get();
    final pending = all.where((t) => t.dirty).length;
    return (all.length - pending, pending);
  }

  /// Budgets joined with their category.
  Stream<List<(Budget, Category)>> watchBudgets() {
    final q = _db.select(_db.budgets).join([
      innerJoin(_db.categories, _db.categories.id.equalsExp(_db.budgets.categoryId)),
    ]);
    return q.watch().map((rows) => [
          for (final r in rows) (r.readTable(_db.budgets), r.readTable(_db.categories)),
        ]);
  }

  /// Creates or updates the monthly budget for [categoryId].
  Future<void> upsertBudget({required int categoryId, required double amount}) async {
    final existing = await (_db.select(_db.budgets)..where((b) => b.categoryId.equals(categoryId)))
        .getSingleOrNull();
    if (existing == null) {
      await _db.into(_db.budgets).insert(BudgetsCompanion.insert(
        categoryId: categoryId,
        amount: amount,
        period: 'monthly',
      ));
    } else {
      await (_db.update(_db.budgets)..where((b) => b.id.equals(existing.id)))
          .write(BudgetsCompanion(amount: Value(amount)));
    }
  }

  Future<void> deleteBudget(int id) {
    return (_db.delete(_db.budgets)..where((b) => b.id.equals(id))).go();
  }

  /// All transactions newest-first, with their category name (null when
  /// uncategorized) — for exports.
  Future<List<(Transaction, String?)>> allTransactions() async {
    final rows = _db.select(_db.transactions).join([
      leftOuterJoin(_db.categories, _db.categories.id.equalsExp(_db.transactions.categoryId)),
    ])
      ..orderBy([OrderingTerm.desc(_db.transactions.txnDate), OrderingTerm.desc(_db.transactions.id)]);
    return (await rows.get()).map((r) {
      final cat = r.readTableOrNull(_db.categories);
      return (r.readTable(_db.transactions), cat?.name);
    }).toList();
  }

  /// Rows waiting to be pushed to Supabase.
  Future<List<Transaction>> dirtyRows() {
    return (_db.select(_db.transactions)..where((t) => t.dirty.equals(true))).get();
  }

  /// Records that [id] now lives remotely as [remoteId]. [dirty] stays true
  /// when the local row is newer than what's on the remote — the next push
  /// overwrites it (update by id) and converges.
  Future<void> markSynced(int id, int remoteId, {bool dirty = false}) {
    return (_db.update(_db.transactions)..where((t) => t.id.equals(id))).write(
      TransactionsCompanion(remoteId: Value(remoteId), dirty: Value(dirty)),
    );
  }

  Future<Transaction?> findByRemoteId(int remoteId) {
    return (_db.select(_db.transactions)..where((t) => t.remoteId.equals(remoteId)))
        .getSingleOrNull();
  }

  Future<Transaction?> findByUpiRef(String upiRef) {
    return (_db.select(_db.transactions)..where((t) => t.upiRef.equals(upiRef)))
        .getSingleOrNull();
  }

  /// Pull-side merge. Returns the winning local row.
  ///
  /// Identity: remote row id first, else same upi_ref. Then LWW by
  /// [localWins] — local newer stays dirty (next push converges the remote),
  /// remote newer overwrites local and clears dirty.
  Future<Transaction> applyRemote(RemoteTransaction r) async {
    final byRemoteId = await findByRemoteId(r.id!);
    if (byRemoteId != null) return _merge(byRemoteId, r);

    if (r.upiRef != null) {
      final byUpi = await findByUpiRef(r.upiRef!);
      if (byUpi != null) return _merge(byUpi, r);
    }

    return _insertFromRemote(r);
  }

  Future<Transaction> _merge(Transaction local, RemoteTransaction r) async {
    if (localWins(local.updatedAt, r.updatedAt)) {
      // Local is newer/equal. Claim the remote id so a duplicate is never
      // inserted, but stay dirty so the next push overwrites the remote copy.
      await markSynced(local.id, r.id!, dirty: true);
      return local;
    }
    // Remote is newer → local copy is stale; overwrite and sync clean.
    await (_db.update(_db.transactions)..where((t) => t.id.equals(local.id))).write(
      TransactionsCompanion(
        amount: Value(r.amount),
        merchant: Value(r.merchant),
        txnDate: Value(r.txnDate),
        note: Value(r.note),
        paymentMethod: Value(r.paymentMethod),
        upiRef: Value(r.upiRef),
        source: Value(r.source),
        updatedAt: Value(r.updatedAt),
        remoteId: Value(r.id),
        dirty: const Value(false),
      ),
    );
    return (_db.select(_db.transactions)..where((t) => t.id.equals(local.id))).getSingle();
  }

  /// A remote row we've never seen → insert a local copy. Categorization is
  /// derived locally from rules (the remote stores no per-user category id).
  Future<Transaction> _insertFromRemote(RemoteTransaction r) async {
    final categoryId = categorize(
      merchant: r.merchant,
      rules: await _db.select(_db.rules).get(),
    );
    final id = await _db.into(_db.transactions).insert(
          TransactionsCompanion.insert(
            amount: r.amount,
            merchant: r.merchant,
            categoryId: Value(categoryId),
            note: Value(r.note),
            paymentMethod: r.paymentMethod,
            upiRef: Value(r.upiRef),
            source: r.source,
            txnDate: r.txnDate,
            updatedAt: Value(r.updatedAt),
            dirty: const Value(false),
            remoteId: Value(r.id),
          ),
        );
    return (_db.select(_db.transactions)..where((t) => t.id.equals(id))).getSingle();
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
