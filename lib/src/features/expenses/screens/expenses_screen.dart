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
import 'package:ledgerly/src/core/widgets/amount_text.dart';
import 'package:ledgerly/src/core/widgets/async_view.dart';
import 'package:ledgerly/src/core/widgets/filter_bar.dart';
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
              if (data.expenses.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.gutter,
                    AppSpacing.sm,
                    AppSpacing.gutter,
                    0,
                  ),
                  child: AppSearchField(
                    hint: 'Search description or note',
                    onChanged: (v) => setState(() => _search = v),
                  ),
                ),
                FilterBar<ExpenseCategory?>(
                  values: [null, ...ExpenseCategory.values],
                  selected: _filter,
                  label: (c) => c?.label ?? 'All',
                  icon: (c) => c == null ? null : expenseCategoryIcon(c),
                  onSelected: (c) => setState(() => _filter = c),
                ),
              ],
              Expanded(
                child: expenses.isEmpty
                    ? AppEmptyState(
                        icon: Icons.receipt_outlined,
                        title: data.expenses.isEmpty
                            ? 'No expenses yet'
                            : q.isNotEmpty
                            ? 'No matches'
                            : 'No ${_filter?.label.toLowerCase()} expenses',
                        message: data.expenses.isEmpty
                            ? 'Tap + to record your first business cost.'
                            : q.isNotEmpty
                            ? 'No expenses match "$_search".'
                            : null,
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
    final currency = data.profile.defaultCurrency;

    // Single pass over the (already newest-first) expenses: group by month and
    // sum each month's subtotal in the default currency. One lazy list item
    // per month keeps the build proportional to what is on screen.
    final groups = <DateTime, List<Expense>>{};
    final monthTotals = <DateTime, Money>{};
    for (final expense in expenses) {
      final month = DateTime(expense.date.year, expense.date.month);
      (groups[month] ??= []).add(expense);
      monthTotals[month] ??= Money.zero(currency);
      if (expense.currency == currency) {
        monthTotals[month] = monthTotals[month]! + expense.amount;
      }
    }
    final months = groups.keys.toList();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.md,
        AppSpacing.gutter,
        96,
      ),
      itemCount: months.length,
      itemBuilder: (context, index) {
        final month = months[index];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (index > 0) const SizedBox(height: AppSpacing.lg),
            SectionHeader(
              title: DateFormat.yMMMM().format(month),
              trailing: AmountText(
                monthTotals[month]!,
                style: AppTextStyles.number,
                alignment: AlignmentDirectional.centerEnd,
              ),
            ),
            RowGroup(
              children: [
                for (final expense in groups[month]!)
                  _ExpenseTile(
                    expense: expense,
                    clientName: expense.clientId == null
                        ? null
                        : data.clientById(expense.clientId!)?.name,
                    onTap: () => onTap(expense),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
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
    final subtitleParts = [
      Formats.date(expense.date),
      ?clientName,
      if (expense.note.isNotEmpty) expense.note,
    ];

    return AppListRow(
      onTap: onTap,
      leading: IconBadge(
        icon: expenseCategoryIcon(expense.category),
        color: SuiteColors.of(context).accent,
      ),
      title: expense.description,
      subtitle: subtitleParts.join(' · '),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AmountText(expense.amount, style: AppTextStyles.number),
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
