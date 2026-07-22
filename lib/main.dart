import 'package:core_lock/core_lock.dart';
import 'package:core_notify/core_notify.dart';
import 'package:core_storage/core_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:ledgerly/src/app.dart';
import 'package:ledgerly/src/core/providers.dart';
import 'package:ledgerly/src/features/notifications/invoice_notifier.dart';
import 'package:ledgerly/src/features/security/providers/lock_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Read the lock flags before the first frame so the app opens already
  // locked (no unlocked flash on cold start).
  const storage = SecureStorageImpl(FlutterSecureStorage());
  final lockEnabled = await LockController.readEnabled(storage, lockStorageKey);
  final biometricEnabled = await LockController.readBiometricEnabled(
    storage,
    lockStorageKey,
  );

  // Local notifications (invoice reminders). Tapping just opens the app.
  final notify = LocalNotify();
  await notify.initialize(channels: InvoiceNotifier.channels, onSelect: (_) {});
  await notify.requestPermission();

  runApp(
    ProviderScope(
      overrides: [
        secureStorageProvider.overrideWithValue(storage),
        // The only place the real platform authenticator is constructed;
        // everything else depends on IDeviceAuth (tests inject fakes).
        deviceAuthProvider.overrideWithValue(LocalAuthDeviceAuth()),
        appLockEnabledOnLaunchProvider.overrideWithValue(lockEnabled),
        appLockBiometricOnLaunchProvider.overrideWithValue(biometricEnabled),
        notifyProvider.overrideWithValue(notify),
      ],
      child: const LedgerlyApp(),
    ),
  );
}
