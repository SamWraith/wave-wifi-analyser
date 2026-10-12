import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wifi_analyser/app.dart';
import 'package:wifi_analyser/widgets/signal_charts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wifi_analyser/viewmodels/analyser_view_model.dart';

void main() {
  for (final size in [const Size(390, 844), const Size(1440, 1000)]) {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('navigation and details at $size in $mode', (tester) async {
        SharedPreferences.setMockInitialValues({
          'theme': mode.index,
          'onboardingComplete': true,
        });
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [demoModeDefaultProvider.overrideWithValue(true)],
            child: const WaveApp(),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Know your WiFi.'), findsOneWidget);
        expect(find.text('SIMULATED CONNECTION'), findsOneWidget);
        expect(
          tester.getSize(find.byType(SignalChart)).width,
          greaterThan(220),
        );
        expect(tester.takeException(), isNull);
        if (size.width >= 950) {
          final mouse = await tester.createGesture(
            kind: PointerDeviceKind.mouse,
          );
          await mouse.addPointer(location: Offset.zero);
          await mouse.moveTo(tester.getCenter(find.text('Overview').first));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await mouse.removePointer();
        }
        await tester.tap(find.text('Networks').last);
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'Studio');
        await tester.pump();
        expect(find.text('Studio Network'), findsOneWidget);
        expect(find.text('Neighbourhood'), findsNothing);
        await tester.tap(find.text('Studio Network'));
        await tester.pumpAndSettle();
        expect(find.text('Copy MAC address'), findsOneWidget);
        expect(find.text('A4:83:E7:12:80:4C'), findsOneWidget);
        Navigator.of(tester.element(find.text('Copy MAC address'))).pop();
        await tester.pumpAndSettle();
        await tester.tap(find.text('Settings').last);
        await tester.pumpAndSettle();
        expect(find.text('Appearance'), findsOneWidget);
        await tester.tap(find.text('Networks').last);
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          'Studio',
        );
        expect(find.text('Neighbourhood'), findsNothing);
        await tester.enterText(find.byType(TextField), '');
        await tester.pump();
        expect(find.text('Neighbourhood'), findsOneWidget);
        await tester.tap(find.text('Settings').last);
        await tester.pumpAndSettle();
        expect(
          ProviderScope.containerOf(tester.element(find.byType(WaveApp)))
              .read(analyserProvider)
              .themeMode,
          mode,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}
