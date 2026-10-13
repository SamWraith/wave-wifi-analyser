import 'package:flutter/material.dart';
import 'package:wifi_analyser/widgets/scan_freshness.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wifi_analyser/models/scan_freshness.dart';

void main() {
  testWidgets(
    'age and stale qualifier advance while paused; clock stops in background',
    (tester) async {
      final at = DateTime(2026, 10, 13);
      var now = at;
      var reads = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: ScanFreshness(
            updated: at,
            demo: false,
            cached: false,
            clock: () {
              reads++;
              return now;
            },
          ),
        ),
      );
      expect(find.text('Last fresh result 0s ago'), findsOneWidget);
      now = at.add(const Duration(minutes: 2));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Last fresh result 2m ago'), findsOneWidget);
      expect(
        find.text('Older observations • recheck before comparing'),
        findsOneWidget,
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      final before = reads;
      now = at.add(const Duration(minutes: 5));
      await tester.pump(const Duration(seconds: 5));
      expect(reads, before);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(find.text('Last fresh result 5m ago'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      final disposedReads = reads;
      await tester.pump(const Duration(seconds: 5));
      expect(reads, disposedReads);
    },
  );
  test('age advances truthfully through seconds, minutes, hours and demo', () {
    final at = DateTime(2026, 10, 13);
    expect(scanAgeLabel(null, at, demo: false), 'No fresh result received yet');
    expect(
      scanAgeLabel(at, at.add(const Duration(seconds: 35)), demo: false),
      'Last fresh result 35s ago',
    );
    expect(
      scanAgeLabel(at, at.add(const Duration(minutes: 2)), demo: false),
      'Last fresh result 2m ago',
    );
    expect(isScanStale(at, at.add(const Duration(minutes: 2))), isTrue);
    expect(
      scanAgeLabel(at, at.add(const Duration(hours: 3)), demo: true),
      'Last simulated update 3h ago',
    );
    expect(
      scanAgeLabel(at, at.subtract(const Duration(seconds: 3)), demo: false),
      'Last fresh result 0s ago',
    );
  });
}
