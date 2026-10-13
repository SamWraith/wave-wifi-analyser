import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:wifi_analyser/models/comparison_session.dart';
import 'package:wifi_analyser/repositories/comparison_sessions_repository.dart';
import 'package:wifi_analyser/viewmodels/comparison_sessions_view_model.dart';
import 'package:wifi_analyser/views/comparison_export_page.dart';

class _Storage implements ComparisonSessionsRepository {
  _Storage(this.sessions);
  final List<ComparisonSession> sessions;
  @override
  Future<List<ComparisonSession>> load() async => sessions;
  @override
  Future<void> save(List<ComparisonSession> sessions) async {}
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Android opens real two-file chooser and cancellation returns to preview',
    (tester) async {
      final sessions = [
        ComparisonSession(
          id: 'native-test',
          bssid: 'aa:bb:cc:dd:ee:ff',
          ssid: 'DO NOT EXPORT',
          label: 'DO NOT EXPORT',
          demo: true,
          start: DateTime.utc(2026, 10, 13),
          end: DateTime.utc(2026, 10, 13, 0, 1),
          samples: [
            SessionSample(
              at: DateTime.utc(2026, 10, 13, 0, 0, 10),
              rssi: -63,
              frequency: 5180,
              width: 80,
              centerFrequency: 5210,
            ),
          ],
        ),
      ];
      final container = ProviderContainer(
        overrides: [
          comparisonSessionsRepositoryProvider.overrideWithValue(
            _Storage(sessions),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(comparisonSessionsProvider.notifier).ready;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(home: ComparisonExportPage(sessions: sessions)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('DO NOT EXPORT'), findsNothing);
      await tester.tap(find.text('Share reviewed files'));
      await tester.pump();
      // Harness dismisses Android chooser with Back, without selecting a receiver.
      debugPrint('WAVE_EXPORT_CHOOSER_READY');
      for (
        var i = 0;
        i < 60 &&
            find
                .text('Sharing cancelled. Nothing confirmed sent.')
                .evaluate()
                .isEmpty;
        i++
      ) {
        await tester.pump(const Duration(seconds: 1));
      }
      expect(
        find.text('Sharing cancelled. Nothing confirmed sent.'),
        findsOneWidget,
      );
      expect(find.text('Share again'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
