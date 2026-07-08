import 'package:flutter/foundation.dart';
import 'package:ledgerly/src/core/clock.dart';
import 'package:ledgerly/src/core/security/device_auth.dart';

/// Where the app-lock gate currently stands.
enum LockStatus {
  /// The persisted flag hasn't been read yet — show nothing sensitive.
  pending,

  /// The lock is engaged; only a successful [LockController.unlock] clears it.
  locked,

  /// The app is open.
  unlocked,
}

/// Pure app-lock state machine. No platform channels, no storage — the
/// authenticator and clock are injected, so the whole matrix is unit-testable.
///
/// Rules:
/// - Cold start ([restore]) with the lock enabled → [LockStatus.locked].
/// - Backgrounded for more than [relockAfter] (default 30 s) → re-locks on
///   resume. Short hops (share sheet, quick app switch) stay unlocked.
/// - [unlock] delegates to [IDeviceAuth]; only success opens the gate.
/// - Enabling mid-session never locks the current session (the user just
///   authenticated to flip the toggle); disabling clears any active lock.
final class LockController extends ChangeNotifier {
  LockController({
    required IDeviceAuth auth,
    Clock clock = const SystemClock(),
    Duration relockAfter = const Duration(seconds: 30),
  }) : _auth = auth,
       _clock = clock,
       _relockAfter = relockAfter;

  final IDeviceAuth _auth;
  final Clock _clock;
  final Duration _relockAfter;

  LockStatus _status = LockStatus.pending;
  bool _enabled = false;
  bool _authInFlight = false;
  DateTime? _backgroundedAt;

  LockStatus get status => _status;
  bool get isEnabled => _enabled;

  /// Applies the persisted flag on cold start: enabled means locked.
  void restore({required bool enabled}) {
    _enabled = enabled;
    _set(enabled ? LockStatus.locked : LockStatus.unlocked);
  }

  /// Reflects the settings toggle. Turning the lock off also unlocks.
  void setEnabled(bool value) {
    _enabled = value;
    if (!value) _set(LockStatus.unlocked);
  }

  /// The app left the foreground. Keeps the earliest timestamp when the
  /// platform emits several background-ish events in a row.
  void onBackgrounded() {
    _backgroundedAt ??= _clock.now();
  }

  /// The app came back. Re-locks when it was away longer than the window.
  void onResumed() {
    final backgroundedAt = _backgroundedAt;
    _backgroundedAt = null;
    if (backgroundedAt == null) return;
    if (!_enabled || _status != LockStatus.unlocked) return;
    if (_clock.now().difference(backgroundedAt) > _relockAfter) {
      _set(LockStatus.locked);
    }
  }

  /// Runs the device prompt and opens the gate on success. Re-entrant calls
  /// while a prompt is already showing are rejected.
  Future<bool> unlock({String reason = 'Unlock Ledgerly'}) async {
    if (_status == LockStatus.unlocked) return true;
    if (_authInFlight) return false;
    _authInFlight = true;
    try {
      final ok = await _auth.authenticate(reason: reason);
      if (ok && _status == LockStatus.locked) _set(LockStatus.unlocked);
      return ok;
    } finally {
      _authInFlight = false;
    }
  }

  void _set(LockStatus next) {
    if (next == _status) return;
    _status = next;
    notifyListeners();
  }
}
