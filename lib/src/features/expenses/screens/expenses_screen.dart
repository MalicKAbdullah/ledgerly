import 'package:core_theme/core_theme.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ledgerly/src/core/data/app_data.dart';
import 'package:ledgerly/src/core/formats.dart';
import 'package:ledgerly/src/core/money/money.dart';
import 'package:ledgerly/src/core/providers.dart';
import 'package:ledgerly/src/core/share_service.dart';
import 'package:ledgerly/src/core/widgets/async_view.dart';
import 'package:ledgerly/src/features/expenses/models/expense.dart';
import 'package:ledgerly/src/features/expenses/services/expense_csv_service.dart';
import 'package:ledgerly/src/features/expenses/widgets/expense_sheet.dart';

/// Month-grouped expense list with category filter chips, add/edit sheet,
/// and CSV export.
final class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

final class _ExpensesScreenState extends ConsumerState<ExpensesScreen> {
  ExpenseCategory? _filter;
  String _search = '';

  Future<void> _exportCsv() async {
    final data = ref.read(appDataProvider).valueOrNull;
    if (data == null || data.expenses.isEmpty) return;
    final csv = ExpenseCsvService.buildCsv(expenses: data.expenses, data: data);
    final today = DateTime.now();
    final stamp =
        '${today.year}'
        '${today.month.toString().padLeft(2, '0')}'
        '${today.day.toString().padLeft(2, '0')}';
    await ShareService.shareCsv(
      csv: csv,
      fileName: 'ledgerly-expenses-$stamp.csv',
    );
  }

  Future<void> _addOrEdit([Expense? existing]) async {
    final data = ref.read(appDataProvider).valueOrNull;
    if (data == null) return;
    final result = await showExpenseSheet(
      context,
      defaultCurrency: data.profile.defaultCurrency,
      clients: data.clients,
      existing: existing,
    );
    if (result == null) return;
    await ref.read(appDataProvider.notifier).saveExpense(result);
  }

  @override
  Widget build(BuildContext context) {
    final asyncData = ref.watch(appDataProvider);
    final hasExpenses = (asyncData.valueOrNull?.expenses.isNotEmpty) ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expenses'),
        actions: [
          if (hasExpenses)
            IconButton(
              tooltip: 'Export CSV',
              icon: const Icon(Icons.file_upload_outlined),
              onPressed: _exportCsv,
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        key: const Key('add-expense'),
        onPressed: () => _addOrEdit(),
        child: const Icon(Icons.add),
      ),
      body: AsyncView<AppData>(
        value: asyncData,
        builder: (data) {
          final q = _search.trim().toLowerCase();
          final expenses =
              data.expenses
                  .where((e) => _filter == null || e.category == _filter)
                  .where(
                    (e) =>
                        q.isEmpty ||
                        e.description.toLowerCase().contains(q) ||
                        e.note.toLowerCase().contains(q),
                  )
                  .toList()
                ..sort((a, b) => b.date.compareTo(a.date));

          return Column(
            children: [
              if (data.expenses.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.sm,
                    AppSpacing.md,
                    0,
                  ),
                  child: TextField(
                    onChanged: (v) => setState(() => _search = v),
                    decoration: const InputDecoration(
                      hintText: 'Search description or note',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
              SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: FilterChip(
                        label: const Text('All'),
                        selected: _filter == null,
                        onSelected: (_) => setState(() => _filter = null),
                      ),
                    ),
                    for (final category in ExpenseCategory.values)
                      Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.sm),
                        child: FilterChip(
                          avatar: Icon(expenseCategoryIcon(category), size: 16),
                          label: Text(category.label),
                          selected: _filter == category,
                          onSelected: (_) => setState(() => _filter = category),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: expenses.isEmpty
                    ? VaultEmptyState(
                        icon: Icons.receipt_outlined,
                        message: data.expenses.isEmpty
                            ? 'No expenses yet.\nTap + to record your first '
                                  'business cost.'
                            : q.isNotEmpty
                            ? 'No expenses match "$_search".'
                            : 'No ${_filter?.label.toLowerCase()} '
                                  'expenses.',
                      )
                    : _GroupedExpenseList(
                        expenses: expenses,
                        data: data,
                        onTap: _addOrEdit,
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

final class _GroupedExpenseList extends ConsumerWidget {
  const _GroupedExpenseList({
    required this.expenses,
    required this.data,
    required this.onTap,
  });

  final List<Expense> expenses;
  final AppData data;
  final ValueChanged<Expense> onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final currency = data.profile.defaultCurrency;

    // Single pass over the (already newest-first) expenses: sum each month's
    // subtotal in the default currency and flatten into a lazy row list — a
    // month header followed by its expenses. Avoids the previous O(n²) rescan
    // per section and builds only the rows on screen via ListView.builder.
    final monthTotals = <DateTime, Money>{};
    final rows = <_ExpenseRow>[];
    DateTime? currentMonth;
    for (final expense in expenses) {
      final month = DateTime(expense.date.year, expense.date.month);
      if (month != currentMonth) {
        currentMonth = month;
        rows.add(_ExpenseRow.header(month));
      }
      if (expense.currency == currency) {
        monthTotals[month] =
            (monthTotals[month] ?? Money.zero(currency)) + expense.amount;
      } else {
        monthTotals[month] ??= Money.zero(currency);
      }
      rows.add(_ExpenseRow.tile(expense));
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, 96),
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = rows[index];
        final expense = row.expense;
        if (expense == null) {
          final month = row.month!;
          return Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xs,
              AppSpacing.md,
              AppSpacing.xs,
              AppSpacing.sm,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat.yMMMM().format(month),
                  style: theme.textTheme.titleSmall,
                ),
                Text(
                  (monthTotals[month] ?? Money.zero(currency)).format(),
                  style: theme.textTheme.titleSmall,
                ),
              ],
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: _ExpenseTile(
            expense: expense,
            clientName: expense.clientId == null
                ? null
                : data.clientById(expense.clientId!)?.name,
            onTap: () => onTap(expense),
          ),
        );
      },
    );
  }
}

/// One row in the flattened expense list: either a month [header] or an
/// expense [tile]. Exactly one of [month]/[expense] is non-null.
final class _ExpenseRow {
  const _ExpenseRow.header(this.month) : expense = null;
  const _ExpenseRow.tile(Expense this.expense) : month = null;

  final DateTime? month;
  final Expense? expense;
}

final class _ExpenseTile extends ConsumerWidget {
  const _ExpenseTile({
    required this.expense,
    required this.onTap,
    this.clientName,
  });

  final Expense expense;
  final String? clientName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final subtitleParts = [
      Formats.date(expense.date),
      ?clientName,
      if (expense.note.isNotEmpty) expense.note,
    ];

    return VaultCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(AppSpacing.sm),
            ),
            child: Icon(
              expenseCategoryIcon(expense.category),
              size: 18,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expense.description,
                  style: theme.textTheme.titleSmall,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitleParts.join(' · '),
                  style: theme.textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(expense.amount.format(), style: AppTextStyles.number),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 20),
            onSelected: (action) async {
              if (action == 'delete') {
                final messenger = ScaffoldMessenger.of(context);
                await ref
                    .read(appDataProvider.notifier)
                    .deleteExpense(expense.id);
                messenger.showSnackBar(
                  const SnackBar(content: Text('Expense deleted')),
                );
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
    );
  }
}
