import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerly/src/features/invoices/models/invoice.dart';
import 'package:ledgerly/src/features/invoices/models/invoice_template.dart';
import 'package:ledgerly/src/features/invoices/services/invoice_pdf_service.dart';
import 'package:ledgerly/src/features/settings/models/business_profile.dart';
import 'package:ledgerly/src/features/invoices/models/payment.dart';
import 'package:ledgerly/src/features/settings/services/logo_service.dart';
import 'package:image/image.dart' as img;

import 'helpers/fakes.dart';
import 'helpers/pdf_test_fonts.dart';

void main() {
  const profile = BusinessProfile(
    name: 'Ada Lovelace',
    businessName: 'Analytical Engines',
    address: '12 Byron Terrace, London',
    email: 'ada@analytical.dev',
    taxId: 'GB-123456',
    defaultCurrency: 'USD',
    invoicePrefix: 'AE',
  );

  void expectPdfMagic(Uint8List bytes) {
    expect(bytes, isNotEmpty);
    expect(bytes.sublist(0, 5), [0x25, 0x50, 0x44, 0x46, 0x2D]); // %PDF-
    expect(bytes.length, greaterThan(1000));
  }

  Invoice sampleInvoice(InvoiceTemplateId template) => makeInvoice(
    number: 'AE-2026-0042',
    template: template,
    items: const [
      LineItem(
        id: 'a',
        description: 'Engine schematics — phase 1 (naïve café résumé)',
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
    notes: 'Payment due within 14 days via bank transfer.',
  );

  group('all three templates render a fully-featured invoice', () {
    for (final template in InvoiceTemplateId.values) {
      test('${template.name} builds valid PDF bytes', () async {
        // Unicode client name — exercises the embedded Inter font.
        final client = makeClient(name: 'Žofia Müllerová');
        final bytes = await InvoicePdfService.render(
          InvoicePdfRequest(
            profile: profile,
            client: client,
            invoice: sampleInvoice(template),
            fonts: loadTestFonts(),
          ),
        );
        expectPdfMagic(bytes);
      });

      test(
        '${template.name} spills many line items onto multiple pages',
        () async {
          final invoice = makeInvoice(
            template: template,
            items: [
              for (var i = 0; i < 60; i++)
                LineItem(
                  id: 'item-$i',
                  description:
                      'Consulting block ${i + 1} — design, build, '
                      'review, and documentation',
                  quantityMilli: 1500,
                  unitPriceMinor: 12345,
                ),
            ],
            taxRateBp: 2000,
          );
          final doc = InvoicePdfService.buildDocument(
            InvoicePdfRequest(
              profile: profile,
              client: makeClient(),
              invoice: invoice,
              fonts: loadTestFonts(),
            ),
          );
          final bytes = await doc.save();
          expectPdfMagic(bytes);
          expect(
            doc.document.pdfPageList.pages.length,
            greaterThan(1),
            reason: '60 line items must not be squashed onto one page',
          );
        },
      );
    }
  });

  test('paid invoice renders (PAID stamp path) with payment history', () async {
    final invoice = makeInvoice(
      status: InvoiceStatus.paid,
      sentAt: DateTime(2026, 6, 2),
      paidAt: DateTime(2026, 6, 20),
      payments: [
        makePayment(id: 'p1', amountMinor: 4000),
        makePayment(
          id: 'p2',
          amountMinor: 6000,
          method: PaymentMethod.paypal,
          note: 'final instalment',
        ),
      ],
    );
    for (final template in InvoiceTemplateId.values) {
      final bytes = await InvoicePdfService.render(
        InvoicePdfRequest(
          profile: profile,
          client: makeClient(),
          invoice: invoice.copyWith(template: template),
          fonts: loadTestFonts(),
        ),
      );
      expectPdfMagic(bytes);
    }
  });

  test('partially paid invoice shows balance rows without error', () async {
    final invoice = makeInvoice(
      status: InvoiceStatus.sent,
      sentAt: DateTime(2026, 6, 2),
      payments: [makePayment(amountMinor: 2500)],
    );
    final bytes = await InvoicePdfService.render(
      InvoicePdfRequest(
        profile: profile,
        client: makeClient(),
        invoice: invoice,
        fonts: loadTestFonts(),
      ),
    );
    expectPdfMagic(bytes);
  });

  test('logo renders in all templates', () async {
    // Generate a tiny in-memory PNG via the same pipeline Settings uses.
    final png = img.encodePng(img.Image(width: 64, height: 48));
    final logoBase64 = LogoService.prepareSync(Uint8List.fromList(png))!;
    final withLogo = profile.copyWith(logoBase64: logoBase64);
    expect(base64Decode(logoBase64), isNotEmpty);

    for (final template in InvoiceTemplateId.values) {
      final bytes = await InvoicePdfService.render(
        InvoicePdfRequest(
          profile: withLogo,
          client: makeClient(),
          invoice: sampleInvoice(template),
          fonts: loadTestFonts(),
        ),
      );
      expectPdfMagic(bytes);
    }
  });

  test('footer can be disabled', () async {
    final noFooter = profile.copyWith(showPdfFooter: false);
    final bytes = await InvoicePdfService.render(
      InvoicePdfRequest(
        profile: noFooter,
        client: makeClient(),
        invoice: sampleInvoice(InvoiceTemplateId.minimal),
        fonts: loadTestFonts(),
      ),
    );
    expectPdfMagic(bytes);
  });

  test('minimal invoice with no items or notes still builds', () async {
    final bytes = await InvoicePdfService.render(
      InvoicePdfRequest(
        profile: const BusinessProfile(),
        client: makeClient(company: ''),
        invoice: makeInvoice(items: const []),
        fonts: loadTestFonts(),
      ),
    );
    expectPdfMagic(bytes);
  });
}
