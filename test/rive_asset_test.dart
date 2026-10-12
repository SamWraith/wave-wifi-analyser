import 'dart:ui' as ui;

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
              final rendered = <List<int>>[];
              for (final time in [0.0, .5, 1.0]) {
                animation.time = time;
                animation.advanceAndApply(0);
                artboard.advance(0);
                final recorder = ui.PictureRecorder();
                final renderer = rive.Renderer.make(ui.Canvas(recorder));
                final painter = rive.BasicArtboardPainter()
                  ..artboardChanged(artboard);
                painter.paint(renderer, const ui.Size(480, 400), 1);
                renderer.dispose();
                painter.dispose();
                final picture = recorder.endRecording();
                final image = await picture.toImage(480, 400);
                final pixels = await image.toByteData(
                  format: ui.ImageByteFormat.rawRgba,
                );
                rendered.add(pixels!.buffer.asUint8List());
                image.dispose();
                picture.dispose();
              }
              expect(
                rendered[0],
                isNot(equals(rendered[1])),
                reason: '${step.artboard} must visibly animate',
              );
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
