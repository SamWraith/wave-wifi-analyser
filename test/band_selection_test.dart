import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wifi_analyser/models/access_point.dart';
import 'package:wifi_analyser/models/analyser_state.dart';
import 'package:wifi_analyser/models/wifi_data_source.dart';
import 'package:wifi_analyser/repositories/settings_repository.dart';
import 'package:wifi_analyser/repositories/wifi_repository.dart';
import 'package:wifi_analyser/viewmodels/analyser_view_model.dart';
import 'package:wifi_analyser/views/analyser_home.dart';
import 'package:wifi_analyser/views/analyser_providers.dart';
import 'package:wifi_analyser/views/app_theme.dart';
import 'package:wifi_analyser/widgets/channel_planning_controls.dart';
import 'package:wifi_analyser/widgets/network_tile.dart';
import 'package:wifi_analyser/widgets/signal_charts.dart';

import 'controller_test.dart' show FakeSettings, FakeWifiRepository;

WifiSnapshot connection(
  WifiDataSource source,
  int frequency, {
  bool identified = true,
}) => WifiSnapshot(
  source: source,
  permission: true,
  locationEnabled: true,
  wifiEnabled: true,
  status: 'Cached connection metadata',
  accessPoints: [
    const AccessPoint(
      ssid: 'Stronger neighbour',
      bssid: '00:11:22:33:44:01',
      rssi: -30,
      frequency: 2412,
    ),
    AccessPoint(
      ssid: 'Connected AP',
      bssid: '00:11:22:33:44:02',
      rssi: -70,
      frequency: frequency,
      connected: identified,
    ),
  ],
);

List<Override> overrides(
  FakeWifiRepository wifi,
  FakeSettings settings,
  WifiDataSource source,
) => [
  wifiRepositoryProvider.overrideWithValue(wifi),
  settingsRepositoryProvider.overrideWithValue(settings),
  liveWifiSourceProvider.overrideWithValue(source),
  demoModeDefaultProvider.overrideWithValue(false),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final source in [WifiDataSource.android, WifiDataSource.macos]) {
    for (final (frequency, band) in [
      (2412, WifiBand.ghz24),
      (5240, WifiBand.ghz5),
      (5975, WifiBand.ghz6),
    ]) {
      test(
        '${source.name} defaults to connected ${band.label} from initial snapshot',
        () async {
          final wifi = FakeWifiRepository()
            ..snapshotValue = connection(source, frequency);
          final container = ProviderContainer(
            overrides: overrides(wifi, FakeSettings(), source),
          );
          addTearDown(() async {
            container.dispose();
            await wifi.events.close();
          });
          await container.read(analyserProvider.notifier).ready;
          expect(container.read(analyserProvider).band, band);
          expect(
            container.read(bandPointsProvider).every((ap) => ap.band == band),
            isTrue,
          );
          expect(container.read(analyserProvider).history, isEmpty);
        },
      );
    }
  }

  test(
    'late connection metadata follows band changes until explicit selection',
    () async {
      final wifi = FakeWifiRepository()
        ..snapshotValue = connection(
          WifiDataSource.android,
          5975,
          identified: false,
        );
      final container = ProviderContainer(
        overrides: overrides(wifi, FakeSettings(), WifiDataSource.android),
      );
      addTearDown(() async {
        container.dispose();
        await wifi.events.close();
      });
      final vm = container.read(analyserProvider.notifier);
      await vm.ready;
      expect(container.read(analyserProvider).band, WifiBand.ghz24);
      wifi.events.add(connection(WifiDataSource.android, 5240));
      expect(container.read(analyserProvider).band, WifiBand.ghz5);
      wifi.events.add(connection(WifiDataSource.android, 5975));
      expect(container.read(analyserProvider).band, WifiBand.ghz6);
      wifi.events.add(
        connection(WifiDataSource.android, 2412, identified: false),
      );
      expect(container.read(analyserProvider).band, WifiBand.ghz6);
      vm.setBand(WifiBand.ghz5);
      wifi.events.add(connection(WifiDataSource.android, 2412));
      expect(container.read(analyserProvider).band, WifiBand.ghz5);
    },
  );

  test(
    'explicit default-band choice before hydration survives first connection',
    () async {
      final wifi = FakeWifiRepository()
        ..snapshotValue = connection(WifiDataSource.macos, 5240);
      final settings = FakeSettings()
        ..loadReply = Completer<AnalyserPreferences>();
      final container = ProviderContainer(
        overrides: overrides(wifi, settings, WifiDataSource.macos),
      );
      addTearDown(() async {
        container.dispose();
        await wifi.events.close();
      });
      final vm = container.read(analyserProvider.notifier);
      vm.setBand(WifiBand.ghz24);
      settings.loadReply!.complete(
        const AnalyserPreferences(ThemeMode.system, -95),
      );
      await vm.ready;
      expect(container.read(analyserProvider).band, WifiBand.ghz24);
    },
  );

  for (final (frequency, band) in [
    (2412, WifiBand.ghz24),
    (5240, WifiBand.ghz5),
    (5975, WifiBand.ghz6),
  ]) {
    testWidgets('all data tabs share connected ${band.label} default', (
      tester,
    ) async {
      final wifi = FakeWifiRepository()
        ..snapshotValue = connection(WifiDataSource.macos, frequency);
      addTearDown(() => wifi.events.close());
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides(wifi, FakeSettings(), WifiDataSource.macos),
          child: MaterialApp(
            theme: buildAppTheme(Brightness.light),
            home: const AnalyserHome(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final page in ['Overview', 'Spectrum', 'Networks', 'Channels']) {
        if (page != 'Overview') {
          await tester.tap(
            find.descendant(
              of: find.byType(NavigationBar),
              matching: find.text(page),
            ),
          );
          await tester.pumpAndSettle();
        }
        expect(
          tester
              .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, band.label))
              .selected,
          isTrue,
        );
        for (final chart in tester.widgetList<SignalChart>(
          find.byType(SignalChart),
        )) {
          expect(chart.band, band);
        }
        for (final tile in tester.widgetList<NetworkTile>(
          find.byType(NetworkTile),
        )) {
          expect(tile.ap.band, band);
        }
        for (final plan in tester.widgetList<ChannelPlanningControls>(
          find.byType(ChannelPlanningControls),
        )) {
          expect(plan.band, band);
        }
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
