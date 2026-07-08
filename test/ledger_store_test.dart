import 'dart:convert';

import 'package:core_crypto/core_crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerly/src/core/data/app_data.dart';
import 'package:ledgerly/src/core/storage/data_key_store.dart';
import 'package:ledgerly/src/core/storage/ledger_store.dart';
import 'package:ledgerly/src/features/invoices/models/invoice.dart';
import 'package:ledgerly/src/features/settings/models/business_profile.dart';

import 'helpers/fakes.dart';

void main() {
  late FakeSecureStorage secureStorage;
  late FakeVaultFile file;
  late LedgerStore store;

  setUp(() {
    secureStorage = FakeSecureStorage();
    file = FakeVaultFile();
    store = LedgerStore(
      cipher: const CipherService(),
      keyStore: DataKeyStore(secureStorage),
      file: file,
    );
  });

  group('DataKeyStore', () {
    test('generates a 256-bit key on first use and persists it', () async {
      final keyStore = DataKeyStore(secureStorage);
      final key = await keyStore.obtainKey();
      expect(key.length, 32);
      expect(secureStorage.store[DataKeyStore.storageKey], base64Encode(key));
    });

    test('returns the same key on subsequent calls', () async {
      final keyStore = DataKeyStore(secureStorage);
      final first = await keyStore.obtainKey();
      final second = await DataKeyStore(secureStorage).obtainKey();
      expect(second, first);
    });
  });

  group('LedgerStore', () {
    test('load returns empty AppData on first launch', () async {
      final data = await store.load();
      expect(data.clients, isEmpty);
      expect(data.invoices, isEmpty);
      expect(data.profile.defaultCurrency, 'USD');
      expect(file.bytes, isNull, reason: 'load must not write');
    });

    test('encrypt/decrypt round-trip preserves all data', () async {
      final data = AppData(
        profile: const BusinessProfile(
          name: 'Ada Lovelace',
          businessName: 'Analytical Engines',
          defaultCurrency: 'GBP',
          defaultTaxRateBp: 2000,
          invoicePrefix: 'AE',
        ),
        clients: [makeClient()],
        invoices: [
          makeInvoice(
            taxRateBp: 750,
            discountType: DiscountType.percent,
            discountValue: 500,
            status: InvoiceStatus.sent,
            sentAt: DateTime(2026, 6, 2),
          ),
        ],
      );

      await store.save(data);
      final restored = await store.load();

      expect(restored.profile.name, 'Ada Lovelace');
      expect(restored.profile.defaultTaxRateBp, 2000);
      expect(restored.profile.invoicePrefix, 'AE');
      expect(restored.clients.single.name, 'Ada Lovelace');
      expect(restored.clients.single.company, 'Analytical Engines Ltd');
      expect(restored.invoices.single.number, 'INV-2026-0001');
      expect(restored.invoices.single.taxRateBp, 750);
      expect(restored.invoices.single.status, InvoiceStatus.sent);
      expect(restored.invoices.single.items.single.quantityMilli, 1000);
    });

    test('bytes on disk are ciphertext, not plaintext JSON', () async {
      await store.save(AppData(clients: [makeClient(name: 'FINDME')]));
      final onDisk = String.fromCharCodes(file.bytes!);
      expect(onDisk.contains('FINDME'), isFalse);
      expect(onDisk.contains('clients'), isFalse);
    });

    test('a second store instance with the same storage decrypts', () async {
      await store.save(AppData(clients: [makeClient()]));
      final otherStore = LedgerStore(
        cipher: const CipherService(),
        keyStore: DataKeyStore(secureStorage),
        file: file,
      );
      final restored = await otherStore.load();
      expect(restored.clients, hasLength(1));
    });

    test('a different key cannot decrypt (AES-GCM auth fails)', () async {
      await store.save(AppData(clients: [makeClient()]));
      final strangerStore = LedgerStore(
        cipher: const CipherService(),
        keyStore: DataKeyStore(FakeSecureStorage()), // fresh key
        file: file,
      );
      await expectLater(strangerStore.load(), throwsA(anything));
    });

    test('tampered ciphertext fails authentication', () async {
      await store.save(const AppData());
      final tampered = file.bytes!;
      tampered[tampered.length - 1] ^= 0xFF;
      file.bytes = tampered;
      await expectLater(store.load(), throwsA(anything));
    });

    test('every save writes fresh bytes (nonce changes)', () async {
      await store.save(const AppData());
      final first = List<int>.of(file.bytes!);
      await store.save(const AppData());
      expect(file.bytes, isNot(equals(first)));
      expect(file.writeCount, 2);
    });
  });
}
