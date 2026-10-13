import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wifi_analyser/models/access_point.dart';
import 'package:wifi_analyser/models/ap_preference.dart';
import 'package:wifi_analyser/repositories/ap_preferences_repository.dart';
import 'package:wifi_analyser/viewmodels/ap_preferences_view_model.dart';

const ap = AccessPoint(
  ssid: 'Shared',
  bssid: 'AA:11',
  rssi: -50,
  frequency: 2412,
);

class FakePreferences implements ApPreferencesRepository {
  Completer<Map<String, ApPreference>>? loading;
  Completer<void>? writing;
  bool failLoad = false, failSave = false;
  Map<String, ApPreference> saved = {};
  final writes = <Map<String, ApPreference>>[];
  @override
  Future<Map<String, ApPreference>> load() async {
    if (failLoad) throw StateError('load');
    return loading == null ? saved : await loading!.future;
  }

  @override
  Future<void> save(Map<String, ApPreference> entries) async {
    writes.add(entries);
    if (writing != null) await writing!.future;
    if (failSave) throw StateError('write');
    saved = entries;
  }
}

Future<void> flush() => Future<void>.delayed(Duration.zero);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('early favorite preserves saved alias and unrelated AP', () async {
    final repo = FakePreferences()..loading = Completer();
    final c = ProviderContainer(
      overrides: [apPreferencesRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(c.dispose);
    final vm = c.read(apPreferencesProvider.notifier);
    vm.setFavorite(ap, true);
    await flush();
    expect(repo.writes, isEmpty);
    repo.loading!.complete({
      'aa:11': const ApPreference(
        bssid: 'aa:11',
        ssid: 'Shared',
        alias: 'Desk',
      ),
      'bb:22': const ApPreference(
        bssid: 'bb:22',
        ssid: 'Shared',
        favorite: true,
      ),
    });
    await flush();
    expect(c.read(apPreferencesProvider).entries['aa:11']!.alias, 'Desk');
    expect(repo.saved.length, 2);
    expect(repo.saved['aa:11']!.favorite, isTrue);
  });
  test('write failure and later edit serialize without stale errors', () async {
    final repo = FakePreferences();
    final c = ProviderContainer(
      overrides: [apPreferencesRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(c.dispose);
    final vm = c.read(apPreferencesProvider.notifier);
    await flush();
    repo.writing = Completer();
    vm.setFavorite(ap, true);
    vm.setAlias(ap, 'Desk');
    repo.failSave = true;
    repo.writing!.complete();
    await flush();
    expect(c.read(apPreferencesProvider).error, isNotNull);
    expect(c.read(apPreferencesProvider).entries['aa:11']!.alias, 'Desk');
    repo.failSave = false;
    repo.writing = null;
    await vm.retry();
    expect(c.read(apPreferencesProvider).error, isNull);
    expect(repo.saved['aa:11']!.alias, 'Desk');
    vm.setAlias(ap, null);
    vm.setFavorite(ap, false);
    await flush();
    expect(repo.saved, isEmpty);
  });
  test('failed hydration never overwrites unknown saved choices', () async {
    final repo = FakePreferences()..failLoad = true;
    repo.saved = {
      'bb:22': const ApPreference(
        bssid: 'bb:22',
        ssid: 'Shared',
        favorite: true,
      ),
    };
    final c = ProviderContainer(
      overrides: [apPreferencesRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(c.dispose);
    final vm = c.read(apPreferencesProvider.notifier);
    await flush();
    vm.setAlias(ap, 'Desk');
    await flush();
    expect(repo.writes, isEmpty);
    repo.failLoad = false;
    await vm.retry();
    await flush();
    expect(repo.saved.length, 2);
  });
  test('cap rejects extra identity and collections stay immutable', () async {
    final repo = FakePreferences()
      ..saved = {
        for (var i = 0; i < 256; i++)
          '$i': ApPreference(bssid: '$i', ssid: 'Shared', favorite: true),
      };
    final c = ProviderContainer(
      overrides: [apPreferencesRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(c.dispose);
    final vm = c.read(apPreferencesProvider.notifier);
    await flush();
    vm.setFavorite(ap, true);
    expect(c.read(apPreferencesProvider).entries.length, 256);
    expect(c.read(apPreferencesProvider).error, contains('256'));
    expect(
      () => c.read(apPreferencesProvider).entries.clear(),
      throwsUnsupportedError,
    );
  });
  test(
    'repeated early edits coalesce and pending tombstones stay bounded',
    () async {
      final repo = FakePreferences()..loading = Completer();
      final c = ProviderContainer(
        overrides: [apPreferencesRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(c.dispose);
      final vm = c.read(apPreferencesProvider.notifier);
      for (var i = 0; i < 10000; i++) {
        vm.setFavorite(ap, i.isEven);
        vm.setAlias(ap, 'Desk $i');
      }
      vm.setAlias(ap, null);
      for (var i = 0; i < 300; i++) {
        final other = AccessPoint(
          ssid: 'Shared',
          bssid: '$i',
          rssi: -50,
          frequency: 2412,
        );
        vm.setFavorite(other, true);
        vm.setFavorite(other, false);
      }
      expect(c.read(apPreferencesProvider).error, contains('pending'));
      await flush();
      repo.loading!.complete({
        'aa:11': const ApPreference(
          bssid: 'aa:11',
          ssid: 'Shared',
          alias: 'Old',
          favorite: true,
        ),
      });
      await flush();
      expect(c.read(apPreferencesProvider).entries, isEmpty);
      expect(repo.saved, isEmpty);
    },
  );
  test('full hydrated store rejects only new early additions', () async {
    final repo = FakePreferences()..loading = Completer();
    final c = ProviderContainer(
      overrides: [apPreferencesRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(c.dispose);
    final vm = c.read(apPreferencesProvider.notifier);
    vm.setFavorite(ap, true);
    vm.updateSaved(
      const ApPreference(bssid: '0', ssid: 'Saved'),
      alias: 'Accepted',
    );
    await flush();
    repo.loading!.complete({
      for (var i = 0; i < 256; i++)
        '$i': ApPreference(bssid: '$i', ssid: 'Saved', favorite: true),
    });
    await flush();
    expect(c.read(apPreferencesProvider).entries.length, 256);
    expect(c.read(apPreferencesProvider).entries.containsKey('aa:11'), isFalse);
    expect(c.read(apPreferencesProvider).error, contains('could not be added'));
    expect(repo.saved['0']!.alias, 'Accepted');
    expect(repo.saved.length, 256);
  });
  test('oversized encoded write preserves existing store', () async {
    SharedPreferences.setMockInitialValues({
      apPreferencesStorageKey: '{"version":1,"entries":[]}',
    });
    final entries = {
      for (var i = 0; i < 256; i++)
        '$i': ApPreference(
          bssid: '$i',
          ssid: String.fromCharCode(1) * 256,
          alias: String.fromCharCode(1) * 64,
        ),
    };
    await expectLater(
      LocalApPreferencesRepository().save(entries),
      throwsStateError,
    );
    expect(await LocalApPreferencesRepository().load(), isEmpty);
  });
  test(
    'version zero migration, relaunch and unsupported/corrupt recovery',
    () async {
      SharedPreferences.setMockInitialValues({
        apPreferencesStorageKey: jsonEncode({
          'version': 0,
          'entries': {
            'AA:11': {'ssid': 'Shared', 'alias': 'Desk', 'favorite': true},
            'BB:22': {'ssid': 'Shared', 'favorite': true},
          },
        }),
      });
      final repo = LocalApPreferencesRepository();
      final entries = await repo.load();
      expect(entries.length, 2);
      expect(entries['aa:11']!.name, 'Desk');
      await repo.save(entries);
      expect(
        (await LocalApPreferencesRepository().load())['bb:22']!.ssid,
        'Shared',
      );
      final prefs = await SharedPreferences.getInstance();
      expect(
        jsonDecode(prefs.getString(apPreferencesStorageKey)!)['version'],
        1,
      );
      await prefs.setString(
        apPreferencesStorageKey,
        '{"version":99,"entries":[]}',
      );
      await expectLater(repo.load(), throwsFormatException);
      expect(prefs.getString(apPreferencesStorageKey), contains('99'));
      await prefs.setString(apPreferencesStorageKey, '{');
      await expectLater(repo.load(), throwsFormatException);
    },
  );
}
