import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme.dart';
import '../../widgets/brand_logo.dart';
import '../../data/database.dart';
import '../../data/transaction_repository.dart';
import '../../widgets/income_expense_toggle.dart';
import '../home_shell.dart';
import '../quick_add_dialog.dart';

final _currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

String formatTxnTime(DateTime dt) {
  final now = DateTime.now();
  final isToday = dt.year == now.year && dt.month == now.month && dt.day == now.day;
  if (isToday) {
    return 'Today, ${DateFormat('h:mm a').format(dt)}';
  }
  final yesterday = now.subtract(const Duration(days: 1));
  final isYesterday = dt.year == yesterday.year && dt.month == yesterday.month && dt.day == yesterday.day;
  if (isYesterday) {
    return 'Yesterday, ${DateFormat('h:mm a').format(dt)}';
  }
  return DateFormat('d MMM, h:mm a').format(dt);
}

/// Aggregates the dashboard figures in one async snapshot.
class HomeSummary {
  const HomeSummary({
    required this.today,
    required this.month,
    required this.income,
    required this.budgetLeft,
    required this.budgetTotal,
    required this.byCategory,
    required this.trend,
  });

  final double today;
  final double month;
  final double income;
  final double budgetLeft;

  /// Sum of all monthly budgets. 0 when none set — the hero must not claim
  /// "over budget" on a fresh install (budgetLeft clamps to 0 then).
  final double budgetTotal;
  final List<(Category, double)> byCategory;
  final List<(String, double)> trend;

  double get netBalance => income - month;
}

/// The user's display name. Google sign-in stores it under `full_name`;
/// the in-app edit writes `name`. Check both.
String? _userName() {
  try {
    final meta = Supabase.instance.client.auth.currentUser?.userMetadata;
    if (meta == null) return null;
    return (meta['name'] as String?) ?? (meta['full_name'] as String?);
  } catch (_) {
    return null;
  }
}

