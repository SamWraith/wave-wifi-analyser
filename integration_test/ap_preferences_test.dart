import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wifi_analyser/models/access_point.dart';
import 'package:wifi_analyser/models/analyser_state.dart';
import 'package:wifi_analyser/repositories/ap_preferences_repository.dart';
import 'package:wifi_analyser/viewmodels/analyser_view_model.dart';
import 'package:wifi_analyser/viewmodels/ap_preferences_view_model.dart';
import 'package:wifi_analyser/views/networks_page.dart';

const point = AccessPoint(
  ssid: 'Shared SSID',
  bssid: '11:22:33:44:55:66',
  rssi: -55,
  frequency: 2412,
);

class FixtureModel extends AnalyserViewModel {
  @override
  AnalyserState build() => AnalyserState(demo: true, accessPoints: [point]);
  void disappear() => state = state.copyWith(accessPoints: []);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Android preferences survive relaunch and missing favorite stays honest',
    (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(apPreferencesStorageKey);
      final container = ProviderContainer(
        overrides: [analyserProvider.overrideWith(FixtureModel.new)],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: SingleChildScrollView(child: NetworksPage())),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Shared SSID'));
      await tester.tap(find.text('Shared SSID'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Add favorite'));
      await tester.tap(find.text('Add favorite'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add local alias'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Desk router');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(
        container.read(apPreferencesProvider).entries[point.bssid]!.alias,
        'Desk router',
      );
      Navigator.of(tester.element(find.text('Remove favorite'))).pop();
      await tester.pumpAndSettle();
      (container.read(analyserProvider.notifier) as FixtureModel).disappear();
      await tester.pumpAndSettle();
      expect(find.textContaining('Not seen ·'), findsOneWidget);
      expect(find.text('dBm'), findsNothing);
      expect(container.read(analyserProvider).history, isEmpty);
      expect(container.read(analyserProvider).lastUpdated, isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      final restarted = ProviderContainer(
        overrides: [analyserProvider.overrideWith(FixtureModel.new)],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: restarted,
          child: const MaterialApp(
            home: Scaffold(body: SingleChildScrollView(child: NetworksPage())),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        restarted.read(apPreferencesProvider).entries[point.bssid]!.favorite,
        isTrue,
      );
      expect(find.text('Desk router'), findsNWidgets(2));
      expect(find.text('Shared SSID'), findsNWidgets(2));
      await tester.pumpWidget(const SizedBox.shrink());
      restarted.dispose();
      await prefs.remove(apPreferencesStorageKey);
    },
  );
}
