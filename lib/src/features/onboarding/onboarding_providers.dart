import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledgerly/src/core/providers.dart';

/// Whether the one-time intro has been shown. Persisted in secure storage
/// (not the vault) so it survives backup restores and vault resets.
final onboardingSeenProvider =
    AsyncNotifierProvider<OnboardingSeenNotifier, bool>(
      OnboardingSeenNotifier.new,
    );

final class OnboardingSeenNotifier extends AsyncNotifier<bool> {
  static const String storageKey = 'ledgerly_onboarding_seen';

  @override
  Future<bool> build() async {
    final value = await ref.watch(secureStorageProvider).read(key: storageKey);
    return value == 'true';
  }

  /// Marks the intro as seen (both "Get started" and "Skip" land here).
  Future<void> complete() async {
    state = const AsyncData(true);
    await ref.read(secureStorageProvider).write(key: storageKey, value: 'true');
  }
}
