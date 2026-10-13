import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:wifi_analyser/models/access_point.dart';
import 'package:wifi_analyser/models/analyser_state.dart';
import 'package:wifi_analyser/viewmodels/analyser_view_model.dart';
import 'package:wifi_analyser/viewmodels/channel_planning_view_model.dart';
import 'package:wifi_analyser/views/analyser_home.dart';

class _Model extends AnalyserViewModel {
  @override
  AnalyserState build() => AnalyserState(
    demo: true,
    band: WifiBand.ghz5,
    accessPoints: const [
      AccessPoint(
        ssid: 'Simulated Office',
        bssid: 'aa:bb:cc:dd:ee:01',
        rssi: -50,
        frequency: 5180,
        width: 80,
        centerFrequency: 5210,
      ),
    ],
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Android planner applies width, recovers invalid edit, shows reasons and cancels',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [analyserProvider.overrideWith(_Model.new)],
          child: const MaterialApp(home: AnalyserHome()),
        ),
      );
      await tester.pumpAndSettle();
      Future<void> tap(String text) async {
        await tester.ensureVisible(find.text(text).last);
        await tester.tap(find.text(text).last);
        await tester.pumpAndSettle();
      }

      await tap('Channels');
      await tap('Change assumptions');
      await tap('80 MHz');
      await tester.enterText(find.byType(TextField), '36,40,36');
      await tap('Apply plan');
      expect(find.text('CH 36 • center 5210 MHz'), findsOneWidget);
      await tap('CH 36 • center 5210 MHz');
      expect(find.textContaining('Simulated Office'), findsOneWidget);
      expect(
        find.textContaining(
          'Reported 80 MHz • primary 5180 MHz • center 5210 MHz',
        ),
        findsOneWidget,
      );
      await tap('Change assumptions');
      await tester.enterText(find.byType(TextField), '144');
      await tap('160 MHz');
      await tap('Apply plan');
      expect(find.textContaining('has no supported 160 MHz'), findsOneWidget);
      await tap('Cancel');
      final container = ProviderScope.containerOf(
        tester.element(find.byType(AnalyserHome)),
      );
      expect(container.read(selectedPlanningAssumptionsProvider).width, 80);
      await tap('Reset this band');
      expect(container.read(selectedPlanningAssumptionsProvider).width, 20);
      expect(tester.takeException(), isNull);
    },
  );
}
