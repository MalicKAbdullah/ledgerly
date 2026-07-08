import 'package:flutter/foundation.dart';
import 'package:ledgerly/src/core/money/money.dart';
import 'package:ledgerly/src/features/invoices/models/invoice_template.dart';
import 'package:ledgerly/src/features/invoices/models/payment.dart';

/// Persisted invoice lifecycle states. `overdue` is derived, never stored —
/// see [Invoice.isOverdue].
enum InvoiceStatus {
  draft,
  sent,
  paid;

  static InvoiceStatus fromName(String name) => InvoiceStatus.values.firstWhere(
    (s) => s.name == name,
    orElse: () => InvoiceStatus.draft,
  );
}

enum DiscountType {
  none,
  percent,
  fixed;

  static DiscountType fromName(String name) => DiscountType.values.firstWhere(
    (t) => t.name == name,
    orElse: () => DiscountType.none,
  );
}

/// One billable row on an invoice. Quantity is stored in thousandths
/// (1500 = 1.5 hours); unit price in minor units of the invoice currency.
@immutable
final class LineItem {
  const LineItem({
    required this.id,
    required this.description,
    required this.quantityMilli,
    required this.unitPriceMinor,
  });

  factory LineItem.fromJson(Map<String, dynamic> json) {
    return LineItem(
      id: json['id'] as String,
      description: json['description'] as String,
      quantityMilli: json['quantityMilli'] as int,
      unitPriceMinor: json['unitPriceMinor'] as int,
    );
  }

  final String id;
  final String description;
  final int quantityMilli;
  final int unitPriceMinor;

  Money unitPrice(String currency) => Money(unitPriceMinor, currency);

  /// quantity x unit price, rounded half-up per line.
  Money total(String currency) =>
      unitPrice(currency).timesQuantityMilli(quantityMilli);

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'description': description,
    'quantityMilli': quantityMilli,
    'unitPriceMinor': unitPriceMinor,
  };
}

/// An invoice. All monetary fields are in [currency] minor units; rates are
/// basis points. Totals are always computed by `InvoiceCalculator`, never
/// stored.
@immutable
final class Invoice {
  const Invoice({
    required this.id,
    required this.number,
    required this.clientId,
    required this.currency,
    required this.issueDate,
    required this.dueDate,
    this.items = const <LineItem>[],
    this.taxRateBp = 0,
    this.discountType = DiscountType.none,
    this.discountValue = 0,
    this.notes = '',
    this.status = InvoiceStatus.draft,
    this.payments = const <Payment>[],
    this.template = InvoiceTemplateId.classic,
    required this.createdAt,
    this.sentAt,
    this.paidAt,
    this.estimateId,
  });

