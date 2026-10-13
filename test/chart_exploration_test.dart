import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wifi_analyser/models/access_point.dart';
import 'package:wifi_analyser/models/analyser_state.dart';
import 'package:wifi_analyser/viewmodels/analyser_view_model.dart';
import 'package:wifi_analyser/views/analyser_home.dart';
import 'package:wifi_analyser/views/chart_panel.dart';
import 'package:wifi_analyser/views/chart_selection.dart';
import 'package:wifi_analyser/widgets/chart_coordinates.dart';
import 'package:wifi_analyser/widgets/chart_inspection.dart';
import 'package:wifi_analyser/widgets/signal_charts.dart';

const ap = AccessPoint(
  ssid: 'Test WiFi',
  bssid: 'test',
  rssi: -50,
  frequency: 5935,
);

class ChartModel extends AnalyserViewModel {
  @override
  AnalyserState build() => AnalyserState(
    demo: true,
    band: WifiBand.ghz6,
    accessPoints: [ap],
    history: {
      ap.bssid: [
        SignalSample(DateTime(2026), -50),
        SignalSample(DateTime(2026, 1, 1, 0, 1), -60),
      ],
    },
  );
}

void main() {
  test(
    'coordinates share spectrum bounds, exceptions, width and history domain',
    () {
      for (final (band, frequency, channel) in [
        (WifiBand.ghz24, 2484, '14'),
        (WifiBand.ghz5, 4920, '184'),
        (WifiBand.ghz6, 5935, '2'),
      ]) {
        final point = AccessPoint(
          ssid: '',
          bssid: 'x',
          rssi: -50,
          frequency: frequency,
          width: 160,
        );
        final axis = ChartCoordinates(band, [point], {});
        final fraction = axis.spectrum.fraction(frequency);
        expect(
          axis.spectrumLabel(fraction),
          'CH $channel · ${frequency.toStringAsFixed(1)} MHz',
        );
        expect(axis.frequency(0), axis.spectrum.minimum);
        expect(axis.frequency(1), axis.spectrum.maximum);
        expect(axis.frequency(fraction), frequency);
      }
      final exception = ChartCoordinates(WifiBand.ghz24, [], {});
      expect(
        exception.spectrumLabel(exception.spectrum.fraction(2483)),
        'Near CH 14 · 2483.0 MHz',
      );
      final six = ChartCoordinates(WifiBand.ghz6, [], {});
      expect(
        six.spectrumLabel(six.spectrum.fraction(5936)),
        'Near CH 2 · 5936.0 MHz',
      );
      final single = ChartCoordinates(
        WifiBand.ghz6,
        [ap],
        {
          ap.bssid: [SignalSample(DateTime(2026), -50)],
        },
      );
      expect(single.time(0), single.time(1));
      const later = AccessPoint(
        ssid: '',
        bssid: 'later',
        rssi: -60,
        frequency: 5955,
      );
      final timeline = ChartCoordinates(
        WifiBand.ghz6,
        [ap, later],
        {
          ap.bssid: [SignalSample(DateTime(2026), -50)],
          later.bssid: [SignalSample(DateTime(2026, 1, 1, 0, 1), -60)],
        },
      );
      expect(
        timeline.historyFraction(SignalSample(DateTime(2026, 1, 1, 0, 1), -60)),
        1,
      );
      expect(ChartCoordinates.strength(0), -20);
      expect(ChartCoordinates.strength(.5), -60);
      expect(ChartCoordinates.strength(1), -100);
      final start = DateTime(2026);
      final end = start.add(const Duration(minutes: 2));
      final axis = ChartCoordinates(
        WifiBand.ghz6,
        [ap],
        {
          ap.bssid: [SignalSample(start, -50), SignalSample(end, -60)],
        },
      );
      expect(
        axis.hasGap(SignalSample(start, -50), SignalSample(end, -60)),
        isTrue,
      );
      const other = AccessPoint(
        ssid: '',
        bssid: 'other',
        frequency: 5955,
        rssi: -50,
      );
      final middle = start.add(const Duration(seconds: 35));
      final last = start.add(const Duration(seconds: 70));
      final missing = ChartCoordinates(
        WifiBand.ghz6,
        [ap, other],
        {
          ap.bssid: [SignalSample(start, -50), SignalSample(last, -60)],
          other.bssid: [SignalSample(middle, -50)],
        },
      );
      expect(
        missing.hasGap(SignalSample(start, -50), SignalSample(last, -60)),
        isTrue,
      );
      expect(axis.time(0), start);
      expect(axis.time(1), end);
      expect(axis.time(.5), start.add(const Duration(minutes: 1)));
      expect(ChartCoordinates(WifiBand.ghz6, [ap], {}).time(.5), isNull);
    },
  );

  testWidgets(
    'ordinary horizontal inspection coexists with vertical scroll and keyboard dismissal',
    (tester) async {
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              controller: scroll,
              child: Column(
                children: [
                  SignalChart(points: [ap], band: WifiBand.ghz6),
                  const SizedBox(height: 1600),
                ],
              ),
            ),
          ),
        ),
      );
      final chart = find.byType(ChartInspection);
      final position = tester.getTopLeft(chart) + const Offset(90, 90);
      await tester.dragFrom(position, const Offset(200, 0));
      await tester.pump();
      expect(find.textContaining('Envelope:'), findsOneWidget);
      expect(scroll.offset, 0);
      await tester.tap(find.byTooltip('Dismiss inspection'));
      await tester.pump();
      await tester.dragFrom(position, const Offset(0, -180));
      await tester.pumpAndSettle();
      expect(scroll.offset, greaterThan(0));
      expect(find.textContaining('Envelope:'), findsNothing);
      scroll.jumpTo(0);
      await tester.pump();
      await tester.tapAt(position);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(find.textContaining('Envelope:'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(find.textContaining('Envelope:'), findsNothing);
    },
  );

  for (final brightness in Brightness.values) {
    testWidgets(
      'focus preserves state, scroll and exits from chart via Escape at large text $brightness',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final selection = ChartSelection();
        addTearDown(selection.dispose);
        final scroll = ScrollController();
        addTearDown(scroll.dispose);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [analyserProvider.overrideWith(ChartModel.new)],
            child: MaterialApp(
              theme: ThemeData(brightness: brightness),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: const TextScaler.linear(2),
                  disableAnimations: true,
                ),
                child: child!,
              ),
              home: Scaffold(
                body: SingleChildScrollView(
                  controller: scroll,
                  child: Column(
                    children: [
                      const SizedBox(height: 100),
                      ChartPanel(selection: selection),
                      const SizedBox(height: 1200),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        selection.toggleGraph();
        selection.cycle(ap.bssid, {ap.bssid}, {ap.bssid});
        await tester.pump();
        await tester.ensureVisible(find.text('Focus chart'));
        final offset = scroll.offset;
        await tester.tap(find.text('Focus chart'));
        await tester.pumpAndSettle();
        expect(find.text('Spectrum focus'), findsOneWidget);
        expect(
          tester
              .widget<SignalChart>(find.byType(SignalChart).last)
              .hiddenBssids,
          {ap.bssid},
        );
        expect(
          tester.widget<SignalChart>(find.byType(SignalChart).last).time,
          isTrue,
        );
        await tester.ensureVisible(find.byType(ChartInspection).last);
        await tester.tapAt(
          tester.getTopLeft(find.byType(ChartInspection).last) +
              const Offset(80, 100),
        );
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.text('Spectrum focus'), findsNothing);
        expect(scroll.offset, offset);
        expect(selection.timeGraph, isTrue);
        expect(selection.hidden({ap.bssid}), {ap.bssid});
        await tester.tap(find.text('Focus chart'));
        await tester.pumpAndSettle();
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.text('Spectrum focus'), findsNothing);
        expect(scroll.offset, offset);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'Overview action preserves chart context; internal actions never navigate',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [analyserProvider.overrideWith(ChartModel.new)],
          child: const MaterialApp(home: AnalyserHome()),
        ),
      );
      await tester.ensureVisible(find.byTooltip('Show signal history'));
      await tester.tap(find.byTooltip('Show signal history'));
      await tester.pumpAndSettle();
      expect(find.text('Open Spectrum'), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const ValueKey('chart-legend-test')),
      );
      await tester.tap(find.byKey(const ValueKey('chart-legend-test')));
      await tester.pumpAndSettle();
      expect(find.text('Open Spectrum'), findsOneWidget);
      await tester.ensureVisible(find.text('Open Spectrum'));
      await tester.tap(find.text('Open Spectrum'));
      await tester.pumpAndSettle();
      expect(find.text('Focus chart'), findsOneWidget);
      final chart = tester.widget<SignalChart>(find.byType(SignalChart));
      expect(chart.band, WifiBand.ghz6);
      expect(chart.time, isTrue);
      expect(chart.hiddenBssids, {ap.bssid});
      expect(tester.takeException(), isNull);
    },
  );
}
