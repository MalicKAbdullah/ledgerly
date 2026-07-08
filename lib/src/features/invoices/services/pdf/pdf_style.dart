import 'package:ledgerly/src/features/invoices/services/pdf/pdf_fonts.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Shared palette and parsed fonts for all PDF templates.
final class PdfStyle {
  PdfStyle(PdfFontBytes bytes)
    : base = pw.Font.ttf(
        bytes.regular.buffer.asByteData(
          bytes.regular.offsetInBytes,
          bytes.regular.lengthInBytes,
        ),
      ),
      semiBold = pw.Font.ttf(
        bytes.semiBold.buffer.asByteData(
          bytes.semiBold.offsetInBytes,
          bytes.semiBold.lengthInBytes,
        ),
      ),
      bold = pw.Font.ttf(
        bytes.bold.buffer.asByteData(
          bytes.bold.offsetInBytes,
          bytes.bold.lengthInBytes,
        ),
      );

  final pw.Font base;
  final pw.Font semiBold;
  final pw.Font bold;

  // Ledgerly indigo, matched to the app accent.
  static const PdfColor accent = PdfColor.fromInt(0xFF4F46E5);
  static const PdfColor accentSoft = PdfColor.fromInt(0xFFE0E7FF);
  static const PdfColor ink = PdfColor.fromInt(0xFF18181B);
  static const PdfColor muted = PdfColor.fromInt(0xFF71717A);
  static const PdfColor faintText = PdfColor.fromInt(0xFFA1A1AA);
  static const PdfColor line = PdfColor.fromInt(0xFFE4E4E7);
  static const PdfColor faint = PdfColor.fromInt(0xFFFAFAFA);
  static const PdfColor paidGreen = PdfColor.fromInt(0xFF16A34A);
  static const PdfColor white = PdfColor.fromInt(0xFFFFFFFF);

  pw.PageTheme pageTheme({pw.BuildCallback? buildBackground}) {
    return pw.PageTheme(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(48, 44, 48, 40),
      theme: pw.ThemeData.withFont(base: base, bold: bold),
      buildBackground: buildBackground,
    );
  }

  pw.TextStyle body({double size = 10, PdfColor color = ink}) =>
      pw.TextStyle(font: base, fontSize: size, color: color);

  pw.TextStyle strong({double size = 10, PdfColor color = ink}) =>
      pw.TextStyle(font: semiBold, fontSize: size, color: color);

  pw.TextStyle heavy({double size = 10, PdfColor color = ink}) =>
      pw.TextStyle(font: bold, fontSize: size, color: color);

  pw.TextStyle overline({
    double size = 8,
    PdfColor color = muted,
    double letterSpacing = 1.2,
  }) => pw.TextStyle(
    font: semiBold,
    fontSize: size,
    color: color,
    letterSpacing: letterSpacing,
  );
}
