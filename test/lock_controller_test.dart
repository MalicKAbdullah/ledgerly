import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerly/src/features/security/services/lock_controller.dart';

import 'helpers/fakes.dart';

void main() {
  late FakeDeviceAuth auth;
  late FakeClock clock;

  LockController makeController() => LockController(auth: auth, clock: clock);

  setUp(() {
    auth = FakeDeviceAuth();
    clock = FakeClock();
  });

  group('cold start', () {
    test('starts pending before the persisted flag is known', () {
      expect(makeController().status, LockStatus.pending);
    });

    test('restore(enabled: true) locks', () {
      final controller = makeController()..restore(enabled: true);
      expect(controller.status, LockStatus.locked);
      expect(controller.isEnabled, isTrue);
    });

    test('restore(enabled: false) unlocks without any prompt', () {
      final controller = makeController()..restore(enabled: false);
      expect(controller.status, LockStatus.unlocked);
      expect(auth.authCalls, 0);
    });
  });

  group('unlock', () {
    test('successful auth unlocks and passes the reason', () async {
      final controller = makeController()..restore(enabled: true);
      expect(await controller.unlock(), UnlockOutcome.unlocked);
      expect(controller.status, LockStatus.unlocked);
      expect(auth.lastReason, 'Unlock Ledgerly');
    });

    test('failed auth stays locked', () async {
      auth.authResult = false;
      final controller = makeController()..restore(enabled: true);
      expect(await controller.unlock(), UnlockOutcome.failed);
      expect(controller.status, LockStatus.locked);
    });

    test('unlock when already unlocked is a no-prompt no-op', () async {
      final controller = makeController()..restore(enabled: false);
      expect(await controller.unlock(), UnlockOutcome.unlocked);
      expect(auth.authCalls, 0);
    });

    test('no usable authenticator reports unavailable, never prompts', () async {
      auth.available = false;
      final controller = makeController()..restore(enabled: true);
      expect(await controller.unlock(), UnlockOutcome.unavailable);
      expect(auth.authCalls, 0);
      expect(controller.status, LockStatus.locked);
    });

    test('enterWithoutAuth opens the gate from locked', () {
      final controller = makeController()..restore(enabled: true);
      controller.enterWithoutAuth();
      expect(controller.status, LockStatus.unlocked);
    });

    test('enterWithoutAuth is a no-op when not locked', () {
      final controller = makeController()..restore(enabled: false);
      controller.enterWithoutAuth();
      expect(controller.status, LockStatus.unlocked);
    });

    test('re-entrant unlock while a prompt is showing is rejected', () async {
      final gate = Completer<bool>();
      auth.onAuthenticate = () => gate.future;
      final controller = makeController()..restore(enabled: true);

      final first = controller.unlock();
      final second = await controller.unlock();
      expect(second, UnlockOutcome.failed);

      gate.complete(true);
      expect(await first, UnlockOutcome.unlocked);
      expect(controller.status, LockStatus.unlocked);
      expect(auth.authCalls, 1);
    });

    test('notifies listeners on state changes only', () async {
      final controller = makeController();
      var notifications = 0;
      controller.addListener(() => notifications++);

      controller.restore(enabled: true); // pending -> locked
      await controller.unlock(); // locked -> unlocked
      await controller.unlock(); // no-op
      expect(notifications, 2);
    });
  });

  group('background re-lock window', () {
    test('away for more than 30s locks on resume', () async {
      final controller = makeController()..restore(enabled: true);
      await controller.unlock();

      controller.onBackgrounded();
      clock.advance(const Duration(seconds: 31));
      controller.onResumed();
      expect(controller.status, LockStatus.locked);
    });

    test('a quick hop (30s or less) stays unlocked', () async {
      final controller = makeController()..restore(enabled: true);
      await controller.unlock();

      controller.onBackgrounded();
      clock.advance(const Duration(seconds: 30));
      controller.onResumed();
      expect(controller.status, LockStatus.unlocked);
    });

    test('repeated background events keep the earliest timestamp', () async {
      final controller = makeController()..restore(enabled: true);
      await controller.unlock();

      controller.onBackgrounded();
      clock.advance(const Duration(seconds: 20));
      controller.onBackgrounded(); // hidden then paused, etc.
      clock.advance(const Duration(seconds: 15));
      controller.onResumed(); // 35s total > 30s
      expect(controller.status, LockStatus.locked);
    });

    test('the window resets after each resume', () async {
      final controller = makeController()..restore(enabled: true);
      await controller.unlock();

      controller.onBackgrounded();
      clock.advance(const Duration(seconds: 20));
      controller.onResumed();
      controller.onBackgrounded();
      clock.advance(const Duration(seconds: 20));
      controller.onResumed();
      expect(controller.status, LockStatus.unlocked);
    });

    test('resume without a background event never locks', () async {
      final controller = makeController()..restore(enabled: true);
      await controller.unlock();
      clock.advance(const Duration(hours: 1));
      controller.onResumed();
      expect(controller.status, LockStatus.unlocked);
    });

    test('does nothing when the lock is disabled', () {
      final controller = makeController()..restore(enabled: false);
      controller.onBackgrounded();
      clock.advance(const Duration(minutes: 5));
      controller.onResumed();
      expect(controller.status, LockStatus.unlocked);
    });

    test('backgrounding while already locked stays locked', () {
      final controller = makeController()..restore(enabled: true);
      controller.onBackgrounded();
      clock.advance(const Duration(minutes: 5));
      controller.onResumed();
      expect(controller.status, LockStatus.locked);
    });
  });

  group('settings toggle', () {
    test('enabling mid-session does not lock the current session', () {
      final controller = makeController()..restore(enabled: false);
      controller.setEnabled(true);
      expect(controller.status, LockStatus.unlocked);
      expect(controller.isEnabled, isTrue);
    });

    test('enabling mid-session arms the background re-lock', () {
      final controller = makeController()..restore(enabled: false);
      controller.setEnabled(true);
      controller.onBackgrounded();
      clock.advance(const Duration(seconds: 31));
      controller.onResumed();
      expect(controller.status, LockStatus.locked);
    });

    test('disabling clears an active lock', () {
      final controller = makeController()..restore(enabled: true);
      expect(controller.status, LockStatus.locked);
      controller.setEnabled(false);
      expect(controller.status, LockStatus.unlocked);
      expect(controller.isEnabled, isFalse);
    });
  });
}
