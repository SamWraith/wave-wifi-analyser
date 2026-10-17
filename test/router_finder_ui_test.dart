import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wifi_analyser/models/analyser_state.dart';
import 'package:wifi_analyser/models/wifi_data_source.dart';
import 'package:wifi_analyser/viewmodels/analyser_view_model.dart';
import 'package:wifi_analyser/viewmodels/ap_preferences_view_model.dart';
import 'package:wifi_analyser/views/app_theme.dart';
import 'package:wifi_analyser/views/router_finder_page.dart';
import 'package:wifi_analyser/widgets/network_tile.dart';

import 'router_finder_test.dart' show FinderScan, target, point, observation;

class _Preferences extends ApPreferencesViewModel {
  @override
  ApPreferencesState build() => ApPreferencesState();
}

void main() {
  const capturePreview = bool.fromEnvironment('WAVE_CAPTURE_FINDER');
  late ProviderContainer container;
  late FinderScan scan;
  setUp(() {
    container = ProviderContainer(
      overrides: [
        analyserProvider.overrideWith(FinderScan.new),
        apPreferencesProvider.overrideWith(_Preferences.new),
      ],
    );
    scan = container.read(analyserProvider.notifier) as FinderScan;
    scan.emit(observation([], ap: target, source: WifiDataSource.demo));
  });
  tearDown(() => container.dispose());

  Future<void> show(
    WidgetTester tester, {
    Widget? home,
    bool dark = false,
    double scale = 1,
  }) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(dark ? Brightness.dark : Brightness.light),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: home ?? const RouterFinderPage(target: target),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'network details opens finder, scan action works and back returns',
    (tester) async {
      await show(
        tester,
        home: const Scaffold(body: NetworkTile(ap: target)),
      );
      await tester.tap(find.text('Test mesh'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Find this router'));
      await tester.tap(find.text('Find this router'));
      await tester.pumpAndSettle();
      expect(find.text('Router finder'), findsOneWidget);
      expect(find.text('SIMULATED DEMO — not measured'), findsOneWidget);
      await tester.tap(find.text('Request scan'));
      expect(scan.requests, 1);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Find this router'), findsOneWidget);
      expect(find.text('Router finder'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'finder shows accepted changes, missing target and source switch honestly',
    (tester) async {
      await show(tester);
      final first = SignalSample(DateTime(2026), -70);
      scan.emit(
        observation([first], ap: point(-70), source: WifiDataSource.demo),
      );
      await tester.pump();
      final second = SignalSample(DateTime(2026, 1, 1, 0, 1), -60);
      scan.emit(
        observation(
          [first, second],
          ap: point(-60),
          source: WifiDataSource.demo,
        ),
      );
      await tester.pump();
      expect(find.text('Warmer • stronger signal'), findsOneWidget);
      expect(find.text('Start -70 dBm · Best -60 dBm'), findsOneWidget);
      await tester.ensureVisible(find.text('Start comparison here'));
      await tester.tap(find.text('Start comparison here'));
      await tester.pump();
      expect(find.text('— dBm'), findsOneWidget);
      final third = SignalSample(DateTime(2026, 1, 1, 0, 2), -55);
      scan.emit(
        observation(
          [first, second, third],
          ap: point(-55),
          source: WifiDataSource.demo,
        ),
      );
      await tester.pump();
      expect(find.text('Start -55 dBm · Best -55 dBm'), findsOneWidget);
      scan.emit(observation([first, second], source: WifiDataSource.demo));
      await tester.pump();
      expect(find.text('Guidance on hold'), findsOneWidget);
      expect(find.textContaining('Target not seen'), findsOneWidget);
      scan.emit(observation([first, second], ap: point(-60)));
      await tester.pump();
      expect(find.textContaining('Data source changed.'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Request scan'),
            )
            .onPressed,
        isNull,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('phone, desktop and large text layouts remain usable', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    for (final layout in [
      (width: 320.0, height: 800.0, scale: 2.0, dark: false),
      (width: 430.0, height: 932.0, scale: 1.0, dark: true),
      (width: 1280.0, height: 900.0, scale: 1.0, dark: false),
    ]) {
      tester.view.physicalSize = Size(layout.width, layout.height);
      await show(tester, dark: layout.dark, scale: layout.scale);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Request scan'));
      await tester.tap(find.text('Request scan'));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }
    expect(scan.requests, 3);
  });

  testWidgets(
    'render Android demo preview of finder with accepted observations',
    (tester) async {
      await tester.runAsync(() async {
        final sdk = Directory('.fvm/flutter_sdk').resolveSymbolicLinksSync();
        final fonts = '$sdk/bin/cache/artifacts/material_fonts';
        for (final entry in {
          'Arial': '$fonts/Roboto-Regular.ttf',
          'monospace': '$fonts/Roboto-Regular.ttf',
          'MaterialIcons': '$fonts/MaterialIcons-Regular.otf',
        }.entries) {
          final loader = FontLoader(entry.key)
            ..addFont(
              File(entry.value).readAsBytes().then(ByteData.sublistView),
            );
          await loader.load();
        }
      });
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(430, 1100);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const capture = ValueKey('finder-preview');
      await show(
        tester,
        dark: true,
        home: const RepaintBoundary(
          key: capture,
          child: RouterFinderPage(target: target),
        ),
      );
      final first = SignalSample(DateTime.now(), -70);
      scan.emit(
        observation([first], ap: point(-70), source: WifiDataSource.demo),
      );
      await tester.pump();
      final second = SignalSample(DateTime.now(), -58);
      scan.emit(
        observation(
          [first, second],
          ap: point(-58),
          source: WifiDataSource.demo,
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(capture),
        );
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory('build/router-finder').create(recursive: true);
        await File('build/router-finder/preview.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    skip: !capturePreview,
  );
}
