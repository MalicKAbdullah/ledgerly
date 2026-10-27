import 'dart:io';
import 'dart:ui' as ui;

import 'package:core_crypto/core_crypto.dart';
import 'package:core_lock/core_lock.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerly/src/app.dart';
import 'package:ledgerly/src/core/app_info.dart';
import 'package:ledgerly/src/core/providers.dart';
import 'package:ledgerly/src/core/router.dart';
import 'package:ledgerly/src/core/storage/data_key_store.dart';
import 'package:ledgerly/src/core/storage/ledger_store.dart';
import 'package:ledgerly/src/features/onboarding/onboarding_providers.dart';
import 'package:ledgerly/src/features/security/providers/lock_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fakes.dart';
import '../preview/preview_support.dart';
import '../preview/sample_data.dart';

/// Design-review renders of the whole app (lock screen and main tabs) in
/// light and dark, with the theme chosen through the Appearance setting.
/// Run with `GALLERY=OUT_DIR flutter test test/gallery`; skipped otherwise.
final String? _galleryOut = Platform.environment['GALLERY'];

final class _NoBiometricMatch implements IDeviceAuth {
  @override
  Future<bool> canAuthenticate() async => true;

  /// The system prompt never succeeds, so the lock stays up for the render.
  @override
  Future<bool> authenticate({required String reason}) async => false;
}

/// Fast stand-in for Argon2; only the password "right" matches.
final class _FakeHasher implements IPasswordHasher {
  @override
  Future<String> hash(String password) async => 'h:$password';

  @override
  Future<bool> verify(String password, String stored) async =>
      stored == 'h:$password';
}

void main() {
  final enabled = _galleryOut != null;

  setUpAll(() async {
    if (enabled) await loadPreviewFonts();
  });

  Future<void> shot(
    WidgetTester tester,
    String name, {
    required ThemeMode mode,
    bool locked = false,
    bool biometric = false,
    String location = '/dashboard',
    Size size = const Size(390, 844),
    Future<void> Function()? act,
  }) async {
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = size * 2;
    tester.view.padding = const FakeViewPadding(top: 24 * 2, bottom: 16 * 2);
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({
      AppearanceController.storageKey: mode.name,
    });
    final storage = FakeSecureStorage();
    final file = FakeVaultFile();
    final appearance = (await tester.runAsync(() async {
      await LedgerStore(
        cipher: const CipherService(),
        keyStore: DataKeyStore(storage),
        file: file,
      ).save(sampleData());
      return AppearanceController.load();
    }))!;
    storage.store.addAll({
      OnboardingSeenNotifier.storageKey: 'true',
      updateAutoCheckKey: 'false',
      if (locked) ...{
        lockStorageKey: 'true',
        '${lockStorageKey}_verifier': 'h:right',
        '${lockStorageKey}_recovery': 'h:x',
      },
    });

    final container = ProviderContainer(
      overrides: [
        appearanceProvider.overrideWithValue(appearance),
        secureStorageProvider.overrideWithValue(storage),
        vaultFileProvider.overrideWithValue(file),
        deviceAuthProvider.overrideWithValue(_NoBiometricMatch()),
        passwordHasherProvider.overrideWithValue(_FakeHasher()),
        appVersionProvider.overrideWith((ref) async => '1.9.0'),
        appLockEnabledOnLaunchProvider.overrideWithValue(locked),
        appLockBiometricOnLaunchProvider.overrideWithValue(biometric),
      ],
    );
    addTearDown(container.dispose);

    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: UncontrolledProviderScope(
          container: container,
          child: const LedgerlyApp(),
        ),
      ),
    );
    if (location != '/dashboard') container.read(routerProvider).go(location);
    Future<void> settle() async {
      for (var i = 0; i < 8; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 40)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    await settle();
    if (act != null) {
      await act();
      await settle();
    }
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();

    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      Directory(_galleryOut!).createSync(recursive: true);
      File(
        '$_galleryOut/$name.png',
      ).writeAsBytesSync(bytes!.buffer.asUint8List());
    });
    await tester.pumpWidget(const SizedBox());
  }

  void gallery(
    String name, {
    bool locked = false,
    bool biometric = false,
    String location = '/dashboard',
    Size size = const Size(390, 844),
    List<ThemeMode> modes = const [ThemeMode.light, ThemeMode.dark],
    Future<void> Function(WidgetTester tester)? act,
  }) {
    for (final mode in modes) {
      testWidgets('$name ${mode.name}', (tester) async {
        await shot(
          tester,
          '$name-${mode.name}',
          mode: mode,
          locked: locked,
          biometric: biometric,
          location: location,
          size: size,
          act: act == null ? null : () => act(tester),
        );
      }, skip: !enabled);
    }
  }

  gallery('lock-01-biometric', locked: true, biometric: true);
  gallery('lock-02-password', locked: true);
  gallery(
    'lock-03-error',
    locked: true,
    act: (tester) async {
      await tester.enterText(find.byType(TextField), 'wrong');
      await tester.tap(find.text('Unlock'));
    },
  );
  gallery(
    'lock-04-recovery',
    locked: true,
    biometric: true,
    act: (tester) => tester.tap(find.text('Forgot password?')),
  );
  gallery(
    'lock-05-small-360x640',
    locked: true,
    biometric: true,
    size: const Size(360, 640),
    modes: const [ThemeMode.light],
  );
  gallery('app-01-dashboard');
  gallery('app-02-invoices', location: '/invoices');
  gallery('app-03-expenses', location: '/expenses');
  gallery('app-04-clients', location: '/clients');
  gallery('app-05-settings', location: '/settings');
}
