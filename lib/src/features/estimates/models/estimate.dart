import 'package:flutter/foundation.dart';
import 'package:ledgerly/src/features/invoices/models/invoice.dart';
import 'package:ledgerly/src/features/invoices/models/invoice_template.dart';

/// Persisted estimate lifecycle states. `expired` is derived, never stored —
/// see [Estimate.isExpired].
enum EstimateStatus {
  draft,
  sent,
  accepted,
  declined;

  static EstimateStatus fromName(String name) => EstimateStatus.values
      .firstWhere((s) => s.name == name, orElse: () => EstimateStatus.draft);

  String get label => switch (this) {
    EstimateStatus.draft => 'Draft',
    EstimateStatus.sent => 'Sent',
    EstimateStatus.accepted => 'Accepted',
    EstimateStatus.declined => 'Declined',
  };
}

/// A quote sent before work starts. Reuses [LineItem] and the exact
/// subtotal → discount → tax math of invoices via `InvoiceCalculator`.
@immutable
final class Estimate {
  const Estimate({
    required this.id,
    required this.number,
    required this.clientId,
    required this.currency,
    required this.issueDate,
    required this.validUntil,
    this.items = const <LineItem>[],
    this.taxRateBp = 0,
    this.discountType = DiscountType.none,
    this.discountValue = 0,
    this.notes = '',
    this.status = EstimateStatus.draft,
    this.template = InvoiceTemplateId.classic,
    required this.createdAt,
    this.sentAt,
    this.acceptedAt,
    this.declinedAt,
    this.convertedInvoiceId,
    this.convertedInvoiceNumber,
  });

