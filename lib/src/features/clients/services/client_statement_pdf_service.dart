import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute, immutable;
import 'package:ledgerly/src/core/formats.dart';
import 'package:ledgerly/src/core/money/money.dart';
import 'package:ledgerly/src/features/clients/models/client.dart';
import 'package:ledgerly/src/features/invoices/models/invoice.dart';
import 'package:ledgerly/src/features/invoices/services/invoice_calculator.dart';
import 'package:ledgerly/src/features/invoices/services/payment_math.dart';
import 'package:ledgerly/src/features/invoices/services/pdf/pdf_fonts.dart';
import 'package:ledgerly/src/features/invoices/services/pdf/pdf_style.dart';
import 'package:ledgerly/src/features/settings/models/business_profile.dart';
import 'package:pdf/widgets.dart' as pw;

@immutable
final class StatementPdfRequest {
  const StatementPdfRequest({
    required this.profile,
    required this.client,
    required this.invoices,
    required this.fonts,
    required this.generatedOn,
  });

  final BusinessProfile profile;
  final Client client;
  final List<Invoice> invoices;
  final PdfFontBytes fonts;
  final DateTime generatedOn;
}

/// A client statement: every invoice for one client with status, totals,
/// and the open balance, grouped per currency so no fake FX ever happens.
abstract final class ClientStatementPdfService {
  static pw.Document buildDocument(StatementPdfRequest request) {
    final style = PdfStyle(request.fonts);
    final invoices = [...request.invoices]
      ..sort((a, b) => a.issueDate.compareTo(b.issueDate));

    final billed = <String, Money>{};
    final open = <String, Money>{};
    for (final invoice in invoices) {
      final totals = InvoiceCalculator.calculate(invoice);
      final balance = PaymentMath.balanceDue(invoice, totals: totals);
      billed[invoice.currency] =
          (billed[invoice.currency] ?? Money.zero(invoice.currency)) +
          totals.total;
      open[invoice.currency] =
          (open[invoice.currency] ?? Money.zero(invoice.currency)) + balance;
    }

    final doc = pw.Document(
      title: 'Statement — ${request.client.name}',
      producer: 'Ledgerly',
    );
    doc.addPage(
      pw.MultiPage(
        pageTheme: style.pageTheme(),
        footer: (context) => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 8),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                request.profile.showPdfFooter ? 'Generated with Ledgerly' : '',
                style: style.body(size: 8, color: PdfStyle.faintText),
              ),
              pw.Text(
                'Page ${context.pageNumber} of ${context.pagesCount}',
                style: style.body(size: 8, color: PdfStyle.faintText),
              ),
            ],
          ),
        ),
        build: (_) => [
          _header(request, style),
          pw.SizedBox(height: 24),
          _table(request, invoices, style),
          pw.SizedBox(height: 18),
          _summary(billed, open, style),
        ],
      ),
    );
    return doc;
  }

  static Future<Uint8List> render(StatementPdfRequest request) =>
      buildDocument(request).save();

  static Future<Uint8List> renderInBackground({
    required BusinessProfile profile,
    required Client client,
    required List<Invoice> invoices,
  }) async {
    final fonts = await PdfFontLoader.load();
    return compute(
      render,
      StatementPdfRequest(
        profile: profile,
        client: client,
        invoices: invoices,
        fonts: fonts,
        generatedOn: DateTime.now(),
      ),
    );
  }

  static pw.Widget _header(StatementPdfRequest request, PdfStyle style) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('STATEMENT', style: style.overline(size: 9)),
                pw.SizedBox(height: 4),
                pw.Text(request.client.name, style: style.heavy(size: 20)),
                if (request.client.company.isNotEmpty)
                  pw.Text(
                    request.client.company,
                    style: style.body(size: 10, color: PdfStyle.muted),
                  ),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  request.profile.displayName,
                  style: style.strong(size: 11),
                ),
                pw.Text(
                  'As of ${Formats.date(request.generatedOn)}',
                  style: style.body(size: 9, color: PdfStyle.muted),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 14),
        pw.Container(height: 1, color: PdfStyle.ink),
      ],
    );
  }

  static pw.Widget _table(
    StatementPdfRequest request,
    List<Invoice> invoices,
    PdfStyle style,
  ) {
    final now = request.generatedOn;

    pw.Widget cell(
      String text, {
      pw.TextStyle? textStyle,
      pw.TextAlign align = pw.TextAlign.left,
    }) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 7, horizontal: 6),
        child: pw.Text(
          text,
          style: textStyle ?? style.body(size: 9),
          textAlign: align,
        ),
      );
    }

    String statusLabel(Invoice invoice) {
      if (invoice.isOverdue(now)) return 'Overdue';
      if (PaymentMath.isPartiallyPaid(invoice)) return 'Partial';
      return invoice.status.name[0].toUpperCase() +
          invoice.status.name.substring(1);
    }

    return pw.Table(
      border: const pw.TableBorder(
        horizontalInside: pw.BorderSide(color: PdfStyle.line, width: 0.4),
        bottom: pw.BorderSide(color: PdfStyle.line, width: 0.4),
      ),
      columnWidths: const {
        0: pw.FlexColumnWidth(2.4),
        1: pw.FlexColumnWidth(1.8),
        2: pw.FlexColumnWidth(1.8),
        3: pw.FlexColumnWidth(1.4),
        4: pw.FlexColumnWidth(1.8),
        5: pw.FlexColumnWidth(1.8),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfStyle.faint),
          repeat: true,
          children: [
            cell('INVOICE', textStyle: style.overline(size: 7.5)),
            cell('ISSUED', textStyle: style.overline(size: 7.5)),
            cell('DUE', textStyle: style.overline(size: 7.5)),
            cell('STATUS', textStyle: style.overline(size: 7.5)),
            cell(
              'TOTAL',
              textStyle: style.overline(size: 7.5),
              align: pw.TextAlign.right,
            ),
            cell(
              'BALANCE',
              textStyle: style.overline(size: 7.5),
              align: pw.TextAlign.right,
            ),
          ],
        ),
        for (final invoice in invoices)
          pw.TableRow(
            children: [
              cell(invoice.number, textStyle: style.strong(size: 9)),
              cell(Formats.date(invoice.issueDate)),
              cell(Formats.date(invoice.dueDate)),
              cell(statusLabel(invoice)),
              cell(
                InvoiceCalculator.calculate(invoice).total.format(),
                align: pw.TextAlign.right,
              ),
              cell(
                PaymentMath.balanceDue(invoice).format(),
                textStyle: style.strong(size: 9),
                align: pw.TextAlign.right,
              ),
            ],
          ),
      ],
    );
  }

  static pw.Widget _summary(
    Map<String, Money> billed,
    Map<String, Money> open,
    PdfStyle style,
  ) {
    pw.Widget row(String label, String value, {bool strong = false}) =>
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 3),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                label,
                style: strong
                    ? style.heavy(size: 11)
                    : style.body(size: 9.5, color: PdfStyle.muted),
              ),
              pw.Text(
                value,
                style: strong
                    ? style.heavy(size: 11)
                    : style.body(size: 9.5, color: PdfStyle.muted),
              ),
            ],
          ),
        );

    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: [
        pw.SizedBox(
          width: 250,
          child: pw.Column(
            children: [
              for (final entry in billed.entries)
                row('Total billed (${entry.key})', entry.value.format()),
              pw.Divider(color: PdfStyle.line, height: 10, thickness: 0.5),
              for (final entry in open.entries)
                row(
                  'Balance due (${entry.key})',
                  entry.value.format(),
                  strong: true,
                ),
            ],
          ),
        ),
      ],
    );
  }
}
