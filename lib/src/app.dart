import 'package:core_lock/core_lock.dart';
import 'package:core_theme/core_theme.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledgerly/src/core/providers.dart';
import 'package:ledgerly/src/core/router.dart';
import 'package:ledgerly/src/features/onboarding/onboarding_screen.dart';
import 'package:ledgerly/src/features/security/providers/lock_providers.dart';

final class LedgerlyApp extends ConsumerWidget {
  const LedgerlyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appearance = ref.watch(appearanceProvider);
    return ListenableBuilder(
      listenable: appearance,
      builder: (context, _) => MaterialApp.router(
        title: 'Ledgerly',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.build(Brightness.light, accent: AppAccents.ledgerly),
        darkTheme: AppTheme.build(Brightness.dark, accent: AppAccents.ledgerly),
        themeMode: appearance.mode,
        // The app lock sits above the router so no route can render while
        // the gate is engaged (and navigation state survives a re-lock);
        // the one-time onboarding intro sits just inside it.
        builder: (context, child) => AppLockGate(
          controller: ref.watch(lockControllerProvider),
          appMark: const SuiteAppIcon(app: SuiteApp.ledgerly, size: 64),
          child: OnboardingGate(child: child),
        ),
        routerConfig: ref.watch(routerProvider),
      ),
    );
  }
}
