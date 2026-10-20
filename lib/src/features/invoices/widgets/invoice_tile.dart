import 'package:core_theme/core_theme.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:ledgerly/src/core/formats.dart';
import 'package:ledgerly/src/core/widgets/amount_text.dart';
import 'package:ledgerly/src/core/widgets/status_chip.dart';
import 'package:ledgerly/src/features/invoices/models/invoice.dart';
import 'package:ledgerly/src/features/invoices/services/invoice_calculator.dart';

/// Invoice row used on the dashboard, invoice list, and client detail
/// screens. Place several inside a [RowGroup] with a
/// [InvoiceTile.separatorIndent] inset.
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

  /// Separator inset for a [RowGroup] of invoice rows (no leading badge).
  static const double separatorIndent = AppSpacing.md;

  @override
  Widget build(BuildContext context) {
    final total = InvoiceCalculator.calculate(invoice).total;

    return AppListRow(
      onTap: onTap,
      title: invoice.number,
      subtitle: 'Due ${Formats.dateShort(invoice.dueDate)} · $clientName',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              AmountText(
                total,
                style: AppTextStyles.number,
                alignment: AlignmentDirectional.centerEnd,
              ),
              const SizedBox(height: AppSpacing.xs),
              StatusChip(invoice: invoice),
            ],
          ),
          ?trailing,
        ],
      ),
    );
  }
}
