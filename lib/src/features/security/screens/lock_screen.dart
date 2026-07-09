import 'package:core_theme/core_theme.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledgerly/src/features/security/providers/lock_providers.dart';
import 'package:ledgerly/src/features/security/services/lock_controller.dart';

/// Full-screen gate shown while the app lock is engaged.
///
/// The biometric/passcode prompt auto-triggers exactly once as soon as the
/// screen appears (a fresh instance is mounted every time the app enters the
/// locked state — cold start, resume re-lock, inactivity re-lock — so the
/// post-frame callback fires on every entry). A latch ([_autoPrompted])
/// guards against a second prompt if the frame is rebuilt before the first
/// attempt resolves.
///
/// The fingerprint/face button is shown immediately and unconditionally — it
/// is never gated behind an async availability probe, so it can't flicker or
/// vanish. If auth fails the button stays for a retry. If the device has no
/// usable authenticator at all, the screen offers a graceful way in (Ledgerly
/// data is encrypted at rest) instead of a permanent lockout.
final class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

final class _LockScreenState extends ConsumerState<LockScreen> {
  bool _busy = false;
  bool _autoPrompted = false;
  UnlockOutcome? _outcome;

  @override
  void initState() {
    super.initState();
    // Auto-trigger the prompt once as soon as the lock screen appears.
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoPrompt());
  }

  void _autoPrompt() {
    if (_autoPrompted) return;
    _autoPrompted = true;
    _attempt();
  }

  Future<void> _attempt() async {
    if (_busy || !mounted) return;
    setState(() {
      _busy = true;
      _outcome = null;
    });
    final outcome = await ref.read(lockControllerProvider).unlock();
    if (!mounted) return;
    // On success the gate closes this screen; nothing else to do here.
    setState(() {
      _busy = false;
      _outcome = outcome;
    });
  }

  void _enterAnyway() {
    ref.read(lockControllerProvider).enterWithoutAuth();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unavailable = _outcome == UnlockOutcome.unavailable;
    final failed = _outcome == UnlockOutcome.failed;

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
                  // The biometric affordance itself — always present, tappable,
                  // and the primary way to re-trigger the prompt.
                  Semantics(
                    button: true,
                    label: 'Unlock with biometrics',
                    child: InkResponse(
                      key: const Key('biometric-button'),
                      onTap: _busy ? null : _attempt,
                      radius: 48,
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: theme.colorScheme.primaryContainer,
                        ),
                        child: Icon(
                          unavailable ? Icons.lock_outline : Icons.fingerprint,
                          size: 36,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const Text('Ledgerly', style: AppTextStyles.h1),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    unavailable
                        ? 'No fingerprint, face, or screen lock is set up on '
                              'this device.'
                        : 'Locked to keep your invoices private.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  if (unavailable)
                    VaultButton(
                      key: const Key('enter-anyway-button'),
                      label: 'Open Ledgerly',
                      onPressed: _enterAnyway,
                    )
                  else
                    VaultButton(
                      key: const Key('unlock-button'),
                      label: 'Unlock Ledgerly',
                      isLoading: _busy,
                      onPressed: _attempt,
                    ),
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    height: 48,
                    child: Text(
                      unavailable
                          ? 'Your data stays encrypted on this device either '
                                'way.'
                          : failed
                          ? "We couldn't verify it's you. "
                                'Try again whenever you\'re ready.'
                          : '',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall!.copyWith(
                        color: failed ? theme.colorScheme.error : null,
                      ),
                    ),
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
