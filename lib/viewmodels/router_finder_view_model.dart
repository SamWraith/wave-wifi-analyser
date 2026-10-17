import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/access_point.dart';
import '../models/analyser_state.dart';
import '../models/ap_preference.dart';
import '../models/router_finder.dart';
import '../models/wifi_data_source.dart';
import 'analyser_view_model.dart';

final routerFinderProvider = NotifierProvider.autoDispose
    .family<RouterFinderViewModel, RouterFinderState, AccessPoint>(
      RouterFinderViewModel.new,
    );

class RouterFinderViewModel extends Notifier<RouterFinderState> {
  RouterFinderViewModel(this.target);
  final AccessPoint target;
  late WifiDataSource _source;
  SignalSample? _lastSample;

  @override
  RouterFinderState build() {
    final scan = ref.read(analyserProvider);
    _source = scan.source;
    _lastSample = _sample(scan);
    ref.listen(
      analyserProvider.select(
        (s) => (s.source, s.history, s.accessPoints, s.cached, s.paused),
      ),
      (_, _) => _observe(ref.read(analyserProvider)),
    );
    return const RouterFinderState();
  }

  SignalSample? _sample(AnalyserState scan) {
    final key = preferenceKey(target.bssid);
    return scan.history.entries
        .where((entry) => preferenceKey(entry.key) == key)
        .firstOrNull
        ?.value
        .lastOrNull;
  }

  void _observe(AnalyserState scan) {
    if (state.sourceChanged) return;
    if (scan.source != _source) {
      state = const RouterFinderState(sourceChanged: true);
      return;
    }
    final sample = _sample(scan);
    if (sample == null || identical(sample, _lastSample)) return;
    _lastSample = sample;
    if (scan.cached || scan.paused) return;
    final ap = scan.accessPoints
        .where((ap) => preferenceKey(ap.bssid) == preferenceKey(target.bssid))
        .firstOrNull;
    if (ap == null || ap.rssi != sample.rssi) return;
    state = state.observe(ap, sample.at);
  }

  void reset() {
    if (state.sourceChanged) return;
    _lastSample = _sample(ref.read(analyserProvider));
    state = const RouterFinderState();
  }
}
