import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wifi_analyser/models/access_point.dart';
import 'package:wifi_analyser/models/analyser_state.dart';
import 'package:wifi_analyser/models/ap_preference.dart';
import 'package:wifi_analyser/repositories/ap_preferences_repository.dart';
import 'package:wifi_analyser/viewmodels/analyser_view_model.dart';
import 'package:wifi_analyser/viewmodels/channel_planning_view_model.dart';
import 'package:wifi_analyser/views/channels_page.dart';
import 'package:wifi_analyser/widgets/channel_plan_tile.dart';

const _ap = AccessPoint(
  ssid: 'Home',
  bssid: 'aa:bb:cc:dd:ee:01',
  rssi: -50,
  frequency: 5180,
  width: 80,
  centerFrequency: 5210,
);

class _Model extends AnalyserViewModel {
  @override
  AnalyserState build() => AnalyserState(
    demo: true,
    band: WifiBand.ghz5,
    accessPoints: [_ap],
    status: 'Demo scanning',
  );
  void replace(AnalyserState next) => state = next;
}

class _Aliases implements ApPreferencesRepository {
  @override
  Future<Map<String, ApPreference>> load() async => {
    _ap.bssid: ApPreference(bssid: _ap.bssid, ssid: 'Home', alias: 'Office'),
  };
  @override
  Future<void> save(Map<String, ApPreference> entries) async {}
}

Future<ProviderContainer> _show(
  WidgetTester tester, {
  Size size = const Size(360, 800),
  double scale = 1,
  Brightness brightness = Brightness.light,
}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        analyserProvider.overrideWith(_Model.new),
        apPreferencesRepositoryProvider.overrideWithValue(_Aliases()),
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
        home: const Scaffold(
          body: SingleChildScrollView(child: ChannelsPage()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(ChannelsPage)));
}

