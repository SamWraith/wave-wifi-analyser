import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wifi_analyser/models/access_point.dart';
import 'package:wifi_analyser/models/ap_preference.dart';
import 'package:wifi_analyser/viewmodels/ap_preferences_view_model.dart';
import 'package:wifi_analyser/models/analyser_state.dart';
import 'package:wifi_analyser/repositories/comparison_sessions_repository.dart';
import 'package:wifi_analyser/viewmodels/analyser_view_model.dart';
import 'package:wifi_analyser/viewmodels/comparison_sessions_view_model.dart';
import 'package:wifi_analyser/models/comparison_session.dart';
import 'package:wifi_analyser/views/sessions_page.dart';
import 'package:wifi_analyser/views/overview_page.dart';

final _start = DateTime(2026, 10, 13, 12);
ComparisonSession _session(
  String id, {
  String bssid = 'aa',
  bool demo = false,
  List<SessionSample> samples = const [],
}) => ComparisonSession(
  id: id,
  bssid: bssid,
  ssid: 'WiFi',
  label: id,
  start: _start,
  end: _start.add(const Duration(minutes: 3)),
  demo: demo,
  samples: samples,
  reason: 'Stopped by you',
);
SessionSample _sample(int seconds, int rssi, {int frequency = 2412}) =>
    SessionSample(
      at: _start.add(Duration(seconds: seconds)),
      rssi: rssi,
      frequency: frequency,
      width: 20,
    );
