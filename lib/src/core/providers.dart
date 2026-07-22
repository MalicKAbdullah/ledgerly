import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:core_backup/core_backup.dart';
import 'package:core_crypto/core_crypto.dart';
import 'package:core_lock/core_lock.dart';
import 'package:core_storage/core_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:ledgerly/src/core/clock.dart';
import 'package:ledgerly/src/core/data/app_data.dart';
import 'package:ledgerly/src/core/data/app_data_notifier.dart';
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

/// Platform biometric prompt for the app lock. The real local_auth
/// implementation is constructed only in main(); tests inject fakes.
final deviceAuthProvider = Provider<IDeviceAuth>(
  (ref) => throw UnimplementedError(
    'deviceAuthProvider must be overridden in main() or with a test fake',
  ),
);

/// Argon2id verifier for the app-lock fallback password.
final passwordHasherProvider = Provider<IPasswordHasher>(
  (ref) => const Argon2PasswordHasher(),
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

/// Backup destination folder (shared engine). Android uses the Storage Access
/// Framework so a Google Drive folder can be picked; iOS uses app documents.
final backupFolderProvider = Provider<IBackupFolder>(
  (ref) =>
      Platform.isAndroid ? SafBackupFolder() : const AppDocumentsBackupFolder(),
);

/// Scheduled auto-backup engine (shared core_backup), namespaced to Ledgerly.
final autoBackupServiceProvider = Provider<AutoBackupService>(
  (ref) => AutoBackupService(
    storage: ref.watch(secureStorageProvider),
    folder: ref.watch(backupFolderProvider),
    keyPrefix: 'ledgerly',
    fileLabel: 'Ledgerly',
    fileExtension: BackupService.fileExtension,
    now: () => ref.read(clockProvider).now(),
  ),
);

/// Produces the encrypted `.lybackup` bytes for the current ledger, reusing the
/// existing [BackupService]. Fed to the auto-backup engine and "Back up now".
final ledgerBackupProducerProvider = Provider<BackupProducer>((ref) {
  return (passphrase) async {
    final data = ref.read(appDataProvider).valueOrNull;
    if (data == null) {
      throw StateError('Ledger data is not loaded yet.');
    }
    final raw = await ref
        .read(backupServiceProvider)
        .export(data: data, passphrase: passphrase!);
    return Uint8List.fromList(utf8.encode(raw));
  };
});
