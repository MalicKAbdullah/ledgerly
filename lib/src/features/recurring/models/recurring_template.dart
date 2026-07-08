import 'package:flutter/foundation.dart';
import 'package:ledgerly/src/features/invoices/models/invoice.dart';
import 'package:ledgerly/src/features/invoices/models/invoice_template.dart';

/// How often a recurring template fires.
enum RecurrenceFrequency {
  weekly,
  monthly;

  static RecurrenceFrequency fromName(String name) =>
      RecurrenceFrequency.values.firstWhere(
        (f) => f.name == name,
        orElse: () => RecurrenceFrequency.monthly,
      );
}

/// A blueprint that materializes into real invoices on a schedule.
///
/// Schedules:
/// - `weekly` — every 7 days from [startDate]; [dayOfMonth] and
///   [intervalMonths] are ignored.
/// - `monthly` — on [dayOfMonth] every [intervalMonths] month(s). Days past
///   the end of a month clamp to its last day (31st → Feb 28/29) while the
///   anchor day is preserved for later months.
@immutable
final class RecurringTemplate {
  const RecurringTemplate({
    required this.id,
    required this.clientId,
    required this.currency,
    this.items = const <LineItem>[],
    this.taxRateBp = 0,
    this.discountType = DiscountType.none,
    this.discountValue = 0,
    this.notes = '',
    this.template = InvoiceTemplateId.classic,
    required this.frequency,
    this.dayOfMonth = 1,
    this.intervalMonths = 1,
    required this.startDate,
    this.endDate,
    this.dueInDays = 14,
    this.active = true,
    required this.nextRunDate,
    required this.createdAt,
  });

  factory RecurringTemplate.fromJson(Map<String, dynamic> json) {
    return RecurringTemplate(
      id: json['id'] as String,
      clientId: json['clientId'] as String,
      currency: json['currency'] as String,
      items: (json['items'] as List<dynamic>? ?? const <dynamic>[])
          .map((e) => LineItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      taxRateBp: json['taxRateBp'] as int? ?? 0,
      discountType: DiscountType.fromName(
        json['discountType'] as String? ?? '',
      ),
      discountValue: json['discountValue'] as int? ?? 0,
      notes: json['notes'] as String? ?? '',
      template: InvoiceTemplateId.fromName(json['template'] as String? ?? ''),
      frequency: RecurrenceFrequency.fromName(
        json['frequency'] as String? ?? '',
      ),
      dayOfMonth: json['dayOfMonth'] as int? ?? 1,
      intervalMonths: json['intervalMonths'] as int? ?? 1,
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: json['endDate'] == null
          ? null
          : DateTime.parse(json['endDate'] as String),
      dueInDays: json['dueInDays'] as int? ?? 14,
      active: json['active'] as bool? ?? true,
      nextRunDate: DateTime.parse(json['nextRunDate'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  final String id;
  final String clientId;
  final String currency;
  final List<LineItem> items;
  final int taxRateBp;
  final DiscountType discountType;
  final int discountValue;
  final String notes;

  /// PDF template generated invoices use.
  final InvoiceTemplateId template;
  final RecurrenceFrequency frequency;

  /// Anchor day for monthly schedules (1–31, clamped per month).
  final int dayOfMonth;

  /// 1 = every month, 3 = quarterly, … (monthly schedules only).
  final int intervalMonths;
  final DateTime startDate;

  /// No invoices are generated after this date (inclusive). Null = forever.
  final DateTime? endDate;

  /// Generated invoices are due this many days after their issue date.
  final int dueInDays;
  final bool active;

  /// The next date an invoice should be generated for.
  final DateTime nextRunDate;
  final DateTime createdAt;

  /// Human-readable schedule, e.g. "Monthly on day 15" or "Every 3 months".
  String describeSchedule() {
    switch (frequency) {
      case RecurrenceFrequency.weekly:
        return 'Weekly';
      case RecurrenceFrequency.monthly:
        final every = intervalMonths <= 1
            ? 'Monthly'
            : 'Every $intervalMonths months';
        return '$every on day $dayOfMonth';
    }
  }

  RecurringTemplate copyWith({
    String? clientId,
    String? currency,
    List<LineItem>? items,
    int? taxRateBp,
    DiscountType? discountType,
    int? discountValue,
    String? notes,
    InvoiceTemplateId? template,
    RecurrenceFrequency? frequency,
    int? dayOfMonth,
    int? intervalMonths,
    DateTime? startDate,
    DateTime? Function()? endDate,
    int? dueInDays,
    bool? active,
    DateTime? nextRunDate,
  }) {
    return RecurringTemplate(
      id: id,
      clientId: clientId ?? this.clientId,
      currency: currency ?? this.currency,
      items: items ?? this.items,
      taxRateBp: taxRateBp ?? this.taxRateBp,
      discountType: discountType ?? this.discountType,
      discountValue: discountValue ?? this.discountValue,
      notes: notes ?? this.notes,
      template: template ?? this.template,
      frequency: frequency ?? this.frequency,
      dayOfMonth: dayOfMonth ?? this.dayOfMonth,
      intervalMonths: intervalMonths ?? this.intervalMonths,
      startDate: startDate ?? this.startDate,
      endDate: endDate == null ? this.endDate : endDate(),
      dueInDays: dueInDays ?? this.dueInDays,
      active: active ?? this.active,
      nextRunDate: nextRunDate ?? this.nextRunDate,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'clientId': clientId,
    'currency': currency,
    'items': items.map((i) => i.toJson()).toList(),
    'taxRateBp': taxRateBp,
    'discountType': discountType.name,
    'discountValue': discountValue,
    'notes': notes,
    'template': template.name,
    'frequency': frequency.name,
    'dayOfMonth': dayOfMonth,
    'intervalMonths': intervalMonths,
    'startDate': startDate.toIso8601String(),
    'endDate': endDate?.toIso8601String(),
    'dueInDays': dueInDays,
    'active': active,
    'nextRunDate': nextRunDate.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
  };
}
