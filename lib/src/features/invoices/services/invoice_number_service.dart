import 'package:ledgerly/src/features/invoices/models/invoice.dart';

/// Generates per-year sequential document numbers: `PREFIX-YYYY-0001`.
///
/// The sequence restarts each year and is derived from existing numbers, so
/// deleting the latest document frees its number while gaps left by earlier
/// deletions are never reused (max + 1 semantics). Invoices and estimates
/// share the pattern but keep independent sequences via their prefixes.
abstract final class InvoiceNumberService {
  static String next({
    required Iterable<Invoice> existing,
    required String prefix,
    required int year,
  }) => nextNumber(
    existingNumbers: existing.map((i) => i.number),
    prefix: prefix,
    year: year,
  );

  /// Same as [next] but over raw number strings, so estimates (or any
  /// future numbered document) can reuse the sequence logic.
  static String nextNumber({
    required Iterable<String> existingNumbers,
    required String prefix,
    required int year,
    String fallbackPrefix = 'INV',
  }) {
    final effectivePrefix = prefix.trim().isEmpty
        ? fallbackPrefix
        : prefix.trim();
    final pattern = RegExp('^${RegExp.escape(effectivePrefix)}-$year-(\\d+)\$');

    var highest = 0;
    for (final number in existingNumbers) {
      final match = pattern.firstMatch(number);
      if (match == null) continue;
      final sequence = int.parse(match.group(1)!);
      if (sequence > highest) highest = sequence;
    }

    final nextSequence = (highest + 1).toString().padLeft(4, '0');
    return '$effectivePrefix-$year-$nextSequence';
  }
}
