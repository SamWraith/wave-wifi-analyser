import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  WifiSnapshot? snapshotValue;
  Object? scanError;
  bool permission = true;
  int scanCalls = 0;
  @override
  bool get supported => true;
  @override
  Stream<WifiSnapshot> get scanResults => events.stream;
  @override
  Future<WifiSnapshot> snapshot() async => snapshotValue ?? sample(false, 100);
  @override
  Future<WifiSnapshot> scan() async {
    scanCalls++;
    if (scanError != null) throw scanError!;
    return scanReply == null ? sample(false, 100) : await scanReply!.future;
  }

  @override
  Future<bool> requestPermission() async => permission;
  @override
  Future<void> openSettings() async {}
}

class FakeSettings implements SettingsRepository {
  ThemeMode theme = ThemeMode.system;
  int minimum = -95;
  Completer<AnalyserPreferences>? loadReply;
  Completer<void>? themeWriteReply;
  bool failTheme = false, failMinimum = false;
  @override
  Future<AnalyserPreferences> load() async => loadReply == null
      ? AnalyserPreferences(theme, minimum)
      : await loadReply!.future;
  @override
  Future<void> saveTheme(ThemeMode mode) async {
    if (themeWriteReply != null) await themeWriteReply!.future;
    if (failTheme) throw StateError('Storage unavailable');
    theme = mode;
  }

