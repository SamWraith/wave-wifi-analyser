import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wifi_analyser/models/access_point.dart';
import 'package:wifi_analyser/models/analyser_state.dart';
import 'package:wifi_analyser/models/router_finder.dart';
import 'package:wifi_analyser/models/wifi_data_source.dart';
import 'package:wifi_analyser/viewmodels/analyser_view_model.dart';
import 'package:wifi_analyser/viewmodels/router_finder_view_model.dart';

const target = AccessPoint(
  ssid: 'Test mesh',
  bssid: 'aa:bb:cc:dd:ee:01',
  rssi: -70,
  frequency: 2412,
);

class FinderScan extends AnalyserViewModel {
  @override
  AnalyserState build() => AnalyserState(demo: false);
  void emit(AnalyserState value) => state = value;
  int requests = 0;
  @override
  Future<void> scan({bool requestPermission = true}) async {
    requests++;
  }
}

AccessPoint point(
  int rssi, {
  String bssid = 'aa:bb:cc:dd:ee:01',
  int frequency = 2412,
}) => AccessPoint(
  ssid: 'Test mesh',
  bssid: bssid,
  rssi: rssi,
  frequency: frequency,
);

AnalyserState observation(
  List<SignalSample> samples, {
  AccessPoint? ap,
  bool cached = false,
  bool paused = false,
  WifiDataSource source = WifiDataSource.android,
}) => AnalyserState(
  demo: source == WifiDataSource.demo,
  liveSource: source == WifiDataSource.demo ? WifiDataSource.android : source,
  cached: cached,
  paused: paused,
  accessPoints: ap == null ? [] : [ap],
  history: {target.bssid: samples},
  lastUpdated: samples.lastOrNull?.at,
);

void main() {
  test('signal guidance has a deadband and resets when frequency changes', () {
    final at = DateTime(2026);
    var state = const RouterFinderState().observe(point(-70), at);
    expect(state.guidance, 'Similar signal to start');
    state = state.observe(point(-68), at);
    expect(state.guidance, 'Similar signal to start');
    state = state.observe(point(-65), at);
    expect(state.guidance, 'Warmer • stronger signal');
    expect(state.bestRssi, -65);
    state = state.observe(point(-74), at);
    expect(state.guidance, 'Colder • weaker signal');
    expect(state.bestRssi, -65);
    state = state.observe(point(-50, frequency: 5180), at);
    expect(state.samples, 1);
    expect(state.baselineRssi, -50);
    expect(state.bestRssi, -50);
  });

  late ProviderContainer container;
  late FinderScan scan;
  setUp(() {
    container = ProviderContainer(
      overrides: [analyserProvider.overrideWith(FinderScan.new)],
    );
    scan = container.read(analyserProvider.notifier) as FinderScan;
  });
  tearDown(() => container.dispose());

  test(
    'ignores pre-open history, duplicates, cached and paused observations',
    () {
      final first = SignalSample(DateTime(2026), -70);
      scan.emit(observation([first], ap: point(-70)));
      container.listen(routerFinderProvider(target), (_, _) {});
      RouterFinderState read() => container.read(routerFinderProvider(target));
      expect(read().samples, 0);
      scan.emit(observation([first], ap: point(-55)));
      expect(read().samples, 0);
      final second = SignalSample(DateTime(2026, 1, 1, 0, 1), -65);
      scan.emit(observation([first, second], ap: point(-65)));
      expect(read().samples, 1);
      scan.emit(observation([first, second], ap: point(-65)));
      expect(read().samples, 1);
      final cached = SignalSample(DateTime(2026, 1, 1, 0, 2), -40);
      scan.emit(observation([second, cached], ap: point(-40), cached: true));
      scan.emit(observation([second, cached], ap: point(-40)));
      expect(read().samples, 1);
      final paused = SignalSample(DateTime(2026, 1, 1, 0, 3), -30);
      scan.emit(observation([cached, paused], ap: point(-30), paused: true));
      expect(read().samples, 1);
      expect(read().latest!.rssi, -65);
    },
  );

  test('follows BSSID case-insensitively, never another mesh AP by SSID', () {
    container.listen(routerFinderProvider(target), (_, _) {});
    final one = SignalSample(DateTime(2026), -60);
    scan.emit(observation([one], ap: point(-60, bssid: 'aa:bb:cc:dd:ee:02')));
    expect(container.read(routerFinderProvider(target)).samples, 0);
    final two = SignalSample(DateTime(2026, 1, 1, 0, 1), -65);
    scan.emit(
      observation([
        one,
        two,
      ], ap: point(-65, bssid: target.bssid.toUpperCase())),
    );
    expect(container.read(routerFinderProvider(target)).samples, 1);
    scan.emit(observation([one, two]));
    expect(container.read(routerFinderProvider(target)).latest!.rssi, -65);
  });

  test('source changes clear guidance and cannot silently restart', () {
    container.listen(routerFinderProvider(target), (_, _) {});
    final one = SignalSample(DateTime(2026), -60);
    scan.emit(observation([one], ap: point(-60)));
    scan.emit(observation([one], ap: point(-60), source: WifiDataSource.demo));
    expect(container.read(routerFinderProvider(target)).sourceChanged, isTrue);
    expect(container.read(routerFinderProvider(target)).latest, isNull);
    scan.emit(observation([SignalSample(DateTime(2027), -50)], ap: point(-50)));
    container.read(routerFinderProvider(target).notifier).reset();
    expect(container.read(routerFinderProvider(target)).sourceChanged, isTrue);
  });

  test('reset demands a new sample and disposal loses comparison', () async {
    final subscription = container.listen(
      routerFinderProvider(target),
      (_, _) {},
    );
    final one = SignalSample(DateTime(2026), -60);
    scan.emit(observation([one], ap: point(-60)));
    container.read(routerFinderProvider(target).notifier).reset();
    scan.emit(observation([one], ap: point(-50)));
    expect(container.read(routerFinderProvider(target)).samples, 0);
    final two = SignalSample(DateTime(2027), -50);
    scan.emit(observation([one, two], ap: point(-50)));
    expect(container.read(routerFinderProvider(target)).baselineRssi, -50);
    subscription.close();
    await container.pump();
    container.listen(routerFinderProvider(target), (_, _) {});
    expect(container.read(routerFinderProvider(target)).samples, 0);
  });
}
