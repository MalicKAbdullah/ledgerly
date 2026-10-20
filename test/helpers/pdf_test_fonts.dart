import 'dart:io';

import 'package:ledgerly/src/features/invoices/services/pdf/pdf_fonts.dart';

PdfFontBytes? _cache;

/// Loads the Mona Sans faces from the `core_theme` font files, so PDF tests stay
/// pure Dart — no asset bundle, no platform channels. Works whether core_theme
/// resolves via the monorepo path (local) or a git dependency (CI).
PdfFontBytes loadTestFonts() {
  final cached = _cache;
  if (cached != null) return cached;

  final dir = _resolveFontsDir();
  return _cache = PdfFontBytes(
    regular: File('$dir/MonaSans-Regular.ttf').readAsBytesSync(),
    semiBold: File('$dir/MonaSans-SemiBold.ttf').readAsBytesSync(),
    bold: File('$dir/MonaSans-Bold.ttf').readAsBytesSync(),
  );
}

String _resolveFontsDir() {
  const local = '../../packages/core_theme/fonts';
  if (File('$local/MonaSans-Regular.ttf').existsSync()) return local;
  final pubCache =
      Platform.environment['PUB_CACHE'] ??
      '${Platform.environment['HOME']}/.pub-cache';
  final gitDir = Directory('$pubCache/git');
  if (gitDir.existsSync()) {
    for (final entry in gitDir.listSync()) {
      if (entry is Directory && entry.path.contains('secure-suite-core')) {
        final fonts = '${entry.path}/core_theme/fonts';
        if (File('$fonts/MonaSans-Regular.ttf').existsSync()) return fonts;
      }
    }
  }
  throw StateError(
    'Could not locate core_theme Mona Sans fonts for PDF tests.',
  );
}
