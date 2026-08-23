import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';


import '../core/categorizer.dart';
import '../core/money.dart';
import 'database.dart';
import 'remote_feature.dart';
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

final rulesProvider = StreamProvider<List<Rule>>(
  (ref) => ref.watch(transactionRepositoryProvider).watchRules(),
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

/// Heatmap data for the last 140 days (20 weeks).
final spendingHeatmapProvider = StreamProvider<Map<DateTime, double>>(
  (ref) => _aggregate(ref, (repo) => repo.spendingHeatmap(DateTime.now())),
);

/// Spend per payment method, for the profile tab.
final paymentMethodTotalsProvider = StreamProvider<List<(String, double, int)>>(
  (ref) => _aggregate(ref, (repo) => repo.paymentMethodTotals()),
);

/// Backup status: (on Supabase, pending push), for the profile tab.
final syncStatusProvider = FutureProvider<(int, int)>(
  (ref) => ref.watch(transactionRepositoryProvider).syncStatus(),
);

/// All wallets for the balance header + pickers.
final walletsProvider = StreamProvider<List<Wallet>>(
  (ref) => ref.watch(transactionRepositoryProvider).watchWallets(),
);

/// Manual exchange rates for multi-currency conversion.
final exchangeRatesProvider = StreamProvider<List<ExchangeRate>>(
  (ref) => ref.watch(transactionRepositoryProvider).watchExchangeRates(),
);

/// Recurring subscriptions for the subscriptions tab/screen.
final recurringProvider = StreamProvider<List<RecurringTransaction>>(
  (ref) => ref.watch(transactionRepositoryProvider).watchRecurring(),
);

/// Savings goals.
final objectivesProvider = StreamProvider<List<Objective>>(
  (ref) => ref.watch(transactionRepositoryProvider).watchObjectives(),
);

/// Credit/debt ledger.
final debtsProvider = StreamProvider<List<Debt>>(
  (ref) => ref.watch(transactionRepositoryProvider).watchDebts(),
);

/// A record of a locally-deleted feature row that must be deleted on Supabase
/// too. [kind] is a [SyncKind.name]; 'categories' covers custom-category
/// deletes (no SyncKind). The engine drains these as DELETEs, then clears them.
class FeatureDelete {
  const FeatureDelete({required this.kind, required this.remoteId});
  final String kind;
  final int remoteId;
}

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
    int? walletId,
    bool isIncome = false,
  }) async {
    final validation = validateManualTransaction(
      amount: amount,
      merchant: merchant,
      paymentMethod: paymentMethod,
    );
    if (validation != null) throw TransactionValidationException(validation);

    // Auto-categorize when the caller left it blank: known merchant → rule.
    // Income never auto-categorizes from expense rules.
    var resolvedCategory = categoryId;
    if (!isIncome) {
      resolvedCategory ??= categorize(
        merchant: merchant,
        rules: await _db.select(_db.rules).get(),
      );
    }

    final id = await _db.into(_db.transactions).insert(
          TransactionsCompanion.insert(
            amount: amount,
            merchant: merchant.trim(),
            categoryId: Value(resolvedCategory),
            walletId: Value(walletId),
            note: Value(note.trim().isEmpty ? null : note.trim()),
            paymentMethod: paymentMethod,
            upiRef: const Value(null),
            source: 'manual',
            txnDate: txnDate,
            isIncome: Value(isIncome),
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
  /// [isIncome] true → money in (received/credited); categorized to income.
  Future<Transaction?> insertCaptured({
    required double amount,
    required String merchant,
    String? upiRef,
    required DateTime txnDate,
    bool isIncome = false,
    double? balance,
  }) async {
    final trimmedRef = upiRef?.trim();
    if (trimmedRef != null && trimmedRef.isNotEmpty && await existsUpiRef(trimmedRef)) {
      return null;
    }

    // Pennywise-style cross-channel deduplication: 
    // Prevent duplicate SMS + Notification captures by checking for the same 
    // amount within a ±2 minute window. We don't check exact merchant because
    // SMS and Notification text often parse merchants slightly differently.
    final twoMinsBefore = txnDate.subtract(const Duration(minutes: 2));
    final twoMinsAfter = txnDate.add(const Duration(minutes: 2));
    
    final duplicate = await (_db.select(_db.transactions)
          ..where((t) => t.amount.equals(amount))
          ..where((t) => t.isIncome.equals(isIncome))
          ..where((t) => t.txnDate.isBetweenValues(twoMinsBefore, twoMinsAfter))
          ..limit(1))
        .getSingleOrNull();
        
    if (duplicate != null) {
      // If both have a valid but DISTINCT upi_ref, they are genuine back-to-back payments.
      final hasDistinctRefs = trimmedRef != null && trimmedRef.isNotEmpty &&
          duplicate.upiRef != null && duplicate.upiRef!.isNotEmpty &&
          trimmedRef != duplicate.upiRef;
          
      if (!hasDistinctRefs) {
        return null; // Already captured via the other channel
      }
    }

    var categoryId = categorize(
      merchant: merchant,
      rules: await _db.select(_db.rules).get(),
    );
    // Income rows get the catch-all income category — "Other income", never
    // "Salary". A UPI credit (refund, cashback, a friend's money) is not a
    // salary payment; labeling it Salary would pollute income reports.
    if (isIncome) {
      final other = await (_db.select(_db.categories)
            ..where((c) => c.name.equals('Other income')))
          .getSingleOrNull();
      categoryId = other?.id;
    }

    // Get default wallet (if any)
    final defaultWallet = await (_db.select(_db.wallets)..limit(1)).getSingleOrNull();

    final id = await _db.into(_db.transactions).insert(
          TransactionsCompanion.insert(
            amount: amount,
            merchant: merchant.trim(),
            categoryId: Value(categoryId),
            walletId: Value(defaultWallet?.id),
            note: const Value(null),
            paymentMethod: 'upi',
            upiRef: Value(trimmedRef),
            source: 'notification',
            txnDate: txnDate,
            isIncome: Value(isIncome),
          ),
        );
        
    // Pennywise-style ground truth balance extraction:
    // If the SMS contained the true bank balance, we adjust the wallet's 
    // initialBalance so that the computed current balance exactly matches it.
    if (balance != null && defaultWallet != null) {
      final txns = await (_db.select(_db.transactions)
            ..where((t) => t.walletId.equals(defaultWallet.id)))
          .get();
      
      double sumTxns = 0.0;
      for (final t in txns) {
        sumTxns += t.isIncome ? t.amount : -t.amount;
      }
      
      // We want: initialBalance + sumTxns = balance
      // Therefore: initialBalance = balance - sumTxns
      final newInitial = balance - sumTxns;
      
      await (_db.update(_db.wallets)..where((w) => w.id.equals(defaultWallet.id)))
          .write(WalletsCompanion(initialBalance: Value(newInitial)));
    }

    final row = await (_db.select(_db.transactions)..where((t) => t.id.equals(id))).getSingle();
    return row;
  }

  /// Watches wallets for the picker + balance header.
  Stream<List<Wallet>> watchWallets() => _db.select(_db.wallets).watch();

  /// Creates a wallet.
  Future<Wallet> insertWallet({required String name, required String currency, double initialBalance = 0}) {
    return _db.into(_db.wallets).insertReturning(WalletsCompanion.insert(
          name: name,
          currency: currency,
          initialBalance: Value(initialBalance),
        ));
  }

  /// Renames a wallet / changes its currency. Marks it dirty for sync.
  Future<void> updateWallet(Wallet wallet) => _db.update(_db.wallets).replace(
        wallet.copyWith(dirty: true),
      );

  Future<void> deleteWallet(int id) async {
    // Null out wallet_id on its transactions so they don't disappear.
    await (_db.update(_db.transactions)..where((t) => t.walletId.equals(id)))
        .write(const TransactionsCompanion(walletId: Value(null)));
    final row = await (_db.select(_db.wallets)..where((w) => w.id.equals(id))).getSingleOrNull();
    if (row == null) return;
    await _deleteFeature('wallets', row.remoteId);
    await (_db.delete(_db.wallets)..where((w) => w.id.equals(id))).go();
  }

  /// Balance of a wallet in its own currency: income − expenses (amounts are
  /// stored positive, sign comes from is_income). Initial balance is added by
  /// the caller, so income raises the balance and a spend lowers it.
  Future<double> walletBalance(int walletId) async {
    final sum = _db.transactions.amount.sum();
    final spent = await (_db.selectOnly(_db.transactions)
          ..addColumns([sum])
          ..where(_db.transactions.walletId.equals(walletId) &
              _expenseOnly()))
        .getSingle();
    final earned = await (_db.selectOnly(_db.transactions)
          ..addColumns([sum])
          ..where(_db.transactions.walletId.equals(walletId) &
              _db.transactions.isIncome.equals(true)))
        .getSingle();
    return ((earned.read(sum) ?? 0) - (spent.read(sum) ?? 0)).toDouble();
  }

  /// Watches exchange rates.
  Stream<List<ExchangeRate>> watchExchangeRates() => _db.select(_db.exchangeRates).watch();

  /// Sets (or replaces) the manual rate fromCurrency → toCurrency.
  Future<void> setExchangeRate({required String from, required String to, required double rate}) async {
    if (rate <= 0) return;
    final existing = await (_db.select(_db.exchangeRates)
          ..where((e) => e.fromCurrency.equals(from) & e.toCurrency.equals(to)))
        .getSingleOrNull();
    if (existing == null) {
      await _db.into(_db.exchangeRates).insert(ExchangeRatesCompanion.insert(
            fromCurrency: from,
            toCurrency: to,
            rate: rate,
          ));
    } else {
      await (_db.update(_db.exchangeRates)..where((e) => e.id.equals(existing.id)))
          .write(ExchangeRatesCompanion(rate: Value(rate)));
    }
  }

  /// Converts [amount] from [from] to [to] using the manual rate (or 1:1 when
  /// the same currency / no rate stored).
  Future<double> convertCurrency(double amount, String from, String to) async {
    if (from == to) return amount;
    final rate = await (_db.select(_db.exchangeRates)
          ..where((e) => e.fromCurrency.equals(from) & e.toCurrency.equals(to)))
        .getSingleOrNull();
    return rate == null ? amount : amount * rate.rate;
  }

  /// Watches recurring subscriptions.
  Stream<List<RecurringTransaction>> watchRecurring() => _db.select(_db.recurringTransactions).watch();

  /// Adds a recurring subscription.
  Future<RecurringTransaction> insertRecurring({
    required String merchant,
    required double amount,
    int? categoryId,
    required String period,
    required DateTime nextDue,
  }) {
    return _db.into(_db.recurringTransactions).insertReturning(RecurringTransactionsCompanion.insert(
          merchant: merchant,
          amount: amount,
          categoryId: Value(categoryId),
          period: period,
          nextDue: nextDue,
        ));
  }

  /// Deletes a recurring subscription. If it was pushed, a tombstone records
  /// the remote row for deletion on the next sync (no server resurrection).
  Future<void> deleteRecurring(int id) async {
    final row = await (_db.select(_db.recurringTransactions)..where((r) => r.id.equals(id)))
        .getSingleOrNull();
    if (row == null) return;
    await _deleteFeature('recurring', row.remoteId);
    await (_db.delete(_db.recurringTransactions)..where((r) => r.id.equals(id))).go();
  }

  Future<void> setRecurringActive(int id, bool active) =>
      (_db.update(_db.recurringTransactions)..where((r) => r.id.equals(id)))
          .write(RecurringTransactionsCompanion(
        active: Value(active),
        dirty: const Value(true),
      ));

  /// Advances [r.nextDue] by one period after it has been paid, so the next
  /// due date rolls forward. Pure + unit-testable. Month-end dates clamp to
  /// the target month's last day (Jan 31 → Feb 28, not Mar 3) — Dart's
  /// DateTime otherwise normalizes 31-Feb to 3-Mar silently.
  static DateTime nextDueAfter(RecurringTransaction r, DateTime paidOn) {
    final base = paidOn.isAfter(r.nextDue) ? paidOn : r.nextDue;
    return switch (r.period) {
      'daily' => base.add(const Duration(days: 1)),
      'weekly' => base.add(const Duration(days: 7)),
      'monthly' => _nextMonthClamped(base),
      'yearly' => _nextYearClamped(base),
      _ => base.add(const Duration(days: 30)),
    };
  }

  static DateTime _nextMonthClamped(DateTime d) {
    final lastDay = DateTime(d.year, d.month + 2, 0).day;
    return DateTime(d.year, d.month + 1, d.day > lastDay ? lastDay : d.day);
  }

  static DateTime _nextYearClamped(DateTime d) {
    final lastDay = DateTime(d.year + 1, d.month + 1, 0).day;
    return DateTime(d.year + 1, d.month, d.day > lastDay ? lastDay : d.day);
  }

  /// Adds a due subscription as a transaction (source = manual) and rolls the
  /// next-due date forward. Returns the inserted transaction.
  Future<Transaction> payRecurring(RecurringTransaction r, {int? walletId, DateTime? on}) async {
    final paidOn = on ?? DateTime.now();
    final txn = await insertManual(
      amount: r.amount,
      merchant: r.merchant,
      categoryId: r.categoryId,
      paymentMethod: 'upi',
      txnDate: paidOn,
      walletId: walletId,
    );
    await (_db.update(_db.recurringTransactions)..where((x) => x.id.equals(r.id)))
        .write(RecurringTransactionsCompanion(
      nextDue: Value(nextDueAfter(r, paidOn)),
      dirty: const Value(true),
    ));
    return txn;
  }

  /// Watches savings goals.
  Stream<List<Objective>> watchObjectives() => _db.select(_db.objectives).watch();

  Future<Objective> insertObjective({
    required String name,
    required double target,
    double saved = 0,
    DateTime? deadline,
  }) {
    return _db.into(_db.objectives).insertReturning(ObjectivesCompanion.insert(
          name: name,
          target: target,
          saved: Value(saved),
          deadline: Value(deadline),
        ));
  }

  /// Adds [amount] to a goal's saved total (allocating saved money).
  Future<void> addToObjective(int id, double amount) async {
    if (amount <= 0) return;
    final o = await (_db.select(_db.objectives)..where((x) => x.id.equals(id))).getSingleOrNull();
    if (o == null) return;
    await (_db.update(_db.objectives)..where((x) => x.id.equals(id)))
        .write(ObjectivesCompanion(
      saved: Value(o.saved + amount),
      dirty: const Value(true),
    ));
  }

  Future<void> deleteObjective(int id) async {
    final row = await (_db.select(_db.objectives)..where((o) => o.id.equals(id))).getSingleOrNull();
    if (row == null) return;
    await _deleteFeature('objectives', row.remoteId);
    await (_db.delete(_db.objectives)..where((o) => o.id.equals(id))).go();
  }

  Stream<List<Debt>> watchDebts() => _db.select(_db.debts).watch();

  Future<void> insertDebt({required String name, required double amount, required bool isLent, String? note}) =>
      _db.into(_db.debts).insert(DebtsCompanion.insert(
        name: name,
        amount: amount,
        isLent: isLent,
        note: Value(note),
      ));

  Future<void> setDebtSettled(int id, bool settled) =>
      (_db.update(_db.debts)..where((d) => d.id.equals(id)))
          .write(DebtsCompanion(
        settled: Value(settled),
        dirty: const Value(true),
      ));

  Future<void> deleteDebt(int id) async {
    final row = await (_db.select(_db.debts)..where((d) => d.id.equals(id))).getSingleOrNull();
    if (row == null) return;
    await _deleteFeature('debts', row.remoteId);
    await (_db.delete(_db.debts)..where((d) => d.id.equals(id))).go();
  }

  /// Category id for [name], case-insensitive. Null when no match.
  Future<int?> categoryIdByName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return null;
    final row = await (_db.select(_db.categories)
          ..where((c) => c.name.lower().equals(trimmed.toLowerCase())))
        .getSingleOrNull();
    return row?.id;
  }

  /// Adds a custom category. New categories sort after all builtins.
  Future<int> insertCategory({
    required String name,
    required String emoji,
    required String color,
    bool isIncome = false,
  }) {
    final sortOrder = _db.selectOnly(_db.categories)
      ..addColumns([_db.categories.sortOrder.max()]);
    return _db.transaction(() async {
      final max = await sortOrder.map((r) => r.read(_db.categories.sortOrder.max())).getSingle();
      return (await _db.into(_db.categories).insertReturning(CategoriesCompanion.insert(
        name: name,
        emoji: emoji,
        color: color,
        isCustom: const Value(true),
        isIncome: Value(isIncome),
        sortOrder: Value((max ?? 0) + 1),
      ))).id;
    });
  }

  Future<void> updateCategory(int id, {required String name, required String emoji, required String color}) =>
      (_db.update(_db.categories)..where((c) => c.id.equals(id)))
          .write(CategoriesCompanion(
            name: Value(name),
            emoji: Value(emoji),
            color: Value(color),
            dirty: const Value(true), // edits re-push (custom cats only — builtins read-only)
          ));

  /// Finds category name by id.
  Future<String?> categoryNameById(int? id) async {
    if (id == null) return null;
    final row = await (_db.select(_db.categories)..where((c) => c.id.equals(id))).getSingleOrNull();
    return row?.name;
  }

  /// Deletes a category and detaches its transactions (they become uncategorized).
  /// Custom categories with a server mirror are tombstoned for remote delete;
  /// builtins are shared reference data and never pushed (no tombstone).
  Future<void> deleteCategory(int id) async {
    final row = await (_db.select(_db.categories)..where((c) => c.id.equals(id))).getSingleOrNull();
    if (row == null) return;
    await _db.transaction(() async {
      if (row.isCustom) {
        await _deleteFeature('categories', row.remoteId);
      }
      await (_db.update(_db.transactions)..where((t) => t.categoryId.equals(id)))
          .write(TransactionsCompanion(categoryId: const Value(null)));
      await (_db.delete(_db.categories)..where((c) => c.id.equals(id))).go();
    });
  }

  /// Inserts a row read from an import file (source = import).
  /// Returns null when a row with the same [upiRef] is already stored (dedupe).
  Future<Transaction?> insertImported({
    required double amount,
    required String merchant,
    int? categoryId,
    String? note,
    required String paymentMethod,
    required DateTime txnDate,
    String? upiRef,
    int? walletId,
    bool isIncome = false,
  }) async {
    final validation = validateManualTransaction(
      amount: amount,
      merchant: merchant,
      paymentMethod: paymentMethod,
    );
    if (validation != null) throw TransactionValidationException(validation);

    final trimmedRef = upiRef?.trim();
    if (trimmedRef != null && trimmedRef.isNotEmpty && await existsUpiRef(trimmedRef)) {
      return null; // duplicate import
    }

    final id = await _db.into(_db.transactions).insert(
          TransactionsCompanion.insert(
            amount: amount,
            merchant: merchant.trim(),
            categoryId: Value(categoryId),
            walletId: Value(walletId),
            note: Value(note?.trim().isEmpty ?? true ? null : note!.trim()),
            paymentMethod: paymentMethod,
            upiRef: Value(trimmedRef),
            source: 'import',
            txnDate: txnDate,
            isIncome: Value(isIncome),
          ),
        );
    final row = await (_db.select(_db.transactions)..where((t) => t.id.equals(id))).getSingle();
    return row;
  }

  /// [Expression] that matches expense rows. Spend aggregates are expense-only;
  /// income is tracked separately so it never inflates "how much did I spend".
  Expression<bool> _expenseOnly() => _db.transactions.isIncome.equals(false);

  /// Total spent on [day] (local calendar day). 0 when none. Expense-only.
  Future<double> dayTotal(DateTime day) {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    final sum = _db.transactions.amount.sum();
    final query = _db.selectOnly(_db.transactions)
      ..addColumns([sum])
      ..where(_db.transactions.txnDate.isBiggerOrEqualValue(start) &
          _db.transactions.txnDate.isSmallerThanValue(end) &
          _expenseOnly());
    return query.getSingle().then((row) => row.read(sum) ?? 0);
  }

  /// Total income on [day] (local calendar day). 0 when none.
  Future<double> dayIncome(DateTime day) {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    final sum = _db.transactions.amount.sum();
    final query = _db.selectOnly(_db.transactions)
      ..addColumns([sum])
      ..where(_db.transactions.txnDate.isBiggerOrEqualValue(start) &
          _db.transactions.txnDate.isSmallerThanValue(end) &
          _db.transactions.isIncome.equals(true));
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
          _db.transactions.txnDate.isSmallerThanValue(endExclusive) &
          _expenseOnly());
    return query.getSingle().then((row) => row.read(sum) ?? 0);
  }

  /// Total income in [month] (local). 0 when none.
  Future<double> monthIncome(DateTime month) {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);
    final sum = _db.transactions.amount.sum();
    final q = _db.selectOnly(_db.transactions)
      ..addColumns([sum])
      ..where(_db.transactions.txnDate.isBiggerOrEqualValue(start) &
          _db.transactions.txnDate.isSmallerThanValue(end) &
          _db.transactions.isIncome.equals(true));
    return q.getSingle().then((row) => row.read(sum) ?? 0);
  }

  /// Heatmap data: total spend per day for the last [days].
  Future<Map<DateTime, double>> spendingHeatmap(DateTime today, {int days = 140}) async {
    final start = DateTime(today.year, today.month, today.day).subtract(Duration(days: days - 1));
    final endExclusive = DateTime(today.year, today.month, today.day).add(const Duration(days: 1));
    
    // We fetch raw rows because Drift doesn't support grouping by a date-casted column out-of-the-box easily without custom expressions.
    final rows = await (_db.select(_db.transactions)
          ..where((t) => t.txnDate.isBiggerOrEqualValue(start) & t.txnDate.isSmallerThanValue(endExclusive) & _expenseOnly()))
        .get();
        
    final Map<DateTime, double> map = {};
    for (final t in rows) {
      final date = DateTime(t.txnDate.year, t.txnDate.month, t.txnDate.day);
      map[date] = (map[date] ?? 0) + t.amount;
    }
    return map;
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
          _db.transactions.txnDate.isSmallerThanValue(endExclusive) &
          _expenseOnly());
    final perCategory = <String, double>{};
    for (final r in await rows.get()) {
      final name = r.readTable(_db.categories).name;
      perCategory[name] = (perCategory[name] ?? 0) + r.readTable(_db.transactions).amount;
    }
    final ranked = perCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return ranked.take(n).map((e) => (e.key, e.value)).toList();
  }

  /// Total spent in [month] (local). Expense-only.
  Future<double> monthTotal(DateTime month) {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);
    final sum = _db.transactions.amount.sum();
    final q = _db.selectOnly(_db.transactions)
      ..addColumns([sum])
      ..where(_db.transactions.txnDate.isBiggerOrEqualValue(start) &
          _db.transactions.txnDate.isSmallerThanValue(end) &
          _expenseOnly());
    return q.getSingle().then((row) => row.read(sum) ?? 0);
  }

  /// Spend per category in [month], largest first. Uncategorized excluded.
  /// Expense-only — income never counts toward category spend.
  Future<List<(Category, double)>> monthSpendByCategory(DateTime month) async {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);
    final rows = _db.select(_db.transactions).join([
      leftOuterJoin(_db.categories, _db.categories.id.equalsExp(_db.transactions.categoryId)),
    ])
      ..where(_db.transactions.txnDate.isBiggerOrEqualValue(start) &
          _db.transactions.txnDate.isSmallerThanValue(end) &
          _expenseOnly());
    final per = <int, (Category, double)>{};
    var uncategorizedTotal = 0.0;
    for (final r in await rows.get()) {
      final cat = r.readTableOrNull(_db.categories);
      final amount = r.readTable(_db.transactions).amount;
      if (cat != null) {
        per.update(cat.id, (v) => (v.$1, v.$2 + amount), ifAbsent: () => (cat, amount));
      } else {
        uncategorizedTotal += amount;
      }
    }
    final list = per.values.toList();
    if (uncategorizedTotal > 0) {
      const uncat = Category(
        id: -1,
        name: 'Uncategorized',
        emoji: '📦',
        color: '#8D99AE',
        isCustom: false,
        sortOrder: 999,
        isIncome: false,
        dirty: false,
      );
      list.add((uncat, uncategorizedTotal));
    }
    list.sort((a, b) => b.$2.compareTo(a.$2));
    return list;
  }

  /// Spend per calendar month over the last [months] months ending at
  /// [end], oldest first. Returns (monthLabel, total) — for the trend chart.
  Future<List<(String, double)>> monthlyTrend(DateTime end, {int months = 6}) async {
    // Scan newest-first, stop once we've covered [months] distinct months.
    final rows = await (_db.select(_db.transactions)
          ..where((t) => t.isIncome.equals(false))
          ..orderBy([(t) => OrderingTerm.desc(t.txnDate)]))
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
    final amountSum = _db.transactions.amount.sum();
    final count = _db.transactions.id.count();
    final query = _db.selectOnly(_db.transactions)
      ..addColumns([_db.transactions.merchant, amountSum, count])
      ..where(_db.transactions.isIncome.equals(false))
      ..groupBy([_db.transactions.merchant])
      ..orderBy([OrderingTerm.desc(amountSum)])
      ..limit(n);
      
    final rows = await query.get();
    return rows.map((r) => (
      r.read(_db.transactions.merchant)!,
      r.read(amountSum) ?? 0.0,
      r.read(count) ?? 0,
    )).toList();
  }

  /// Total spent per payment method, largest first.
  Future<List<(String, double, int)>> paymentMethodTotals() async {
    final amountSum = _db.transactions.amount.sum();
    final count = _db.transactions.id.count();
    final query = _db.selectOnly(_db.transactions)
      ..addColumns([_db.transactions.paymentMethod, amountSum, count])
      ..where(_db.transactions.isIncome.equals(false))
      ..groupBy([_db.transactions.paymentMethod])
      ..orderBy([OrderingTerm.desc(amountSum)]);
      
    final rows = await query.get();
    return rows.map((r) => (
      r.read(_db.transactions.paymentMethod)!,
      r.read(amountSum) ?? 0.0,
      r.read(count) ?? 0,
    )).toList();
  }

  /// (rows pushed to Supabase, rows pending push). Feature rows (budgets,
  /// wallets, recurring, objectives, debts) count as pending until synced.
  Future<(int, int)> syncStatus() async {
    final pendingCountExp = _db.transactions.id.count();
    final pending = (await (_db.selectOnly(_db.transactions)
          ..addColumns([pendingCountExp])
          ..where(_db.transactions.dirty.equals(true)))
        .getSingle()).read(pendingCountExp) ?? 0;
        
    final syncedCountExp = _db.transactions.id.count();
    final synced = (await (_db.selectOnly(_db.transactions)
          ..addColumns([syncedCountExp])
          ..where(_db.transactions.dirty.equals(false)))
        .getSingle()).read(syncedCountExp) ?? 0;

    return (synced + (await _featureRowsSynced()), pending + (await featureRowsPending()));
  }

  /// Synced feature rows (remoteId != null) — for the profile backup line.
  Future<int> _featureRowsSynced() async {
    var synced = 0;
    synced += (await _db.select(_db.budgets).get()).where((b) => b.remoteId != null).length;
    synced += (await _db.select(_db.wallets).get()).where((w) => w.remoteId != null).length;
    synced += (await _db.select(_db.recurringTransactions).get()).where((r) => r.remoteId != null).length;
    synced += (await _db.select(_db.objectives).get()).where((o) => o.remoteId != null).length;
    synced += (await _db.select(_db.debts).get()).where((d) => d.remoteId != null).length;
    return synced;
  }

  /// Total unsynced feature rows (budgets, wallets, recurring, objectives,
  /// debts) — for the profile backup line.
  Future<int> featureRowsPending() async {
    var pending = 0;
    pending += (await _db.select(_db.budgets).get()).where((b) => b.dirty).length;
    pending += (await _db.select(_db.wallets).get()).where((w) => w.dirty).length;
    pending += (await _db.select(_db.recurringTransactions).get()).where((r) => r.dirty).length;
    pending += (await _db.select(_db.objectives).get()).where((o) => o.dirty).length;
    pending += (await _db.select(_db.debts).get()).where((d) => d.dirty).length;
    return pending;
  }

  /// Dirty feature rows of [kind] — the SyncEngine pushes these.
  Future<List<dynamic>> dirtyRowsFor(SyncKind kind) {
    switch (kind) {
      case SyncKind.budgets:
        return (_db.select(_db.budgets)..where((b) => b.dirty.equals(true))).get();
      case SyncKind.wallets:
        return (_db.select(_db.wallets)..where((w) => w.dirty.equals(true))).get();
      case SyncKind.recurring:
        return (_db.select(_db.recurringTransactions)..where((r) => r.dirty.equals(true))).get();
      case SyncKind.objectives:
        return (_db.select(_db.objectives)..where((o) => o.dirty.equals(true))).get();
      case SyncKind.debts:
        return (_db.select(_db.debts)..where((d) => d.dirty.equals(true))).get();
    }
  }

  /// Marks a feature row synced (or dirty when [dirty]).
  Future<void> markFeatureSynced(SyncKind kind, int id, int remoteId, {bool dirty = false}) async {
    switch (kind) {
      case SyncKind.budgets:
        await (_db.update(_db.budgets)..where((b) => b.id.equals(id)))
            .write(BudgetsCompanion(remoteId: Value(remoteId), dirty: Value(dirty)));
      case SyncKind.wallets:
        await (_db.update(_db.wallets)..where((w) => w.id.equals(id)))
            .write(WalletsCompanion(remoteId: Value(remoteId), dirty: Value(dirty)));
      case SyncKind.recurring:
        await (_db.update(_db.recurringTransactions)..where((r) => r.id.equals(id)))
            .write(RecurringTransactionsCompanion(remoteId: Value(remoteId), dirty: Value(dirty)));
      case SyncKind.objectives:
        await (_db.update(_db.objectives)..where((o) => o.id.equals(id)))
            .write(ObjectivesCompanion(remoteId: Value(remoteId), dirty: Value(dirty)));
      case SyncKind.debts:
        await (_db.update(_db.debts)..where((d) => d.id.equals(id)))
            .write(DebtsCompanion(remoteId: Value(remoteId), dirty: Value(dirty)));
    }
  }

  /// Custom categories pending push. Builtins are shared reference data
  /// (seeded identically everywhere) — never pushed.
  Future<List<Category>> dirtyCustomCategories() {
    return (_db.select(_db.categories)
          ..where((c) => c.isCustom.equals(true) & c.dirty.equals(true)))
        .get();
  }

  /// Marks [id] pushed: server id recorded, no longer dirty.
  Future<void> markCategorySynced(int id, int remoteId) =>
      (_db.update(_db.categories)..where((c) => c.id.equals(id)))
          .write(CategoriesCompanion(dirty: const Value(false), remoteId: Value(remoteId)));

  /// Local category id → server id. Null for builtins (shared, same id on
  /// both sides — caller uses the local id directly) or unsynced customs.
  Future<int?> categoryRemoteId(int localCategoryId) async {
    final c = await (_db.select(_db.categories)..where((x) => x.id.equals(localCategoryId)))
        .getSingleOrNull();
    return (c == null || !c.isCustom) ? null : c.remoteId;
  }

  /// Server category id → local custom category id. Null when no local custom
  /// has that remote id (builtins share ids — caller keeps the raw id).
  Future<int?> categoryLocalId(int remoteCategoryId) async {
    final c = await (_db.select(_db.categories)..where((x) => x.remoteId.equals(remoteCategoryId)))
        .getSingleOrNull();
    return c?.id;
  }

  Future<Category?> findCategoryByRemoteId(int remoteId) =>
      (_db.select(_db.categories)..where((c) => c.remoteId.equals(remoteId))).getSingleOrNull();

  Future<void> insertCategoryFromRemote(Map<String, Object?> map) =>
      _db.into(_db.categories).insert(CategoriesCompanion(
            id: Value(map['id']! as int),
            name: Value(map['name']! as String),
            emoji: Value(map['emoji']! as String),
            color: Value(map['color']! as String),
            isCustom: Value(map['isCustom']! as bool),
            sortOrder: Value(map['sortOrder']! as int),
            isIncome: Value(map['isIncome']! as bool),
            dirty: const Value(false),
            remoteId: Value(map['id']! as int),
          ));

  Future<void> updateCategoryFromRemote(int localId, Map<String, Object?> map) =>
      (_db.update(_db.categories)..where((c) => c.id.equals(localId))).write(CategoriesCompanion(
            name: Value(map['name']! as String),
            emoji: Value(map['emoji']! as String),
            color: Value(map['color']! as String),
            sortOrder: Value(map['sortOrder']! as int),
            dirty: const Value(false),
            remoteId: Value(map['id']! as int),
          ));

  /// A remote feature row → local payload. [SyncKind] chooses the table.
  ///
  /// categoryId null → custom category (no server mirror); the row is skipped
  /// by the engine before this is reached. updatedAt defaults to now for
  /// tables without an updated_at column (wallets/recurring/objectives/debts).
  Map<String, Object?> featureToLocalMap(SyncKind kind, Map<String, dynamic> r) {
    switch (kind) {
      case SyncKind.budgets:
        return {
          'id': r['id'],
          'categoryId': r['category_id'],
          'amount': parseAmount(r['amount']?.toString()) ?? 0.0,
          'period': r['period'],
          'alertPct50': r['alert_pct_50'] ?? 50,
          'alertPct80': r['alert_pct_80'] ?? 80,
          'alertPct100': r['alert_pct_100'] ?? 100,
          'updatedAt': r['updated_at'] == null
              ? DateTime.now()
              : DateTime.parse(r['updated_at'] as String).toLocal(),
          'dirty': false,
          'remoteId': r['id'],
        };
      case SyncKind.wallets:
        return {
          'id': r['id'],
          'name': r['name'],
          'currency': r['currency'],
          'initialBalance': parseAmount(r['initial_balance']?.toString()) ?? 0.0,
          'createdAt': DateTime.parse(r['created_at'] as String).toLocal(),
          'dirty': false,
          'remoteId': r['id'],
        };
      case SyncKind.recurring:
        return {
          'id': r['id'],
          'merchant': r['merchant'],
          'amount': parseAmount(r['amount']?.toString()) ?? 0.0,
          'categoryId': r['category_id'],
          'period': r['period'],
          'nextDue': DateTime.parse(r['next_due'] as String).toLocal(),
          'active': r['active'] ?? true,
          'dirty': false,
          'remoteId': r['id'],
        };
      case SyncKind.objectives:
        return {
          'id': r['id'],
          'name': r['name'],
          'target': parseAmount(r['target']?.toString()) ?? 0.0,
          'saved': parseAmount(r['saved']?.toString()) ?? 0.0,
          'deadline': r['deadline'] == null ? null : DateTime.parse(r['deadline'] as String).toLocal(),
          'dirty': false,
          'remoteId': r['id'],
        };
      case SyncKind.debts:
        return {
          'id': r['id'],
          'name': r['name'],
          'amount': parseAmount(r['amount']?.toString()) ?? 0.0,
          'isLent': r['is_lent'] ?? false,
          'note': r['note'],
          'settled': r['settled'] ?? false,
          'createdAt': DateTime.parse(r['created_at'] as String).toLocal(),
          'dirty': false,
          'remoteId': r['id'],
        };
    }
  }

  /// Local feature row by its remote id, or null when not stored yet.
  Future<dynamic> findFeatureByRemoteId(SyncKind kind, int remoteId) {
    switch (kind) {
      case SyncKind.budgets:
        return (_db.select(_db.budgets)..where((b) => b.remoteId.equals(remoteId))).getSingleOrNull();
      case SyncKind.wallets:
        return (_db.select(_db.wallets)..where((w) => w.remoteId.equals(remoteId))).getSingleOrNull();
      case SyncKind.recurring:
        return (_db.select(_db.recurringTransactions)..where((r) => r.remoteId.equals(remoteId))).getSingleOrNull();
      case SyncKind.objectives:
        return (_db.select(_db.objectives)..where((o) => o.remoteId.equals(remoteId))).getSingleOrNull();
      case SyncKind.debts:
        return (_db.select(_db.debts)..where((d) => d.remoteId.equals(remoteId))).getSingleOrNull();
    }
  }

  /// Inserts a remote feature row locally with [map] (column-name → value,
  /// local id = remote id, dirty=false). Only reached when the remote
  /// category_id maps to a local category (custom-category rows skipped).
  Future<void> insertFeatureFromRemote(SyncKind kind, Map<String, Object?> map) {
    switch (kind) {
      case SyncKind.budgets:
        return _db.into(_db.budgets).insert(BudgetsCompanion(
              id: Value(map['id']! as int),
              categoryId: Value(map['categoryId']! as int),
              amount: Value(map['amount']! as double),
              period: Value(map['period']! as String),
              alertPct50: Value(map['alertPct50']! as int),
              alertPct80: Value(map['alertPct80']! as int),
              alertPct100: Value(map['alertPct100']! as int),
              updatedAt: Value(map['updatedAt']! as DateTime),
              dirty: const Value(false),
              remoteId: Value(map['remoteId']! as int),
            ));
      case SyncKind.wallets:
        return _db.into(_db.wallets).insert(WalletsCompanion(
              id: Value(map['id']! as int),
              name: Value(map['name']! as String),
              currency: Value(map['currency']! as String),
              initialBalance: Value(map['initialBalance']! as double),
              createdAt: Value(map['createdAt']! as DateTime),
              dirty: const Value(false),
              remoteId: Value(map['remoteId']! as int),
            ));
      case SyncKind.recurring:
        return _db.into(_db.recurringTransactions).insert(RecurringTransactionsCompanion(
              id: Value(map['id']! as int),
              merchant: Value(map['merchant']! as String),
              amount: Value(map['amount']! as double),
              categoryId: Value(map['categoryId'] as int?),
              period: Value(map['period']! as String),
              nextDue: Value(map['nextDue']! as DateTime),
              active: Value(map['active']! as bool),
              dirty: const Value(false),
              remoteId: Value(map['remoteId']! as int),
            ));
      case SyncKind.objectives:
        return _db.into(_db.objectives).insert(ObjectivesCompanion(
              id: Value(map['id']! as int),
              name: Value(map['name']! as String),
              target: Value(map['target']! as double),
              saved: Value(map['saved']! as double),
              deadline: Value(map['deadline'] as DateTime?),
              dirty: const Value(false),
              remoteId: Value(map['remoteId']! as int),
            ));
      case SyncKind.debts:
        return _db.into(_db.debts).insert(DebtsCompanion(
              id: Value(map['id']! as int),
              name: Value(map['name']! as String),
              amount: Value(map['amount']! as double),
              isLent: Value(map['isLent']! as bool),
              note: Value(map['note'] as String?),
              settled: Value(map['settled']! as bool),
              createdAt: Value(map['createdAt']! as DateTime),
              dirty: const Value(false),
              remoteId: Value(map['remoteId']! as int),
            ));
    }
  }

  /// Overwrites local feature row [localId] with remote [map]. Only reached
  /// when the row is converged or remote-owned (local not dirty).
  Future<void> updateFeatureFromRemote(SyncKind kind, int localId, Map<String, Object?> map) {
    switch (kind) {
      case SyncKind.budgets:
        return (_db.update(_db.budgets)..where((b) => b.id.equals(localId))).write(BudgetsCompanion(
              amount: Value(map['amount']! as double),
              period: Value(map['period']! as String),
              alertPct50: Value(map['alertPct50']! as int),
              alertPct80: Value(map['alertPct80']! as int),
              alertPct100: Value(map['alertPct100']! as int),
              updatedAt: Value(map['updatedAt']! as DateTime),
              dirty: const Value(false),
              remoteId: Value(map['remoteId']! as int),
            ));
      case SyncKind.wallets:
        return (_db.update(_db.wallets)..where((w) => w.id.equals(localId))).write(WalletsCompanion(
              name: Value(map['name']! as String),
              currency: Value(map['currency']! as String),
              initialBalance: Value(map['initialBalance']! as double),
              dirty: const Value(false),
              remoteId: Value(map['remoteId']! as int),
            ));
      case SyncKind.recurring:
        return (_db.update(_db.recurringTransactions)..where((r) => r.id.equals(localId))).write(RecurringTransactionsCompanion(
              merchant: Value(map['merchant']! as String),
              amount: Value(map['amount']! as double),
              categoryId: Value(map['categoryId'] as int?),
              period: Value(map['period']! as String),
              nextDue: Value(map['nextDue']! as DateTime),
              active: Value(map['active']! as bool),
              dirty: const Value(false),
              remoteId: Value(map['remoteId']! as int),
            ));
      case SyncKind.objectives:
        return (_db.update(_db.objectives)..where((o) => o.id.equals(localId))).write(ObjectivesCompanion(
              name: Value(map['name']! as String),
              target: Value(map['target']! as double),
              saved: Value(map['saved']! as double),
              deadline: Value(map['deadline'] as DateTime?),
              dirty: const Value(false),
              remoteId: Value(map['remoteId']! as int),
            ));
      case SyncKind.debts:
        return (_db.update(_db.debts)..where((d) => d.id.equals(localId))).write(DebtsCompanion(
              name: Value(map['name']! as String),
              amount: Value(map['amount']! as double),
              isLent: Value(map['isLent']! as bool),
              note: Value(map['note'] as String?),
              settled: Value(map['settled']! as bool),
              dirty: const Value(false),
              remoteId: Value(map['remoteId']! as int),
            ));
    }
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

  /// Creates or updates the monthly budget for [categoryId]. Marks it dirty.
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
          .write(BudgetsCompanion(
        amount: Value(amount),
        updatedAt: Value(DateTime.now()),
        dirty: const Value(true),
      ));
    }
  }

  Future<void> deleteBudget(int id) async {
    final row = await (_db.select(_db.budgets)..where((b) => b.id.equals(id))).getSingleOrNull();
    if (row == null) return;
    await _deleteFeature('budgets', row.remoteId);
    await (_db.delete(_db.budgets)..where((b) => b.id.equals(id))).go();
  }

  /// Checks if [categoryId] has an active budget and returns its budget status:
  /// (categoryName, spentSoFar, budgetAmount, pct)
  Future<(String, double, double, int)?> checkCategoryBudgetStatus(int categoryId, DateTime date) async {
    final b = await (_db.select(_db.budgets)..where((b) => b.categoryId.equals(categoryId))).getSingleOrNull();
    if (b == null || b.amount <= 0) return null;

    final cat = await (_db.select(_db.categories)..where((c) => c.id.equals(categoryId))).getSingleOrNull();
    if (cat == null) return null;

    final startOfMonth = DateTime(date.year, date.month, 1);
    final endOfMonth = DateTime(date.year, date.month + 1, 1);

    final txns = await (_db.select(_db.transactions)
          ..where((t) =>
              t.categoryId.equals(categoryId) &
              t.isIncome.equals(false) &
              t.txnDate.isBiggerOrEqualValue(startOfMonth) &
              t.txnDate.isSmallerThanValue(endOfMonth)))
        .get();

    final spent = txns.fold(0.0, (s, t) => s + t.amount);
    final pct = ((spent / b.amount) * 100).round();
    return (cat.name, spent, b.amount, pct);
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

  /// Edits an existing transaction. Marks it dirty so the next push
  /// overwrites the remote row. Used by the edit flow on the transactions tab.
  Future<void> updateTransaction({
    required int id,
    required double amount,
    required String merchant,
    int? categoryId,
    String note = '',
    String paymentMethod = 'upi',
    DateTime? txnDate,
    bool isIncome = false,
  }) {
    return (_db.update(_db.transactions)..where((t) => t.id.equals(id))).write(
      TransactionsCompanion(
        amount: Value(amount),
        merchant: Value(merchant.trim()),
        categoryId: Value(categoryId),
        note: Value(note.trim().isEmpty ? null : note.trim()),
        paymentMethod: Value(paymentMethod),
        txnDate: Value(txnDate ?? DateTime.now()),
        isIncome: Value(isIncome),
        dirty: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Local delete of a transaction. If it was already pushed (has a remote_id),
  /// a tombstone records the remote row for deletion on the next sync — this
  /// keeps a stale pull from resurrecting the row. Unsynced rows just vanish.
  Future<void> deleteTransaction(int id) async {
    final row = await (_db.select(_db.transactions)..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) return;
    await _db.transaction(() async {
      if (row.remoteId != null) {
        await _db.into(_db.deletedTransactions).insert(
          DeletedTransactionsCompanion.insert(remoteId: row.remoteId!),
        );
      }
      await (_db.delete(_db.transactions)..where((t) => t.id.equals(id))).go();
    });
  }

  /// Tombstone remote ids that still need deleting on Supabase.
  Future<List<int>> deletedRemoteIds() {
    return _db.select(_db.deletedTransactions).get().then(
          (rows) => [for (final r in rows) r.remoteId],
        );
  }

  /// Clears a tombstone once its remote row is deleted (or gone).
  Future<void> clearDeletedRow(int remoteId) {
    return (_db.delete(_db.deletedTransactions)..where((t) => t.remoteId.equals(remoteId))).go();
  }

  /// Writes a feature-delete tombstone. [remoteId] null = row was never pushed
  /// (no server copy to delete) — the local delete is enough.
  Future<void> _deleteFeature(String kind, int? remoteId) async {
    if (remoteId == null) return;
    await _db.into(_db.deletedFeatures).insert(
      DeletedFeaturesCompanion.insert(kind: kind, remoteId: remoteId),
    );
  }

  /// Feature deletes still pending on Supabase, oldest first.
  Future<List<FeatureDelete>> deletedFeatureRemoteIds() async {
    final rows = await (_db.select(_db.deletedFeatures)
          ..orderBy([(f) => OrderingTerm.asc(f.id)]))
        .get();
    return [for (final r in rows) FeatureDelete(kind: r.kind, remoteId: r.remoteId)];
  }

  /// Clears a feature-delete tombstone once its remote row is deleted.
  Future<void> clearDeletedFeature(String kind, int remoteId) {
    return (_db.delete(_db.deletedFeatures)
          ..where((f) => f.kind.equals(kind) & f.remoteId.equals(remoteId)))
        .go();
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
    if (local.updatedAt.isAfter(r.updatedAt)) {
      // Local is strictly newer. Claim the remote id so a duplicate is never
      // inserted, but stay dirty so the next push overwrites the remote copy.
      await markSynced(local.id, r.id!, dirty: true);
      return local;
    }
    if (local.updatedAt.isBefore(r.updatedAt)) {
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
          isIncome: Value(r.isIncome),
          updatedAt: Value(r.updatedAt),
          remoteId: Value(r.id),
          dirty: const Value(false),
        ),
      );
      return (_db.select(_db.transactions)..where((t) => t.id.equals(local.id))).getSingle();
    }
    // Equal timestamps → already converged. Claim the remote id and go clean;
    // marking equal rows dirty re-pushed them on every sync forever.
    await markSynced(local.id, r.id!);
    return local;
  }

  /// A remote row we've never seen → insert a local copy. Categorization is
  /// derived locally from rules (the remote stores no per-user category id).
  Future<Transaction> _insertFromRemote(RemoteTransaction r) async {
    // Income never auto-categorizes from expense rules.
    final categoryId = r.isIncome
        ? null
        : categorize(
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
            isIncome: Value(r.isIncome),
            txnDate: r.txnDate,
            updatedAt: Value(r.updatedAt),
            dirty: const Value(false),
            remoteId: Value(r.id),
          ),
        );
    return (_db.select(_db.transactions)..where((t) => t.id.equals(id))).getSingle();
  }

  static const paymentMethods = ['cash', 'upi', 'card', 'wallet'];

  /// Pennywise-style Income Autopay / Auto-Subscription execution
  /// Materializes any active recurring transaction whose nextDue date has arrived.
  /// Advances the nextDue date based on the period.
  Future<void> processAutopay() async {
    final now = DateTime.now();
    final due = await (_db.select(_db.recurringTransactions)
          ..where((r) => r.active.equals(true) & r.nextDue.isSmallerOrEqualValue(now)))
        .get();

    for (final r in due) {
      await insertManual(
        amount: r.amount,
        merchant: r.merchant,
        categoryId: r.categoryId,
        paymentMethod: 'upi',
        txnDate: r.nextDue,
        isIncome: false,
      );

      // Advance date
      DateTime next;
      switch (r.period) {
        case 'daily':
          next = r.nextDue.add(const Duration(days: 1));
          break;
        case 'weekly':
          next = r.nextDue.add(const Duration(days: 7));
          break;
        case 'yearly':
          next = DateTime(r.nextDue.year + 1, r.nextDue.month, r.nextDue.day);
          break;
        case 'monthly':
        default:
          next = DateTime(r.nextDue.year, r.nextDue.month + 1, r.nextDue.day);
      }

      await (_db.update(_db.recurringTransactions)..where((t) => t.id.equals(r.id))).write(
        RecurringTransactionsCompanion(nextDue: Value(next), dirty: const Value(true)),
      );
    }
  }

  /// Watch rules for the Rules UI
  Stream<List<Rule>> watchRules() => _db.select(_db.rules).watch();

  Future<void> insertRule(String pattern, int categoryId) async {
    await _db.into(_db.rules).insert(
      RulesCompanion.insert(
        pattern: pattern,
        categoryId: categoryId,
        type: 'learned',
      ),
    );
  }

  Future<void> deleteRule(int id) async {
    await (_db.delete(_db.rules)..where((r) => r.id.equals(id))).go();
  }
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
