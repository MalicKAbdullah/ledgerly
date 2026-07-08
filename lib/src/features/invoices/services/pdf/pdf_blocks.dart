import 'package:ledgerly/src/core/formats.dart';
import 'package:ledgerly/src/core/money/money.dart';
import 'package:ledgerly/src/features/clients/models/client.dart';
import 'package:ledgerly/src/features/invoices/models/invoice.dart';
import 'package:ledgerly/src/features/invoices/services/invoice_calculator.dart';
import 'package:ledgerly/src/features/invoices/services/payment_math.dart';
import 'package:ledgerly/src/features/invoices/services/pdf/pdf_style.dart';
import 'package:ledgerly/src/features/settings/models/business_profile.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Everything a template needs to lay out one document.
///
/// Defaults render an invoice; the optional overrides let the same three
/// templates render estimates ("ESTIMATE" title, "VALID UNTIL" date label,
/// custom status, a conversion note) without duplicating any layout.
final class PdfInvoiceContext {
  PdfInvoiceContext({
    required this.profile,
    required this.client,
    required this.invoice,
    required this.style,
    this.title = 'INVOICE',
    this.dueLabel = 'DUE',
    this.totalLabel = 'Total Due',
    this.statusOverride,
    this.conversionNote,
  }) : totals = InvoiceCalculator.calculate(invoice),
       paid = PaymentMath.amountPaid(invoice),
       logo = _decodeLogo(profile);

  final BusinessProfile profile;
  final Client client;
  final Invoice invoice;
  final PdfStyle style;
  final InvoiceTotals totals;
  final Money paid;
  final pw.MemoryImage? logo;

  /// Big document word, e.g. `INVOICE` / `ESTIMATE`.
  final String title;

  /// All-caps label for the second date, e.g. `DUE` / `VALID UNTIL`.
  final String dueLabel;

  /// Label of the emphasized totals row when nothing was paid.
  final String totalLabel;

  /// Overrides the derived status label (estimates set their own).
  final String? statusOverride;

  /// Extra line printed after the notes, e.g.
  /// `Estimate EST-2026-0001 → Invoice INV-2026-0007`.
  final String? conversionNote;

  bool get isPaid => invoice.status == InvoiceStatus.paid;

  Money get balance => PaymentMath.balanceDue(invoice, totals: totals);

  /// [title] in sentence case for quieter placements (`Invoice`).
  String get titleWord => title.isEmpty
      ? title
      : title[0].toUpperCase() + title.substring(1).toLowerCase();

  /// [dueLabel] in sentence case (`Due` / `Valid until`).
  String get dueWord => dueLabel.isEmpty
      ? dueLabel
      : dueLabel[0].toUpperCase() + dueLabel.substring(1).toLowerCase();

  /// Status shown in the meta grid.
  String get statusLabel {
    final override = statusOverride;
    if (override != null) return override;
    if (isPaid) return 'Paid';
    if (!paid.isZero) return 'Partially paid';
    return invoice.status.name[0].toUpperCase() +
        invoice.status.name.substring(1);
  }

  /// Label + formatted value rows for the totals block, in print order.
  /// The last row is the emphasized one ("Balance Due" / "Total").
  List<(String, String)> totalsRows() {
    final rows = <(String, String)>[
      ('Subtotal', totals.subtotal.format()),
      if (!totals.discount.isZero) ('Discount', '-${totals.discount.format()}'),
      if (invoice.taxRateBp != 0)
        ('Tax (${formatBasisPoints(invoice.taxRateBp)}%)', totals.tax.format()),
    ];
    if (paid.isZero || paid.isNegative) {
      rows.add((totalLabel, totals.total.format()));
    } else {
      rows
        ..add(('Total', totals.total.format()))
        ..add(('Paid', '-${paid.format()}'))
        ..add(('Balance Due', balance.format()));
    }
    return rows;
  }

  static pw.MemoryImage? _decodeLogo(BusinessProfile profile) {
    final bytes = profile.logoBytes;
    if (bytes == null) return null;
    try {
      return pw.MemoryImage(bytes);
    } catch (_) {
      return null; // A corrupt logo must never block invoicing.
    }
  }
}

