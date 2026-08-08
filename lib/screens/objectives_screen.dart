import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/theme.dart';
import '../data/database.dart';
import '../data/transaction_repository.dart';

final _currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

/// Savings goals: target + progress, add allocation, delete.
class ObjectivesScreen extends ConsumerStatefulWidget {
  const ObjectivesScreen({super.key});

  @override
  ConsumerState<ObjectivesScreen> createState() => _ObjectivesScreenState();
}

class _ObjectivesScreenState extends ConsumerState<ObjectivesScreen> {
  @override
  Widget build(BuildContext context) {
    final goals = ref.watch(objectivesProvider).value ?? const <Objective>[];
    return Scaffold(
      appBar: AppBar(title: const Text('Savings goals')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (goals.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 48),
                child: Column(
                  children: [
                    const Text('🎯', style: TextStyle(fontSize: 44)),
                    const SizedBox(height: 12),
                    Text('No goals yet.', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    const Text('Set a savings target to watch it grow.'),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () => _add(context),
                      icon: const Icon(Icons.add),
                      label: const Text('Add goal'),
                    ),
                  ],
                ),
              ),
            )
          else
            for (final g in goals) _GoalCard(goal: g),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(context),
        icon: const Icon(Icons.add),
        label: const Text('Add goal'),
      ),
    );
  }

  Future<void> _add(BuildContext context) async {
    final name = TextEditingController();
    final target = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New goal'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, autofocus: true, decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: 12),
            TextField(
              controller: target,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Target amount', prefixText: '₹ '),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final n = name.text.trim();
              final t = double.tryParse(target.text.trim());
              if (n.isEmpty || t == null || t <= 0) return;
              ref.read(transactionRepositoryProvider).insertObjective(name: n, target: t);
              Navigator.of(ctx).pop();
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

class _GoalCard extends ConsumerWidget {
  const _GoalCard({required this.goal});

  final Objective goal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pct = goal.target <= 0 ? 0.0 : (goal.saved / goal.target).clamp(0.0, 1.0);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(goal.name, style: Theme.of(context).textTheme.titleMedium)),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Delete',
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text('Delete "${goal.name}"?'),
                        content: const Text('This permanently removes the goal and its saved amount.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                          FilledButton(
                            onPressed: () => Navigator.of(ctx).pop(true),
                            child: const Text('Delete', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      await ref.read(transactionRepositoryProvider).deleteObjective(goal.id);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: pct, minHeight: 8, borderRadius: BorderRadius.circular(4)),
            const SizedBox(height: 8),
            Text('${_currency.format(goal.saved)} of ${_currency.format(goal.target)} (${(pct * 100).round()}%)',
                style: moneyStyle.copyWith(fontSize: 13)),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton(
                onPressed: () async {
                  final amount = TextEditingController();
                  await showDialog<void>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Add to goal'),
                      content: TextField(
                        controller: amount,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Amount saved'),
                      ),
                      actions: [
                        TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
                        FilledButton(
                          onPressed: () {
                            final a = double.tryParse(amount.text.trim());
                            if (a != null && a > 0) {
                              ref.read(transactionRepositoryProvider).addToObjective(goal.id, a);
                            }
                            Navigator.of(ctx).pop();
                          },
                          child: const Text('Add'),
                        ),
                      ],
                    ),
                  );
                },
                child: const Text('Add saved amount'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
