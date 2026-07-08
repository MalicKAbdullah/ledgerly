import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute, immutable;
import 'package:ledgerly/src/features/clients/models/client.dart';
import 'package:ledgerly/src/features/invoices/models/invoice.dart';
import 'package:ledgerly/src/features/invoices/models/invoice_template.dart';
import 'package:ledgerly/src/features/invoices/services/pdf/classic_template.dart';
import 'package:ledgerly/src/features/invoices/services/pdf/minimal_template.dart';
import 'package:ledgerly/src/features/invoices/services/pdf/modern_template.dart';
import 'package:ledgerly/src/features/invoices/services/pdf/pdf_blocks.dart';
import 'package:ledgerly/src/features/invoices/services/pdf/pdf_fonts.dart';
import 'package:ledgerly/src/features/invoices/services/pdf/pdf_style.dart';
import 'package:ledgerly/src/features/settings/models/business_profile.dart';
import 'package:pdf/widgets.dart' as pw;

/// Everything needed to render one invoice PDF. Contains only plain data,
/// so it can be sent to a background isolate.
@immutable
final class InvoicePdfRequest {
  const InvoicePdfRequest({
    required this.profile,
    required this.client,
    required this.invoice,
    required this.fonts,
  });

  final BusinessProfile profile;
  final Client client;
  final Invoice invoice;
  final PdfFontBytes fonts;
}

/// Renders invoice PDFs with one of three templates (Classic / Modern /
/// Minimal), the business logo, payments, and a PAID stamp on settled
/// invoices.
///
/// Layout is pure Dart (package:pdf) and unit-tested without platform
/// dependencies. From the UI, always call [renderInBackground]: rendering a
/// multi-page document takes tens of milliseconds, so it runs in an isolate
/// to keep the frame budget intact.
abstract final class InvoicePdfService {
  /// Builds the document synchronously. Exposed so tests can inspect page
  /// counts; app code should prefer [renderInBackground].
  static pw.Document buildDocument(InvoicePdfRequest request) {
    final style = PdfStyle(request.fonts);
    final ctx = PdfInvoiceContext(
      profile: request.profile,
      client: request.client,
      invoice: request.invoice,
      style: style,
    );

    final doc = pw.Document(
      title: 'Invoice ${request.invoice.number}',
      producer: 'Ledgerly',
    );

    doc.addPage(
      pw.MultiPage(
        pageTheme: style.pageTheme(
          buildBackground: ctx.isPaid ? (_) => PdfBlocks.paidStamp() : null,
        ),
        footer: (context) => PdfBlocks.footer(
          context,
          style,
          showCredit: request.profile.showPdfFooter,
        ),
        build: (_) => switch (request.invoice.template) {
          InvoiceTemplateId.classic => ClassicTemplate.build(ctx),
          InvoiceTemplateId.modern => ModernTemplate.build(ctx),
          InvoiceTemplateId.minimal => MinimalTemplate.build(ctx),
        },
      ),
    );
    return doc;
  }

  /// Renders to bytes on the current isolate.
  static Future<Uint8List> render(InvoicePdfRequest request) =>
      buildDocument(request).save();

  /// Loads fonts (cached) and renders on a background isolate.
  static Future<Uint8List> renderInBackground({
    required BusinessProfile profile,
    required Client client,
    required Invoice invoice,
  }) async {
    final fonts = await PdfFontLoader.load();
    return compute(
      render,
      InvoicePdfRequest(
        profile: profile,
        client: client,
        invoice: invoice,
        fonts: fonts,
      ),
    );
  }
}
