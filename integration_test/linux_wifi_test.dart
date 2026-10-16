import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wifi_analyser/app.dart';
import 'package:wifi_analyser/viewmodels/analyser_view_model.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:wifi_analyser/models/wifi_data_source.dart';
import 'package:wifi_analyser/repositories/wifi_repository.dart';

/// Works on a Linux desktop with or without system D-Bus/NetworkManager/radio.
/// Error-state proof alone does not qualify live RF measurements or permissions.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Linux native bridge reports live source or explicit service error',
    (tester) async {
      final repo = LinuxWifiRepository();
      await repo.cancelScan();
      try {
        final state = await repo.snapshot();
        expect(state.source, WifiDataSource.linux);
        expect(state.scanCompleted, isFalse);
        expect(state.scanRequested, isFalse);
        expect(state.fresh, isFalse);
        expect(state.locationEnabled, isTrue);
        for (final ap in state.accessPoints) {
          expect(ap.width, 0);
          expect(ap.timestamp, 0);
          expect(ap.centerFrequency, isNull);
          expect(ap.rssi, inInclusiveRange(-127, 0));
        }
        final scan = await repo.scan(interactive: false);
        expect(scan.source, WifiDataSource.linux);
        if (scan.scanCompleted) expect(scan.completionId, greaterThan(0));
      } on PlatformException catch (error) {
        expect(error.code, isNotEmpty);
        expect(error.code, isNot('invalid_snapshot'));
        expect(error.message, isNotEmpty);
      }
      await repo.cancelScan();
      await (await SharedPreferences.getInstance()).setBool(
        'onboardingComplete',
        true,
      );
      await tester.pumpWidget(const ProviderScope(child: WaveApp()));
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(WaveApp)),
      );
      await container.read(analyserProvider.notifier).ready;
      await tester.pumpAndSettle();
      expect(container.read(analyserProvider).demo, isFalse);
      expect(container.read(analyserProvider).source, WifiDataSource.linux);
      expect(container.read(analyserProvider).status, isNotEmpty);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit5);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(find.text('Appearance'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    skip: kIsWeb || defaultTargetPlatform != TargetPlatform.linux,
  );
}