  factory Invoice.fromJson(Map<String, dynamic> json) {
    return Invoice(
      id: json['id'] as String,
      number: json['number'] as String,
      clientId: json['clientId'] as String,
      currency: json['currency'] as String,
      issueDate: DateTime.parse(json['issueDate'] as String),
      dueDate: DateTime.parse(json['dueDate'] as String),
      items: (json['items'] as List<dynamic>)
          .map((e) => LineItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      taxRateBp: json['taxRateBp'] as int? ?? 0,
      discountType: DiscountType.fromName(
        json['discountType'] as String? ?? '',
      ),
      discountValue: json['discountValue'] as int? ?? 0,
      notes: json['notes'] as String? ?? '',
      status: InvoiceStatus.fromName(json['status'] as String? ?? ''),
      payments: (json['payments'] as List<dynamic>? ?? const <dynamic>[])
          .map((e) => Payment.fromJson(e as Map<String, dynamic>))
          .toList(),
      template: InvoiceTemplateId.fromName(json['template'] as String? ?? ''),
      createdAt: DateTime.parse(json['createdAt'] as String),
      sentAt: _parseOptional(json['sentAt'] as String?),
      paidAt: _parseOptional(json['paidAt'] as String?),
      estimateId: json['estimateId'] as String?,
    );
  }

  static DateTime? _parseOptional(String? value) =>
      value == null ? null : DateTime.parse(value);

  final String id;

  /// Auto-assigned number such as `INV-2026-0001`; empty until first save.
  final String number;
  final String clientId;
  final String currency;
  final DateTime issueDate;
  final DateTime dueDate;
  final List<LineItem> items;

  /// Tax rate in basis points (750 = 7.5%).
  final int taxRateBp;
  final DiscountType discountType;

  /// Meaning depends on [discountType]: basis points for `percent`,
  /// minor units for `fixed`, ignored for `none`.
  final int discountValue;
  final String notes;
  final InvoiceStatus status;

  /// Payments recorded against this invoice, in the order they were added.
  final List<Payment> payments;

  /// PDF template this invoice renders with.
  final InvoiceTemplateId template;
  final DateTime createdAt;
  final DateTime? sentAt;
  final DateTime? paidAt;

  /// Set when this invoice was created by converting an estimate.
  final String? estimateId;

  /// Derived state: a sent invoice whose due date has passed (date-only
  /// comparison; due today is not yet overdue).
  bool isOverdue(DateTime now) {
    if (status != InvoiceStatus.sent) return false;
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final today = DateTime(now.year, now.month, now.day);
    return today.isAfter(due);
  }

  /// Transitions to [next], recording timestamps: `sentAt` is set on first
  /// entry into `sent` (or when jumping straight to `paid`), `paidAt` on
  /// entry into `paid`. Moving backwards clears the timestamps that no
  /// longer apply.
  Invoice withStatus(InvoiceStatus next, DateTime now) {
    switch (next) {
      case InvoiceStatus.draft:
        return _copyStatus(next, sentAt: null, paidAt: null);
      case InvoiceStatus.sent:
        return _copyStatus(next, sentAt: sentAt ?? now, paidAt: null);
      case InvoiceStatus.paid:
        return _copyStatus(next, sentAt: sentAt ?? now, paidAt: paidAt ?? now);
    }
  }

  Invoice _copyStatus(
    InvoiceStatus status, {
    required DateTime? sentAt,
    required DateTime? paidAt,
  }) {
    return Invoice(
      id: id,
      number: number,
      clientId: clientId,
      currency: currency,
      issueDate: issueDate,
      dueDate: dueDate,
      items: items,
      taxRateBp: taxRateBp,
      discountType: discountType,
      discountValue: discountValue,
      notes: notes,
      status: status,
      payments: payments,
      template: template,
      createdAt: createdAt,
      sentAt: sentAt,
      paidAt: paidAt,
      estimateId: estimateId,
    );
  }

  Invoice copyWith({
    String? number,
    String? clientId,
    String? currency,
    DateTime? issueDate,
    DateTime? dueDate,
    List<LineItem>? items,
    int? taxRateBp,
    DiscountType? discountType,
    int? discountValue,
    String? notes,
    List<Payment>? payments,
    InvoiceTemplateId? template,
  }) {
    return Invoice(
      id: id,
      number: number ?? this.number,
      clientId: clientId ?? this.clientId,
      currency: currency ?? this.currency,
      issueDate: issueDate ?? this.issueDate,
      dueDate: dueDate ?? this.dueDate,
      items: items ?? this.items,
      taxRateBp: taxRateBp ?? this.taxRateBp,
      discountType: discountType ?? this.discountType,
      discountValue: discountValue ?? this.discountValue,
      notes: notes ?? this.notes,
      status: status,
      payments: payments ?? this.payments,
      template: template ?? this.template,
      createdAt: createdAt,
      sentAt: sentAt,
      paidAt: paidAt,
      estimateId: estimateId,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'number': number,
    'clientId': clientId,
    'currency': currency,
    'issueDate': issueDate.toIso8601String(),
    'dueDate': dueDate.toIso8601String(),
    'items': items.map((i) => i.toJson()).toList(),
    'taxRateBp': taxRateBp,
    'discountType': discountType.name,
    'discountValue': discountValue,
    'notes': notes,
    'status': status.name,
    'payments': payments.map((p) => p.toJson()).toList(),
    'template': template.name,
    'createdAt': createdAt.toIso8601String(),
    'sentAt': sentAt?.toIso8601String(),
    'paidAt': paidAt?.toIso8601String(),
    'estimateId': estimateId,
  };
}
