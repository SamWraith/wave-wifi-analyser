import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/access_point.dart';
import '../models/analyser_state.dart';
import 'spectrum_axis.dart';

const graphColors = [
  Color(0xFF7C6EF6),
  Color(0xFF2CC9A8),
  Color(0xFFEBA85F),
  Color(0xFF5EA8EE),
  Color(0xFFE777AB),
  Color(0xFF97BA59),
];
Color pointColor(AccessPoint ap) =>
    graphColors[ap.bssid.codeUnits.fold<int>(0, (sum, v) => sum + v) %
        graphColors.length];

class SignalChart extends StatelessWidget {
  const SignalChart({
    super.key,
    required this.points,
    required this.band,
    this.history,
    this.time = false,
    this.hiddenBssids = const {},
  });
  final List<AccessPoint> points;
  final WifiBand band;
  final Map<String, List<SignalSample>>? history;
  final bool time;
  final Set<String> hiddenBssids;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 270,
    width: double.infinity,
    child: CustomPaint(
      painter: _SignalPainter(
        points,
        band,
        history ?? {},
        time,
        Theme.of(context).colorScheme.onSurfaceVariant,
        Theme.of(context).colorScheme.outlineVariant,
        hiddenBssids,
      ),
    ),
  );
}

class _SignalPainter extends CustomPainter {
  _SignalPainter(
    List<AccessPoint> points,
    this.band,
    Map<String, List<SignalSample>> history,
    this.time,
    this.labelColor,
    this.gridColor,
    Set<String> hiddenBssids,
  ) : hiddenBssids = Set.unmodifiable(hiddenBssids),
      points = List.unmodifiable(points),
      history = Map.unmodifiable({
        for (final point in points)
          point.bssid: List<SignalSample>.unmodifiable(
            history[point.bssid] ?? const [],
          ),
      }),
      axis = SpectrumAxis.forPoints(band, points);

  final List<AccessPoint> points;
  final WifiBand band;
  final Map<String, List<SignalSample>> history;
  final bool time;
  final Color labelColor, gridColor;
  final SpectrumAxis axis;
  final Set<String> hiddenBssids;

  void _label(Canvas canvas, String value, Offset at, {double size = 10}) {
    final text = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          color: labelColor,
          fontSize: size,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(canvas, at);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final area = Rect.fromLTRB(38, 18, size.width - 10, size.height - 35);
    if (area.width <= 0 || area.height <= 0) return;
    _paintGrid(canvas, area);
    canvas.save();
    canvas.clipRect(area);
    if (time) {
      _paintHistory(canvas, area);
    } else {
      _paintSpectrum(canvas, area);
    }
    canvas.restore();
    _paintAxis(canvas, area);
  }

  double _y(Rect area, num rssi) =>
      area.bottom - (rssi.clamp(-100, -20) + 100) / 80 * area.height;

  void _paintGrid(Canvas canvas, Rect area) {
    final paint = Paint()
      ..color = gridColor.withValues(alpha: .5)
      ..strokeWidth = 1;
    for (var rssi = -100; rssi <= -20; rssi += 20) {
      final y = _y(area, rssi);
      canvas.drawLine(Offset(area.left, y), Offset(area.right, y), paint);
      _label(canvas, '$rssi', Offset(0, y - 6));
    }
    _label(canvas, 'dBm', const Offset(0, 0), size: 9);
  }

  void _paintHistory(Canvas canvas, Rect area) {
    final all = history.values.expand((samples) => samples);
    if (all.isEmpty) return;
    final newest = all
        .map((sample) => sample.at.millisecondsSinceEpoch)
        .reduce(math.max);
    final oldest = all
        .map((sample) => sample.at.millisecondsSinceEpoch)
        .reduce(math.min);
    final span = math.max(1000, newest - oldest);
    for (final point in points) {
      if (hiddenBssids.contains(point.bssid)) continue;
      final samples = history[point.bssid]!;
      final path = Path();
      for (var i = 0; i < samples.length; i++) {
        final x =
            area.left +
            (samples[i].at.millisecondsSinceEpoch - oldest) / span * area.width;
        final y = _y(area, samples[i].rssi);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = pointColor(point)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round,
      );
      if (samples.length == 1) {
        canvas.drawCircle(
          Offset(area.left, _y(area, samples.first.rssi)),
          3,
          Paint()..color = pointColor(point),
        );
      }
    }
  }

  void _paintSpectrum(Canvas canvas, Rect area) {
    double x(num frequency) =>
        area.left + axis.fraction(frequency) * area.width;
    for (final point in points.reversed) {
      if (hiddenBssids.contains(point.bssid)) continue;
      // Illustrative envelope; bandwidth and center derive from the scan.
      final width = math.max(point.width, 20);
      final center = x(point.spectralCenter);
      final left = x(point.spectralCenter - width / 2);
      final right = x(point.spectralCenter + width / 2);
      final y = _y(area, point.rssi);
      final path = Path()
        ..moveTo(left, area.bottom)
        ..cubicTo(left, y, center - (right - left) / 6, y, center, y)
        ..cubicTo(center + (right - left) / 6, y, right, y, right, area.bottom);
      canvas.drawPath(
        Path.from(path)..close(),
        Paint()..color = pointColor(point).withValues(alpha: .13),
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = pointColor(point)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2,
      );
    }
  }

  void _paintAxis(Canvas canvas, Rect area) {
    if (time) {
      _label(canvas, 'Oldest sample', Offset(area.left, area.bottom + 12));
      _label(canvas, 'Latest', Offset(area.right - 32, area.bottom + 12));
      return;
    }
    for (final (channel, frequency) in axis.ticks) {
      final x = area.left + axis.fraction(frequency) * area.width;
      _label(canvas, '$channel', Offset(x - 6, area.bottom + 12));
    }
  }

  // Compare rendered content, not collection identity or unpainted metadata.
  List<Object> get _pointContent => [
    for (final point in points)
      time
          ? point.bssid
          : (
              point.bssid,
              point.rssi,
              point.frequency,
              point.spectralCenter,
              point.width,
            ),
  ];
  List<Object> get _historyContent => [
    for (final point in points)
      for (final sample in history[point.bssid]!)
        (point.bssid, sample.at.millisecondsSinceEpoch, sample.rssi),
  ];

  @override
  bool shouldRepaint(covariant _SignalPainter oldDelegate) =>
      band != oldDelegate.band ||
      time != oldDelegate.time ||
      labelColor != oldDelegate.labelColor ||
      gridColor != oldDelegate.gridColor ||
      !setEquals(hiddenBssids, oldDelegate.hiddenBssids) ||
      !listEquals(_pointContent, oldDelegate._pointContent) ||
      (time && !listEquals(_historyContent, oldDelegate._historyContent));
}
