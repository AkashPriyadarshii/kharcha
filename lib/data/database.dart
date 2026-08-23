import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:io';

part 'database.g.dart';

/// Categories mirror the Supabase `categories` table.
class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 40)();
  TextColumn get emoji => text().withLength(min: 1, max: 8)();
  TextColumn get color => text().withLength(min: 7, max: 9)(); // #RRGGBB
  BoolColumn get isCustom => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  /// Income category (Salary, Bonus…) — only offered when adding income.
  BoolColumn get isIncome => boolean().withDefault(const Constant(false))();
  /// Sync state (schema v10): custom categories push to Supabase (server id
  /// differs from local → remoteId); builtins are shared reference data and
  /// never pushed (seeded identically on every device + server).
  BoolColumn get dirty => boolean().withDefault(const Constant(true))();
  IntColumn get remoteId => integer().nullable()();
}

/// Merchants: normalized name + default category.
class Merchants extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 80)();
  IntColumn get categoryId => integer().nullable().references(Categories, #id)();
  TextColumn get icon => text().withLength(min: 0, max: 4).nullable()();
}

/// Rules: keyword → category. type = builtin | learned.
class Rules extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get pattern => text().withLength(min: 1, max: 80)();
  IntColumn get categoryId => integer().references(Categories, #id)();
  TextColumn get type => text().withLength(min: 1, max: 16)(); // builtin | learned
}

/// Wallets: separate balances + per-wallet currency (offline-first; exchange
/// rates are manual). v0.1.1. Synced to Supabase (schema v9).
class Wallets extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 40)();
  TextColumn get currency => text().withLength(min: 3, max: 3)(); // ISO 4217
  /// Opening balance (positive = money already in the wallet before tracking).
  RealColumn get initialBalance => real().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get dirty => boolean().withDefault(const Constant(true))();
  IntColumn get remoteId => integer().nullable()();
}

/// Manual exchange rates (ISO → ISO), used to convert wallet balances to the
/// app's display currency. Offline-first; user-maintained, no live fetch.
class ExchangeRates extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get fromCurrency => text().withLength(min: 3, max: 3)();
  TextColumn get toCurrency => text().withLength(min: 3, max: 3)();
  /// Amount of `toCurrency` for 1 unit of `fromCurrency`.
  RealColumn get rate => real()();
}

/// Recurring subscriptions: amount, merchant, cadence, next-due date. The app
/// lists due/overdue subscriptions and can add them as transactions in one tap.
/// v0.1.1. Synced to Supabase (schema v9).
class RecurringTransactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get merchant => text().withLength(min: 1, max: 80)();
  RealColumn get amount => real()();
  IntColumn get categoryId => integer().nullable().references(Categories, #id)();
  /// daily | weekly | monthly | yearly
  TextColumn get period => text().withLength(min: 1, max: 16)();
  /// Next due date (local). Today/overdue = due now.
  DateTimeColumn get nextDue => dateTime()();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  BoolColumn get dirty => boolean().withDefault(const Constant(true))();
  IntColumn get remoteId => integer().nullable()();
}

/// Savings goals: name, target, deadline. Progress is funded by a one-off
/// allocation (saved amount) tracked on the goal itself. v0.1.1. Synced to
/// Supabase (schema v9).
class Objectives extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 60)();
  RealColumn get target => real()();
  /// How much has been saved toward the goal so far.
  RealColumn get saved => real().withDefault(const Constant(0))();
  DateTimeColumn? get deadline => dateTime().nullable()();
  BoolColumn get dirty => boolean().withDefault(const Constant(true))();
  IntColumn get remoteId => integer().nullable()();
}

/// Credit/debt ledger: money lent to or borrowed from someone. v0.1.1.
/// Synced to Supabase (schema v9).
class Debts extends Table {
  IntColumn get id => integer().autoIncrement()();
  /// The person you lent to / borrowed from.
  TextColumn get name => text().withLength(min: 1, max: 60)();
  RealColumn get amount => real()();
  /// true = you lent (money out), false = you borrowed (money in).
  BoolColumn get isLent => boolean()();
  TextColumn get note => text().withLength(min: 0, max: 200).nullable()();
  BoolColumn get settled => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get dirty => boolean().withDefault(const Constant(true))();
  IntColumn get remoteId => integer().nullable()();
}

