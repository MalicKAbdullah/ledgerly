import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:core_storage/core_storage.dart';

/// Manages the random 256-bit data key that encrypts the vault file.
///
/// The key is generated once on first launch with a cryptographically secure
/// RNG and kept in the platform keychain/keystore via [ISecureStorage]. It is
/// never derived from a password and never leaves secure storage unencrypted
/// by the OS.
final class DataKeyStore {
  const DataKeyStore(this._secureStorage, {Random? random}) : _random = random;

  static const String storageKey = 'ledgerly_data_key';
  static const int keyLengthBytes = 32;

  final ISecureStorage _secureStorage;
  final Random? _random;

  /// Returns the existing data key, generating and persisting one on first
  /// launch.
  Future<Uint8List> obtainKey() async {
    final existing = await _secureStorage.read(key: storageKey);
    if (existing != null) {
      return base64Decode(existing);
    }

    final rng = _random ?? Random.secure();
    final key = Uint8List.fromList(
      List<int>.generate(keyLengthBytes, (_) => rng.nextInt(256)),
    );
    await _secureStorage.write(key: storageKey, value: base64Encode(key));
    return key;
  }
}
