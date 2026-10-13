import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wifi_analyser/models/access_point.dart';
import 'package:wifi_analyser/models/analyser_state.dart';
import 'package:wifi_analyser/models/comparison_session.dart';
import 'package:wifi_analyser/repositories/comparison_sessions_repository.dart';
import 'package:wifi_analyser/repositories/settings_repository.dart';
import 'package:wifi_analyser/repositories/wifi_repository.dart';
import 'package:wifi_analyser/viewmodels/analyser_view_model.dart';
import 'package:wifi_analyser/viewmodels/comparison_sessions_view_model.dart';

import 'controller_test.dart' show FakeWifiRepository, FakeSettings, sample;

class FakeSessionClock implements SessionClock {
  DateTime wall = DateTime(2026, 10, 13, 12);
  Duration uptime = Duration.zero;
  @override
  DateTime now() => wall;
  @override
  Duration get elapsed => uptime;
}

class MemorySessions implements ComparisonSessionsRepository {
  List<ComparisonSession> saved = [];
  Completer<List<ComparisonSession>>? loadReply;
  Completer<void>? writeReply;
  bool fail = false;
  int writes = 0;
  @override
  Future<List<ComparisonSession>> load() async =>
      loadReply == null ? saved : await loadReply!.future;
  @override
  Future<void> save(List<ComparisonSession> sessions) async {
    writes++;
    if (writeReply != null) await writeReply!.future;
    if (fail) throw StateError('Full');
    saved = sessions;
  }
}

