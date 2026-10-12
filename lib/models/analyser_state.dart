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
    this.paused = false,
    this.permission = false,
    this.locationEnabled = false,
    this.wifiEnabled = false,
    this.status = 'Ready to scan',
    this.query = '',
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
  final bool demo,
      busy,
      paused,
      permission,
      locationEnabled,
      wifiEnabled,
      excludeConnected;
  final String status, query;
  final ThemeMode themeMode;
  final WifiBand band;
  final int minimumRssi;
  final List<AccessPoint> accessPoints;
  final Map<String, List<SignalSample>> history;
  final DateTime? lastUpdated;
  List<AccessPoint> get bandPoints =>
      accessPoints.where((ap) => ap.band == band).toList()
        ..sort((a, b) => b.rssi.compareTo(a.rssi));
  List<AccessPoint> get visiblePoints => bandPoints
      .where(
        (ap) =>
            ap.rssi >= minimumRssi &&
            ap.name.toLowerCase().contains(query.toLowerCase()),
      )
      .toList();
  AccessPoint? get connected =>
      accessPoints.where((ap) => ap.connected).firstOrNull;
  List<ChannelRating> get ratings =>
      rateChannels(accessPoints, band, excludeConnected: excludeConnected);
  AnalyserState copyWith({
    bool? demo,
    bool? busy,
    bool? paused,
    bool? permission,
    bool? locationEnabled,
    bool? wifiEnabled,
    bool? excludeConnected,
    String? status,
    String? query,
    ThemeMode? themeMode,
    WifiBand? band,
    int? minimumRssi,
    List<AccessPoint>? accessPoints,
    Map<String, List<SignalSample>>? history,
    DateTime? lastUpdated,
    bool clearLastUpdated = false,
  }) => AnalyserState(
    demo: demo ?? this.demo,
    busy: busy ?? this.busy,
    paused: paused ?? this.paused,
    permission: permission ?? this.permission,
    locationEnabled: locationEnabled ?? this.locationEnabled,
    wifiEnabled: wifiEnabled ?? this.wifiEnabled,
    excludeConnected: excludeConnected ?? this.excludeConnected,
    status: status ?? this.status,
    query: query ?? this.query,
    themeMode: themeMode ?? this.themeMode,
    band: band ?? this.band,
    minimumRssi: minimumRssi ?? this.minimumRssi,
    accessPoints: accessPoints ?? this.accessPoints,
    history: history ?? this.history,
    lastUpdated: clearLastUpdated ? null : lastUpdated ?? this.lastUpdated,
  );
}

@immutable
class WifiSnapshot {
  const WifiSnapshot({
    required this.permission,
    required this.locationEnabled,
    required this.wifiEnabled,
    required this.status,
    required this.accessPoints,
    this.fresh = false,
    this.scanRequested = false,
  });
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
