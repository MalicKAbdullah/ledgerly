import 'package:core_crypto/core_crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ledgerly/src/core/data/app_data.dart';
import 'package:ledgerly/src/core/providers.dart';
import 'package:ledgerly/src/core/storage/data_key_store.dart';
import 'package:ledgerly/src/core/storage/ledger_store.dart';
import 'package:ledgerly/src/features/invoices/screens/invoice_editor_screen.dart';

import '../helpers/fakes.dart';

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

  Future<void> pumpEditor(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final router = GoRouter(
      initialLocation: '/edit',
      routes: [
        GoRoute(path: '/edit', builder: (_, _) => const InvoiceEditorScreen()),
        GoRoute(
          path: '/invoices/:id',
          builder: (_, state) =>
              Scaffold(body: Text('preview:${state.pathParameters['id']}')),
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

  testWidgets('validates that a client is selected and items exist', (
    tester,
  ) async {
    await store.save(AppData(clients: [makeClient()]));
    await pumpEditor(tester);

    // No client selected yet.
    await tester.tap(find.byKey(const Key('save-invoice')));
    await tester.pumpAndSettle();
    expect(find.text('Select a client before saving.'), findsOneWidget);

    // Select the client, still no line items.
    await tester.tap(find.byKey(const Key('client-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ada Lovelace — Analytical Engines Ltd').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('save-invoice')));
    await tester.pumpAndSettle();
    expect(find.text('Add at least one line item.'), findsOneWidget);
  });

  testWidgets('line item sheet validates its fields', (tester) async {
    await store.save(AppData(clients: [makeClient()]));
    await pumpEditor(tester);

    await tester.tap(find.byKey(const Key('add-line-item')));
    await tester.pumpAndSettle();

    // Clear the prefilled quantity and submit an empty form.
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('item-quantity')),
        matching: find.byType(TextField),
      ),
      '',
    );
    await tester.tap(find.byKey(const Key('item-submit')));
    await tester.pumpAndSettle();

    expect(find.text('Description is required'), findsOneWidget);
    expect(find.text('Enter a quantity like 1 or 1.5'), findsOneWidget);
    expect(find.text('Enter a valid price'), findsOneWidget);
  });

  testWidgets('a complete invoice saves, gets a number, and navigates', (
    tester,
  ) async {
    await store.save(AppData(clients: [makeClient()]));
    await pumpEditor(tester);

    // Select client.
    await tester.tap(find.byKey(const Key('client-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ada Lovelace — Analytical Engines Ltd').last);
    await tester.pumpAndSettle();

    // Add a line item: 1.5 x $100.00.
    await tester.tap(find.byKey(const Key('add-line-item')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('item-description')),
        matching: find.byType(TextField),
      ),
      'Design work',
    );
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('item-quantity')),
        matching: find.byType(TextField),
      ),
      '1.5',
    );
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('item-price')),
        matching: find.byType(TextField),
      ),
      '100',
    );
    await tester.tap(find.byKey(const Key('item-submit')));
    await tester.pumpAndSettle();

    // Line total appears in the editor ($150.00).
    expect(find.text(r'$150.00'), findsWidgets);

    await tester.tap(find.byKey(const Key('save-invoice')));
    await tester.pumpAndSettle();

    // Navigated to the preview route of the saved invoice.
    expect(find.textContaining('preview:'), findsOneWidget);

    // The invoice was persisted with an auto-assigned number.
    final saved = await store.load();
    expect(saved.invoices, hasLength(1));
    expect(saved.invoices.single.number, 'INV-${DateTime.now().year}-0001');
    expect(saved.invoices.single.items.single.quantityMilli, 1500);
    expect(saved.invoices.single.items.single.unitPriceMinor, 10000);
  });
}
