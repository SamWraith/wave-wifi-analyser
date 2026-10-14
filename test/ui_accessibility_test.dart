import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wifi_analyser/models/access_point.dart';
import 'package:wifi_analyser/models/analyser_state.dart';
import 'package:wifi_analyser/models/channel_plan.dart';
import 'package:wifi_analyser/models/comparison_session.dart';
import 'package:wifi_analyser/viewmodels/analyser_view_model.dart';
import 'package:wifi_analyser/viewmodels/comparison_sessions_view_model.dart';
import 'package:wifi_analyser/views/analyser_home.dart';
import 'package:wifi_analyser/views/analyser_navigation.dart';
import 'package:wifi_analyser/views/app_theme.dart';
import 'package:wifi_analyser/views/comparison_export_page.dart';
import 'package:wifi_analyser/widgets/channel_planning_controls.dart';
import 'package:wifi_analyser/widgets/chart_inspection.dart';
import 'package:wifi_analyser/widgets/chart_legend_item.dart';
import 'package:wifi_analyser/widgets/comparison_export_preview.dart';
import 'package:wifi_analyser/widgets/network_tile.dart';
import 'package:wifi_analyser/widgets/signal_charts.dart';
import 'package:wifi_analyser/widgets/wave_components.dart';

const point = AccessPoint(
  ssid: 'Studio Network',
  bssid: 'A4:83:E7:12:80:4C',
  rssi: -60,
  frequency: 2437,
  security: 'Open',
);

class UiModel extends AnalyserViewModel {
  @override
  AnalyserState build() => AnalyserState(
    demo: true,
    accessPoints: [point],
    status: 'Simulated scan complete',
    lastUpdated: DateTime(2026),
  );
}

final session = ComparisonSession(
  id: 'ui',
  bssid: point.bssid,
  ssid: point.ssid,
  label: 'Study',
  start: DateTime(2026),
  end: DateTime(2026, 1, 1, 0, 1),
);

