import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/access_point.dart';
import '../models/analyser_state.dart';
import 'spectrum_axis.dart';
import 'spectrum_envelope.dart';

/// One plot geometry for rendering and cursor inspection. Hidden curves do not
/// change these bounds. Inspection follows visible envelopes or real samples.
class ChartCoordinates {
  ChartCoordinates(
    this.band,
    List<AccessPoint> points,
    Map<String, List<SignalSample>> history,
  ) : points = List.unmodifiable(points),
      history = Map.unmodifiable({
        for (final point in points)
          point.bssid: List<SignalSample>.unmodifiable(
            history[point.bssid] ?? const [],
          ),
      }),
      spectrum = SpectrumAxis.forPoints(band, points) {
    final times = [
      for (final ap in points)
        for (final sample in history[ap.bssid] ?? const <SignalSample>[])
          sample.at.millisecondsSinceEpoch,
    ];
    oldest = times.isEmpty ? null : times.reduce(math.min);
    newest = times.isEmpty ? null : times.reduce(math.max);
    final observations = times.toSet().toList()..sort();
    _observationIndex = {
      for (var i = 0; i < observations.length; i++) observations[i]: i,
    };
    _historyHits = List.unmodifiable([
      for (final point in this.points)
        for (final sample in this.history[point.bssid]!)
          ChartHit(
            point,
            Offset(
              historyFraction(sample),
              1 - (sample.rssi.clamp(-100, -20) + 100) / 80,
            ),
            sample.rssi.toDouble(),
            sample: sample,
          ),
    ]);
  }
  final WifiBand band;
  final List<AccessPoint> points;
  final Map<String, List<SignalSample>> history;
  final SpectrumAxis spectrum;
  late final int? oldest, newest;
  late final Map<int, int> _observationIndex;
  late final List<ChartHit> _historyHits;

  /// Break paths when another plotted AP was observed without this AP, or
  /// observations are separated by more than two foreground scan intervals.
  bool hasGap(SignalSample previous, SignalSample next) =>
      next.at.difference(previous.at) > const Duration(seconds: 70) ||
      _observationIndex[next.at.millisecondsSinceEpoch]! -
              _observationIndex[previous.at.millisecondsSinceEpoch]! >
          1;
  int get span => (newest ?? 0) - (oldest ?? 0);
  static Rect area(Size size) =>
      Rect.fromLTRB(38, 18, size.width - 10, size.height - 35);
  static double y(Rect area, num rssi) =>
      area.bottom - (rssi.clamp(-100, -20) + 100) / 80 * area.height;
  static double strength(double fraction) =>
      -100 + (1 - fraction.clamp(0, 1)) * 80;
  double frequency(double fraction) =>
      spectrum.minimum +
      fraction.clamp(0, 1) * (spectrum.maximum - spectrum.minimum);
  double historyFraction(SignalSample sample) =>
      (sample.at.millisecondsSinceEpoch - oldest!) / math.max(1, span);
  DateTime? time(double fraction) => oldest == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(
          oldest! + (fraction.clamp(0, 1) * span).round(),
        );

  /// Select the closest visible curve at the requested frequency. Outside
  /// envelopes, clamp to their edges; never leave the marker in empty space.
  /// History selects actual timestamps first, then the nearest AP vertically.
  ChartHit? inspect(
    Offset cursor,
    Size plotSize, {
    required bool timeGraph,
    Set<String> hiddenBssids = const {},
  }) {
    ChartHit? best;
    var bestX = double.infinity, bestDistance = double.infinity;
    final candidates = timeGraph
        ? _historyHits.where((hit) => !hiddenBssids.contains(hit.point.bssid))
        : points
              .where((point) => !hiddenBssids.contains(point.bssid))
              .map((point) => _envelopeHit(point, cursor.dx));
    for (final hit in candidates) {
      final dx = (hit.fraction.dx - cursor.dx).abs() * plotSize.width;
      final dy = (hit.fraction.dy - cursor.dy).abs() * plotSize.height;
      final distance = dx * dx + dy * dy;
      final closer = timeGraph
          ? dx < bestX - .001 ||
                ((dx - bestX).abs() <= .001 && distance < bestDistance)
          : distance < bestDistance;
      if (closer) {
        best = hit;
        bestX = dx;
        bestDistance = distance;
      }
    }
    return best;
  }

  ChartHit _envelopeHit(AccessPoint point, double fraction) {
    final mhz = frequency(fraction).clamp(
      point.spectralCenter - SpectrumEnvelope.halfWidth(point),
      point.spectralCenter + SpectrumEnvelope.halfWidth(point),
    );
    final rssi = SpectrumEnvelope.strengthAt(point, mhz);
    return ChartHit(
      point,
      Offset(spectrum.fraction(mhz), 1 - (rssi + 100) / 80),
      rssi,
    );
  }

  String spectrumLabel(double fraction) {
    final mhz = frequency(fraction);
    final centers = switch (band) {
      WifiBand.ghz24 => [for (var ch = 1; ch <= 13; ch++) 2407 + ch * 5, 2484],
      WifiBand.ghz5 => [
        for (var ch = 184; ch <= 196; ch++) 4000 + ch * 5,
        for (var ch = 32; ch <= 177; ch++) 5000 + ch * 5,
      ],
      WifiBand.ghz6 => [5935, for (var ch = 1; ch <= 233; ch++) 5950 + ch * 5],
    };
    final nearest = centers.reduce(
      (a, b) => (a - mhz).abs() <= (b - mhz).abs() ? a : b,
    );
    final frequencyLabel = '${mhz.toStringAsFixed(1)} MHz';
    // Guard bands and the 5 GHz inter-band gap have no channel coordinate.
    if ((nearest - mhz).abs() > 10) return frequencyLabel;
    final channel = AccessPoint(
      ssid: '',
      bssid: '',
      rssi: -100,
      frequency: nearest,
    ).channel;
    final prefix = (nearest - mhz).abs() < .05 ? 'CH' : 'Near CH';
    return '$prefix $channel · $frequencyLabel';
  }
}

/// A marker on a rendered curve, with a real sample only for history.
class ChartHit {
  const ChartHit(this.point, this.fraction, this.rssi, {this.sample});
  final AccessPoint point;
  final Offset fraction;
  final double rssi;
  final SignalSample? sample;
}
