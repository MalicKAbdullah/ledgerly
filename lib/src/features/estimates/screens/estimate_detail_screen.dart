import 'package:core_theme/core_theme.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ledgerly/src/core/data/app_data.dart';
import 'package:ledgerly/src/core/formats.dart';
import 'package:ledgerly/src/core/providers.dart';
import 'package:ledgerly/src/core/widgets/amount_text.dart';
import 'package:ledgerly/src/core/widgets/async_view.dart';
import 'package:ledgerly/src/features/estimates/models/estimate.dart';
import 'package:ledgerly/src/features/estimates/services/estimate_math.dart';
import 'package:ledgerly/src/features/estimates/services/estimate_pdf_service.dart';
import 'package:ledgerly/src/features/estimates/widgets/estimate_widgets.dart';
import 'package:ledgerly/src/features/invoices/widgets/invoice_detail_widgets.dart';
import 'package:printing/printing.dart';

/// Estimate detail: totals hero, actions (send/share PDF, accept, decline,
/// convert to invoice, duplicate), items, template picker.
final class EstimateDetailScreen extends ConsumerWidget {
  const EstimateDetailScreen({required this.estimateId, super.key});

  final String estimateId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(appDataProvider);

    return AsyncView<AppData>(
      value: asyncData,
      builder: (data) {
        final estimate = data.estimateById(estimateId);
        if (estimate == null) {
          return const Scaffold(
            body: AppEmptyState(
              icon: Icons.request_quote_outlined,
              title: 'Estimate not found',
              message: 'This estimate no longer exists.',
            ),
          );
        }
        return _DetailBody(data: data, estimate: estimate);
      },
    );
  }
}

final class _DetailBody extends ConsumerWidget {
  const _DetailBody({required this.data, required this.estimate});

  final AppData data;
  final Estimate estimate;

  Future<void> _sharePdf(BuildContext context) async {
    final client = data.clientById(estimate.clientId);
    if (client == null) return;
    final bytes = await EstimatePdfService.renderInBackground(
      profile: data.profile,
      client: client,
      estimate: estimate,
      now: DateTime.now(),
    );
    await Printing.sharePdf(bytes: bytes, filename: '${estimate.number}.pdf');
  }

  Future<void> _convert(BuildContext context, WidgetRef ref) async {
    final invoice = await ref
        .read(appDataProvider.notifier)
        .convertEstimateToInvoice(estimate.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Draft invoice ${invoice.number} created'),
        action: SnackBarAction(
          label: 'Open',
          onPressed: () => context.go('/invoices/${invoice.id}'),
        ),
      ),
    );
  }

  Future<void> _duplicate(BuildContext context, WidgetRef ref) async {
    final copy = await ref
        .read(appDataProvider.notifier)
        .duplicateEstimate(estimate.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Duplicated as ${copy.number}')));
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete estimate?'),
        content: Text('${estimate.number} will be permanently deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await ref.read(appDataProvider.notifier).deleteEstimate(estimate.id);
    if (context.mounted) context.go('/invoices/estimates');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = data.clientById(estimate.clientId);
    final notifier = ref.read(appDataProvider.notifier);
    final totals = EstimateMath.totals(estimate);
    final isOpen =
        estimate.status == EstimateStatus.draft ||
        estimate.status == EstimateStatus.sent;

    return Scaffold(
      appBar: AppBar(
        title: Text(estimate.number),
        actions: [
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () =>
                context.go('/invoices/estimates/${estimate.id}/edit'),
          ),
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _delete(context, ref),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          AppSpacing.sm,
          AppSpacing.gutter,
          AppSpacing.xl,
        ),
        children: [
          HeroMetricCard(
            label: client == null
                ? 'Unknown client'
                : client.company.isEmpty
                ? client.name
                : '${client.name} — ${client.company}',
            trailing: EstimateStatusChip(estimate: estimate),
            value: AmountText(totals.total, style: AppTextStyles.display),
            delta: estimate.isConverted
                ? Flexible(
                    child: Text(
                      'Converted to invoice '
                      '${estimate.convertedInvoiceNumber ?? ''}',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: SuiteColors.of(context).textSecondary,
                      ),
                    ),
                  )
                : null,
            footer: [
              StatTile(
                label: 'Issued',
                value: Formats.date(estimate.issueDate),
              ),
              StatTile(
                label: 'Valid until',
                value: Formats.date(estimate.validUntil),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              QuickAction(
                icon: Icons.ios_share,
                label: 'Share PDF',
                onTap: () => _sharePdf(context),
              ),
              const SizedBox(width: AppSpacing.smd),
              QuickAction(
                icon: Icons.copy_outlined,
                label: 'Duplicate',
                onTap: () => _duplicate(context, ref),
              ),
              if (isOpen && !estimate.isConverted) ...[
                const SizedBox(width: AppSpacing.smd),
                QuickAction(
                  icon: Icons.receipt_long_outlined,
                  label: 'To invoice',
                  onTap: () => _convert(context, ref),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (estimate.status == EstimateStatus.draft)
            VaultButton(
              label: 'Mark as Sent',
              onPressed: () =>
                  notifier.setEstimateStatus(estimate.id, EstimateStatus.sent),
            ),
          if (estimate.status == EstimateStatus.sent) ...[
            Row(
              children: [
                Expanded(
                  child: VaultButton(
                    key: const Key('accept-estimate'),
                    label: 'Accept',
                    onPressed: () => notifier.setEstimateStatus(
                      estimate.id,
                      EstimateStatus.accepted,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.smd),
                Expanded(
                  child: VaultButton(
                    key: const Key('decline-estimate'),
                    label: 'Decline',
                    variant: VaultButtonVariant.secondary,
                    onPressed: () => notifier.setEstimateStatus(
                      estimate.id,
                      EstimateStatus.declined,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          const SectionHeader(title: 'Items'),
          InvoiceItemsCard(invoice: EstimateMath.shadowInvoice(estimate)),
          const SizedBox(height: AppSpacing.lg),
          const SectionHeader(title: 'PDF template'),
          TemplatePicker(
            selected: estimate.template,
            onChanged: (template) =>
                notifier.setEstimateTemplate(estimate.id, template),
          ),
          if (estimate.notes.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            const SectionHeader(title: 'Notes'),
            VaultCard(child: Text(estimate.notes)),
          ],
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}
