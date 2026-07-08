import 'package:ledgerly/src/features/estimates/models/estimate.dart';
import 'package:ledgerly/src/features/invoices/models/invoice.dart';
import 'package:ledgerly/src/features/invoices/services/invoice_calculator.dart';

/// Estimate money math — identical to invoices by construction: the
/// estimate is projected onto a shadow [Invoice] and run through the same
/// [InvoiceCalculator] (subtotal → discount → tax, half-up rounding).
abstract final class EstimateMath {
  static InvoiceTotals totals(Estimate estimate) =>
      InvoiceCalculator.calculate(shadowInvoice(estimate));

  /// A read-only invoice projection of [estimate] (no payments, draft) used
  /// for totals and PDF rendering. Never persisted.
  static Invoice shadowInvoice(Estimate estimate) {
    return Invoice(
      id: estimate.id,
      number: estimate.number,
      clientId: estimate.clientId,
      currency: estimate.currency,
      issueDate: estimate.issueDate,
      dueDate: estimate.validUntil,
      items: estimate.items,
      taxRateBp: estimate.taxRateBp,
      discountType: estimate.discountType,
      discountValue: estimate.discountValue,
      notes: estimate.notes,
      template: estimate.template,
      createdAt: estimate.createdAt,
    );
  }
}
