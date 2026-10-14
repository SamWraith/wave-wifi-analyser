import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/access_point.dart';
import '../models/analyser_state.dart';
import 'spectrum_axis.dart';
import 'spectrum_envelope.dart';
import 'chart_coordinates.dart';
import 'chart_inspection.dart';

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
    this.height = 270,
    this.onEscape,
  });
  final List<AccessPoint> points;
  final WifiBand band;
  final Map<String, List<SignalSample>>? history;
  final bool time;
  final double height;
  final VoidCallback? onEscape;
  final Set<String> hiddenBssids;
  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.bodySmall!
        .copyWith(fontSize: 12, fontWeight: FontWeight.w500, height: 1);
    final textScaler = MediaQuery.textScalerOf(context);
    final probe = TextPainter(
      text: TextSpan(text: '-100', style: labelStyle),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
    )..layout();
    final coordinates = ChartCoordinates(
      band,
      points,
      history ?? {},
      plotInsets: EdgeInsets.fromLTRB(
        math.max(38, probe.width + 8),
        math.max(18, probe.height * 1.5),
        10,
        math.max(35, probe.height + 18),
      ),
    );
    probe.dispose();
    return ChartInspection(
      height: height,
      onEscape: onEscape,
      time: time,
      coordinates: coordinates,
      hiddenBssids: hiddenBssids,
      child: CustomPaint(
        painter: _SignalPainter(
          points,
          band,
          history ?? {},
          time,
          Theme.of(context).colorScheme.onSurfaceVariant,
          Theme.of(context).colorScheme.outlineVariant,
          hiddenBssids,
          coordinates,
          labelStyle,
          textScaler,
        ),
      ),
    );
  }
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
    this.coordinates,
    this.labelStyle,
    this.textScaler,
  ) : hiddenBssids = Set.unmodifiable(hiddenBssids),
      points = List.unmodifiable(points),
      history = Map.unmodifiable({
        for (final point in points)
          point.bssid: List<SignalSample>.unmodifiable(
            history[point.bssid] ?? const [],
          ),
      }),
      axis = coordinates.spectrum;

  final List<AccessPoint> points;
  final WifiBand band;
  final Map<String, List<SignalSample>> history;
  final bool time;
  final Color labelColor, gridColor;
  final SpectrumAxis axis;
  final ChartCoordinates coordinates;
  final Set<String> hiddenBssids;
  final TextStyle labelStyle;
  final TextScaler textScaler;

  TextPainter _text(String value) => TextPainter(
    text: TextSpan(
      text: value,
      style: labelStyle.copyWith(color: labelColor),
    ),
    textDirection: TextDirection.ltr,
    textScaler: textScaler,
  )..layout();

  void _label(Canvas canvas, String value, Offset at, {bool right = false}) {
    final text = _text(value);
    text.paint(canvas, Offset(at.dx - (right ? text.width : 0), at.dy));
    text.dispose();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final area = coordinates.plotArea(size);
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

  double _y(Rect area, num rssi) => ChartCoordinates.y(area, rssi);

  void _paintGrid(Canvas canvas, Rect area) {
    final paint = Paint()
      ..color = gridColor.withValues(alpha: .5)
      ..strokeWidth = 1;
    for (var rssi = -100; rssi <= -20; rssi += 20) {
      final y = _y(area, rssi);
      canvas.drawLine(Offset(area.left, y), Offset(area.right, y), paint);
      _label(canvas, '$rssi', Offset(0, y - textScaler.scale(12) / 2));
    }
    _label(canvas, 'dBm', const Offset(0, 0));
  }

  void _paintHistory(Canvas canvas, Rect area) {
    if (coordinates.oldest == null) return;
    for (final point in points) {
      if (hiddenBssids.contains(point.bssid)) continue;
      final samples = history[point.bssid]!;
      final path = Path();
      for (var i = 0; i < samples.length; i++) {
        final x =
            area.left + coordinates.historyFraction(samples[i]) * area.width;
        final y = _y(area, samples[i].rssi);
        if (i == 0 || coordinates.hasGap(samples[i - 1], samples[i])) {
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
      // Dots retain isolated observations when adjacent path segments have gaps.
      for (final sample in samples) {
        canvas.drawCircle(
          Offset(
            area.left + coordinates.historyFraction(sample) * area.width,
            _y(area, sample.rssi),
          ),
          3,
          Paint()..color = pointColor(point),
        );
      }
    }
  }

  void _paintSpectrum(Canvas canvas, Rect area) {
    for (final point in points.reversed) {
      if (hiddenBssids.contains(point.bssid)) continue;
      final path = SpectrumEnvelope.path(point, axis, area);
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
      final oldest = _text('Oldest sample');
      final latest = _text('Latest');
      final short = oldest.width + latest.width + 16 > area.width;
      final compactOldest = _text('Oldest');
      final showOldest =
          !short || compactOldest.width + latest.width + 16 <= area.width;
      oldest.dispose();
      latest.dispose();
      compactOldest.dispose();
      if (showOldest) {
        _label(
          canvas,
          short ? 'Oldest' : 'Oldest sample',
          Offset(area.left, area.bottom + 12),
        );
      }
      _label(
        canvas,
        'Latest',
        Offset(area.right, area.bottom + 12),
        right: true,
      );
      return;
    }
    double lastRight = double.negativeInfinity;
    for (final (channel, frequency) in axis.ticks) {
      final x = area.left + axis.fraction(frequency) * area.width;
      final text = _text('$channel');
      final left = (x - text.width / 2).clamp(
        area.left,
        math.max(area.left, area.right - text.width),
      );
      if (left >= lastRight + 8) {
        text.paint(canvas, Offset(left.toDouble(), area.bottom + 12));
        lastRight = left + text.width;
      }
      text.dispose();
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
      labelStyle != oldDelegate.labelStyle ||
      textScaler != oldDelegate.textScaler ||
      coordinates.plotInsets != oldDelegate.coordinates.plotInsets ||
      !setEquals(hiddenBssids, oldDelegate.hiddenBssids) ||
      !listEquals(_pointContent, oldDelegate._pointContent) ||
      (time && !listEquals(_historyContent, oldDelegate._historyContent));
}
