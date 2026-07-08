import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

/// Currency metadata: ISO 4217 codes and their minor-unit exponents.
abstract final class Currencies {
  static const Map<String, int> _decimalDigits = <String, int>{
    'BHD': 3,
    'IQD': 3,
    'JOD': 3,
    'KWD': 3,
    'OMR': 3,
    'TND': 3,
    'JPY': 0,
    'KRW': 0,
    'VND': 0,
  };

  /// Currencies offered in the UI. Any valid ISO code still works in [Money].
  static const List<String> supported = <String>[
    'USD',
    'EUR',
    'GBP',
    'PKR',
    'AED',
    'SAR',
    'INR',
    'CAD',
    'AUD',
    'JPY',
    'CHF',
    'KWD',
  ];

  /// Number of digits after the decimal point for [code] (default 2).
  static int decimalDigits(String code) => _decimalDigits[code] ?? 2;

  /// Display symbol for [code], e.g. `$` for USD.
  static String symbol(String code) =>
      NumberFormat.simpleCurrency(name: code).currencySymbol;
}

/// An immutable amount of money stored as integer minor units (e.g. cents)
/// plus an ISO 4217 currency code.
///
/// All arithmetic is exact integer arithmetic. Division (percentages and
/// fractional quantities) rounds **half-up, away from zero**: 0.5 minor
/// units round to 1, and -0.5 round to -1. This matches common invoicing
/// conventions and is documented app-wide.
@immutable
final class Money implements Comparable<Money> {
  const Money(this.minorUnits, this.currency);

  /// Zero in the given currency.
  const Money.zero(this.currency) : minorUnits = 0;

  /// Parses a decimal string such as `"1234.50"` into exact minor units.
  ///
  /// Digits beyond the currency's precision are rounded half-up.
  /// Throws [FormatException] for malformed input.
  factory Money.parse(String input, String currency) =>
      Money(parseScaled(input, Currencies.decimalDigits(currency)), currency);

  /// Parses a decimal string into an integer scaled by 10^[digits].
  /// Digits beyond [digits] are rounded half-up (away from zero).
  /// Throws [FormatException] for malformed input.
  static int parseScaled(String input, int digits) {
    final trimmed = input.trim().replaceAll(',', '');
    final match = _decimalPattern.firstMatch(trimmed);
    if (match == null || trimmed.isEmpty || trimmed == '-' || trimmed == '+') {
      throw FormatException('Invalid amount: "$input"');
    }
    final negative = match.group(1) == '-';
    final wholePart = match.group(2) ?? '0';
    final fracPart = match.group(3) ?? '';
    if ((match.group(2) ?? '').isEmpty && fracPart.isEmpty) {
      throw FormatException('Invalid amount: "$input"');
    }

    var scaled = int.parse(wholePart) * _pow10(digits);
    if (fracPart.isNotEmpty) {
      // Keep one extra digit to apply half-up rounding.
      final padded = fracPart.padRight(digits + 1, '0');
      final kept = int.parse(padded.substring(0, digits + 1));
      scaled += (kept + 5) ~/ 10;
    }
    return negative ? -scaled : scaled;
  }

  static final RegExp _decimalPattern = RegExp(r'^([+-]?)(\d+)?(?:\.(\d+))?$');

  final int minorUnits;
  final String currency;

  bool get isZero => minorUnits == 0;
  bool get isNegative => minorUnits < 0;

  Money operator +(Money other) {
    _assertSameCurrency(other);
    return Money(minorUnits + other.minorUnits, currency);
  }

  Money operator -(Money other) {
    _assertSameCurrency(other);
    return Money(minorUnits - other.minorUnits, currency);
  }

  Money operator -() => Money(-minorUnits, currency);

  bool operator >(Money other) {
    _assertSameCurrency(other);
    return minorUnits > other.minorUnits;
  }

  bool operator <(Money other) {
    _assertSameCurrency(other);
    return minorUnits < other.minorUnits;
  }

  /// Multiplies by an integer factor (exact).
  Money times(int factor) => Money(minorUnits * factor, currency);

  /// Applies a percentage expressed in basis points (1 bp = 0.01%).
  /// `750` means 7.5%. Rounds half-up away from zero.
  Money percentBp(int basisPoints) =>
      Money(_divRoundHalfUp(minorUnits * basisPoints, 10000), currency);

