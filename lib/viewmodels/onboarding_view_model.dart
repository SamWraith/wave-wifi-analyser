import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/onboarding_repository.dart';

class OnboardingState {
  const OnboardingState({
    this.loading = false,
    this.completed = false,
    this.saving = false,
    this.error,
  });
  final bool loading, completed, saving;
  final String? error;
}

final onboardingProvider =
    NotifierProvider<OnboardingViewModel, OnboardingState>(
      OnboardingViewModel.new,
    );

class OnboardingViewModel extends Notifier<OnboardingState> {
  @override
  OnboardingState build() {
    unawaited(Future.microtask(_load));
    return const OnboardingState(loading: true);
  }

  Future<void> _load() async {
    if (!ref.mounted) return;
    try {
      final complete = await ref
          .read(onboardingRepositoryProvider)
          .isComplete();
      if (ref.mounted) state = OnboardingState(completed: complete);
    } catch (_) {
      if (ref.mounted) {
        state = const OnboardingState(
          error: 'Could not load welcome preferences. You can still continue.',
        );
      }
    }
  }

  Future<void> complete() async {
    if (state.loading || state.saving || state.completed) return;
    state = const OnboardingState(saving: true);
    try {
      await ref.read(onboardingRepositoryProvider).complete();
      if (ref.mounted) state = const OnboardingState(completed: true);
    } catch (_) {
      if (ref.mounted) {
        state = const OnboardingState(
          error: 'Could not save your choice. Tap again to retry.',
        );
      }
    }
  }
}
