import 'database.dart';

/// Which feature table a SyncEngine batch covers. Categories are shared
/// reference data (no per-user rows); exchange rates are derived from user
/// wallets, not stored separately.
enum SyncKind { budgets, wallets, recurring, objectives, debts }

/// Supabase table name for [kind].
String featureTableFor(SyncKind kind) => switch (kind) {
      SyncKind.budgets => 'budgets',
      SyncKind.wallets => 'wallets',
      SyncKind.recurring => 'recurring_transactions',
      SyncKind.objectives => 'objectives',
      SyncKind.debts => 'debts',
    };

/// A custom category as stored on Supabase (user-scoped). Builtins are shared
/// reference data (seeded everywhere) and never sent. The server id is read
/// back after insert — local id ≠ server id, so budgets/recurring translate
/// category_id through remoteId.
Map<String, dynamic> customCategoryToRemoteJson(Category c, String userId) => {
      'user_id': userId,
      'name': c.name,
      'emoji': c.emoji,
      'color': c.color,
      'is_custom': true,
      'sort_order': c.sortOrder,
      'is_income': c.isIncome,
    };

/// Local feature row → Supabase payload (snake_case, user-scoped). The local
/// `id` is omitted — remote identity is the identity column. Local-only rows
/// (custom categories) are filtered by the engine before this is reached.
Map<String, dynamic> localToRemoteFeatureJson(SyncKind kind, dynamic row, String userId) {
  switch (kind) {
    case SyncKind.budgets:
      final b = row as Budget;
      return {
        'user_id': userId,
        'category_id': b.categoryId,
        'amount': b.amount,
        'period': b.period,
        'alert_pct_50': b.alertPct50,
        'alert_pct_80': b.alertPct80,
        'alert_pct_100': b.alertPct100,
        'updated_at': b.updatedAt.toUtc().toIso8601String(),
      };
    case SyncKind.wallets:
      final w = row as Wallet;
      return {
        'user_id': userId,
        'name': w.name,
        'currency': w.currency,
        'initial_balance': w.initialBalance,
        'account_mask': w.accountMask,
        'bank_name': w.bankName,
        'latest_sms_balance': w.latestSmsBalance,
        'created_at': w.createdAt.toUtc().toIso8601String(),
      };
    case SyncKind.recurring:
      final r = row as RecurringTransaction;
      return {
        'user_id': userId,
        'merchant': r.merchant,
        'amount': r.amount,
        'category_id': r.categoryId,
        'period': r.period,
        'next_due': r.nextDue.toUtc().toIso8601String(),
        'active': r.active,
      };
    case SyncKind.objectives:
      final o = row as Objective;
      return {
        'user_id': userId,
        'name': o.name,
        'target': o.target,
        'saved': o.saved,
        'deadline': o.deadline?.toUtc().toIso8601String(),
      };
    case SyncKind.debts:
      final d = row as Debt;
      return {
        'user_id': userId,
        'name': d.name,
        'amount': d.amount,
        'is_lent': d.isLent,
        'note': d.note,
        'settled': d.settled,
        'created_at': d.createdAt.toUtc().toIso8601String(),
      };
  }
}
