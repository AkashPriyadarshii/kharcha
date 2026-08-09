import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/money.dart';
import '../core/theme.dart';
import '../data/database.dart';
import '../data/transaction_repository.dart';

final _currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

/// Credit/debt ledger: money lent to / borrowed from people, with settle.
class DebtsScreen extends ConsumerStatefulWidget {
  const DebtsScreen({super.key});

  @override
  ConsumerState<DebtsScreen> createState() => _DebtsScreenState();
}

class _DebtsScreenState extends ConsumerState<DebtsScreen> {
  Future<void> _confirmDelete(BuildContext context, Debt d) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete entry with ${d.name}?'),
        content: const Text('This permanently removes the record.'),
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
      await ref.read(transactionRepositoryProvider).deleteDebt(d.id);
    }
  }

  Future<void> _showAdd() async {
    final name = TextEditingController();
    final amount = TextEditingController();
    final note = TextEditingController();
    var isLent = true;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('New entry'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('I lent')),
                  ButtonSegment(value: false, label: Text('I borrowed')),
                ],
                selected: {isLent},
                onSelectionChanged: (s) => setDialogState(() => isLent = s.first),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: name,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Person'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amount,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Amount', prefixText: '₹ '),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: note,
                decoration: const InputDecoration(labelText: 'Note (optional)'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final a = parseAmount(amount.text);
                if (name.text.trim().isEmpty || a == null || a <= 0) return;
                await ref.read(transactionRepositoryProvider).insertDebt(
                      name: name.text.trim(),
                      amount: a,
                      isLent: isLent,
                      note: note.text.trim().isEmpty ? null : note.text.trim(),
                    );
                if (context.mounted) Navigator.of(context).pop();
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final debts = ref.watch(debtsProvider).value ?? const <Debt>[];
    final lent = debts.where((d) => d.isLent && !d.settled).fold(0.0, (s, d) => s + d.amount);
    final borrowed = debts.where((d) => !d.isLent && !d.settled).fold(0.0, (s, d) => s + d.amount);
    return Scaffold(
      appBar: AppBar(title: const Text('Credit & debt')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAdd,
        icon: const Icon(Icons.add),
        label: const Text('New'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          // Net position strip — the one hero figure.
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0A3D2E),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('YOU ARE OWED', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: const Color(0x99FFFFFF), letterSpacing: 1.2, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(_currency.format(lent), style: moneyStyle.copyWith(fontSize: 22, color: const Color(0xFF8BE0B8))),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('YOU OWE', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: const Color(0x99FFFFFF), letterSpacing: 1.2, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(_currency.format(borrowed), style: moneyStyle.copyWith(fontSize: 22, color: const Color(0xFFFFC266))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (debts.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Column(
                children: [
                  const Text('🤝', style: TextStyle(fontSize: 44)),
                  const SizedBox(height: 12),
                  Text('Nothing tracked yet.', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text('Lent ₹500 to Ravi? Borrowed from Priya?', style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            )
          else
            for (final d in debts)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: d.isLent ? const Color(0xFF0A6B4D) : const Color(0xFFB08900),
                  child: Icon(d.isLent ? Icons.south_west : Icons.north_east, color: Colors.white, size: 18),
                ),
                title: Text(d.name,
                    style: d.settled ? TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant) : null),
                subtitle: Text([d.note ?? '', d.isLent ? 'lent' : 'borrowed'].where((s) => s.isNotEmpty).join(' · ')),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_currency.format(d.amount),
                        style: moneyStyle.copyWith(
                          fontSize: 13,
                          color: d.settled ? Theme.of(context).colorScheme.onSurfaceVariant : null,
                        )),
                    IconButton(
                      icon: Icon(d.settled ? Icons.undo : Icons.check_circle_outline),
                      tooltip: d.settled ? 'Mark unsettled' : 'Mark settled',
                      onPressed: () => ref.read(transactionRepositoryProvider).setDebtSettled(d.id, !d.settled),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Delete',
                      onPressed: () => _confirmDelete(context, d),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