  /// Multiplies by a quantity expressed in thousandths (`1500` = 1.5).
  /// Rounds half-up away from zero.
  Money timesQuantityMilli(int quantityMilli) =>
      Money(_divRoundHalfUp(minorUnits * quantityMilli, 1000), currency);

  /// Clamps to be no less than zero.
  Money clampNonNegative() => minorUnits < 0 ? Money.zero(currency) : this;

  /// Integer division rounding half-up, away from zero.
  /// [denominator] must be positive.
  static int _divRoundHalfUp(int numerator, int denominator) {
    assert(denominator > 0, 'denominator must be positive');
    final quotient = (numerator.abs() + denominator ~/ 2) ~/ denominator;
    return numerator < 0 ? -quotient : quotient;
  }

  static int _pow10(int exponent) {
    var result = 1;
    for (var i = 0; i < exponent; i++) {
      result *= 10;
    }
    return result;
  }

  /// Formats with currency symbol and thousands grouping, e.g. `$1,234.50`.
  /// Built from integers only — no double conversion, so it stays exact.
  String format() {
    final digits = Currencies.decimalDigits(currency);
    final symbol = Currencies.symbol(currency);
    final sign = minorUnits < 0 ? '-' : '';
    final abs = minorUnits.abs();
    final factor = _pow10(digits);
    final whole = NumberFormat.decimalPattern('en_US').format(abs ~/ factor);
    if (digits == 0) return '$sign$symbol$whole';
    final frac = (abs % factor).toString().padLeft(digits, '0');
    return '$sign$symbol$whole.$frac';
  }

  /// Plain decimal string without symbol or grouping, e.g. `1234.50`.
  /// Suitable for pre-filling edit fields and round-tripping via [Money.parse].
  String toDecimalString() {
    final digits = Currencies.decimalDigits(currency);
    final sign = minorUnits < 0 ? '-' : '';
    final abs = minorUnits.abs();
    final factor = _pow10(digits);
    if (digits == 0) return '$sign${abs ~/ factor}';
    final frac = (abs % factor).toString().padLeft(digits, '0');
    return '$sign${abs ~/ factor}.$frac';
  }

  void _assertSameCurrency(Money other) {
    if (other.currency != currency) {
      throw ArgumentError('Currency mismatch: $currency vs ${other.currency}');
    }
  }

  @override
  int compareTo(Money other) {
    _assertSameCurrency(other);
    return minorUnits.compareTo(other.minorUnits);
  }

  @override
  bool operator ==(Object other) =>
      other is Money &&
      other.minorUnits == minorUnits &&
      other.currency == currency;

  @override
  int get hashCode => Object.hash(minorUnits, currency);

  @override
  String toString() => 'Money(${toDecimalString()} $currency)';
}

/// Parses a human-entered percentage such as `"7.5"` into basis points
/// (`750`). Returns null for malformed input. Rounds beyond 2 decimals.
int? tryParseBasisPoints(String input) {
  final trimmed = input.trim().replaceAll('%', '');
  if (trimmed.isEmpty) return 0;
  try {
    // Percent with 2 decimals maps exactly onto basis points.
    return Money.parseScaled(trimmed, 2);
  } on FormatException {
    return null;
  }
}

/// Formats basis points as a human percentage, e.g. `750` -> `7.5`.
String formatBasisPoints(int basisPoints) {
  final sign = basisPoints < 0 ? '-' : '';
  final abs = basisPoints.abs();
  final whole = abs ~/ 100;
  final frac = abs % 100;
  if (frac == 0) return '$sign$whole';
  final fracStr = frac % 10 == 0
      ? '${frac ~/ 10}'
      : frac.toString().padLeft(2, '0');
  return '$sign$whole.$fracStr';
}

/// Parses a quantity such as `"1.5"` into thousandths (`1500`).
/// Returns null for malformed or negative input.
int? tryParseQuantityMilli(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return null;
  try {
    final milli = Money.parseScaled(trimmed, 3);
    return milli < 0 ? null : milli;
  } on FormatException {
    return null;
  }
}

/// Formats thousandths quantity for display: `1500` -> `1.5`, `2000` -> `2`.
String formatQuantityMilli(int quantityMilli) {
  final whole = quantityMilli ~/ 1000;
  final frac = quantityMilli % 1000;
  if (frac == 0) return '$whole';
  var fracStr = frac.toString().padLeft(3, '0');
  while (fracStr.endsWith('0')) {
    fracStr = fracStr.substring(0, fracStr.length - 1);
  }
  return '$whole.$fracStr';
}
