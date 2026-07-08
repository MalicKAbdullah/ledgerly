import 'package:core_theme/core_theme.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:ledgerly/src/core/formats.dart';
import 'package:ledgerly/src/core/money/money.dart';
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
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final totals = InvoiceCalculator.calculate(invoice);
    final paid = PaymentMath.amountPaid(invoice);
    final balance = PaymentMath.balanceDue(invoice, totals: totals);
    final partial = PaymentMath.isPartiallyPaid(invoice);

    return VaultCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    totals.total.format(),
                    style: AppTextStyles.numberLarge.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              StatusChip(invoice: invoice),
            ],
          ),
          if (partial) ...[
            const SizedBox(height: AppSpacing.sm),
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm + 2,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: brightness == Brightness.dark
                    ? AppColors.warningContainerDark
                    : AppColors.warningContainerLight,
                borderRadius: BorderRadius.circular(AppSpacing.sm),
              ),
              child: Text(
                'Partially paid — ${paid.format()} of ${totals.total.format()} '
                'received, ${balance.format()} due',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.warning(brightness),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Text(
            client == null
                ? 'Unknown client'
                : client!.company.isEmpty
                ? client!.name
                : '${client!.name} — ${client!.company}',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Issued ${Formats.date(invoice.issueDate)} · '
            'Due ${Formats.date(invoice.dueDate)}',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
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
    final theme = Theme.of(context);
    return Expanded(
      child: VaultCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.md,
          horizontal: AppSpacing.xs,
        ),
        child: Column(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(AppSpacing.sm + 2),
              ),
              child: Icon(icon, size: 19, color: theme.colorScheme.primary),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              label,
              style: theme.textTheme.labelMedium,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<InvoiceTemplateId>(
            segments: [
              for (final template in InvoiceTemplateId.values)
                ButtonSegment(value: template, label: Text(template.label)),
            ],
            selected: {selected},
            onSelectionChanged: (selection) => onChanged(selection.first),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          selected.description,
          style: Theme.of(context).textTheme.bodySmall,
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
    final theme = Theme.of(context);
    final totals = InvoiceCalculator.calculate(invoice);
    final paid = PaymentMath.amountPaid(invoice);
    final balance = PaymentMath.balanceDue(invoice, totals: totals);

    Widget row(String label, String value, {bool bold = false, Color? color}) {
      final labelStyle = bold
          ? theme.textTheme.titleMedium
          : theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            );
      final valueStyle =
          (bold ? AppTextStyles.number : AppTextStyles.numberSmall).copyWith(
            color:
                color ??
                (bold
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.onSurfaceVariant),
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
                      Text(item.description, style: theme.textTheme.labelLarge),
                      Text(
                        '${formatQuantityMilli(item.quantityMilli)} × '
                        '${item.unitPrice(invoice.currency).format()}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Text(
                  item.total(invoice.currency).format(),
                  style: AppTextStyles.numberSmall.copyWith(
                    color: theme.colorScheme.onSurface,
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
            row(
              'Paid',
              '-${paid.format()}',
              color: AppColors.success(theme.brightness),
            ),
            row('Balance due', balance.format(), bold: true),
          ],
        ],
      ),
    );
  }
}
