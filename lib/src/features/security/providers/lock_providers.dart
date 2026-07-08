import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledgerly/src/core/providers.dart';
import 'package:ledgerly/src/features/security/services/app_lock_settings.dart';
import 'package:ledgerly/src/features/security/services/lock_controller.dart';

final appLockSettingsProvider = Provider<AppLockSettings>(
  (ref) => AppLockSettings(
    storage: ref.watch(secureStorageProvider),
    auth: ref.watch(deviceAuthProvider),
  ),
);

/// Whether the device can offer the lock (biometrics or screen lock set up).
/// Errors (e.g. no authenticator injected) read as "not available".
final deviceAuthAvailableProvider = FutureProvider<bool>(
  (ref) => ref.watch(appLockSettingsProvider).canOffer(),
);

/// The persisted toggle, re-read after every change (settings invalidates it).
final appLockEnabledProvider = FutureProvider<bool>(
  (ref) => ref.watch(appLockSettingsProvider).isEnabled(),
);

/// The live lock state machine. Created once per scope; the persisted flag
/// is restored asynchronously so a cold start with the lock on lands on the
/// lock screen before any data is shown.
final lockControllerProvider = ChangeNotifierProvider<LockController>((ref) {
  final controller = LockController(
    auth: ref.watch(deviceAuthProvider),
    clock: ref.watch(clockProvider),
  );
  var disposed = false;
  ref.onDispose(() => disposed = true);
  ref.read(appLockSettingsProvider).isEnabled().then((enabled) {
    if (!disposed) controller.restore(enabled: enabled);
  });
  return controller;
});
