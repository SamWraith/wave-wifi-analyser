import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:rive/rive.dart' as rive;
import 'package:wifi_analyser/models/onboarding_step.dart';
import 'package:wifi_analyser/views/app_theme.dart';
import 'package:wifi_analyser/views/onboarding_page.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Rive scenes load, replay, rest, and honor reduced motion', (
    tester,
  ) async {
    var finished = false;
    Future<void> showWelcome({bool reduced = false}) => tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: buildAppTheme(Brightness.light),
          darkTheme: buildAppTheme(Brightness.dark),
          themeMode: ThemeMode.dark,
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: reduced),
            child: OnboardingPage(onFinished: () => finished = true),
          ),
        ),
      ),
    );

    await showWelcome();
    for (final step in onboardingSteps) {
      // Real native decoding runs outside Flutter's frame clock.
      final replay = find.widgetWithText(TextButton, step.action);
      for (var attempt = 0; attempt < 100; attempt++) {
        await tester.pump(const Duration(milliseconds: 50));
        if (replay.evaluate().isNotEmpty &&
            tester.widget<TextButton>(replay).onPressed != null) {
          break;
        }
      }
      expect(find.byType(rive.RiveArtboardWidget), findsOneWidget);
      expect(tester.widget<TextButton>(replay).onPressed, isNotNull);
      await tester.ensureVisible(replay);
      await tester.tap(replay);
      await tester.pump();
      await tester.pumpAndSettle();
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(tester.takeException(), isNull);

      final next = find.widgetWithText(
        FilledButton,
        step == onboardingSteps.last ? 'Start exploring' : 'Continue',
      );
      await tester.ensureVisible(next);
      await tester.tap(next);
      await tester.pump();
    }
    expect(finished, isTrue);

    await showWelcome(reduced: true);
    await tester.pumpAndSettle();
    final reducedButton = find.widgetWithText(TextButton, 'Motion reduced');
    expect(tester.widget<TextButton>(reducedButton).onPressed, isNull);
    expect(find.byType(rive.RiveArtboardWidget), findsOneWidget);
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });
}
