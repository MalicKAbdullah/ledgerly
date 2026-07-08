import 'package:ledgerly/src/core/data/app_data.dart';
import 'package:ledgerly/src/features/expenses/models/expense.dart';
import 'package:ledgerly/src/features/invoices/services/csv_export_service.dart';

/// Builds a CSV summary of expenses — pure string work, fully unit-tested.
/// Same conventions as the invoice export: ISO dates, plain decimal
/// amounts, separate currency column, RFC 4180 escaping.
abstract final class ExpenseCsvService {
  static const String header =
      'Date,Category,Description,Client,Currency,Amount,Note';

  static String buildCsv({
    required List<Expense> expenses,
    required AppData data,
  }) {
    final rows = <String>[header];
    final sorted = [...expenses]..sort((a, b) => a.date.compareTo(b.date));

    for (final expense in sorted) {
      final clientId = expense.clientId;
      final clientName = clientId == null
          ? ''
          : data.clientById(clientId)?.name ?? 'Unknown';
      rows.add(
        [
          _isoDate(expense.date),
          expense.category.label,
          CsvExportService.escape(expense.description),
          CsvExportService.escape(clientName),
          expense.currency,
          expense.amount.toDecimalString(),
          CsvExportService.escape(expense.note),
        ].join(','),
      );
    }
    return rows.join('\r\n');
  }

  static String _isoDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
