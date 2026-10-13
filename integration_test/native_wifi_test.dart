import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:wifi_analyser/models/wifi_guidance.dart';
import 'package:wifi_analyser/viewmodels/wifi_guidance_view_model.dart';
import 'package:wifi_analyser/views/wifi_guidance_sheet.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wifi_analyser/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wifi_analyser/viewmodels/analyser_view_model.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Android scan bridge returns real platform state', (
    tester,
  ) async {
    const native = MethodChannel('com.samirpandey.wifi_analyser/wifi');
    final snapshot = await native.invokeMapMethod<String, dynamic>('snapshot');
    expect(snapshot, isNotNull);
    expect(snapshot!['permission'], isA<bool>());
    expect(snapshot['wifiEnabled'], isA<bool>());
    expect(snapshot['locationEnabled'], isA<bool>());
    expect(snapshot['accessPoints'], isA<List>());

    await (await SharedPreferences.getInstance()).setBool(
      'onboardingComplete',
      true,
    );
    await tester.pumpWidget(const ProviderScope(child: WaveApp()));
    await tester.pumpAndSettle();
    expect(find.text('Know your WiFi.'), findsOneWidget);
    expect(find.text('SIMULATED CONNECTION'), findsNothing);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(WaveApp)),
    );
    await container
        .read(analyserProvider.notifier)
        .scan(requestPermission: false);
    await tester.pump(const Duration(seconds: 2));
    expect(container.read(analyserProvider).demo, isFalse);
    expect(container.read(analyserProvider).status, isNotEmpty);
    await tester.ensureVisible(find.text('Improve my WiFi'));
    await tester.tap(find.text('Improve my WiFi'));
    await tester.pumpAndSettle();
    expect(find.byType(WifiGuidanceSheet), findsOneWidget);
    for (final problem in WifiProblem.values) {
      final label = problem == WifiProblem.weakSignal
          ? 'Weak signal'
          : 'Crowded channel';
      await tester.ensureVisible(find.text(label));
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      final guide = container.read(wifiGuidanceProvider);
      expect(guide.problem, problem);
      expect(guide.current, isNull);
      if (container.read(analyserProvider).cached) {
        expect(guide.baseline, isNull);
        expect(guide.message, isNotNull);
      }
    }
    await tester.ensureVisible(find.byTooltip('Close troubleshooting'));
    await tester.tap(find.byTooltip('Close troubleshooting'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
