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

/// Transactions mirror the Supabase `transactions` table.
class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  RealColumn get amount => real()();
  TextColumn get merchant => text().withLength(min: 1, max: 80)();
  IntColumn get categoryId => integer().nullable().references(Categories, #id)();
  DateTimeColumn get txnDate => dateTime()();
  TextColumn get note => text().withLength(min: 0, max: 500).nullable()();
  TextColumn get paymentMethod => text().withLength(min: 1, max: 16)(); // cash | upi | card | wallet
  TextColumn get upiRef => text().withLength(min: 0, max: 120).nullable()();
  TextColumn get source => text().withLength(min: 1, max: 16)(); // notification | manual | sms
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// Budgets: per-category monthly limits + alert thresholds.
class Budgets extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get categoryId => integer().references(Categories, #id)();
  RealColumn get amount => real()();
  TextColumn get period => text().withLength(min: 1, max: 16)(); // monthly | weekly | yearly
  IntColumn get alertPct50 => integer().withDefault(const Constant(50))();
  IntColumn get alertPct80 => integer().withDefault(const Constant(80))();
  IntColumn get alertPct100 => integer().withDefault(const Constant(100))();
}

@DriftDatabase(tables: [Categories, Merchants, Rules, Transactions, Budgets])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _seed();
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
    await _seedRules();
  }

  Future<void> _seedRules() async {
    // ~40 builtin merchant → category rules. Add more in P1 as UPI apps vary.
    final ruleMap = <String, String>{
      'swiggy': 'Food',
      'zomato': 'Food',
      'dominos': 'Food',
      'mcdonald': 'Food',
      'uber': 'Travel',
      'ola': 'Travel',
      'rapido': 'Travel',
      'amazon': 'Shopping',
      'flipkart': 'Shopping',
      'myntra': 'Shopping',
      'meesho': 'Shopping',
      'reliance': 'Grocery',
      'dmart': 'Grocery',
      'bigbasket': 'Grocery',
      'blinkit': 'Grocery',
      'zepto': 'Grocery',
      'jiomart': 'Grocery',
      'netflix': 'Bills',
      'hotstar': 'Bills',
      'spotify': 'Bills',
      'airtel': 'Recharge',
      'jio': 'Recharge',
      'vodafone': 'Recharge',
      'vi': 'Recharge',
      'electricity': 'Bills',
      'bms': 'Entertainment',
      'bookmyshow': 'Entertainment',
      'paytm': 'Other',
      'phonepe': 'Other',
      'google pay': 'Other',
      'gpay': 'Other',
      'rent': 'Rent',
      'emi': 'Bills',
      'toll': 'Travel',
      'irctc': 'Travel',
      'apollo': 'Medical',
      'fortis': 'Medical',
      '1mg': 'Medical',
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
