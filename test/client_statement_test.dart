import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerly/src/features/clients/services/client_statement_pdf_service.dart';
import 'package:ledgerly/src/features/invoices/models/invoice.dart';
import 'package:ledgerly/src/features/settings/models/business_profile.dart';

import 'helpers/fakes.dart';
import 'helpers/pdf_test_fonts.dart';

void main() {
  const profile = BusinessProfile(
    name: 'Ada Lovelace',
    businessName: 'Analytical Engines',
    email: 'ada@analytical.dev',
  );

  test(
    'statement builds valid PDF bytes for a mixed set of invoices',
    () async {
      final bytes = await ClientStatementPdfService.render(
        StatementPdfRequest(
          profile: profile,
          client: makeClient(name: 'Đorđe Šarić'),
          invoices: [
            makeInvoice(id: 'a', number: 'INV-2026-0001'),
            makeInvoice(
              id: 'b',
              number: 'INV-2026-0002',
              status: InvoiceStatus.sent,
              sentAt: DateTime(2026, 5, 1),
              dueDate: DateTime(2026, 5, 15),
            ),
            makeInvoice(
              id: 'c',
              number: 'INV-2026-0003',
              status: InvoiceStatus.sent,
              sentAt: DateTime(2026, 6, 1),
              payments: [makePayment(amountMinor: 2500)],
            ),
            makeInvoice(
              id: 'd',
              number: 'INV-2026-0004',
              status: InvoiceStatus.paid,
              paidAt: DateTime(2026, 6, 10),
            ),
            makeInvoice(id: 'e', number: 'INV-2026-0005', currency: 'EUR'),
          ],
          fonts: loadTestFonts(),
          generatedOn: DateTime(2026, 7, 5),
        ),
      );
      expect(bytes, isNotEmpty);
      expect(bytes.sublist(0, 5), [0x25, 0x50, 0x44, 0x46, 0x2D]);
      expect(bytes.length, greaterThan(1000));
    },
  );

  test('statement with many invoices spans multiple pages', () async {
    final doc = ClientStatementPdfService.buildDocument(
      StatementPdfRequest(
        profile: profile,
        client: makeClient(),
        invoices: [
          for (var i = 0; i < 80; i++)
            makeInvoice(
              id: 'inv-$i',
              number: 'INV-2026-${(i + 1).toString().padLeft(4, '0')}',
            ),
        ],
        fonts: loadTestFonts(),
        generatedOn: DateTime(2026, 7, 5),
      ),
    );
    await doc.save();
    expect(doc.document.pdfPageList.pages.length, greaterThan(1));
  });

  test('statement builds for a client with no invoices', () async {
    final bytes = await ClientStatementPdfService.render(
      StatementPdfRequest(
        profile: profile,
        client: makeClient(),
        invoices: const [],
        fonts: loadTestFonts(),
        generatedOn: DateTime(2026, 7, 5),
      ),
    );
    expect(bytes.sublist(0, 5), [0x25, 0x50, 0x44, 0x46, 0x2D]);
  });
}