/// Blocks shared by more than one template.
abstract final class PdfBlocks {
  /// Diagonal PAID watermark drawn behind every page of a settled invoice.
  static pw.Widget paidStamp() {
    return pw.Watermark(
      angle: 0.5,
      child: pw.Opacity(
        opacity: 0.07,
        child: pw.Text(
          'PAID',
          style: const pw.TextStyle(fontSize: 160, color: PdfStyle.paidGreen),
        ),
      ),
    );
  }

  /// Page footer: optional "Generated with Ledgerly" credit and page
  /// numbers on multi-page invoices.
  static pw.Widget footer(
    pw.Context context,
    PdfStyle style, {
    required bool showCredit,
  }) {
    final pageLabel = context.pagesCount > 1
        ? 'Page ${context.pageNumber} of ${context.pagesCount}'
        : '';
    if (!showCredit && pageLabel.isEmpty) return pw.SizedBox();
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfStyle.line, width: 0.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            showCredit ? 'Generated with Ledgerly' : '',
            style: style.body(size: 8, color: PdfStyle.faintText),
          ),
          pw.Text(
            pageLabel,
            style: style.body(size: 8, color: PdfStyle.faintText),
          ),
        ],
      ),
    );
  }

  /// "Paid on [date]" ribbon + payment history lines for invoices with
  /// recorded payments.
  static pw.Widget paymentsBlock(PdfInvoiceContext ctx) {
    final style = ctx.style;
    final currency = ctx.invoice.currency;
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('PAYMENTS RECEIVED', style: style.overline()),
        pw.SizedBox(height: 6),
        for (final payment in ctx.invoice.payments)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 3),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  '${Formats.date(payment.date)} — ${payment.method.label}'
                  '${payment.note.isEmpty ? '' : ' (${payment.note})'}',
                  style: style.body(size: 9, color: PdfStyle.muted),
                ),
                pw.Text(
                  payment.amount(currency).format(),
                  style: style.strong(size: 9, color: PdfStyle.muted),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// "Estimate → Invoice" line printed on converted estimates.
  static pw.Widget conversionNote(PdfInvoiceContext ctx) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      decoration: const pw.BoxDecoration(color: PdfStyle.faint),
      child: pw.Text(
        ctx.conversionNote ?? '',
        style: ctx.style.strong(size: 9, color: PdfStyle.muted),
      ),
    );
  }

  /// Notes / payment terms block.
  static pw.Widget notes(
    PdfInvoiceContext ctx, {
    String title = 'NOTES & PAYMENT TERMS',
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title, style: ctx.style.overline()),
        pw.SizedBox(height: 6),
        pw.Text(ctx.invoice.notes, style: ctx.style.body(size: 9.5)),
      ],
    );
  }

  /// The freelancer's own block: name, address, email, tax id.
  static List<pw.Widget> businessLines(
    PdfInvoiceContext ctx, {
    PdfColor color = PdfStyle.muted,
    pw.TextAlign align = pw.TextAlign.right,
  }) {
    final profile = ctx.profile;
    final style = ctx.style;
    return [
      if (profile.address.trim().isNotEmpty)
        pw.Text(
          profile.address,
          textAlign: align,
          style: style.body(size: 9, color: color),
        ),
      if (profile.email.isNotEmpty)
        pw.Text(profile.email, style: style.body(size: 9, color: color)),
      if (profile.taxId.isNotEmpty)
        pw.Text(
          'Tax ID: ${profile.taxId}',
          style: style.body(size: 9, color: color),
        ),
    ];
  }

  /// The client block: name, company, address, email.
  static List<pw.Widget> clientLines(PdfInvoiceContext ctx) {
    final client = ctx.client;
    final style = ctx.style;
    return [
      pw.Text(client.name, style: style.strong(size: 11)),
      if (client.company.isNotEmpty)
        pw.Text(
          client.company,
          style: style.body(size: 9, color: PdfStyle.muted),
        ),
      if (client.address.trim().isNotEmpty)
        pw.Text(
          client.address,
          style: style.body(size: 9, color: PdfStyle.muted),
        ),
      if (client.email.isNotEmpty)
        pw.Text(
          client.email,
          style: style.body(size: 9, color: PdfStyle.muted),
        ),
    ];
  }
}
