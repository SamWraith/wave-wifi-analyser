import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:wifi_analyser/models/access_point.dart';
import 'package:wifi_analyser/models/analyser_state.dart';
import 'package:wifi_analyser/viewmodels/analyser_view_model.dart';
import 'package:wifi_analyser/views/analyser_home.dart';
import 'package:wifi_analyser/widgets/chart_inspection.dart';
import 'package:wifi_analyser/widgets/signal_charts.dart';

const _ap = AccessPoint(
  ssid: 'Integration fixture',
  bssid: 'fixture',
  rssi: -50,
  frequency: 2484,
);

class _ChartModel extends AnalyserViewModel {
  @override
  AnalyserState build() => AnalyserState(
    demo: true,
    accessPoints: [_ap],
    history: {
      _ap.bssid: [
        SignalSample(DateTime(2026), -50),
        SignalSample(DateTime(2026, 1, 1, 0, 0, 35), -60),
      ],
    },
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Android chart exploration preserves selection and page scroll', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [analyserProvider.overrideWith(_ChartModel.new)],
        child: const MaterialApp(home: AnalyserHome()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(ChartInspection));
    final position =
        tester.getTopLeft(find.byType(ChartInspection)) + const Offset(90, 90);
    await tester.dragFrom(position, const Offset(120, 0));
    await tester.pumpAndSettle();
    expect(find.textContaining('Cursor coordinates:'), findsOneWidget);
    await tester.tap(find.byTooltip('Dismiss inspection'));
    await tester.pumpAndSettle();
    final before = tester.getTopLeft(find.byType(ChartInspection)).dy;
    await tester.dragFrom(position, const Offset(0, 80));
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.byType(ChartInspection)).dy,
      greaterThan(before),
    );
    expect(find.textContaining('Cursor coordinates:'), findsNothing);
    await tester.ensureVisible(find.byTooltip('Show signal history'));
    await tester.tap(find.byTooltip('Show signal history'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('chart-legend-fixture')),
    );
    await tester.tap(find.byKey(const ValueKey('chart-legend-fixture')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Open Spectrum'));
    await tester.tap(find.text('Open Spectrum'));
    await tester.pumpAndSettle();
    final chart = tester.widget<SignalChart>(find.byType(SignalChart));
    expect(chart.time, isTrue);
    expect(chart.hiddenBssids, {_ap.bssid});
    await tester.ensureVisible(find.text('Focus chart'));
    await tester.tap(find.text('Focus chart'));
    await tester.pumpAndSettle();
    expect(find.text('Spectrum focus'), findsOneWidget);
    expect(
      tester.widget<SignalChart>(find.byType(SignalChart).last).height,
      greaterThan(chart.height),
    );
    await tester.tap(find.byTooltip('Close focus'));
    await tester.pumpAndSettle();
    expect(find.text('Spectrum focus'), findsNothing);
    expect(tester.widget<SignalChart>(find.byType(SignalChart)).hiddenBssids, {
      _ap.bssid,
    });
    expect(tester.takeException(), isNull);
  });
}
