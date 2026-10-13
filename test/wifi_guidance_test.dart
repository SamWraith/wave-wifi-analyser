import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wifi_analyser/models/access_point.dart';
import 'package:wifi_analyser/models/analyser_state.dart';
import 'package:wifi_analyser/models/wifi_guidance.dart';
import 'package:wifi_analyser/repositories/settings_repository.dart';
import 'package:wifi_analyser/repositories/wifi_repository.dart';
import 'package:wifi_analyser/viewmodels/analyser_view_model.dart';
import 'package:wifi_analyser/viewmodels/wifi_guidance_view_model.dart';
import 'package:wifi_analyser/views/wifi_guidance_sheet.dart';

import 'controller_test.dart' show FakeWifiRepository, FakeSettings;

WifiSnapshot connectedScan(
  int timestamp, {
  int rssi = -78,
  String bssid = 'home',
  bool fresh = true,
}) => WifiSnapshot(
  permission: true,
  locationEnabled: true,
  wifiEnabled: true,
  status: fresh ? 'Scan complete' : 'Cached',
  fresh: fresh,
  accessPoints: [
    AccessPoint(
      ssid: 'Home',
      bssid: bssid,
      rssi: rssi,
      frequency: 2412,
      timestamp: timestamp,
      connected: true,
    ),
    AccessPoint(
      ssid: 'Neighbour',
      bssid: 'other',
      rssi: -50,
      frequency: 2412,
      timestamp: timestamp,
    ),
  ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeWifiRepository wifi;
  late ProviderContainer container;
  late ProviderSubscription<WifiGuidanceState> subscription;
  var age = Duration.zero;
  setUp(() {
    age = Duration.zero;
    wifi = FakeWifiRepository();
    container = ProviderContainer(
      overrides: [
        wifiRepositoryProvider.overrideWithValue(wifi),
        settingsRepositoryProvider.overrideWithValue(FakeSettings()),
        demoModeDefaultProvider.overrideWithValue(false),
        guidanceClockProvider.overrideWithValue(
          () => (container.read(analyserProvider).lastUpdated ?? DateTime.now())
              .add(age),
        ),
      ],
    );
    subscription = container.listen(wifiGuidanceProvider, (_, next) {});
  });
  tearDown(() async {
    subscription.close();
    container.dispose();
    await wifi.events.close();
  });

  test('recheck requires new same-BSSID observation, not cached/duplicate or prior fresh data', () async {
    await container.read(analyserProvider.notifier).ready;
    wifi.events.add(connectedScan(100));
    final vm = container.read(wifiGuidanceProvider.notifier);
    vm.choose(WifiProblem.weakSignal);
    expect(container.read(wifiGuidanceProvider).baseline!.ap.rssi, -78);
    wifi.events.add(connectedScan(200, rssi: -72));
    await vm.recheck();
    wifi.events.add(connectedScan(200, rssi: -72));
    expect(container.read(wifiGuidanceProvider).waiting, isTrue);
    wifi.events.add(connectedScan(300, rssi: -60, fresh: false));
    expect(container.read(wifiGuidanceProvider).current, isNull);
    wifi.events.add(connectedScan(300, rssi: -60));
    final guide = container.read(wifiGuidanceProvider);
    expect(guide.waiting, isFalse);
    expect(
      guidanceComparison(guide.problem!, guide.baseline!, guide.current!),
      contains('increased by 18 dB'),
    );
  });

  test(
    'demo, stale, empty and paused data cannot establish baseline',
    () async {
      final analyser = container.read(analyserProvider.notifier);
      await analyser.ready;
      final vm = container.read(wifiGuidanceProvider.notifier);
      vm.choose(WifiProblem.weakSignal);
      expect(container.read(wifiGuidanceProvider).baseline, isNull);
      wifi.events.add(connectedScan(100));
      age = const Duration(minutes: 2);
      vm.choose(WifiProblem.weakSignal);
      expect(container.read(wifiGuidanceProvider).message, contains('older'));
      age = Duration.zero;
      analyser.togglePause();
      vm.choose(WifiProblem.weakSignal);
      expect(container.read(wifiGuidanceProvider).message, contains('paused'));
      analyser.togglePause();
      await analyser.setDemo(true);
      vm.choose(WifiProblem.crowdedChannel);
      expect(container.read(wifiGuidanceProvider).baseline, isNull);
      expect(container.read(wifiGuidanceProvider).message, contains('Demo'));
    },
  );

  test('new AP invalidates comparison, and workspace switch clears pending baseline', () async {
    final analyser = container.read(analyserProvider.notifier);
    await analyser.ready;
    wifi.events.add(connectedScan(100));
    final vm = container.read(wifiGuidanceProvider.notifier);
    vm.choose(WifiProblem.weakSignal);
    await vm.recheck();
    wifi.events.add(connectedScan(200, bssid: 'roamed'));
    expect(container.read(wifiGuidanceProvider).baseline, isNull);
    expect(container.read(wifiGuidanceProvider).message, contains('changed'));
    vm.choose(WifiProblem.weakSignal);
    await vm.recheck();
    await analyser.setDemo(true);
    expect(container.read(wifiGuidanceProvider).waiting, isFalse);
    expect(container.read(wifiGuidanceProvider).baseline, isNull);
  });

  test('channel guidance uses connected band and full scan, independent of display filters', () async {
    final analyser = container.read(analyserProvider.notifier);
    await analyser.ready;
    wifi.events.add(connectedScan(100));
    analyser.setBand(WifiBand.ghz6);
    analyser.setQuery('hidden');
    analyser.updateMinimum(-40);
    final vm = container.read(wifiGuidanceProvider.notifier);
    vm.choose(WifiProblem.crowdedChannel);
    final evidence = container.read(wifiGuidanceProvider).baseline!;
    expect(evidence.ap.band, WifiBand.ghz24);
    expect(evidence.overlap, 10);
    expect(evidence.candidate, 6);
    await vm.recheck();
    wifi.events.add(
      WifiSnapshot(
        permission: true,
        locationEnabled: true,
        wifiEnabled: true,
        status: 'New',
        fresh: true,
        accessPoints: [
          const AccessPoint(
            ssid: 'Home',
            bssid: 'home',
            rssi: -70,
            frequency: 2437,
            timestamp: 200,
            connected: true,
          ),
        ],
      ),
    );
    final guide = container.read(wifiGuidanceProvider);
    expect(
      guidanceComparison(guide.problem!, guide.baseline!, guide.current!),
      contains('decreased'),
    );
  });

  for (final brightness in Brightness.values) {
    testWidgets(
      'guided sheet scrolls at large text in $brightness and closes cleanly',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: ThemeData(brightness: brightness),
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => showWifiGuidance(context),
                    child: const Text('Open guide'),
                  ),
                ),
              ),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(2)),
                child: child!,
              ),
            ),
          ),
        );
        await tester.runAsync(
          () => container.read(analyserProvider.notifier).ready,
        );
        wifi.events.add(connectedScan(100));
        await tester.tap(find.text('Open guide'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Weak signal'));
        await tester.tap(find.text('Weak signal'));
        await tester.pumpAndSettle();
        expect(find.text('-78 dBm • Weak signal'), findsOneWidget);
        await tester.ensureVisible(find.text('Recheck after change'));
        await tester.tap(find.text('Recheck after change'));
        await tester.pumpAndSettle();
        wifi.events.add(connectedScan(200, rssi: -60));
        await tester.pumpAndSettle();
        expect(
          find.text('Received signal increased by 18 dB in this recheck.'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.byTooltip('Close troubleshooting'));
        await tester.tap(find.byTooltip('Close troubleshooting'));
        await tester.pumpAndSettle();
        expect(find.byType(WifiGuidanceSheet), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
