import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wifi_analyser/models/access_point.dart';
import 'package:wifi_analyser/models/analyser_state.dart';
import 'package:wifi_analyser/models/ap_preference.dart';
import 'package:wifi_analyser/repositories/ap_preferences_repository.dart';
import 'package:wifi_analyser/viewmodels/analyser_view_model.dart';
import 'package:wifi_analyser/viewmodels/ap_preferences_view_model.dart';
import 'package:wifi_analyser/views/networks_page.dart';
import 'package:wifi_analyser/widgets/chart_legend_item.dart';
import 'package:wifi_analyser/widgets/network_tile.dart';

const first = AccessPoint(
  ssid: 'Home',
  bssid: 'aa:bb:cc:dd:ee:01',
  rssi: -62,
  frequency: 2412,
);
const second = AccessPoint(
  ssid: 'Home',
  bssid: 'aa:bb:cc:dd:ee:02',
  rssi: -58,
  frequency: 2437,
);

class _PreferencesRepository implements ApPreferencesRepository {
  _PreferencesRepository([this.entries = const {}]);
  Map<String, ApPreference> entries;
  bool fail = false;
  @override
  Future<Map<String, ApPreference>> load() async => entries;
  @override
  Future<void> save(Map<String, ApPreference> next) async {
    if (fail) throw StateError('write failed');
    entries = Map.of(next);
  }
}

class _ScanModel extends AnalyserViewModel {
  @override
  AnalyserState build() => AnalyserState(demo: true, accessPoints: []);
}

Future<ProviderContainer> _show(
  WidgetTester tester,
  Widget body,
  _PreferencesRepository repository, {
  double scale = 1,
  Brightness brightness = Brightness.light,
}) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        apPreferencesRepositoryProvider.overrideWithValue(repository),
        analyserProvider.overrideWith(_ScanModel.new),
      ],
      child: MaterialApp(
        theme: ThemeData(brightness: brightness),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            disableAnimations: true,
          ),
          child: child!,
        ),
        home: Scaffold(body: body),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));
}

