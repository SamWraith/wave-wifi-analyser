import 'dart:math' as math;

import '../models/access_point.dart';

/// Shared frequency range and channel ticks for spectrum paths and labels.
class SpectrumAxis {
  const SpectrumAxis(this.minimum, this.maximum, this.ticks);

  factory SpectrumAxis.forPoints(WifiBand band, List<AccessPoint> points) {
    final (minimum, maximum, channels, base) = switch (band) {
      WifiBand.ghz24 => (2402.0, 2487.0, [1, 3, 5, 7, 9, 11, 13], 2407),
      WifiBand.ghz5 => (5150.0, 5850.0, [36, 64, 100, 132, 165], 5000),
      WifiBand.ghz6 => (5925.0, 7125.0, [1, 49, 97, 145, 193, 233], 5950),
    };
    var low = minimum;
    var high = maximum;
    for (final point in points) {
      final halfWidth = math.max(point.width, 20) / 2;
      low = math.min(low, point.spectralCenter - halfWidth);
      high = math.max(high, point.spectralCenter + halfWidth);
    }
    final ticks = [
      for (final channel in channels) (channel, base + channel * 5),
    ];
    if (band == WifiBand.ghz5 && low < 5000) {
      // Public-safety channels use the 4000 MHz base, unlike ordinary 5 GHz.
      for (final point in points.where((point) => point.frequency < 5000)) {
        final tick = (point.channel, point.frequency);
        if (!ticks.contains(tick)) ticks.add(tick);
      }
      ticks.sort((a, b) => a.$2.compareTo(b.$2));
    }
    return SpectrumAxis(low, high, List.unmodifiable(ticks));
  }

  final double minimum, maximum;
  final List<(int channel, int frequency)> ticks;

  double fraction(num frequency) => (frequency - minimum) / (maximum - minimum);
}
