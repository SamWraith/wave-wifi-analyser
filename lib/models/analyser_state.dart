import 'package:flutter/material.dart';

import 'access_point.dart';

@immutable
class SignalSample {
  const SignalSample(this.at, this.rssi);
  final DateTime at;
  final int rssi;
}

@immutable
class AnalyserState {
  AnalyserState({
    required this.demo,
    this.busy = false,
    this.cached = true,
    this.paused = false,
    this.permission = false,
    this.locationEnabled = false,
    this.wifiEnabled = false,
    this.status = 'Ready to scan',
    this.query = '',
    this.preferencesError,
    this.themeMode = ThemeMode.system,
    this.band = WifiBand.ghz24,
    this.minimumRssi = -95,
    this.excludeConnected = true,
    List<AccessPoint> accessPoints = const [],
    Map<String, List<SignalSample>> history = const {},
    this.lastUpdated,
  }) : accessPoints = List.unmodifiable(accessPoints),
       history = Map.unmodifiable(
         history.map(
           (key, value) =>
               MapEntry(key, List<SignalSample>.unmodifiable(value)),
         ),
       );
  const AnalyserState._fromFrozen({
    required this.demo,
    this.busy = false,
    this.cached = true,
    this.paused = false,
    this.permission = false,
    this.locationEnabled = false,
    this.wifiEnabled = false,
    this.status = 'Ready to scan',
    this.query = '',
    this.preferencesError,
    this.themeMode = ThemeMode.system,
    this.band = WifiBand.ghz24,
    this.minimumRssi = -95,
    this.excludeConnected = true,
    this.accessPoints = const [],
    this.history = const {},
    this.lastUpdated,
  });
  final bool demo,
      busy,
      cached,
      paused,
      permission,
      locationEnabled,
      wifiEnabled,
      excludeConnected;
  final String status, query;
  final String? preferencesError;
  final ThemeMode themeMode;
  final WifiBand band;
  final int minimumRssi;
  final List<AccessPoint> accessPoints;
  final Map<String, List<SignalSample>> history;
  final DateTime? lastUpdated;
  AnalyserState copyWith({
    bool? demo,
    bool? busy,
    bool? cached,
    bool? paused,
    bool? permission,
    bool? locationEnabled,
    bool? wifiEnabled,
    bool? excludeConnected,
    String? status,
    String? query,
    String? preferencesError,
    bool clearPreferencesError = false,
    ThemeMode? themeMode,
    WifiBand? band,
    int? minimumRssi,
    List<AccessPoint>? accessPoints,
    Map<String, List<SignalSample>>? history,
    DateTime? lastUpdated,
    bool clearLastUpdated = false,
  }) => AnalyserState._fromFrozen(
    demo: demo ?? this.demo,
    busy: busy ?? this.busy,
    cached: cached ?? this.cached,
    paused: paused ?? this.paused,
    permission: permission ?? this.permission,
    locationEnabled: locationEnabled ?? this.locationEnabled,
    wifiEnabled: wifiEnabled ?? this.wifiEnabled,
    excludeConnected: excludeConnected ?? this.excludeConnected,
    status: status ?? this.status,
    query: query ?? this.query,
    preferencesError: clearPreferencesError
        ? null
        : preferencesError ?? this.preferencesError,
    themeMode: themeMode ?? this.themeMode,
    band: band ?? this.band,
    minimumRssi: minimumRssi ?? this.minimumRssi,
    accessPoints: accessPoints == null
        ? this.accessPoints
        : List.unmodifiable(accessPoints),
    history: history == null
        ? this.history
        : Map.unmodifiable(
            history.map(
              (key, value) =>
                  MapEntry(key, List<SignalSample>.unmodifiable(value)),
            ),
          ),
    lastUpdated: clearLastUpdated ? null : lastUpdated ?? this.lastUpdated,
  );
}

@immutable
class WifiSnapshot {
  WifiSnapshot({
    required this.permission,
    required this.locationEnabled,
    required this.wifiEnabled,
    required this.status,
    required List<AccessPoint> accessPoints,
    this.fresh = false,
    this.scanRequested = false,
  }) : accessPoints = List.unmodifiable(accessPoints);
  final bool permission, locationEnabled, wifiEnabled, fresh, scanRequested;
  final String status;
  final List<AccessPoint> accessPoints;
  factory WifiSnapshot.fromMap(Map<dynamic, dynamic> m) => WifiSnapshot(
    permission: m['permission'] == true,
    locationEnabled: m['locationEnabled'] == true,
    wifiEnabled: m['wifiEnabled'] == true,
    status: m['status'] as String? ?? 'Ready',
    fresh: m['fresh'] == true,
    scanRequested: m['scanRequested'] == true,
    accessPoints: List.unmodifiable(
      (m['accessPoints'] as List? ?? []).map(
        (ap) => AccessPoint.fromMap(Map<dynamic, dynamic>.from(ap as Map)),
      ),
    ),
  );
}