  factory Estimate.fromJson(Map<String, dynamic> json) {
    return Estimate(
      id: json['id'] as String,
      number: json['number'] as String,
      clientId: json['clientId'] as String,
      currency: json['currency'] as String,
      issueDate: DateTime.parse(json['issueDate'] as String),
      validUntil: DateTime.parse(json['validUntil'] as String),
      items: (json['items'] as List<dynamic>? ?? const <dynamic>[])
          .map((e) => LineItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      taxRateBp: json['taxRateBp'] as int? ?? 0,
      discountType: DiscountType.fromName(
        json['discountType'] as String? ?? '',
      ),
      discountValue: json['discountValue'] as int? ?? 0,
      notes: json['notes'] as String? ?? '',
      status: EstimateStatus.fromName(json['status'] as String? ?? ''),
      template: InvoiceTemplateId.fromName(json['template'] as String? ?? ''),
      createdAt: DateTime.parse(json['createdAt'] as String),
      sentAt: _parseOptional(json['sentAt'] as String?),
      acceptedAt: _parseOptional(json['acceptedAt'] as String?),
      declinedAt: _parseOptional(json['declinedAt'] as String?),
      convertedInvoiceId: json['convertedInvoiceId'] as String?,
      convertedInvoiceNumber: json['convertedInvoiceNumber'] as String?,
    );
  }

  static DateTime? _parseOptional(String? value) =>
      value == null ? null : DateTime.parse(value);

  final String id;

  /// Auto-assigned number such as `EST-2026-0001`; empty until first save.
  final String number;
  final String clientId;
  final String currency;
  final DateTime issueDate;

  /// The offer stands until this date (inclusive).
  final DateTime validUntil;
  final List<LineItem> items;
  final int taxRateBp;
  final DiscountType discountType;
  final int discountValue;
  final String notes;
  final EstimateStatus status;
  final InvoiceTemplateId template;
  final DateTime createdAt;
  final DateTime? sentAt;
  final DateTime? acceptedAt;
  final DateTime? declinedAt;

  /// Set when the estimate was converted; the created invoice's id/number.
  final String? convertedInvoiceId;
  final String? convertedInvoiceNumber;

  bool get isConverted => convertedInvoiceId != null;

  /// Derived state: an open (draft/sent) estimate whose validity date has
  /// passed. Date-only comparison — valid until end of that day.
  bool isExpired(DateTime now) {
    if (status == EstimateStatus.accepted ||
        status == EstimateStatus.declined) {
      return false;
    }
    final valid = DateTime(validUntil.year, validUntil.month, validUntil.day);
    final today = DateTime(now.year, now.month, now.day);
    return today.isAfter(valid);
  }

  /// Transitions to [next], recording timestamps. `sentAt` is set on first
  /// entry into `sent` (or when jumping straight to a terminal state);
  /// accepting/declining stamps its own timestamp and clears the other.
  Estimate withStatus(EstimateStatus next, DateTime now) {
    switch (next) {
      case EstimateStatus.draft:
        return _copyStatus(
          next,
          sentAt: null,
          acceptedAt: null,
          declinedAt: null,
        );
      case EstimateStatus.sent:
        return _copyStatus(
          next,
          sentAt: sentAt ?? now,
          acceptedAt: null,
          declinedAt: null,
        );
      case EstimateStatus.accepted:
        return _copyStatus(
          next,
          sentAt: sentAt ?? now,
          acceptedAt: acceptedAt ?? now,
          declinedAt: null,
        );
      case EstimateStatus.declined:
        return _copyStatus(
          next,
          sentAt: sentAt ?? now,
          acceptedAt: null,
          declinedAt: declinedAt ?? now,
        );
    }
  }

  Estimate _copyStatus(
    EstimateStatus status, {
    required DateTime? sentAt,
    required DateTime? acceptedAt,
    required DateTime? declinedAt,
  }) {
    return Estimate(
      id: id,
      number: number,
      clientId: clientId,
      currency: currency,
      issueDate: issueDate,
      validUntil: validUntil,
      items: items,
      taxRateBp: taxRateBp,
      discountType: discountType,
      discountValue: discountValue,
      notes: notes,
      status: status,
      template: template,
      createdAt: createdAt,
      sentAt: sentAt,
      acceptedAt: acceptedAt,
      declinedAt: declinedAt,
      convertedInvoiceId: convertedInvoiceId,
      convertedInvoiceNumber: convertedInvoiceNumber,
    );
  }

  Estimate copyWith({
    String? number,
    String? clientId,
    String? currency,
    DateTime? issueDate,
    DateTime? validUntil,
    List<LineItem>? items,
    int? taxRateBp,
    DiscountType? discountType,
    int? discountValue,
    String? notes,
    InvoiceTemplateId? template,
    String? convertedInvoiceId,
    String? convertedInvoiceNumber,
  }) {
    return Estimate(
      id: id,
      number: number ?? this.number,
      clientId: clientId ?? this.clientId,
      currency: currency ?? this.currency,
      issueDate: issueDate ?? this.issueDate,
      validUntil: validUntil ?? this.validUntil,
      items: items ?? this.items,
      taxRateBp: taxRateBp ?? this.taxRateBp,
      discountType: discountType ?? this.discountType,
      discountValue: discountValue ?? this.discountValue,
      notes: notes ?? this.notes,
      status: status,
      template: template ?? this.template,
      createdAt: createdAt,
      sentAt: sentAt,
      acceptedAt: acceptedAt,
      declinedAt: declinedAt,
      convertedInvoiceId: convertedInvoiceId ?? this.convertedInvoiceId,
      convertedInvoiceNumber:
          convertedInvoiceNumber ?? this.convertedInvoiceNumber,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'number': number,
    'clientId': clientId,
    'currency': currency,
    'issueDate': issueDate.toIso8601String(),
    'validUntil': validUntil.toIso8601String(),
    'items': items.map((i) => i.toJson()).toList(),
    'taxRateBp': taxRateBp,
    'discountType': discountType.name,
    'discountValue': discountValue,
    'notes': notes,
    'status': status.name,
    'template': template.name,
    'createdAt': createdAt.toIso8601String(),
    'sentAt': sentAt?.toIso8601String(),
    'acceptedAt': acceptedAt?.toIso8601String(),
    'declinedAt': declinedAt?.toIso8601String(),
    'convertedInvoiceId': convertedInvoiceId,
    'convertedInvoiceNumber': convertedInvoiceNumber,
  };
}
