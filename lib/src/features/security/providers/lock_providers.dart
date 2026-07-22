import 'package:core_lock/core_lock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledgerly/src/core/providers.dart';

/// App-lock wiring on the shared core_lock package: a fingerprint unlocks
/// Ledgerly, with an app-set password (never the phone PIN) as the fallback.

const String lockStorageKey = 'ledgerly_app_lock_enabled';

/// Whether the lock / biometric were on at launch — read in main() before
/// runApp so the first frame is already locked.
final appLockEnabledOnLaunchProvider = Provider<bool>((ref) => false);
final appLockBiometricOnLaunchProvider = Provider<bool>((ref) => false);

final lockControllerProvider = ChangeNotifierProvider<LockController>(
  (ref) => LockController(
    deviceAuth: ref.watch(deviceAuthProvider),
    hasher: ref.watch(passwordHasherProvider),
    storage: ref.watch(secureStorageProvider),
    clock: () => ref.read(clockProvider).now(),
    storageKey: lockStorageKey,
    appName: 'Ledgerly',
    enabled: ref.watch(appLockEnabledOnLaunchProvider),
    biometricEnabled: ref.watch(appLockBiometricOnLaunchProvider),
  ),
);

/// Settings availability: whether the device has enrolled biometrics.
final deviceAuthAvailableProvider = FutureProvider<bool>(
  (ref) => ref.watch(deviceAuthProvider).canAuthenticate(),
);