  @override
  Future<void> saveMinimum(int value) async {
    if (failMinimum) throw StateError('Storage unavailable');
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
  test(
    'delayed preference hydration preserves early theme and threshold edits',
    () async {
      settings.loadReply = Completer<AnalyserPreferences>();
      final vm = container.read(analyserProvider.notifier);
      await vm.setTheme(ThemeMode.dark);
      await vm.setMinimum(-65);
      settings.loadReply!.complete(
        const AnalyserPreferences(ThemeMode.light, -90),
      );
      await vm.ready;
      final state = container.read(analyserProvider);
      expect(state.themeMode, ThemeMode.dark);
      expect(state.minimumRssi, -65);
      expect(settings.theme, ThemeMode.dark);
      expect(settings.minimum, -65);
    },
  );
  test(
    'save failures are recoverable and retry clears only saved field error',
    () async {
      final vm = container.read(analyserProvider.notifier);
      await vm.ready;
      settings.failTheme = settings.failMinimum = true;
      await vm.setTheme(ThemeMode.dark);
      await vm.setMinimum(-70);
      expect(
        container.read(analyserProvider).preferencesError,
        contains('theme'),
      );
      expect(
        container.read(analyserProvider).preferencesError,
        contains('signal threshold'),
      );
      expect(container.read(analyserProvider).themeMode, ThemeMode.dark);
      settings.failTheme = false;
      await vm.setTheme(ThemeMode.dark);
      expect(
        container.read(analyserProvider).preferencesError,
        isNot(contains('theme')),
      );
      expect(
        container.read(analyserProvider).preferencesError,
        contains('signal threshold'),
      );
      settings.failMinimum = false;
      await vm.setMinimum(-70);
      expect(container.read(analyserProvider).preferencesError, isNull);
    },
  );
  test('older failed write cannot roll back newer selection', () async {
    final vm = container.read(analyserProvider.notifier);
    await vm.ready;
    settings.themeWriteReply = Completer<void>();
    final first = vm.setTheme(ThemeMode.dark);
    await Future<void>.delayed(Duration.zero);
    final latest = vm.setTheme(ThemeMode.light);
    settings.themeWriteReply!.completeError(StateError('Old write failed'));
    settings.themeWriteReply = null;
    await first;
    await latest;
    expect(container.read(analyserProvider).themeMode, ThemeMode.light);
    expect(container.read(analyserProvider).preferencesError, isNull);
    expect(settings.theme, ThemeMode.light);
  });
  test(
    'slider preview retains immutable collection identity and waits for commit',
    () async {
      final vm = container.read(analyserProvider.notifier);
      await vm.ready;
      final old = container.read(analyserProvider);
      vm.updateMinimum(-60);
      final next = container.read(analyserProvider);
      expect(identical(old.accessPoints, next.accessPoints), isTrue);
      expect(identical(old.history, next.history), isTrue);
      expect(next.minimumRssi, -60);
      expect(settings.minimum, -95);
      await vm.setMinimum(-60);
      expect(settings.minimum, -60);
    },
  );
  test(
    'permission denial clears busy without requesting a native scan',
    () async {
      wifi.snapshotValue = WifiSnapshot(
        permission: false,
        locationEnabled: true,
        wifiEnabled: true,
        status: 'Permission required',
        accessPoints: [],
      );
      wifi.permission = false;
      final vm = container.read(analyserProvider.notifier);
      await vm.ready;
      await vm.scan();
      expect(wifi.scanCalls, 0);
      expect(container.read(analyserProvider).busy, isFalse);
      expect(container.read(analyserProvider).permission, isFalse);
    },
  );
  test('repository failures become recoverable scan status', () async {
    final vm = container.read(analyserProvider.notifier);
    await vm.ready;
    wifi.scanError = PlatformException(
      code: 'invalid_snapshot',
      message: 'Malformed scan',
    );
    await vm.scan();
    expect(container.read(analyserProvider).busy, isFalse);
    expect(container.read(analyserProvider).status, 'Malformed scan');
  });
  test(
    'late replies are rejected after background, pause, and disposal',
    () async {
      final vm = container.read(analyserProvider.notifier);
      await vm.ready;
      wifi.scanReply = Completer<WifiSnapshot>();
      final pending = vm.scan();
      await Future<void>.delayed(Duration.zero);
      vm.didChangeAppLifecycleState(AppLifecycleState.paused);
      wifi.scanReply!.complete(sample(true, 500));
      await pending;
      expect(container.read(analyserProvider).history, isEmpty);
      vm.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await Future<void>.delayed(Duration.zero);
      wifi.scanReply = Completer<WifiSnapshot>();
      final pausedScan = vm.scan();
      await Future<void>.delayed(Duration.zero);
      vm.togglePause();
      wifi.scanReply!.complete(sample(true, 600));
      await pausedScan;
      expect(container.read(analyserProvider).history, isEmpty);
      vm.togglePause();
      wifi.scanReply = Completer<WifiSnapshot>();
      final disposedScan = vm.scan();
      await Future<void>.delayed(Duration.zero);
      container.dispose();
      wifi.scanReply!.complete(sample(true, 700));
      await disposedScan;
    },
  );
  test('native stream errors cannot overwrite demo or paused status', () async {
    final vm = container.read(analyserProvider.notifier);
    await vm.ready;
    await vm.setDemo(true);
    wifi.events.addError(PlatformException(code: 'offline'));
    expect(container.read(analyserProvider).status, contains('Simulated'));
    await vm.setDemo(false);
    vm.togglePause();
    final status = container.read(analyserProvider).status;
    wifi.events.addError(PlatformException(code: 'offline'));
    expect(container.read(analyserProvider).status, status);
  });
  test('scan deadline settles cached state and disposal cancels timers', () {
    fakeAsync((clock) {
      final localWifi = FakeWifiRepository();
      final localContainer = ProviderContainer(
        overrides: [
          wifiRepositoryProvider.overrideWithValue(localWifi),
          settingsRepositoryProvider.overrideWithValue(FakeSettings()),
          demoModeDefaultProvider.overrideWithValue(false),
        ],
      );
      final vm = localContainer.read(analyserProvider.notifier);
      clock.flushMicrotasks();
      localWifi.scanReply = Completer<WifiSnapshot>()
        ..complete(
          WifiSnapshot(
            permission: true,
            locationEnabled: true,
            wifiEnabled: true,
            status: 'Requested',
            accessPoints: [],
            scanRequested: true,
          ),
        );
      vm.scan();
      clock.flushMicrotasks();
      expect(localContainer.read(analyserProvider).busy, isTrue);
      clock.elapse(const Duration(seconds: 15));
      clock.flushMicrotasks();
      expect(localContainer.read(analyserProvider).busy, isFalse);
      expect(localContainer.read(analyserProvider).status, contains('cached'));
      localContainer.dispose();
      localWifi.events.close();
      clock.flushMicrotasks();
      expect(clock.pendingTimers, isEmpty);
    });
  });
  test(
    'evicted access point timestamps share bounded history lifetime',
    () async {
      final vm = container.read(analyserProvider.notifier);
      await vm.ready;
      WifiSnapshot snapshot(List<AccessPoint> points) => WifiSnapshot(
        permission: true,
        locationEnabled: true,
        wifiEnabled: true,
        status: 'Fresh',
        fresh: true,
        accessPoints: points,
      );
      final points = List.generate(
        257,
        (i) => AccessPoint(
          ssid: 'AP $i',
          bssid: 'bssid-$i',
          rssi: -50,
          frequency: 2412,
          timestamp: 100,
        ),
      );
      wifi.events.add(snapshot(points));
      expect(container.read(analyserProvider).history, hasLength(256));
      expect(
        container.read(analyserProvider).history.containsKey('bssid-0'),
        isFalse,
      );
      wifi.events.add(snapshot(points));
      expect(
        container.read(analyserProvider).history.containsKey('bssid-0'),
        isFalse,
      );
      expect(
        container
            .read(analyserProvider)
            .history
            .values
            .every((samples) => samples.length == 1),
        isTrue,
      );
      wifi.events.add(
        snapshot([
          const AccessPoint(
            ssid: 'AP 0',
            bssid: 'bssid-0',
            rssi: -50,
            frequency: 2412,
            timestamp: 200,
          ),
        ]),
      );
      expect(container.read(analyserProvider).history, hasLength(256));
      expect(container.read(analyserProvider).history['bssid-0'], hasLength(1));
    },
  );
}
