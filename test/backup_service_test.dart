import 'dart:convert';

import 'package:core_crypto/core_crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerly/src/core/data/app_data.dart';
import 'package:ledgerly/src/features/backup/services/backup_service.dart';
import 'package:ledgerly/src/features/invoices/models/invoice.dart';
import 'package:ledgerly/src/features/settings/models/business_profile.dart';

import 'helpers/fakes.dart';

void main() {
  late BackupService service;

  setUp(() {
    service = BackupService(
      keyDerivation: FakeKeyDerivation(),
      cipher: const CipherService(),
      clock: FakeClock(DateTime(2026, 7, 5, 10)),
    );
  });

  AppData sampleData() => AppData(
    profile: const BusinessProfile(
      name: 'Ada Lovelace',
      businessName: 'Café Résumé — naïve studio 🌙',
      defaultCurrency: 'EUR',
    ),
    clients: [
      makeClient(id: 'c1', name: 'Žofia Müllerová'),
      makeClient(id: 'c2', name: 'Bob'),
    ],
    invoices: [
      makeInvoice(id: 'i1', number: 'INV-2026-0001'),
      makeInvoice(
        id: 'i2',
        number: 'INV-2026-0002',
        status: InvoiceStatus.paid,
        paidAt: DateTime(2026, 6, 20),
        payments: [makePayment(id: 'p1')],
      ),
    ],
  );

  test('export produces the documented envelope', () async {
    final raw = await service.export(
      data: sampleData(),
      passphrase: 'correct horse',
    );
    final envelope = jsonDecode(raw) as Map<String, dynamic>;
    expect(envelope['formatVersion'], 1);
    expect(envelope['app'], 'ledgerly');
    expect(envelope['appVersion'], isNotEmpty);
    expect(envelope['createdAt'], '2026-07-05T10:00:00.000');
    expect(envelope['clientCount'], 2);
    expect(envelope['invoiceCount'], 2);
    expect(envelope['salt'], isNotEmpty);
    expect(envelope['nonce'], isNotEmpty);
    expect(envelope['ciphertext'], isNotEmpty);
  });

  test('ciphertext leaks no plaintext', () async {
    final raw = await service.export(
      data: sampleData(),
      passphrase: 'correct horse',
    );
    expect(raw.contains('Lovelace'), isFalse);
    expect(raw.contains('INV-2026'), isFalse);
    expect(raw.contains('Müllerová'), isFalse);
  });

  test('round-trip restores everything exactly, unicode included', () async {
    final original = sampleData();
    final raw = await service.export(
      data: original,
      passphrase: 'correct horse',
    );
    final restored = await service.decode(
      raw: raw,
      passphrase: 'correct horse',
    );
    expect(jsonEncode(restored.toJson()), jsonEncode(original.toJson()));
    expect(restored.profile.businessName, 'Café Résumé — naïve studio 🌙');
    expect(restored.invoices[1].payments, hasLength(1));
  });

  test('wrong passphrase throws wrongPassphrase', () async {
    final raw = await service.export(
      data: sampleData(),
      passphrase: 'correct horse',
    );
    expect(
      () => service.decode(raw: raw, passphrase: 'wrong horse'),
      throwsA(
        isA<BackupException>().having(
          (e) => e.error,
          'error',
          BackupError.wrongPassphrase,
        ),
      ),
    );
  });

  test('tampered ciphertext also fails as wrongPassphrase', () async {
    final raw = await service.export(
      data: sampleData(),
      passphrase: 'correct horse',
    );
    final envelope = jsonDecode(raw) as Map<String, dynamic>;
    final bytes = base64Decode(envelope['ciphertext'] as String);
    bytes[0] ^= 0xFF;
    envelope['ciphertext'] = base64Encode(bytes);
    expect(
      () => service.decode(
        raw: jsonEncode(envelope),
        passphrase: 'correct horse',
      ),
      throwsA(
        isA<BackupException>().having(
          (e) => e.error,
          'error',
          BackupError.wrongPassphrase,
        ),
      ),
    );
  });

  test('garbage input throws invalidFormat', () async {
    for (final junk in ['not json', '{}', '{"salt": 5}', '[]']) {
      expect(
        () => service.decode(raw: junk, passphrase: 'x'),
        throwsA(
          isA<BackupException>().having(
            (e) => e.error,
            'error',
            BackupError.invalidFormat,
          ),
        ),
        reason: junk,
      );
    }
  });

  test('a future format version is rejected', () async {
    final raw = await service.export(
      data: sampleData(),
      passphrase: 'correct horse',
    );
    final envelope = jsonDecode(raw) as Map<String, dynamic>;
    envelope['formatVersion'] = 99;
    expect(
      () => service.decode(
        raw: jsonEncode(envelope),
        passphrase: 'correct horse',
      ),
      throwsA(
        isA<BackupException>().having(
          (e) => e.error,
          'error',
          BackupError.unsupportedVersion,
        ),
      ),
    );
  });

  group('merge', () {
    test('adds new clients and invoices, keeps existing ones', () {
      final existing = AppData(
        clients: [makeClient(id: 'c1')],
        invoices: [makeInvoice(id: 'i1', number: 'INV-2026-0001')],
      );
      final imported = AppData(
        clients: [makeClient(id: 'c2', name: 'New Client')],
        invoices: [makeInvoice(id: 'i2', number: 'INV-2026-0002')],
      );
      final merged = BackupService.merge(existing, imported);
      expect(merged.clients.map((c) => c.id).toSet(), {'c1', 'c2'});
      expect(merged.invoices.map((i) => i.id).toSet(), {'i1', 'i2'});
    });

    test('newer invoice wins on id clashes — either direction', () {
      final older = makeInvoice(
        id: 'i1',
        notes: 'old',
        createdAt: DateTime(2026, 6, 1),
      );
      final newer = makeInvoice(
        id: 'i1',
        notes: 'new',
        createdAt: DateTime(2026, 6, 1),
        status: InvoiceStatus.paid,
        paidAt: DateTime(2026, 6, 20), // later activity ⇒ newer
      );

      final a = BackupService.merge(
        AppData(invoices: [older]),
        AppData(invoices: [newer]),
      );
      expect(a.invoices.single.notes, 'new');

      final b = BackupService.merge(
        AppData(invoices: [newer]),
        AppData(invoices: [older]),
      );
      expect(b.invoices.single.notes, 'new');
    });

    test('equal timestamps keep the existing record', () {
      final mine = makeInvoice(id: 'i1', notes: 'mine');
      final theirs = makeInvoice(id: 'i1', notes: 'theirs');
      final merged = BackupService.merge(
        AppData(invoices: [mine]),
        AppData(invoices: [theirs]),
      );
      expect(merged.invoices.single.notes, 'mine');
    });

    test('merge keeps the device profile; replace is caller-side', () {
      final existing = AppData(
        profile: const BusinessProfile(businessName: 'Mine'),
      );
      final imported = AppData(
        profile: const BusinessProfile(businessName: 'Backup'),
      );
      expect(
        BackupService.merge(existing, imported).profile.businessName,
        'Mine',
      );
    });
  });

  test('invoiceLastTouched picks the latest of all activity', () {
    final invoice = makeInvoice(
      createdAt: DateTime(2026, 1, 1),
      sentAt: DateTime(2026, 2, 1),
      payments: [makePayment(date: DateTime(2026, 3, 1))],
    );
    expect(BackupService.invoiceLastTouched(invoice), DateTime(2026, 3, 1));
  });

  test('suggested file name is date-stamped .lybackup', () {
    expect(
      BackupService.suggestedFileName(DateTime(2026, 7, 5)),
      'ledgerly-2026-07-05.lybackup',
    );
  });
}
