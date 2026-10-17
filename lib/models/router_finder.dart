import 'access_point.dart';

/// Ephemeral signal comparison, never a physical location measurement.
class RouterFinderState {
  const RouterFinderState({
    this.latest,
    this.baselineRssi,
    this.bestRssi,
    this.updated,
    this.samples = 0,
    this.sourceChanged = false,
  });

  final AccessPoint? latest;
  final int? baselineRssi, bestRssi;
  final DateTime? updated;
  final int samples;
  final bool sourceChanged;

  int? get change => latest == null ? null : latest!.rssi - baselineRssi!;
  String get guidance => switch (change) {
    null => 'Waiting for a new target observation',
    >= 3 => 'Warmer • stronger signal',
    <= -3 => 'Colder • weaker signal',
    _ => 'Similar signal to start',
  };

  RouterFinderState observe(AccessPoint ap, DateTime at) {
    // A band/channel change can alter propagation; start a new comparison.
    final reset = latest != null && latest!.frequency != ap.frequency;
    final baseline = reset ? ap.rssi : baselineRssi ?? ap.rssi;
    final best = reset ? ap.rssi : bestRssi;
    return RouterFinderState(
      latest: ap,
      baselineRssi: baseline,
      bestRssi: best == null || ap.rssi > best ? ap.rssi : best,
      samples: reset ? 1 : samples + 1,
      updated: at,
    );
  }
}
