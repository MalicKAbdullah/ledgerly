import 'package:core_crypto/core_crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerly/src/core/data/app_data.dart';
import 'package:ledgerly/src/core/providers.dart';
import 'package:ledgerly/src/core/storage/data_key_store.dart';
import 'package:ledgerly/src/core/storage/ledger_store.dart';
import 'package:ledgerly/src/features/dashboard/screens/dashboard_screen.dart';
import 'package:ledgerly/src/features/invoices/models/invoice.dart';
import 'package:ledgerly/src/features/settings/models/business_profile.dart';

import '../helpers/fakes.dart';

void main() {
  testWidgets('dashboard renders stats and recent invoices from a fake repo', (
    tester,
  ) async {
    final secureStorage = FakeSecureStorage();
    final file = FakeVaultFile();

    // Seed the encrypted store exactly the way the app writes it.
    final store = LedgerStore(
      cipher: const CipherService(),
      keyStore: DataKeyStore(secureStorage),
      file: file,
    );
    final now = DateTime.now();
    await store.save(
      AppData(
        profile: const BusinessProfile(name: 'Ada', defaultCurrency: 'USD'),
        clients: [makeClient()],
        invoices: [
          makeInvoice(
            id: 'sent-1',
            number: 'INV-2026-0001',
            status: InvoiceStatus.sent,
            dueDate: now.add(const Duration(days: 10)),
            items: const [
              LineItem(
                id: 'i1',
                description: 'Design',
                quantityMilli: 1000,
                unitPriceMinor: 25000, // $250.00 outstanding
              ),
            ],
          ),
          makeInvoice(
            id: 'paid-1',
            number: 'INV-2026-0002',
            status: InvoiceStatus.paid,
            paidAt: now,
            items: const [
              LineItem(
                id: 'i2',
                description: 'Build',
                quantityMilli: 1000,
                unitPriceMinor: 10000, // $100.00 paid this month
              ),
            ],
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          secureStorageProvider.overrideWithValue(secureStorage),
          vaultFileProvider.overrideWithValue(file),
        ],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );

    // First frame is the loading spinner while the vault decrypts.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();

    expect(find.text('Outstanding'), findsOneWidget);
    expect(find.text(r'$250.00'), findsWidgets);
    expect(find.text('Paid this month'), findsOneWidget);
    expect(find.text(r'$100.00'), findsWidgets);
    expect(find.text('Overdue (0)'), findsOneWidget);
    expect(find.text('Revenue vs expenses — last 6 months'), findsOneWidget);

    // Recent invoices list shows both invoices with the client name.
    await tester.scrollUntilVisible(find.text('INV-2026-0001'), 200);
    expect(find.text('INV-2026-0001'), findsOneWidget);
    expect(find.text('Ada Lovelace'), findsWidgets);
  });

  testWidgets(
    'fresh install: empty dashboard guides towards the business profile',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            secureStorageProvider.overrideWithValue(FakeSecureStorage()),
            vaultFileProvider.overrideWithValue(FakeVaultFile()),
          ],
          child: const MaterialApp(home: DashboardScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Welcome to Ledgerly'), findsOneWidget);
      expect(find.text('Set up your business profile'), findsOneWidget);
      expect(find.text('New Invoice'), findsOneWidget);
    },
  );

  testWidgets(
    'with a profile set the empty state offers a first invoice instead',
    (tester) async {
      final secureStorage = FakeSecureStorage();
      final file = FakeVaultFile();
      final store = LedgerStore(
        cipher: const CipherService(),
        keyStore: DataKeyStore(secureStorage),
        file: file,
      );
      await store.save(
        const AppData(profile: BusinessProfile(businessName: 'Ada Studio')),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            secureStorageProvider.overrideWithValue(secureStorage),
            vaultFileProvider.overrideWithValue(file),
          ],
          child: const MaterialApp(home: DashboardScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('No invoices yet'), findsOneWidget);
      expect(find.text('New Invoice'), findsOneWidget);
      expect(find.text('Set up your business profile'), findsNothing);
    },
  );
}
