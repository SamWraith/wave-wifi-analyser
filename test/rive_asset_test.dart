import 'package:flutter_test/flutter_test.dart';
import 'package:rive/rive.dart' as rive;
import 'package:wifi_analyser/models/onboarding_step.dart';

void main() {
  testWidgets(
    'bundled Rive artboards contain playable finite Explore timelines',
    (tester) async {
      await tester.runAsync(() async {
        await rive.RiveNative.init();
        final file = await rive.File.asset(
          'assets/rive/wave_onboarding.riv',
          riveFactory: rive.Factory.flutter,
        );
        expect(file, isNotNull);
        try {
          for (final step in onboardingSteps) {
            final artboard = file!.artboard(step.artboard);
            expect(artboard, isNotNull, reason: step.artboard);
            final animation = artboard!.animationNamed('Explore');
            expect(animation, isNotNull, reason: step.artboard);
            try {
              expect(animation!.duration, greaterThan(0));
              expect(animation.duration, lessThanOrEqualTo(2));
              for (final time in [0.0, .5, 1.0]) {
                animation.time = time;
                animation.apply();
                artboard.advance(0);
              }
            } finally {
              animation?.dispose();
              artboard.dispose();
            }
          }
        } finally {
          file?.dispose();
        }
      });
    },
  );
}
