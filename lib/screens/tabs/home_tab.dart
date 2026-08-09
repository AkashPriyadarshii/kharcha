import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme.dart';
import '../../data/database.dart';
import '../../data/transaction_repository.dart';
import '../../widgets/income_expense_toggle.dart';

final _currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

/// Aggregates the dashboard figures in one async snapshot.
class HomeSummary {
  const HomeSummary({
    required this.today,
    required this.month,
    required this.income,
    required this.budgetLeft,
    required this.byCategory,
    required this.trend,
  });

  final double today;
  final double month;
  final double income;
  final double budgetLeft;
  final List<(Category, double)> byCategory;
  final List<(String, double)> trend;
}

/// The user's display name. Google sign-in stores it under `full_name`;
/// the in-app edit writes `name`. Check both.
String? _userName() {
  final meta = Supabase.instance.client.auth.currentUser?.userMetadata;
  if (meta == null) return null;
  return (meta['name'] as String?) ?? (meta['full_name'] as String?);
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
      income: await repo.monthIncome(now),
      budgetLeft: (budgetTotal - spentOnBudgeted).clamp(0, double.infinity),
      byCategory: byCategory,
      trend: await repo.monthlyTrend(now),
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
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _GreetingHeader(name: _userName()),
          const SizedBox(height: 16),
          _HeroPanel(summary: s),
          const SizedBox(height: 16),
          _IncomeExpenseRow(summary: s),
          const SizedBox(height: 24),
          SectionTitle('Monthly trend'),
          const SizedBox(height: 8),
          _TrendCard(trend: s.trend),
          const SizedBox(height: 24),
          SectionTitle('This month by category'),
          const SizedBox(height: 8),
          if (s.byCategory.isEmpty)
            Text('No spends this month yet.', style: Theme.of(context).textTheme.bodyMedium)
          else
            for (final c in s.byCategory)
              _CategoryBar(category: c.$1, amount: c.$2, max: s.byCategory.first.$2),
          const SizedBox(height: 24),
          SectionTitle('Recent transactions'),
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

/// Greeting + the user's name (Cashew-style identity header). "Good evening,
/// Akash." — the app talks to you, not at you.
class _GreetingHeader extends StatelessWidget {
  const _GreetingHeader({required this.name});

  final String? name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(greeting, style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              if (name != null)
                Text(name!, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ],
    );
  }
}

/// Income / expense as sibling cards — income gets its own mint card, not a
/// footnote in the hero.
class _IncomeExpenseRow extends StatelessWidget {
  const _IncomeExpenseRow({required this.summary});

  final HomeSummary summary;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'Income this month',
            amount: summary.income,
            color: incomeGreen,
            icon: Icons.arrow_downward,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: 'Spent today',
            amount: summary.today,
            color: expenseRed,
            icon: Icons.receipt_long_outlined,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.amount, required this.color, required this.icon});

  final String label;
  final double amount;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 8),
            Text(label, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 4),
            Text(
              _currency.format(amount),
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact 6-month spend line — the trend is what the hero number can't say.
class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.trend});

  final List<(String, double)> trend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (trend.isEmpty) return const SizedBox.shrink();
    final max = trend.map((t) => t.$2).fold(0.0, (a, b) => b > a ? b : a);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
        child: SizedBox(
          height: 140,
          child: LineChart(
            LineChartData(
              minY: 0,
              maxY: max <= 0 ? 1 : max * 1.2,
              gridData: FlGridData(show: true, drawVerticalLine: false),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 1,
                    getTitlesWidget: (v, _) {
                      final i = v.toInt();
                      if (i < 0 || i >= trend.length) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(trend[i].$1, style: theme.textTheme.labelSmall),
                      );
                    },
                  ),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: [for (var i = 0; i < trend.length; i++) FlSpot(i.toDouble(), trend[i].$2)],
                  isCurved: true,
                  barWidth: 3,
                  color: theme.colorScheme.primary,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(show: true, color: theme.colorScheme.primary.withValues(alpha: 0.12)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RecentTile extends StatelessWidget {
  const _RecentTile({required this.transaction});

  final Transaction transaction;

  @override
  Widget build(BuildContext context) {
    final income = transaction.isIncome;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: Icon(
        income ? Icons.arrow_downward : Icons.receipt_long_outlined,
        size: 20,
        color: income ? incomeGreen : expenseRed,
      ),
      title: Text(transaction.merchant),
      subtitle: income ? const Text('Income') : null,
      trailing: Text(
        '${income ? '+ ' : ''}${_currency.format(transaction.amount)}',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: income ? incomeGreen : expenseRed,
            ),
      ),
    );
  }
}

/// Signature hero: a deep green panel whose headline is the month spend —
/// the ₹ figure is the point of every screen. Amber only when over budget.
class _HeroPanel extends ConsumerStatefulWidget {
  const _HeroPanel({required this.summary});

  final HomeSummary summary;

  @override
  ConsumerState<_HeroPanel> createState() => _HeroPanelState();
}

class _HeroPanelState extends ConsumerState<_HeroPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void initState() {
    super.initState();
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final over = widget.summary.budgetLeft <= 0;
    // Count-up from ₹0 → month spend on load (and on every data refresh).
    final animated = Tween(begin: 0.0, end: widget.summary.month)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: over ? const Color(0xFF2A1606) : const Color(0xFF0A3D2E),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0x14FFFFFF),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'THIS MONTH',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: const Color(0xB3FFFFFF),
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              Text('Today ${_currency.format(widget.summary.today)}',
                  style: theme.textTheme.labelMedium?.copyWith(color: const Color(0xB3FFFFFF))),
            ],
          ),
          const SizedBox(height: 20),
          AnimatedBuilder(
            animation: _ctrl,
            builder: (context, _) => Text(
              _currency.format(animated.value),
              style: moneyStyle.copyWith(
                fontSize: 40,
                height: 1.0,
                color: over ? const Color(0xFFFFC266) : Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            over ? 'Over budget — time to slow down' : 'Budget left ${_currency.format(widget.summary.budgetLeft)}',
            style: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xCCFFFFFF)),
          ),
          // Income figure — mint (light green) for contrast on the dark panel.
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.arrow_downward, size: 14, color: Color(0xFF7EE0A8)),
              const SizedBox(width: 6),
              Text('Income this month',
                  style: theme.textTheme.bodySmall?.copyWith(color: const Color(0xB3FFFFFF))),
              const Spacer(),
              Text(
                _currency.format(widget.summary.income),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF7EE0A8),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          // Signature ₹ strip — quiet, bottom edge of the panel.
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: 28,
              height: 3,
              decoration: BoxDecoration(
                color: scheme.tertiary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
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
    Color(int.parse('FF${category.color.replaceFirst('#', '')}', radix: 16));
