import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/database.dart';
import '../../data/transaction_repository.dart';

final _currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
final _dateFormat = DateFormat('d MMM');

/// Full transactions list, newest first. Search/filters land in 4.2.
class TransactionsTab extends ConsumerWidget {
  const TransactionsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactions = ref.watch(transactionsProvider);
    final categories = ref.watch(categoriesProvider).value ?? const <Category>[];
    return transactions.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Could not load expenses.\n$e')),
      data: (list) => list.isEmpty
          ? const _EmptyState()
          : _TransactionList(transactions: list, categories: categories),
    );
  }
}

class _TransactionList extends StatelessWidget {
  const _TransactionList({required this.transactions, required this.categories});

  final List<Transaction> transactions;
  final List<Category> categories;

  Category? _categoryFor(int? id) {
    for (final c in categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 96),
      itemCount: transactions.length,
      itemBuilder: (context, i) {
        final t = transactions[i];
        final cat = _categoryFor(t.categoryId);
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: cat == null
                ? const Color(0xFF8D99AE)
                : Color(int.parse('FF${cat.color}', radix: 16)),
            child: Text(cat?.emoji ?? '📦'),
          ),
          title: Text(t.merchant),
          subtitle: Text(
            [
              if (cat != null) cat.name,
              t.note ?? '',
              _dateFormat.format(t.txnDate),
            ].where((s) => s.isNotEmpty).join(' · '),
          ),
          trailing: Text(
            _currency.format(t.amount),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                  fontWeight: FontWeight.w600,
                ),
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('💸', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            Text('No expenses yet.', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text(
              'Add one with the Quick add button — or UPI notifications will do it for you.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
