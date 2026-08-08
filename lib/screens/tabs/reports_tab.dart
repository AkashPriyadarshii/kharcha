import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../data/database.dart';
import '../../data/transaction_repository.dart';
import 'home_tab.dart' show categoryColor;

final _currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

/// Reports: spend by category (pie), monthly trend (line), merchant ranking.
class ReportsTab extends ConsumerWidget {
  const ReportsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(monthSpendProvider);
    final trend = ref.watch(monthlyTrendProvider);
    final merchants = ref.watch(merchantRankingProvider);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        const SectionTitle('This month by category'),
        const SizedBox(height: 8),
        if (month.value == null)
          const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
        else if (month.value!.isEmpty)
          Text('No spends this month yet.', style: Theme.of(context).textTheme.bodyMedium)
        else
          _CategoryPie(categories: month.value!),
        const SizedBox(height: 24),
        const SectionTitle('Monthly trend'),
        const SizedBox(height: 8),
        if (trend.value == null)
          const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
        else
          _MonthlyTrendLine(trend: trend.value!),
        const SizedBox(height: 24),
        const SectionTitle('Top merchants'),
        const SizedBox(height: 8),
        if (merchants.value == null)
          const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
        else if (merchants.value!.isEmpty)
          Text('No merchants yet.', style: Theme.of(context).textTheme.bodyMedium)
        else
          for (final (name, amount, count) in merchants.value!) _MerchantRow(name: name, amount: amount, count: count),
      ],
    );
  }
}

class _CategoryPie extends StatelessWidget {
  const _CategoryPie({required this.categories});

  final List<(Category, double)> categories;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = categories.fold(0.0, (s, c) => s + c.$2);
    return Column(
      children: [
        SizedBox(
          height: 220,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 48,
                  sections: [
                    for (final (cat, amount) in categories)
                      PieChartSectionData(
                        value: amount,
                        color: categoryColor(cat),
                        radius: 54,
                        title: '',
                      ),
                  ],
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Total', style: theme.textTheme.labelSmall),
                  Text(
                    _currency.format(total),
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: [
            for (final (cat, amount) in categories)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: categoryColor(cat), shape: BoxShape.circle)),
                  const SizedBox(width: 4),
                  Text(
                    '${cat.name} · ${_currency.format(amount)}'
                    '${total > 0 ? ' (${(amount / total * 100).round()}%)' : ''}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

class _MonthlyTrendLine extends StatelessWidget {
  const _MonthlyTrendLine({required this.trend});

  final List<(String, double)> trend;

  @override
  Widget build(BuildContext context) {
    final max = trend.map((t) => t.$2).fold(0.0, (a, b) => b > a ? b : a);
    return SizedBox(
      height: 200,
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
                  // fl_chart can tick outside the data range — skip those.
                  if (i < 0 || i >= trend.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(trend[i].$1, style: Theme.of(context).textTheme.labelSmall),
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
              color: Theme.of(context).colorScheme.primary,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(show: true, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15)),
            ),
          ],
        ),
      ),
    );
  }
}

class _MerchantRow extends StatelessWidget {
  const _MerchantRow({required this.name, required this.amount, required this.count});

  final String name;
  final double amount;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(name),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(_currency.format(amount), style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
          Text('$count×', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}
