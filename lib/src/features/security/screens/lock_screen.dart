import 'package:core_theme/core_theme.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledgerly/src/features/security/providers/lock_providers.dart';

/// Full-screen gate shown while the app lock is engaged. The device prompt
/// is triggered automatically on entry; the button retries after a failure.
final class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

final class _LockScreenState extends ConsumerState<LockScreen> {
  bool _busy = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    // Auto-trigger the prompt as soon as the lock screen appears.
    WidgetsBinding.instance.addPostFrameCallback((_) => _attempt());
  }

  Future<void> _attempt() async {
    if (_busy || !mounted) return;
    setState(() {
      _busy = true;
      _failed = false;
    });
    final ok = await ref.read(lockControllerProvider).unlock();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _failed = !ok;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.colorScheme.primaryContainer,
                    ),
                    child: Icon(
                      Icons.receipt_long,
                      size: 36,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const Text('Ledgerly', style: AppTextStyles.h1),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Locked to keep your invoices private.',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  VaultButton(
                    key: const Key('unlock-button'),
                    label: 'Unlock Ledgerly',
                    isLoading: _busy,
                    onPressed: _attempt,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    height: 40,
                    child: _failed
                        ? Text(
                            "We couldn't verify it's you. "
                            'Try again whenever you\'re ready.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall!.copyWith(
                              color: theme.colorScheme.error,
                            ),
                          )
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
