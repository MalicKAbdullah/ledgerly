import 'package:ledgerly/src/core/money/money.dart';
import 'package:ledgerly/src/features/invoices/models/invoice.dart';
import 'package:ledgerly/src/features/invoices/services/invoice_calculator.dart';

/// Pure payment arithmetic. All rules in one place:
///
/// - **Amount paid** is the exact integer sum of recorded payments.
/// - **Balance due** = total − paid, never negative. A `paid` invoice always
///   has a zero balance, even when it was marked paid manually without
///   payment records (legacy invoices and the "mark as paid" shortcut).
/// - **Partially paid** = some money received, some still owed, and the
///   invoice not yet settled.
abstract final class PaymentMath {
  /// Exact sum of all recorded payments.
  static Money amountPaid(Invoice invoice) {
    var paid = Money.zero(invoice.currency);
    for (final payment in invoice.payments) {
      paid += payment.amount(invoice.currency);
    }
    return paid;
  }

  /// What the client still owes. Never negative; zero for settled invoices.
  static Money balanceDue(Invoice invoice, {InvoiceTotals? totals}) {
    if (invoice.status == InvoiceStatus.paid) {
      return Money.zero(invoice.currency);
    }
    final total = (totals ?? InvoiceCalculator.calculate(invoice)).total;
    return (total - amountPaid(invoice)).clampNonNegative();
  }

  /// True when payments cover part — but not all — of the total.
  static bool isPartiallyPaid(Invoice invoice) {
    if (invoice.status == InvoiceStatus.paid) return false;
    final paid = amountPaid(invoice);
    if (paid.isZero || paid.isNegative) return false;
    return !balanceDue(invoice).isZero;
  }

  /// Whether recording [amountMinor] against [invoice] is allowed:
  /// positive and no larger than the open balance (no overpayment).
  static PaymentValidation validatePayment(Invoice invoice, int amountMinor) {
    if (invoice.status == InvoiceStatus.paid) {
      return PaymentValidation.alreadyPaid;
    }
    if (amountMinor <= 0) return PaymentValidation.notPositive;
    final balance = balanceDue(invoice);
    if (amountMinor > balance.minorUnits) {
      return PaymentValidation.exceedsBalance;
    }
    return PaymentValidation.ok;
  }
}

enum PaymentValidation {
  ok,
  notPositive,
  exceedsBalance,
  alreadyPaid;

  bool get isOk => this == PaymentValidation.ok;
}
