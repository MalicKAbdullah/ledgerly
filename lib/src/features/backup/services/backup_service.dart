import 'dart:convert';
import 'dart:typed_data';

import 'package:core_crypto/core_crypto.dart';
import 'package:ledgerly/src/core/app_info.dart';
import 'package:ledgerly/src/core/clock.dart';
import 'package:ledgerly/src/core/data/app_data.dart';
import 'package:ledgerly/src/core/security/key_derivation.dart';
import 'package:ledgerly/src/features/clients/models/client.dart';
import 'package:ledgerly/src/features/estimates/models/estimate.dart';
import 'package:ledgerly/src/features/expenses/models/expense.dart';
import 'package:ledgerly/src/features/invoices/models/invoice.dart';
import 'package:ledgerly/src/features/recurring/models/recurring_template.dart';

/// Why a backup could not be read.
enum BackupError { invalidFormat, unsupportedVersion, wrongPassphrase }

final class BackupException implements Exception {
  const BackupException(this.error);

  final BackupError error;

  @override
  String toString() => 'BackupException($error)';
}

/// Encrypted `.lybackup` export/import of the whole ledger.
///
/// The file is a JSON envelope `{formatVersion, app, appVersion, createdAt,
/// clientCount, invoiceCount, salt, nonce, ciphertext}` where the ciphertext
/// is the full [AppData] JSON encrypted with AES-256-GCM under an Argon2id
/// key derived from a separate backup passphrase (independent of the
/// device-bound vault key, so the file can be restored on any device).
final class BackupService {
  const BackupService({
    required IKeyDerivation keyDerivation,
    required CipherService cipher,
    required Clock clock,
  }) : _kdf = keyDerivation,
       _cipher = cipher,
       _clock = clock;

  final IKeyDerivation _kdf;
  final CipherService _cipher;
  final Clock _clock;

  static const int formatVersion = 1;
  static const String fileExtension = 'lybackup';
  static const int minPassphraseLength = 8;

  /// Serializes and encrypts the full [data] snapshot under [passphrase].
  Future<String> export({
    required AppData data,
    required String passphrase,
  }) async {
    final salt = await _cipher.generateSalt();
    final key = await _kdf.deriveKey(passphrase: passphrase, salt: salt);
    final payload = await _cipher.encrypt(
      plaintext: jsonEncode(data.toJson()),
      keyBytes: key,
      salt: salt,
    );
    key.fillRange(0, key.length, 0);
    return jsonEncode({
      'formatVersion': formatVersion,
      'app': 'ledgerly',
      'appVersion': AppInfo.version,
      'createdAt': _clock.now().toIso8601String(),
      'clientCount': data.clients.length,
      'invoiceCount': data.invoices.length,
      'salt': base64Encode(salt),
      'nonce': base64Encode(payload.nonce),
      'ciphertext': base64Encode(payload.ciphertext),
    });
  }

  /// Decrypts a backup produced by [export]. Throws [BackupException] on a
  /// malformed file, unsupported (newer) format version, or wrong
  /// passphrase.
  Future<AppData> decode({
    required String raw,
    required String passphrase,
  }) async {
    final Map<String, dynamic> envelope;
    final Uint8List salt;
    final Uint8List nonce;
    final Uint8List ciphertext;
    try {
      envelope = jsonDecode(raw) as Map<String, dynamic>;
      salt = base64Decode(envelope['salt'] as String);
      nonce = base64Decode(envelope['nonce'] as String);
      ciphertext = base64Decode(envelope['ciphertext'] as String);
    } catch (_) {
      throw const BackupException(BackupError.invalidFormat);
    }
    final version = envelope['formatVersion'];
    if (version is! int || version > formatVersion) {
      throw const BackupException(BackupError.unsupportedVersion);
    }

    final key = await _kdf.deriveKey(passphrase: passphrase, salt: salt);
    final String plaintext;
    try {
      plaintext = await _cipher.decrypt(
        payload: EncryptedPayload(
          ciphertext: ciphertext,
          nonce: nonce,
          salt: salt,
        ),
        keyBytes: key,
      );
    } catch (_) {
      // AES-GCM authentication failed: wrong passphrase (or tampered file).
      throw const BackupException(BackupError.wrongPassphrase);
    } finally {
      key.fillRange(0, key.length, 0);
    }

    try {
      return AppData.fromJson(jsonDecode(plaintext) as Map<String, dynamic>);
    } catch (_) {
      throw const BackupException(BackupError.invalidFormat);
    }
  }

  /// Merges [imported] into [existing] by id — records that only exist in
  /// the backup are added, id clashes keep whichever side was touched more
  /// recently (ties keep the current data). The business profile always
  /// stays as it is on this device; use Replace to take the backup's.
  static AppData merge(AppData existing, AppData imported) {
    return existing.copyWith(
      clients: mergeById<Client>(
        existing.clients,
        imported.clients,
        id: (c) => c.id,
        touchedAt: (c) => c.createdAt,
      ),
      invoices: mergeById<Invoice>(
        existing.invoices,
        imported.invoices,
        id: (i) => i.id,
        touchedAt: invoiceLastTouched,
      ),
      expenses: mergeById<Expense>(
        existing.expenses,
        imported.expenses,
        id: (e) => e.id,
        touchedAt: (e) => e.createdAt,
      ),
      estimates: mergeById<Estimate>(
        existing.estimates,
        imported.estimates,
        id: (e) => e.id,
        touchedAt: estimateLastTouched,
      ),
      recurringTemplates: mergeById<RecurringTemplate>(
        existing.recurringTemplates,
        imported.recurringTemplates,
        id: (t) => t.id,
        // A further-advanced schedule is the newer state — it prevents
        // re-generating invoices that the other device already created.
        touchedAt: (t) => t.nextRunDate,
      ),
    );
  }

  /// The most recent moment an estimate changed in a way we can observe.
  static DateTime estimateLastTouched(Estimate estimate) {
    var latest = estimate.createdAt;
    for (final t in [
      estimate.sentAt,
      estimate.acceptedAt,
      estimate.declinedAt,
    ]) {
      if (t != null && t.isAfter(latest)) latest = t;
    }
    return latest;
  }

  /// Generic newest-wins merge; the existing record survives on a tie.
  static List<T> mergeById<T>(
    List<T> existing,
    List<T> imported, {
    required String Function(T) id,
    required DateTime Function(T) touchedAt,
  }) {
    final byId = {for (final e in existing) id(e): e};
    for (final candidate in imported) {
      final current = byId[id(candidate)];
      if (current == null || touchedAt(candidate).isAfter(touchedAt(current))) {
        byId[id(candidate)] = candidate;
      }
    }
    return byId.values.toList();
  }

  /// The most recent moment an invoice changed in a way we can observe:
  /// creation, status timestamps, or any recorded payment.
  static DateTime invoiceLastTouched(Invoice invoice) {
    var latest = invoice.createdAt;
    void consider(DateTime? t) {
      if (t != null && t.isAfter(latest)) latest = t;
    }

    consider(invoice.sentAt);
    consider(invoice.paidAt);
    for (final payment in invoice.payments) {
      consider(payment.date);
    }
    return latest;
  }

  static String suggestedFileName(DateTime now) {
    String two(int n) => n.toString().padLeft(2, '0');
    return 'ledgerly-${now.year}-${two(now.month)}-${two(now.day)}'
        '.$fileExtension';
  }
}
