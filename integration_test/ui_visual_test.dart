import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wifi_analyser/app.dart';
import 'package:wifi_analyser/viewmodels/analyser_view_model.dart';
import 'package:wifi_analyser/widgets/network_tile.dart';
import 'package:wifi_analyser/widgets/signal_charts.dart';

/// Real Android rendering/IME with explicit demo data and in-memory preferences.
/// Does not request RF permissions or overwrite existing device preferences.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('Android UI ${mode.name} at ${scale}x text', (tester) async {
        SharedPreferences.setMockInitialValues({
          'onboardingComplete': true,
          'theme': mode.index,
        });
        await tester.pumpWidget(
          ProviderScope(
            overrides: [demoModeDefaultProvider.overrideWithValue(true)],
            child: MediaQuery.fromView(
              view: tester.view,
              child: Builder(
                builder: (context) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(scale),
                    disableAnimations: true,
                  ),
                  child: const WaveApp(),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await binding.convertFlutterSurfaceToImage();
        await tester.pumpAndSettle();
        final prefix = '${mode.name}-${scale}x';
        Future<void> capture(String name) async {
          expect(tester.takeException(), isNull);
          await binding.takeScreenshot('$prefix-$name');
        }

        Future<void> page(IconData icon) async {
          await tester.tap(
            find.descendant(
              of: find.byType(NavigationBar),
              matching: find.byIcon(icon),
            ),
          );
          await tester.pumpAndSettle();
        }

        expect(find.text('SIMULATED CONNECTION'), findsOneWidget);
        expect(
          MediaQuery.textScalerOf(tester.element(find.byType(NavigationBar)))
              .scale(14),
          14 * scale,
        );
        await capture('overview');
        await page(Icons.stacked_line_chart_rounded);
        await tester.ensureVisible(find.byType(SignalChart));
        await tester.pumpAndSettle();
        await capture('spectrum');
        await page(Icons.wifi_rounded);
        await tester.ensureVisible(find.byType(NetworkTile).first);
        await tester.pumpAndSettle();
        await capture('networks');
        await tester.tap(find.byType(NetworkTile).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Add local alias'));
        await tester.pumpAndSettle();
        final aliasField = find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        );
        await tester.showKeyboard(aliasField);
        await tester.pump(const Duration(seconds: 1));
        expect(aliasField.hitTestable(), findsOneWidget);
        expect(find.text('Name on this device'), findsOneWidget);
        final keyboard =
            tester.view.viewInsets.bottom / tester.view.devicePixelRatio;
        expect(
          keyboard,
          greaterThan(0),
          reason: 'Native Android keyboard must be visible for this check.',
        );
        binding.reportData ??= {};
        binding.reportData!['$prefix-keyboard-inset'] = keyboard;
        await capture('alias-keyboard');
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Close access point details'));
        await tester.pumpAndSettle();
        await page(Icons.tune_rounded);
        await tester.ensureVisible(find.text('Change assumptions'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Change assumptions'));
        await tester.pumpAndSettle();
        expect(find.text('Primary channels'), findsOneWidget);
        await capture('channel-dialog');
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        await page(Icons.settings_outlined);
        await capture('settings');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}
