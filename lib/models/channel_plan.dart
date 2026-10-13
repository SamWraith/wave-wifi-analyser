import 'access_point.dart';

/// Planning inputs are session-local; channel validity is geometry, not regulation.
class PlanningAssumptions {
  PlanningAssumptions({this.width = 20, List<int> channels = const []})
    : channels = List.unmodifiable(channels.take(64));
  final int width;
  final List<int> channels;
}

List<int> planningWidths(WifiBand band) =>
    band == WifiBand.ghz24 ? const [20, 40] : const [20, 40, 80, 160];

List<int> defaultPlanningChannels(WifiBand band, [int width = 20]) {
  final channels = switch (band) {
    WifiBand.ghz24 => const [1, 6, 11],
    WifiBand.ghz5 => const [36, 40, 44, 48, 149, 153, 157, 161],
    WifiBand.ghz6 => List.generate(15, (i) => 5 + i * 16),
  };
  return List.unmodifiable(
    channels.where(
      (channel) => planningCenters(band, channel, width).isNotEmpty,
    ),
  );
}

/// Exceptional frequencies cannot use the ordinary 5 MHz channel formula.
int? planningFrequency(WifiBand band, int channel) => switch (band) {
  WifiBand.ghz24 =>
    channel == 14
        ? 2484
        : channel >= 1 && channel <= 13
        ? 2407 + channel * 5
        : null,
  WifiBand.ghz5 =>
    channel >= 182 && channel <= 196 && channel.isEven
        ? 4000 + channel * 5
        : [
            ...List.generate(8, (i) => 36 + i * 4),
            ...List.generate(12, (i) => 100 + i * 4),
            ...List.generate(8, (i) => 149 + i * 4),
          ].contains(channel)
        ? 5000 + channel * 5
        : null,
  WifiBand.ghz6 =>
    channel == 2
        ? 5935
        : channel >= 1 && channel <= 233 && (channel - 1) % 4 == 0
        ? 5950 + channel * 5
        : null,
};

/// Each primary may have two 2.4 GHz 40 MHz extension choices.
List<int> planningCenters(WifiBand band, int channel, int width) {
  final frequency = planningFrequency(band, channel);
  if (frequency == null || !planningWidths(band).contains(width)) {
    return const [];
  }
  if (width == 20) return [frequency];
  if (band == WifiBand.ghz24) {
    if (channel == 14) return const [];
    return [if (channel >= 5) frequency - 10, if (channel <= 9) frequency + 10];
  }
  if (band == WifiBand.ghz6 && channel == 2 ||
      band == WifiBand.ghz5 && channel >= 182) {
    return const [];
  }
  final start = band == WifiBand.ghz6
      ? 1
      : channel < 100
      ? 36
      : channel < 149
      ? 100
      : 149;
  final end = band == WifiBand.ghz6
      ? 233
      : start == 36
      ? 64
      : start == 100
      ? 144
      : 177;
  final count = width ~/ 20;
  final first = start + ((channel - start) ~/ (4 * count)) * 4 * count;
  if (first + (count - 1) * 4 > end) return const [];
  return [planningFrequency(band, first)! + (count - 1) * 10];
}

/// Reject the entire edit on errors; never silently drop malformed entries.
List<int> parsePlanningChannels(String input, WifiBand band, int width) {
  if (input.trim().isEmpty) return const [];
  if (input.length > 512) {
    throw const FormatException('Use at most 64 channels.');
  }
  final tokens = input.trim().split(RegExp(r'[,\s]+'));
  if (tokens.length > 64) {
    throw const FormatException('Use at most 64 channels.');
  }
  final channels = <int>{};
  for (final token in tokens) {
    if (!RegExp(r'^[0-9]+$').hasMatch(token)) {
      throw const FormatException(
        'Use channel numbers separated by commas or spaces.',
      );
    }
    final channel = int.tryParse(token);
    if (channel == null || planningCenters(band, channel, width).isEmpty) {
      throw FormatException(
        'Channel $token has no supported $width MHz plan in ${band.label}.',
      );
    }
    channels.add(channel);
  }
  return channels.toList()..sort();
}

class OverlapContributor {
  const OverlapContributor(this.ap, this.score);
  final AccessPoint ap;
  final double score;
}

class ChannelPlan {
  ChannelPlan(
    this.channel,
    this.center,
    this.width,
    List<OverlapContributor> contributors,
  ) : contributors = List.unmodifiable(contributors.take(3)),
      contributorCount = contributors.length,
      score = contributors.fold(0, (sum, item) => sum + item.score);
  final int channel, center, width;

  /// Strongest three only; count/score still include every observed contributor.
  final List<OverlapContributor> contributors;
  final int contributorCount;
  final double score;
}

List<ChannelPlan> planChannels(
  List<AccessPoint> aps,
  WifiBand band,
  PlanningAssumptions assumptions, {
  bool excludeConnected = true,
}) {
  final channels = assumptions.channels.isEmpty
      ? defaultPlanningChannels(band, assumptions.width)
      : assumptions.channels;
  final plans = <ChannelPlan>[];
  for (final channel in channels) {
    for (final center in planningCenters(band, channel, assumptions.width)) {
      final contributors = <OverlapContributor>[];
      for (final ap in aps) {
        if (ap.band != band || excludeConnected && ap.connected) continue;
        final score = overlapContribution(ap, center, assumptions.width);
        if (score > 0) contributors.add(OverlapContributor(ap, score));
      }
      contributors.sort((a, b) {
        final score = b.score.compareTo(a.score);
        return score != 0 ? score : a.ap.bssid.compareTo(b.ap.bssid);
      });
      plans.add(ChannelPlan(channel, center, assumptions.width, contributors));
    }
  }
  plans.sort((a, b) {
    final score = a.score.compareTo(b.score);
    if (score != 0) return score;
    final channel = a.channel.compareTo(b.channel);
    return channel != 0 ? channel : a.center.compareTo(b.center);
  });
  return List.unmodifiable(plans);
}
