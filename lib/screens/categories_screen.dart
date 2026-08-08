import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../data/transaction_repository.dart';
import '../widgets/category_icon.dart';

const _palette = <String>[
  '#E86A17', '#2E86AB', '#9B5DE5', '#F4B942', '#06D6A0',
  '#EF476F', '#4CAF50', '#E63946', '#FF9F1C', '#8D99AE', '#0077B6', '#B5179E',
];

const _emojis = <String>['🍔', '🚗', '🛍️', '⚡', '📱', '🏠', '🛒', '💊', '🎬', '📦', '☕', '🎓', '🐾', '🎁', '✈️'];

/// Lists all categories; add/edit/delete custom ones. Builtins are read-only.
class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  int _tab = 0; // 0 = expense, 1 = income

  Future<void> _showEditor([Category? existing]) async {
    final name = TextEditingController(text: existing?.name);
    var emoji = existing?.emoji ?? '📦';
    var color = existing?.color ?? _palette.first;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'New category' : 'Edit category'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 4,
                  children: [
                    for (final e in _emojis)
                      InkWell(
                        onTap: () => setDialogState(() => emoji = e),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: e == emoji ? Theme.of(context).colorScheme.primaryContainer : null,
                          ),
                          child: Text(e),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  for (final c in _palette)
                    InkWell(
                      onTap: () => setDialogState(() => color = c),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Color(int.parse(c.replaceFirst('#', '0xFF'))),
                          shape: BoxShape.circle,
                          border: c == color
                              ? Border.all(color: Theme.of(context).colorScheme.onSurface, width: 2)
                              : null,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          actions: [
            if (existing != null)
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _delete(existing);
                },
                child: const Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final trimmed = name.text.trim();
                if (trimmed.isEmpty) return;
                final repo = ref.read(transactionRepositoryProvider);
                if (existing == null) {
                  await repo.insertCategory(name: trimmed, emoji: emoji, color: color);
                } else {
                  await repo.updateCategory(existing.id, name: trimmed, emoji: emoji, color: color);
                }
                if (context.mounted) Navigator.of(context).pop();
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _delete(Category c) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete "${c.name}"?'),
        content: const Text('Its transactions stay but become uncategorized.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(transactionRepositoryProvider).deleteCategory(c.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider).value ?? const <Category>[];
    return Scaffold(
      appBar: AppBar(title: const Text('Categories')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showEditor(),
        icon: const Icon(Icons.add),
        label: const Text('New'),
      ),
      body: categories.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 0, label: Text('Expense'), icon: Icon(Icons.remove_circle_outline)),
                    ButtonSegment(value: 1, label: Text('Income'), icon: Icon(Icons.add_circle_outline)),
                  ],
                  selected: {_tab},
                  onSelectionChanged: (s) => setState(() => _tab = s.first),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 96, top: 8),
                    children: [
                      for (final c in categories.where(
                        (c) => _tab == 0 ? !c.isIncome : c.isIncome,
                      ))
                        _CategoryTile(category: c, onEdit: _showEditor),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.category, required this.onEdit});

  final Category category;
  final ValueChanged<Category> onEdit;

  @override
  Widget build(BuildContext context) {
    final c = category;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Color(int.parse(c.color.replaceFirst('#', '0xFF'))),
        child: CategoryIcon(
          categoryName: c.name,
          emojiFallback: c.emoji,
          size: 20,
          color: Colors.white,
        ),
      ),
      title: Text(c.name),
      subtitle: c.isCustom ? null : const Text('Built-in'),
      trailing: c.isCustom ? const Icon(Icons.edit_outlined) : null,
      onTap: c.isCustom ? () => onEdit(c) : null,
    );
  }
}
