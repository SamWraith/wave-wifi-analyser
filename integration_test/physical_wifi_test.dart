import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wifi_analyser/app.dart';
import 'package:wifi_analyser/models/wifi_guidance.dart';
import 'package:wifi_analyser/viewmodels/analyser_view_model.dart';
import 'package:wifi_analyser/viewmodels/wifi_guidance_view_model.dart';

/// Opt-in: needs a physical Android device connected to WiFi, with scan access.
/// Logs aggregate evidence only; never SSIDs or BSSIDs.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('physical RF freshness, pause and guided same-AP recheck', (
    tester,
  ) async {
    await (await SharedPreferences.getInstance()).setBool(
      'onboardingComplete',
      true,
    );
    await tester.pumpWidget(const ProviderScope(child: WaveApp()));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(WaveApp)),
    );
    final vm = container.read(analyserProvider.notifier);
    await vm.ready;
    if (!container.read(analyserProvider).permission) {
      debugPrint(
        'Physical test: waiting for Android precise-location permission prompt',
      );
      await vm.scan();
      await tester.pump(const Duration(seconds: 2));
    }
    final initial = container.read(analyserProvider);
    expect(initial.demo, isFalse);
    expect(
      initial.permission,
      isTrue,
      reason: 'Grant precise location in Android app permissions.',
    );
    expect(
      initial.locationEnabled,
      isTrue,
      reason: 'Enable Android Location services.',
    );
    expect(
      initial.wifiEnabled,
      isTrue,
      reason: 'Enable WiFi and connect to a network.',
    );

    if (initial.lastUpdated == null && !initial.busy) {
      await vm.scan(requestPermission: false);
    }
    for (var second = 0; second < 20; second++) {
      await tester.pump(const Duration(seconds: 1));
      final scan = container.read(analyserProvider);
      if (!scan.cached && scan.lastUpdated != null) break;
    }
    final fresh = container.read(analyserProvider);
    expect(
      fresh.cached,
      isFalse,
      reason:
          'Android did not deliver a fresh scan within 20 seconds: ${fresh.status}',
    );
    expect(fresh.lastUpdated, isNotNull);
    expect(fresh.accessPoints, isNotEmpty);
    expect(
      fresh.accessPoints.any((ap) => ap.connected),
      isTrue,
      reason: 'Connected AP must appear in physical scan results.',
    );
    final bands = fresh.accessPoints
        .map((ap) => ap.band.label)
        .toSet()
        .join(', ');
    debugPrint(
      'Physical scan: ${fresh.accessPoints.length} APs; bands: $bands; history APs: ${fresh.history.length}',
    );

    vm.togglePause();
    await tester.pump();
    final beforeAge = tester
        .widgetList<Text>(find.byType(Text))
        .map((text) => text.data)
        .whereType<String>()
        .firstWhere((text) => text.startsWith('Last fresh result'));
    await tester.pump(const Duration(seconds: 3));
    final paused = container.read(analyserProvider);
    expect(paused.lastUpdated, fresh.lastUpdated);
    expect(identical(paused.history, fresh.history), isTrue);
    final afterAge = tester
        .widgetList<Text>(find.byType(Text))
        .map((text) => text.data)
        .whereType<String>()
        .firstWhere((text) => text.startsWith('Last fresh result'));
    expect(afterAge, isNot(beforeAge));
    expect(paused.busy, isFalse);
    vm.togglePause();
    await tester.pump();

    await tester.ensureVisible(find.text('Improve my WiFi'));
    await tester.tap(find.text('Improve my WiFi'));
    await tester.pumpAndSettle();
    for (final problem in WifiProblem.values) {
      final label = problem == WifiProblem.weakSignal
          ? 'Weak signal'
          : 'Crowded channel';
      await tester.ensureVisible(find.text(label));
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(container.read(wifiGuidanceProvider).baseline, isNotNull);
    }
    final guide = container.read(wifiGuidanceProvider.notifier);
    guide.choose(WifiProblem.weakSignal);
    final baseline = container.read(wifiGuidanceProvider).baseline!;
    // Match foreground request policy; avoid rapid retries defeating throttle.
    vm.togglePause();
    await tester.pump(const Duration(seconds: 35));
    vm.togglePause();
    await tester.pump();
    await guide.recheck();
    for (var second = 0; second < 20; second++) {
      await tester.pump(const Duration(seconds: 1));
      if (container.read(wifiGuidanceProvider).current != null) break;
    }
    final comparison = container.read(wifiGuidanceProvider);
    expect(
      comparison.current,
      isNotNull,
      reason:
          'No comparable fresh result; ${comparison.message}; scan: ${container.read(analyserProvider).status}',
    );
    expect(comparison.current!.ap.bssid, baseline.ap.bssid);
    expect(
      comparison.current!.ap.timestamp,
      greaterThan(baseline.ap.timestamp),
    );
    expect(comparison.current!.at.isAfter(baseline.at), isTrue);
    final samples = container
        .read(analyserProvider)
        .history[baseline.ap.bssid]!;
    expect(samples.length, greaterThanOrEqualTo(2));
    debugPrint(
      'Physical recheck: same AP, newer native timestamp; ${samples.length} fresh samples; RSSI delta ${comparison.current!.ap.rssi - baseline.ap.rssi} dB',
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  }, skip: !const bool.fromEnvironment('WAVE_PHYSICAL_RF'));
}