Future<void> _tap(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'apply, invalid-width recovery, cancel, clear and reset preserve plan',
    (tester) async {
      final container = await _show(tester);
      await _tap(tester, 'Change assumptions');
      await _tap(tester, '80 MHz');
      await tester.enterText(find.byType(TextField), '36,40,36');
      await _tap(tester, 'Apply plan');
      expect(container.read(selectedPlanningAssumptionsProvider).channels, [
        36,
        40,
      ]);
      expect(find.text('CH 36 • center 5210 MHz'), findsOneWidget);
      await _tap(tester, 'Change assumptions');
      await _tap(tester, '160 MHz');
      await tester.enterText(find.byType(TextField), '144');
      await _tap(tester, 'Apply plan');
      expect(find.textContaining('has no supported 160 MHz'), findsOneWidget);
      expect(container.read(selectedPlanningAssumptionsProvider).width, 80);
      await _tap(tester, 'Cancel');
      expect(container.read(selectedPlanningAssumptionsProvider).width, 80);
      await _tap(tester, 'Change assumptions');
      await _tap(tester, 'Clear shortlist');
      await _tap(tester, 'Apply plan');
      expect(
        container.read(selectedPlanningAssumptionsProvider).channels,
        isEmpty,
      );
      expect(container.read(selectedPlanningAssumptionsProvider).width, 80);
      await _tap(tester, 'Reset this band');
      expect(container.read(selectedPlanningAssumptionsProvider).width, 20);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'reasons preserve aliases, reported geometry and separate same-SSID APs',
    (tester) async {
      final container = await _show(tester);
      final model = container.read(analyserProvider.notifier) as _Model;
      model.replace(
        container
            .read(analyserProvider)
            .copyWith(
              accessPoints: [
                _ap,
                const AccessPoint(
                  ssid: 'Home',
                  bssid: 'aa:bb:cc:dd:ee:02',
                  rssi: -60,
                  frequency: 5180,
                ),
              ],
            ),
      );
      container
          .read(planningAssumptionsProvider.notifier)
          .apply(WifiBand.ghz5, 80, '36');
      await tester.pumpAndSettle();
      await _tap(tester, 'CH 36 • center 5210 MHz');
      expect(find.textContaining('Office • Home'), findsOneWidget);
      expect(find.textContaining('aa:bb:cc:dd:ee:02'), findsOneWidget);
      expect(
        find.textContaining(
          'Reported 80 MHz • primary 5180 MHz • center 5210 MHz',
        ),
        findsOneWidget,
      );
      final before = container.read(channelPlansProvider);
      model.replace(
        container
            .read(analyserProvider)
            .copyWith(query: 'no match', minimumRssi: -30),
      );
      await tester.pump();
      expect(identical(before, container.read(channelPlansProvider)), isTrue);
      expect(find.byType(ChannelPlanTile), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final brightness in Brightness.values) {
    testWidgets(
      'narrow 3x text $brightness keeps inputs and recovery reachable',
      (tester) async {
        await _show(
          tester,
          size: const Size(320, 720),
          scale: 3,
          brightness: brightness,
        );
        await _tap(tester, 'Change assumptions');
        await tester.ensureVisible(find.byType(TextField));
        await tester.enterText(find.byType(TextField), '😀');
        await _tap(tester, 'Apply plan');
        expect(find.textContaining('Use channel numbers'), findsOneWidget);
        await _tap(tester, 'Clear shortlist');
        await _tap(tester, 'Apply plan');
        expect(find.byType(AlertDialog), findsNothing);
        await _tap(tester, 'CH 36 • center 5180 MHz');
        await tester.ensureVisible(find.textContaining('Office • Home'));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('desktop keyboard Escape cancels edits; statuses stay honest', (
    tester,
  ) async {
    final container = await _show(tester, size: const Size(1280, 1000));
    await _tap(tester, 'Change assumptions');
    await tester.enterText(find.byType(TextField), '36');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(
      container.read(selectedPlanningAssumptionsProvider).channels,
      isEmpty,
    );
    final model = container.read(analyserProvider.notifier) as _Model;
    model.replace(
      AnalyserState(
        demo: false,
        band: WifiBand.ghz5,
        accessPoints: [_ap],
        cached: true,
        paused: true,
        lastUpdated: DateTime.now().subtract(const Duration(minutes: 5)),
      ),
    );
    await tester.pump();
    expect(
      find.textContaining('Paused • retained observations'),
      findsOneWidget,
    );
    expect(
      find.text('Cached results • signal may have changed'),
      findsOneWidget,
    );
    model.replace(
      container
          .read(analyserProvider)
          .copyWith(paused: false, status: 'WiFi disabled', accessPoints: []),
    );
    await tester.pump();
    expect(find.text('WiFi disabled'), findsOneWidget);
    expect(find.byType(ChannelPlanTile), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  testWidgets('all 59 candidates remain reachable in bounded pages', (
    tester,
  ) async {
    final container = await _show(tester, size: const Size(1280, 1000));
    final model = container.read(analyserProvider.notifier) as _Model;
    model.replace(
      AnalyserState(
        demo: true,
        band: WifiBand.ghz6,
        accessPoints: const [
          AccessPoint(ssid: 'Six', bssid: 'six', rssi: -50, frequency: 5955),
        ],
      ),
    );
    final channels = List.generate(59, (i) => 1 + i * 4);
    container
        .read(planningAssumptionsProvider.notifier)
        .apply(WifiBand.ghz6, 20, channels.join(','));
    await tester.pumpAndSettle();
    expect(find.byType(ChannelPlanTile), findsNWidgets(8));
    final plans = container.read(channelPlansProvider);
    for (var page = 0; page < 7; page++) {
      await _tap(tester, 'Next candidates');
      expect(
        find.byType(ChannelPlanTile).evaluate().length,
        lessThanOrEqualTo(8),
      );
      expect(identical(plans, container.read(channelPlansProvider)), isTrue);
    }
    expect(
      find.text('Candidates 57–59 of 59 • lowest overlap first'),
      findsOneWidget,
    );
    final last = plans.last;
    expect(
      find.text('CH ${last.channel} • center ${last.center} MHz'),
      findsOneWidget,
    );
    await _tap(tester, 'Previous candidates');
    expect(find.byType(ChannelPlanTile), findsNWidgets(8));
    // Reset changes identity/page, leaving every example reachable.
    await _tap(tester, 'Reset this band');
    expect(
      find.text('Candidates 1–8 of 15 • lowest overlap first'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'keyboard activates assumptions, width and Apply without pointer',
    (tester) async {
      await _show(tester, size: const Size(1280, 1000));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('band changes retain independent applied assumptions', (
    tester,
  ) async {
    final container = await _show(tester);
    container
        .read(planningAssumptionsProvider.notifier)
        .apply(WifiBand.ghz5, 80, '36');
    final model = container.read(analyserProvider.notifier) as _Model;
    model.replace(
      container.read(analyserProvider).copyWith(band: WifiBand.ghz24),
    );
    await tester.pumpAndSettle();
    expect(container.read(selectedPlanningAssumptionsProvider).width, 20);
    expect(find.byType(ChannelPlanTile), findsNothing);
    model.replace(
      container.read(analyserProvider).copyWith(band: WifiBand.ghz5),
    );
    await tester.pumpAndSettle();
    expect(container.read(selectedPlanningAssumptionsProvider).width, 80);
    expect(find.text('CH 36 • center 5210 MHz'), findsOneWidget);
  });
}
