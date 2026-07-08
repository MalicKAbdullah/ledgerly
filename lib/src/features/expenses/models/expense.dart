import 'package:flutter/foundation.dart';
import 'package:ledgerly/src/core/money/money.dart';

/// What kind of business cost an expense is.
enum ExpenseCategory {
  supplies,
  software,
  travel,
  fees,
  other;

  static ExpenseCategory fromName(String name) => ExpenseCategory.values
      .firstWhere((c) => c.name == name, orElse: () => ExpenseCategory.other);

  String get label => switch (this) {
    ExpenseCategory.supplies => 'Supplies',
    ExpenseCategory.software => 'Software',
    ExpenseCategory.travel => 'Travel',
    ExpenseCategory.fees => 'Fees',
    ExpenseCategory.other => 'Other',
  };
}

/// A business cost. The amount is stored in integer minor units of
/// [currency], same policy as invoices.
@immutable
final class Expense {
  const Expense({
    required this.id,
    required this.date,
    required this.category,
    required this.description,
    required this.amountMinor,
    required this.currency,
    this.clientId,
    this.note = '',
    required this.createdAt,
  });

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: json['id'] as String,
      date: DateTime.parse(json['date'] as String),
      category: ExpenseCategory.fromName(json['category'] as String? ?? ''),
      description: json['description'] as String? ?? '',
      amountMinor: json['amountMinor'] as int,
      currency: json['currency'] as String,
      clientId: json['clientId'] as String?,
      note: json['note'] as String? ?? '',
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  final String id;
  final DateTime date;
  final ExpenseCategory category;
  final String description;
  final int amountMinor;
  final String currency;

  /// Optional link to the client this cost was incurred for.
  final String? clientId;
  final String note;
  final DateTime createdAt;

  Money get amount => Money(amountMinor, currency);

  Expense copyWith({
    DateTime? date,
    ExpenseCategory? category,
    String? description,
    int? amountMinor,
    String? currency,
    String? Function()? clientId,
    String? note,
  }) {
    return Expense(
      id: id,
      date: date ?? this.date,
      category: category ?? this.category,
      description: description ?? this.description,
      amountMinor: amountMinor ?? this.amountMinor,
      currency: currency ?? this.currency,
      clientId: clientId == null ? this.clientId : clientId(),
      note: note ?? this.note,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'date': date.toIso8601String(),
    'category': category.name,
    'description': description,
    'amountMinor': amountMinor,
    'currency': currency,
    'clientId': clientId,
    'note': note,
    'createdAt': createdAt.toIso8601String(),
  };
}
