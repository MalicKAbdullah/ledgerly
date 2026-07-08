import 'package:ledgerly/src/core/formats.dart';
import 'package:ledgerly/src/core/money/money.dart';
import 'package:ledgerly/src/features/invoices/services/pdf/pdf_blocks.dart';
import 'package:ledgerly/src/features/invoices/services/pdf/pdf_style.dart';
import 'package:pdf/widgets.dart' as pw;

/// Classic — traditional letterhead feel: centered masthead, double rule,
/// fully ruled line-item table, formal meta grid.
abstract final class ClassicTemplate {
  static List<pw.Widget> build(PdfInvoiceContext ctx) {
    return [
      _masthead(ctx),
      pw.SizedBox(height: 22),
      _metaAndParties(ctx),
      pw.SizedBox(height: 24),
      _itemsTable(ctx),
      pw.SizedBox(height: 14),
      _totals(ctx),
      if (ctx.invoice.payments.isNotEmpty) ...[
        pw.SizedBox(height: 20),
        PdfBlocks.paymentsBlock(ctx),
      ],
      if (ctx.invoice.notes.trim().isNotEmpty) ...[
        pw.SizedBox(height: 20),
        PdfBlocks.notes(ctx),
      ],
      if (ctx.conversionNote != null) ...[
        pw.SizedBox(height: 20),
        PdfBlocks.conversionNote(ctx),
      ],
    ];
  }

  static pw.Widget _masthead(PdfInvoiceContext ctx) {
    final style = ctx.style;
    return pw.Column(
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (ctx.logo != null) ...[
                  pw.Container(
                    width: 42,
                    height: 42,
                    margin: const pw.EdgeInsets.only(right: 12),
                    child: pw.Image(ctx.logo!, fit: pw.BoxFit.contain),
                  ),
                ],
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      ctx.profile.displayName.isEmpty
                          ? 'Invoice'
                          : ctx.profile.displayName,
                      style: style.heavy(size: 16),
                    ),
                    pw.SizedBox(height: 3),
                    ...PdfBlocks.businessLines(ctx, align: pw.TextAlign.left),
                  ],
                ),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  ctx.title,
                  style: style.heavy(size: 24).copyWith(letterSpacing: 3),
                ),
                pw.SizedBox(height: 3),
                pw.Text(
                  ctx.invoice.number,
                  style: style.body(size: 11, color: PdfStyle.muted),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 14),
        // Classic double rule.
        pw.Container(height: 1.6, color: PdfStyle.ink),
        pw.SizedBox(height: 2),
        pw.Container(height: 0.6, color: PdfStyle.ink),
      ],
    );
  }

  static pw.Widget _metaAndParties(PdfInvoiceContext ctx) {
    final style = ctx.style;
    pw.Widget meta(String label, String value, {bool strong = false}) =>
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 6),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(label, style: style.overline(size: 7.5)),
              pw.Text(
                value,
                style: strong ? style.strong(size: 10) : style.body(size: 10),
              ),
            ],
          ),
        );

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('BILLED TO', style: style.overline()),
              pw.SizedBox(height: 6),
              ...PdfBlocks.clientLines(ctx),
            ],
          ),
        ),
        pw.SizedBox(width: 48),
        pw.SizedBox(
          width: 190,
          child: pw.Column(
            children: [
              meta('${ctx.title} NO.', ctx.invoice.number),
              meta('ISSUED', Formats.date(ctx.invoice.issueDate)),
              meta(
                ctx.dueLabel,
                Formats.date(ctx.invoice.dueDate),
                strong: true,
              ),
              meta('STATUS', ctx.statusLabel, strong: true),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _itemsTable(PdfInvoiceContext ctx) {
    final style = ctx.style;
    final currency = ctx.invoice.currency;

    pw.Widget cell(
      String text, {
      pw.TextStyle? textStyle,
      pw.TextAlign align = pw.TextAlign.left,
    }) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 7, horizontal: 8),
        child: pw.Text(
          text,
          style: textStyle ?? style.body(size: 9.5),
          textAlign: align,
        ),
      );
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfStyle.line, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(5),
        1: pw.FlexColumnWidth(1.3),
        2: pw.FlexColumnWidth(2),
        3: pw.FlexColumnWidth(2),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfStyle.faint),
          repeat: true,
          children: [
            cell('DESCRIPTION', textStyle: style.overline(size: 7.5)),
            cell(
              'QTY',
              textStyle: style.overline(size: 7.5),
              align: pw.TextAlign.right,
            ),
            cell(
              'UNIT PRICE',
              textStyle: style.overline(size: 7.5),
              align: pw.TextAlign.right,
            ),
            cell(
              'AMOUNT',
              textStyle: style.overline(size: 7.5),
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
          width: 230,
          child: pw.Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i == rows.length - 1)
                  pw.Container(
                    height: 1,
                    color: PdfStyle.ink,
                    margin: const pw.EdgeInsets.symmetric(vertical: 4),
                  ),
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 3),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        rows[i].$1,
                        style: i == rows.length - 1
                            ? style.heavy(size: 12)
                            : style.body(size: 9.5, color: PdfStyle.muted),
                      ),
                      pw.Text(
                        rows[i].$2,
                        style: i == rows.length - 1
                            ? style.heavy(size: 12)
                            : style.body(size: 9.5, color: PdfStyle.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
