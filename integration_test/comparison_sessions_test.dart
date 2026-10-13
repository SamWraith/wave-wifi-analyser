import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wifi_analyser/models/access_point.dart';
import 'package:wifi_analyser/models/analyser_state.dart';
import 'package:wifi_analyser/repositories/comparison_sessions_repository.dart';
import 'package:wifi_analyser/viewmodels/analyser_view_model.dart';
import 'package:wifi_analyser/viewmodels/comparison_sessions_view_model.dart';
import 'package:wifi_analyser/views/sessions_page.dart';

const point = AccessPoint(
  ssid: 'Fixture WiFi',
  bssid: '11:22:33:44:55:66',
  rssi: -55,
  frequency: 2412,
);

class FixtureModel extends AnalyserViewModel {
  @override
  AnalyserState build() => AnalyserState(demo: true, accessPoints: [point]);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Android room sessions persist, compare and delete; observations explicitly simulated',
    (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(comparisonSessionsStorageKey);
      ProviderContainer create() => ProviderContainer(
        overrides: [analyserProvider.overrideWith(FixtureModel.new)],
      );
      var container = create();
      Future<void> show() async {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: SessionsPage()),
          ),
        );
        await tester.pumpAndSettle();
      }

      await show();
      for (final room in ['Study', 'Hall']) {
        await tester.ensureVisible(
          find.byType(DropdownButtonFormField<String>),
        );
        await tester.tap(find.byType(DropdownButtonFormField<String>));
        await tester.pumpAndSettle();
        await tester.tap(find.text(point.bssid).last);
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextFormField), room);
        await tester.ensureVisible(find.text('Start simulated session'));
        await tester.tap(find.text('Start simulated session'));
        await tester.pumpAndSettle();
        expect(
          container.read(comparisonSessionsProvider).active!.samples,
          isEmpty,
        );
        final vm = container.read(comparisonSessionsProvider.notifier);
        vm.observe([point], {}, demo: true);
        final measured = AccessPoint(
          ssid: point.ssid,
          bssid: point.bssid,
          rssi: room == 'Study' ? -65 : -55,
          frequency: 2412,
        );
        vm.observe([measured], {point.bssid: measured}, demo: true);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Stop and save'));
        await tester.tap(find.text('Stop and save'));
        await tester.pumpAndSettle();
        expect(
          container.read(comparisonSessionsProvider).sessions.last.samples,
          hasLength(1),
        );
      }
      final loaded = await LocalComparisonSessionsRepository().load();
      expect(loaded, hasLength(2));
      expect(loaded.every((s) => s.demo), isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      container = create();
      await show();
      expect(container.read(comparisonSessionsProvider).sessions, hasLength(2));
      for (var i = 0; i < 2; i++) {
        final checkbox = find.byType(Checkbox).at(i);
        await tester.ensureVisible(checkbox);
        await tester.tap(checkbox);
        await tester.pumpAndSettle();
      }
      await tester.ensureVisible(find.text('Compare rooms'));
      expect(find.text('Median delta vs Study: +10.0 dB'), findsOneWidget);
      await tester.ensureVisible(find.byTooltip('Delete Study'));
      await tester.tap(find.byTooltip('Delete Study'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep'));
      await tester.pumpAndSettle();
      expect(container.read(comparisonSessionsProvider).sessions, hasLength(2));
      await tester.tap(find.byTooltip('Delete Study'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect((await LocalComparisonSessionsRepository().load()), hasLength(1));
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await prefs.remove(comparisonSessionsStorageKey);
    },
  );
}
