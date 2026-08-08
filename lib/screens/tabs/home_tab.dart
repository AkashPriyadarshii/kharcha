import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/database.dart';
import '../../data/transaction_repository.dart';

final _currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

/// Aggregates the dashboard figures in one async snapshot.
class HomeSummary {
  const HomeSummary({
    required this.today,
    required this.month,
    required this.budgetLeft,
    required this.byCategory,
  });

  final double today;
  final double month;
  final double budgetLeft;
  final List<(Category, double)> byCategory;
}

final homeSummaryProvider = StreamProvider<HomeSummary>((ref) {
  final repo = ref.watch(transactionRepositoryProvider);
  // Recompute the whole dashboard on every insert/delete — same "stale
  // aggregates" fix as the tab-level providers.
  return repo.watchAll().asyncMap((_) async {
    final now = DateTime.now();
    final byCategory = await repo.monthSpendByCategory(now);
    final budgets = await repo.watchBudgets().first;
    final spentOnBudgeted = byCategory
        .where((c) => budgets.any((b) => b.$1.categoryId == c.$1.id))
        .fold(0.0, (s, c) => s + c.$2);
    final budgetTotal = budgets.fold(0.0, (s, b) => s + b.$1.amount);
    return HomeSummary(
      today: await repo.dayTotal(now),
      month: await repo.monthTotal(now),
      budgetLeft: (budgetTotal - spentOnBudgeted).clamp(0, double.infinity),
      byCategory: byCategory,
    );
  });
});

/// Home dashboard: today / this month / budget left + this month by category.
class HomeTab extends ConsumerWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(homeSummaryProvider);
    final recent = ref.watch(transactionsProvider).value ?? const <Transaction>[];
    final recent5 = recent.take(5).toList();
    return summary.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Could not load dashboard.\n$e')),
      data: (s) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _StatRow(summary: s),
          const SizedBox(height: 24),
          Text('This month by category', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (s.byCategory.isEmpty)
            Text('No spends this month yet.', style: Theme.of(context).textTheme.bodyMedium)
          else
            for (final c in s.byCategory)
              _CategoryBar(category: c.$1, amount: c.$2, max: s.byCategory.first.$2),
          const SizedBox(height: 24),
          Text('Recent transactions', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (recent5.isEmpty)
            Text('No expenses yet — add one with Quick add, or enable capture.',
                style: Theme.of(context).textTheme.bodyMedium)
          else
            for (final t in recent5) _RecentTile(transaction: t),
        ],
      ),
    );
  }
}

class _RecentTile extends StatelessWidget {
  const _RecentTile({required this.transaction});

  final Transaction transaction;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: const Icon(Icons.receipt_long_outlined, size: 20),
      title: Text(transaction.merchant),
      trailing: Text(
        _currency.format(transaction.amount),
        style: Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.summary});

  final HomeSummary summary;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Stat(label: 'Today', value: _currency.format(summary.today)),
        const SizedBox(width: 12),
        _Stat(label: 'This month', value: _currency.format(summary.month)),
        const SizedBox(width: 12),
        _Stat(label: 'Budget left', value: _currency.format(summary.budgetLeft)),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryBar extends StatelessWidget {
  const _CategoryBar({required this.category, required this.amount, required this.max});

  final Category category;
  final double amount;
  final double max;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = categoryColor(category);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(category.emoji),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(category.name, style: theme.textTheme.bodyMedium),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: max <= 0 ? 0 : (amount / max).clamp(0.0, 1.0),
                    minHeight: 8,
                    color: color,
                    backgroundColor: color.withValues(alpha: 0.15),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _currency.format(amount),
            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// Parses a stored #RRGGBB into a [Color]. Shared by dashboard + budget bars.
Color categoryColor(Category category) =>
    Color(int.parse('FF${category.color}', radix: 16));
