import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kharcha/data/database.dart';
import 'package:kharcha/data/transaction_repository.dart';
import 'package:kharcha/screens/tabs/home_tab.dart';

Widget _testHarness({
  required AppDatabase db,
  required Widget child,
  HomeSummary? summaryOverride,
}) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, _) => Scaffold(body: child)),
      GoRoute(
        path: '/add',
        builder: (_, state) {
          final t = state.extra as Transaction?;
          return Scaffold(body: Text('Edit ${t?.merchant ?? ""}'));
        },
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      if (summaryOverride != null)
        homeSummaryProvider.overrideWith((ref) => Stream.value(summaryOverride)),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  group('HomeSummary logic', () {
    test('netBalance is income minus month spend', () {
      const summary = HomeSummary(
        today: 500,
        month: 12000,
        income: 50000,
        budgetLeft: 8000,
        budgetTotal: 20000,
        byCategory: [],
        trend: [],
      );
      expect(summary.netBalance, 38000);
    });

    test('categoryColor parses standard hex strings', () {
      const cat = Category(
        id: 1,
        name: 'Food',
        emoji: '🍔',
        color: '#EF476F',
        isIncome: false,
        isCustom: false,
        sortOrder: 1,
        dirty: false,
      );
      final color = categoryColor(cat);
      expect(color, const Color(0xFFEF476F));
    });

    test('formatTxnTime formats relative and absolute timestamps', () {
      final now = DateTime.now();
      expect(formatTxnTime(now), contains('Today'));
      expect(formatTxnTime(now.subtract(const Duration(days: 1))), contains('Yesterday'));
      expect(formatTxnTime(DateTime(2026, 1, 15, 14, 30)), '15 Jan, 2:30 PM');
    });
  });

  group('HomeTab Widget', () {
    testWidgets('renders hero spend and empty state when no expenses exist', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final db = AppDatabase(executor: NativeDatabase.memory());
      addTearDown(() async => db.close());

      const summary = HomeSummary(
        today: 0,
        month: 0,
        income: 0,
        budgetLeft: 0,
        budgetTotal: 0,
        byCategory: [],
        trend: [],
      );

      await tester.pumpWidget(_testHarness(db: db, child: const HomeTab(), summaryOverride: summary));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1000));

      expect(find.text('THIS MONTH'), findsOneWidget);
      expect(find.text('No expenses yet'), findsOneWidget);
      expect(find.text('Quick add'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('renders recent transaction item and navigates on tap', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final db = AppDatabase(executor: NativeDatabase.memory());
      addTearDown(() async => db.close());
      final repo = TransactionRepository(db);

      final food = await (db.select(db.categories)..where((c) => c.name.equals('Food'))).getSingle();
      await repo.insertManual(
        amount: 250,
        merchant: 'Swiggy',
        categoryId: food.id,
        paymentMethod: 'upi',
        txnDate: DateTime.now(),
      );

      final summary = HomeSummary(
        today: 250,
        month: 250,
        income: 0,
        budgetLeft: 5000,
        budgetTotal: 10000,
        byCategory: [(food, 250)],
        trend: [('Aug', 250)],
      );

      await tester.pumpWidget(_testHarness(db: db, child: const HomeTab(), summaryOverride: summary));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1000));

      expect(find.text('Swiggy'), findsOneWidget);
      expect(find.text('View all'), findsOneWidget);

      // Tap on recent transaction tile to navigate to edit
      await tester.tap(find.text('Swiggy'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Edit Swiggy'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
    });
  });
}
