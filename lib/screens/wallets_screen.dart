import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/money.dart';
import '../core/theme.dart';
import '../data/database.dart';
import '../data/transaction_repository.dart';

const _currencies = ['INR', 'USD', 'EUR', 'GBP', 'AED', 'SGD'];

/// Wallet list + balance header. Add/edit/delete wallets; per-wallet currency.
class WalletsScreen extends ConsumerStatefulWidget {
  const WalletsScreen({super.key});

  @override
  ConsumerState<WalletsScreen> createState() => _WalletsScreenState();
}

class _WalletsScreenState extends ConsumerState<WalletsScreen> {
  @override
  Widget build(BuildContext context) {
    final wallets = ref.watch(walletsProvider).value ?? const <Wallet>[];
    final accounts = wallets.where((w) => w.accountMask != null && w.accountMask!.isNotEmpty).toList();
    final manualWallets = wallets.where((w) => w.accountMask == null || w.accountMask!.isEmpty).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Accounts & Wallets')),
      body: SafeArea(
        top: false,
        child: wallets.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(16),
                child: Text('No accounts yet. Add one to track balances.',
                    style: Theme.of(context).textTheme.bodyMedium),
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (accounts.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8, top: 8),
                      child: Text('Accounts (Auto-tracked)', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Theme.of(context).colorScheme.primary)),
                    ),
                    for (final w in accounts) _WalletTile(wallet: w),
                    const Divider(),
                  ],
                  if (manualWallets.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8, top: 8),
                      child: Text('Wallets (Manual)', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Theme.of(context).colorScheme.primary)),
                    ),
                    for (final w in manualWallets) _WalletTile(wallet: w),
                  ],
                ],
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addWallet(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Account / Wallet'),
      ),
    );
  }

  Future<void> _addWallet(BuildContext context) async {
    final name = TextEditingController();
    String currency = 'INR';
    final balance = TextEditingController();
    final accountMask = TextEditingController();
    final bankName = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('New wallet'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: currency,
                  decoration: const InputDecoration(labelText: 'Currency'),
                  items: [for (final c in _currencies) DropdownMenuItem(value: c, child: Text(c))],
                  onChanged: (v) => setLocal(() => currency = v ?? 'INR'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: balance,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Opening balance (optional)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: accountMask,
                  decoration: const InputDecoration(labelText: 'Account Mask (e.g. 1234)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: bankName,
                  decoration: const InputDecoration(labelText: 'Bank Name (e.g. HDFC)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                final n = name.text.trim();
                if (n.isEmpty) return;
                ref.read(transactionRepositoryProvider).insertWallet(
                      name: n,
                      currency: currency,
                      initialBalance: parseAmount(balance.text) ?? 0,
                      accountMask: accountMask.text.trim().isEmpty ? null : accountMask.text.trim(),
                      bankName: bankName.text.trim().isEmpty ? null : bankName.text.trim(),
                    );
                Navigator.of(ctx).pop();
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }
}

class _WalletTile extends ConsumerWidget {
  const _WalletTile({required this.wallet});

  final Wallet wallet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balance = ref.watch(walletBalanceProvider(wallet.id)).value ?? 0.0;
    final totalBalance = balance + wallet.initialBalance;
    final symbol = _currencySymbol(wallet.currency);
    
    // Check if SMS balance drifts from computed balance (allowing 1 unit delta for rounding)
    final bool hasDrift = wallet.latestSmsBalance != null && (wallet.latestSmsBalance! - totalBalance).abs() > 1.0;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.account_balance_wallet_outlined),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(wallet.name),
          if (hasDrift) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _showDriftDialog(context, totalBalance, symbol),
              child: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 18),
            ),
          ]
        ],
      ),
      subtitle: Text(wallet.currency),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            NumberFormat.currency(locale: 'en_IN', symbol: symbol).format(totalBalance),
            style: moneyStyle.copyWith(fontSize: 13),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit wallet',
            onPressed: () => _editWallet(context, ref, wallet),
          ),
        ],
      ),
    );
  }

  void _showDriftDialog(BuildContext context, double currentBalance, String symbol) {
    final diff = wallet.latestSmsBalance! - currentBalance;
    final diffFormatted = NumberFormat.currency(locale: 'en_IN', symbol: symbol).format(diff.abs());
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Balance Sync Drift'),
        content: Text('The last SMS reported a balance of ${NumberFormat.currency(locale: 'en_IN', symbol: symbol).format(wallet.latestSmsBalance!)}.\n\n'
            'Your tracked balance is off by $diffFormatted. You should add an adjustment transaction.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK')),
        ],
      ),
    );
  }

  void _editWallet(BuildContext context, WidgetRef ref, Wallet wallet) {
    final name = TextEditingController(text: wallet.name);
    final accountMask = TextEditingController(text: wallet.accountMask ?? '');
    final bankName = TextEditingController(text: wallet.bankName ?? '');
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit wallet'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: accountMask,
                decoration: const InputDecoration(labelText: 'Account Mask (e.g. 1234)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: bankName,
                decoration: const InputDecoration(labelText: 'Bank Name (e.g. HDFC)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final n = name.text.trim();
              if (n.isEmpty) return;
              ref.read(transactionRepositoryProvider).updateWallet(wallet.copyWith(
                    name: n,
                    accountMask: Value(accountMask.text.trim().isEmpty ? null : accountMask.text.trim()),
                    bankName: Value(bankName.text.trim().isEmpty ? null : bankName.text.trim()),
                  ));
              Navigator.of(ctx).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

/// Live per-wallet balance: recomputed on every insert/delete (same stale-
/// aggregate fix as the dashboard providers).
final walletBalanceProvider = StreamProvider.family<double, int>(
  (ref, walletId) => ref
      .watch(transactionRepositoryProvider)
      .watchAll()
      .asyncMap((_) => ref.read(transactionRepositoryProvider).walletBalance(walletId)),
);

String _currencySymbol(String code) => switch (code) {
      'INR' => '₹',
      'USD' => r'$',
      'EUR' => '€',
      'GBP' => '£',
      'AED' => 'AED ',
      'SGD' => 'S\$',
      _ => code,
    };
