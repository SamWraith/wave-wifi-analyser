import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/analyser_state.dart';
import '../models/wifi_data_source.dart';

enum WifiSettingsTarget { wifi, location, permission }

abstract interface class WifiRepository {
  bool get supported;
  Stream<WifiSnapshot> get scanResults;
  Future<WifiSnapshot> snapshot();
  Future<WifiSnapshot> scan({bool interactive = false});
  Future<bool> requestPermission();
  Future<void> openSettings({
    WifiSettingsTarget target = WifiSettingsTarget.wifi,
  });
}

final wifiRepositoryProvider = Provider<WifiRepository>(
  (ref) => kIsWeb
      ? AndroidWifiRepository()
      : switch (defaultTargetPlatform) {
          TargetPlatform.linux => LinuxWifiRepository(),
          TargetPlatform.windows => WindowsWifiRepository(),
          TargetPlatform.macOS => MacosWifiRepository(),
          _ => AndroidWifiRepository(),
        },
);

class AndroidWifiRepository implements WifiRepository {
  static const _native = MethodChannel('com.samirpandey.wifi_analyser/wifi');
  static const _events = EventChannel(
    'com.samirpandey.wifi_analyser/scan_results',
  );
  @override
  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  @override
  Stream<WifiSnapshot> get scanResults =>
      _events.receiveBroadcastStream().map(decodeSnapshot);
  Future<WifiSnapshot> _read(String method) async {
    final result = await _native.invokeMethod<Object?>(method);
    if (result == null) {
      throw PlatformException(
        code: 'empty_snapshot',
        message: 'Android returned no WiFi state',
      );
    }
    return decodeSnapshot(result);
  }

  @override
  Future<WifiSnapshot> snapshot() => _read('snapshot');
  @override
  Future<WifiSnapshot> scan({bool interactive = false}) => _read('scan');
  @override
  Future<bool> requestPermission() async =>
      await _native.invokeMethod<bool>('requestPermission') ?? false;
  @override
  Future<void> openSettings({
    WifiSettingsTarget target = WifiSettingsTarget.wifi,
  }) => _native.invokeMethod<void>('openSettings', {'target': target.name});
}

/// Keep malformed native payloads inside the repository error boundary.
WifiSnapshot decodeSnapshot(Object? value) {
  try {
    return WifiSnapshot.fromMap(Map<dynamic, dynamic>.from(value as Map));
  } on TypeError {
    throw PlatformException(
      code: 'invalid_snapshot',
      message: 'Native platform returned malformed WiFi state',
    );
  } on ArgumentError {
    throw PlatformException(
      code: 'invalid_snapshot',
      message: 'Native platform returned malformed WiFi state',
    );
  } on FormatException {
    throw PlatformException(
      code: 'invalid_snapshot',
      message: 'Native platform returned malformed WiFi state',
    );
  }
}

/// Explicit platform identity stays injectable without expanding fake contracts.
final liveWifiSourceProvider = Provider<WifiDataSource>((ref) {
  final repository = ref.read(wifiRepositoryProvider);
  return repository is DesktopWifiRepository
      ? repository.source
      : WifiDataSource.android;
});

/// Desktop methods resolve after completion; Android alone uses broadcasts.
/// Keep validation and cancellation shared without changing injectable fakes.
class DesktopWifiRepository extends AndroidWifiRepository {
  DesktopWifiRepository(this.source, this.platform);
  final WifiDataSource source;
  final TargetPlatform platform;
  static const _native = MethodChannel('com.samirpandey.wifi_analyser/wifi');
  @override
  bool get supported => !kIsWeb && defaultTargetPlatform == platform;
  @override
  Stream<WifiSnapshot> get scanResults => const Stream.empty();
  Future<void> cancelScan() => _native.invokeMethod<void>('cancelScan');
  @override
  Future<WifiSnapshot> snapshot() => _readDesktop('snapshot');
  @override
  Future<WifiSnapshot> scan({bool interactive = false}) =>
      _readDesktop('scan', arguments: {'interactive': interactive});

  Future<WifiSnapshot> _readDesktop(
    String method, {
    Map<String, Object?>? arguments,
  }) async {
    final payload = await _native.invokeMethod<Object?>(method, arguments);
    _validateDesktopPayload(payload, source: source);
    final snapshot = decodeSnapshot(payload);
    if ((snapshot.scanCompleted && snapshot.completionId <= 0) ||
        (source != WifiDataSource.macos &&
            (snapshot.scanRequested || snapshot.fresh))) {
      throw PlatformException(
        code: 'invalid_snapshot',
        message: '${source.label} returned invalid scan completion metadata',
      );
    }
    return snapshot;
  }
}

class MacosWifiRepository extends DesktopWifiRepository {
  MacosWifiRepository() : super(WifiDataSource.macos, TargetPlatform.macOS);
}

class WindowsWifiRepository extends DesktopWifiRepository {
  WindowsWifiRepository()
    : super(WifiDataSource.windows, TargetPlatform.windows);
}

class LinuxWifiRepository extends DesktopWifiRepository {
  LinuxWifiRepository() : super(WifiDataSource.linux, TargetPlatform.linux);
}

void _validateDesktopPayload(
  Object? payload, {
  required WifiDataSource source,
}) {
  final unknownWidth = source != WifiDataSource.macos;
  final bssidPattern = RegExp(r'^(?:[0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$');
  bool valid = payload is Map && payload['source'] == source.name;
  if (valid) {
    final map = payload;
    valid =
        [
          'permission',
          'locationEnabled',
          'wifiEnabled',
          'scanCompleted',
          'interfaceAvailable',
        ].every((key) => map[key] is bool) &&
        [
          'completionId',
          'redactedCount',
          'unavailableCount',
        ].every((key) => map[key] is int && (map[key] as int) >= 0) &&
        map['accessPoints'] is List;
    if (valid) {
      for (final ap in map['accessPoints'] as List) {
        if (ap is! Map ||
            ap['bssid'] is! String ||
            !bssidPattern.hasMatch(ap['bssid'] as String) ||
            ap['bssid'] == '00:00:00:00:00:00' ||
            (ap['bssid'] as String).toLowerCase() == 'ff:ff:ff:ff:ff:ff' ||
            ap['rssi'] is! int ||
            (ap['rssi'] as int) > 0 ||
            (ap['rssi'] as int) < -127 ||
            ap['frequency'] is! int ||
            (ap['frequency'] as int) <= 0 ||
            ap['width'] is! int ||
            !(unknownWidth ? [0] : [20, 40, 80, 160]).contains(ap['width']) ||
            ap['timestamp'] is! int ||
            ap['timestamp'] != 0 ||
            ap['centerFrequency'] != null) {
          valid = false;
          break;
        }
      }
    }
  }
  if (!valid) {
    throw PlatformException(
      code: 'invalid_snapshot',
      message: '${source.label} returned malformed WiFi state',
    );
  }
}
