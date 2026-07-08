import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledgerly/src/features/security/providers/lock_providers.dart';
import 'package:ledgerly/src/features/security/screens/lock_screen.dart';
import 'package:ledgerly/src/features/security/services/lock_controller.dart';

/// Sits above the router (via MaterialApp.builder) and covers the whole app
/// with [LockScreen] while the lock is engaged. The routed subtree stays in
/// the tree (offstage) so navigation state survives a re-lock.
///
/// Also forwards lifecycle events to the [LockController]: leaving the
/// foreground starts the 30-second re-lock window, resuming checks it.
final class LockGate extends ConsumerStatefulWidget {
  const LockGate({required this.child, super.key});

  final Widget? child;

  @override
  ConsumerState<LockGate> createState() => _LockGateState();
}

final class _LockGateState extends ConsumerState<LockGate>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = ref.read(lockControllerProvider);
    switch (state) {
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        controller.onBackgrounded();
      case AppLifecycleState.resumed:
        controller.onResumed();
      case AppLifecycleState.inactive:
        break; // Transient (notification shade, biometric prompt, …).
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(lockControllerProvider).status;
    final unlocked = status == LockStatus.unlocked;

    return Stack(
      fit: StackFit.expand,
      children: [
        TickerMode(
          enabled: unlocked,
          child: Offstage(
            offstage: !unlocked,
            child: widget.child ?? const SizedBox.shrink(),
          ),
        ),
        // Blank cover while the persisted flag loads — never flash data.
        if (status == LockStatus.pending)
          const Scaffold(body: SizedBox.expand()),
        if (status == LockStatus.locked) const LockScreen(),
      ],
    );
  }
}
