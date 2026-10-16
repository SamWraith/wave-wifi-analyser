import 'package:flutter/foundation.dart';

import 'access_point.dart';
import 'analyser_state.dart';
import 'scan_freshness.dart';
import 'wifi_data_source.dart';

enum WifiProblem { weakSignal, crowdedChannel }

@immutable
class WifiEvidence {
  const WifiEvidence({
    required this.ap,
    required this.at,
    required this.overlap,
    required this.candidate,
    this.source = WifiDataSource.android,
  });
  final WifiDataSource source;
  final AccessPoint ap;
  final DateTime at;
  final double overlap;
  final int candidate;
}

@immutable
class WifiGuidanceState {
  const WifiGuidanceState({
    this.problem,
    this.baseline,
    this.current,
    this.waiting = false,
    this.message,
  });
  final WifiProblem? problem;
  final WifiEvidence? baseline, current;
  final bool waiting;
  final String? message;
}

String? guidanceBlocker(AnalyserState scan, DateTime now) {
  if (scan.demo) {
    return 'Demo data can illustrate the charts, but cannot diagnose your WiFi. Use live Android, macOS or Windows scans for this check.';
  }
  if (scan.paused) {
    return 'Scanning is paused. Resume scanning before starting or rechecking.';
  }
  if (!scan.permission || !scan.locationEnabled || !scan.wifiEnabled) {
    return 'Live scanning needs location permission, Location services and WiFi. Use scan recovery above.';
  }
  if (scan.accessPoints.isEmpty) {
    return 'No access points observed. Connect to WiFi and scan again.';
  }
  if (scan.cached || isScanStale(scan.lastUpdated, now)) {
    return 'Results are cached or older than two minutes. Request a fresh scan before comparing.';
  }
  final ap = scan.accessPoints.where((ap) => ap.connected).firstOrNull;
  if (ap == null) {
    return 'No connected access point identified. Connect to WiFi and scan again.';
  }
  final last = scan.history[ap.bssid]?.lastOrNull;
  if (last == null || last.at != scan.lastUpdated || last.rssi != ap.rssi) {
    return 'The connected access point has no fresh observation in this result. Scan again.';
  }
  return null;
}

WifiEvidence wifiEvidence(AnalyserState scan) {
  final ap = scan.accessPoints.firstWhere((ap) => ap.connected);
  return WifiEvidence(
    ap: ap,
    source: scan.source,
    at: scan.lastUpdated!,
    overlap: estimateChannelOverlap(
      scan.accessPoints,
      ap.band,
      ap.spectralCenter,
    ),
    candidate: rateChannels(scan.accessPoints, ap.band).first.channel,
  );
}

String guidanceAction(
  WifiProblem problem,
  WifiEvidence evidence,
) => switch (problem) {
  WifiProblem.weakSignal =>
    evidence.ap.rssi < -70
        ? 'Move closer to your router, then recheck from the new position.'
        : 'Signal is not weak in this observation. Recheck at the spot where WiFi feels slow.',
  WifiProblem.crowdedChannel =>
    'Check whether your router supports channel ${evidence.candidate} on ${evidence.ap.band.label}. If you change its channel, reconnect and recheck.',
};

String guidanceComparison(
  WifiProblem problem,
  WifiEvidence before,
  WifiEvidence after,
) {
  if (problem == WifiProblem.weakSignal) {
    final delta = after.ap.rssi - before.ap.rssi;
    return delta == 0
        ? 'Received signal is unchanged in this recheck.'
        : 'Received signal ${delta > 0 ? 'increased' : 'decreased'} by ${delta.abs()} dB in this recheck.';
  }
  final delta = after.overlap - before.overlap;
  return delta.abs() < .001
      ? 'Estimated overlap is unchanged in this recheck.'
      : 'Estimated overlap ${delta < 0 ? 'decreased' : 'increased'} in this recheck. This is a relative channel heuristic.';
}
