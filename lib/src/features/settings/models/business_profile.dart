import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:ledgerly/src/features/invoices/models/invoice_template.dart';

/// The freelancer's own business details, used on invoices and as defaults.
@immutable
final class BusinessProfile {
  const BusinessProfile({
    this.name = '',
    this.businessName = '',
    this.address = '',
    this.email = '',
    this.taxId = '',
    this.defaultCurrency = 'USD',
    this.defaultTaxRateBp = 0,
    this.invoicePrefix = 'INV',
    this.defaultTemplate = InvoiceTemplateId.classic,
    this.showPdfFooter = true,
    this.logoBase64 = '',
  });

  factory BusinessProfile.fromJson(Map<String, dynamic> json) {
    return BusinessProfile(
      name: json['name'] as String? ?? '',
      businessName: json['businessName'] as String? ?? '',
      address: json['address'] as String? ?? '',
      email: json['email'] as String? ?? '',
      taxId: json['taxId'] as String? ?? '',
      defaultCurrency: json['defaultCurrency'] as String? ?? 'USD',
      defaultTaxRateBp: json['defaultTaxRateBp'] as int? ?? 0,
      invoicePrefix: json['invoicePrefix'] as String? ?? 'INV',
      defaultTemplate: InvoiceTemplateId.fromName(
        json['defaultTemplate'] as String? ?? '',
      ),
      showPdfFooter: json['showPdfFooter'] as bool? ?? true,
      logoBase64: json['logoBase64'] as String? ?? '',
    );
  }

  final String name;
  final String businessName;
  final String address;
  final String email;
  final String taxId;
  final String defaultCurrency;

  /// Default tax rate in basis points (750 = 7.5%).
  final int defaultTaxRateBp;
  final String invoicePrefix;

  /// PDF template new invoices start with.
  final InvoiceTemplateId defaultTemplate;

  /// Whether PDFs carry the small "Generated with Ledgerly" footer.
  final bool showPdfFooter;

  /// Optional business logo (PNG bytes, base64). Empty when unset. Stored
  /// inline so it lives inside the encrypted vault with everything else.
  final String logoBase64;

  bool get hasLogo => logoBase64.isNotEmpty;

  /// Decoded logo bytes, or null when no logo is set.
  Uint8List? get logoBytes =>
      logoBase64.isEmpty ? null : base64Decode(logoBase64);

  /// Name shown on invoices: business name, falling back to personal name.
  String get displayName => businessName.isNotEmpty ? businessName : name;

  BusinessProfile copyWith({
    String? name,
    String? businessName,
    String? address,
    String? email,
    String? taxId,
    String? defaultCurrency,
    int? defaultTaxRateBp,
    String? invoicePrefix,
    InvoiceTemplateId? defaultTemplate,
    bool? showPdfFooter,
    String? logoBase64,
  }) {
    return BusinessProfile(
      name: name ?? this.name,
      businessName: businessName ?? this.businessName,
      address: address ?? this.address,
      email: email ?? this.email,
      taxId: taxId ?? this.taxId,
      defaultCurrency: defaultCurrency ?? this.defaultCurrency,
      defaultTaxRateBp: defaultTaxRateBp ?? this.defaultTaxRateBp,
      invoicePrefix: invoicePrefix ?? this.invoicePrefix,
      defaultTemplate: defaultTemplate ?? this.defaultTemplate,
      showPdfFooter: showPdfFooter ?? this.showPdfFooter,
      logoBase64: logoBase64 ?? this.logoBase64,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'name': name,
    'businessName': businessName,
    'address': address,
    'email': email,
    'taxId': taxId,
    'defaultCurrency': defaultCurrency,
    'defaultTaxRateBp': defaultTaxRateBp,
    'invoicePrefix': invoicePrefix,
    'defaultTemplate': defaultTemplate.name,
    'showPdfFooter': showPdfFooter,
    'logoBase64': logoBase64,
  };
}
