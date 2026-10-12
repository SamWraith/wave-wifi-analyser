import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/access_point.dart';
import '../models/analyser_state.dart';

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
  });
  final List<AccessPoint> points;
  final WifiBand band;
  final Map<String, List<SignalSample>>? history;
  final bool time;
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
      ),
    ),
  );
}

class _SignalPainter extends CustomPainter {
  _SignalPainter(
    this.points,
    this.band,
    this.history,
    this.time,
    this.labelColor,
    this.gridColor,
  );
  final List<AccessPoint> points;
  final WifiBand band;
  final Map<String, List<SignalSample>> history;
  final bool time;
  final Color labelColor, gridColor;
  void label(
    Canvas canvas,
    String value,
    Offset at, {
    Color? color,
    double size = 10,
  }) {
    final text = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          color: color ?? labelColor,
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
    double y(num rssi) =>
        area.bottom - (rssi.clamp(-100, -20) + 100) / 80 * area.height;
    for (var rssi = -100; rssi <= -20; rssi += 20) {
      canvas.drawLine(
        Offset(area.left, y(rssi)),
        Offset(area.right, y(rssi)),
        Paint()
          ..color = gridColor.withValues(alpha: .5)
          ..strokeWidth = 1,
      );
      label(canvas, '$rssi', Offset(0, y(rssi) - 6));
    }
    label(canvas, 'dBm', const Offset(0, 0), size: 9);
    canvas.save();
    canvas.clipRect(area);
    if (time) {
      final all = points
          .expand((ap) => history[ap.bssid] ?? <SignalSample>[])
          .toList();
      if (all.isNotEmpty) {
        final newest = all
            .map((s) => s.at.millisecondsSinceEpoch)
            .reduce(math.max);
        final oldest = all
            .map((s) => s.at.millisecondsSinceEpoch)
            .reduce(math.min);
        final span = math.max(1000, newest - oldest);
        for (final ap in points) {
          final samples = history[ap.bssid] ?? [];
          final path = Path();
          for (var i = 0; i < samples.length; i++) {
            final x =
                area.left +
                (samples[i].at.millisecondsSinceEpoch - oldest) /
                    span *
                    area.width;
            if (i == 0) {
              path.moveTo(x, y(samples[i].rssi));
            } else {
              path.lineTo(x, y(samples[i].rssi));
            }
          }
          canvas.drawPath(
            path,
            Paint()
              ..color = pointColor(ap)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.5
              ..strokeCap = StrokeCap.round,
          );
          if (samples.length == 1) {
            canvas.drawCircle(
              Offset(area.left, y(samples.first.rssi)),
              3,
              Paint()..color = pointColor(ap),
            );
          }
        }
      }
    } else {
      final bounds = switch (band) {
        WifiBand.ghz24 => (2402.0, 2487.0),
        WifiBand.ghz5 => (5150.0, 5850.0),
        WifiBand.ghz6 => (5925.0, 7125.0),
      };
      double x(num f) =>
          area.left + (f - bounds.$1) / (bounds.$2 - bounds.$1) * area.width;
      for (final ap in points.reversed) {
        // Smooth envelope is illustrative; bandwidth and center derive from scan.
        final width = math.max(ap.width, 20);
        final center = x(ap.spectralCenter),
            left = x(ap.spectralCenter - width / 2),
            right = x(ap.spectralCenter + width / 2);
        final path = Path()
          ..moveTo(left, area.bottom)
          ..cubicTo(
            left,
            y(ap.rssi),
            center - ((right - left) / 6),
            y(ap.rssi),
            center,
            y(ap.rssi),
          )
          ..cubicTo(
            center + ((right - left) / 6),
            y(ap.rssi),
            right,
            y(ap.rssi),
            right,
            area.bottom,
          );
        final fill = Path.from(path)..close();
        canvas.drawPath(
          fill,
          Paint()..color = pointColor(ap).withValues(alpha: .13),
        );
        canvas.drawPath(
          path,
          Paint()
            ..color = pointColor(ap)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.2,
        );
      }
    }
    canvas.restore();
    if (time) {
      label(canvas, 'Oldest sample', Offset(area.left, area.bottom + 12));
      label(canvas, 'Latest', Offset(area.right - 32, area.bottom + 12));
    } else {
      final ticks = switch (band) {
        WifiBand.ghz24 => [1, 3, 5, 7, 9, 11, 13],
        WifiBand.ghz5 => [36, 64, 100, 132, 165],
        WifiBand.ghz6 => [1, 49, 97, 145, 193, 233],
      };
      final bounds = switch (band) {
        WifiBand.ghz24 => (2402.0, 2487.0),
        WifiBand.ghz5 => (5150.0, 5850.0),
        WifiBand.ghz6 => (5925.0, 7125.0),
      };
      for (final ch in ticks) {
        final f =
            (band == WifiBand.ghz24
                ? 2407
                : band == WifiBand.ghz5
                ? 5000
                : 5950) +
            ch * 5;
        final x =
            area.left + (f - bounds.$1) / (bounds.$2 - bounds.$1) * area.width;
        label(canvas, '$ch', Offset(x - 6, area.bottom + 12));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SignalPainter oldDelegate) => true;
}
