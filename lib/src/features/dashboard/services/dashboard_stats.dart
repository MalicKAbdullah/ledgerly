import 'package:flutter/foundation.dart';
import 'package:ledgerly/src/core/money/money.dart';
import 'package:ledgerly/src/features/invoices/models/invoice.dart';
import 'package:ledgerly/src/features/invoices/services/invoice_calculator.dart';
import 'package:ledgerly/src/features/invoices/services/payment_math.dart';

/// Revenue collected in one calendar month.
@immutable
final class MonthlyRevenue {
  const MonthlyRevenue({required this.month, required this.total});

  /// First day of the month, midnight.
  final DateTime month;
  final Money total;
}

/// Pure dashboard aggregation.
///
/// Multi-currency policy (documented): statistics are computed in the
/// business profile's **default currency only**. Invoices in other
/// currencies are counted in [otherCurrencyCount] and excluded from the
/// monetary figures, keeping every displayed number exact — no fake FX.
@immutable
final class DashboardStats {
  const DashboardStats({
    required this.currency,
    required this.outstanding,
    required this.overdueCount,
    required this.overdueAmount,
    required this.paidThisMonth,
    required this.monthlyRevenue,
    required this.otherCurrencyCount,
  });

  /// Currency all monetary figures are expressed in.
  final String currency;

  /// Open balances of all sent-but-unpaid invoices (including overdue
  /// ones). Partial payments reduce this — it is what is actually owed.
  final Money outstanding;
  final int overdueCount;
  final Money overdueAmount;

  /// Revenue from invoices whose `paidAt` falls in the current month.
  final Money paidThisMonth;

  /// Last [monthsOfHistory] months, oldest first; the last entry is the
  /// current month. Based on `paidAt` of paid invoices.
  final List<MonthlyRevenue> monthlyRevenue;

  /// Invoices excluded because they use a different currency.
  final int otherCurrencyCount;

  static const int monthsOfHistory = 6;

  static DashboardStats compute({
    required List<Invoice> invoices,
    required String currency,
    required DateTime now,
  }) {
    var outstanding = Money.zero(currency);
    var overdueCount = 0;
    var overdueAmount = Money.zero(currency);
    var paidThisMonth = Money.zero(currency);
    var otherCurrencyCount = 0;

    final months = List<DateTime>.generate(
      monthsOfHistory,
      (i) => DateTime(now.year, now.month - (monthsOfHistory - 1) + i),
    );
    final revenueByMonth = <DateTime, Money>{
      for (final m in months) m: Money.zero(currency),
    };

    for (final invoice in invoices) {
      if (invoice.currency != currency) {
        otherCurrencyCount++;
        continue;
      }
      final totals = InvoiceCalculator.calculate(invoice);
      final total = totals.total;

      if (invoice.status == InvoiceStatus.sent) {
        final balance = PaymentMath.balanceDue(invoice, totals: totals);
        outstanding += balance;
        if (invoice.isOverdue(now)) {
          overdueCount++;
          overdueAmount += balance;
        }
      }

      final paidAt = invoice.paidAt;
      if (invoice.status == InvoiceStatus.paid && paidAt != null) {
        if (paidAt.year == now.year && paidAt.month == now.month) {
          paidThisMonth += total;
        }
        final bucket = DateTime(paidAt.year, paidAt.month);
        final current = revenueByMonth[bucket];
        if (current != null) {
          revenueByMonth[bucket] = current + total;
        }
      }
    }

    return DashboardStats(
      currency: currency,
      outstanding: outstanding,
      overdueCount: overdueCount,
      overdueAmount: overdueAmount,
      paidThisMonth: paidThisMonth,
      monthlyRevenue: [
        for (final m in months)
          MonthlyRevenue(month: m, total: revenueByMonth[m]!),
      ],
      otherCurrencyCount: otherCurrencyCount,
    );
  }
}
