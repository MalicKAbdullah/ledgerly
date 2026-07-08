import 'package:core_theme/core_theme.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:ledgerly/src/core/formats.dart';
import 'package:ledgerly/src/core/widgets/status_chip.dart';
import 'package:ledgerly/src/features/invoices/models/invoice.dart';
import 'package:ledgerly/src/features/invoices/services/invoice_calculator.dart';

/// Compact invoice row used on the dashboard, invoice list, and client
/// detail screens.
final class InvoiceTile extends StatelessWidget {
  const InvoiceTile({
    required this.invoice,
    required this.clientName,
    this.onTap,
    this.trailing,
    super.key,
  });

  final Invoice invoice;
  final String clientName;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = InvoiceCalculator.calculate(invoice).total;

    return VaultCard(
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        invoice.number,
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    StatusChip(invoice: invoice),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  clientName,
                  style: theme.textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                total.format(),
                style: AppTextStyles.number.copyWith(
                  fontSize: 15,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Due ${Formats.date(invoice.dueDate)}',
                style: theme.textTheme.labelSmall,
              ),
            ],
          ),
          ?trailing,
        ],
      ),
    );
  }
}
