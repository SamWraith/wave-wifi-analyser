import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wifi_analyser/models/access_point.dart';
import 'package:wifi_analyser/models/analyser_state.dart';
import 'package:wifi_analyser/repositories/settings_repository.dart';
import 'package:wifi_analyser/repositories/wifi_repository.dart';
import 'package:wifi_analyser/viewmodels/analyser_view_model.dart';

class FakeWifiRepository implements WifiRepository {
  final events = StreamController<WifiSnapshot>.broadcast(sync: true);
  Completer<WifiSnapshot>? scanReply;
  @override
  bool get supported => true;
  @override
  Stream<WifiSnapshot> get scanResults => events.stream;
  @override
  Future<WifiSnapshot> snapshot() async => sample(false, 100);
  @override
  Future<WifiSnapshot> scan() async =>
      scanReply == null ? sample(false, 100) : await scanReply!.future;
  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<void> openSettings() async {}
}

class FakeSettings implements SettingsRepository {
  ThemeMode theme = ThemeMode.system;
  int minimum = -95;
  @override
  Future<AnalyserPreferences> load() async =>
      AnalyserPreferences(theme, minimum);
  @override
  Future<void> saveTheme(ThemeMode mode) async {
    theme = mode;
  }

  @override
  Future<void> saveMinimum(int value) async {
    minimum = value;
  }
}

WifiSnapshot sample(bool fresh, int timestamp) => WifiSnapshot(
  permission: true,
  locationEnabled: true,
  wifiEnabled: true,
  status: 'Ready',
  fresh: fresh,
  accessPoints: [
    AccessPoint(
      ssid: 'Test AP',
      bssid: '00:11:22:33:44:55',
      rssi: -55,
      frequency: 2412,
      timestamp: timestamp,
    ),
  ],
);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeWifiRepository wifi;
  late FakeSettings settings;
  late ProviderContainer container;
  setUp(() {
    wifi = FakeWifiRepository();
    settings = FakeSettings();
    container = ProviderContainer(
      overrides: [
        wifiRepositoryProvider.overrideWithValue(wifi),
        settingsRepositoryProvider.overrideWithValue(settings),
        demoModeDefaultProvider.overrideWithValue(false),
      ],
    );
  });
  tearDown(() async {
    container.dispose();
    await wifi.events.close();
  });
  test('cached/duplicate timestamps never become fresh history; state stays immutable', () async {
    final vm = container.read(analyserProvider.notifier);
    await vm.ready;
    expect(container.read(analyserProvider).accessPoints.length, 1);
    expect(container.read(analyserProvider).history, isEmpty);
    wifi.events.add(sample(true, 100));
    final first = container.read(analyserProvider);
    expect(first.history.values.single.length, 1);
    wifi.events.add(sample(true, 100));
    expect(container.read(analyserProvider).history.values.single.length, 1);
    wifi.events.add(sample(false, 200));
    expect(container.read(analyserProvider).history.values.single.length, 1);
    wifi.events.add(sample(true, 200));
    expect(container.read(analyserProvider).history.values.single.length, 2);
    expect(first.history.values.single.length, 1);
    expect(() => first.history.values.single.clear(), throwsUnsupportedError);
    vm.togglePause();
    wifi.events.add(sample(true, 300));
    expect(container.read(analyserProvider).history.values.single.length, 2);
  });
  test('switching to demo ignores an in-flight native scan response', () async {
    final vm = container.read(analyserProvider.notifier);
    await vm.ready;
    wifi.scanReply = Completer<WifiSnapshot>();
    final pending = vm.scan();
    await vm.setDemo(true);
    wifi.scanReply!.complete(sample(true, 500));
    await pending;
    final state = container.read(analyserProvider);
    expect(state.demo, isTrue);
    expect(state.accessPoints.first.ssid, 'Studio Network');
    expect(state.status, contains('Simulated'));
  });
  test(
    'theme and signal threshold persist through settings repository',
    () async {
      final vm = container.read(analyserProvider.notifier);
      await vm.ready;
      await vm.setTheme(ThemeMode.dark);
      await vm.setMinimum(-70);
      expect(settings.theme, ThemeMode.dark);
      expect(settings.minimum, -70);
      expect(container.read(analyserProvider).themeMode, ThemeMode.dark);
    },
  );
}
