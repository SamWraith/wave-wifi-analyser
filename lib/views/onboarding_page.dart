import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/onboarding_step.dart';
import '../widgets/onboarding_illustration.dart';
import '../widgets/wave_motion.dart';
import '../widgets/wave_haptics.dart';
import '../widgets/stable_text_slot.dart';

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({
    super.key,
    required this.onFinished,
    this.saving = false,
    this.error,
  });
  final VoidCallback onFinished;
  final bool saving;
  final String? error;

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  int _index = 0;
  final _scroll = ScrollController();

  void _moveTo(int index) {
    WaveHaptics.selection();
    setState(() => _index = index);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _next() {
    if (_index == onboardingSteps.length - 1) {
      WaveHaptics.selection();
      widget.onFinished();
    } else {
      _moveTo(_index + 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final step = onboardingSteps[_index];
    final art = ref.watch(onboardingArtProvider)(step);
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, bounds) {
            final wide = bounds.maxWidth >= 850;
            return SingleChildScrollView(
              controller: _scroll,
              padding: EdgeInsets.symmetric(
                horizontal: wide ? 56 : 24,
                vertical: 20,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _WelcomeHeader(
                        onSkip: widget.saving
                            ? null
                            : () {
                                WaveHaptics.selection();
                                widget.onFinished();
                              },
                      ),
                      SizedBox(height: wide ? 70 : 22),
                      if (wide)
                        Row(
                          children: [
                            Expanded(child: art),
                            const SizedBox(width: 64),
                            Expanded(
                              child: _WelcomeCopy(step: step, index: _index),
                            ),
                          ],
                        )
                      else ...[
                        art,
                        const SizedBox(height: 24),
                        _WelcomeCopy(step: step, index: _index),
                      ],
                      const SizedBox(height: 30),
                      if (widget.error != null) ...[
                        Text(
                          widget.error!,
                          semanticsLabel: widget.error,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      _WelcomeControls(
                        index: _index,
                        saving: widget.saving,
                        onBack: () => _moveTo(_index - 1),
                        onNext: _next,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'WIFI, MADE VISIBLE.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          letterSpacing: 2,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _WelcomeHeader extends StatelessWidget {
  const _WelcomeHeader({required this.onSkip});
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Row(
          children: [
            Icon(
              Icons.wifi_rounded,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 10),
            const Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  'wave',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      TextButton(onPressed: onSkip, child: const Text('Skip')),
    ],
  );
}

class _WelcomeCopy extends StatelessWidget {
  const _WelcomeCopy({required this.step, required this.index});
  final OnboardingStep step;
  final int index;

  @override
  Widget build(BuildContext context) => WaveReveal(
    key: ValueKey(index),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StableTextSlot(
          text: step.eyebrow,
          alternatives: onboardingSteps.map((step) => step.eyebrow),
          style: TextStyle(
            fontSize: 11,
            letterSpacing: 1.8,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 16),
        StableTextSlot(
          text: step.title,
          alternatives: onboardingSteps.map((step) => step.title),
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
            fontSize: 40,
            fontWeight: FontWeight.w700,
            height: 1.1,
            letterSpacing: -1.5,
          ),
        ),
        const SizedBox(height: 18),
        StableTextSlot(
          text: step.body,
          alternatives: onboardingSteps.map((step) => step.body),
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            height: 1.6,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
  );
}

class _WelcomeControls extends StatelessWidget {
  const _WelcomeControls({
    required this.index,
    required this.saving,
    required this.onBack,
    required this.onNext,
  });
  final int index;
  final bool saving;
  final VoidCallback onBack, onNext;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Semantics(
        label: 'Welcome step ${index + 1} of ${onboardingSteps.length}',
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            onboardingSteps.length,
            (i) => AnimatedContainer(
              duration: WaveMotion.duration(context, 180),
              width: i == index ? 24 : 7,
              height: 7,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: i == index
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 18),
      Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Row(
            children: [
              Visibility(
                visible: index > 0,
                maintainState: true,
                maintainAnimation: true,
                maintainSize: true,
                child: TextButton(
                  onPressed: saving ? null : onBack,
                  child: const Text('Back'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: saving ? null : onNext,
                  icon: Icon(
                    index == onboardingSteps.length - 1
                        ? Icons.wifi_find_rounded
                        : Icons.arrow_forward_rounded,
                    size: 18,
                  ),
                  label: StableTextSlot(
                    alternatives: const [
                      'Continue',
                      'Start exploring',
                      'Saving…',
                    ],
                    style: null,
                    text: saving
                        ? 'Saving…'
                        : index == onboardingSteps.length - 1
                        ? 'Start exploring'
                        : 'Continue',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}
