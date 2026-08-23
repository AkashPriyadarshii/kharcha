import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kharcha/data/database.dart';
import 'package:kharcha/data/transaction_repository.dart';
import 'package:kharcha/screens/add_expense_screen.dart';

Widget _testHarness({required AppDatabase db, required Widget child}) {
  final router = GoRouter(
    initialLocation: '/add',
    routes: [
      GoRoute(path: '/', builder: (_, _) => const Scaffold(body: Text('Home'))),
      GoRoute(path: '/add', builder: (_, _) => child),
    ],
  );
  return ProviderScope(
    overrides: [databaseProvider.overrideWithValue(db)],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets('full form saves an expense to the database', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppDatabase(executor: NativeDatabase.memory());
    addTearDown(() async => db.close());

    await tester.pumpWidget(_testHarness(db: db, child: const AddExpenseScreen()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), '450.50');
    await tester.enterText(find.byType(TextFormField).at(1), 'Zomato');
    await tester.enterText(find.byType(TextFormField).at(2), 'Lunch');

    await tester.tap(find.text('Save expense'));
    await tester.pumpAndSettle();

    final rows = await db.select(db.transactions).get();
    expect(rows, hasLength(1));
    expect(rows.single.amount, 450.5);
    expect(rows.single.merchant, 'Zomato');
    expect(rows.single.note, 'Lunch');
    expect(rows.single.source, 'manual');
    expect(rows.single.paymentMethod, 'upi');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('empty form shows validation errors and saves nothing', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppDatabase(executor: NativeDatabase.memory());
    addTearDown(() async => db.close());

    await tester.pumpWidget(_testHarness(db: db, child: const AddExpenseScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save expense'));
    await tester.pumpAndSettle();

    expect(find.text('Enter an amount greater than zero.'), findsOneWidget);
    expect(find.text('Enter the merchant name.'), findsOneWidget);
    expect(await db.select(db.transactions).get(), isEmpty);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('category picker lists seeded categories', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppDatabase(executor: NativeDatabase.memory());
    addTearDown(() async => db.close());

    await tester.pumpWidget(_testHarness(db: db, child: const AddExpenseScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();

    expect(find.text('🍔  Food').last, findsOneWidget);

    await tester.tap(find.text('🍔  Food').last);
    await tester.pumpAndSettle();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  });
}