/// Transactions mirror the Supabase `transactions` table.
class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  RealColumn get amount => real()();
  TextColumn get merchant => text().withLength(min: 1, max: 80)();
  IntColumn get categoryId => integer().nullable().references(Categories, #id)();
  IntColumn get walletId => integer().nullable().references(Wallets, #id)();
  DateTimeColumn get txnDate => dateTime()();
  TextColumn get note => text().withLength(min: 0, max: 500).nullable()();
  TextColumn get paymentMethod => text().withLength(min: 1, max: 16)(); // cash | upi | card | wallet
  TextColumn get upiRef => text().withLength(min: 0, max: 120).nullable()();
  TextColumn get source => text().withLength(min: 1, max: 16)(); // notification | manual | sms | import
  /// True for money in (salary, cashback…) — excluded from spend aggregates.
  BoolColumn get isIncome => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  /// True until the row is pushed to Supabase.
  BoolColumn get dirty => boolean().withDefault(const Constant(true))();
  /// Supabase row id once pushed; null while unsynced.
  IntColumn get remoteId => integer().nullable()();
}

/// Rows the user deleted locally that must be deleted on Supabase too.
/// Keyed by remote_id (the remote row id we already pushed). Synced via
/// DELETE; cleared once the remote row is gone. Prevents a stale pull from
/// resurrecting a deleted transaction. v0.2.1.
class DeletedTransactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  /// Supabase row id of the deleted transaction.
  IntColumn get remoteId => integer()();
  DateTimeColumn get deletedAt => dateTime().withDefault(currentDateAndTime)();
}

/// Tombstones for feature-table deletes (budgets, wallets, recurring,
/// objectives, debts, custom categories). Keyed by kind + remote_id — feature
/// tables have separate identity columns, so a shared id needs the kind to
/// disambiguate. Same contract as [DeletedTransactions]: synced via DELETE,
/// cleared once the remote row is gone, prevents a stale pull from
/// resurrecting a deleted row. v0.2.2.
class DeletedFeatures extends Table {
  IntColumn get id => integer().autoIncrement()();
  /// Which table the remote row belongs to (SyncKind.name or 'categories').
  TextColumn get kind => text().withLength(min: 1, max: 16)();
  /// Supabase row id of the deleted feature row.
  IntColumn get remoteId => integer()();
  DateTimeColumn get deletedAt => dateTime().withDefault(currentDateAndTime)();
}

/// Budgets: per-category monthly limits + alert thresholds. Synced to Supabase
/// (schema v9); category_id is the shared seeded category id. Custom categories
/// now sync too (v10) — budgets reference their remote id on the server.
class Budgets extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get categoryId => integer().references(Categories, #id)();
  RealColumn get amount => real()();
  TextColumn get period => text().withLength(min: 1, max: 16)(); // monthly | weekly | yearly
  IntColumn get alertPct50 => integer().withDefault(const Constant(50))();
  IntColumn get alertPct80 => integer().withDefault(const Constant(80))();
  IntColumn get alertPct100 => integer().withDefault(const Constant(100))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get dirty => boolean().withDefault(const Constant(true))();
  IntColumn get remoteId => integer().nullable()();
}

