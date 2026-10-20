import 'package:core_lock/core_lock.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledgerly/src/features/security/providers/lock_providers.dart';

/// Settings → Security: the shared app-lock section (fingerprint + app-set
/// password), identical across every Secure Suite app.
final class SecuritySection extends ConsumerWidget {
  const SecuritySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Security'),
        AppLockSettings(controller: ref.watch(lockControllerProvider)),
      ],
    );
  }
}