class UiSessions extends ComparisonSessionsViewModel {
  @override
  ComparisonSessionsState build() =>
      ComparisonSessionsState(sessions: [session]);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  Future<void> show(
    WidgetTester tester,
    Widget home, {
    Size size = const Size(360, 800),
    double scale = 2,
    Brightness brightness = Brightness.light,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          analyserProvider.overrideWith(UiModel.new),
          comparisonSessionsProvider.overrideWith(UiSessions.new),
        ],
        child: MaterialApp(
          theme: buildAppTheme(brightness),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              disableAnimations: true,
            ),
            child: child!,
          ),
          home: home,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'large-text scan summary has no reserved blank slot and reachable controls',
    (tester) async {
      await show(
        tester,
        const Scaffold(
          body: Padding(
            padding: EdgeInsets.all(20),
            child: SingleChildScrollView(child: ScanStatusBar()),
          ),
        ),
      );
      final status = tester.getRect(find.text('Simulated scan complete'));
      final age = tester.getRect(find.textContaining('Last simulated update'));
      expect(age.top - status.bottom, inInclusiveRange(0, 2));
      expect(
        tester.getRect(find.byTooltip('Pause scanning')).top,
        greaterThan(age.bottom),
      );
      expect(find.byTooltip('Scan now').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'large-text bottom navigation keeps full names accessible and changes page',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await show(tester, const AnalyserHome());
      final navigation = tester.widget<NavigationBar>(
        find.byType(NavigationBar),
      );
      expect(
        navigation.labelBehavior,
        NavigationDestinationLabelBehavior.alwaysHide,
      );
      expect(find.byTooltip('Networks'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.wifi_rounded).last);
      await tester.pumpAndSettle();
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        2,
      );
      expect(find.text('Access points'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      semantics.dispose();
    },
  );

  testWidgets(
    'open-network icon is unlocked and large-text metadata gets full row width',
    (tester) async {
      for (final brightness in Brightness.values) {
        await show(
          tester,
          const Scaffold(
            body: Padding(
              padding: EdgeInsets.all(20),
              child: SingleChildScrollView(child: NetworkTile(ap: point)),
            ),
          ),
          brightness: brightness,
        );
        expect(find.byIcon(Icons.wifi_lock_rounded), findsNothing);
        expect(find.byIcon(Icons.wifi_rounded), findsOneWidget);
        final signal = tester.getRect(find.text('-60'));
        final metadata = tester.getRect(find.text('CH 6 · Open · 20 MHz'));
        expect(metadata.top, greaterThan(signal.bottom));
        expect(tester.getRect(find.text(point.bssid)).left, lessThan(30));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      }
    },
  );

  testWidgets(
    'channel field has short label and untruncated instructions outside input',
    (tester) async {
      await show(
        tester,
        PlanningAssumptionsDialog(
          band: WifiBand.ghz5,
          assumptions: PlanningAssumptions(width: 80),
        ),
      );
      final input = tester.widget<TextField>(find.byType(TextField));
      expect(input.decoration!.labelText, 'Channels');
      expect(find.text('Primary channels'), findsOneWidget);
      final instructions = find.text(
        'Separate with commas or spaces. Blank restores examples; duplicates merge.',
      );
      await tester.ensureVisible(instructions);
      await tester.pumpAndSettle();
      expect(instructions.hitTestable(), findsOneWidget);
      expect(tester.widget<Text>(instructions).maxLines, isNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('chart scales axes, repaints and keeps cursor on same geometry', (
    tester,
  ) async {
    Future<(CustomPainter, ChartInspection)> chart(double scale) async {
      await show(
        tester,
        const Scaffold(
          body: SignalChart(points: [point], band: WifiBand.ghz24),
        ),
        scale: scale,
      );
      final painter = tester
          .widget<CustomPaint>(
            find.descendant(
              of: find.byType(SignalChart),
              matching: find.byType(CustomPaint),
            ),
          )
          .painter!;
      return (
        painter,
        tester.widget<ChartInspection>(find.byType(ChartInspection)),
      );
    }

    final normal = await chart(1);
    final large = await chart(2);
    expect(large.$1.shouldRepaint(normal.$1), isTrue);
    expect(
      large.$2.coordinates.plotInsets.left,
      greaterThan(normal.$2.coordinates.plotInsets.left),
    );
    final paintRect = tester.getRect(
      find.descendant(
        of: find.byType(SignalChart),
        matching: find.byType(CustomPaint),
      ),
    );
    final area = large.$2.coordinates.plotArea(paintRect.size);
    final x =
        area.left +
        large.$2.coordinates.spectrum.fraction(point.spectralCenter) *
            area.width;
    await tester.tapAt(paintRect.topLeft + Offset(x, area.center.dy));
    await tester.pump();
    expect(find.textContaining('Envelope: Studio Network'), findsOneWidget);
    expect(find.textContaining('-60.0 dBm'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('desktop export actions share content left edge', (tester) async {
    await show(
      tester,
      ComparisonExportPage(sessions: [session]),
      size: const Size(1280, 800),
      scale: 1,
    );
    final body = tester.getRect(find.byType(WavePanel).first);
    final action = tester.getRect(
      find.widgetWithText(FilledButton, 'Share reviewed files'),
    );
    expect(action.left, closeTo(body.left, 1));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('CSV remains exact selectable text with horizontal scrolling', (
    tester,
  ) async {
    const csv =
        'session,source,start_utc,end_utc,sample_count,rssi_dbm,frequency_mhz,reported_width_mhz\nSession 1,macOS,2026-01-01T00:00:00Z,2026-01-01T00:01:00Z,1,-60,2437,20';
    await show(
      tester,
      const Scaffold(
        body: SingleChildScrollView(
          child: ComparisonExportPreview(text: csv, csv: true),
        ),
      ),
      scale: 1,
    );
    expect(
      tester.widget<SelectableText>(find.byType(SelectableText)).data,
      csv,
    );
    final scroll = find.byWidgetPredicate(
      (widget) =>
          widget is SingleChildScrollView &&
          widget.scrollDirection == Axis.horizontal,
    );
    final controller = tester.widget<SingleChildScrollView>(scroll).controller!;
    expect(controller.position.maxScrollExtent, greaterThan(0));
    final viewport = tester.getRect(scroll);
    await tester.dragFrom(
      Offset(viewport.center.dx, viewport.bottom - 8),
      const Offset(-180, 0),
    );
    await tester.pumpAndSettle();
    expect(controller.offset, greaterThan(0));
    expect(
      tester.widget<SelectableText>(find.byType(SelectableText)).data,
      csv,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('legend wraps complete identity at ${scale}x text', (
      tester,
    ) async {
      final label = '${point.name} · CH ${point.channel} · 12:80:4C';
      await show(
        tester,
        Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Wrap(
                children: [
                  ChartLegendItem(
                    point: point,
                    visible: true,
                    solo: false,
                    nextAction: 'Hide',
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
        scale: scale,
      );
      final text = tester.getRect(find.text(label));
      final chip = tester.getRect(find.byType(FilterChip));
      expect(text.right, lessThanOrEqualTo(chip.right));
      if (scale == 2) expect(text.height, greaterThan(50));
      final paragraph = tester.renderObject<RenderParagraph>(
        find
            .descendant(
              of: find.byType(ChartLegendItem),
              matching: find.byType(RichText),
            )
            .first,
      );
      expect(
        paragraph.size.height,
        greaterThanOrEqualTo(
          paragraph.getMaxIntrinsicHeight(paragraph.size.width) - 1,
        ),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('AP details exposes explicit accessible close action', (
    tester,
  ) async {
    await show(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showAccessPointDetails(context, point),
            child: const Text('Open details'),
          ),
        ),
      ),
      scale: 1,
    );
    await tester.tap(find.text('Open details'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Close access point details'));
    await tester.pumpAndSettle();
    expect(find.byType(AccessPointDetailsSheet), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
