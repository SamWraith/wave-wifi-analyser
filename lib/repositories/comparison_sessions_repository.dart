import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/comparison_session.dart';
import '../models/wifi_data_source.dart';
import '../models/ap_preference.dart';

const comparisonSessionsStorageKey = 'comparisonSessions';
// 24 × 120 compact samples fit below 1 MiB; reject oversized input before decode.
const maxSessionsStorageBytes = 1048576;

abstract interface class ComparisonSessionsRepository {
  Future<List<ComparisonSession>> load();
  Future<void> save(List<ComparisonSession> sessions);
}

final comparisonSessionsRepositoryProvider =
    Provider<ComparisonSessionsRepository>(
      (ref) => LocalComparisonSessionsRepository(),
    );

class LocalComparisonSessionsRepository
    implements ComparisonSessionsRepository {
  @override
  Future<List<ComparisonSession>> load() async {
    final raw = (await SharedPreferences.getInstance()).getString(
      comparisonSessionsStorageKey,
    );
    return raw == null ? const [] : decode(raw);
  }

  static List<ComparisonSession> decode(String raw) {
    if (raw.length > maxSessionsStorageBytes ||
        utf8.encode(raw).length > maxSessionsStorageBytes) {
      throw const FormatException('Session storage too large');
    }
    final root = jsonDecode(raw);
    // Shipped v1 records use demo=false for Android. Unknown versions remain
    // recoverable and are never overwritten until successful load.
    if (root is! Map ||
        root['version'] is! int ||
        (root['version'] != 1 && root['version'] != 2) ||
        root['sessions'] is! List) {
      throw const FormatException('Unsupported session schema');
    }
    final version = root['version'] as int;
    final records = root['sessions'] as List;
    if (records.length > maxComparisonSessions) {
      throw const FormatException('Session limit exceeded');
    }
    final ids = <String>{};
    final sessions = <ComparisonSession>[];
    int integer(Object? value, int min, int max) {
      if (value is! int || value < min || value > max) {
        throw const FormatException('Invalid session number');
      }
      return value;
    }

    String string(Object? value, int max, {bool nonempty = false}) {
      if (value is! String ||
          value.length > max ||
          (nonempty && value.isEmpty)) {
        throw const FormatException('Invalid session text');
      }
      return value;
    }

    // v2 retains millisecond fields for clear v1 migration while storing exact
    // accepted microseconds. Conflicting fields indicate damaged storage.
    int timestamp(Map record, String field, int min, int max) {
      final millis = integer(record[field], 0, 8640000000000000);
      final micros = version == 1
          ? millis * 1000
          : integer(record['${field}Micros'], 0, 8640000000000000000);
      if (micros < min || micros > max || micros ~/ 1000 != millis) {
        throw const FormatException('Invalid session timestamp');
      }
      return micros;
    }

    for (final record in records) {
      if (record is! Map ||
          record['demo'] is! bool ||
          record['samples'] is! List) {
        throw const FormatException('Invalid session');
      }
      final legacySource = WifiDataSource.fromDemo(record['demo'] as bool);
      var source = legacySource;
      if (version == 2) {
        final value = record['source'];
        final matches = WifiDataSource.values.where((s) => s.name == value);
        if (matches.isEmpty) {
          throw const FormatException('Invalid session source');
        }
        source = matches.single;
        if ((source == WifiDataSource.demo) != record['demo']) {
          throw const FormatException('Conflicting session source');
        }
      }
      final id = string(record['id'], 128, nonempty: true);
      if (!ids.add(id)) throw const FormatException('Duplicate session');
      final bssid = string(record['bssid'], 128, nonempty: true);
      if (preferenceKey(bssid) != bssid) {
        throw const FormatException('Invalid session identity');
      }
      final start = timestamp(record, 'start', 0, 8640000000000000000);
      final end = timestamp(record, 'end', start, 8640000000000000000);
      final values = record['samples'] as List;
      if (values.length > maxSessionSamples) {
        throw const FormatException('Sample limit exceeded');
      }
      final samples = <SessionSample>[];
      var previous = start;
      for (final s in values) {
        if (s is! Map) throw const FormatException('Invalid sample');
        final at = timestamp(s, 'at', previous, end);
        previous = at;
        samples.add(
          SessionSample(
            at: DateTime.fromMicrosecondsSinceEpoch(at),
            rssi: integer(s['rssi'], -127, 0),
            frequency: integer(s['frequency'], 2000, 8000),
            width: integer(
              s['width'],
              source == WifiDataSource.windows || source == WifiDataSource.linux
                  ? 0
                  : 1,
              320,
            ),
            centerFrequency: s['center'] == null
                ? null
                : integer(s['center'], 0, 8000),
          ),
        );
      }
      sessions.add(
        ComparisonSession(
          id: id,
          bssid: bssid,
          ssid: string(record['ssid'], 256),
          label: string(record['label'], maxSessionLabelLength),
          start: DateTime.fromMicrosecondsSinceEpoch(start),
          end: DateTime.fromMicrosecondsSinceEpoch(end),
          source: source,
          reason: string(record['reason'], 128),
          samples: samples,
          missingBatches: integer(record['missing'], 0, 2147483647),
          cachedBatches: integer(record['cached'], 0, 2147483647),
        ),
      );
    }
    return List.unmodifiable(sessions);
  }

  @override
  Future<void> save(List<ComparisonSession> sessions) async {
    final raw = jsonEncode({
      'version': 2,
      'sessions': sessions.map((s) => s.toJson()).toList(),
    });
    decode(
      raw,
    ); // Same validation for writing and hydration, including Unicode.
    if (!await (await SharedPreferences.getInstance()).setString(
      comparisonSessionsStorageKey,
      raw,
    )) {
      throw StateError('Could not save sessions');
    }
  }
}
