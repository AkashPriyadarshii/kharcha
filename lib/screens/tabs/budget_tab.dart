import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../data/database.dart';
import '../../data/transaction_repository.dart';
import 'home_tab.dart' show categoryColor;

final _currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

/// Spend relative to budget → alert stage. Pure — unit-testable.
enum BudgetAlert { ok, warn50, warn80, over }

BudgetAlert budgetAlert(double ratio) {
  if (ratio >= 1) return BudgetAlert.over;
  if (ratio >= 0.8) return BudgetAlert.warn80;
  if (ratio >= 0.5) return BudgetAlert.warn50;
  return BudgetAlert.ok;
}

/// Per-category monthly budgets with progress and 50/80/100 alerts.
class BudgetTab extends ConsumerWidget {
  const BudgetTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgets = ref.watch(budgetsProvider);
    final spend = ref.watch(monthSpendProvider).value ?? const <(Category, double)>[];
    return budgets.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Could not load budgets.\n$e')),
      data: (list) => list.isEmpty
          ? _BudgetEmpty(onAdd: () => _showBudgetDialog(context, ref))
          : _BudgetList(
              budgets: list,
              spend: spend,
              onAdd: () => _showBudgetDialog(context, ref),
              onEdit: (budget, category) => _showBudgetDialog(context, ref, budget: budget, category: category),
              onDelete: (budget) => _deleteBudget(context, ref, budget),
            ),
    );
  }
}

Future<void> _showBudgetDialog(
  BuildContext context,
  WidgetRef ref, {
  Budget? budget,
  Category? category,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _BudgetDialog(existing: budget, category: category),
  );
}

Future<void> _deleteBudget(BuildContext context, WidgetRef ref, Budget budget) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Remove budget?'),
      content: const Text('This only deletes the monthly limit, not your expenses.'),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Remove')),
      ],
    ),
  );
  if (confirmed == true) {
    await ref.read(transactionRepositoryProvider).deleteBudget(budget.id);
  }
}

class _BudgetEmpty extends StatelessWidget {
  const _BudgetEmpty({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎯', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            Text('No budgets yet.', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text('Set monthly limits per category.', textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Add budget'),
            ),
          ],
        ),
      ),
    );
  }
}

class _BudgetList extends StatelessWidget {
  const _BudgetList({
    required this.budgets,
    required this.spend,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  final List<(Budget, Category)> budgets;
  final List<(Category, double)> spend;
  final VoidCallback onAdd;
  final void Function(Budget, Category) onEdit;
  final void Function(Budget) onDelete;

  double _spentFor(int categoryId) {
    for (final s in spend) {
      if (s.$1.id == categoryId) return s.$2;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        const SectionTitle('Monthly budgets'),
        const SizedBox(height: 8),
        for (final (budget, category) in budgets)
          _BudgetTile(
            budget: budget,
            category: category,
            spent: _spentFor(category.id),
            onEdit: () => onEdit(budget, category),
            onDelete: () => onDelete(budget),
          ),
        ListTile(
          leading: const Icon(Icons.add_circle_outline),
          title: const Text('Add budget'),
          onTap: onAdd,
        ),
      ],
    );
  }
}

class _BudgetTile extends StatelessWidget {
  const _BudgetTile({
    required this.budget,
    required this.category,
    required this.spent,
    required this.onEdit,
    required this.onDelete,
  });

  final Budget budget;
  final Category category;
  final double spent;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ratio = budget.amount <= 0 ? 0.0 : spent / budget.amount;
    final scheme = Theme.of(context).colorScheme;
    final color = switch (budgetAlert(ratio)) {
      BudgetAlert.ok => scheme.primary,
      BudgetAlert.warn50 => const Color(0xFFB08900), // amber, spend-tracked
      BudgetAlert.warn80 => const Color(0xFFE07B00), // orange
      BudgetAlert.over => scheme.error,
    };
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: categoryColor(category),
        child: Text(category.emoji),
      ),
      title: Text(category.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio.clamp(0.0, 1.0),
              minHeight: 8,
              color: color,
              backgroundColor: color.withValues(alpha: 0.15),
            ),
          ),
          const SizedBox(height: 4),
          Text('${_currency.format(spent)} / ${_currency.format(budget.amount)}',
              style: moneyStyle.copyWith(fontSize: 13)),
        ],
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'edit', child: Text('Edit')),
          PopupMenuItem(value: 'delete', child: Text('Delete')),
        ],
      ),
      onTap: onEdit,
      isThreeLine: true,
    );
  }
}

class _BudgetDialog extends ConsumerStatefulWidget {
  const _BudgetDialog({this.existing, this.category});

  final Budget? existing;
  final Category? category;

  @override
  ConsumerState<_BudgetDialog> createState() => _BudgetDialogState();
}

class _BudgetDialogState extends ConsumerState<_BudgetDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amount;
  int? _categoryId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _categoryId = widget.existing?.categoryId ?? widget.category?.id;
    _amount = TextEditingController(text: widget.existing?.amount.toString() ?? '');
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final categoryId = _categoryId;
    if (categoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick a category.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(transactionRepositoryProvider).upsertBudget(
            categoryId: categoryId,
            amount: double.parse(_amount.text),
          );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      setState(() => _saving = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not save: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider).value ?? const <Category>[];
    return AlertDialog(
      title: Text(widget.existing == null ? 'Add budget' : 'Edit budget'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<int>(
              initialValue: _categoryId,
              decoration: const InputDecoration(labelText: 'Category'),
              items: [
                for (final c in categories)
                  DropdownMenuItem(value: c.id, child: Text('${c.emoji}  ${c.name}')),
              ],
              onChanged: (v) => setState(() => _categoryId = v),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _amount,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              decoration: const InputDecoration(labelText: 'Monthly limit', prefixText: '₹ '),
              validator: (value) {
                final amount = double.tryParse(value ?? '');
                if (amount == null || amount <= 0) return 'Enter an amount greater than zero.';
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Save'),
        ),
      ],
    );
  }
}
