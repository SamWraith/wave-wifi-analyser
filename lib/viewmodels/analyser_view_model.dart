import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/access_point.dart';
import '../models/analyser_state.dart';
import '../repositories/demo_wifi_source.dart';
import '../repositories/wifi_repository.dart';
import '../repositories/settings_repository.dart';

final demoModeDefaultProvider = Provider<bool>(
  (ref) => !ref.read(wifiRepositoryProvider).supported,
);
final analyserProvider = NotifierProvider<AnalyserViewModel, AnalyserState>(
  AnalyserViewModel.new,
);

class AnalyserViewModel extends Notifier<AnalyserState>
    with WidgetsBindingObserver {
  late WifiRepository _wifi;
  late SettingsRepository _settings;
  late Future<void> ready;
  Timer? _timer, _deadline;
  StreamSubscription<WifiSnapshot>? _subscription;
  final Map<String, int> _lastTimestamp = {};
  int _evictedTimestampFloor = 0;
  bool _active = true;
  int _epoch = 0, _themeRevision = 0, _minimumRevision = 0;
  final _demo = DemoWifiSource();
  Future<void> _preferenceWrites = Future.value();
  final Map<String, String> _preferenceErrors = {};
  @override
  AnalyserState build() {
    _wifi = ref.read(wifiRepositoryProvider);
    _settings = ref.read(settingsRepositoryProvider);
    WidgetsBinding.instance.addObserver(this);
    ref.onDispose(() {
      _epoch++;
      _timer?.cancel();
      _deadline?.cancel();
      _subscription?.cancel();
      WidgetsBinding.instance.removeObserver(this);
    });
    ready = Future.microtask(_initialize);
    return AnalyserState(demo: ref.read(demoModeDefaultProvider));
  }

  Future<void> _initialize() async {
    try {
      final prefs = await _settings.load();
      if (!ref.mounted) return;
      state = state.copyWith(
        themeMode: _themeRevision == 0 ? prefs.themeMode : state.themeMode,
        minimumRssi: _minimumRevision == 0
            ? prefs.minimumRssi
            : state.minimumRssi,
      );
    } catch (_) {
      if (ref.mounted) {
        state = state.copyWith(
          preferencesError:
              'Could not load preferences. Current choices remain available.',
        );
      }
    }
    if (!ref.mounted) return;
    if (_wifi.supported) {
      _subscription = _wifi.scanResults.listen(
        (snapshot) {
          if (!_acceptLiveUpdates) return;
          _deadline?.cancel();
          state = state.copyWith(busy: false);
          _apply(snapshot);
        },
        onError: (Object error) {
          if (_acceptLiveUpdates) {
            _deadline?.cancel();
            state = state.copyWith(
              busy: false,
              status: 'Scan unavailable: $error',
            );
          }
        },
      );
    }
    if (state.demo) {
      await scan();
    } else {
      await _snapshot();
    }
    if (ref.mounted) _schedule();
  }

  bool get _acceptLiveUpdates =>
      ref.mounted && !state.demo && !state.paused && _active;

  bool _isCurrent(int epoch) => ref.mounted && epoch == _epoch;

  void _schedule() {
    _timer?.cancel();
    if (!state.paused && _active) {
      _timer = Timer.periodic(
        Duration(seconds: state.demo ? 3 : 35),
        (_) => scan(requestPermission: false),
      );
    }
  }

  Future<void> _snapshot() async {
    final epoch = _epoch;
    try {
      final snapshot = await _wifi.snapshot();
      if (ref.mounted && epoch == _epoch) _apply(snapshot);
    } on PlatformException catch (e) {
      if (ref.mounted && epoch == _epoch) {
        state = state.copyWith(
          status: e.message ?? 'Could not read WiFi state',
        );
      }
    } on MissingPluginException {
      if (ref.mounted && epoch == _epoch) {
        state = state.copyWith(
          status: 'Live scanning requires Android. Try demo mode.',
        );
      }
    }
  }

  void _apply(WifiSnapshot snapshot) {
    final now = DateTime.now();
    final history = state.history.map(
      (key, value) => MapEntry(key, List<SignalSample>.of(value)),
    );
    var observed = false;
    // Keep one floor for the whole batch: eviction during this scan must not
    // suppress other first-time APs from the same hardware scan.
    final timestampFloor = _evictedTimestampFloor;
    for (final ap in snapshot.accessPoints) {
      if (snapshot.fresh &&
          ap.timestamp > (_lastTimestamp[ap.bssid] ?? timestampFloor)) {
        _record(history, ap.bssid, now, ap.rssi);
        _lastTimestamp[ap.bssid] = ap.timestamp;
        observed = true;
      }
    }
    state = state.copyWith(
      permission: snapshot.permission,
      locationEnabled: snapshot.locationEnabled,
      wifiEnabled: snapshot.wifiEnabled,
      status: snapshot.status,
      accessPoints: snapshot.accessPoints,
      history: history,
      lastUpdated: observed ? now : null,
    );
  }

  void _record(
    Map<String, List<SignalSample>> history,
    String bssid,
    DateTime at,
    int rssi,
  ) {
    final samples = history.putIfAbsent(bssid, () => []);
    samples.add(SignalSample(at, rssi));
    if (samples.length > 60) samples.removeAt(0);
    if (history.length > 256) {
      final oldest = history.keys.first;
      history.remove(oldest);
      final evicted = _lastTimestamp.remove(oldest);
      if (evicted != null && evicted > _evictedTimestampFloor) {
        _evictedTimestampFloor = evicted;
      }
    }
  }

  Future<void> scan({bool requestPermission = true}) async {
    if (!ref.mounted || state.busy || state.paused || !_active) return;
    if (state.demo) {
      _scanDemo();
      return;
    }
    final epoch = _epoch;
    state = state.copyWith(busy: true, status: 'Scanning nearby networks…');
    try {
      if (!await _ensurePermission(requestPermission, epoch)) return;
      final snapshot = await _wifi.scan();
      if (!ref.mounted || epoch != _epoch) return;
      _apply(snapshot);
      if (!snapshot.scanRequested) {
        state = state.copyWith(busy: false);
      } else if (state.busy) {
        _waitForScan(epoch);
      }
    } on PlatformException catch (e) {
      if (ref.mounted && epoch == _epoch) {
        state = state.copyWith(busy: false, status: e.message ?? 'Scan failed');
      }
    } on MissingPluginException {
      if (ref.mounted && epoch == _epoch) {
        state = state.copyWith(
          busy: false,
          status: 'Live scanning requires Android. Try demo mode.',
        );
      }
    }
  }

  void _scanDemo() {
    final now = DateTime.now();
    final points = _demo.next();
    final history = state.history.map(
      (key, value) => MapEntry(key, List<SignalSample>.of(value)),
    );
    for (final ap in points) {
      _record(history, ap.bssid, now, ap.rssi);
    }
    state = state.copyWith(
      accessPoints: points,
      history: history,
      lastUpdated: now,
      status: 'Simulated data • no hardware scan',
    );
  }

  Future<bool> _ensurePermission(bool requestPermission, int epoch) async {
    if (!requestPermission || state.permission) return _isCurrent(epoch);
    final allowed = await _wifi.requestPermission();
    if (!_isCurrent(epoch)) return false;
    state = state.copyWith(permission: allowed);
    if (allowed) return true;
    state = state.copyWith(busy: false);
    await _snapshot();
    return false;
  }

  void _waitForScan(int epoch) {
    _deadline?.cancel();
    _deadline = Timer(const Duration(seconds: 15), () async {
      if (!_isCurrent(epoch)) return;
      state = state.copyWith(busy: false);
      await _snapshot();
      if (_isCurrent(epoch)) {
        state = state.copyWith(
          status: 'No new scan yet. Showing cached results.',
        );
      }
    });
  }

  Future<void> setTheme(ThemeMode value) {
    if (!ref.mounted) return Future.value();
    final revision = ++_themeRevision;
    state = state.copyWith(themeMode: value);
    return _savePreference(
      'theme',
      () => revision == _themeRevision,
      () => _settings.saveTheme(value),
    );
  }

  /// Update slider feedback without writing storage on every drag event.
  void updateMinimum(int value) {
    if (!ref.mounted) return;
    _minimumRevision++;
    state = state.copyWith(minimumRssi: value.clamp(-95, -40));
  }

  Future<void> setMinimum(int value) {
    if (!ref.mounted) return Future.value();
    updateMinimum(value);
    final revision = _minimumRevision;
    final minimum = state.minimumRssi;
    return _savePreference(
      'signal threshold',
      () => revision == _minimumRevision,
      () => _settings.saveMinimum(minimum),
    );
  }

  Future<void> _savePreference(
    String field,
    bool Function() isLatest,
    Future<void> Function() write,
  ) {
    final next = _preferenceWrites.then((_) async {
      if (!ref.mounted || !isLatest()) return;
      try {
        await write();
        if (!ref.mounted || !isLatest()) return;
        _preferenceErrors.remove(field);
      } catch (_) {
        if (!ref.mounted || !isLatest()) return;
        _preferenceErrors[field] =
            'Could not save $field. Choose it again to retry.';
      }
      final error = _preferenceErrors.values.join(' ');
      state = state.copyWith(
        preferencesError: error.isEmpty ? null : error,
        clearPreferencesError: error.isEmpty,
      );
    });
    _preferenceWrites = next;
    return next;
  }

  void setBand(WifiBand value) {
    state = state.copyWith(band: value);
  }

  void setQuery(String value) {
    state = state.copyWith(query: value);
  }

  void setExclude(bool value) {
    state = state.copyWith(excludeConnected: value);
  }

  Future<void> setDemo(bool value) async {
    _epoch++;
    _deadline?.cancel();
    _lastTimestamp.clear();
    _evictedTimestampFloor = 0;
    state = state.copyWith(
      demo: value,
      busy: false,
      history: {},
      accessPoints: [],
      clearLastUpdated: true,
    );
    _schedule();
    if (value) {
      await scan();
    } else {
      await _snapshot();
    }
  }

  void togglePause() {
    _epoch++;
    _deadline?.cancel();
    state = state.copyWith(paused: !state.paused, busy: false);
    _schedule();
  }

  Future<void> openSettings() async {
    try {
      await _wifi.openSettings();
    } on MissingPluginException {
      if (ref.mounted) {
        state = state.copyWith(
          status: 'WiFi settings are available on Android.',
        );
      }
    } on PlatformException catch (e) {
      if (ref.mounted) {
        state = state.copyWith(status: e.message ?? 'Could not open settings');
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!ref.mounted) return;
    _active = state == AppLifecycleState.resumed;
    if (!_active) {
      _epoch++;
      _deadline?.cancel();
      this.state = this.state.copyWith(busy: false);
    }
    _schedule();
    if (_active && !this.state.demo) _snapshot();
  }
}