Future<void> settle() => Future<void>.delayed(Duration.zero);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const ap = AccessPoint(
    ssid: 'Test AP',
    bssid: '00:11:22:33:44:55',
    rssi: -55,
    frequency: 2412,
    timestamp: 100,
  );
  late MemorySessions repo;
  late FakeWifiRepository wifi;
  late ProviderContainer container;
  setUp(() {
    repo = MemorySessions();
    wifi = FakeWifiRepository();
    container = ProviderContainer(
      overrides: [
        comparisonSessionsRepositoryProvider.overrideWithValue(repo),
        wifiRepositoryProvider.overrideWithValue(wifi),
        settingsRepositoryProvider.overrideWithValue(FakeSettings()),
        demoModeDefaultProvider.overrideWithValue(false),
      ],
    );
  });
  tearDown(() async {
    container.dispose();
    await wifi.events.close();
  });
  test('fresh boundary rejects history, duplicates, cached, paused and background replies', () async {
    final analyser = container.read(analyserProvider.notifier);
    await analyser.ready;
    final vm = container.read(comparisonSessionsProvider.notifier);
    await vm.ready;
    wifi.events.add(sample(true, 100));
    expect(vm.start(ap, 'Living room', demo: false), isTrue);
    expect(container.read(comparisonSessionsProvider).active!.samples, isEmpty);
    wifi.events.add(sample(true, 100));
    wifi.events.add(sample(false, 200));
    expect(container.read(comparisonSessionsProvider).active!.samples, isEmpty);
    wifi.events.add(sample(true, 200));
    expect(
      container.read(comparisonSessionsProvider).active!.samples,
      hasLength(1),
    );
    analyser.togglePause();
    wifi.events.add(sample(true, 300));
    await settle();
    expect(repo.saved.single.samples, hasLength(1));
    expect(repo.saved.single.reason, 'Scanning paused');
    analyser.togglePause();
    vm.start(ap, 'Desk', demo: false);
    analyser.didChangeAppLifecycleState(AppLifecycleState.paused);
    wifi.events.add(sample(true, 400));
    await settle();
    expect(repo.saved.last.samples, isEmpty);
    expect(repo.saved.last.reason, 'App left foreground');
    analyser.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await settle();
    expect(container.read(comparisonSessionsProvider).active, isNull);
  });
  test('duplicate identities record only newest accepted AP in either order and case', () async {
    final analyser = container.read(analyserProvider.notifier);
    await analyser.ready;
    final vm = container.read(comparisonSessionsProvider.notifier);
    await vm.ready;
    const identity = 'aa:bb:cc:dd:ee:ff';
    AccessPoint point(int timestamp, int rssi, {bool uppercase = false}) =>
        AccessPoint(
          ssid: 'Same SSID',
          bssid: uppercase ? identity.toUpperCase() : identity,
          rssi: rssi,
          frequency: rssi == -50 ? 5180 : 2412,
          timestamp: timestamp,
        );
    WifiSnapshot batch(List<AccessPoint> points) => WifiSnapshot(
      permission: true,
      locationEnabled: true,
      wifiEnabled: true,
      status: 'Fresh',
      fresh: true,
      accessPoints: points,
    );
    wifi.events.add(batch([point(100, -80)]));
    for (var index = 0; index < 2; index++) {
      final oldTimestamp = 100 + index * 100;
      final old = point(oldTimestamp, -80, uppercase: index.isEven);
      final fresh = point(oldTimestamp + 100, -50, uppercase: index.isOdd);
      vm.start(point(100, -80), 'Order $index', demo: false);
      wifi.events.add(batch(index.isEven ? [old, fresh] : [fresh, old]));
      final samples = container
          .read(comparisonSessionsProvider)
          .active!
          .samples;
      expect(samples, hasLength(1));
      expect(samples.single.rssi, -50);
      expect(samples.single.frequency, 5180);
      wifi.events.add(
        batch([point(oldTimestamp + 100, -80, uppercase: index.isEven)]),
      );
      expect(
        container.read(comparisonSessionsProvider).active!.samples,
        hasLength(1),
      );
      vm.stop();
      await settle();
    }
  });

  test(
    'missing AP and stale batches stay explicit; source change ends recording',
    () async {
      final analyser = container.read(analyserProvider.notifier);
      await analyser.ready;
      final vm = container.read(comparisonSessionsProvider.notifier);
      await vm.ready;
      vm.start(ap, '', demo: false);
      vm.observe([], {}, demo: false);
      vm.observe([ap], {}, demo: false);
      vm.observe([ap], {ap.bssid: ap}, demo: true);
      expect(
        container.read(comparisonSessionsProvider).active!.missingBatches,
        1,
      );
      expect(
        container.read(comparisonSessionsProvider).active!.cachedBatches,
        1,
      );
      await analyser.setDemo(true);
      await settle();
      expect(repo.saved.single.demo, isFalse);
      expect(repo.saved.single.samples, isEmpty);
    },
  );
  test('hydration failure cannot replace inaccessible records; label survives early retry', () async {
    repo.loadReply = Completer();
    final vm = container.read(comparisonSessionsProvider.notifier);
    expect(vm.start(ap, '🛜 room', demo: false), isFalse);
    repo.loadReply!.completeError(StateError('Bad schema'));
    await vm.ready;
    expect(container.read(comparisonSessionsProvider).error, isNotNull);
    expect(repo.writes, 0);
    repo.loadReply = null;
    await vm.retry();
    expect(vm.start(ap, '🛜 room', demo: false), isTrue);
    vm.stop();
    await settle();
    expect(repo.saved.single.label, '🛜 room');
  });
  test('writes coalesce and stale failures cannot replace latest deletion; retry recovers', () async {
    final vm = container.read(comparisonSessionsProvider.notifier);
    await vm.ready;
    repo.writeReply = Completer();
    vm.start(ap, 'One', demo: false);
    vm.stop();
    final id = container.read(comparisonSessionsProvider).sessions.single.id;
    vm.delete(id);
    repo.writeReply!.completeError(StateError('Old'));
    repo.writeReply = null;
    await settle();
    expect(repo.saved, isEmpty);
    expect(container.read(comparisonSessionsProvider).error, isNull);
    repo.fail = true;
    vm.start(ap, 'Two', demo: false);
    vm.stop();
    await settle();
    expect(container.read(comparisonSessionsProvider).error, contains('Retry'));
    repo.fail = false;
    await vm.retry();
    expect(repo.saved, hasLength(1));
    vm.start(ap, 'Cancelled', demo: false);
    vm.cancel();
    expect(container.read(comparisonSessionsProvider).sessions, hasLength(1));
  });
  test('wall clock correction never invalidates anchored observation and stop times', () async {
    final clock = FakeSessionClock();
    final c = ProviderContainer(
      overrides: [
        comparisonSessionsRepositoryProvider.overrideWithValue(repo),
        sessionClockProvider.overrideWithValue(clock),
      ],
    );
    addTearDown(c.dispose);
    final vm = c.read(comparisonSessionsProvider.notifier);
    await vm.ready;
    vm.start(ap, 'Clock correction', demo: false);
    final start = clock.wall;
    clock.uptime = const Duration(seconds: 35);
    clock.wall = clock.wall.subtract(const Duration(hours: 2));
    vm.observe([ap], {ap.bssid: ap}, demo: false);
    clock.uptime = const Duration(seconds: 70);
    vm.observe([ap], {ap.bssid: ap}, demo: false);
    clock.wall = clock.wall.subtract(const Duration(days: 1));
    clock.uptime = const Duration(seconds: 75);
    vm.stop();
    await settle();
    final session = repo.saved.single;
    expect(session.samples.first.at, start.add(const Duration(seconds: 35)));
    expect(session.samples.last.at, start.add(const Duration(seconds: 70)));
    expect(session.end, start.add(const Duration(seconds: 75)));
    final raw = jsonEncode({
      'version': 1,
      'sessions': [session.toJson()],
    });
    expect(LocalComparisonSessionsRepository.decode(raw), hasLength(1));
  });

  test('caps preserve records, freeze samples, split contexts and calculate exact median', () async {
    final vm = container.read(comparisonSessionsProvider.notifier);
    await vm.ready;
    vm.start(ap, 'Room', demo: false);
    for (var i = 0; i < 120; i++) {
      final measured = AccessPoint(
        ssid: ap.ssid,
        bssid: ap.bssid,
        rssi: i.isEven ? -50 : -61,
        frequency: i < 60 ? 2412 : 5180,
        width: i < 60 ? 20 : 80,
      );
      vm.observe([measured], {ap.bssid: measured}, demo: false);
    }
    await settle();
    final saved = repo.saved.single;
    expect(saved.samples, hasLength(120));
    expect(saved.groups, hasLength(2));
    expect(medianRssi(saved.samples), -55.5);
    expect(() => saved.samples.clear(), throwsUnsupportedError);
    expect(() => saved.groups.values.first.clear(), throwsUnsupportedError);
    for (var i = 1; i < 24; i++) {
      vm.start(ap, '$i', demo: false);
      vm.stop();
    }
    await settle();
    expect(vm.start(ap, 'Overflow', demo: false), isFalse);
    expect(repo.saved, hasLength(24));
  });
  test('versioned storage relaunch validates Unicode and rejects malformed/future schemas', () async {
    SharedPreferences.setMockInitialValues({});
    final local = LocalComparisonSessionsRepository();
    final now = DateTime.now();
    final session = ComparisonSession(
      id: 'one',
      bssid: ap.bssid,
      ssid: ap.ssid,
      label: '🛜' * 32,
      start: now,
      end: now,
      demo: false,
      reason: 'Stopped',
    );
    await local.save([session]);
    expect((await local.load()).single.label, session.label);
    final raw = jsonEncode({
      'version': 1,
      'sessions': [session.toJson()],
    });
    expect(
      () => LocalComparisonSessionsRepository.decode(
        raw.replaceFirst('"version":1', '"version":2'),
      ),
      throwsFormatException,
    );
    final malformed = session.toJson()..['end'] = null;
    expect(
      () => LocalComparisonSessionsRepository.decode(
        jsonEncode({
          'version': 1,
          'sessions': [malformed],
        }),
      ),
      throwsFormatException,
    );
    expect(
      () => LocalComparisonSessionsRepository.decode(
        jsonEncode({
          'version': 1,
          'sessions': [session.toJson(), session.toJson()],
        }),
      ),
      throwsFormatException,
    );
    expect(
      () => LocalComparisonSessionsRepository.decode('x' * 1048577),
      throwsFormatException,
    );
  });
}
