import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Thin wrapper over the platform share sheet. Nothing here ever leaves
/// the device unless the user picks a destination in the system sheet.
abstract final class ShareService {
  static Future<void> shareText(String text, {String? subject}) =>
      Share.share(text, subject: subject);

  /// Writes [csv] to a temp file and hands it to the share sheet.
  static Future<void> shareCsv({
    required String csv,
    required String fileName,
  }) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}${Platform.pathSeparator}$fileName');
    await file.writeAsString(csv, flush: true);
    await Share.shareXFiles([
      XFile(file.path, mimeType: 'text/csv'),
    ], subject: fileName);
  }
}
