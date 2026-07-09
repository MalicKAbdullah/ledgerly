import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerly/src/core/providers.dart';
import 'package:ledgerly/src/features/security/providers/lock_providers.dart';
import 'package:ledgerly/src/features/security/services/app_lock_settings.dart';
import 'package:ledgerly/src/features/security/services/lock_controller.dart';
import 'package:ledgerly/src/features/security/widgets/lock_gate.dart';

import '../helpers/fakes.dart';

/// Pumps a [LockGate] with the app lock enabled and the given fake auth,
/// returning the fake clock so tests can drive the re-lock window.
Future<FakeClock> pumpLockedGate(
  WidgetTester tester, {
  required FakeDeviceAuth auth,
}) async {
  final storage = FakeSecureStorage();
  storage.store[AppLockSettings.storageKey] = 'true';
  final clock = FakeClock();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        deviceAuthProvider.overrideWithValue(auth),
        secureStorageProvider.overrideWithValue(storage),
        clockProvider.overrideWithValue(clock),
      ],
      child: const MaterialApp(
        home: LockGate(child: Text('Sensitive invoices')),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return clock;
}

LockController controllerOf(WidgetTester tester) =>
    ProviderScope.containerOf(
      tester.element(find.byType(LockGate)),
    ).read(lockControllerProvider);

void main() {
  testWidgets('shows the fingerprint button immediately when locked', (
    tester,
  ) async {
    // The prompt is left in-flight (pending completer) so we can assert the
    // button is on screen *while* auth is still resolving — it must never be
    // hidden behind an async availability probe.
    final gate = Completer<bool>();
    final auth = FakeDeviceAuth()..onAuthenticate = () => gate.future;
    final storage = FakeSecureStorage();
    storage.store[AppLockSettings.storageKey] = 'true';

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          deviceAuthProvider.overrideWithValue(auth),
          secureStorageProvider.overrideWithValue(storage),
          clockProvider.overrideWithValue(FakeClock()),
        ],
        child: const MaterialApp(
          home: LockGate(child: Text('Sensitive invoices')),
        ),
      ),
    );
    // A few frames to run the async restore + post-frame auto-prompt, without
    // pumpAndSettle (the in-flight spinner would never settle).
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('biometric-button')), findsOneWidget);
    expect(find.byKey(const Key('unlock-button')), findsOneWidget);
    expect(find.text('Sensitive invoices'), findsNothing);

    // Let the in-flight prompt resolve so no work is left pending.
    gate.complete(false);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('unlock-button')), findsOneWidget);
  });

  testWidgets('auto-prompts on entry, keeps the button after a failure', (
    tester,
  ) async {
    final auth = FakeDeviceAuth(authResult: false);
    await pumpLockedGate(tester, auth: auth);

    // The prompt fired automatically once, failed with friendly copy, and
    // the button is still there to retry.
    expect(auth.authCalls, 1);
    expect(find.textContaining("couldn't verify"), findsOneWidget);
    expect(find.byKey(const Key('unlock-button')), findsOneWidget);
    expect(find.text('Sensitive invoices'), findsNothing);

    // Retry with the prompt succeeding unlocks the app.
    auth.authResult = true;
    await tester.tap(find.byKey(const Key('unlock-button')));
    await tester.pumpAndSettle();

    expect(auth.authCalls, 2);
    expect(find.text('Sensitive invoices'), findsOneWidget);
    expect(find.byKey(const Key('unlock-button')), findsNothing);
  });

  testWidgets('auto-prompt fires again on every re-lock, not just cold start', (
    tester,
  ) async {
    final auth = FakeDeviceAuth();
    final clock = await pumpLockedGate(tester, auth: auth);

    // Cold-start auto-prompt succeeded.
    expect(auth.authCalls, 1);
    expect(find.text('Sensitive invoices'), findsOneWidget);

    // Background past the re-lock window, then resume: the gate re-locks and
    // a fresh lock screen auto-prompts without any tap.
    final controller = controllerOf(tester);
    controller.onBackgrounded();
    clock.advance(const Duration(seconds: 31));
    controller.onResumed();
    await tester.pumpAndSettle();

    expect(auth.authCalls, 2);
    expect(find.text('Sensitive invoices'), findsOneWidget);
  });

  testWidgets('unavailable hardware offers graceful entry, never a lockout', (
    tester,
  ) async {
    final auth = FakeDeviceAuth(available: false);
    await pumpLockedGate(tester, auth: auth);

    // The auto-attempt found no authenticator: it never prompted, the app is
    // still gated, and the screen explains + offers a way in.
    expect(auth.authCalls, 0);
    expect(find.text('Sensitive invoices'), findsNothing);
    expect(find.byKey(const Key('enter-anyway-button')), findsOneWidget);
    expect(find.textContaining('encrypted'), findsOneWidget);

    await tester.tap(find.byKey(const Key('enter-anyway-button')));
    await tester.pumpAndSettle();

    expect(find.text('Sensitive invoices'), findsOneWidget);
  });
}
