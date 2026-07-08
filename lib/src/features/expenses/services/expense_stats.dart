import 'package:flutter/foundation.dart';
import 'package:ledgerly/src/core/money/money.dart';
import 'package:ledgerly/src/features/expenses/models/expense.dart';

/// Expenses summed over one calendar month.
@immutable
final class MonthlyExpense {
  const MonthlyExpense({required this.month, required this.total});

  /// First day of the month, midnight.
  final DateTime month;
  final Money total;
}

/// Pure expense aggregation.
///
/// Multi-currency policy (same as the dashboard): figures are computed in
/// the business profile's **default currency only**. Expenses in other
/// currencies are counted in [otherCurrencyCount] and excluded from the
/// monetary figures — no fake FX.
@immutable
final class ExpenseStats {
  const ExpenseStats({
    required this.currency,
    required this.thisMonth,
    required this.monthlyTotals,
    required this.otherCurrencyCount,
  });

  /// Currency all monetary figures are expressed in.
  final String currency;

  /// Total spent in the current calendar month.
  final Money thisMonth;

  /// Last [monthsOfHistory] months, oldest first; the last entry is the
  /// current month.
  final List<MonthlyExpense> monthlyTotals;

  /// Expenses excluded because they use a different currency.
  final int otherCurrencyCount;

  static const int monthsOfHistory = 6;

  static ExpenseStats compute({
    required List<Expense> expenses,
    required String currency,
    required DateTime now,
  }) {
    var thisMonth = Money.zero(currency);
    var otherCurrencyCount = 0;

    final months = List<DateTime>.generate(
      monthsOfHistory,
      (i) => DateTime(now.year, now.month - (monthsOfHistory - 1) + i),
    );
    final byMonth = <DateTime, Money>{
      for (final m in months) m: Money.zero(currency),
    };

    for (final expense in expenses) {
      if (expense.currency != currency) {
        otherCurrencyCount++;
        continue;
      }
      if (expense.date.year == now.year && expense.date.month == now.month) {
        thisMonth += expense.amount;
      }
      final bucket = DateTime(expense.date.year, expense.date.month);
      final current = byMonth[bucket];
      if (current != null) {
        byMonth[bucket] = current + expense.amount;
      }
    }

    return ExpenseStats(
      currency: currency,
      thisMonth: thisMonth,
      monthlyTotals: [
        for (final m in months) MonthlyExpense(month: m, total: byMonth[m]!),
      ],
      otherCurrencyCount: otherCurrencyCount,
    );
  }
}
