import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/access_point.dart';
import '../models/analyser_state.dart';
import 'spectrum_axis.dart';

/// One plot geometry for rendering and cursor inspection. Hidden curves do not
/// change these bounds. Cursor values are coordinates, never measured samples.
class ChartCoordinates {
  ChartCoordinates(
    this.band,
    List<AccessPoint> points,
    Map<String, List<SignalSample>> history,
  ) : spectrum = SpectrumAxis.forPoints(band, points) {
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
  }
  final WifiBand band;
  final SpectrumAxis spectrum;
  late final int? oldest, newest;
  late final Map<int, int> _observationIndex;

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
