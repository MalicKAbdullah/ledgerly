import 'dart:async';

import 'package:core_theme/core_theme.dart';
import 'package:core_ui/core_ui.dart';
import 'package:core_update/core_update.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ledgerly/src/core/data/app_data.dart';
import 'package:ledgerly/src/core/providers.dart';
import 'package:ledgerly/src/core/widgets/async_view.dart';
import 'package:ledgerly/src/features/dashboard/dashboard_providers.dart';
import 'package:ledgerly/src/features/dashboard/services/dashboard_stats.dart';
import 'package:ledgerly/src/features/dashboard/widgets/revenue_chart.dart';
import 'package:ledgerly/src/features/expenses/services/expense_stats.dart';
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
      appBar: AppBar(title: const Text('Dashboard')),
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
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    // Memoized: recomputed only when the underlying invoices/expenses change,
    // not on every dashboard rebuild (theme, media query, snackbar, …).
    final stats = ref.watch(dashboardStatsProvider)!;
    final expenseStats = ref.watch(expenseStatsProvider)!;
    final profitThisMonth = stats.paidThisMonth - expenseStats.thisMonth;

    if (data.invoices.isEmpty) {
      final needsProfile = data.profile.displayName.isEmpty;
      return VaultEmptyState(
        icon: Icons.insights_outlined,
        message: needsProfile
            ? 'Welcome to Ledgerly!\nStart with your business details — '
                  'they appear on every invoice you send.'
            : 'No invoices yet.\nCreate your first invoice to see your '
                  'business at a glance.',
        action: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (needsProfile) ...[
              VaultButton(
                key: const Key('setup-profile-cta'),
                label: 'Set up your business profile',
                isFullWidth: false,
                onPressed: () => context.go('/settings'),
              ),
              const SizedBox(height: AppSpacing.sm),
              VaultButton(
                label: 'New Invoice',
                isFullWidth: false,
                variant: VaultButtonVariant.secondary,
                onPressed: () => context.go('/invoices/new'),
              ),
            ] else
              VaultButton(
                label: 'New Invoice',
                isFullWidth: false,
                onPressed: () => context.go('/invoices/new'),
              ),
          ],
        ),
      );
    }

    final recent = [...data.invoices]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        const _UpdateCard(),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: 'Outstanding',
                value: stats.outstanding.format(),
                icon: Icons.hourglass_bottom,
                color: theme.colorScheme.primary,
                container: theme.colorScheme.primaryContainer,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _StatCard(
                label: 'Overdue (${stats.overdueCount})',
                value: stats.overdueAmount.format(),
                icon: Icons.warning_amber_rounded,
                color: stats.overdueCount > 0
                    ? AppColors.error(brightness)
                    : AppColors.textTertiary(brightness),
                container: stats.overdueCount > 0
                    ? (brightness == Brightness.dark
                          ? AppColors.errorContainerDark
                          : AppColors.errorContainerLight)
                    : AppColors.surfaceAlt(brightness),
                emphasize: stats.overdueCount > 0,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        _StatCard(
          label: 'Paid this month',
          value: stats.paidThisMonth.format(),
          icon: Icons.check_circle_outline,
          color: AppColors.success(brightness),
          container: brightness == Brightness.dark
              ? AppColors.successContainerDark
              : AppColors.successContainerLight,
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: 'Expenses this month',
                value: expenseStats.thisMonth.format(),
                icon: Icons.payments_outlined,
                color: AppColors.error(brightness),
                container: brightness == Brightness.dark
                    ? AppColors.errorContainerDark
                    : AppColors.errorContainerLight,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _StatCard(
                label: 'Profit this month',
                value: profitThisMonth.format(),
                icon: Icons.trending_up,
                color: profitThisMonth.isNegative
                    ? AppColors.error(brightness)
                    : AppColors.success(brightness),
                container: AppColors.surfaceAlt(brightness),
                emphasize: profitThisMonth.isNegative,
              ),
            ),
          ],
        ),
        if (stats.otherCurrencyCount > 0 ||
            expenseStats.otherCurrencyCount > 0) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            _otherCurrencyNote(stats, expenseStats),
            style: theme.textTheme.labelSmall,
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Revenue vs expenses — last 6 months',
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.md),
        VaultCard(
          child: RepaintBoundary(
            child: RevenueChart(
              months: stats.monthlyRevenue,
              expenses: expenseStats.monthlyTotals,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Recent invoices', style: theme.textTheme.titleLarge),
            TextButton(
              onPressed: () => context.go('/invoices'),
              child: const Text('View all'),
            ),
          ],
        ),
        for (final invoice in recent.take(5)) ...[
          InvoiceTile(
            invoice: invoice,
            clientName: data.clientById(invoice.clientId)?.name ?? 'Unknown',
            onTap: () => context.go('/invoices/${invoice.id}'),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
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

/// Stat card with the suite's icon-in-tinted-container pattern and
/// tabular-figure money so digits stay aligned as values change.
final class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.container,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color container;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return VaultCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: container,
                  borderRadius: BorderRadius.circular(AppSpacing.sm),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  label,
                  style: theme.textTheme.labelMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 250),
              style: AppTextStyles.numberLarge.copyWith(
                fontSize: 26,
                color: emphasize ? color : theme.colorScheme.onSurface,
              ),
              child: Text(value),
            ),
          ),
        ],
      ),
    );
  }
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
