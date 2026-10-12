import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../viewmodels/onboarding_view_model.dart';
import 'analyser_home.dart';
import 'onboarding_page.dart';

class OnboardingGate extends ConsumerWidget {
  const OnboardingGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingProvider);
    if (state.loading) {
      return const Scaffold(
        body: Center(
          child: Text(
            'wave',
            style: TextStyle(fontSize: 36, fontWeight: FontWeight.w800),
          ),
        ),
      );
    }
    if (state.completed) return const AnalyserHome();
    return OnboardingPage(
      saving: state.saving,
      error: state.error,
      onFinished: ref.read(onboardingProvider.notifier).complete,
    );
  }
}
