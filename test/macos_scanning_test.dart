import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wifi_analyser/models/access_point.dart';
import 'package:wifi_analyser/models/analyser_state.dart';
import 'package:wifi_analyser/models/wifi_data_source.dart';
import 'package:wifi_analyser/models/wifi_guidance.dart';
import 'package:wifi_analyser/viewmodels/wifi_guidance_view_model.dart';
import 'package:wifi_analyser/repositories/settings_repository.dart';
import 'package:wifi_analyser/repositories/wifi_repository.dart';
import 'package:wifi_analyser/viewmodels/analyser_view_model.dart';
import 'package:wifi_analyser/widgets/scan_freshness.dart';

import 'controller_test.dart' show FakeWifiRepository, FakeSettings;

WifiSnapshot completion(int id, {bool completed = true}) => WifiSnapshot(
  source: WifiDataSource.macos,
  scanCompleted: completed,
  completionId: id,
  permission: true,
  locationEnabled: true,
  wifiEnabled: true,
  status: 'macOS scan completion; per-AP time unavailable',
  accessPoints: const [
    AccessPoint(
      ssid: 'AP',
      bssid: '00:11:22:33:44:55',
      rssi: -55,
      frequency: 2412,
      timestamp: 0,
    ),
  ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'macOS completed scans record once without fabricated AP timestamps',
    () async {
      final wifi = FakeWifiRepository()
        ..snapshotValue = completion(0, completed: false);
      final container = ProviderContainer(
        overrides: [
          wifiRepositoryProvider.overrideWithValue(wifi),
          liveWifiSourceProvider.overrideWithValue(WifiDataSource.macos),
          settingsRepositoryProvider.overrideWithValue(FakeSettings()),
          demoModeDefaultProvider.overrideWithValue(false),
        ],
      );
      addTearDown(() {
        container.dispose();
        wifi.events.close();
      });
      final vm = container.read(analyserProvider.notifier);
      await vm.ready;
      expect(container.read(analyserProvider).history, isEmpty);
      wifi.scanReply = Completer<WifiSnapshot>()..complete(completion(1));
      await vm.scan();
      final first = container.read(analyserProvider);
      expect(first.source, WifiDataSource.macos);
      expect(first.accessPoints.single.timestamp, 0);
      expect(first.history.values.single, hasLength(1));
      await vm.scan(); // repeated completion ID does not record
      expect(wifi.scanCalls, 2);
      expect(
        container.read(analyserProvider).history.values.single,
        hasLength(1),
      );
      wifi.events.add(completion(2, completed: false));
      expect(
        container.read(analyserProvider).history.values.single,
        hasLength(1),
      );
      wifi.scanReply = Completer<WifiSnapshot>()..complete(completion(2));
      await vm.scan(); // same RSSI still distinct completed scan; age explicitly unknown
      expect(
        container.read(analyserProvider).history.values.single,
        hasLength(2),
      );
      vm.togglePause();
      wifi.events.add(completion(3));
      expect(
        container.read(analyserProvider).history.values.single,
        hasLength(2),
      );
      await vm.setDemo(true);
      wifi.events.add(completion(4));
      expect(container.read(analyserProvider).source, WifiDataSource.demo);
    },
  );

  test('empty completions update scan age without AP history', () async {
    final wifi = FakeWifiRepository()
      ..snapshotValue = completion(0, completed: false);
    final container = ProviderContainer(
      overrides: [
        wifiRepositoryProvider.overrideWithValue(wifi),
        liveWifiSourceProvider.overrideWithValue(WifiDataSource.macos),
        settingsRepositoryProvider.overrideWithValue(FakeSettings()),
        demoModeDefaultProvider.overrideWithValue(false),
      ],
    );
    addTearDown(() {
      container.dispose();
      wifi.events.close();
    });
    await container.read(analyserProvider.notifier).ready;
    wifi.events.add(
      WifiSnapshot(
        source: WifiDataSource.macos,
        scanCompleted: true,
        completionId: 1,
        permission: true,
        locationEnabled: true,
        wifiEnabled: true,
        status: '3 redacted results excluded',
        redactedCount: 3,
        accessPoints: const [],
      ),
    );
    final scan = container.read(analyserProvider);
    expect(scan.history, isEmpty);
    expect(scan.lastUpdated, isNotNull);
    expect(scan.cached, isFalse);
    expect(scan.redactedCount, 3);
  });

  test(
    'macOS guidance accepts new completion after backward clock correction',
    () async {
      var now = DateTime(2026, 10, 14, 12);
      final wifi = FakeWifiRepository()
        ..snapshotValue = completion(0, completed: false);
      final container = ProviderContainer(
        overrides: [
          wifiRepositoryProvider.overrideWithValue(wifi),
          liveWifiSourceProvider.overrideWithValue(WifiDataSource.macos),
          settingsRepositoryProvider.overrideWithValue(FakeSettings()),
          demoModeDefaultProvider.overrideWithValue(false),
          observationClockProvider.overrideWithValue(() => now),
          guidanceClockProvider.overrideWithValue(() => now),
        ],
      );
      final subscription = container.listen(wifiGuidanceProvider, (_, _) {});
      addTearDown(() {
        subscription.close();
        container.dispose();
        wifi.events.close();
      });
      await container.read(analyserProvider.notifier).ready;
      WifiSnapshot connected(int id) => WifiSnapshot(
        source: WifiDataSource.macos,
        scanCompleted: true,
        completionId: id,
        permission: true,
        locationEnabled: true,
        wifiEnabled: true,
        status: 'Completed',
        accessPoints: const [
          AccessPoint(
            ssid: 'Home',
            bssid: '00:11:22:33:44:55',
            rssi: -55,
            frequency: 2412,
            connected: true,
            timestamp: 0,
          ),
        ],
      );
      wifi.events.add(connected(1));
      final vm = container.read(wifiGuidanceProvider.notifier);
      vm.choose(WifiProblem.weakSignal);
      expect(container.read(wifiGuidanceProvider).baseline, isNotNull);
      await vm.recheck();
      expect(
        container.read(wifiGuidanceProvider).message,
        contains('cache freshness remain unknown'),
      );
      now = now.subtract(const Duration(hours: 1));
      wifi.events.add(connected(2));
      expect(container.read(wifiGuidanceProvider).waiting, isFalse);
      expect(container.read(wifiGuidanceProvider).current!.at, now);
    },
  );

  test('macOS repository validates source and completion metadata', () async {
    const channel = MethodChannel('com.samirpandey.wifi_analyser/wifi');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    Object? response;
    messenger.setMockMethodCallHandler(channel, (_) async => response);
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final repository = MacosWifiRepository();
    for (final invalid in [
      null,
      {'source': 'android'},
      {'source': 'unknown'},
      {'source': 'macos', 'scanCompleted': true, 'completionId': 0},
    ]) {
      response = invalid;
      await expectLater(repository.scan(), throwsA(isA<PlatformException>()));
    }
    response = {
      'source': 'macos',
      'permission': true,
      'locationEnabled': true,
      'wifiEnabled': true,
      'scanCompleted': true,
      'completionId': 2,
      'redactedCount': 3,
      'unavailableCount': 1,
      'interfaceAvailable': true,
      'accessPoints': <Object>[],
    };
    final valid = Map<String, Object?>.from(response as Map);
    for (final invalid in [
      {...valid, 'permission': 'allowed'},
      {...valid, 'redactedCount': -1},
      {...valid, 'completionId': 1.5},
      {
        ...valid,
        'accessPoints': [
          {
            'bssid': '<redacted>',
            'rssi': -55,
            'frequency': 2412,
            'width': 20,
            'timestamp': 0,
          },
        ],
      },
      {
        ...valid,
        'accessPoints': [
          {
            'bssid': '00:11:22:33:44:55',
            'rssi': -55,
            'frequency': 2412,
            'width': null,
            'timestamp': 0,
          },
        ],
      },
    ]) {
      response = invalid;
      await expectLater(repository.scan(), throwsA(isA<PlatformException>()));
    }
    response = valid;
    final result = await repository.scan();
    expect(result.completionId, 2);
    expect(result.redactedCount, 3);
    expect(result.accessPoints, isEmpty);
    expect(await repository.scanResults.isEmpty, isTrue);
  });

  testWidgets('macOS age labels completion and unknown radio freshness', (
    tester,
  ) async {
    final now = DateTime(2026, 10, 14);
    await tester.pumpWidget(
      MaterialApp(
        home: ScanFreshness(
          updated: now,
          demo: false,
          cached: false,
          source: WifiDataSource.macos,
          clock: () => now,
        ),
      ),
    );
    expect(find.text('Last completed scan 0s ago'), findsOneWidget);
    expect(
      find.text(
        'Scan completion • per-AP age unavailable; cache may contribute',
      ),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
