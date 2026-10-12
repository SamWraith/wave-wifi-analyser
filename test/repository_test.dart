import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wifi_analyser/models/access_point.dart';
import 'package:wifi_analyser/models/analyser_state.dart';
import 'package:wifi_analyser/repositories/settings_repository.dart';
import 'package:wifi_analyser/repositories/wifi_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('malformed native data becomes recoverable platform failure', () {
    for (final value in [
      null,
      42,
      {'accessPoints': 'broken'},
      {
        'accessPoints': [
          {'rssi': 'invalid'},
        ],
      },
    ]) {
      expect(
        () => decodeSnapshot(value),
        throwsA(
          isA<PlatformException>().having(
            (error) => error.code,
            'code',
            'invalid_snapshot',
          ),
        ),
      );
    }
    final snapshot = decodeSnapshot({
      'permission': true,
      'accessPoints': [
        {'ssid': 'AP', 'bssid': '00', 'rssi': -50, 'frequency': 2412},
      ],
    });
    expect(snapshot.permission, isTrue);
    expect(snapshot.accessPoints.single.rssi, -50);
  });
  test('snapshot freezes caller-owned access points', () {
    final points = <AccessPoint>[
      const AccessPoint(ssid: 'AP', bssid: '00', rssi: -50, frequency: 2412),
    ];
    final snapshot = WifiSnapshot(
      permission: true,
      locationEnabled: true,
      wifiEnabled: true,
      status: 'Ready',
      accessPoints: points,
    );
    points.clear();
    expect(snapshot.accessPoints, hasLength(1));
    expect(() => snapshot.accessPoints.clear(), throwsUnsupportedError);
  });
  test('local settings save and reload validated preferences', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = LocalSettingsRepository();
    await repository.saveTheme(ThemeMode.dark);
    await repository.saveMinimum(-70);
    final prefs = await repository.load();
    expect(prefs.themeMode, ThemeMode.dark);
    expect(prefs.minimumRssi, -70);
  });
}
