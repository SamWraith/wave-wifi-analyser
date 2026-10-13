import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wifi_analyser/models/access_point.dart';
import 'package:wifi_analyser/models/analyser_state.dart';
import 'package:wifi_analyser/widgets/chart_coordinates.dart';
import 'package:wifi_analyser/widgets/signal_charts.dart';
import 'package:wifi_analyser/widgets/spectrum_envelope.dart';

const point = AccessPoint(
  ssid: 'Curve',
  bssid: 'curve',
  frequency: 2462,
  centerFrequency: 2452,
  width: 40,
  rssi: -50,
);

void main() {
  test(
    'landscape marker lies on exact painted envelope and clamps to its edges',
    () {
      final coordinates = ChartCoordinates(WifiBand.ghz24, [point], {});
      final area = ChartCoordinates.area(const Size(350, 270));
      final path = SpectrumEnvelope.path(point, coordinates.spectrum, area);
      final metric = path.computeMetrics().single;
      // Compare inverse inspection against points along the actual cubic path.
      for (var i = 0; i <= 20; i++) {
        final at = metric.getTangentForOffset(metric.length * i / 20)!.position;
        final x = (at.dx - area.left) / area.width;
        final hit = coordinates.inspect(
          Offset(x, 0),
          area.size,
          timeGraph: false,
        )!;
        expect(area.left + hit.fraction.dx * area.width, closeTo(at.dx, .02));
        expect(area.top + hit.fraction.dy * area.height, closeTo(at.dy, .5));
      }
      final peak = coordinates.inspect(
        Offset(coordinates.spectrum.fraction(2452), 1),
        area.size,
        timeGraph: false,
      )!;
      expect(peak.rssi, closeTo(-50, .0001));
      for (final x in [0.0, 1.0]) {
        final edge = coordinates.inspect(
          Offset(x, .2),
          area.size,
          timeGraph: false,
        )!;
        expect(edge.rssi, closeTo(-100, .0001));
        expect(coordinates.frequency(edge.fraction.dx), x == 0 ? 2432 : 2472);
      }
      expect(
        coordinates.inspect(
          const Offset(.5, .5),
          area.size,
          timeGraph: false,
          hiddenBssids: {point.bssid},
        ),
        isNull,
      );
    },
  );

  test('history snaps to real samples across gaps, excludes hidden APs and resolves same-time curves', () {
    const other = AccessPoint(
      ssid: 'Other',
      bssid: 'other',
      frequency: 2462,
      rssi: -80,
    );
    final start = DateTime(2026);
    final end = start.add(const Duration(minutes: 5));
    final first = SignalSample(start, -50);
    final last = SignalSample(end, -60);
    final otherLast = SignalSample(end, -80);
    final coordinates = ChartCoordinates(
      WifiBand.ghz24,
      [point, other],
      {
        point.bssid: [first, last],
        other.bssid: [otherLast],
      },
    );
    final left = coordinates.inspect(
      const Offset(.1, 1),
      const Size(300, 200),
      timeGraph: true,
    )!;
    expect(left.sample, same(first));
    expect(left.fraction.dx, 0);
    expect(left.rssi, -50);
    final right = coordinates.inspect(
      const Offset(.8, .5),
      const Size(300, 200),
      timeGraph: true,
    )!;
    expect(right.sample, same(last));
    expect(right.fraction, const Offset(1, .5));
    final lower = coordinates.inspect(
      const Offset(.8, .75),
      const Size(300, 200),
      timeGraph: true,
    )!;
    expect(lower.point.bssid, other.bssid);
    expect(lower.sample, same(otherLast));
    final hidden = coordinates.inspect(
      const Offset(.8, .75),
      const Size(300, 200),
      timeGraph: true,
      hiddenBssids: {other.bssid},
    )!;
    expect(hidden.sample, same(last));
    expect(
      ChartCoordinates(
        WifiBand.ghz24,
        [point],
        {},
      ).inspect(const Offset(.5, .5), const Size(300, 200), timeGraph: true),
      isNull,
    );
  });

  testWidgets(
    'readout identifies recorded sample; hiding every curve removes marker',
    (tester) async {
      final sample = SignalSample(DateTime(2026, 10, 13, 12, 30), -55);
      Future<void> render({bool hidden = false}) => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SignalChart(
              points: [point],
              band: WifiBand.ghz24,
              time: true,
              history: {
                point.bssid: [sample],
              },
              hiddenBssids: hidden ? {point.bssid} : {},
            ),
          ),
        ),
      );
      await render();
      await tester.tapAt(const Offset(180, 90));
      await tester.pump();
      expect(
        find.textContaining('Recorded sample: Curve (curve)'),
        findsOneWidget,
      );
      expect(
        find.textContaining('2026-10-13 12:30:00 · -55 dBm'),
        findsOneWidget,
      );
      await render(hidden: true);
      await tester.pump();
      expect(find.textContaining('Recorded sample:'), findsNothing);
      expect(find.textContaining('No visible history samples'), findsOneWidget);
      await tester.tap(find.byTooltip('Dismiss inspection'));
      await tester.pump();
      expect(find.byTooltip('Dismiss inspection'), findsNothing);
    },
  );
}