Future<void> _tap(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text));
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'favorites and alias save, cancel and remove stay BSSID specific',
    (tester) async {
      final repo = _PreferencesRepository();
      final container = await _show(
        tester,
        const AccessPointDetailsSheet(ap: first),
        repo,
      );
      await _tap(tester, 'Add favorite');
      expect(repo.entries[first.bssid]!.favorite, isTrue);
      expect(find.text('Remove favorite'), findsOneWidget);
      await _tap(tester, 'Add local alias');
      await tester.enterText(find.byType(TextField).last, 'Living room');
      await _tap(tester, 'Cancel');
      expect(repo.entries[first.bssid]!.alias, isNull);
      await _tap(tester, 'Add local alias');
      await tester.enterText(find.byType(TextField).last, 'Living room');
      await _tap(tester, 'Save');
      expect(find.text('Living room'), findsOneWidget);
      expect(find.text('SSID: Home'), findsOneWidget);
      expect(repo.entries[first.bssid]!.alias, 'Living room');
      expect(repo.entries.containsKey(second.bssid), isFalse);
      await _tap(tester, 'Edit local alias');
      await _tap(tester, 'Remove alias');
      expect(find.text('Home'), findsOneWidget);
      expect(repo.entries[first.bssid]!.alias, isNull);
      await _tap(tester, 'Remove favorite');
      expect(container.read(apPreferencesProvider).entries, isEmpty);
      expect(repo.entries, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'same SSID legend shows local alias, original SSID and distinct channel/BSSID',
    (tester) async {
      final repo = _PreferencesRepository({
        first.bssid: ApPreference(
          bssid: first.bssid,
          ssid: 'Home',
          alias: 'Living room',
        ),
      });
      await _show(
        tester,
        SingleChildScrollView(
          child: Column(
            children: [
              for (final ap in [first, second])
                ChartLegendItem(
                  point: ap,
                  visible: true,
                  solo: false,
                  nextAction: 'Hide',
                  onTap: () {},
                ),
            ],
          ),
        ),
        repo,
      );
      expect(find.text('Living room · Home · CH 1 · dd:ee:01'), findsOneWidget);
      expect(find.text('Home · CH 6 · dd:ee:02'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('chart-legend-aa:bb:cc:dd:ee:01')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('chart-legend-aa:bb:cc:dd:ee:02')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final brightness in Brightness.values) {
    testWidgets(
      'missing favorite recovery fits narrow 3x text in $brightness',
      (tester) async {
        final repo = _PreferencesRepository({
          first.bssid: ApPreference(
            bssid: first.bssid,
            ssid: 'Home',
            alias: 'Living room',
            favorite: true,
          ),
        });
        await _show(
          tester,
          const SingleChildScrollView(child: NetworksPage()),
          repo,
          scale: 3,
          brightness: brightness,
        );
        expect(find.text('Not seen · ${first.bssid}'), findsOneWidget);
        expect(find.text('-62'), findsNothing);
        expect(find.textContaining('dBm'), findsNothing);
        await _tap(tester, 'Living room');
        expect(find.textContaining('No current signal'), findsOneWidget);
        await _tap(tester, 'Edit local alias');
        await tester.enterText(find.byType(TextField).last, 'Office');
        await _tap(tester, 'Save');
        expect(find.text('Office'), findsNWidgets(2));
        await tester.ensureVisible(find.text('Office').last);
        await tester.pumpAndSettle();
        expect(find.text('Office').last.hitTestable(), findsOneWidget);
        expect(find.text('SSID: Home'), findsNWidgets(2));
        await _tap(tester, 'Remove favorite');
        expect(repo.entries[first.bssid]!.favorite, isFalse);
        expect(repo.entries[first.bssid]!.alias, 'Office');
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('failed preference save exposes retry and keeps chosen alias', (
    tester,
  ) async {
    final repo = _PreferencesRepository()..fail = true;
    await _show(tester, const AccessPointDetailsSheet(ap: first), repo);
    await _tap(tester, 'Add local alias');
    await tester.enterText(find.byType(TextField).last, 'Office');
    await _tap(tester, 'Save');
    expect(find.text('Office'), findsOneWidget);
    expect(find.text('Retry preferences'), findsOneWidget);
    repo.fail = false;
    await _tap(tester, 'Retry preferences');
    expect(repo.entries[first.bssid]!.alias, 'Office');
    expect(find.text('Retry preferences'), findsNothing);
  });
  testWidgets('alias-only missing AP remains manageable and removable', (
    tester,
  ) async {
    final repo = _PreferencesRepository({
      first.bssid: ApPreference(
        bssid: first.bssid,
        ssid: 'Home',
        alias: 'Office',
      ),
    });
    await _show(
      tester,
      const SingleChildScrollView(child: NetworksPage()),
      repo,
    );
    expect(find.text('Saved aliases'), findsOneWidget);
    expect(find.text('Favorites'), findsNothing);
    expect(find.textContaining('Not seen'), findsOneWidget);
    await _tap(tester, 'Office');
    await _tap(tester, 'Edit local alias');
    await _tap(tester, 'Remove alias');
    expect(repo.entries, isEmpty);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Add local alias'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('emoji alias boundary reports error without discarding edit', (
    tester,
  ) async {
    final repo = _PreferencesRepository();
    await _show(tester, const AccessPointDetailsSheet(ap: first), repo);
    await _tap(tester, 'Add local alias');
    final tooLong = List.filled(40, '😀').join();
    await tester.enterText(find.byType(TextField).last, tooLong);
    await _tap(tester, 'Save');
    expect(find.text('Alias too long. Try a shorter name.'), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(repo.entries, isEmpty);
    final valid = List.filled(32, '😀').join();
    await tester.enterText(find.byType(TextField).last, valid);
    await _tap(tester, 'Save');
    expect(find.byType(AlertDialog), findsNothing);
    expect(repo.entries[first.bssid]!.alias, valid);
    expect(tester.takeException(), isNull);
  });
}
