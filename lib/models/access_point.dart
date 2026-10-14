import 'dart:math' as math;

enum WifiBand {
  ghz24('2.4 GHz'),
  ghz5('5 GHz'),
  ghz6('6 GHz');

  const WifiBand(this.label);
  final String label;
}

class AccessPoint {
  const AccessPoint({
    required this.ssid,
    required this.bssid,
    required this.rssi,
    required this.frequency,
    this.width = 20,
    this.centerFrequency,
    this.security = 'Unknown',
    this.connected = false,
    this.timestamp = 0,
  });
  final String ssid, bssid, security;
  final int rssi, frequency, width, timestamp;
  final int? centerFrequency;
  int get spectralCenter => centerFrequency != null && centerFrequency! > 0
      ? centerFrequency!
      : frequency;
  final bool connected;
  String get name => ssid.isEmpty ? 'Hidden or unavailable name' : ssid;
  WifiBand get band => frequency >= 5925
      ? WifiBand.ghz6
      : frequency >= 4900
      ? WifiBand.ghz5
      : WifiBand.ghz24;
  int get channel => frequency == 2484
      ? 14
      : frequency == 5935
      ? 2
      : band == WifiBand.ghz24
      ? (frequency - 2407) ~/ 5
      : band == WifiBand.ghz6
      ? (frequency - 5950) ~/ 5
      : frequency < 5000
      ? (frequency - 4000) ~/ 5
      : (frequency - 5000) ~/ 5;
  String get quality => rssi >= -50
      ? 'Excellent'
      : rssi >= -65
      ? 'Good'
      : rssi >= -75
      ? 'Fair'
      : 'Weak';
  double get distance => math
      .pow(10, (27.55 - 20 * math.log(frequency) / math.ln10 + rssi.abs()) / 20)
      .toDouble();
  factory AccessPoint.fromMap(Map<dynamic, dynamic> m) => AccessPoint(
    ssid: m['ssid'] as String? ?? '',
    bssid: m['bssid'] as String? ?? '',
    rssi: (m['rssi'] as num).toInt(),
    frequency: (m['frequency'] as num).toInt(),
    width: (m['width'] as num?)?.toInt() ?? 20,
    centerFrequency: (m['centerFrequency'] as num?)?.toInt(),
    security: m['security'] as String? ?? 'Unknown',
    connected: m['connected'] == true,
    timestamp: (m['timestamp'] as num?)?.toInt() ?? 0,
  );
}

class ChannelRating {
  const ChannelRating(this.channel, this.frequency, this.interference);
  final int channel, frequency;
  final double interference;
}

// Local heuristic, not olgor's proprietary scoring algorithm. Width-aware
// overlap weighted by received power; never a measured throughput estimate.
List<ChannelRating> rateChannels(
  List<AccessPoint> aps,
  WifiBand band, {
  bool excludeConnected = true,
}) {
  final channels = switch (band) {
    WifiBand.ghz24 => [1, 6, 11],
    WifiBand.ghz5 => [36, 40, 44, 48, 149, 153, 157, 161],
    WifiBand.ghz6 => List.generate(15, (i) => 5 + i * 16),
  };
  final ratings = channels.map((ch) {
    final freq =
        (band == WifiBand.ghz24
            ? 2407
            : band == WifiBand.ghz5
            ? 5000
            : 5950) +
        ch * 5;
    final score = estimateChannelOverlap(
      aps,
      band,
      freq,
      excludeConnected: excludeConnected,
    );
    return ChannelRating(ch, freq, score);
  }).toList();
  ratings.sort((a, b) {
    final c = a.interference.compareTo(b.interference);
    return c != 0 ? c : a.channel.compareTo(b.channel);
  });
  return ratings;
}

/// Width-aware relative overlap, not measured noise or throughput.
double estimateChannelOverlap(
  List<AccessPoint> aps,
  WifiBand band,
  int frequency, {
  bool excludeConnected = true,
}) {
  var score = 0.0;
  for (final ap in aps.where(
    (a) => a.band == band && !(excludeConnected && a.connected),
  )) {
    score += overlapContribution(ap, frequency, 20);
  }
  return score;
}

/// Triangular bandwidth overlap weighted by received power.
/// Uses reported source geometry; never modifies source observations.
double overlapContribution(AccessPoint ap, int center, int width) {
  final overlap = math.max(
    0.0,
    1 - (center - ap.spectralCenter).abs() / (ap.width / 2 + width / 2),
  );
  return overlap * math.pow(10, (ap.rssi + 60) / 10);
}
