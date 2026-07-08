import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:ledgerly/src/core/formats.dart';
import 'package:ledgerly/src/features/invoices/models/invoice.dart';

/// One event on the invoice's life story.
final class InvoiceEvent {
  const InvoiceEvent({
    required this.date,
    required this.label,
    required this.icon,
    this.detail = '',
  });

  final DateTime date;
  final String label;
  final String detail;
  final IconData icon;
}

/// Builds the chronological event list for an invoice: created, sent,
/// every payment, and settled. Pure — easy to test and reuse.
List<InvoiceEvent> buildInvoiceEvents(Invoice invoice) {
  final events = <InvoiceEvent>[
    InvoiceEvent(
      date: invoice.createdAt,
      label: 'Invoice created',
      icon: Icons.note_add_outlined,
    ),
    if (invoice.sentAt != null)
      InvoiceEvent(
        date: invoice.sentAt!,
        label: 'Sent to client',
        icon: Icons.send_outlined,
      ),
    for (final payment in invoice.payments)
      InvoiceEvent(
        date: payment.date,
        label: 'Payment received',
        detail:
            '${payment.amount(invoice.currency).format()}'
            ' · ${payment.method.label}',
        icon: Icons.payments_outlined,
      ),
    if (invoice.paidAt != null)
      InvoiceEvent(
        date: invoice.paidAt!,
        label: 'Paid in full',
        icon: Icons.check_circle_outline,
      ),
  ]..sort((a, b) => a.date.compareTo(b.date));
  return events;
}

/// Vertical timeline of an invoice's events.
final class InvoiceTimeline extends StatelessWidget {
  const InvoiceTimeline({required this.invoice, super.key});

  final Invoice invoice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final events = buildInvoiceEvents(invoice);

    return Column(
      children: [
        for (var i = 0; i < events.length; i++)
          _TimelineRow(
            event: events[i],
            isLast: i == events.length - 1,
            theme: theme,
          ),
      ],
    );
  }
}

final class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.event,
    required this.isLast,
    required this.theme,
  });

  final InvoiceEvent event;
  final bool isLast;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(event.icon, size: 15, color: scheme.primary),
              ),
              if (!isLast)
                Expanded(
                  child: Container(width: 2, color: scheme.outlineVariant),
                ),
            ],
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(event.label, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text(
                    event.detail.isEmpty
                        ? Formats.date(event.date)
                        : '${Formats.date(event.date)} · ${event.detail}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
