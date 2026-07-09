import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledgerly/src/core/providers.dart';
import 'package:ledgerly/src/features/dashboard/services/dashboard_stats.dart';
import 'package:ledgerly/src/features/expenses/services/expense_stats.dart';

/// Memoized dashboard aggregation.
///
/// The `.select` reads only the slices the computation depends on (the
/// invoice list identity and the default currency). Because [AppData.copyWith]
/// preserves the reference of untouched lists, unrelated mutations — e.g.
/// saving an expense — leave `invoices` identical, so this provider does *not*
/// recompute. The result is cached until those inputs actually change, instead
/// of being recomputed on every dashboard rebuild.
final dashboardStatsProvider = Provider<DashboardStats?>((ref) {
  final input = ref.watch(
    appDataProvider.select((async) {
      final data = async.valueOrNull;
      return data == null
          ? null
          : (invoices: data.invoices, currency: data.profile.defaultCurrency);
    }),
  );
  if (input == null) return null;
  return DashboardStats.compute(
    invoices: input.invoices,
    currency: input.currency,
    now: DateTime.now(),
  );
});

/// Memoized expense aggregation — see [dashboardStatsProvider]. Depends only on
/// the expense list identity and the default currency.
final expenseStatsProvider = Provider<ExpenseStats?>((ref) {
  final input = ref.watch(
    appDataProvider.select((async) {
      final data = async.valueOrNull;
      return data == null
          ? null
          : (expenses: data.expenses, currency: data.profile.defaultCurrency);
    }),
  );
  if (input == null) return null;
  return ExpenseStats.compute(
    expenses: input.expenses,
    currency: input.currency,
    now: DateTime.now(),
  );
});
