import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wifi_analyser/models/analyser_state.dart';
import 'package:wifi_analyser/viewmodels/analyser_view_model.dart';
import 'package:wifi_analyser/views/analyser_navigation.dart';
import 'package:wifi_analyser/views/onboarding_page.dart';
import 'package:wifi_analyser/views/app_theme.dart';
import 'package:wifi_analyser/widgets/onboarding_illustration.dart';

class _StatusViewModel extends AnalyserViewModel {
  @override
  AnalyserState build() => AnalyserState(demo: true);
  void message(String value) => state = state.copyWith(status: value);
}

void main() {
  for (final scale in [1.0, 1.5]) {
    testWidgets('welcome controls keep position across steps at scale $scale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 2200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            onboardingArtProvider.overrideWithValue(
              (step) => const AspectRatio(aspectRatio: 1.2, child: SizedBox()),
            ),
          ],
          child: MaterialApp(
            theme: buildAppTheme(Brightness.light),
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: OnboardingPage(onFinished: () {}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final button = find.byType(FilledButton);
      final initial = tester.getRect(button);
      for (var step = 1; step < 3; step++) {
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(
          find.text(
            step == 1 ? 'Less overlap.\nMore clarity.' : 'Ready when\nyou are.',
          ),
          findsOneWidget,
        );
        expect(tester.getRect(button), initial);
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  testWidgets(
    'home scan status does not move following content for normal messages',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final model = _StatusViewModel();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [analyserProvider.overrideWith(() => model)],
          child: MaterialApp(
            theme: buildAppTheme(Brightness.light),
            home: const Scaffold(
              body: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  children: [ScanStatusBar(), Text('Next section')],
                ),
              ),
            ),
          ),
        ),
      );
      final position = tester.getTopLeft(find.text('Next section'));
      for (final message in [
        'Scanning… Cached results shown until new scan arrives.',
        'Allow precise location to discover nearby WiFi networks.',
        'Scan complete',
        'Enable Location services in Android settings to scan WiFi.',
      ]) {
        model.message(message);
        await tester.pumpAndSettle();
        expect(tester.getTopLeft(find.text('Next section')), position);
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
