import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:ledgerly/src/features/invoices/models/invoice.dart';
import 'package:ledgerly/src/features/invoices/services/payment_math.dart';

/// Small pill showing invoice status in the suite's semantic colors:
/// draft = neutral, sent = info, partially paid = warning, paid = success,
/// overdue = error. Status changes cross-fade.
final class StatusChip extends StatelessWidget {
  const StatusChip({required this.invoice, super.key});

  final Invoice invoice;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final overdue = invoice.isOverdue(DateTime.now());
    final partial = PaymentMath.isPartiallyPaid(invoice);

    final (label, color, container) = switch ((
      overdue,
      partial,
      invoice.status,
    )) {
      (true, _, _) => (
        'Overdue',
        AppColors.error(brightness),
        brightness == Brightness.dark
            ? AppColors.errorContainerDark
            : AppColors.errorContainerLight,
      ),
      (_, true, _) => (
        'Partial',
        AppColors.warning(brightness),
        brightness == Brightness.dark
            ? AppColors.warningContainerDark
            : AppColors.warningContainerLight,
      ),
      (_, _, InvoiceStatus.draft) => (
        'Draft',
        AppColors.textTertiary(brightness),
        AppColors.surfaceAlt(brightness),
      ),
      (_, _, InvoiceStatus.sent) => (
        'Sent',
        AppColors.info(brightness),
        brightness == Brightness.dark
            ? const Color(0xFF172554)
            : const Color(0xFFDBEAFE),
      ),
      (_, _, InvoiceStatus.paid) => (
        'Paid',
        AppColors.success(brightness),
        brightness == Brightness.dark
            ? AppColors.successContainerDark
            : AppColors.successContainerLight,
      ),
    };

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      transitionBuilder: (child, animation) =>
          FadeTransition(opacity: animation, child: child),
      child: Container(
        key: ValueKey(label),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: container,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
