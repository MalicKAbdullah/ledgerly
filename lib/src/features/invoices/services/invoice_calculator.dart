import 'package:flutter/foundation.dart';
import 'package:ledgerly/src/core/money/money.dart';
import 'package:ledgerly/src/features/invoices/models/invoice.dart';

/// Computed monetary breakdown of an invoice.
@immutable
final class InvoiceTotals {
  const InvoiceTotals({
    required this.subtotal,
    required this.discount,
    required this.taxableBase,
    required this.tax,
    required this.total,
  });

  final Money subtotal;
  final Money discount;
  final Money taxableBase;
  final Money tax;
  final Money total;
}

/// Pure invoice math. Rounding policy (documented app-wide): every
/// division rounds half-up, away from zero, and rounding happens at each
/// step — per line item, then on the discount, then on the tax — so the
/// printed rows always sum exactly to the printed total.
///
/// Order of operations: subtotal -> discount -> tax on the discounted base.
abstract final class InvoiceCalculator {
  static InvoiceTotals calculate(Invoice invoice) {
    final currency = invoice.currency;

    var subtotal = Money.zero(currency);
    for (final item in invoice.items) {
      subtotal += item.total(currency);
    }

    final discount = _discountAmount(invoice, subtotal);
    final taxableBase = subtotal - discount;
    final tax = taxableBase.percentBp(invoice.taxRateBp);
    final total = taxableBase + tax;

    return InvoiceTotals(
      subtotal: subtotal,
      discount: discount,
      taxableBase: taxableBase,
      tax: tax,
      total: total,
    );
  }

  /// Discount is never negative and never exceeds the subtotal.
  static Money _discountAmount(Invoice invoice, Money subtotal) {
    final currency = invoice.currency;
    switch (invoice.discountType) {
      case DiscountType.none:
        return Money.zero(currency);
      case DiscountType.percent:
        final raw = subtotal.percentBp(invoice.discountValue);
        return _clamp(raw, subtotal);
      case DiscountType.fixed:
        final raw = Money(invoice.discountValue, currency);
        return _clamp(raw, subtotal);
    }
  }

  static Money _clamp(Money value, Money max) {
    final nonNegative = value.clampNonNegative();
    return nonNegative > max ? max : nonNegative;
  }
}
