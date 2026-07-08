import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerly/src/core/providers.dart';
import 'package:ledgerly/src/features/onboarding/onboarding_providers.dart';
import 'package:ledgerly/src/features/onboarding/onboarding_screen.dart';

import '../helpers/fakes.dart';

Widget app(FakeSecureStorage storage) {
  return ProviderScope(
    overrides: [secureStorageProvider.overrideWithValue(storage)],
    child: const MaterialApp(
      home: OnboardingGate(child: Scaffold(body: Text('MAIN APP'))),
    ),
  );
}

void main() {
  testWidgets('first launch shows all three pages, Get started completes', (
    tester,
  ) async {
    final storage = FakeSecureStorage();
    await tester.pumpWidget(app(storage));
    await tester.pumpAndSettle();

    expect(find.text('MAIN APP'), findsNothing);
    expect(find.text('Invoices that look professional'), findsOneWidget);

    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pumpAndSettle();
    expect(
      find.text('Your business data stays on this device'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pumpAndSettle();
    expect(find.text('Get paid'), findsOneWidget);
    expect(find.text('Get started'), findsOneWidget);

    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pumpAndSettle();

    expect(find.text('MAIN APP'), findsOneWidget);
    expect(storage.store[OnboardingSeenNotifier.storageKey], 'true');
  });

  testWidgets('skip jumps straight into the app and persists the flag', (
    tester,
  ) async {
    final storage = FakeSecureStorage();
    await tester.pumpWidget(app(storage));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('onboarding-skip')));
    await tester.pumpAndSettle();

    expect(find.text('MAIN APP'), findsOneWidget);
    expect(storage.store[OnboardingSeenNotifier.storageKey], 'true');
  });

  testWidgets('returning users never see the intro again', (tester) async {
    final storage = FakeSecureStorage();
    storage.store[OnboardingSeenNotifier.storageKey] = 'true';

    await tester.pumpWidget(app(storage));
    await tester.pumpAndSettle();

    expect(find.text('MAIN APP'), findsOneWidget);
    expect(find.text('Invoices that look professional'), findsNothing);
  });
}
