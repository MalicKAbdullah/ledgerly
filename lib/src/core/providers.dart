import 'package:core_crypto/core_crypto.dart';
import 'package:core_storage/core_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:ledgerly/src/core/clock.dart';
import 'package:ledgerly/src/core/data/app_data.dart';
import 'package:ledgerly/src/core/data/app_data_notifier.dart';
import 'package:ledgerly/src/core/security/device_auth.dart';
import 'package:ledgerly/src/core/security/key_derivation.dart';
import 'package:ledgerly/src/core/storage/data_key_store.dart';
import 'package:ledgerly/src/core/storage/ledger_store.dart';
import 'package:ledgerly/src/core/storage/vault_file.dart';
import 'package:ledgerly/src/features/backup/services/backup_service.dart';

/// Platform secure storage (keychain/keystore). Tests override this with an
/// in-memory fake — no platform channels are touched in unit tests.
final secureStorageProvider = Provider<ISecureStorage>(
  (ref) => const SecureStorageImpl(FlutterSecureStorage()),
);

/// Wall clock. Tests override with a fake to drive the app-lock window.
final clockProvider = Provider<Clock>((ref) => const SystemClock());

/// Platform authentication prompt for the app lock. The real local_auth
/// implementation is constructed only in main(); tests inject fakes.
final deviceAuthProvider = Provider<IDeviceAuth>(
  (ref) => throw UnimplementedError(
    'deviceAuthProvider must be overridden in main() or with a test fake',
  ),
);

/// Encrypted vault file location. Tests override with an in-memory fake.
final vaultFileProvider = Provider<IVaultFile>((ref) => LocalVaultFile());

final cipherServiceProvider = Provider<CipherService>(
  (ref) => const CipherService(),
);

final dataKeyStoreProvider = Provider<DataKeyStore>(
  (ref) => DataKeyStore(ref.watch(secureStorageProvider)),
);

final ledgerStoreProvider = Provider<LedgerStore>(
  (ref) => LedgerStore(
    cipher: ref.watch(cipherServiceProvider),
    keyStore: ref.watch(dataKeyStoreProvider),
    file: ref.watch(vaultFileProvider),
  ),
);

/// The single source of truth for all app data.
final appDataProvider = AsyncNotifierProvider<AppDataNotifier, AppData>(
  AppDataNotifier.new,
);

/// Argon2id passphrase derivation for encrypted backups. Tests override
/// with a fast deterministic fake.
final keyDerivationProvider = Provider<IKeyDerivation>(
  (ref) => const Argon2KeyDerivation(KeyDerivationService()),
);

/// Encrypted `.lybackup` export/import codec.
final backupServiceProvider = Provider<BackupService>(
  (ref) => BackupService(
    keyDerivation: ref.watch(keyDerivationProvider),
    cipher: ref.watch(cipherServiceProvider),
    clock: ref.watch(clockProvider),
  ),
);
