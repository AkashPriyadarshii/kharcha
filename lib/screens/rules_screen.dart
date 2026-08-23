import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../data/transaction_repository.dart';

/// Manage Auto-categorization Rules (Pennywise feature)
class RulesScreen extends ConsumerStatefulWidget {
  const RulesScreen({super.key});

  @override
  ConsumerState<RulesScreen> createState() => _RulesScreenState();
}

class _RulesScreenState extends ConsumerState<RulesScreen> {
  @override
  Widget build(BuildContext context) {
    final rules = ref.watch(rulesProvider).value ?? const <Rule>[];
    final categories = ref.watch(categoriesProvider).value ?? const <Category>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Rules'),
      ),
      body: rules.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.rule_folder, size: 64, color: Theme.of(context).colorScheme.outline),
                    const SizedBox(height: 16),
                    const Text('No rules yet.', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text(
                      'Rules automatically categorize expenses when they are captured from SMS or notifications.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              itemCount: rules.length,
              itemBuilder: (context, index) {
                final rule = rules[index];
                final cat = categories.where((c) => c.id == rule.categoryId).firstOrNull;
                return ListTile(
                  leading: const Icon(Icons.bolt),
                  title: Text(rule.pattern),
                  subtitle: Text(cat == null ? 'Unknown category' : '→ ${cat.emoji} ${cat.name}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _deleteRule(rule),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addRule(categories),
        icon: const Icon(Icons.add),
        label: const Text('New Rule'),
      ),
    );
  }

  Future<void> _deleteRule(Rule rule) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete rule?'),
        content: Text('Remove rule for "${rule.pattern}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    
    final repo = ref.read(transactionRepositoryProvider);
    await repo.deleteRule(rule.id);
  }

  Future<void> _addRule(List<Category> categories) async {
    final formKey = GlobalKey<FormState>();
    final pattern = TextEditingController();
    int? categoryId;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Rule'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: pattern,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Merchant Keyword / Regex',
                  hintText: 'e.g. swiggy, zomato, amazon',
                ),
                validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                decoration: const InputDecoration(labelText: 'Target Category'),
                items: [
                  for (final c in categories)
                    DropdownMenuItem(value: c.id, child: Text('${c.emoji}  ${c.name}')),
                ],
                onChanged: (v) => categoryId = v,
                validator: (v) => v == null ? 'Select a category' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == true && categoryId != null) {
      final repo = ref.read(transactionRepositoryProvider);
      await repo.insertRule(pattern.text.trim(), categoryId!);
    }
  }
}
