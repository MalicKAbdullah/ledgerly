import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerly/src/core/providers.dart';
import 'package:ledgerly/src/features/security/services/app_lock_settings.dart';
import 'package:ledgerly/src/features/security/widgets/lock_gate.dart';

import '../helpers/fakes.dart';

void main() {
  testWidgets('lock gate hides the app until the fake auth unlocks it', (
    tester,
  ) async {
    // App lock enabled; the first (auto-triggered) prompt fails.
    final auth = FakeDeviceAuth(authResult: false);
    final storage = FakeSecureStorage();
    storage.store[AppLockSettings.storageKey] = 'true';

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          deviceAuthProvider.overrideWithValue(auth),
          secureStorageProvider.overrideWithValue(storage),
        ],
        child: const MaterialApp(
          home: LockGate(child: Text('Sensitive invoices')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Locked: lock screen up, auto-trigger fired once and failed with
    // friendly copy, app content not shown.
    expect(find.text('Ledgerly'), findsOneWidget);
    expect(find.text('Unlock Ledgerly'), findsOneWidget);
    expect(auth.authCalls, 1);
    expect(find.textContaining("couldn't verify"), findsOneWidget);
    expect(find.text('Sensitive invoices'), findsNothing);

    // Retry with the prompt succeeding unlocks the app.
    auth.authResult = true;
    await tester.tap(find.byKey(const Key('unlock-button')));
    await tester.pumpAndSettle();

    expect(auth.authCalls, 2);
    expect(find.text('Sensitive invoices'), findsOneWidget);
    expect(find.text('Unlock Ledgerly'), findsNothing);
  });
}
