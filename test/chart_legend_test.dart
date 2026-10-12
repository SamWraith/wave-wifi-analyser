import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wifi_analyser/models/access_point.dart';
import 'package:wifi_analyser/models/analyser_state.dart';
import 'package:wifi_analyser/viewmodels/analyser_view_model.dart';
import 'package:wifi_analyser/views/chart_panel.dart';
import 'package:wifi_analyser/widgets/signal_charts.dart';
import 'package:wifi_analyser/widgets/chart_legend.dart';

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
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'compact legend scrolls/expands without losing selection at $scale',
      (tester) async {
        tester.view.physicalSize = const Size(390, 1100);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final model = _ChartModel();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [analyserProvider.overrideWith(() => model)],
            child: MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(
                  textScaler: TextScaler.linear(scale),
                  disableAnimations: scale == 2.0,
                ),
                child: const Scaffold(
                  body: SingleChildScrollView(
                    child: ChartPanel(compactLegend: true),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final legend = find.byType(ChartLegend);
        final collapsedHeight = tester.getSize(legend).height;
        expect(collapsedHeight, lessThanOrEqualTo(72));
        final scroll = find.byKey(const PageStorageKey('compact-chart-legend'));
        await tester.drag(scroll, const Offset(-2000, 0));
        await tester.pumpAndSettle();
        final lastChip = find.byKey(ValueKey('chart-legend-${ap(8).bssid}'));
        await tester.tap(lastChip);
        await tester.pumpAndSettle();
        expect(
          tester.widget<SignalChart>(find.byType(SignalChart)).hiddenBssids,
          {ap(8).bssid},
        );
        await tester.tap(find.byTooltip('Expand WiFi legends'));
        await tester.pumpAndSettle();
        expect(scroll, findsNothing);
        expect(tester.getSize(legend).height, greaterThan(collapsedHeight));
        expect(tester.widget<FilterChip>(lastChip).selected, isFalse);
        await tester.tap(find.byTooltip('Collapse WiFi legends'));
        await tester.pumpAndSettle();
        expect(scroll, findsOneWidget);
        expect(tester.getSize(legend).height, collapsedHeight);
        // More scan results do not add rows to the collapsed Overview legend.
        model.update(List.generate(40, ap));
        await tester.pumpAndSettle();
        expect(tester.getSize(legend).height, collapsedHeight);
        await tester.tap(find.byTooltip('Show all networks'));
        await tester.pumpAndSettle();
        expect(
          tester.widget<SignalChart>(find.byType(SignalChart)).hiddenBssids,
          isEmpty,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
