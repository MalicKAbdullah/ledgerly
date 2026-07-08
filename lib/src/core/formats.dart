import 'package:intl/intl.dart';

/// Shared date formatting helpers.
abstract final class Formats {
  static final DateFormat _date = DateFormat.yMMMd();
  static final DateFormat _month = DateFormat.MMM();

  /// e.g. `Jul 3, 2026`
  static String date(DateTime value) => _date.format(value);

  /// e.g. `Jul`
  static String monthShort(DateTime value) => _month.format(value);
}
