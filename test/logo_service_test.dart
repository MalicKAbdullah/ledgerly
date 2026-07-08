import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:ledgerly/src/features/settings/services/logo_service.dart';

void main() {
  test('large images are downscaled to at most 512px on the long side', () {
    final big = img.Image(width: 2048, height: 1024);
    final result = LogoService.prepareSync(
      Uint8List.fromList(img.encodePng(big)),
    );
    expect(result, isNotNull);
    final decoded = img.decodePng(base64Decode(result!))!;
    expect(decoded.width, 512);
    expect(decoded.height, 256);
  });

  test('small images are kept at their original size', () {
    final small = img.Image(width: 100, height: 60);
    final result = LogoService.prepareSync(
      Uint8List.fromList(img.encodePng(small)),
    );
    final decoded = img.decodePng(base64Decode(result!))!;
    expect(decoded.width, 100);
    expect(decoded.height, 60);
  });

  test('portrait images downscale by height', () {
    final tall = img.Image(width: 600, height: 1200);
    final result = LogoService.prepareSync(
      Uint8List.fromList(img.encodePng(tall)),
    );
    final decoded = img.decodePng(base64Decode(result!))!;
    expect(decoded.height, 512);
    expect(decoded.width, 256);
  });

  test('non-image bytes return null instead of throwing', () {
    expect(LogoService.prepareSync(Uint8List.fromList([1, 2, 3, 4])), isNull);
  });
}
