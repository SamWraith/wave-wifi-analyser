import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/analyser_state.dart';

abstract interface class WifiRepository {
  bool get supported;
  Stream<WifiSnapshot> get scanResults;
  Future<WifiSnapshot> snapshot();
  Future<WifiSnapshot> scan();
  Future<bool> requestPermission();
  Future<void> openSettings();
}

final wifiRepositoryProvider = Provider<WifiRepository>(
  (ref) => AndroidWifiRepository(),
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
  Future<WifiSnapshot> scan() => _read('scan');
  @override
  Future<bool> requestPermission() async =>
      await _native.invokeMethod<bool>('requestPermission') ?? false;
  @override
  Future<void> openSettings() => _native.invokeMethod<void>('openSettings');
}

/// Keep malformed native payloads inside the repository error boundary.
WifiSnapshot decodeSnapshot(Object? value) {
  try {
    return WifiSnapshot.fromMap(Map<dynamic, dynamic>.from(value as Map));
  } on TypeError {
    throw PlatformException(
      code: 'invalid_snapshot',
      message: 'Android returned malformed WiFi state',
    );
  } on FormatException {
    throw PlatformException(
      code: 'invalid_snapshot',
      message: 'Android returned malformed WiFi state',
    );
  }
}
