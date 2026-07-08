import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:ledgerly/src/core/formats.dart';
import 'package:ledgerly/src/features/dashboard/services/dashboard_stats.dart';
import 'package:ledgerly/src/features/expenses/services/expense_stats.dart';

/// Bar chart of collected revenue for the last six months, with an optional
/// paired expenses series (month buckets must align with [months]).
///
/// Chart geometry uses doubles (display only); all money math stays in
/// integer minor units upstream.
final class RevenueChart extends StatelessWidget {
  const RevenueChart({required this.months, this.expenses, super.key});

  final List<MonthlyRevenue> months;
  final List<MonthlyExpense>? expenses;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final expenseMonths = expenses;
    final showExpenses =
        expenseMonths != null && expenseMonths.any((m) => !m.total.isZero);

    var maxMinor = months.fold<int>(
      0,
      (max, m) => m.total.minorUnits > max ? m.total.minorUnits : max,
    );
    if (showExpenses) {
      maxMinor = expenseMonths.fold<int>(
        maxMinor,
        (max, m) => m.total.minorUnits > max ? m.total.minorUnits : max,
      );
    }
    final maxY = maxMinor == 0 ? 1.0 : maxMinor * 1.2;
    final expenseColor = scheme.error.withValues(alpha: 0.75);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 180,
          child: BarChart(
            BarChartData(
              maxY: maxY,
              alignment: BarChartAlignment.spaceAround,
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(),
                topTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= months.length) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          Formats.monthShort(months[index].month),
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      );
                    },
                  ),
                ),
              ),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => scheme.onSurface,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final isExpenseRod = showExpenses && rodIndex == 1;
                    final value = isExpenseRod
                        ? expenseMonths[group.x].total
                        : months[group.x].total;
                    return BarTooltipItem(
                      isExpenseRod ? '-${value.format()}' : value.format(),
                      TextStyle(
                        color: scheme.surface,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    );
                  },
                ),
              ),
              barGroups: [
                for (var i = 0; i < months.length; i++)
                  BarChartGroupData(
                    x: i,
                    barsSpace: 3,
                    barRods: [
                      BarChartRodData(
                        toY: months[i].total.minorUnits.toDouble(),
                        width: showExpenses ? 12 : 22,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(6),
                        ),
                        color: scheme.primary,
                        backDrawRodData: BackgroundBarChartRodData(
                          show: !showExpenses,
                          toY: maxY,
                          color: scheme.primary.withValues(alpha: 0.06),
                        ),
                      ),
                      if (showExpenses)
                        BarChartRodData(
                          toY: expenseMonths[i].total.minorUnits.toDouble(),
                          width: 12,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(6),
                          ),
                          color: expenseColor,
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        if (showExpenses) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendDot(color: scheme.primary, label: 'Revenue'),
              const SizedBox(width: 16),
              _LegendDot(color: expenseColor, label: 'Expenses'),
            ],
          ),
        ],
      ],
    );
  }
}

final class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}
