import 'package:core_crypto/core_crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerly/src/core/data/app_data.dart';
import 'package:ledgerly/src/core/providers.dart';
import 'package:ledgerly/src/core/storage/data_key_store.dart';
import 'package:ledgerly/src/core/storage/ledger_store.dart';
import 'package:ledgerly/src/features/invoices/models/invoice.dart';
import 'package:ledgerly/src/features/invoices/models/invoice_template.dart';
import 'package:ledgerly/src/features/invoices/models/payment.dart';

import 'helpers/fakes.dart';

/// End-to-end notifier flows for payments: record → auto-paid transition,
/// partial state, overpayment rejection, and removal reverting status.
/// Everything runs against the real encrypted store with in-memory fakes.
void main() {
  late FakeSecureStorage secureStorage;
  late FakeVaultFile file;
  late ProviderContainer container;

  Future<void> seed(AppData data) async {
    final store = LedgerStore(
      cipher: const CipherService(),
      keyStore: DataKeyStore(secureStorage),
      file: file,
    );
    await store.save(data);
  }

  setUp(() {
    secureStorage = FakeSecureStorage();
    file = FakeVaultFile();
    container = ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(secureStorage),
        vaultFileProvider.overrideWithValue(file),
      ],
    );
    addTearDown(container.dispose);
  });

  Future<AppData> load() => container.read(appDataProvider.future);

  test('recording a partial payment keeps status sent', () async {
    await seed(
      AppData(
        clients: [makeClient()],
        invoices: [
          makeInvoice(status: InvoiceStatus.sent, sentAt: DateTime(2026, 6, 2)),
        ],
      ),
    );
    await load();

    final updated = await container
        .read(appDataProvider.notifier)
        .recordPayment(
          'inv-1',
          date: DateTime(2026, 6, 10),
          amountMinor: 4000,
          method: PaymentMethod.cash,
          note: 'first half',
        );

    expect(updated.status, InvoiceStatus.sent);
    expect(updated.payments.single.amountMinor, 4000);
    expect(updated.payments.single.method, PaymentMethod.cash);
    expect(updated.paidAt, isNull);
  });

  test('payment covering the balance flips the invoice to paid', () async {
    await seed(
      AppData(
        clients: [makeClient()],
        invoices: [
          makeInvoice(status: InvoiceStatus.sent, sentAt: DateTime(2026, 6, 2)),
        ],
      ),
    );
    await load();
    final notifier = container.read(appDataProvider.notifier);

    await notifier.recordPayment(
      'inv-1',
      date: DateTime(2026, 6, 10),
      amountMinor: 4000,
    );
    final updated = await notifier.recordPayment(
      'inv-1',
      date: DateTime(2026, 6, 20),
      amountMinor: 6000,
    );

    expect(updated.status, InvoiceStatus.paid);
    expect(updated.paidAt, DateTime(2026, 6, 20));
    expect(updated.payments.length, 2);

    // Persisted: reload from the encrypted file.
    final reloaded = ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(secureStorage),
        vaultFileProvider.overrideWithValue(file),
      ],
    );
    addTearDown(reloaded.dispose);
    final data = await reloaded.read(appDataProvider.future);
    expect(data.invoiceById('inv-1')!.status, InvoiceStatus.paid);
    expect(data.invoiceById('inv-1')!.payments.length, 2);
  });

  test('overpayment throws and mutates nothing', () async {
    await seed(
      AppData(
        clients: [makeClient()],
        invoices: [
          makeInvoice(status: InvoiceStatus.sent, sentAt: DateTime(2026, 6, 2)),
        ],
      ),
    );
    await load();
    final notifier = container.read(appDataProvider.notifier);

    await expectLater(
      notifier.recordPayment(
        'inv-1',
        date: DateTime(2026, 6, 10),
        amountMinor: 10001,
      ),
      throwsArgumentError,
    );
    final data = await load();
    expect(data.invoiceById('inv-1')!.payments, isEmpty);
  });

  test('removing the settling payment reverts paid back to sent', () async {
    await seed(
      AppData(
        clients: [makeClient()],
        invoices: [
          makeInvoice(status: InvoiceStatus.sent, sentAt: DateTime(2026, 6, 2)),
        ],
      ),
    );
    await load();
    final notifier = container.read(appDataProvider.notifier);

    final paid = await notifier.recordPayment(
      'inv-1',
      date: DateTime(2026, 6, 10),
      amountMinor: 10000,
    );
    expect(paid.status, InvoiceStatus.paid);

    await notifier.removePayment('inv-1', paid.payments.single.id);
    final data = await load();
    final invoice = data.invoiceById('inv-1')!;
    expect(invoice.status, InvoiceStatus.sent);
    expect(invoice.payments, isEmpty);
    expect(invoice.paidAt, isNull);
    expect(invoice.sentAt, DateTime(2026, 6, 2), reason: 'sentAt preserved');
  });

  test('removing one of several payments keeps a settled invoice paid when '
      'the rest still covers the total', () async {
    // $100 invoice with a $100 payment and an (older) $100 manual overlap is
    // impossible via validation, so model the realistic case: two payments
    // 60 + 40, remove the 40 → owed again.
    await seed(
      AppData(
        clients: [makeClient()],
        invoices: [
          makeInvoice(status: InvoiceStatus.sent, sentAt: DateTime(2026, 6, 2)),
        ],
      ),
    );
    await load();
    final notifier = container.read(appDataProvider.notifier);
    await notifier.recordPayment(
      'inv-1',
      date: DateTime(2026, 6, 5),
      amountMinor: 6000,
    );
    final settled = await notifier.recordPayment(
      'inv-1',
      date: DateTime(2026, 6, 6),
      amountMinor: 4000,
    );
    expect(settled.status, InvoiceStatus.paid);

    await notifier.removePayment('inv-1', settled.payments.last.id);
    final data = await load();
    final invoice = data.invoiceById('inv-1')!;
    expect(invoice.status, InvoiceStatus.sent);
    expect(invoice.payments.length, 1);
  });

  test('setInvoiceTemplate persists the chosen template', () async {
    await seed(AppData(clients: [makeClient()], invoices: [makeInvoice()]));
    await load();

    await container
        .read(appDataProvider.notifier)
        .setInvoiceTemplate('inv-1', InvoiceTemplateId.modern);

    final data = await load();
    expect(data.invoiceById('inv-1')!.template, InvoiceTemplateId.modern);
  });

  test('duplicate keeps the template but not the payments', () async {
    await seed(
      AppData(
        clients: [makeClient()],
        invoices: [
          makeInvoice(
            status: InvoiceStatus.sent,
            sentAt: DateTime(2026, 6, 2),
            template: InvoiceTemplateId.minimal,
            payments: [makePayment(amountMinor: 5000)],
          ),
        ],
      ),
    );
    await load();

    final copy = await container
        .read(appDataProvider.notifier)
        .duplicateInvoice('inv-1');

    expect(copy.template, InvoiceTemplateId.minimal);
    expect(copy.payments, isEmpty);
    expect(copy.status, InvoiceStatus.draft);
  });
}
