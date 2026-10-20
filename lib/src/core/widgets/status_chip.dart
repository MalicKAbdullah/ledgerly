import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:ledgerly/src/core/widgets/status_pill.dart';
import 'package:ledgerly/src/features/invoices/models/invoice.dart';
import 'package:ledgerly/src/features/invoices/services/payment_math.dart';

/// Small pill showing invoice status in the suite's semantic colors:
/// draft = neutral, sent = info, partially paid = warning, paid = positive,
/// overdue = negative. Status changes cross-fade.
final class StatusChip extends StatelessWidget {
  const StatusChip({required this.invoice, super.key});

  final Invoice invoice;

  @override
  Widget build(BuildContext context) {
    final c = SuiteColors.of(context);
    final overdue = invoice.isOverdue(DateTime.now());
    final partial = PaymentMath.isPartiallyPaid(invoice);

    final (label, color, container) = switch ((
      overdue,
      partial,
      invoice.status,
    )) {
      (true, _, _) => ('Overdue', c.negative, c.negativeContainer),
      (_, true, _) => ('Partial', c.warning, c.warningContainer),
      (_, _, InvoiceStatus.draft) => ('Draft', c.textSecondary, c.surfaceAlt),
      (_, _, InvoiceStatus.sent) => ('Sent', c.info, c.infoContainer),
      (_, _, InvoiceStatus.paid) => ('Paid', c.positive, c.positiveContainer),
    };

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      transitionBuilder: (child, animation) =>
          FadeTransition(opacity: animation, child: child),
      child: StatusPill(
        key: ValueKey(label),
        label: label,
        color: color,
        container: container,
      ),
    );
  }
}
