import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wifi_analyser/models/access_point.dart';
import 'package:wifi_analyser/models/analyser_state.dart';
import 'package:wifi_analyser/viewmodels/analyser_view_model.dart';
import 'package:wifi_analyser/views/chart_panel.dart';
import 'package:wifi_analyser/views/wifi_guidance_sheet.dart';
import 'package:wifi_analyser/widgets/network_tile.dart';
import 'package:wifi_analyser/widgets/signal_charts.dart';

const point = AccessPoint(
  ssid: 'Home',
  bssid: 'aa:bb:cc:dd:ee:ff',
  rssi: -62,
  frequency: 2412,
  security: 'WPA2 Enterprise authentication',
);

class PolishModel extends AnalyserViewModel {
  @override
  AnalyserState build() => AnalyserState(demo: true, accessPoints: [point]);
  void update() => state = state.copyWith(
    accessPoints: [
      const AccessPoint(
        ssid: 'Home',
        bssid: 'aa:bb:cc:dd:ee:ff',
        rssi: -60,
        frequency: 2412,
      ),
    ],
  );
}

class SheetObserver extends NavigatorObserver {
  ModalBottomSheetRoute<dynamic>? sheet;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is ModalBottomSheetRoute) sheet = route;
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final scale in [1.0, 2.0, 3.0]) {
    for (final brightness in Brightness.values) {
      testWidgets('selectable details fit 360px at ${scale}x in $brightness', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: ThemeData(brightness: brightness),
              home: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: const Scaffold(body: AccessPointDetailsSheet(ap: point)),
              ),
            ),
          ),
        );
        expect(find.text(point.bssid), findsOneWidget);
        expect(find.byType(SelectableText), findsNWidgets(7));
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text(point.security));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text('Copy MAC address'));
        await tester.pumpAndSettle();
        expect(find.text('Copy MAC address').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }

  for (final preferences in [(false, false), (true, false), (false, true)]) {
    for (final guide in [true, false]) {
      testWidgets(
        '${guide ? 'guide' : 'details'} sheet open/close obeys preferences $preferences',
        (tester) async {
          final navigator = GlobalKey<NavigatorState>();
          final observer = SheetObserver();
          await tester.pumpWidget(
            ProviderScope(
              overrides: [analyserProvider.overrideWith(PolishModel.new)],
              child: MaterialApp(
                navigatorKey: navigator,
                navigatorObservers: [observer],
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    disableAnimations: preferences.$1,
                    accessibleNavigation: preferences.$2,
                  ),
                  child: child!,
                ),
                home: Builder(
                  builder: (context) => Scaffold(
                    body: TextButton(
                      onPressed: () {
                        if (guide) {
                          showWifiGuidance(context);
                        } else {
                          showAccessPointDetails(context, point);
                        }
                      },
                      child: const Text('Open'),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('Open'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 40));
          final reduced = preferences.$1 || preferences.$2;
          expect(
            observer.sheet!.animation!.value,
            reduced ? 1 : allOf(greaterThan(0), lessThan(1)),
          );
          await tester.pumpAndSettle();
          expect(observer.sheet!.animation!.value, 1);
          navigator.currentState!.pop();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 40));
          if (reduced) {
            expect(
              find.byType(
                guide ? WifiGuidanceSheet : AccessPointDetailsSheet,
                skipOffstage: false,
              ),
              findsNothing,
            );
          } else {
            expect(
              observer.sheet!.animation!.value,
              allOf(greaterThan(0), lessThan(1)),
            );
          }
          await tester.pumpAndSettle();
          expect(
            find.byType(
              guide ? WifiGuidanceSheet : AccessPointDetailsSheet,
              skipOffstage: false,
            ),
            findsNothing,
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }

  testWidgets(
    'chart mode has one selection haptic per action, none for new data',
    (tester) async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            calls.add(call);
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );
      final model = PolishModel();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [analyserProvider.overrideWith(() => model)],
          child: const MaterialApp(
            home: Scaffold(body: SingleChildScrollView(child: ChartPanel())),
          ),
        ),
      );
      await tester.pumpAndSettle();
      calls.clear();
      for (final tooltip in ['Show signal history', 'Show channel graph']) {
        await tester.tap(find.byTooltip(tooltip));
        await tester.pumpAndSettle();
      }
      expect(
        calls
            .where((call) => call.method == 'HapticFeedback.vibrate')
            .map((call) => call.arguments),
        [
          'HapticFeedbackType.selectionClick',
          'HapticFeedbackType.selectionClick',
        ],
      );
      expect(
        tester.widget<SignalChart>(find.byType(SignalChart)).time,
        isFalse,
      );
      calls.clear();
      model.update();
      await tester.pumpAndSettle();
      expect(
        calls.where((call) => call.method == 'HapticFeedback.vibrate'),
        isEmpty,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant({TargetPlatform.android}),
  );
}
