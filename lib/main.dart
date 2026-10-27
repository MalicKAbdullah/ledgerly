import 'dart:async';

import 'package:core_lock/core_lock.dart';
import 'package:core_notify/core_notify.dart';
import 'package:core_theme/core_theme.dart';
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

  // One bulk secure-storage read serves every launch read (lock flags, data
  // key, preferences). Ledgerly is the only writer of its keys and holds the
  // data key in memory for the session anyway.
  final storage = await CachedSecureStorage.load(
    const SecureStorageImpl(FlutterSecureStorage()),
  );
  // Read before the first frame so the app opens already locked (no
  // unlocked flash on cold start).
  final lockEnabled = await LockController.readEnabled(storage, lockStorageKey);
  final biometricEnabled = await LockController.readBiometricEnabled(
    storage,
    lockStorageKey,
  );
  final appearance = await AppearanceController.load();

  // Local notifications (invoice reminders). Set up after the first frame is
  // scheduled; LocalNotify queues calls until it is ready.
  final notify = LocalNotify(
    smallIcon: 'ic_stat_notify',
    accentColor: AppAccents.ledgerly.light,
  );

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
        appearanceProvider.overrideWithValue(appearance),
      ],
      child: const LedgerlyApp(),
    ),
  );

  // Tapping a notification just opens the app.
  unawaited(
    notify
        .initialize(channels: InvoiceNotifier.channels, onSelect: (_) {})
        .then((_) => notify.requestPermission()),
  );
}
