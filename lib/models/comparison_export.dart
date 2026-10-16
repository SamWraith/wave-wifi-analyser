import 'ap_preference.dart';
import 'access_point.dart';
import 'comparison_session.dart';

const exportLimitations =
    'Foreground observations only; gaps are not filled. Missing AP and rejected '
    'updates add no samples. RSSI and median are signal evidence, not noise, '
    'interference, throughput or guaranteed improvement. Radio contexts remain '
    'separate. Timestamps are UTC, anchored to recording start. CSV text cells '
    'are spreadsheet-escaped; numeric measurements are unchanged.';

class ComparisonExport {
  const ComparisonExport({required this.summary, required this.csv});
  final String summary, csv;
  static const summaryFilename = 'wave-comparison.txt';
  static const csvFilename = 'wave-comparison.csv';
}

/// Pure serializer. Never accepts aliases or uses stored IDs in output.
ComparisonExport serializeComparison(
  List<ComparisonSession> sessions, {
  bool includeIdentifiers = false,
  bool includeLabels = false,
}) {
  if (sessions.isEmpty || sessions.length > maxComparisonSessions) {
    throw ArgumentError('Select 1–24 saved sessions.');
  }
  final first = sessions.first;
  if (sessions.any(
        (s) =>
            s.end == null ||
            s.samples.length > maxSessionSamples ||
            s.source != first.source ||
            preferenceKey(s.bssid) != preferenceKey(first.bssid),
      ) ||
      sessions.map((s) => s.id).toSet().length != sessions.length) {
    throw ArgumentError('Select saved sessions for the same BSSID and source.');
  }
  final summary = StringBuffer(
    'Wave WiFi comparison\n'
    'Source: ${first.source.evidenceLabel}\n'
    'SSID/BSSID: ${includeIdentifiers ? 'included' : 'excluded'}; '
    'room labels: ${includeLabels ? 'included' : 'excluded'}; aliases: excluded.\n'
    'This is not an anonymity guarantee. Labels, timing and radio context may identify a place.\n'
    '$exportLimitations\n${first.source.observationLimitations}\n',
  );
  final rows = <List<Object?>>[
    [
      'session',
      'source',
      if (includeLabels) 'room_label',
      if (includeIdentifiers) ...['ssid', 'bssid'],
      'start_utc',
      'end_utc',
      'sample_count',
      'missing_ap_updates',
      'cached_updates',
      'sample_utc',
      'rssi_dbm',
      'frequency_mhz',
      'reported_width_mhz',
      'reported_center_mhz',
      'radio_context',
      'limitations',
    ],
  ];
  for (var index = 0; index < sessions.length; index++) {
    final s = sessions[index];
    final name = 'Session ${index + 1}';
    final source = s.source.evidenceLabel;
    summary.writeln('\n$name${includeLabels ? ' · ${s.label}' : ''}');
    if (includeIdentifiers) {
      summary.writeln('SSID: ${s.ssid}\nBSSID: ${s.bssid}');
    }
    summary.writeln(
      '${_utc(s.start)} – ${_utc(s.end!)}\n'
      '${s.samples.length} samples; ${s.missingBatches} missing AP updates; '
      '${s.cachedBatches} cached updates.',
    );
    if (s.samples.isEmpty) {
      summary.writeln(
        s.source.usesCompletionTime
            ? 'No accepted scan observations. No signal estimate.'
            : 'No fresh samples. No signal estimate.',
      );
    } else {
      var previous = s.start;
      var longest = Duration.zero;
      for (final sample in s.samples) {
        final gap = sample.at.difference(previous);
        if (gap > longest) longest = gap;
        previous = sample.at;
      }
      final tail = s.end!.difference(previous);
      if (tail > longest) longest = tail;
      summary.writeln(
        'Longest session gap: ${longest.inMicroseconds / 1000} ms; '
        'wait to first: ${s.samples.first.at.difference(s.start).inMicroseconds / 1000} ms; '
        'silence to stop: ${tail.inMicroseconds / 1000} ms.',
      );
      final groups = <(int, int, int?), List<SessionSample>>{};
      for (final sample in s.samples) {
        groups
            .putIfAbsent((
              sample.frequency,
              sample.width,
              sample.centerFrequency,
            ), () => [])
            .add(sample);
      }
      for (final group in groups.entries) {
        final values = group.value.map((v) => v.rssi).toList()..sort();
        summary.writeln(
          '${_radio(group.value.first)}: ${values.length} samples; '
          'median ${medianRssi(group.value)} dBm; range ${values.first} to ${values.last} dBm.',
        );
      }
    }
    // Empty sessions still carry metadata, without a fabricated sample.
    for (final sample
        in s.samples.isEmpty ? <SessionSample?>[null] : s.samples) {
      rows.add([
        name,
        source,
        if (includeLabels) s.label,
        if (includeIdentifiers) ...[s.ssid, s.bssid],
        _utc(s.start),
        _utc(s.end!),
        s.samples.length,
        s.missingBatches,
        s.cachedBatches,
        sample == null ? '' : _utc(sample.at),
        sample?.rssi,
        sample?.frequency,
        sample == null || sample.width == 0 ? null : sample.width,
        sample?.centerFrequency,
        sample == null ? '' : _radio(sample),
        '$exportLimitations ${s.source.observationLimitations}',
      ]);
    }
  }
  return ComparisonExport(
    summary: summary.toString(),
    csv: '${rows.map((row) => row.map(_cell).join(',')).join('\r\n')}\r\n',
  );
}

String _utc(DateTime date) => date.toUtc().toIso8601String();
String _cell(Object? value) {
  if (value == null) return '""';
  if (value is num) return value.toString();
  var text = value.toString();
  if (RegExp(r'^[\s\x00-\x1f]*[=+@-]').hasMatch(text) ||
      text.startsWith('\t') ||
      text.startsWith('\r') ||
      text.startsWith('\n')) {
    text = "'$text";
  }
  return '"${text.replaceAll('"', '""')}"';
}

String _radio(SessionSample sample) {
  final ap = AccessPoint(
    ssid: '',
    bssid: '',
    rssi: sample.rssi,
    frequency: sample.frequency,
  );
  return '${ap.band.label} · CH ${ap.channel} · primary ${sample.frequency} MHz · '
      'reported width ${sample.width == 0 ? 'unknown' : '${sample.width} MHz'} · reported center '
      '${sample.centerFrequency == null ? 'unknown' : '${sample.centerFrequency} MHz'}';
}
