import 'package:core_theme/core_theme.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:ledgerly/src/core/formats.dart';
import 'package:ledgerly/src/core/money/money.dart';
import 'package:ledgerly/src/core/widgets/amount_text.dart';
import 'package:ledgerly/src/core/widgets/status_chip.dart';
import 'package:ledgerly/src/features/clients/models/client.dart';
import 'package:ledgerly/src/features/invoices/models/invoice.dart';
import 'package:ledgerly/src/features/invoices/models/invoice_template.dart';
import 'package:ledgerly/src/features/invoices/services/invoice_calculator.dart';
import 'package:ledgerly/src/features/invoices/services/payment_math.dart';

/// Hero card at the top of the invoice detail: total, status, client,
/// dates, and — when partially paid — the live balance.
final class InvoiceHeaderCard extends StatelessWidget {
  const InvoiceHeaderCard({
    required this.invoice,
    required this.client,
    super.key,
  });

  final Invoice invoice;
  final Client? client;

  @override
  Widget build(BuildContext context) {
    final c = SuiteColors.of(context);
    final totals = InvoiceCalculator.calculate(invoice);
    final paid = PaymentMath.amountPaid(invoice);
    final balance = PaymentMath.balanceDue(invoice, totals: totals);
    final partial = PaymentMath.isPartiallyPaid(invoice);
    final who = client == null
        ? 'Unknown client'
        : client!.company.isEmpty
        ? client!.name
        : '${client!.name} — ${client!.company}';

    return HeroMetricCard(
      label: who,
      trailing: StatusChip(invoice: invoice),
      value: AmountText(totals.total, style: AppTextStyles.display),
      delta: partial
          ? Flexible(
              child: Text(
                'Partially paid — ${paid.format()} of ${totals.total.format()} '
                'received, ${balance.format()} due',
                style: AppTextStyles.bodySmall.copyWith(color: c.warning),
              ),
            )
          : null,
      footer: [
        StatTile(label: 'Issued', value: Formats.date(invoice.issueDate)),
        StatTile(label: 'Due', value: Formats.date(invoice.dueDate)),
      ],
    );
  }
}

/// One tappable quick action (icon in tinted container + label).
final class QuickAction extends StatelessWidget {
  const QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = SuiteColors.of(context);
    return Expanded(
      child: VaultCard(
        onTap: onTap,
        radius: AppSpacing.radiusMd,
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.smd,
          horizontal: AppSpacing.xs,
        ),
        child: Column(
          children: [
            Icon(icon, size: 22, color: c.accent),
            const SizedBox(height: AppSpacing.sm),
            Text(
              label,
              style: AppTextStyles.caption.copyWith(color: c.textPrimary),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// Per-invoice PDF template picker.
final class TemplatePicker extends StatelessWidget {
  const TemplatePicker({
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final InvoiceTemplateId selected;
  final ValueChanged<InvoiceTemplateId> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = SuiteColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSegmentedControl<InvoiceTemplateId>(
          segments: [
            for (final template in InvoiceTemplateId.values)
              AppSegment(value: template, label: template.label),
          ],
          selected: selected,
          onChanged: onChanged,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          selected.description,
          style: AppTextStyles.bodySmall.copyWith(color: c.textSecondary),
        ),
      ],
    );
  }
}

/// Items + totals card, with tabular-figure amounts.
final class InvoiceItemsCard extends StatelessWidget {
  const InvoiceItemsCard({required this.invoice, super.key});

  final Invoice invoice;

  @override
  Widget build(BuildContext context) {
    final c = SuiteColors.of(context);
    final totals = InvoiceCalculator.calculate(invoice);
    final paid = PaymentMath.amountPaid(invoice);
    final balance = PaymentMath.balanceDue(invoice, totals: totals);

    Widget row(String label, String value, {bool bold = false, Color? color}) {
      final labelStyle = bold
          ? AppTextStyles.h4.copyWith(color: c.textPrimary)
          : AppTextStyles.bodyMedium.copyWith(color: c.textSecondary);
      final valueStyle =
          (bold ? AppTextStyles.number : AppTextStyles.numberSmall).copyWith(
            color: color ?? (bold ? c.textPrimary : c.textSecondary),
          );
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: labelStyle),
            Text(value, style: valueStyle),
          ],
        ),
      );
    }

    return VaultCard(
      child: Column(
        children: [
          for (final item in invoice.items) ...[
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.description,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: c.textPrimary,
                        ),
                      ),
                      Text(
                        '${formatQuantityMilli(item.quantityMilli)} × '
                        '${item.unitPrice(invoice.currency).format()}',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: c.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  item.total(invoice.currency).format(),
                  style: AppTextStyles.numberSmall.copyWith(
                    color: c.textPrimary,
                  ),
                ),
              ],
            ),
            if (item != invoice.items.last) const Divider(height: 20),
          ],
          const Divider(height: 24),
          row('Subtotal', totals.subtotal.format()),
          if (!totals.discount.isZero)
            row('Discount', '-${totals.discount.format()}'),
          if (invoice.taxRateBp != 0)
            row(
              'Tax (${formatBasisPoints(invoice.taxRateBp)}%)',
              totals.tax.format(),
            ),
          if (paid.isZero)
            row('Total', totals.total.format(), bold: true)
          else ...[
            row('Total', totals.total.format()),
            row('Paid', '-${paid.format()}', color: c.positive),
            row('Balance due', balance.format(), bold: true),
          ],
        ],
      ),
    );
  }
}
