import 'package:core_theme/core_theme.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ledgerly/src/core/data/app_data.dart';
import 'package:ledgerly/src/core/providers.dart';
import 'package:ledgerly/src/core/share_service.dart';
import 'package:ledgerly/src/core/widgets/async_view.dart';
import 'package:ledgerly/src/features/invoices/models/invoice.dart';
import 'package:ledgerly/src/features/invoices/services/invoice_pdf_service.dart';
import 'package:ledgerly/src/features/invoices/services/reminder_service.dart';
import 'package:ledgerly/src/features/invoices/widgets/invoice_detail_widgets.dart';
import 'package:ledgerly/src/features/invoices/widgets/invoice_timeline.dart';
import 'package:ledgerly/src/features/invoices/widgets/payment_history_card.dart';
import 'package:ledgerly/src/features/invoices/widgets/record_payment_sheet.dart';
import 'package:printing/printing.dart';

/// Invoice detail: hero card, quick actions, payments, timeline, template
/// picker, and PDF share/print.
final class InvoicePreviewScreen extends ConsumerWidget {
  const InvoicePreviewScreen({required this.invoiceId, super.key});

  final String invoiceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(appDataProvider);

    return AsyncView<AppData>(
      value: asyncData,
      builder: (data) {
        final invoice = data.invoiceById(invoiceId);
        if (invoice == null) {
          return const Scaffold(
            body: VaultEmptyState(
              icon: Icons.receipt_long_outlined,
              message: 'This invoice no longer exists.',
            ),
          );
        }
        return _DetailBody(data: data, invoice: invoice);
      },
    );
  }
}

final class _DetailBody extends ConsumerWidget {
  const _DetailBody({required this.data, required this.invoice});

  final AppData data;
  final Invoice invoice;

  Future<void> _sharePdf(BuildContext context) async {
    final client = data.clientById(invoice.clientId);
    if (client == null) return;
    final bytes = await InvoicePdfService.renderInBackground(
      profile: data.profile,
      client: client,
      invoice: invoice,
    );
    await Printing.sharePdf(bytes: bytes, filename: '${invoice.number}.pdf');
  }

  Future<void> _printPdf(BuildContext context) async {
    final client = data.clientById(invoice.clientId);
    if (client == null) return;
    await Printing.layoutPdf(
      onLayout: (_) => InvoicePdfService.renderInBackground(
        profile: data.profile,
        client: client,
        invoice: invoice,
      ),
    );
  }

  Future<void> _sendReminder(BuildContext context) async {
    final client = data.clientById(invoice.clientId);
    if (client == null) return;
    await ShareService.shareText(
      ReminderService.buildReminderText(
        profile: data.profile,
        client: client,
        invoice: invoice,
        now: DateTime.now(),
      ),
      subject: 'Payment reminder — ${invoice.number}',
    );
  }

  Future<void> _recordPayment(BuildContext context, WidgetRef ref) async {
    final draft = await showRecordPaymentSheet(context, invoice: invoice);
    if (draft == null) return;
    final updated = await ref
        .read(appDataProvider.notifier)
        .recordPayment(
          invoice.id,
          date: draft.date,
          amountMinor: draft.amountMinor,
          method: draft.method,
          note: draft.note,
        );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          updated.status == InvoiceStatus.paid
              ? '${invoice.number} is now fully paid'
              : 'Payment recorded',
        ),
      ),
    );
  }

  Future<void> _duplicate(BuildContext context, WidgetRef ref) async {
    final copy = await ref
        .read(appDataProvider.notifier)
        .duplicateInvoice(invoice.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Duplicated as ${copy.number}')));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final client = data.clientById(invoice.clientId);
    final notifier = ref.read(appDataProvider.notifier);
    final isPaid = invoice.status == InvoiceStatus.paid;

    return Scaffold(
      appBar: AppBar(
        title: Text(invoice.number),
        actions: [
          IconButton(
            key: const Key('make-recurring'),
            tooltip: 'Make recurring',
            icon: const Icon(Icons.autorenew),
            onPressed: () =>
                context.go('/invoices/recurring/new?fromInvoice=${invoice.id}'),
          ),
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.go('/invoices/${invoice.id}/edit'),
          ),
          IconButton(
            tooltip: 'Print',
            icon: const Icon(Icons.print_outlined),
            onPressed: () => _printPdf(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          InvoiceHeaderCard(invoice: invoice, client: client),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              if (!isPaid) ...[
                QuickAction(
                  icon: Icons.payments_outlined,
                  label: 'Payment',
                  onTap: () => _recordPayment(context, ref),
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              if (invoice.status == InvoiceStatus.sent) ...[
                QuickAction(
                  icon: Icons.notifications_active_outlined,
                  label: 'Remind',
                  onTap: () => _sendReminder(context),
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              QuickAction(
                icon: Icons.copy_outlined,
                label: 'Duplicate',
                onTap: () => _duplicate(context, ref),
              ),
              const SizedBox(width: AppSpacing.sm),
              QuickAction(
                icon: Icons.ios_share,
                label: 'Share PDF',
                onTap: () => _sharePdf(context),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (invoice.status == InvoiceStatus.draft)
            VaultButton(
              label: 'Mark as Sent',
              onPressed: () =>
                  notifier.setInvoiceStatus(invoice.id, InvoiceStatus.sent),
            ),
          if (invoice.status == InvoiceStatus.sent)
            VaultButton(
              label: 'Mark as Paid',
              onPressed: () =>
                  notifier.setInvoiceStatus(invoice.id, InvoiceStatus.paid),
            ),
          const SizedBox(height: AppSpacing.lg),
          Text('Items', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          InvoiceItemsCard(invoice: invoice),
          if (invoice.payments.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            Text('Payments', style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            PaymentHistoryCard(
              invoice: invoice,
              onRemove: (payment) =>
                  notifier.removePayment(invoice.id, payment.id),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Text('PDF template', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          TemplatePicker(
            selected: invoice.template,
            onChanged: (template) =>
                notifier.setInvoiceTemplate(invoice.id, template),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Activity', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          VaultCard(child: InvoiceTimeline(invoice: invoice)),
          if (invoice.notes.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            Text('Notes', style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            VaultCard(child: Text(invoice.notes)),
          ],
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}
