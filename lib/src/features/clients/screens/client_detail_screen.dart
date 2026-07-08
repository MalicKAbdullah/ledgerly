import 'package:core_theme/core_theme.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ledgerly/src/core/data/app_data.dart';
import 'package:ledgerly/src/core/money/money.dart';
import 'package:ledgerly/src/core/providers.dart';
import 'package:ledgerly/src/core/widgets/async_view.dart';
import 'package:ledgerly/src/features/clients/models/client.dart';
import 'package:ledgerly/src/features/clients/services/client_statement_pdf_service.dart';
import 'package:ledgerly/src/features/invoices/models/invoice.dart';
import 'package:ledgerly/src/features/invoices/services/invoice_calculator.dart';
import 'package:ledgerly/src/features/invoices/services/payment_math.dart';
import 'package:ledgerly/src/features/invoices/widgets/invoice_tile.dart';
import 'package:printing/printing.dart';

final class ClientDetailScreen extends ConsumerWidget {
  const ClientDetailScreen({required this.clientId, super.key});

  final String clientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(appDataProvider);

    return AsyncView<AppData>(
      value: asyncData,
      builder: (data) {
        final client = data.clientById(clientId);
        if (client == null) {
          return const Scaffold(
            body: VaultEmptyState(
              icon: Icons.person_off_outlined,
              message: 'This client no longer exists.',
            ),
          );
        }
        return _DetailBody(data: data, client: client);
      },
    );
  }
}

final class _DetailBody extends ConsumerWidget {
  const _DetailBody({required this.data, required this.client});

  final AppData data;
  final Client client;

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final invoiceCount = data.invoicesForClient(client.id).length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete client?'),
        content: Text(
          invoiceCount == 0
              ? 'This will remove ${client.name}.'
              : 'This will remove ${client.name} and their $invoiceCount '
                    'invoice(s). This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(appDataProvider.notifier).deleteClient(client.id);
    if (context.mounted) context.go('/clients');
  }

  Future<void> _shareStatement(BuildContext context) async {
    final bytes = await ClientStatementPdfService.renderInBackground(
      profile: data.profile,
      client: client,
      invoices: data.invoicesForClient(client.id),
    );
    final safeName = client.name.replaceAll(RegExp(r'[^\w\- ]'), '').trim();
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'statement-${safeName.isEmpty ? 'client' : safeName}.pdf',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final invoices = data.invoicesForClient(client.id)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    // Per-currency totals so mixed-currency clients stay exact.
    final billed = <String, Money>{};
    final outstanding = <String, Money>{};
    for (final invoice in invoices) {
      final totals = InvoiceCalculator.calculate(invoice);
      billed[invoice.currency] =
          (billed[invoice.currency] ?? Money.zero(invoice.currency)) +
          totals.total;
      if (invoice.status == InvoiceStatus.sent) {
        outstanding[invoice.currency] =
            (outstanding[invoice.currency] ?? Money.zero(invoice.currency)) +
            PaymentMath.balanceDue(invoice, totals: totals);
      }
    }

    String joined(Map<String, Money> totals) => totals.isEmpty
        ? Money.zero(data.profile.defaultCurrency).format()
        : totals.values.map((m) => m.format()).join(' + ');

    return Scaffold(
      appBar: AppBar(
        title: Text(client.name),
        actions: [
          if (invoices.isNotEmpty)
            IconButton(
              tooltip: 'Share statement',
              icon: const Icon(Icons.summarize_outlined),
              onPressed: () => _shareStatement(context),
            ),
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.go('/clients/${client.id}/edit'),
          ),
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmDelete(context, ref),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/invoices/new?clientId=${client.id}'),
        icon: const Icon(Icons.add),
        label: const Text('Invoice'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          VaultCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (client.company.isNotEmpty)
                  _infoRow(theme, Icons.business_outlined, client.company),
                if (client.email.isNotEmpty)
                  _infoRow(theme, Icons.email_outlined, client.email),
                if (client.address.isNotEmpty)
                  _infoRow(theme, Icons.place_outlined, client.address),
                if (client.notes.isNotEmpty)
                  _infoRow(theme, Icons.notes_outlined, client.notes),
                if (client.company.isEmpty &&
                    client.email.isEmpty &&
                    client.address.isEmpty &&
                    client.notes.isEmpty)
                  Text('No details yet.', style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: VaultCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Total billed', style: theme.textTheme.labelSmall),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          joined(billed),
                          style: AppTextStyles.number.copyWith(
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: VaultCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Outstanding', style: theme.textTheme.labelSmall),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          joined(outstanding),
                          style: AppTextStyles.number.copyWith(
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Invoices', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          if (invoices.isEmpty)
            const VaultEmptyState(
              icon: Icons.receipt_long_outlined,
              message: 'No invoices for this client yet.',
            )
          else
            for (final invoice in invoices) ...[
              InvoiceTile(
                invoice: invoice,
                clientName: client.name,
                onTap: () => context.go('/invoices/${invoice.id}'),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _infoRow(ThemeData theme, IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
