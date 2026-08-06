import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kharcha/data/database.dart';
import 'package:kharcha/data/transaction_repository.dart';
import 'package:kharcha/screens/add_expense_screen.dart';

void main() {
  testWidgets('full form saves an expense to the database', (tester) async {
    final db = AppDatabase(executor: NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: AddExpenseScreen()),
      ),
    );

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
  });

  testWidgets('empty form shows validation errors and saves nothing', (tester) async {
    final db = AppDatabase(executor: NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: AddExpenseScreen()),
      ),
    );

    await tester.tap(find.text('Save expense'));
    await tester.pumpAndSettle();

    expect(find.text('Enter an amount greater than zero.'), findsOneWidget);
    expect(find.text('Enter the merchant name.'), findsOneWidget);
    expect(await db.select(db.transactions).get(), isEmpty);
  });

  testWidgets('category picker lists seeded categories', (tester) async {
    final db = AppDatabase(executor: NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: AddExpenseScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Category'));
    await tester.pumpAndSettle();

    expect(find.text('🍔  Food'), findsOneWidget);
  });
}
