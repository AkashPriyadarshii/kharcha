import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../core/transaction_filter.dart';
import '../../data/database.dart';
import '../../data/transaction_repository.dart';
import '../../widgets/income_expense_toggle.dart';

final _currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
final _dateFormat = DateFormat('d MMM');

/// Date presets for the transactions list filter.
enum _DatePreset { all, today, month, last30, custom }

/// Full transactions list with search + filters, newest first.
class TransactionsTab extends ConsumerStatefulWidget {
  const TransactionsTab({super.key});

  @override
  ConsumerState<TransactionsTab> createState() => _TransactionsTabState();
}

class _TransactionsTabState extends ConsumerState<TransactionsTab> {
  final _searchController = TextEditingController();
  int? _categoryId;
  String? _merchant;
  String? _paymentMethod;
  bool? _isIncome;
  _DatePreset _datePreset = _DatePreset.all;
  DateTimeRange? _customRange;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Inclusive range for the active date preset. Null bounds = unbounded.
  (DateTime?, DateTime?) get _dateRange {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    DateTime endOfDay(DateTime d) =>
        d.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1));
    switch (_datePreset) {
      case _DatePreset.all:
        return (null, null);
      case _DatePreset.today:
        return (today, endOfDay(today));
      case _DatePreset.month:
        return (
          DateTime(now.year, now.month, 1),
          endOfDay(DateTime(now.year, now.month + 1, 0)),
        );
      case _DatePreset.last30:
        return (today.subtract(const Duration(days: 29)), endOfDay(today));
      case _DatePreset.custom:
        final r = _customRange;
        return r == null ? (null, null) : (r.start, endOfDay(r.end));
    }
  }

  Future<void> _onDatePreset(_DatePreset? preset) async {
    if (preset == null) return;
    if (preset == _DatePreset.custom) {
      final now = DateTime.now();
      final range = await showDateRangePicker(
        context: context,
        firstDate: DateTime(now.year - 5),
        lastDate: DateTime(now.year + 1, 12, 31),
        initialDateRange: _customRange ?? DateTimeRange(start: now, end: now),
      );
      if (range == null) return; // Cancelled → keep current filter.
      setState(() {
        _datePreset = preset;
        _customRange = range;
      });
    } else {
      setState(() => _datePreset = preset);
    }
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _categoryId = null;
      _merchant = null;
      _paymentMethod = null;
      _isIncome = null;
      _datePreset = _DatePreset.all;
      _customRange = null;
    });
  }

  String _dateLabel(_DatePreset p) => switch (p) {
        _DatePreset.all => 'All time',
        _DatePreset.today => 'Today',
        _DatePreset.month => 'This month',
        _DatePreset.last30 => 'Last 30 days',
        _DatePreset.custom => _customRange == null
            ? 'Custom range'
            : '${_dateFormat.format(_customRange!.start)} – ${_dateFormat.format(_customRange!.end)}',
      };

  static String _methodLabel(String m) => m[0].toUpperCase() + m.substring(1);

  @override
  Widget build(BuildContext context) {
    final transactions = ref.watch(transactionsProvider);
    final categories = ref.watch(categoriesProvider).value ?? const <Category>[];
    return transactions.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Could not load expenses.\n$e')),
      data: (list) =>
          list.isEmpty ? const _EmptyState() : _buildList(context, list, categories),
    );
  }

  Widget _buildList(BuildContext context, List<Transaction> list, List<Category> categories) {
    final merchants = <String>{for (final t in list) t.merchant}.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    // Guard: a filtered merchant can outlive the rows that named it.
    final merchant = merchants.contains(_merchant) ? _merchant : null;
    final (from, to) = _dateRange;
    final filter = TransactionFilter(
      query: _searchController.text,
      categoryId: _categoryId,
      merchant: merchant,
      paymentMethod: _paymentMethod,
      isIncome: _isIncome,
      from: from,
      to: to,
    );
    final filtered = filter.apply(list);
    return Column(
      children: [
        _buildFilterBar(context, categories, merchants, merchant),
        Expanded(
          child: filtered.isEmpty
              ? _NoMatches(onClear: _clearFilters)
              : _TransactionList(transactions: filtered, categories: categories),
        ),
      ],
    );
  }

  Widget _buildFilterBar(
    BuildContext context,
    List<Category> categories,
    List<String> merchants,
    String? merchant,
  ) {
    final filterActive = _searchController.text.isNotEmpty ||
        _categoryId != null ||
        merchant != null ||
        _paymentMethod != null ||
        _isIncome != null ||
        _datePreset != _DatePreset.all;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search merchant or note',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'Clear search',
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                    ),
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterDropdown<int>(
                  value: _categoryId,
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All categories')),
                    for (final c in categories)
                      DropdownMenuItem(value: c.id, child: Text('${c.emoji} ${c.name}')),
                  ],
                  onChanged: (v) => setState(() => _categoryId = v),
                ),
                const SizedBox(width: 24),
                _FilterDropdown<String>(
                  value: merchant,
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All merchants')),
                    for (final m in merchants) DropdownMenuItem(value: m, child: Text(m)),
                  ],
                  onChanged: (v) => setState(() => _merchant = v),
                ),
                const SizedBox(width: 24),
                _FilterDropdown<String>(
                  value: _paymentMethod,
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All methods')),
                    for (final m in TransactionRepository.paymentMethods)
                      DropdownMenuItem(value: m, child: Text(_methodLabel(m))),
                  ],
                  onChanged: (v) => setState(() => _paymentMethod = v),
                ),
                const SizedBox(width: 24),
                _FilterDropdown<bool>(
                  value: _isIncome,
                  items: const [
                    DropdownMenuItem(value: null, child: Text('All types')),
                    DropdownMenuItem(value: false, child: Text('Expenses')),
                    DropdownMenuItem(value: true, child: Text('Income')),
                  ],
                  onChanged: (v) => setState(() => _isIncome = v),
                ),
                const SizedBox(width: 24),
                _FilterDropdown<_DatePreset>(
                  value: _datePreset,
                  items: [
                    for (final p in _DatePreset.values)
                      DropdownMenuItem(value: p, child: Text(_dateLabel(p))),
                  ],
                  onChanged: _onDatePreset,
                ),
              ],
            ),
          ),
          if (filterActive)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _clearFilters,
                child: const Text('Clear filters'),
              ),
            ),
        ],
      ),
    );
  }
}

/// Compact unlabeled dropdown (an "All X" item doubles as the placeholder).
class _FilterDropdown<T> extends StatelessWidget {
  const _FilterDropdown({required this.value, required this.items, required this.onChanged});

  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButton<T>(
      value: value,
      isDense: true,
      underline: const SizedBox.shrink(),
      borderRadius: BorderRadius.circular(12),
      items: items,
      onChanged: onChanged,
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
                : Color(int.parse('FF${cat.color.replaceFirst('#', '')}', radix: 16)),
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
            '${t.isIncome ? '+ ' : ''}${_currency.format(t.amount)}',
            style: moneyStyle.copyWith(
              fontSize: Theme.of(context).textTheme.titleMedium?.fontSize,
              color: t.isIncome ? incomeGreen : expenseRed,
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

class _NoMatches extends StatelessWidget {
  const _NoMatches({required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🔍', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            Text('No matching expenses.', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text('Try a different search or filter.', textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FilledButton.tonal(onPressed: onClear, child: const Text('Clear filters')),
          ],
        ),
      ),
    );
  }
}
