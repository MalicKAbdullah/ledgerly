import 'package:ledgerly/src/core/data/app_data.dart';
import 'package:ledgerly/src/features/invoices/models/invoice.dart';
import 'package:ledgerly/src/features/invoices/services/invoice_calculator.dart';
import 'package:ledgerly/src/features/invoices/services/payment_math.dart';

/// Builds a CSV summary of invoices — pure string work, fully unit-tested.
///
/// Dates are ISO (yyyy-mm-dd) and amounts are plain decimals with a
/// separate currency column, so the file imports cleanly into any
/// spreadsheet regardless of locale.
abstract final class CsvExportService {
  static const String header =
      'Number,Client,Issue Date,Due Date,Status,Currency,Total,Paid,Balance';

  static String buildCsv({
    required List<Invoice> invoices,
    required AppData data,
    required DateTime now,
  }) {
    final rows = <String>[header];
    final sorted = [...invoices]
      ..sort((a, b) => a.issueDate.compareTo(b.issueDate));

    for (final invoice in sorted) {
      final totals = InvoiceCalculator.calculate(invoice);
      final paid = PaymentMath.amountPaid(invoice);
      final balance = PaymentMath.balanceDue(invoice, totals: totals);
      rows.add(
        [
          escape(invoice.number),
          escape(data.clientById(invoice.clientId)?.name ?? 'Unknown'),
          _isoDate(invoice.issueDate),
          _isoDate(invoice.dueDate),
          escape(_status(invoice, now)),
          invoice.currency,
          totals.total.toDecimalString(),
          paid.toDecimalString(),
          balance.toDecimalString(),
        ].join(','),
      );
    }
    return rows.join('\r\n');
  }

  static String _status(Invoice invoice, DateTime now) {
    if (invoice.isOverdue(now)) return 'Overdue';
    if (PaymentMath.isPartiallyPaid(invoice)) return 'Partially paid';
    return invoice.status.name[0].toUpperCase() +
        invoice.status.name.substring(1);
  }

  static String _isoDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  /// RFC 4180 escaping: quote fields containing commas, quotes, or
  /// newlines; double any embedded quotes.
  static String escape(String field) {
    if (field.contains(',') ||
        field.contains('"') ||
        field.contains('\n') ||
        field.contains('\r')) {
      return '"${field.replaceAll('"', '""')}"';
    }
    return field;
  }
}
