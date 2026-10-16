import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wifi_analyser/models/access_point.dart';
import 'package:wifi_analyser/models/analyser_state.dart';
import 'package:wifi_analyser/models/comparison_export.dart';
import 'package:wifi_analyser/models/comparison_session.dart';
import 'package:wifi_analyser/models/wifi_data_source.dart';
import 'package:wifi_analyser/repositories/comparison_sessions_repository.dart';
import 'package:wifi_analyser/repositories/settings_repository.dart';
import 'package:wifi_analyser/repositories/wifi_repository.dart';
import 'package:wifi_analyser/viewmodels/analyser_view_model.dart';
import 'package:wifi_analyser/widgets/scan_freshness.dart';

import 'controller_test.dart' show FakeWifiRepository, FakeSettings;

const point = AccessPoint(
  ssid: 'Home',
  bssid: '00:11:22:33:44:55',
  rssi: -55,
  frequency: 6115,
  width: 0,
  connected: true,
);
WifiSnapshot result(int id, {bool completed = true}) => WifiSnapshot(
  source: WifiDataSource.windows,
  permission: true,
  locationEnabled: true,
  wifiEnabled: true,
  scanCompleted: completed,
  completionId: id,
  status: 'Windows scan completion; radio freshness unknown',
  accessPoints: const [point],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Windows defaults to live repository and explicit Windows identity', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(
      container.read(wifiRepositoryProvider),
      isA<WindowsWifiRepository>(),
    );
    expect(container.read(demoModeDefaultProvider), isFalse);
    expect(container.read(liveWifiSourceProvider), WifiDataSource.windows);
  });

  test('Windows accepts completions once, follows connection band, rejects late replies', () async {
    final wifi = FakeWifiRepository()
      ..snapshotValue = result(0, completed: false);
    final container = ProviderContainer(
      overrides: [
        wifiRepositoryProvider.overrideWithValue(wifi),
        liveWifiSourceProvider.overrideWithValue(WifiDataSource.windows),
        settingsRepositoryProvider.overrideWithValue(FakeSettings()),
      ],
    );
    addTearDown(() {
      container.dispose();
      wifi.events.close();
    });
    final vm = container.read(analyserProvider.notifier);
    await vm.ready;
    expect(container.read(analyserProvider).demo, isFalse);
    expect(container.read(analyserProvider).history, isEmpty);
    expect(container.read(analyserProvider).band, WifiBand.ghz6);
    wifi.scanReply = Completer<WifiSnapshot>()..complete(result(1));
    await vm.scan();
    await vm.scan();
    expect(container.read(analyserProvider).history[point.bssid], hasLength(1));
    expect(container.read(analyserProvider).cached, isTrue);
    vm.setBand(WifiBand.ghz24);
    wifi.scanReply = Completer<WifiSnapshot>();
    final pending = vm.scan();
    await Future<void>.delayed(Duration.zero);
    vm.togglePause();
    wifi.scanReply!.complete(result(2));
    await pending;
    expect(container.read(analyserProvider).history[point.bssid], hasLength(1));
    expect(container.read(analyserProvider).band, WifiBand.ghz24);
    vm.togglePause();
    wifi.scanReply = Completer<WifiSnapshot>()..complete(result(3));
    await vm.scan();
    expect(container.read(analyserProvider).history[point.bssid], hasLength(2));
    expect(container.read(analyserProvider).acceptedScanId, 3);
  });

  test(
    'Windows native failures stay live and recover without simulated samples',
    () async {
      final wifi = FakeWifiRepository()
        ..snapshotValue = result(0, completed: false);
      final container = ProviderContainer(
        overrides: [
          wifiRepositoryProvider.overrideWithValue(wifi),
          liveWifiSourceProvider.overrideWithValue(WifiDataSource.windows),
          settingsRepositoryProvider.overrideWithValue(FakeSettings()),
        ],
      );
      addTearDown(() {
        container.dispose();
        wifi.events.close();
      });
      final vm = container.read(analyserProvider.notifier);
      await vm.ready;
      wifi.scanReply = Completer<WifiSnapshot>();
      final pending = vm.scan();
      await Future<void>.delayed(Duration.zero);
      wifi.scanReply!.completeError(
        PlatformException(
          code: 'access_denied',
          message: 'Enable Location access in Windows Settings',
        ),
      );
      await pending;
      final state = container.read(analyserProvider);
      expect(state.source, WifiDataSource.windows);
      expect(state.busy, isFalse);
      expect(state.history, isEmpty);
      expect(state.status, contains('Windows Settings'));
      wifi.scanReply = Completer<WifiSnapshot>()..complete(result(1));
      await vm.scan();
      expect(
        container.read(analyserProvider).history[point.bssid],
        hasLength(1),
      );
    },
  );

  test(
    'Windows payload rejects invented freshness, malformed IDs and RF metadata',
    () async {
      const channel = MethodChannel('com.samirpandey.wifi_analyser/wifi');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final valid = <String, Object?>{
        'source': 'windows',
        'permission': true,
        'locationEnabled': true,
        'wifiEnabled': true,
        'interfaceAvailable': true,
        'scanCompleted': true,
        'completionId': 1,
        'redactedCount': 0,
        'unavailableCount': 0,
        'accessPoints': [
          <String, Object?>{
            'bssid': point.bssid,
            'rssi': -55,
            'frequency': 6115,
            'width': 0,
            'timestamp': 0,
            'connected': true,
          },
        ],
      };
      Object? response = valid;
      messenger.setMockMethodCallHandler(channel, (_) async => response);
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final repo = WindowsWifiRepository();
      expect((await repo.scan()).accessPoints.single.width, 0);
      expect(await repo.scanResults.isEmpty, isTrue);
      for (final invalid in [
        {...valid, 'source': 'android'},
        {...valid, 'completionId': 0},
        {...valid, 'fresh': true},
        {...valid, 'scanRequested': true},
        {...valid, 'permission': 'allowed'},
        {...valid, 'unavailableCount': -1},
        {
          ...valid,
          'accessPoints': [
            {...((valid['accessPoints'] as List).single as Map), 'width': 20},
          ],
        },
        {
          ...valid,
          'accessPoints': [
            {
              ...((valid['accessPoints'] as List).single as Map),
              'timestamp': 123,
            },
          ],
        },
      ]) {
        response = invalid;
        await expectLater(repo.scan(), throwsA(isA<PlatformException>()));
      }
    },
  );

  test(
    'unknown Windows width survives save/load and exports as unavailable',
    () async {
      SharedPreferences.setMockInitialValues({});
      final repo = LocalComparisonSessionsRepository();
      final at = DateTime(2026, 10, 16);
      final session = ComparisonSession(
        id: 'windows-session',
        bssid: point.bssid,
        ssid: 'Home',
        label: 'Room',
        start: at,
        end: at.add(const Duration(seconds: 40)),
        source: WifiDataSource.windows,
        samples: [SessionSample(at: at, rssi: -55, frequency: 6115, width: 0)],
      );
      await repo.save([session]);
      final loaded = await repo.load();
      expect(loaded.single.source, WifiDataSource.windows);
      expect(loaded.single.samples.single.width, 0);
      final export = serializeComparison(loaded);
      expect(export.summary, contains('reported width unknown'));
      expect(export.summary, contains('20 MHz'));
      expect(export.csv, contains('Windows scan observations'));
      expect(point.widthLabel, 'Unknown width');
      expect(
        overlapContribution(point, 6115, 20),
        overlapContribution(
          const AccessPoint(ssid: '', bssid: '', rssi: -55, frequency: 6115),
          6115,
          20,
        ),
      );
    },
  );

  testWidgets(
    'Windows scan age labels completion with unknown radio freshness',
    (tester) async {
      final now = DateTime(2026, 10, 16);
      await tester.pumpWidget(
        MaterialApp(
          home: ScanFreshness(
            updated: now,
            demo: false,
            cached: false,
            source: WifiDataSource.windows,
            clock: () => now,
          ),
        ),
      );
      expect(find.text('Last completed scan 0s ago'), findsOneWidget);
      expect(find.textContaining('per-AP age unavailable'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
