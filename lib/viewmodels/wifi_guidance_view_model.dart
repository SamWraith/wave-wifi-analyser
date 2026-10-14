import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/wifi_guidance.dart';
import '../models/analyser_state.dart';
import '../models/wifi_data_source.dart';
import 'analyser_view_model.dart';

final guidanceClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);
final wifiGuidanceProvider =
    NotifierProvider.autoDispose<WifiGuidanceViewModel, WifiGuidanceState>(
      WifiGuidanceViewModel.new,
    );

/// Ephemeral guided check. Baseline belongs to one BSSID and one live workspace.
class WifiGuidanceViewModel extends Notifier<WifiGuidanceState> {
  int? _requiredTimestamp;
  int? _requiredCompletion;

  @override
  WifiGuidanceState build() {
    ref.listen(
      analyserProvider.select(
        (s) => (
          s.source,
          s.accessPoints,
          s.history,
          s.lastUpdated,
          s.cached,
          s.acceptedScanId,
        ),
      ),
      (_, next) {
        if ((next.$1 == WifiDataSource.demo ||
                (state.baseline != null &&
                    next.$1 != state.baseline!.source)) &&
            (state.baseline != null || state.waiting)) {
          _requiredTimestamp = null;
          state = WifiGuidanceState(
            problem: state.problem,
            message: 'Data source changed. Start a new live check to compare.',
          );
        } else if (state.waiting) {
          _acceptRecheck(ref.read(analyserProvider));
        }
      },
    );
    return const WifiGuidanceState();
  }

  DateTime get _now => ref.read(guidanceClockProvider)();

  void choose(WifiProblem problem) {
    _requiredTimestamp = null;
    final scan = ref.read(analyserProvider);
    final blocker = guidanceBlocker(scan, _now);
    state = WifiGuidanceState(
      problem: problem,
      baseline: blocker == null ? wifiEvidence(scan) : null,
      message: blocker,
    );
  }

  Future<void> recheck() async {
    if (state.problem == null) return;
    final scan = ref.read(analyserProvider);
    if (scan.demo || scan.paused) {
      state = WifiGuidanceState(
        problem: state.problem,
        baseline: state.baseline,
        current: state.current,
        message: guidanceBlocker(scan, _now),
      );
      return;
    }
    // Demand an observation newer than both baseline and currently shown AP.
    final bssid = state.baseline?.ap.bssid;
    final ap = scan.accessPoints
        .where((a) => bssid == null ? a.connected : a.bssid == bssid)
        .firstOrNull;
    final baselineTimestamp = state.baseline?.ap.timestamp ?? 0;
    _requiredCompletion = scan.acceptedScanId;
    _requiredTimestamp = (ap?.timestamp ?? 0) > baselineTimestamp
        ? ap!.timestamp
        : baselineTimestamp;
    state = WifiGuidanceState(
      problem: state.problem,
      baseline: state.baseline,
      waiting: true,
      message: scan.source == WifiDataSource.macos
          ? 'Waiting for a new completed macOS scan. Per-AP time and cache freshness remain unknown.'
          : 'Waiting for a new observation. Scan requests are bounded; cached results cannot complete this check.',
    );
    await ref.read(analyserProvider.notifier).scan();
  }

  void _acceptRecheck(AnalyserState scan) {
    if (guidanceBlocker(scan, _now) != null) return;
    final next = wifiEvidence(scan);
    if (state.baseline != null && next.ap.bssid != state.baseline!.ap.bssid) {
      _requiredTimestamp = null;
      state = WifiGuidanceState(
        problem: state.problem,
        message: 'Connected access point changed. Choose a problem again to start a new check; different access points cannot be compared.',
      );
      return;
    }
    if (scan.source == WifiDataSource.macos) {
      if (_requiredCompletion != null &&
          scan.acceptedScanId <= _requiredCompletion!) {
        return;
      }
    } else if (next.ap.timestamp <= (_requiredTimestamp ?? 0)) {
      return;
    }
    _requiredTimestamp = null;
    state = WifiGuidanceState(
      problem: state.problem,
      baseline: state.baseline ?? next,
      current: state.baseline == null ? null : next,
    );
  }
}
