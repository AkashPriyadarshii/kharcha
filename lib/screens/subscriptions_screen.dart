import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/money.dart';
import '../core/theme.dart';
import '../data/database.dart';
import '../data/transaction_repository.dart';

final _currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

/// Recurring subscriptions: list due/upcoming, pay one-tap, add new, toggle.
class SubscriptionsScreen extends ConsumerStatefulWidget {
  const SubscriptionsScreen({super.key});

  @override
  ConsumerState<SubscriptionsScreen> createState() => _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends ConsumerState<SubscriptionsScreen> {
  bool _onlyDue = false;

  @override
  Widget build(BuildContext context) {
    final recurring = ref.watch(recurringProvider).value ?? const <RecurringTransaction>[];
    final now = DateTime.now();
    final due = recurring.where((r) => r.active && !r.nextDue.isAfter(now)).toList()
      ..sort((a, b) => a.nextDue.compareTo(b.nextDue));
    final shown = _onlyDue ? due : recurring;

    final activeList = recurring.where((r) => r.active).toList();
    final totalMonthly = activeList.fold(0.0, (s, r) {
      final monthly = switch (r.period) {
        'daily' => r.amount * 30.0,
        'weekly' => r.amount * 4.33,
        'monthly' => r.amount,
        'yearly' => r.amount / 12.0,
        _ => r.amount,
      };
      return s + monthly;
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscriptions'),
        actions: [
          IconButton(
            tooltip: _onlyDue ? 'Show all' : 'Show due only',
            icon: Icon(_onlyDue ? Icons.list : Icons.notifications_outlined),
            onPressed: () => setState(() => _onlyDue = !_onlyDue),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (recurring.isNotEmpty) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Monthly commitment',
                              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _currency.format(totalMonthly),
                              style: moneyStyle.copyWith(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('${activeList.length} active', style: Theme.of(context).textTheme.bodySmall),
                          if (due.isNotEmpty)
                            Text(
                              '${due.length} due now',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).colorScheme.error,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (shown.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Column(
                  children: [
                    const Text('🔁', style: TextStyle(fontSize: 44)),
                    const SizedBox(height: 12),
                    Text('No subscriptions yet.', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text('Track Netflix, gym, rent — anything that recurs.',
                        style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () => _add(context),
                      icon: const Icon(Icons.add),
                      label: const Text('Add subscription'),
                    ),
                  ],
                ),
              )
            else
              for (final r in shown)
                _RecurringTile(recurring: r, due: r.active && !r.nextDue.isAfter(now)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(context),
        icon: const Icon(Icons.add),
        label: const Text('Add subscription'),
      ),
    );
  }

  Future<void> _add(BuildContext context) async {
    final merchant = TextEditingController();
    final amount = TextEditingController();
    String period = 'monthly';
    DateTime nextDue = DateTime.now();
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('New subscription'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: merchant,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Merchant'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amount,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Amount', prefixText: '₹ '),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: period,
                decoration: const InputDecoration(labelText: 'Period'),
                items: [
                  for (final p in const ['daily', 'weekly', 'monthly', 'yearly'])
                    DropdownMenuItem(value: p, child: Text(p[0].toUpperCase() + p.substring(1))),
                ],
                onChanged: (v) => setLocal(() => period = v ?? 'monthly'),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Next due: ${DateFormat.yMMMd().format(nextDue)}'),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: nextDue,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) setLocal(() => nextDue = picked);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                final m = merchant.text.trim();
                final a = parseAmount(amount.text);
                if (m.isEmpty || a == null || a <= 0) return;
                ref.read(transactionRepositoryProvider).insertRecurring(
                      merchant: m,
                      amount: a,
                      period: period,
                      nextDue: nextDue,
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

class _RecurringTile extends ConsumerWidget {
  const _RecurringTile({required this.recurring, required this.due});

  final RecurringTransaction recurring;
  final bool due;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        recurring.active ? Icons.repeat : Icons.pause_circle_outline,
        color: due ? Theme.of(context).colorScheme.error : null,
      ),
      title: Text(recurring.merchant),
      subtitle: Text('${_currency.format(recurring.amount)} · ${_periodLabel(recurring.period)}'
          ' · next ${DateFormat.yMMMd().format(recurring.nextDue)}',
          style: moneyStyle.copyWith(fontSize: 13)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (due)
            FilledButton.tonal(
              onPressed: () async {
                await ref.read(transactionRepositoryProvider).payRecurring(recurring);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text('Paid ${recurring.merchant}')));
              },
              child: const Text('Pay'),
            ),
          IconButton(
            tooltip: recurring.active ? 'Pause' : 'Resume',
            icon: Icon(recurring.active ? Icons.pause_circle_outline : Icons.play_circle_outline),
            onPressed: () => ref.read(transactionRepositoryProvider).setRecurringActive(
                  recurring.id,
                  !recurring.active,
                ),
          ),
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text('Delete "${recurring.merchant}"?'),
                  content: const Text('This permanently removes the subscription.'),
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
                await ref.read(transactionRepositoryProvider).deleteRecurring(recurring.id);
              }
            },
          ),
        ],
      ),
    );
  }

  String _periodLabel(String p) => switch (p) {
        'daily' => 'daily',
        'weekly' => 'weekly',
        'monthly' => 'monthly',
        'yearly' => 'yearly',
        _ => p,
      };
}
