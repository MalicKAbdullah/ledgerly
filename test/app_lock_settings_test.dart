import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerly/src/features/security/services/app_lock_settings.dart';

import 'helpers/fakes.dart';

void main() {
  late FakeSecureStorage storage;
  late FakeDeviceAuth auth;
  late AppLockSettings settings;

  setUp(() {
    storage = FakeSecureStorage();
    auth = FakeDeviceAuth();
    settings = AppLockSettings(storage: storage, auth: auth);
  });

  test('lock is off by default', () async {
    expect(await settings.isEnabled(), isFalse);
  });

  test(
    'enable requires one successful authentication and round-trips',
    () async {
      expect(await settings.enable(), isTrue);
      expect(auth.authCalls, 1);
      expect(auth.lastReason, 'Confirm to turn on app lock');

      // Round-trip: a fresh instance over the same storage sees the flag.
      final reloaded = AppLockSettings(storage: storage, auth: auth);
      expect(await reloaded.isEnabled(), isTrue);
    },
  );

  test('failed authentication leaves the lock off', () async {
    auth.authResult = false;
    expect(await settings.enable(), isFalse);
    expect(await settings.isEnabled(), isFalse);
    expect(storage.store, isEmpty);
  });

  test('enable never prompts when the device cannot authenticate', () async {
    auth.available = false;
    expect(await settings.enable(), isFalse);
    expect(auth.authCalls, 0);
    expect(await settings.isEnabled(), isFalse);
  });

  test('disable round-trips back to off', () async {
    await settings.enable();
    expect(await settings.isEnabled(), isTrue);

    await settings.disable();
    expect(await settings.isEnabled(), isFalse);
    expect(storage.store, isEmpty);
  });

  test('canOffer mirrors device availability', () async {
    expect(await settings.canOffer(), isTrue);
    auth.available = false;
    expect(await settings.canOffer(), isFalse);
  });
}
