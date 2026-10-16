import 'access_point.dart';
import 'wifi_data_source.dart';

const maxComparisonSessions = 24;
const maxSessionSamples = 120;
const maxSessionLabelLength = 64;

class SessionSample {
  const SessionSample({
    required this.at,
    required this.rssi,
    required this.frequency,
    required this.width,
    this.centerFrequency,
  });
  final DateTime at;
  final int rssi, frequency, width;
  final int? centerFrequency;
  String get context {
    final ap = AccessPoint(
      ssid: '',
      bssid: '',
      rssi: rssi,
      frequency: frequency,
      width: width,
      centerFrequency: centerFrequency,
    );
    return '${ap.band.label} • CH ${ap.channel} ($frequency MHz) • ${ap.widthLabel} • reported center ${centerFrequency == null ? 'unknown' : '$centerFrequency MHz'}';
  }

  Map<String, Object?> toJson() => {
    'at': at.millisecondsSinceEpoch,
    'atMicros': at.microsecondsSinceEpoch,
    'rssi': rssi,
    'frequency': frequency,
    'width': width,
    'center': centerFrequency,
  };
}

double medianRssi(List<SessionSample> samples) {
  final values = samples.map((s) => s.rssi).toList()..sort();
  if (values.isEmpty) throw StateError('No observations');
  final middle = values.length ~/ 2;
  return values.length.isOdd
      ? values[middle].toDouble()
      : (values[middle - 1] + values[middle]) / 2;
}

class ComparisonSession {
  ComparisonSession({
    required this.id,
    required this.bssid,
    required this.ssid,
    required this.label,
    required this.start,
    this.end,
    bool demo = false,
    WifiDataSource? source,
    this.reason = '',
    List<SessionSample> samples = const [],
    this.missingBatches = 0,
    this.cachedBatches = 0,
  }) : source = source ?? WifiDataSource.fromDemo(demo),
       samples = List.unmodifiable(samples);
  final String id, bssid, ssid, label, reason;
  final DateTime start;
  final DateTime? end;
  final WifiDataSource source;
  bool get demo => source == WifiDataSource.demo;
  final List<SessionSample> samples;
  final int missingBatches, cachedBatches;
  Map<String, List<SessionSample>> get groups {
    final result = <String, List<SessionSample>>{};
    for (final sample in samples) {
      result.putIfAbsent(sample.context, () => []).add(sample);
    }
    return Map.unmodifiable(
      result.map(
        (key, value) => MapEntry(key, List<SessionSample>.unmodifiable(value)),
      ),
    );
  }

  ComparisonSession update({
    SessionSample? sample,
    DateTime? end,
    String? reason,
    bool missing = false,
    bool cached = false,
  }) => ComparisonSession(
    id: id,
    bssid: bssid,
    ssid: ssid,
    label: label,
    start: start,
    end: end ?? this.end,
    source: source,
    reason: reason ?? this.reason,
    samples: [...samples, ?sample],
    missingBatches: missingBatches + (missing ? 1 : 0),
    cachedBatches: cachedBatches + (cached ? 1 : 0),
  );
  Map<String, Object?> toJson() => {
    'id': id,
    'bssid': bssid,
    'ssid': ssid,
    'label': label,
    'start': start.millisecondsSinceEpoch,
    'startMicros': start.microsecondsSinceEpoch,
    'end': end?.millisecondsSinceEpoch,
    'endMicros': end?.microsecondsSinceEpoch,
    'demo': demo,
    'source': source.name,
    'reason': reason,
    'samples': samples.map((s) => s.toJson()).toList(),
    'missing': missingBatches,
    'cached': cachedBatches,
  };
}
