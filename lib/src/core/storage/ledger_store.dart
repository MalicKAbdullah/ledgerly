import 'dart:convert';

import 'package:core_crypto/core_crypto.dart';
import 'package:ledgerly/src/core/data/app_data.dart';
import 'package:ledgerly/src/core/storage/data_key_store.dart';
import 'package:ledgerly/src/core/storage/vault_file.dart';

/// Repository persistence: JSON -> AES-256-GCM -> single vault file.
///
/// Load-decrypt on start, encrypt-write on every mutation. The payload
/// layout (salt | nonce | ciphertext+tag) comes from core_crypto. The salt
/// slot is filled with fresh random bytes on each write; it is not used for
/// key derivation because the data key is random, not password-derived.
final class LedgerStore {
  const LedgerStore({
    required CipherService cipher,
    required DataKeyStore keyStore,
    required IVaultFile file,
  }) : _cipher = cipher,
       _keyStore = keyStore,
       _file = file;

  final CipherService _cipher;
  final DataKeyStore _keyStore;
  final IVaultFile _file;

  /// Reads and decrypts the vault. Returns an empty [AppData] on first
  /// launch (no file yet).
  Future<AppData> load() async {
    final bytes = await _file.read();
    if (bytes == null) return const AppData();

    final key = await _keyStore.obtainKey();
    final plaintext = await _cipher.decrypt(
      payload: EncryptedPayload.fromBytes(bytes),
      keyBytes: key,
    );
    return AppData.fromJson(jsonDecode(plaintext) as Map<String, dynamic>);
  }

  /// Encrypts and writes the full snapshot.
  Future<void> save(AppData data) async {
    final key = await _keyStore.obtainKey();
    final payload = await _cipher.encrypt(
      plaintext: jsonEncode(data.toJson()),
      keyBytes: key,
      salt: await _cipher.generateSalt(),
    );
    await _file.write(payload.toBytes());
  }
}
