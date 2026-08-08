import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kharcha/data/database.dart';
import 'package:kharcha/data/transaction_repository.dart';

void main() {
  late AppDatabase db;
  late TransactionRepository repo;

  setUp(() {
    db = AppDatabase(executor: NativeDatabase.memory());
    repo = TransactionRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('insertWallet persists and watchWallets emits it', () async {
    await repo.insertWallet(name: 'HDFC', currency: 'INR');
    final wallets = await repo.watchWallets().first;
    expect(wallets.single.name, 'HDFC');
    expect(wallets.single.currency, 'INR');
  });

  test('walletBalance = sum of transactions on that wallet', () async {
    final w = await repo.insertWallet(name: 'Cash', currency: 'INR');
    await repo.insertManual(
      amount: 100, merchant: 'A', paymentMethod: 'upi', txnDate: DateTime(2026, 8, 1), walletId: w.id);
    await repo.insertManual(
      amount: 50, merchant: 'B', paymentMethod: 'cash', txnDate: DateTime(2026, 8, 2), walletId: w.id);
    expect(await repo.walletBalance(w.id), 150);
  });

  test('walletBalance ignores transactions on other wallets', () async {
    final w1 = await repo.insertWallet(name: 'Cash', currency: 'INR');
    final w2 = await repo.insertWallet(name: 'Card', currency: 'INR');
    await repo.insertManual(
      amount: 100, merchant: 'A', paymentMethod: 'upi', txnDate: DateTime(2026, 8, 1), walletId: w2.id);
    expect(await repo.walletBalance(w1.id), 0);
    expect(await repo.walletBalance(w2.id), 100);
  });

  test('deleteWallet nulls wallet_id on its transactions', () async {
    final w = await repo.insertWallet(name: 'Cash', currency: 'INR');
    await repo.insertManual(
      amount: 100, merchant: 'A', paymentMethod: 'upi', txnDate: DateTime(2026, 8, 1), walletId: w.id);
    await repo.deleteWallet(w.id);
    final rows = await db.select(db.transactions).get();
    expect(rows.single.walletId, isNull);
    expect(await repo.watchWallets().first, isEmpty);
  });

  test('convertCurrency uses manual rate, 1:1 when missing', () async {
    await repo.setExchangeRate(from: 'USD', to: 'INR', rate: 83);
    expect(await repo.convertCurrency(2, 'USD', 'INR'), 166);
    expect(await repo.convertCurrency(100, 'INR', 'INR'), 100);
    expect(await repo.convertCurrency(100, 'USD', 'EUR'), 100); // no rate → 1:1
  });

  test('setExchangeRate replaces existing rate', () async {
    await repo.setExchangeRate(from: 'USD', to: 'INR', rate: 83);
    await repo.setExchangeRate(from: 'USD', to: 'INR', rate: 85);
    expect(await repo.convertCurrency(1, 'USD', 'INR'), 85);
  });
}
