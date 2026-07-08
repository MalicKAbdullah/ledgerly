import 'package:core_theme/core_theme.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ledgerly/src/core/data/app_data.dart';
import 'package:ledgerly/src/core/providers.dart';
import 'package:ledgerly/src/core/share_service.dart';
import 'package:ledgerly/src/core/widgets/async_view.dart';
import 'package:ledgerly/src/features/invoices/services/csv_export_service.dart';
import 'package:ledgerly/src/features/invoices/models/invoice.dart';
import 'package:ledgerly/src/features/invoices/widgets/invoice_tile.dart';

enum _InvoiceFilter { all, draft, sent, overdue, paid }

final class InvoicesScreen extends ConsumerStatefulWidget {
  const InvoicesScreen({super.key});

  @override
  ConsumerState<InvoicesScreen> createState() => _InvoicesScreenState();
}

final class _InvoicesScreenState extends ConsumerState<InvoicesScreen> {
  _InvoiceFilter _filter = _InvoiceFilter.all;

  Future<void> _exportCsv() async {
    final data = ref.read(appDataProvider).valueOrNull;
    if (data == null || data.invoices.isEmpty) return;
    final csv = CsvExportService.buildCsv(
      invoices: data.invoices,
      data: data,
      now: DateTime.now(),
    );
    final today = DateTime.now();
    final stamp =
        '${today.year}'
        '${today.month.toString().padLeft(2, '0')}'
        '${today.day.toString().padLeft(2, '0')}';
    await ShareService.shareCsv(
      csv: csv,
      fileName: 'ledgerly-invoices-$stamp.csv',
    );
  }

  @override
  Widget build(BuildContext context) {
    final asyncData = ref.watch(appDataProvider);
    final hasInvoices = (asyncData.valueOrNull?.invoices.isNotEmpty) ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoices'),
        actions: [
          IconButton(
            key: const Key('open-estimates'),
            tooltip: 'Estimates',
            icon: const Icon(Icons.request_quote_outlined),
            onPressed: () => context.go('/invoices/estimates'),
          ),
          IconButton(
            key: const Key('open-recurring'),
            tooltip: 'Recurring invoices',
            icon: const Icon(Icons.autorenew),
            onPressed: () => context.go('/invoices/recurring'),
          ),
          if (hasInvoices)
            IconButton(
              tooltip: 'Export CSV',
              icon: const Icon(Icons.file_upload_outlined),
              onPressed: _exportCsv,
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/invoices/new'),
        child: const Icon(Icons.add),
      ),
      body: AsyncView<AppData>(
        value: asyncData,
        builder: (data) {
          final now = DateTime.now();
          final invoices = data.invoices.where((i) {
            return switch (_filter) {
              _InvoiceFilter.all => true,
              _InvoiceFilter.draft => i.status == InvoiceStatus.draft,
              _InvoiceFilter.sent =>
                i.status == InvoiceStatus.sent && !i.isOverdue(now),
              _InvoiceFilter.overdue => i.isOverdue(now),
              _InvoiceFilter.paid => i.status == InvoiceStatus.paid,
            };
          }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

          return Column(
            children: [
              SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  children: [
                    for (final filter in _InvoiceFilter.values)
                      Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.sm),
                        child: FilterChip(
                          label: Text(_filterLabel(filter)),
                          selected: _filter == filter,
                          onSelected: (_) => setState(() => _filter = filter),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: invoices.isEmpty
                    ? VaultEmptyState(
                        icon: Icons.receipt_long_outlined,
                        message: data.invoices.isEmpty
                            ? 'No invoices yet.\nTap + to create your first '
                                  'invoice.'
                            : 'No ${_filterLabel(_filter).toLowerCase()} '
                                  'invoices.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md,
                          AppSpacing.sm,
                          AppSpacing.md,
                          96,
                        ),
                        itemCount: invoices.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (context, index) {
                          final invoice = invoices[index];
                          return _DismissibleInvoice(
                            invoice: invoice,
                            clientName:
                                data.clientById(invoice.clientId)?.name ??
                                'Unknown',
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _filterLabel(_InvoiceFilter filter) => switch (filter) {
    _InvoiceFilter.all => 'All',
    _InvoiceFilter.draft => 'Draft',
    _InvoiceFilter.sent => 'Sent',
    _InvoiceFilter.overdue => 'Overdue',
    _InvoiceFilter.paid => 'Paid',
  };
}

/// Swipe an unpaid invoice to mark it paid; long-press menu for more.
final class _DismissibleInvoice extends ConsumerWidget {
  const _DismissibleInvoice({required this.invoice, required this.clientName});

  final Invoice invoice;
  final String clientName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canMarkPaid = invoice.status != InvoiceStatus.paid;
    final tile = InvoiceTile(
      invoice: invoice,
      clientName: clientName,
      onTap: () => context.go('/invoices/${invoice.id}'),
      trailing: _InvoiceMenu(invoice: invoice),
    );

    if (!canMarkPaid) return tile;

    return Dismissible(
      key: ValueKey('dismiss-${invoice.id}'),
      direction: DismissDirection.startToEnd,
      confirmDismiss: (_) async {
        await ref
            .read(appDataProvider.notifier)
            .setInvoiceStatus(invoice.id, InvoiceStatus.paid);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${invoice.number} marked as paid')),
          );
        }
        return false; // The tile stays; only its status changed.
      },
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.successLight,
          borderRadius: BorderRadius.circular(AppSpacing.borderRadius),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 8),
            Text(
              'Mark paid',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
      child: tile,
    );
  }
}

final class _InvoiceMenu extends ConsumerWidget {
  const _InvoiceMenu({required this.invoice});

  final Invoice invoice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(appDataProvider.notifier);

    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 20),
      onSelected: (action) async {
        final messenger = ScaffoldMessenger.of(context);
        switch (action) {
          case 'sent':
            await notifier.setInvoiceStatus(invoice.id, InvoiceStatus.sent);
          case 'paid':
            await notifier.setInvoiceStatus(invoice.id, InvoiceStatus.paid);
          case 'duplicate':
            final copy = await notifier.duplicateInvoice(invoice.id);
            messenger.showSnackBar(
              SnackBar(content: Text('Duplicated as ${copy.number}')),
            );
          case 'delete':
            await notifier.deleteInvoice(invoice.id);
            messenger.showSnackBar(
              SnackBar(content: Text('${invoice.number} deleted')),
            );
        }
      },
      itemBuilder: (context) => [
        if (invoice.status == InvoiceStatus.draft)
          const PopupMenuItem(value: 'sent', child: Text('Mark as sent')),
        if (invoice.status != InvoiceStatus.paid)
          const PopupMenuItem(value: 'paid', child: Text('Mark as paid')),
        const PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
        const PopupMenuItem(value: 'delete', child: Text('Delete')),
      ],
    );
  }
}
