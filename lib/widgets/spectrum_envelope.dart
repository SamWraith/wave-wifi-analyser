import 'dart:math' as math;

import 'package:flutter/painting.dart';

import '../models/access_point.dart';
import 'spectrum_axis.dart';

/// One illustrative envelope definition for both rendering and inspection.
/// Values along this shape are not RF samples.
abstract final class SpectrumEnvelope {
  static double halfWidth(AccessPoint point) => math.max(point.width, 20) / 2;

  static Path path(AccessPoint point, SpectrumAxis axis, Rect area) {
    double x(num frequency) =>
        area.left + axis.fraction(frequency) * area.width;
    final center = x(point.spectralCenter);
    final left = x(point.spectralCenter - halfWidth(point));
    final right = x(point.spectralCenter + halfWidth(point));
    final peak =
        area.bottom - (point.rssi.clamp(-100, -20) + 100) / 80 * area.height;
    return Path()
      ..moveTo(left, area.bottom)
      ..cubicTo(left, peak, center - (right - left) / 6, peak, center, peak)
      ..cubicTo(
        center + (right - left) / 6,
        peak,
        right,
        peak,
        right,
        area.bottom,
      );
  }

  static double strengthAt(AccessPoint point, double frequency) {
    final progress =
        (1 - (frequency - point.spectralCenter).abs() / halfWidth(point)).clamp(
          0.0,
          1.0,
        );
    // Half-envelope Bézier x is 2t² - t³. Invert its monotonic x to
    // evaluate the same y drawn by path(), rather than a parabola or estimate.
    var low = 0.0, high = 1.0;
    for (var i = 0; i < 32; i++) {
      final t = (low + high) / 2;
      if (2 * t * t - t * t * t < progress) {
        low = t;
      } else {
        high = t;
      }
    }
    final t = (low + high) / 2;
    return -100 +
        (point.rssi.clamp(-100, -20) + 100) *
            (1 - math.pow(1 - t, 3).toDouble());
  }
}
