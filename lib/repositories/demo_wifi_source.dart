import 'dart:math' as math;

import '../models/access_point.dart';

/// Deterministic simulated scans, isolated from hardware and domain models.
class DemoWifiSource {
  int _tick = 0;

  List<AccessPoint> next() {
    _tick++;
    return _accessPoints
        .map(
          (ap) => AccessPoint(
            ssid: ap.ssid,
            bssid: ap.bssid,
            rssi: ap.rssi + (math.sin(_tick * .6 + ap.frequency) * 3).round(),
            frequency: ap.frequency,
            centerFrequency: ap.centerFrequency,
            width: ap.width,
            security: ap.security,
            connected: ap.connected,
          ),
        )
        .toList();
  }
}

const _accessPoints = [
  AccessPoint(
    ssid: 'Studio Network',
    bssid: 'A4:83:E7:12:80:4C',
    rssi: -43,
    frequency: 2437,
    connected: true,
    security: 'WPA3',
    width: 20,
  ),
  AccessPoint(
    ssid: 'Neighbourhood',
    bssid: 'B8:27:EB:64:21:01',
    rssi: -68,
    frequency: 2412,
    security: 'WPA2',
  ),
  AccessPoint(
    ssid: 'Home Office',
    bssid: 'C0:25:E9:32:12:88',
    rssi: -59,
    frequency: 2462,
    security: 'WPA2',
    width: 40,
  ),
  AccessPoint(
    ssid: 'Coffee & Company',
    bssid: 'D4:61:9D:10:42:09',
    rssi: -77,
    frequency: 2422,
    security: 'Open',
  ),
  AccessPoint(
    ssid: '',
    bssid: 'E0:63:DA:55:19:20',
    rssi: -82,
    frequency: 2452,
    security: 'WPA2',
  ),
  AccessPoint(
    ssid: 'Studio Network • 5G',
    bssid: 'A4:83:E7:12:80:4D',
    rssi: -51,
    frequency: 5180,
    security: 'WPA3',
    width: 80,
  ),
  AccessPoint(
    ssid: 'Home Office • 5G',
    bssid: 'C0:25:E9:32:12:89',
    rssi: -72,
    frequency: 5745,
    security: 'WPA2',
    width: 40,
  ),
  AccessPoint(
    ssid: 'Next-generation',
    bssid: 'F8:72:EA:21:90:03',
    rssi: -62,
    frequency: 5975,
    security: 'WPA3',
    width: 80,
  ),
];
