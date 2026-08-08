import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (due.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '${due.length} due now',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (shown.isEmpty)
            Text('No subscriptions yet. Add a recurring payment to track it.',
                style: Theme.of(context).textTheme.bodyMedium)
          else
            for (final r in shown)
              _RecurringTile(recurring: r, due: r.active && !r.nextDue.isAfter(now)),
        ],
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
                final a = double.tryParse(amount.text.trim());
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
