import 'package:flutter/foundation.dart';
import 'package:ledgerly/src/core/money/money.dart';

/// How a payment was received.
enum PaymentMethod {
  bankTransfer,
  cash,
  card,
  paypal,
  other;

  static PaymentMethod fromName(String name) => PaymentMethod.values.firstWhere(
    (m) => m.name == name,
    orElse: () => PaymentMethod.other,
  );

  String get label => switch (this) {
    PaymentMethod.bankTransfer => 'Bank transfer',
    PaymentMethod.cash => 'Cash',
    PaymentMethod.card => 'Card',
    PaymentMethod.paypal => 'PayPal',
    PaymentMethod.other => 'Other',
  };
}

/// A payment recorded against an invoice. The amount is stored in minor
/// units of the invoice's currency (payments never have their own currency).
@immutable
final class Payment {
  const Payment({
    required this.id,
    required this.date,
    required this.amountMinor,
    this.method = PaymentMethod.bankTransfer,
    this.note = '',
  });

  factory Payment.fromJson(Map<String, dynamic> json) {
    return Payment(
      id: json['id'] as String,
      date: DateTime.parse(json['date'] as String),
      amountMinor: json['amountMinor'] as int,
      method: PaymentMethod.fromName(json['method'] as String? ?? ''),
      note: json['note'] as String? ?? '',
    );
  }

  final String id;
  final DateTime date;
  final int amountMinor;
  final PaymentMethod method;
  final String note;

  Money amount(String currency) => Money(amountMinor, currency);

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'date': date.toIso8601String(),
    'amountMinor': amountMinor,
    'method': method.name,
    'note': note,
  };
}
