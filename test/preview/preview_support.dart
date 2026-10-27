import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ledgerly/src/core/data/app_data.dart';
import 'package:ledgerly/src/core/providers.dart';
import 'package:core_crypto/core_crypto.dart';
import 'package:core_lock/core_lock.dart';
import 'package:ledgerly/src/core/storage/data_key_store.dart';
import 'package:ledgerly/src/core/storage/ledger_store.dart';

import '../helpers/fakes.dart';

/// Preview renders only run on request: `PREVIEW=OUT_DIR flutter test
/// test/preview`. Pixel output differs per platform, so they are design
/// review aids, not CI goldens.
final String? previewOut = Platform.environment['PREVIEW'];

Future<void> loadPreviewFonts() async {
  final config =
      jsonDecode(File('.dart_tool/package_config.json').readAsStringSync())
          as Map<String, dynamic>;
  final root =
      (config['packages'] as List<dynamic>)
              .cast<Map<String, dynamic>>()
              .firstWhere((p) => p['name'] == 'core_theme')['rootUri']
          as String;
  final fonts =
      '${Directory.fromUri(File('.dart_tool/package_config.json').absolute.uri.resolve(root)).path}/fonts';
  Future<void> family(String name, List<String> files) async {
    final loader = FontLoader(name);
    for (final f in files) {
      loader.addFont(
        Future.value(ByteData.sublistView(File(f).readAsBytesSync())),
      );
    }
    await loader.load();
  }

  await family(AppTextStyles.fontFamily, [
    for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold'])
      '$fonts/MonaSans-$w.ttf',
  ]);
  await family(AppTextStyles.displayFamily, [
    for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold'])
      '$fonts/MonaSansDisplay-$w.ttf',
  ]);
  await family(AppTextStyles.monoFamily, [
    for (final w in ['Regular', 'Medium', 'SemiBold'])
      '$fonts/MonaSansMono-$w.ttf',
  ]);
  final flutterRoot =
      Platform.environment['FLUTTER_ROOT'] ??
      '/Users/abdullah/development/flutter';
  await family('MaterialIcons', [
    '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  ]);
}

/// Seeds an encrypted vault the way the app writes it and returns provider
/// overrides that load it.
Future<List<Override>> seededOverrides(AppData data) async {
  final secureStorage = FakeSecureStorage();
  final file = FakeVaultFile();
  await LedgerStore(
    cipher: const CipherService(),
    keyStore: DataKeyStore(secureStorage),
    file: file,
  ).save(data);
  SharedPreferences.setMockInitialValues({});
  final appearance = await AppearanceController.load();
  return [
    appearanceProvider.overrideWithValue(appearance),
    secureStorageProvider.overrideWithValue(secureStorage),
    vaultFileProvider.overrideWithValue(file),
    deviceAuthProvider.overrideWithValue(const UnavailableDeviceAuth()),
  ];
}

/// Renders [screen] in light and dark at phone width, side by side, and writes
/// `NAME.png`.
Future<void> renderScreen(
  WidgetTester tester,
  String name,
  Widget Function() screen, {
  AppData? data,
  double height = 844,
  double width = 390,
}) async {
  tester.view.devicePixelRatio = 2;
  tester.view.physicalSize = Size((width * 2 + 2) * 2, height * 2);
  addTearDown(tester.view.reset);
  final key = GlobalKey();
  final seed = data ?? const AppData();
  final overrides = <Brightness, List<Override>>{
    Brightness.light: await tester.runAsync(() => seededOverrides(seed)) ?? [],
    Brightness.dark: await tester.runAsync(() => seededOverrides(seed)) ?? [],
  };

  Widget pane(Brightness b) => SizedBox(
    width: width,
    height: height,
    child: ProviderScope(
      overrides: overrides[b]!,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.build(b, accent: AppAccents.ledgerly),
        builder: (context, child) => MediaQuery(
          data: MediaQueryData(
            size: Size(width, height),
            padding: const EdgeInsets.only(top: 44, bottom: 20),
            disableAnimations: true,
          ),
          child: child!,
        ),
        home: screen(),
      ),
    ),
  );

  await tester.pumpWidget(
    RepaintBoundary(
      key: key,
      child: ColoredBox(
        color: const Color(0xFF808080),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              pane(Brightness.light),
              const SizedBox(width: 2),
              pane(Brightness.dark),
            ],
          ),
        ),
      ),
    ),
  );
  for (var i = 0; i < 8; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 40)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory(previewOut!).createSync(recursive: true);
    File('$previewOut/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}
