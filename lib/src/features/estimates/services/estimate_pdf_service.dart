import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute, immutable;
import 'package:ledgerly/src/features/clients/models/client.dart';
import 'package:ledgerly/src/features/estimates/models/estimate.dart';
import 'package:ledgerly/src/features/estimates/services/estimate_math.dart';
import 'package:ledgerly/src/features/invoices/models/invoice_template.dart';
import 'package:ledgerly/src/features/invoices/services/pdf/classic_template.dart';
import 'package:ledgerly/src/features/invoices/services/pdf/minimal_template.dart';
import 'package:ledgerly/src/features/invoices/services/pdf/modern_template.dart';
import 'package:ledgerly/src/features/invoices/services/pdf/pdf_blocks.dart';
import 'package:ledgerly/src/features/invoices/services/pdf/pdf_fonts.dart';
import 'package:ledgerly/src/features/invoices/services/pdf/pdf_style.dart';
import 'package:ledgerly/src/features/settings/models/business_profile.dart';
import 'package:pdf/widgets.dart' as pw;

/// Everything needed to render one estimate PDF. Contains only plain data,
/// so it can be sent to a background isolate.
@immutable
final class EstimatePdfRequest {
  const EstimatePdfRequest({
    required this.profile,
    required this.client,
    required this.estimate,
    required this.fonts,
    required this.now,
  });

  final BusinessProfile profile;
  final Client client;
  final Estimate estimate;
  final PdfFontBytes fonts;

  /// Wall clock used only to derive the "Expired" status label.
  final DateTime now;
}

/// Renders estimate PDFs by reusing the three invoice templates with an
/// "ESTIMATE" title, a "VALID UNTIL" date, no payments section (estimates
/// have none), and — after conversion — an "Estimate → Invoice" note.
abstract final class EstimatePdfService {
  /// Builds the document synchronously. Exposed so tests can inspect it;
  /// app code should prefer [renderInBackground].
  static pw.Document buildDocument(EstimatePdfRequest request) {
    final estimate = request.estimate;
    final style = PdfStyle(request.fonts);
    final ctx = PdfInvoiceContext(
      profile: request.profile,
      client: request.client,
      invoice: EstimateMath.shadowInvoice(estimate),
      style: style,
      title: 'ESTIMATE',
      dueLabel: 'VALID UNTIL',
      totalLabel: 'Estimated Total',
      statusOverride: estimate.isExpired(request.now)
          ? 'Expired'
          : estimate.status.label,
      conversionNote: estimate.isConverted
          ? 'Estimate ${estimate.number} → '
                'Invoice ${estimate.convertedInvoiceNumber ?? ''}'
          : null,
    );

    final doc = pw.Document(
      title: 'Estimate ${estimate.number}',
      producer: 'Ledgerly',
    );

    doc.addPage(
      pw.MultiPage(
        pageTheme: style.pageTheme(),
        footer: (context) => PdfBlocks.footer(
          context,
          style,
          showCredit: request.profile.showPdfFooter,
        ),
        build: (_) => switch (estimate.template) {
          InvoiceTemplateId.classic => ClassicTemplate.build(ctx),
          InvoiceTemplateId.modern => ModernTemplate.build(ctx),
          InvoiceTemplateId.minimal => MinimalTemplate.build(ctx),
        },
      ),
    );
    return doc;
  }

  /// Renders to bytes on the current isolate.
  static Future<Uint8List> render(EstimatePdfRequest request) =>
      buildDocument(request).save();

  /// Loads fonts (cached) and renders on a background isolate.
  static Future<Uint8List> renderInBackground({
    required BusinessProfile profile,
    required Client client,
    required Estimate estimate,
    required DateTime now,
  }) async {
    final fonts = await PdfFontLoader.load();
    return compute(
      render,
      EstimatePdfRequest(
        profile: profile,
        client: client,
        estimate: estimate,
        fonts: fonts,
        now: now,
      ),
    );
  }
}
