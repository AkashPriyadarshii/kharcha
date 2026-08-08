import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

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
    return Scaffold(
      appBar: AppBar(title: const Text('Wallets')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (wallets.isEmpty)
            Text('No wallets yet. Add one to track balances per account.',
                style: Theme.of(context).textTheme.bodyMedium)
          else
            for (final w in wallets)
              _WalletTile(wallet: w),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addWallet(context),
        icon: const Icon(Icons.add),
        label: const Text('Add wallet'),
      ),
    );
  }

  Future<void> _addWallet(BuildContext context) async {
    final name = TextEditingController();
    String currency = 'INR';
    final balance = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('New wallet'),
          content: Column(
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
            ],
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
                      initialBalance: double.tryParse(balance.text.trim()) ?? 0,
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
    final symbol = _currencySymbol(wallet.currency);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.account_balance_wallet_outlined),
      title: Text(wallet.name),
      subtitle: Text(wallet.currency),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            NumberFormat.currency(locale: 'en_IN', symbol: symbol).format(balance + wallet.initialBalance),
            style: moneyStyle.copyWith(fontSize: 13),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Rename wallet',
            onPressed: () => _editWallet(context, ref, wallet),
          ),
        ],
      ),
    );
  }

  void _editWallet(BuildContext context, WidgetRef ref, Wallet wallet) {
    final name = TextEditingController(text: wallet.name);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename wallet'),
        content: TextField(
          controller: name,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final n = name.text.trim();
              if (n.isEmpty) return;
              ref.read(transactionRepositoryProvider).updateWallet(wallet.copyWith(name: n));
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