Future<void> _show(
  WidgetTester tester,
  Widget child, {
  double scale = 1,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _SessionsStorage implements ComparisonSessionsRepository {
  bool failLoad = true;
  @override
  Future<List<ComparisonSession>> load() async {
    if (failLoad) throw StateError('Read failed');
    return [];
  }

  @override
  Future<void> save(List<ComparisonSession> sessions) async {}
}

class _ScanModel extends AnalyserViewModel {
  void reportScanError() => state = state.copyWith(
    demo: false,
    status: 'Scan unavailable: WiFi is off',
    wifiEnabled: false,
    permission: false,
    locationEnabled: false,
    cached: true,
  );
  @override
  AnalyserState build() => AnalyserState(
    demo: true,
    accessPoints: [
      const AccessPoint(
        ssid: 'Desk WiFi',
        bssid: 'aa',
        rssi: -55,
        frequency: 2412,
      ),
    ],
  );
}

class _DuplicateScan extends _ScanModel {
  @override
  AnalyserState build() => AnalyserState(
    demo: true,
    accessPoints: [
      const AccessPoint(
        ssid: 'Stale',
        bssid: 'AA',
        rssi: -55,
        frequency: 2412,
        timestamp: 1,
      ),
      const AccessPoint(
        ssid: 'Latest',
        bssid: 'aa',
        rssi: -65,
        frequency: 2412,
        timestamp: 2,
      ),
    ],
  );
}

class _LongScan extends _ScanModel {
  @override
  AnalyserState build() => AnalyserState(
    demo: true,
    accessPoints: [
      for (final bssid in ['00:11:22:33:44:55', '00:11:22:33:44:66'])
        AccessPoint(
          ssid: 'Shared network with an unusually long original SSID',
          bssid: bssid,
          rssi: -55,
          frequency: 5180,
          width: 80,
        ),
    ],
  );
}

class _PickerPreferences extends ApPreferencesViewModel {
  @override
  ApPreferencesState build() => ApPreferencesState(
    entries: {
      '00:11:22:33:44:55': const ApPreference(
        bssid: '00:11:22:33:44:55',
        ssid: 'Shared network with an unusually long original SSID',
        alias: 'Long room alias that also describes router placement',
        favorite: true,
      ),
    },
  );
}

void main() {
  testWidgets('Overview discovery reflects ongoing recording after returning', (
    tester,
  ) async {
    final storage = _SessionsStorage()..failLoad = false;
    final container = ProviderContainer(
      overrides: [
        comparisonSessionsRepositoryProvider.overrideWithValue(storage),
      ],
    );
    addTearDown(container.dispose);
    final sessions = container.read(comparisonSessionsProvider.notifier);
    await sessions.ready;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: RoomComparisonButton())),
      ),
    );
    expect(find.text('Compare rooms'), findsOneWidget);
    sessions.start(
      const AccessPoint(ssid: 'WiFi', bssid: 'aa', rssi: -50, frequency: 2412),
      'Study',
      demo: true,
    );
    await tester.pumpAndSettle();
    expect(find.text('Recording · Study (simulated)'), findsOneWidget);
    sessions.stop();
    await tester.pumpAndSettle();
    expect(find.text('Compare rooms'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'long AP identities remain visible in narrow large-text picker across themes',
    (tester) async {
      tester.view.physicalSize = const Size(320, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final dark in [false, true]) {
        for (final reduced in [false, true]) {
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                comparisonSessionsRepositoryProvider.overrideWithValue(
                  _SessionsStorage()..failLoad = false,
                ),
                analyserProvider.overrideWith(_LongScan.new),
                apPreferencesProvider.overrideWith(_PickerPreferences.new),
              ],
              child: MaterialApp(
                theme: ThemeData(
                  brightness: dark ? Brightness.dark : Brightness.light,
                ),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(2),
                    disableAnimations: reduced,
                  ),
                  child: child!,
                ),
                home: const SessionsPage(),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.ensureVisible(
            find.byType(DropdownButtonFormField<String>),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.byType(DropdownButtonFormField<String>));
          await tester.pumpAndSettle();
          expect(find.text('00:11:22:33:44:55'), findsWidgets);
          expect(find.text('00:11:22:33:44:66'), findsWidgets);
          expect(find.textContaining('Long room alias'), findsWidgets);
          expect(find.textContaining('Shared network with'), findsWidgets);
          expect(tester.takeException(), isNull);
          await tester.tap(find.text('00:11:22:33:44:55').last);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        }
      }
    },
  );
  testWidgets(
    'AP picker deduplicates canonical identity using latest native timestamp',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            comparisonSessionsRepositoryProvider.overrideWithValue(
              _SessionsStorage()..failLoad = false,
            ),
            analyserProvider.overrideWith(_DuplicateScan.new),
          ],
          child: const MaterialApp(home: SessionsPage()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      expect(find.text('Latest'), findsWidgets);
      expect(find.textContaining('Stale'), findsNothing);
      await tester.tap(find.text('Latest').last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        tester
            .widget<DropdownButton<String>>(find.byType(DropdownButton<String>))
            .items!
            .length,
        1,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'saved selection semantics retain identity and disabled/selected state',
    (tester) async {
      final semantics = tester.ensureSemantics();

      for (final enabled in [true, false]) {
        await _show(
          tester,
          SavedSessionTile(
            session: _session('Study'),
            alias: 'Desk router',
            selected: enabled,
            onSelect: enabled ? (_) {} : null,
            onDelete: () {},
          ),
        );
        expect(find.text('Desk router (WiFi) · aa'), findsOneWidget);
        expect(
          tester.getSemantics(find.byType(Checkbox)),
          matchesSemantics(
            label:
                'Select Study, Desk router (WiFi), aa, measured for comparison',
            hasCheckedState: true,
            isChecked: enabled,
            hasEnabledState: true,
            isEnabled: enabled,
            isFocusable: enabled,
            hasTapAction: enabled,
            hasFocusAction: enabled,
          ),
        );
      }
      semantics.dispose();
    },
  );
  testWidgets('active scan failure shows recovery and returns to Overview', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final storage = _SessionsStorage()..failLoad = false;
    final container = ProviderContainer(
      overrides: [
        comparisonSessionsRepositoryProvider.overrideWithValue(storage),
        analyserProvider.overrideWith(_ScanModel.new),
      ],
    );
    addTearDown(container.dispose);
    final scan = container.read(analyserProvider.notifier) as _ScanModel;
    scan.reportScanError();
    final sessions = container.read(comparisonSessionsProvider.notifier);
    await sessions.ready;
    sessions.start(
      container.read(analyserProvider).accessPoints.first,
      'Study',
      demo: false,
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showComparisonSessions(context),
                child: const Text('Overview'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Overview'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Return to Overview'), 200);
    expect(find.text('Scan unavailable: WiFi is off'), findsOneWidget);
    expect(find.textContaining('Scanning needs WiFi'), findsOneWidget);
    expect(
      find.text('Latest results are cached. No fresh samples added.'),
      findsOneWidget,
    );
    expect(container.read(comparisonSessionsProvider).active!.samples, isEmpty);
    await tester.ensureVisible(
      find.widgetWithText(TextButton, 'Return to Overview'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Return to Overview'));
    await tester.pumpAndSettle();
    expect(find.text('Overview'), findsOneWidget);
    expect(find.byType(SessionsPage), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'load failure disables recording and retry preserves room label',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final storage = _SessionsStorage();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            comparisonSessionsRepositoryProvider.overrideWithValue(storage),
            analyserProvider.overrideWith(_ScanModel.new),
          ],
          child: const MaterialApp(home: SessionsPage()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'Study');
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Desk WiFi').last);
      await tester.pumpAndSettle();
      final start = find.widgetWithText(
        FilledButton,
        'Start simulated session',
      );
      expect(tester.widget<FilledButton>(start).onPressed, isNull);
      expect(find.textContaining('Retry before recording'), findsOneWidget);
      storage.failLoad = false;
      await tester.ensureVisible(find.text('Retry session storage'));
      await tester.tap(find.text('Retry session storage'));
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(start).onPressed, isNotNull);
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField))
            .controller!
            .text,
        'Study',
      );
      await tester.ensureVisible(start);
      await tester.tap(start);
      await tester.pumpAndSettle();
      expect(find.text('Simulated session running'), findsOneWidget);
      expect(find.text('0 samples'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('matching contexts show measured median delta and honest gaps', (
    tester,
  ) async {
    await _show(
      tester,
      SessionComparison(
        sessions: [
          _session('Study', samples: [_sample(10, -70), _sample(80, -60)]),
          _session('Hall', samples: [_sample(10, -50), _sample(45, -50)]),
        ],
      ),
    );
    expect(find.text('Median delta vs Study: +15.0 dB'), findsOneWidget);
    expect(find.text('Longest observation gap: 70 seconds'), findsOneWidget);
    expect(
      find.text(
        'Wait before first sample: 10 seconds · silence before stop: 100 seconds',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Silence between observations'), findsOneWidget);
  });
  testWidgets(
    'changed radio contexts keep metrics separate and suppress delta',
    (tester) async {
      await _show(
        tester,
        SessionComparison(
          sessions: [
            _session(
              'Study',
              samples: [_sample(0, -70), _sample(35, -60, frequency: 5180)],
            ),
            _session('Hall', samples: [_sample(0, -50)]),
          ],
        ),
      );
      expect(find.textContaining('no combined signal delta'), findsOneWidget);
      expect(find.textContaining('Median delta vs'), findsNothing);
      expect(find.textContaining('5 GHz'), findsOneWidget);
    },
  );
  testWidgets('empty observations and cross identity/source are guarded', (
    tester,
  ) async {
    await _show(
      tester,
      SessionComparison(sessions: [_session('Study'), _session('Hall')]),
    );
    expect(
      find.text('No fresh samples. No signal comparison available.'),
      findsNWidgets(2),
    );
    expect(tester.takeException(), isNull);
    for (final second in [
      _session('Hall', bssid: 'bb'),
      _session('Hall', demo: true),
    ]) {
      await _show(
        tester,
        SessionComparison(sessions: [_session('Study'), second]),
      );
      expect(
        find.text(
          'Choose at least two sessions for the same BSSID and source.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Median delta vs'), findsNothing);
    }
  });
  testWidgets('recording controls and comparison fit narrow large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var stopped = false;
    await _show(
      tester,
      RecordingPanel(
        session: _session('Study'),
        onStop: () => stopped = true,
        onCancel: () {},
      ),
      scale: 2,
    );
    await tester.ensureVisible(find.text('Stop and save'));
    await tester.tap(find.text('Stop and save'));
    expect(stopped, isTrue);
    expect(tester.takeException(), isNull);
    await _show(
      tester,
      SessionComparison(
        sessions: [
          _session('Study', samples: [_sample(0, -60)]),
          _session('Hall', samples: [_sample(0, -70)]),
        ],
      ),
      scale: 2,
    );
    expect(tester.takeException(), isNull);
  });
}
