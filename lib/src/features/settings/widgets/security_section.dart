import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledgerly/src/features/security/providers/lock_providers.dart';

/// Settings → Security: the optional app-lock toggle. Enabling requires one
/// successful device authentication; when the device has no biometrics or
/// screen lock the switch is disabled with an explanation.
final class SecuritySection extends ConsumerWidget {
  const SecuritySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final available =
        ref.watch(deviceAuthAvailableProvider).valueOrNull ?? false;
    final enabled = ref.watch(appLockEnabledProvider).valueOrNull ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Security', style: theme.textTheme.titleLarge),
        const SizedBox(height: AppSpacing.sm),
        SwitchListTile(
          key: const Key('app-lock-toggle'),
          contentPadding: EdgeInsets.zero,
          title: Text('App lock', style: theme.textTheme.titleSmall),
          subtitle: Text(
            available
                ? 'Require fingerprint or face unlock to open Ledgerly.'
                : 'Not available — set up a screen lock or fingerprint on '
                      'this device first.',
            style: theme.textTheme.bodySmall,
          ),
          value: enabled && available,
          onChanged: available ? (value) => _toggle(context, ref, value) : null,
        ),
      ],
    );
  }

  Future<void> _toggle(BuildContext context, WidgetRef ref, bool value) async {
    final settings = ref.read(appLockSettingsProvider);
    var applied = value;
    if (value) {
      applied = await settings.enable();
      if (!applied && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("We couldn't verify it's you — app lock stays off."),
          ),
        );
      }
    } else {
      await settings.disable();
    }
    ref.read(lockControllerProvider).setEnabled(applied);
    ref.invalidate(appLockEnabledProvider);
  }
}
