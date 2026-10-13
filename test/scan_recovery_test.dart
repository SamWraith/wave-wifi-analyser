import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wifi_analyser/models/analyser_state.dart';
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
}
