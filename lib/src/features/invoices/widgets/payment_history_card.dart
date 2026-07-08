import 'package:core_theme/core_theme.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:ledgerly/src/core/formats.dart';
import 'package:ledgerly/src/features/invoices/models/invoice.dart';
import 'package:ledgerly/src/features/invoices/models/payment.dart';

/// Payment history rows on the invoice detail screen. Long-press a row to
/// remove a mistakenly recorded payment.
final class PaymentHistoryCard extends StatelessWidget {
  const PaymentHistoryCard({
    required this.invoice,
    required this.onRemove,
    super.key,
  });

  final Invoice invoice;
  final ValueChanged<Payment> onRemove;

  Future<void> _confirmRemove(BuildContext context, Payment payment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove payment?'),
        content: Text(
          'Remove the ${payment.amount(invoice.currency).format()} payment '
          'from ${Formats.date(payment.date)}? The balance due will go '
          'back up.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true) onRemove(payment);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final success = AppColors.success(brightness);
    final successContainer = brightness == Brightness.dark
        ? AppColors.successContainerDark
        : AppColors.successContainerLight;

    return VaultCard(
      child: Column(
        children: [
          for (final payment in invoice.payments) ...[
            InkWell(
              onLongPress: () => _confirmRemove(context, payment),
              borderRadius: BorderRadius.circular(AppSpacing.sm),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: successContainer,
                        borderRadius: BorderRadius.circular(AppSpacing.sm),
                      ),
                      child: Icon(
                        Icons.payments_outlined,
                        size: 18,
                        color: success,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            payment.method.label,
                            style: theme.textTheme.titleSmall,
                          ),
                          Text(
                            payment.note.isEmpty
                                ? Formats.date(payment.date)
                                : '${Formats.date(payment.date)} · ${payment.note}',
                            style: theme.textTheme.bodySmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Text(
                      payment.amount(invoice.currency).format(),
                      style: AppTextStyles.number.copyWith(color: success),
                    ),
                  ],
                ),
              ),
            ),
            if (payment != invoice.payments.last) const Divider(height: 16),
          ],
        ],
      ),
    );
  }
}
