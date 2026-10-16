import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wifi_analyser/models/analyser_state.dart';
import 'package:wifi_analyser/models/wifi_data_source.dart';
import 'package:wifi_analyser/repositories/wifi_repository.dart';
import 'package:wifi_analyser/viewmodels/analyser_view_model.dart';
import 'package:wifi_analyser/views/analyser_navigation.dart';

class RecoveryModel extends AnalyserViewModel {
  WifiSettingsTarget? opened;
  int scans = 0;
  @override
  AnalyserState build() => AnalyserState(demo: false);
  void update(AnalyserState value) => state = value;
  @override
  Future<void> scan({bool requestPermission = true}) async {
    scans++;
  }

  @override
  Future<void> openSettings({
    WifiSettingsTarget target = WifiSettingsTarget.wifi,
  }) async {
    opened = target;
  }
}

void main() {
  testWidgets(
    'recovery follows permission, Location, WiFi and respects demo/pause',
    (tester) async {
      tester.view.physicalSize = const Size(360, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final model = RecoveryModel();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [analyserProvider.overrideWith(() => model)],
          child: const MaterialApp(
            home: Scaffold(
              body: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(2)),
                child: ScanStatusBar(),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Allow precise location'));
      expect(model.scans, 1);
      await tester.tap(find.text('App permissions'));
      expect(model.opened, WifiSettingsTarget.permission);
      model.update(AnalyserState(demo: false, permission: true));
      await tester.pump();
      await tester.tap(find.text('Enable Location'));
      expect(model.opened, WifiSettingsTarget.location);
      model.update(
        AnalyserState(demo: false, permission: true, locationEnabled: true),
      );
      await tester.pump();
      await tester.tap(find.text('Enable WiFi'));
      expect(model.opened, WifiSettingsTarget.wifi);
      model.update(AnalyserState(demo: true));
      await tester.pump();
      expect(find.text('Enable WiFi'), findsNothing);
      model.update(AnalyserState(demo: false, paused: true));
      await tester.pump();
      expect(find.text('Allow precise location'), findsNothing);
      expect(find.text('No fresh result received yet'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  for (final source in [
    WifiDataSource.macos,
    WifiDataSource.windows,
    WifiDataSource.linux,
  ]) {
    testWidgets(
      '${source.label} recovery distinguishes unavailable hardware and redacted identifiers',
      (tester) async {
        final model = RecoveryModel();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [analyserProvider.overrideWith(() => model)],
            child: const MaterialApp(home: Scaffold(body: ScanStatusBar())),
          ),
        );
        model.update(
          AnalyserState(demo: false, liveSource: source, wifiEnabled: true),
        );
        await tester.pump();
        await tester.tap(
          find.text(
            source == WifiDataSource.linux
                ? 'Authorize WiFi scan'
                : 'Allow location',
          ),
        );
        expect(model.scans, 1);
        await tester.tap(
          find.text(
            source == WifiDataSource.linux
                ? 'Network settings'
                : 'Location privacy settings',
          ),
        );
        expect(model.opened, WifiSettingsTarget.permission);
        model.update(
          AnalyserState(
            demo: false,
            liveSource: source,
            permission: true,
            locationEnabled: true,
            interfaceAvailable: false,
          ),
        );
        await tester.pump();
        expect(find.text('Enable WiFi'), findsNothing);
        expect(
          find.textContaining('WiFi interface unavailable.'),
          findsOneWidget,
        );
        model.update(
          AnalyserState(
            demo: false,
            liveSource: source,
            permission: true,
            locationEnabled: true,
            wifiEnabled: true,
            redactedCount: 2,
          ),
        );
        await tester.pump();
        if (source == WifiDataSource.linux) {
          expect(
            find.textContaining('Identifiers unavailable from Linux driver'),
            findsOneWidget,
          );
          expect(find.text('Review Location access'), findsNothing);
        } else {
          await tester.tap(find.text('Review Location access'));
          expect(model.opened, WifiSettingsTarget.permission);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  testWidgets('Windows radio-off recovery works before first location grant', (
    tester,
  ) async {
    final model = RecoveryModel();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [analyserProvider.overrideWith(() => model)],
        child: const MaterialApp(home: Scaffold(body: ScanStatusBar())),
      ),
    );
    model.update(
      AnalyserState(demo: false, liveSource: WifiDataSource.windows),
    );
    await tester.pump();
    expect(find.text('Allow location'), findsNothing);
    await tester.tap(find.text('Enable WiFi'));
    expect(model.opened, WifiSettingsTarget.wifi);
    model.update(
      AnalyserState(
        demo: false,
        liveSource: WifiDataSource.windows,
        interfaceAvailable: false,
      ),
    );
    await tester.pump();
    expect(find.text('Enable WiFi'), findsNothing);
    expect(find.textContaining('WiFi interface unavailable'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
