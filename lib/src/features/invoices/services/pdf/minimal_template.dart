import 'package:ledgerly/src/core/formats.dart';
import 'package:ledgerly/src/core/money/money.dart';
import 'package:ledgerly/src/features/invoices/services/pdf/pdf_blocks.dart';
import 'package:ledgerly/src/features/invoices/services/pdf/pdf_style.dart';
import 'package:pdf/widgets.dart' as pw;

/// Minimal — purely typographic and monochrome: an oversized invoice
/// number, hairline rules, generous whitespace, no fills or color.
abstract final class MinimalTemplate {
  static List<pw.Widget> build(PdfInvoiceContext ctx) {
    return [
      _masthead(ctx),
      pw.SizedBox(height: 34),
      _parties(ctx),
      pw.SizedBox(height: 34),
      _items(ctx),
      pw.SizedBox(height: 16),
      _totals(ctx),
      if (ctx.invoice.payments.isNotEmpty) ...[
        pw.SizedBox(height: 26),
        PdfBlocks.paymentsBlock(ctx),
      ],
      if (ctx.invoice.notes.trim().isNotEmpty) ...[
        pw.SizedBox(height: 26),
        PdfBlocks.notes(ctx, title: 'NOTES'),
      ],
      if (ctx.conversionNote != null) ...[
        pw.SizedBox(height: 26),
        PdfBlocks.conversionNote(ctx),
      ],
    ];
  }

  static pw.Widget _masthead(PdfInvoiceContext ctx) {
    final style = ctx.style;
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
                pw.Text(
                  ctx.titleWord,
                  style: style.body(size: 11, color: PdfStyle.muted),
                ),
                pw.SizedBox(height: 2),
                pw.Text(ctx.invoice.number, style: style.heavy(size: 26)),
              ],
            ),
            if (ctx.logo != null)
              pw.Container(
                width: 40,
                height: 40,
                child: pw.Image(ctx.logo!, fit: pw.BoxFit.contain),
              )
            else
              pw.Text(ctx.profile.displayName, style: style.strong(size: 12)),
          ],
        ),
        pw.SizedBox(height: 18),
        pw.Container(height: 0.7, color: PdfStyle.ink),
      ],
    );
  }

  static pw.Widget _parties(PdfInvoiceContext ctx) {
    final style = ctx.style;
    pw.Widget column(String label, List<pw.Widget> children) => pw.Expanded(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: style.overline(size: 7.5, color: PdfStyle.faintText),
          ),
          pw.SizedBox(height: 8),
          ...children,
        ],
      ),
    );

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        column('BILLED TO', PdfBlocks.clientLines(ctx)),
        column('FROM', [
          pw.Text(ctx.profile.displayName, style: style.strong(size: 11)),
          ...PdfBlocks.businessLines(ctx, align: pw.TextAlign.left),
        ]),
        column('DATES', [
          pw.Text(
            'Issued ${Formats.date(ctx.invoice.issueDate)}',
            style: style.body(size: 9.5),
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            '${ctx.dueWord} ${Formats.date(ctx.invoice.dueDate)}',
            style: style.strong(size: 9.5),
          ),
        ]),
      ],
    );
  }

  static pw.Widget _items(PdfInvoiceContext ctx) {
    final style = ctx.style;
    final currency = ctx.invoice.currency;

    pw.Widget cell(
      String text, {
      pw.TextStyle? textStyle,
      pw.TextAlign align = pw.TextAlign.left,
    }) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 9, horizontal: 2),
        child: pw.Text(
          text,
          style: textStyle ?? style.body(size: 9.5),
          textAlign: align,
        ),
      );
    }

    return pw.Table(
      border: const pw.TableBorder(
        horizontalInside: pw.BorderSide(color: PdfStyle.line, width: 0.4),
        bottom: pw.BorderSide(color: PdfStyle.ink, width: 0.7),
      ),
      columnWidths: const {
        0: pw.FlexColumnWidth(5),
        1: pw.FlexColumnWidth(1.3),
        2: pw.FlexColumnWidth(2),
        3: pw.FlexColumnWidth(2),
      },
      children: [
        pw.TableRow(
          repeat: true,
          children: [
            cell(
              'Description',
              textStyle: style.body(size: 8.5, color: PdfStyle.faintText),
            ),
            cell(
              'Qty',
              textStyle: style.body(size: 8.5, color: PdfStyle.faintText),
              align: pw.TextAlign.right,
            ),
            cell(
              'Unit price',
              textStyle: style.body(size: 8.5, color: PdfStyle.faintText),
              align: pw.TextAlign.right,
            ),
            cell(
              'Amount',
              textStyle: style.body(size: 8.5, color: PdfStyle.faintText),
              align: pw.TextAlign.right,
            ),
          ],
        ),
        for (final item in ctx.invoice.items)
          pw.TableRow(
            children: [
              cell(item.description),
              cell(
                formatQuantityMilli(item.quantityMilli),
                align: pw.TextAlign.right,
              ),
              cell(
                item.unitPrice(currency).format(),
                align: pw.TextAlign.right,
              ),
              cell(
                item.total(currency).format(),
                textStyle: style.strong(size: 9.5),
                align: pw.TextAlign.right,
              ),
            ],
          ),
      ],
    );
  }

  static pw.Widget _totals(PdfInvoiceContext ctx) {
    final style = ctx.style;
    final rows = ctx.totalsRows();
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: [
        pw.SizedBox(
          width: 220,
          child: pw.Column(
            children: [
              for (var i = 0; i < rows.length; i++)
                pw.Padding(
                  padding: pw.EdgeInsets.only(
                    top: i == rows.length - 1 ? 8 : 3,
                    bottom: 3,
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        rows[i].$1,
                        style: i == rows.length - 1
                            ? style.strong(size: 11)
                            : style.body(size: 9.5, color: PdfStyle.muted),
                      ),
                      pw.Text(
                        rows[i].$2,
                        style: i == rows.length - 1
                            ? style.heavy(size: 15)
                            : style.body(size: 9.5, color: PdfStyle.muted),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
