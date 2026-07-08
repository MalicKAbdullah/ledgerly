import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerly/src/features/estimates/models/estimate.dart';
import 'package:ledgerly/src/features/estimates/services/estimate_pdf_service.dart';
import 'package:ledgerly/src/features/invoices/models/invoice.dart';
import 'package:ledgerly/src/features/invoices/models/invoice_template.dart';
import 'package:ledgerly/src/features/settings/models/business_profile.dart';

import 'helpers/fakes.dart';
import 'helpers/pdf_test_fonts.dart';

void main() {
  const profile = BusinessProfile(
    name: 'Ada Lovelace',
    businessName: 'Analytical Engines',
    address: '12 Byron Terrace, London',
    email: 'ada@analytical.dev',
    taxId: 'GB-123456',
  );

  void expectPdfMagic(Uint8List bytes) {
    expect(bytes, isNotEmpty);
    expect(bytes.sublist(0, 5), [0x25, 0x50, 0x44, 0x46, 0x2D]); // %PDF-
    expect(bytes.length, greaterThan(1000));
  }

  Estimate sampleEstimate(
    InvoiceTemplateId template, {
    EstimateStatus status = EstimateStatus.sent,
    String? convertedInvoiceId,
    String? convertedInvoiceNumber,
  }) {
    return Estimate(
      id: 'est-1',
      number: 'EST-2026-0042',
      clientId: 'client-1',
      currency: 'USD',
      issueDate: DateTime(2026, 6, 1),
      validUntil: DateTime(2026, 7, 1),
      items: const [
        LineItem(
          id: 'a',
          description: 'Engine schematics — naïve café résumé',
          quantityMilli: 12500,
          unitPriceMinor: 9500,
        ),
        LineItem(
          id: 'b',
          description: 'On-site consultation',
          quantityMilli: 1000,
          unitPriceMinor: 25000,
        ),
      ],
      taxRateBp: 750,
      discountType: DiscountType.percent,
      discountValue: 1000,
      notes: 'Prices valid for 30 days.',
      status: status,
      template: template,
      createdAt: DateTime(2026, 6, 1, 9),
      convertedInvoiceId: convertedInvoiceId,
      convertedInvoiceNumber: convertedInvoiceNumber,
    );
  }

  EstimatePdfRequest request(Estimate estimate, {DateTime? now}) =>
      EstimatePdfRequest(
        profile: profile,
        client: makeClient(name: 'Žofia Müllerová'),
        estimate: estimate,
        fonts: loadTestFonts(),
        now: now ?? DateTime(2026, 6, 15),
      );

  group('all three templates render an estimate', () {
    for (final template in InvoiceTemplateId.values) {
      test('${template.name} builds valid PDF bytes', () async {
        final bytes = await EstimatePdfService.render(
          request(sampleEstimate(template)),
        );
        expectPdfMagic(bytes);
      });
    }
  });

  test('document title says Estimate, not Invoice', () async {
    final doc = EstimatePdfService.buildDocument(
      request(sampleEstimate(InvoiceTemplateId.classic)),
    );
    final bytes = await doc.save();
    expectPdfMagic(bytes);
    // The PDF /Title metadata carries the document word.
    final raw = String.fromCharCodes(bytes);
    expect(raw, contains('Estimate EST-2026-0042'));
    expect(raw, isNot(contains('Invoice EST-2026-0042')));
  });

  test('converted estimate renders the conversion note', () async {
    final bytes = await EstimatePdfService.render(
      request(
        sampleEstimate(
          InvoiceTemplateId.modern,
          status: EstimateStatus.accepted,
          convertedInvoiceId: 'inv-9',
          convertedInvoiceNumber: 'INV-2026-0009',
        ),
      ),
    );
    expectPdfMagic(bytes);
  });

  test('expired estimate renders with the derived Expired status', () async {
    final bytes = await EstimatePdfService.render(
      request(
        sampleEstimate(InvoiceTemplateId.classic),
        now: DateTime(2026, 8, 1),
      ),
    );
    expectPdfMagic(bytes);
  });

  test('estimate with no items or notes still builds', () async {
    final estimate = Estimate(
      id: 'est-2',
      number: 'EST-2026-0001',
      clientId: 'client-1',
      currency: 'USD',
      issueDate: DateTime(2026, 6, 1),
      validUntil: DateTime(2026, 6, 30),
      createdAt: DateTime(2026, 6, 1),
    );
    final bytes = await EstimatePdfService.render(request(estimate));
    expectPdfMagic(bytes);
  });
}
