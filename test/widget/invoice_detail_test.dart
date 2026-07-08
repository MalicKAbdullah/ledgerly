import 'package:core_crypto/core_crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ledgerly/src/core/data/app_data.dart';
import 'package:ledgerly/src/core/providers.dart';
import 'package:ledgerly/src/core/storage/data_key_store.dart';
import 'package:ledgerly/src/core/storage/ledger_store.dart';
import 'package:ledgerly/src/features/invoices/models/invoice.dart';
import 'package:ledgerly/src/features/invoices/models/payment.dart';
import 'package:ledgerly/src/features/invoices/screens/invoice_preview_screen.dart';
import 'package:ledgerly/src/features/settings/models/business_profile.dart';

import '../helpers/fakes.dart';

void main() {
  late FakeSecureStorage secureStorage;
  late FakeVaultFile file;

  setUp(() {
    secureStorage = FakeSecureStorage();
    file = FakeVaultFile();
  });

  Future<void> seed(AppData data) async {
    final store = LedgerStore(
      cipher: const CipherService(),
      keyStore: DataKeyStore(secureStorage),
      file: file,
    );
    await store.save(data);
  }

  Future<void> pumpDetail(WidgetTester tester, String invoiceId) async {
    tester.view.physicalSize = const Size(800, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final router = GoRouter(
      initialLocation: '/invoices/$invoiceId',
      routes: [
        GoRoute(
          path: '/invoices/:id',
          builder: (_, state) =>
              InvoicePreviewScreen(invoiceId: state.pathParameters['id']!),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          secureStorageProvider.overrideWithValue(secureStorage),
          vaultFileProvider.overrideWithValue(file),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('partially paid invoice shows badge, balance, payment history, '
      'and timeline', (tester) async {
    await seed(
      AppData(
        profile: const BusinessProfile(name: 'Ada'),
        clients: [makeClient()],
        invoices: [
          makeInvoice(
            status: InvoiceStatus.sent,
            sentAt: DateTime(2026, 6, 2),
            dueDate: DateTime.now().add(const Duration(days: 30)),
            payments: [
              makePayment(
                amountMinor: 2500,
                method: PaymentMethod.cash,
                note: 'deposit',
              ),
            ],
          ),
        ],
      ),
    );
    await pumpDetail(tester, 'inv-1');

    // Status chip shows the partial state.
    expect(find.text('Partial'), findsOneWidget);
    // Partially-paid banner with exact amounts.
    expect(
      find.textContaining(
        r'Partially paid — $25.00 of $100.00 received, $75.00 due',
      ),
      findsOneWidget,
    );
    // Items card shows total / paid / balance rows.
    expect(find.text('Balance due'), findsOneWidget);
    expect(find.text(r'-$25.00'), findsOneWidget);
    // Payment history row.
    expect(find.text('Payments'), findsOneWidget);
    expect(find.text('Cash'), findsOneWidget);
    // Timeline events.
    expect(find.text('Invoice created'), findsOneWidget);
    expect(find.text('Sent to client'), findsOneWidget);
    expect(find.text('Payment received'), findsOneWidget);
  });

  testWidgets('recording the remaining balance marks the invoice paid', (
    tester,
  ) async {
    await seed(
      AppData(
        profile: const BusinessProfile(name: 'Ada'),
        clients: [makeClient()],
        invoices: [
          makeInvoice(
            status: InvoiceStatus.sent,
            sentAt: DateTime(2026, 6, 2),
            dueDate: DateTime.now().add(const Duration(days: 30)),
            payments: [makePayment(amountMinor: 4000)],
          ),
        ],
      ),
    );
    await pumpDetail(tester, 'inv-1');

    // Open the record-payment sheet from the quick action.
    await tester.tap(find.text('Payment'));
    await tester.pumpAndSettle();

    // Amount is prefilled with the open balance ($60.00) — just submit.
    expect(find.byKey(const Key('payment-amount')), findsOneWidget);
    await tester.tap(find.byKey(const Key('payment-submit')));
    await tester.pumpAndSettle();

    expect(find.text('Paid'), findsWidgets);
    expect(find.text('Paid in full'), findsOneWidget);
    expect(find.textContaining('fully paid'), findsOneWidget);
  });

  testWidgets('overpayment is rejected with a friendly error', (tester) async {
    await seed(
      AppData(
        profile: const BusinessProfile(name: 'Ada'),
        clients: [makeClient()],
        invoices: [
          makeInvoice(
            status: InvoiceStatus.sent,
            sentAt: DateTime(2026, 6, 2),
            dueDate: DateTime.now().add(const Duration(days: 30)),
          ),
        ],
      ),
    );
    await pumpDetail(tester, 'inv-1');

    await tester.tap(find.text('Payment'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('payment-amount')), '100.01');
    await tester.tap(find.byKey(const Key('payment-submit')));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('more than the'),
      findsOneWidget,
      reason: 'overpayment must be blocked in the sheet',
    );
  });
}
