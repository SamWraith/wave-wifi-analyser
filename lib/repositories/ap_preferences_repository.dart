import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/ap_preference.dart';

const maxApPreferences = 256;
const maxAliasLength = 64;
const apPreferencesStorageKey = 'apPreferences';

abstract interface class ApPreferencesRepository {
  Future<Map<String, ApPreference>> load();
  Future<void> save(Map<String, ApPreference> entries);
}

final apPreferencesRepositoryProvider = Provider<ApPreferencesRepository>(
  (ref) => LocalApPreferencesRepository(),
);

class LocalApPreferencesRepository implements ApPreferencesRepository {
  @override
  Future<Map<String, ApPreference>> load() async {
    final raw = (await SharedPreferences.getInstance()).getString(
      apPreferencesStorageKey,
    );
    if (raw == null) return const {};
    if (raw.length > 262144) {
      throw const FormatException('AP preferences too large');
    }
    final decoded = jsonDecode(raw);
    if (decoded is! Map) throw const FormatException('Invalid AP preferences');
    final version = decoded['version'];
    // Version 0 used a BSSID-keyed map. Read it without discarding identities;
    // the next successful edit writes the version 1 list envelope.
    final Object? records;
    if (version == 0 && decoded['entries'] is Map) {
      records = (decoded['entries'] as Map).entries.map((e) {
        if (e.value is! Map) throw const FormatException('Invalid AP entry');
        return {...e.value as Map, 'bssid': e.key};
      }).toList();
    } else if (version == 1) {
      records = decoded['entries'];
    } else {
      throw const FormatException('Unsupported AP preferences version');
    }
    if (records is! List || records.length > maxApPreferences) {
      throw const FormatException('Invalid AP entries');
    }
    final result = <String, ApPreference>{};
    for (final item in records) {
      if (item is! Map ||
          item['bssid'] is! String ||
          item['ssid'] is! String ||
          item['favorite'] is! bool ||
          (item['alias'] != null && item['alias'] is! String)) {
        throw const FormatException('Invalid AP entry');
      }
      final key = preferenceKey(item['bssid'] as String);
      final alias = (item['alias'] as String?)?.trim();
      if (key.isEmpty ||
          key.length > 128 ||
          (item['ssid'] as String).length > 256 ||
          (alias?.length ?? 0) > maxAliasLength ||
          result.containsKey(key)) {
        throw const FormatException('Invalid AP identity');
      }
      if (item['favorite'] == true || (alias?.isNotEmpty ?? false)) {
        result[key] = ApPreference(
          bssid: key,
          ssid: item['ssid'] as String,
          alias: alias?.isEmpty == true ? null : alias,
          favorite: item['favorite'] as bool,
        );
      }
    }
    return Map.unmodifiable(result);
  }

  @override
  Future<void> save(Map<String, ApPreference> entries) async {
    if (entries.length > maxApPreferences) {
      throw StateError('AP preference limit reached');
    }
    final raw = jsonEncode({
      'version': 1,
      'entries': entries.values.map((e) => e.toJson()).toList(),
    });
    if (raw.length > 262144) {
      throw StateError('AP preferences too large');
    }
    if (!await (await SharedPreferences.getInstance()).setString(
      apPreferencesStorageKey,
      raw,
    )) {
      throw StateError('Could not persist AP preferences');
    }
  }
}
