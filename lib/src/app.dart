import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledgerly/src/core/router.dart';
import 'package:ledgerly/src/features/onboarding/onboarding_screen.dart';
import 'package:ledgerly/src/features/security/widgets/lock_gate.dart';

final class LedgerlyApp extends ConsumerWidget {
  const LedgerlyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Ledgerly',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(Brightness.light, accent: AppColors.indigoAccent),
      darkTheme: AppTheme.build(
        Brightness.dark,
        accent: AppColors.indigoAccent,
      ),
      themeMode: ThemeMode.system,
      // The app lock sits above the router so no route can render while
      // the gate is engaged (and navigation state survives a re-lock);
      // the one-time onboarding intro sits just inside it.
      builder: (context, child) =>
          LockGate(child: OnboardingGate(child: child)),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