final homeSummaryProvider = StreamProvider<HomeSummary>((ref) {
  final repo = ref.watch(transactionRepositoryProvider);
  // Recompute the whole dashboard on every insert/delete — same "stale
  // aggregates" fix as the tab-level providers.
  return repo.watchAll().asyncMap((_) async {
    final now = DateTime.now();
    final byCategory = await repo.monthSpendByCategory(now);
    final budgets = await repo.watchBudgets().first;
    final budgetTotal = budgets.fold(0.0, (s, b) => s + b.$1.amount);

    var totalBudgetRemaining = 0.0;
    for (final (b, cat) in budgets) {
      final spentForCat = byCategory.firstWhere(
        (c) => c.$1.id == cat.id,
        orElse: () => (cat, 0.0),
      ).$2;
      final remaining = (b.amount - spentForCat).clamp(0.0, double.infinity);
      totalBudgetRemaining += remaining;
    }

    return HomeSummary(
      today: await repo.dayTotal(now),
      month: await repo.monthTotal(now),
      income: await repo.monthIncome(now),
      budgetLeft: totalBudgetRemaining,
      budgetTotal: budgetTotal,
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
    final categories = ref.watch(categoriesProvider).value ?? const <Category>[];
    final recent5 = recent.take(5).toList();
    return summary.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 36, color: expenseRed),
                  const SizedBox(height: 12),
                  Text('Could not load dashboard', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    'An error occurred while loading summary. Tap below to retry.',
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => ref.refresh(homeSummaryProvider),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      data: (s) => RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(homeSummaryProvider);
          ref.invalidate(transactionsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _GreetingHeader(name: _userName()),
            const SizedBox(height: 16),
            _HeroPanel(summary: s),
            const SizedBox(height: 24),
            const SectionTitle('Monthly trend'),
            const SizedBox(height: 8),
            _TrendCard(trend: s.trend),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SectionTitle('This month by category'),
                if (s.byCategory.isNotEmpty)
                  TextButton(
                    onPressed: () => ref.read(homeTabIndexProvider.notifier).state = 2,
                    child: const Text('Budgets'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (s.byCategory.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.pie_chart_outline, size: 24, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'No spends this month yet.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              for (final c in s.byCategory)
                _CategoryBar(
                  category: c.$1,
                  amount: c.$2,
                  total: s.month,
                  max: s.byCategory.first.$2,
                  onTap: () => ref.read(homeTabIndexProvider.notifier).state = 1,
                ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SectionTitle('Recent transactions'),
                if (recent5.isNotEmpty)
                  TextButton(
                    onPressed: () => ref.read(homeTabIndexProvider.notifier).state = 1,
                    child: const Text('View all'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (recent5.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Icon(Icons.receipt_long_outlined, size: 36, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(height: 12),
                      Text(
                        'No expenses yet',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Add your first expense or enable auto-capture to track UPI spends automatically.',
                        style: Theme.of(context).textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () => showDialog<void>(context: context, builder: (_) => const QuickAddDialog()),
                        icon: const Icon(Icons.add),
                        label: const Text('Quick add'),
                      ),
                    ],
                  ),
                ),
              )
            else
              for (final t in recent5)
                _RecentTile(
                  transaction: t,
                  category: categories.where((c) => c.id == t.categoryId).firstOrNull,
                ),
          ],
        ),
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

/// Signature hero: a deep green panel whose headline is the month spend —
/// the ₹ figure is the point of every screen. Ink-amber when over budget.
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
    final hasBudget = widget.summary.budgetTotal > 0;
    final over = hasBudget && widget.summary.budgetLeft <= 0;
    final net = widget.summary.netBalance;

    final animated = Tween(begin: 0.0, end: widget.summary.month)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    final cardBg = over ? const Color(0xFF331E05) : const Color(0xFF0A3D2E);
    final accentColor = over ? const Color(0xFFF59E0B) : Colors.white;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
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
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0x14FFFFFF),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Today ${_currency.format(widget.summary.today)}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: const Color(0xE6FFFFFF),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          AnimatedBuilder(
            animation: _ctrl,
            builder: (context, _) => Text(
              _currency.format(animated.value),
              style: moneyStyle.copyWith(
                fontSize: 38,
                height: 1.0,
                color: accentColor,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                over
                    ? Icons.warning_amber_rounded
                    : (hasBudget ? Icons.check_circle_outline : Icons.info_outline),
                size: 16,
                color: over ? const Color(0xFFF59E0B) : const Color(0xCCFFFFFF),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  over
                      ? 'Over budget by ${_currency.format(widget.summary.month - widget.summary.budgetTotal)}'
                      : hasBudget
                          ? 'Budget left ${_currency.format(widget.summary.budgetLeft)}'
                          : 'No budgets yet — tap Budget tab to set limits',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: over ? const Color(0xFFF59E0B) : const Color(0xCCFFFFFF),
                    fontWeight: over ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Integrated Income & Net stats row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0x14FFFFFF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.arrow_downward, size: 14, color: Color(0xFF7EE0A8)),
                      const SizedBox(width: 6),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Income',
                            style: theme.textTheme.labelSmall?.copyWith(color: const Color(0xB3FFFFFF)),
                          ),
                          Text(
                            _currency.format(widget.summary.income),
                            style: moneyStyle.copyWith(
                              fontSize: 13,
                              color: const Color(0xFF7EE0A8),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 26, color: const Color(0x24FFFFFF)),
                const SizedBox(width: 12),
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        net >= 0 ? Icons.savings_outlined : Icons.trending_down,
                        size: 14,
                        color: net >= 0 ? const Color(0xFF7EE0A8) : const Color(0xFFFFB4AB),
                      ),
                      const SizedBox(width: 6),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Net',
                            style: theme.textTheme.labelSmall?.copyWith(color: const Color(0xB3FFFFFF)),
                          ),
                          Text(
                            _currency.format(net),
                            style: moneyStyle.copyWith(
                              fontSize: 13,
                              color: net >= 0 ? const Color(0xFF7EE0A8) : const Color(0xFFFFB4AB),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact 6-month spend line with interactive touch tooltip.
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
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
        child: SizedBox(
          height: 140,
          child: LineChart(
            LineChartData(
              minY: 0,
              maxY: max <= 0 ? 1 : max * 1.2,
              gridData: const FlGridData(show: true, drawVerticalLine: false),
              lineTouchData: LineTouchData(
                enabled: true,
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((spot) {
                      final i = spot.x.toInt();
                      final label = (i >= 0 && i < trend.length) ? trend[i].$1 : '';
                      return LineTooltipItem(
                        '$label\n${_currency.format(spot.y)}',
                        const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      );
                    }).toList();
                  },
                ),
              ),
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
  const _RecentTile({
    required this.transaction,
    this.category,
  });

  final Transaction transaction;
  final Category? category;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final income = transaction.isIncome;
    final color = income ? incomeGreen : expenseRed;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/add', extra: transaction),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              BrandLogo(
                merchantName: transaction.merchant,
                fallbackEmoji: transaction.emoji ?? (income ? '💰' : (category?.emoji ?? '🧾')),
                fallbackColor: category?.color,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.merchant,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (income) 'Income' else if (category != null) category!.name,
                        formatTxnTime(transaction.txnDate),
                      ].join(' · '),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${income ? '+ ' : ''}${_currency.format(transaction.amount)}',
                style: moneyStyle.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryBar extends StatelessWidget {
  const _CategoryBar({
    required this.category,
    required this.amount,
    required this.total,
    required this.max,
    this.onTap,
  });

  final Category category;
  final double amount;
  final double total;
  final double max;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = categoryColor(category);
    final pct = total > 0 ? (amount / total * 100).toStringAsFixed(0) : '0';
    final barValue = max <= 0 ? 0.0 : (amount / max).clamp(0.0, 1.0);

    return Semantics(
      label: '${category.name}: ${_currency.format(amount)}, $pct percent of monthly spend',
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Row(
            children: [
              Text(category.emoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(category.name, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
                        Text('$pct%', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: barValue,
                        minHeight: 6,
                        color: color,
                        backgroundColor: color.withValues(alpha: 0.15),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _currency.format(amount),
                style: moneyStyle.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Parses a stored #RRGGBB into a [Color]. Shared by dashboard + budget bars.
Color categoryColor(Category category) =>
    Color(int.parse('FF${category.color.replaceFirst('#', '')}', radix: 16));
