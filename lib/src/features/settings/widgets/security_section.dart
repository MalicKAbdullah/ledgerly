import 'package:core_lock/core_lock.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledgerly/src/features/security/providers/lock_providers.dart';

/// Settings → Security: the shared app-lock section (fingerprint + app-set
/// password), identical across every Secure Suite app.
final class SecuritySection extends ConsumerWidget {
  const SecuritySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Security', style: theme.textTheme.titleLarge),
        const SizedBox(height: AppSpacing.sm),
        AppLockSettings(controller: ref.watch(lockControllerProvider)),
      ],
    );
  }
}
