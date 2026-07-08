import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

/// Minimal file abstraction so the repository can be unit-tested with an
/// in-memory fake — no platform channels in tests.
abstract interface class IVaultFile {
  Future<Uint8List?> read();

  Future<void> write(Uint8List bytes);
}

/// Stores the encrypted vault as a single file in the app documents
/// directory. Writes go to a temp file first, then rename — an interrupted
/// write can never corrupt the existing vault.
final class LocalVaultFile implements IVaultFile {
  LocalVaultFile({this.fileName = 'ledgerly.vault'});

  final String fileName;

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}${Platform.pathSeparator}$fileName');
  }

  @override
  Future<Uint8List?> read() async {
    final file = await _file();
    if (!file.existsSync()) return null;
    return file.readAsBytes();
  }

  @override
  Future<void> write(Uint8List bytes) async {
    final file = await _file();
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsBytes(bytes, flush: true);
    await tmp.rename(file.path);
  }
}
