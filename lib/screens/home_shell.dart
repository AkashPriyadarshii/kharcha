import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/capture_inbox.dart';
import '../data/database.dart';
import '../data/transaction_repository.dart';
import 'quick_add_dialog.dart';

final _currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
final _dateFormat = DateFormat('d MMM');

/// Main shell: transactions list + FAB (quick-add) + full-form entry.
/// Drains the UPI inbox on startup (captures expenses added while closed).
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  @override
  void initState() {
    super.initState();
    _drainInbox();
  }

  Future<void> _drainInbox() async {
    try {
      final repo = ref.read(transactionRepositoryProvider);
      await drainCaptureInbox(inbox: await captureInboxFile(), repo: repo);
    } catch (_) {
      // Opportunistic; never block the shell on a capture failure.
    }
  }

  Future<void> _signOut(BuildContext context) async {
    await Supabase.instance.client.auth.signOut();
  }

  void _quickAdd(BuildContext context) {
    showDialog<void>(context: context, builder: (_) => const QuickAddDialog());
  }

  @override
  Widget build(BuildContext context) {
    final transactions = ref.watch(transactionsProvider);
    final categories = ref.watch(categoriesProvider).value ?? const <Category>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kharcha'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_box_outlined),
            tooltip: 'Add expense',
            onPressed: () => context.push('/add'),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_active_outlined),
            tooltip: 'Auto-capture UPI payments',
            onPressed: () => context.push('/enable-capture'),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () => _signOut(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _quickAdd(context),
        icon: const Icon(Icons.add),
        label: const Text('Quick add'),
      ),
      body: transactions.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load expenses.\n$e')),
        data: (list) => list.isEmpty ? _EmptyState(onAdd: () => _quickAdd(context)) : _TransactionList(
              transactions: list,
              categories: categories,
            ),
      ),
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
            backgroundColor: Color(int.parse('FF${cat?.color ?? '8D99AE'}', radix: 16)),
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
  const _EmptyState({required this.onAdd});

  final VoidCallback onAdd;

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
            Text(
              'No expenses yet.',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Add your first one — or wait, UPI notifications will do it for you.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Add expense'),
            ),
          ],
        ),
      ),
    );
  }
}
