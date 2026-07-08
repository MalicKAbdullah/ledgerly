import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerly/src/core/data/app_data.dart';
import 'package:ledgerly/src/features/invoices/models/invoice.dart';

/// A verbatim snapshot of the JSON a v1.1 install stores on disk (before
/// expenses, estimates and recurring templates existed). The owner has live
/// data in this shape — it must always load with sensible defaults.
const String v11StateJson = '''
{
  "schemaVersion": 1,
  "profile": {
    "name": "Ada Lovelace",
    "businessName": "Analytical Engines",
    "address": "12 Byron Terrace, London",
    "email": "ada@analytical.dev",
    "taxId": "GB-123456",
    "defaultCurrency": "USD",
    "defaultTaxRateBp": 750,
    "invoicePrefix": "INV",
    "defaultTemplate": "modern",
    "showPdfFooter": true,
    "logoBase64": ""
  },
  "clients": [
    {
      "id": "client-1",
      "name": "Grace Hopper",
      "company": "Compilers Inc",
      "email": "grace@compilers.dev",
      "address": "1 Harbor Way",
      "notes": "Net 14",
      "createdAt": "2026-01-10T00:00:00.000"
    }
  ],
  "invoices": [
    {
      "id": "inv-1",
      "number": "INV-2026-0001",
      "clientId": "client-1",
      "currency": "USD",
      "issueDate": "2026-06-01T00:00:00.000",
      "dueDate": "2026-06-15T00:00:00.000",
      "items": [
        {
          "id": "item-1",
          "description": "Design work",
          "quantityMilli": 1500,
          "unitPriceMinor": 10000
        }
      ],
      "taxRateBp": 750,
      "discountType": "percent",
      "discountValue": 1000,
      "notes": "Thanks!",
      "status": "paid",
      "payments": [
        {
          "id": "pay-1",
          "date": "2026-06-10T00:00:00.000",
          "amountMinor": 14513,
          "method": "bankTransfer",
          "note": ""
        }
      ],
      "template": "classic",
      "createdAt": "2026-06-01T09:00:00.000",
      "sentAt": "2026-06-01T10:00:00.000",
      "paidAt": "2026-06-10T00:00:00.000"
    }
  ]
}
''';

void main() {
  group('v1.1 state compatibility', () {
    test('a v1.1 vault JSON still loads with every field intact', () {
      final data = AppData.fromJson(
        jsonDecode(v11StateJson) as Map<String, dynamic>,
      );

      expect(data.profile.businessName, 'Analytical Engines');
      expect(data.profile.defaultTaxRateBp, 750);
      expect(data.clients, hasLength(1));
      expect(data.clients.single.name, 'Grace Hopper');
      expect(data.invoices, hasLength(1));

      final invoice = data.invoices.single;
      expect(invoice.number, 'INV-2026-0001');
      expect(invoice.status, InvoiceStatus.paid);
      expect(invoice.payments.single.amountMinor, 14513);
      expect(invoice.items.single.quantityMilli, 1500);
    });

    test('fields added after v1.1 default to empty/sensible values', () {
      final data = AppData.fromJson(
        jsonDecode(v11StateJson) as Map<String, dynamic>,
      );

      expect(data.expenses, isEmpty);
      expect(data.estimates, isEmpty);
      expect(data.recurringTemplates, isEmpty);
      expect(data.invoices.single.estimateId, isNull);
    });

    test('a v1.1 snapshot survives a load → save → load cycle', () {
      final loaded = AppData.fromJson(
        jsonDecode(v11StateJson) as Map<String, dynamic>,
      );
      final cycled = AppData.fromJson(
        jsonDecode(jsonEncode(loaded.toJson())) as Map<String, dynamic>,
      );
      expect(jsonEncode(cycled.toJson()), jsonEncode(loaded.toJson()));
    });

    test('completely empty maps still produce defaults', () {
      final data = AppData.fromJson(const <String, dynamic>{});
      expect(data.clients, isEmpty);
      expect(data.invoices, isEmpty);
      expect(data.expenses, isEmpty);
      expect(data.estimates, isEmpty);
      expect(data.recurringTemplates, isEmpty);
      expect(data.profile.defaultCurrency, 'USD');
    });
  });
}
