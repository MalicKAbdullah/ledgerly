import 'dart:async';

import 'package:core_theme/core_theme.dart';
import 'package:core_ui/core_ui.dart';
import 'package:core_update/core_update.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ledgerly/src/core/data/app_data.dart';
import 'package:ledgerly/src/core/providers.dart';
import 'package:ledgerly/src/core/widgets/amount_text.dart';
import 'package:ledgerly/src/core/widgets/async_view.dart';
import 'package:ledgerly/src/features/dashboard/dashboard_providers.dart';
import 'package:ledgerly/src/features/dashboard/services/dashboard_stats.dart';
import 'package:ledgerly/src/features/dashboard/widgets/revenue_chart.dart';
import 'package:ledgerly/src/features/expenses/services/expense_stats.dart';
import 'package:ledgerly/src/features/invoices/models/invoice.dart';
import 'package:ledgerly/src/features/invoices/widgets/invoice_tile.dart';

final class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

final class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _checkedRecurringRun = false;
  bool _checkedAutoBackup = false;
  bool _checkedInvoiceNotify = false;

  /// Posts an invoice-reminder notification once per open when any sent
  /// invoices are overdue or due soon (deduped to once a day internally).
  void _maybeNotifyInvoices() {
    if (_checkedInvoiceNotify) return;
    _checkedInvoiceNotify = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final data = ref.read(appDataProvider).valueOrNull;
      if (data == null) return;
      unawaited(
        ref.read(invoiceNotifierProvider).checkOnOpen(data, DateTime.now()),
      );
    });
  }

  /// Runs a scheduled backup once per app open, when one is due (F-4 auto-backup).
  /// Silent and fire-and-forget; failures are recorded and shown in Settings.
  void _maybeRunAutoBackup() {
    if (_checkedAutoBackup) return;
    _checkedAutoBackup = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        ref
            .read(autoBackupServiceProvider)
            .runIfDue(ref.read(ledgerBackupProducerProvider)),
      );
    });
  }

  /// Surfaces the "N invoices generated from recurring schedules" banner
  /// exactly once after the load-time materializer run.
  void _maybeAnnounceRecurringRun() {
    if (_checkedRecurringRun) return;
    _checkedRecurringRun = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final result = ref
          .read(appDataProvider.notifier)
          .takeRecurringRunResult();
      if (result == null || !result.hasChanges) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.summary),
          action: SnackBarAction(
            label: 'View',
            onPressed: () {
              if (mounted) context.go('/invoices');
            },
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final asyncData = ref.watch(appDataProvider);
    if (asyncData.hasValue) {
      _maybeAnnounceRecurringRun();
      _maybeRunAutoBackup();
      _maybeNotifyInvoices();
    }

    return Scaffold(
      body: AsyncView<AppData>(
        value: asyncData,
        builder: (data) => _DashboardBody(data: data),
      ),
    );
  }
}

final class _DashboardBody extends ConsumerWidget {
  const _DashboardBody({required this.data});

  final AppData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Memoized: recomputed only when the underlying invoices/expenses change,
    // not on every dashboard rebuild (theme, media query, snackbar, …).
    final stats = ref.watch(dashboardStatsProvider)!;
    final expenseStats = ref.watch(expenseStatsProvider)!;
    final profitThisMonth = stats.paidThisMonth - expenseStats.thisMonth;

    if (data.invoices.isEmpty) {
      final needsProfile = data.profile.displayName.isEmpty;
      return SafeArea(
        child: AppEmptyState(
          icon: Icons.receipt_long_outlined,
          title: needsProfile ? 'Welcome to Ledgerly' : 'No invoices yet',
          message: needsProfile
              ? 'Start with your business details. They appear on every '
                    'invoice you send.'
              : 'Create your first invoice to see your business at a '
                    'glance.',
          action: VaultButton(
            key: needsProfile ? const Key('setup-profile-cta') : null,
            label: needsProfile
                ? 'Set up your business profile'
                : 'New Invoice',
            isFullWidth: false,
            onPressed: () =>
                context.go(needsProfile ? '/settings' : '/invoices/new'),
          ),
          secondaryAction: needsProfile
              ? VaultButton(
                  label: 'New Invoice',
                  isFullWidth: false,
                  variant: VaultButtonVariant.secondary,
                  onPressed: () => context.go('/invoices/new'),
                )
              : null,
        ),
      );
    }

