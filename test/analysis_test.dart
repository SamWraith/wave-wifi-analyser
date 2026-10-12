import 'package:flutter_test/flutter_test.dart';
import 'package:wifi_analyser/models/access_point.dart';

void main() {
  test('frequency conversion covers channel 14 and 6 GHz exception', () {
    AccessPoint ap(int f) =>
        AccessPoint(ssid: 'x', bssid: 'x', rssi: -50, frequency: f);
    expect(ap(2412).channel, 1);
    expect(ap(2484).channel, 14);
    expect(ap(5180).channel, 36);
    expect(ap(5975).channel, 5);
    expect(ap(5935).channel, 2);
    expect(ap(5935).band, WifiBand.ghz6);
  });
  test('connected AP excluded only in connected-network planning', () {
    const aps = [
      AccessPoint(
        ssid: 'x',
        bssid: 'x',
        rssi: -40,
        frequency: 2412,
        connected: true,
      ),
    ];
    expect(
      rateChannels(aps, WifiBand.ghz24).every((r) => r.interference == 0),
      isTrue,
    );
    expect(
      rateChannels(aps, WifiBand.ghz24, excludeConnected: false).last.channel,
      1,
    );
  });
  test('overlap accounts for bandwidth, band, and power', () {
    const aps = [
      AccessPoint(
        ssid: 'wide',
        bssid: 'a',
        rssi: -40,
        frequency: 2437,
        width: 40,
      ),
      AccessPoint(
        ssid: 'other band',
        bssid: 'b',
        rssi: -20,
        frequency: 5180,
        width: 80,
      ),
    ];
    final ratings = rateChannels(aps, WifiBand.ghz24);
    expect(ratings.last.channel, 6);
    expect(ratings.first.interference, greaterThan(0));
    final weaker = rateChannels([
      const AccessPoint(
        ssid: 'wide',
        bssid: 'a',
        rssi: -70,
        frequency: 2437,
        width: 40,
      ),
    ], WifiBand.ghz24);
    expect(ratings.last.interference, greaterThan(weaker.last.interference));
  });
}
