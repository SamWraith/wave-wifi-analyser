import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wifi_analyser/models/access_point.dart';
import 'package:wifi_analyser/models/analyser_state.dart';
import 'package:wifi_analyser/viewmodels/analyser_view_model.dart';
import 'package:wifi_analyser/views/chart_panel.dart';
import 'package:wifi_analyser/widgets/signal_charts.dart';

AccessPoint ap(int id, {int rssi = -50}) => AccessPoint(
  ssid: id < 2 ? 'Shared name' : 'WiFi $id',
  bssid: '00:11:22:33:44:$id',
  frequency: 5180 + id * 20,
  rssi: rssi,
);

class _ChartModel extends AnalyserViewModel {
  @override
  AnalyserState build() => AnalyserState(
    demo: true,
    band: WifiBand.ghz5,
    accessPoints: List.generate(9, ap),
  );

  void update(List<AccessPoint> points) =>
      state = state.copyWith(accessPoints: points);
}

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('legend cycles hide/include/solo/reset in $brightness', (
      tester,
    ) async {
      final model = _ChartModel();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [analyserProvider.overrideWith(() => model)],
          child: MaterialApp(
            theme: ThemeData(brightness: brightness),
            home: const Scaffold(
              body: SingleChildScrollView(child: ChartPanel()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      SignalChart chart() => tester.widget(find.byType(SignalChart));
      Finder chip(int id) =>
          find.byKey(ValueKey('chart-legend-${ap(id).bssid}'));
      Future<void> tap(int id) async {
        await tester.ensureVisible(chip(id));
        await tester.tap(chip(id));
        await tester.pumpAndSettle();
      }

      expect(find.byType(FilterChip), findsNWidgets(9));
      expect(chart().hiddenBssids, isEmpty);
      await tap(0);
      expect(chart().hiddenBssids, {ap(0).bssid});
      expect(tester.widget<FilterChip>(chip(0)).selected, isFalse);
      // Same SSID remains independent because legend identity uses BSSID.
      expect(tester.widget<FilterChip>(chip(1)).selected, isTrue);
      await tap(0);
      expect(chart().hiddenBssids, isEmpty);
      await tap(0);
      expect(chart().hiddenBssids, {for (var i = 1; i < 9; i++) ap(i).bssid});
      await tap(0);
      expect(chart().hiddenBssids, isEmpty);
      await tap(8);
      expect(chart().hiddenBssids, {ap(8).bssid});
      // Visibility survives chart mode changes and fresh signal/order updates.
      await tester.ensureVisible(find.byTooltip('Show signal history'));
      await tester.tap(find.byTooltip('Show signal history'));
      await tester.pumpAndSettle();
      expect(chart().time, isTrue);
      expect(chart().hiddenBssids, {ap(8).bssid});
      model.update([ap(8, rssi: -30), ...List.generate(8, ap)]);
      await tester.pumpAndSettle();
      expect(chart().hiddenBssids, {ap(8).bssid});
      expect(chart().points.first.rssi, -30);
      await tester.ensureVisible(find.text('Show all'));
      await tester.tap(find.text('Show all'));
      await tester.pumpAndSettle();
      expect(chart().hiddenBssids, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('solo can switch networks and missing solo never blanks chart', (
    tester,
  ) async {
    final model = _ChartModel();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [analyserProvider.overrideWith(() => model)],
        child: const MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: ChartPanel())),
        ),
      ),
    );
    await tester.pumpAndSettle();
    Future<void> tap(int id) async {
      final chip = find.byKey(ValueKey('chart-legend-${ap(id).bssid}'));
      await tester.ensureVisible(chip);
      await tester.tap(chip);
      await tester.pumpAndSettle();
    }

    SignalChart chart() => tester.widget(find.byType(SignalChart));
    for (var i = 0; i < 3; i++) {
      await tap(0);
    }
    await tap(1);
    expect(chart().hiddenBssids.contains(ap(1).bssid), isFalse);
    expect(chart().hiddenBssids.contains(ap(0).bssid), isTrue);
    model.update([ap(2), ap(3)]);
    await tester.pumpAndSettle();
    expect(chart().hiddenBssids, isEmpty);
    await tap(2);
    expect(chart().hiddenBssids, {ap(2).bssid});
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