    final c = SuiteColors.of(context);
    final recent = [...data.invoices]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final openCount = data.invoices
        .where(
          (i) => i.status == InvoiceStatus.sent && i.currency == stats.currency,
        )
        .length;
    final now = DateTime.now();
    final name = data.profile.displayName;

    return ListView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        MediaQuery.paddingOf(context).top + AppSpacing.lg,
        AppSpacing.gutter,
        AppSpacing.xl,
      ),
      children: [
        const _UpdateCard(),
        Text(
          DateFormat('EEEE, d MMMM').format(now),
          style: AppTextStyles.label.copyWith(color: c.textSecondary),
        ),
        const SizedBox(height: 2),
        Text(
          name.isEmpty ? 'Dashboard' : name,
          style: AppTextStyles.h2.copyWith(color: c.textPrimary),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: AppSpacing.lg),
        HeroMetricCard(
          label: 'Outstanding',
          trailing: stats.overdueCount > 0
              ? DeltaBadge(
                  delta: 0,
                  label: '${stats.overdueCount} overdue',
                  polarity: DeltaPolarity.upIsBad,
                  subtle: true,
                )
              : null,
          value: AmountText(stats.outstanding, style: AppTextStyles.hero),
          delta: Flexible(
            child: Text(
              openCount == 1
                  ? 'Across 1 open invoice'
                  : 'Across $openCount open invoices',
              style: AppTextStyles.bodySmall.copyWith(color: c.textSecondary),
            ),
          ),
          footer: [
            StatTile(
              label: 'Overdue (${stats.overdueCount})',
              value: stats.overdueAmount.format(),
              valueColor: stats.overdueCount > 0 ? c.negative : null,
            ),
            StatTile(
              label: 'Paid this month',
              value: stats.paidThisMonth.format(),
              valueColor: c.positive,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.smd),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: MetricCard(
                label: 'Expenses',
                caption: 'This month',
                icon: Icons.payments_outlined,
                value: AmountText(
                  expenseStats.thisMonth,
                  style: AppTextStyles.numberMedium,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.smd),
            Expanded(
              child: MetricCard(
                label: 'Profit',
                caption: 'This month',
                icon: Icons.trending_up,
                value: AmountText(
                  profitThisMonth,
                  style: AppTextStyles.numberMedium,
                  tone: MoneyTone.signed,
                ),
              ),
            ),
          ],
        ),
        if (stats.otherCurrencyCount > 0 ||
            expenseStats.otherCurrencyCount > 0) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            _otherCurrencyNote(stats, expenseStats),
            style: AppTextStyles.caption.copyWith(color: c.textTertiary),
          ),
        ],
        const SizedBox(height: AppSpacing.smd),
        VaultCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Revenue vs expenses — last 6 months',
                style: AppTextStyles.label.copyWith(color: c.textSecondary),
              ),
              const SizedBox(height: AppSpacing.md),
              RepaintBoundary(
                child: RevenueChart(
                  months: stats.monthlyRevenue,
                  expenses: expenseStats.monthlyTotals,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        SectionHeader(
          title: 'Recent invoices',
          actionLabel: 'View all',
          onAction: () => context.go('/invoices'),
        ),
        RowGroup(
          separatorIndent: InvoiceTile.separatorIndent,
          children: [
            for (final invoice in recent.take(5))
              InvoiceTile(
                invoice: invoice,
                clientName:
                    data.clientById(invoice.clientId)?.name ?? 'Unknown',
                onTap: () => context.go('/invoices/${invoice.id}'),
              ),
          ],
        ),
      ],
    );
  }
}

String _otherCurrencyNote(DashboardStats stats, ExpenseStats expenseStats) {
  final parts = <String>[
    if (stats.otherCurrencyCount > 0) '${stats.otherCurrencyCount} invoice(s)',
    if (expenseStats.otherCurrencyCount > 0)
      '${expenseStats.otherCurrencyCount} expense(s)',
  ];
  return '${parts.join(' and ')} in other currencies are not included '
      '(stats use ${stats.currency}).';
}

/// "Update available" card, shown when a newer GitHub release exists and the
/// user hasn't dismissed it this session.
class _UpdateCard extends ConsumerWidget {
  const _UpdateCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(updateCheckProvider).valueOrNull;
    final dismissed = ref.watch(updateDismissedProvider);
    if (info == null || dismissed) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: UpdateBanner(
        info: info,
        onUpdate: () => ref.read(updateServiceProvider).openDownload(info),
        onDismiss: () =>
            ref.read(updateDismissedProvider.notifier).state = true,
      ),
    );
  }
}
