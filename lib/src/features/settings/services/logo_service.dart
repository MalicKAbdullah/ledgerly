import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;
import 'package:image/image.dart' as img;

/// Prepares a picked image for use as the business logo: decode, downscale
/// to at most [maxDimension] on the longest side, re-encode as PNG, and
/// base64 it for storage inside the encrypted vault.
///
/// Pure Dart (package:image). The heavy decode/resize runs in an isolate
/// via [prepare] so picking a 12-megapixel photo never janks the UI.
abstract final class LogoService {
  static const int maxDimension = 512;

  /// Returns base64-encoded PNG, or null when [bytes] is not a decodable
  /// image.
  static Future<String?> prepare(Uint8List bytes) =>
      compute(prepareSync, bytes);

  /// Synchronous worker — exposed for tests.
  static String? prepareSync(Uint8List bytes) {
    img.Image? decoded;
    try {
      decoded = img.decodeImage(bytes);
    } catch (_) {
      return null; // Garbage bytes must never crash Settings.
    }
    if (decoded == null) return null;

    var logo = decoded;
    if (logo.width > maxDimension || logo.height > maxDimension) {
      logo = logo.width >= logo.height
          ? img.copyResize(logo, width: maxDimension)
          : img.copyResize(logo, height: maxDimension);
    }
    return base64Encode(img.encodePng(logo));
  }
}
