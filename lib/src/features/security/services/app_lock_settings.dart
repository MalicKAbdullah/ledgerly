import 'package:core_storage/core_storage.dart';
import 'package:ledgerly/src/core/security/device_auth.dart';

/// Persists the optional app-lock toggle behind the existing secure-storage
/// abstraction. Enabling requires one successful device authentication so
/// the user proves the prompt works before it stands between them and their
/// invoices.
final class AppLockSettings {
  const AppLockSettings({
    required ISecureStorage storage,
    required IDeviceAuth auth,
  }) : _storage = storage,
       _auth = auth;

  static const String storageKey = 'ledgerly_app_lock_enabled';

  final ISecureStorage _storage;
  final IDeviceAuth _auth;

  /// Whether the device can offer the lock at all.
  Future<bool> canOffer() => _auth.canAuthenticate();

  Future<bool> isEnabled() async =>
      await _storage.read(key: storageKey) == 'true';

  /// Turns the lock on. Returns true only after one successful
  /// authentication; on any failure nothing is persisted.
  Future<bool> enable() async {
    if (!await _auth.canAuthenticate()) return false;
    if (!await _auth.authenticate(reason: 'Confirm to turn on app lock')) {
      return false;
    }
    await _storage.write(key: storageKey, value: 'true');
    return true;
  }

  /// Turns the lock off.
  Future<void> disable() => _storage.delete(key: storageKey);
}