@DriftDatabase(tables: [Categories, Merchants, Rules, Transactions, Budgets, Wallets, ExchangeRates, RecurringTransactions, Objectives, Debts, DeletedTransactions, DeletedFeatures])
class AppDatabase extends _$AppDatabase {
  /// [executor] override lets tests inject `NativeDatabase.memory()`.
  AppDatabase({QueryExecutor? executor}) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 11;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _seed();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            // Existing rows default dirty = true → they push on first sync.
            await m.addColumn(transactions, transactions.dirty);
            await m.addColumn(transactions, transactions.remoteId);
          }
          if (from < 3) {
            // v0.1.1: wallets + multi-currency. Existing transactions keep
            // wallet_id NULL (they belong to no wallet) — no data rewrite.
            await m.addColumn(transactions, transactions.walletId);
            await m.createTable(wallets);
            await m.createTable(exchangeRates);
          }
          if (from < 4) {
            await m.createTable(recurringTransactions);
          }
          if (from < 5) {
            await m.createTable(objectives);
          }
          if (from < 6) {
            await m.createTable(debts);
          }
          if (from < 7) {
            // v0.2.0: income support. Existing rows stay expenses (false).
            await m.addColumn(transactions, transactions.isIncome);
            await m.addColumn(categories, categories.isIncome);
          }
          if (from < 8) {
            // v0.2.1: delete sync. Existing rows need no backfill — tombstones
            // are only written for deletes that happen after the upgrade.
            await m.createTable(deletedTransactions);
          }
          if (from < 9) {
            // v0.2.1: sync feature tables (budgets, wallets, recurring,
            // objectives, debts). Default dirty=true marks every existing row
            // for a one-time push → full backup. No data rewrite.
            await m.addColumn(wallets, wallets.dirty);
            await m.addColumn(wallets, wallets.remoteId);
            await m.addColumn(recurringTransactions, recurringTransactions.dirty);
            await m.addColumn(recurringTransactions, recurringTransactions.remoteId);
            await m.addColumn(objectives, objectives.dirty);
            await m.addColumn(objectives, objectives.remoteId);
            await m.addColumn(debts, debts.dirty);
            await m.addColumn(debts, debts.remoteId);
            await m.addColumn(budgets, budgets.updatedAt);
            await m.addColumn(budgets, budgets.dirty);
            await m.addColumn(budgets, budgets.remoteId);
          }
          if (from < 10) {
            // v0.2.1: categories sync. Custom categories now back up to
            // Supabase (server id ≠ local id → remoteId). Builtins default
            // dirty=true but the engine skips them (shared reference data).
            await m.addColumn(categories, categories.dirty);
            await m.addColumn(categories, categories.remoteId);
          }
          if (from < 11) {
            // v0.2.2: feature delete sync. Tombstones for budget/wallet/
            // recurring/objective/debt/category deletes so a stale pull can't
            // resurrect them. No backfill needed — only future deletes write.
            await m.createTable(deletedFeatures);
          }
        },
      );

  Future<void> _seed() async {
    final defaultCategories = [
      (name: 'Food', emoji: '🍔', color: '#E86A17', sortOrder: 0),
      (name: 'Travel', emoji: '🚗', color: '#2E86AB', sortOrder: 1),
      (name: 'Shopping', emoji: '🛍️', color: '#9B5DE5', sortOrder: 2),
      (name: 'Bills', emoji: '⚡', color: '#F4B942', sortOrder: 3),
      (name: 'Recharge', emoji: '📱', color: '#06D6A0', sortOrder: 4),
      (name: 'Rent', emoji: '🏠', color: '#EF476F', sortOrder: 5),
      (name: 'Grocery', emoji: '🛒', color: '#4CAF50', sortOrder: 6),
      (name: 'Medical', emoji: '💊', color: '#E63946', sortOrder: 7),
      (name: 'Entertainment', emoji: '🎬', color: '#FF9F1C', sortOrder: 8),
      (name: 'Other', emoji: '📦', color: '#8D99AE', sortOrder: 9),
    ];
    for (final c in defaultCategories) {
      final id = await into(categories).insertReturning(CategoriesCompanion.insert(
        name: c.name,
        emoji: c.emoji,
        color: c.color,
        sortOrder: Value(c.sortOrder),
      ));
      await into(merchants).insert(MerchantsCompanion.insert(
        name: c.name,
        categoryId: Value(id.id),
        icon: Value(c.emoji),
      ));
    }
    // Income categories — shown only in income mode on the add forms.
    final incomeCategories = [
      (name: 'Salary', emoji: '💼', color: '#2E9E6B', sortOrder: 0),
      (name: 'Bonus', emoji: '🎁', color: '#F4B942', sortOrder: 1),
      (name: 'Gift', emoji: '🎉', color: '#9B5DE5', sortOrder: 2),
      (name: 'Other income', emoji: '💰', color: '#06D6A0', sortOrder: 3),
    ];
    for (final c in incomeCategories) {
      await into(categories).insert(CategoriesCompanion.insert(
        name: c.name,
        emoji: c.emoji,
        color: c.color,
        sortOrder: Value(10 + c.sortOrder),
        isIncome: const Value(true),
      ));
    }
    await _seedRules();
  }

  Future<void> _seedRules() async {
    // ~80 builtin merchant → category rules.
    final ruleMap = <String, String>{
      // Food & Dining
      'swiggy': 'Food',
      'zomato': 'Food',
      'dominos': 'Food',
      'mcdonald': 'Food',
      'kfc': 'Food',
      'burger king': 'Food',
      'pizza hut': 'Food',
      'subway': 'Food',
      'starbucks': 'Food',
      'chaayos': 'Food',
      'chai point': 'Food',
      'eatsure': 'Food',
      'faasos': 'Food',
      'behrouz': 'Food',
      // Travel & Commute
      'uber': 'Travel',
      'ola': 'Travel',
      'rapido': 'Travel',
      'namma yatri': 'Travel',
      'irctc': 'Travel',
      'redbus': 'Travel',
      'makemytrip': 'Travel',
      'goibibo': 'Travel',
      'easemytrip': 'Travel',
      'indigo': 'Travel',
      'air india': 'Travel',
      'toll': 'Travel',
      'fastag': 'Travel',
      'petrol': 'Travel',
      'fuel': 'Travel',
      'hpcl': 'Travel',
      'bpcl': 'Travel',
      'iocl': 'Travel',
      'shell': 'Travel',
      // Shopping
      'amazon': 'Shopping',
      'flipkart': 'Shopping',
      'myntra': 'Shopping',
      'meesho': 'Shopping',
      'ajio': 'Shopping',
      'nykaa': 'Shopping',
      'tata cliq': 'Shopping',
      'croma': 'Shopping',
      'vijay sales': 'Shopping',
      'decathlon': 'Shopping',
      'lenskart': 'Shopping',
      'ikea': 'Shopping',
      // Grocery & Essentials
      'blinkit': 'Grocery',
      'zepto': 'Grocery',
      'instamart': 'Grocery',
      'bigbasket': 'Grocery',
      'dmart': 'Grocery',
      'reliance fresh': 'Grocery',
      'reliance retail': 'Grocery',
      'reliance smart': 'Grocery',
      'reliance': 'Grocery',
      'jiomart': 'Grocery',
      'dunzo': 'Grocery',
      'spencer': 'Grocery',
      'nature basket': 'Grocery',
      // Medical & Health
      'apollo': 'Medical',
      'pharmeasy': 'Medical',
      'netmeds': 'Medical',
      '1mg': 'Medical',
      'tata 1mg': 'Medical',
      'medplus': 'Medical',
      'practo': 'Medical',
      'fortis': 'Medical',
      'max healthcare': 'Medical',
      // Recharge & Telecom
      'airtel': 'Recharge',
      'jio': 'Recharge',
      'vodafone': 'Recharge',
      'vi': 'Recharge',
      'bsnl': 'Recharge',
      'act fibernet': 'Recharge',
      // Bills & Utilities
      'netflix': 'Bills',
      'hotstar': 'Bills',
      'spotify': 'Bills',
      'prime video': 'Bills',
      'youtube premium': 'Bills',
      'apple': 'Bills',
      'electricity': 'Bills',
      'bescom': 'Bills',
      'tneb': 'Bills',
      'mahadiscom': 'Bills',
      'bses': 'Bills',
      'tata power': 'Bills',
      'gas bill': 'Bills',
      'indane': 'Bills',
      'hp gas': 'Bills',
      'bharat gas': 'Bills',
      'water bill': 'Bills',
      'rent': 'Rent',
      'emi': 'Bills',
      // Entertainment
      'bookmyshow': 'Entertainment',
      'bms': 'Entertainment',
      'pvr': 'Entertainment',
      'inox': 'Entertainment',
      'cinepolis': 'Entertainment',
      'steam': 'Entertainment',
      'playstation': 'Entertainment',
      // Payment utilities / generic
      'paytm': 'Other',
      'phonepe': 'Other',
      'google pay': 'Other',
      'gpay': 'Other',
    };
    for (final entry in ruleMap.entries) {
      final cat = await (select(categories)..where((t) => t.name.equals(entry.value))).getSingleOrNull();
      if (cat != null) {
        await into(rules).insert(RulesCompanion.insert(
          pattern: entry.key,
          categoryId: cat.id,
          type: 'builtin',
        ));
      }
    }
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'kharcha.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
