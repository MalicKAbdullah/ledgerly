import 'package:local_auth/local_auth.dart';

/// Abstraction over the platform authentication prompt (biometrics with a
/// device-credential fallback) so lock logic is testable without platform
/// channels.
abstract interface class IDeviceAuth {
  /// Whether the device can show an authentication prompt at all
  /// (biometrics enrolled, or a PIN/pattern/passcode set up).
  Future<bool> canAuthenticate();

  /// Shows the system prompt. Returns true when the user authenticated.
  Future<bool> authenticate({required String reason});
}

/// Production implementation backed by the local_auth plugin. Constructed
/// only in main() — everywhere else depends on [IDeviceAuth].
final class LocalAuthDeviceAuth implements IDeviceAuth {
  LocalAuthDeviceAuth([LocalAuthentication? auth])
    : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  @override
  Future<bool> canAuthenticate() async {
    try {
      // isDeviceSupported covers device credentials (PIN/pattern/passcode)
      // as well as biometrics, matching the non-biometricOnly prompt below.
      return await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> authenticate({required String reason}) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          // Allow the device PIN/pattern/passcode as a fallback so users
          // without (working) biometrics are never locked out.
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}
