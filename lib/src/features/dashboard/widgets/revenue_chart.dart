import 'package:core_theme/core_theme.dart';
import 'package:core_ui/core_ui.dart';
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
    final c = SuiteColors.of(context);
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
    final labelStyle = AppTextStyles.caption.copyWith(color: c.textTertiary);
    final lastIndex = months.length - 1;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 160,
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
                          style: index == lastIndex
                              ? labelStyle.copyWith(color: c.textPrimary)
                              : labelStyle,
                        ),
                      );
                    },
                  ),
                ),
              ),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => c.textPrimary,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final isExpenseRod = showExpenses && rodIndex == 1;
                    final value = isExpenseRod
                        ? expenseMonths[group.x].total
                        : months[group.x].total;
                    return BarTooltipItem(
                      isExpenseRod ? '-${value.format()}' : value.format(),
                      AppTextStyles.caption.copyWith(
                        color: c.surface,
                        fontWeight: FontWeight.w600,
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
                        width: showExpenses ? 12 : 24,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(5),
                        ),
                        color: c.accent,
                        backDrawRodData: BackgroundBarChartRodData(
                          show: !showExpenses,
                          toY: maxY,
                          color: c.surfaceAlt,
                        ),
                      ),
                      if (showExpenses)
                        BarChartRodData(
                          toY: expenseMonths[i].total.minorUnits.toDouble(),
                          width: 12,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(5),
                          ),
                          color: c.textTertiary,
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        if (showExpenses) ...[
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 96,
                child: ChartLegendRow(color: c.accent, label: 'Revenue'),
              ),
              SizedBox(
                width: 96,
                child: ChartLegendRow(color: c.textTertiary, label: 'Expenses'),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
