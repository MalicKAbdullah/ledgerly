import 'package:ledgerly/src/core/formats.dart';
import 'package:ledgerly/src/core/money/money.dart';
import 'package:ledgerly/src/features/invoices/services/pdf/pdf_blocks.dart';
import 'package:ledgerly/src/features/invoices/services/pdf/pdf_style.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Modern — accent color band header, airy spacing, borderless table with
/// soft zebra rows, and a tinted balance card.
abstract final class ModernTemplate {
  static List<pw.Widget> build(PdfInvoiceContext ctx) {
    return [
      _band(ctx),
      pw.SizedBox(height: 26),
      _parties(ctx),
      pw.SizedBox(height: 26),
      _itemsTable(ctx),
      pw.SizedBox(height: 18),
      _totals(ctx),
      if (ctx.invoice.payments.isNotEmpty) ...[
        pw.SizedBox(height: 22),
        PdfBlocks.paymentsBlock(ctx),
      ],
      if (ctx.invoice.notes.trim().isNotEmpty) ...[
        pw.SizedBox(height: 22),
        PdfBlocks.notes(ctx),
      ],
      if (ctx.conversionNote != null) ...[
        pw.SizedBox(height: 22),
        PdfBlocks.conversionNote(ctx),
      ],
    ];
  }

  static pw.Widget _band(PdfInvoiceContext ctx) {
    final style = ctx.style;
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 22, vertical: 18),
      decoration: pw.BoxDecoration(
        color: PdfStyle.accent,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Row(
            children: [
              if (ctx.logo != null)
                pw.Container(
                  width: 38,
                  height: 38,
                  margin: const pw.EdgeInsets.only(right: 12),
                  padding: const pw.EdgeInsets.all(4),
                  decoration: pw.BoxDecoration(
                    color: PdfStyle.white,
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Image(ctx.logo!, fit: pw.BoxFit.contain),
                ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    ctx.profile.displayName.isEmpty
                        ? 'Invoice'
                        : ctx.profile.displayName,
                    style: style.heavy(size: 15, color: PdfStyle.white),
                  ),
                  if (ctx.profile.email.isNotEmpty)
                    pw.Text(
                      ctx.profile.email,
                      style: style.body(
                        size: 9,
                        color: const PdfColor.fromInt(0xFFC7D2FE),
                      ),
                    ),
                ],
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                ctx.title,
                style: style
                    .overline(
                      size: 9,
                      color: const PdfColor.fromInt(0xFFC7D2FE),
                    )
                    .copyWith(letterSpacing: 2.5),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                ctx.invoice.number,
                style: style.heavy(size: 14, color: PdfStyle.white),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _parties(PdfInvoiceContext ctx) {
    final style = ctx.style;
    pw.Widget block(String label, List<pw.Widget> children) => pw.Expanded(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: style.overline(color: PdfStyle.accent)),
          pw.SizedBox(height: 7),
          ...children,
        ],
      ),
    );

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        block('BILLED TO', PdfBlocks.clientLines(ctx)),
        block('FROM', [
          pw.Text(ctx.profile.displayName, style: style.strong(size: 11)),
          ...PdfBlocks.businessLines(ctx, align: pw.TextAlign.left),
        ]),
        pw.SizedBox(
          width: 150,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text('ISSUED', style: style.overline(color: PdfStyle.accent)),
              pw.SizedBox(height: 7),
              pw.Text(
                Formats.date(ctx.invoice.issueDate),
                style: style.body(size: 10),
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                ctx.dueLabel,
                style: style.overline(color: PdfStyle.accent),
              ),
              pw.SizedBox(height: 7),
              pw.Text(
                Formats.date(ctx.invoice.dueDate),
                style: style.strong(size: 10),
              ),
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
        padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        child: pw.Text(
          text,
          style: textStyle ?? style.body(size: 9.5),
          textAlign: align,
        ),
      );
    }

    final items = ctx.invoice.items;
    return pw.Table(
      columnWidths: const {
        0: pw.FlexColumnWidth(5),
        1: pw.FlexColumnWidth(1.3),
        2: pw.FlexColumnWidth(2),
        3: pw.FlexColumnWidth(2),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(color: PdfStyle.accent, width: 1.2),
            ),
          ),
          repeat: true,
          children: [
            cell(
              'DESCRIPTION',
              textStyle: style.overline(size: 7.5, color: PdfStyle.accent),
            ),
            cell(
              'QTY',
              textStyle: style.overline(size: 7.5, color: PdfStyle.accent),
              align: pw.TextAlign.right,
            ),
            cell(
              'UNIT PRICE',
              textStyle: style.overline(size: 7.5, color: PdfStyle.accent),
              align: pw.TextAlign.right,
            ),
            cell(
              'AMOUNT',
              textStyle: style.overline(size: 7.5, color: PdfStyle.accent),
              align: pw.TextAlign.right,
            ),
          ],
        ),
        for (var i = 0; i < items.length; i++)
          pw.TableRow(
            decoration: pw.BoxDecoration(
              color: i.isOdd ? PdfStyle.faint : null,
            ),
            children: [
              cell(items[i].description),
              cell(
                formatQuantityMilli(items[i].quantityMilli),
                align: pw.TextAlign.right,
              ),
              cell(
                items[i].unitPrice(currency).format(),
                align: pw.TextAlign.right,
              ),
              cell(
                items[i].total(currency).format(),
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
    final headline = rows.removeLast();

    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: [
        pw.SizedBox(
          width: 240,
          child: pw.Column(
            children: [
              for (final row in rows)
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(
                    vertical: 3,
                    horizontal: 12,
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        row.$1,
                        style: style.body(size: 9.5, color: PdfStyle.muted),
                      ),
                      pw.Text(
                        row.$2,
                        style: style.body(size: 9.5, color: PdfStyle.muted),
                      ),
                    ],
                  ),
                ),
              pw.SizedBox(height: 6),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 12,
                ),
                decoration: pw.BoxDecoration(
                  color: ctx.isPaid ? PdfStyle.faint : PdfStyle.accentSoft,
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      headline.$1,
                      style: style.heavy(
                        size: 12,
                        color: ctx.isPaid
                            ? PdfStyle.paidGreen
                            : PdfStyle.accent,
                      ),
                    ),
                    pw.Text(
                      headline.$2,
                      style: style.heavy(
                        size: 13,
                        color: ctx.isPaid
                            ? PdfStyle.paidGreen
                            : PdfStyle.accent,
                      ),
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
